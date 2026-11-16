extends RefCounted
## Drives a LocoController along a scripted path and measures what the
## acceptance criteria ask for, from the emitted pose only.

const Morph = preload("../loco_morphology.gd")
const Ctl = preload("../loco_controller.gd")
const IK = preload("../loco_ik.gd")
const Support = preload("../loco_support.gd")
const Bodies = preload("bodies.gd")

var morph
var ctl
var ground: Callable
var pos := Vector3.ZERO
var yaw := 0.0
var t := 0.0
var frames: Array = []          # per-frame records
var steps: Array = []           # completed stance phases: {leg, t0, t1, slide, target_drift}
var gait_events: Array = []     # {t, from, to, fr}
var keep_frames := true
var _stance: Array = []
var nan_seen := false
var max_stretch := 0.0
var min_clearance := INF        # swing foot height above ground (should never be negative)
var max_swing_lift := 0.0
var max_drop := 0.0             # largest reach-guard drop / hip height
var max_vert_acc := 0.0         # largest |d2 root.y / dt2| in g (second difference)
var knee_mid: Array = []        # knee flexion (deg) per leg samples at mid-stance
var _y_hist: Array = []
var _dt := 1.0 / 60.0

func _init(body: Dictionary, ground_fn: Callable = Callable()) -> void:
	morph = Morph.analyse(body)
	ground = ground_fn if ground_fn.is_valid() else func(_x, _z): return 0.0
	ctl = Ctl.new(morph, ground)
	ctl.gait_changed.connect(func(a, b, f): gait_events.append({"t": t, "from": a, "to": b, "fr": f}))
	for i in range(morph.legs.size()):
		_stance.append({})

func speed_for_froude(f: float) -> float:
	return sqrt(f * 9.81 * morph.hip_height)

## speed_fn(t) -> m/s, yawrate_fn(t) -> rad/s. `tick` > 0 emulates the C
## world: the pose is sampled at that period and interpolated linearly.
func run(duration: float, speed_fn: Callable, yawrate_fn: Callable = Callable(), dt := 1.0 / 60.0, tick := 0.0) -> void:
	_dt = dt
	var n := int(round(duration / dt))
	var tick_a := pos
	var tick_b := pos
	var yaw_a := yaw
	var yaw_b := yaw
	var tick_t := 0.0
	for k in range(n):
		var sp: float = speed_fn.call(t)
		var wr: float = yawrate_fn.call(t) if yawrate_fn.is_valid() else 0.0
		yaw += wr * dt
		var vel := Vector3(sin(yaw), 0.0, cos(yaw)) * sp
		pos += vel * dt
		t += dt
		if tick > 0.0:
			tick_t += dt
			if tick_t >= tick - 1e-9:
				tick_t = 0.0
				tick_a = tick_b; yaw_a = yaw_b
				tick_b = pos; yaw_b = yaw
			var a := tick_t / tick
			ctl.step(dt, tick_a.lerp(tick_b, a), lerp_angle(yaw_a, yaw_b, a))
		else:
			ctl.step(dt, pos, yaw, vel)
		_measure()

func _measure() -> void:
	var p: Dictionary = ctl.pose
	var root: Transform3D = p.root
	if not (is_finite(root.origin.x) and is_finite(root.origin.y) and is_finite(root.basis.x.x) and is_finite(p.neck.pitch) and is_finite(p.tail.yaw)):
		nan_seen = true
	var n_contact := 0
	max_drop = max(max_drop, float(ctl._drop) / morph.hip_height) if t > 2.0 else max_drop
	_y_hist.append(root.origin.y)
	if _y_hist.size() > 3:
		_y_hist.pop_front()
	if _y_hist.size() == 3 and t > 2.0:
		max_vert_acc = max(max_vert_acc, abs(_y_hist[2] - 2.0 * _y_hist[1] + _y_hist[0]) / (_dt * _dt) / 9.81)
	for i in range(morph.legs.size()):
		var m: Dictionary = morph.legs[i]
		var hip: Vector3 = root * m.hip
		var target: Vector3 = p.feet[i]
		var sol := IK.two_bone(hip, target, m.upper, m.lower, root.basis.z)
		var st: Dictionary = _stance[i]
		if p.contact[i]:
			n_contact += 1
			var ls: float = ctl._legs[i].s
			if ls > 0.4 and ls < 0.6 and t > 2.0:
				var dd: float = hip.distance_to(target)
				var ci: float = clamp((m.upper * m.upper + m.lower * m.lower - dd * dd) / (2.0 * m.upper * m.lower), -1.0, 1.0)
				knee_mid.append(180.0 - rad_to_deg(acos(ci)))
			max_stretch = max(max_stretch, sol.stretch)
			if st.is_empty():
				_stance[i] = {"leg": i, "t0": t, "p0": sol.foot, "q0": target, "slide": 0.0, "drift": 0.0}
			else:
				st.slide = max(st.slide, (sol.foot as Vector3).distance_to(st.p0))
				st.drift = max(st.drift, target.distance_to(st.q0))
		else:
			if not st.is_empty():
				st["t1"] = t
				steps.append(st)
				_stance[i] = {}
			var clr: float = target.y - m.ankle - float(ground.call(target.x, target.z))
			min_clearance = min(min_clearance, clr)
			max_swing_lift = max(max_swing_lift, clr)
	var poly := Support.polygon(p, morph)
	var com: Vector3 = p.com
	var margin := Support.margin(poly, Vector2(com.x, com.z))
	if keep_frames:
		frames.append({"t": t, "contact": p.contact.duplicate(), "n": n_contact, "margin": margin,
			"com_y": com.y - float(ground.call(com.x, com.z)), "root_y": root.origin.y, "gait": p.gait, "fr": p.froude,
			"pitch": p.pitch, "roll": p.roll, "duty": p.duty, "cadence": p.cadence, "stride": p.stride,
			"neck": p.neck.duplicate(), "tail": p.tail.duplicate(), "com": com, "bounce": p.bounce})

func max_slide(t_from := 0.0) -> float:
	var s := 0.0
	for st in steps:
		if st.t0 >= t_from:
			s = max(s, st.slide)
	return s

func stable_fraction(t_from := 0.0) -> float:
	var ok := 0
	var n := 0
	for f in frames:
		if f.t < t_from:
			continue
		n += 1
		if f.margin >= 0.0:
			ok += 1
	return float(ok) / max(n, 1)

## Measured footfall pattern over [t_from, end]: duty factor per leg and the
## touchdown phase of each leg relative to leg `ref`, from contact flags only.
func footfalls(t_from: float, ref := 0) -> Dictionary:
	var n: int = morph.legs.size()
	if n == 0:
		return {"period": 0.0, "phase": [], "duty": []}
	var td: Array = []
	var on: Array = []
	var tot := 0
	for i in range(n):
		td.append([])
		on.append(0)
	var prev: Array = []
	for f in frames:
		if f.t < t_from:
			continue
		tot += 1
		for i in range(n):
			if f.contact[i]:
				on[i] += 1
				if not prev.is_empty() and not prev[i]:
					td[i].append(f.t)
		prev = f.contact
	var period := 0.0
	if td[ref].size() >= 2:
		period = (td[ref][-1] - td[ref][0]) / (td[ref].size() - 1)
	var ph: Array = []
	var du: Array = []
	for i in range(n):
		du.append(float(on[i]) / max(tot, 1))
		var acc := Vector2.ZERO
		for x in td[i]:
			# phase relative to the latest ref touchdown before x
			var last := -1.0
			for r in td[ref]:
				if r <= x + 1e-9:
					last = r
			if last >= 0.0 and period > 0.0:
				var a: float = TAU * (x - last) / period
				acc += Vector2(cos(a), sin(a))
		ph.append(fposmod(acc.angle() / TAU, 1.0) if acc.length() > 0.0 else -1.0)
	return {"period": period, "phase": ph, "duty": du}

func knee_mean() -> float:
	var a := 0.0
	for k in knee_mid:
		a += k
	return a / max(knee_mid.size(), 1)
