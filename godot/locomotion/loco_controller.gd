extends RefCounted
## Locomotion controller (G73): the visual and physical interpretation of the
## C world's position, heading and speed for one creature.
##
## Pure maths, no nodes. Feed it the interpolated world pose every frame with
## step(); read `pose` and hand it to the creature rig.
##
##   var loco = LocoController.new(LocoMorphology.analyse(rig.loco_describe()), ground_fn)
##   loco.step(delta, world_pos, heading_yaw, world_velocity)
##   rig.loco_apply(loco.pose)
##
## Frames: +Y up; a body with yaw 0 faces +Z and yaw 90 degrees faces +X
## (the C world's bearing convention). Body-local +X is the creature's left.

const Gait = preload("loco_gait.gd")
const G := 9.81
const MAX_DT := 1.0 / 90.0
const STRAIGHT := 0.985         # longest a leg is allowed to get, as a share of its length

signal footfall(leg: int, position: Vector3)
signal liftoff(leg: int, position: Vector3)
signal gait_changed(from: StringName, to: StringName, froude: float)

var morph
var ground: Callable            # func(x: float, z: float) -> float (metres)

# --- readable state
var gait: StringName = &"walk"
var fr := 0.0
var duty := 0.8
var stride := 1.0
var cadence := 0.0              # strides per second
var phase := 0.0                # master stride phase (unbounded)
var bounce := 0.0               # 0 inverted pendulum .. 1 spring-mass
var crouch := 0.0
var time := 0.0
var pose := {}

# --- tunables (dimensionless)
var vault_gain := 1.0           # share of the rigid-leg pendulum arc the hips follow
var leg_axis_torque := 0.25     # share of leg force that pitches the body
var bank_gain := 0.7
var stability_gain := 0.9

var _legs: Array = []
var _off := PackedFloat32Array()
var _ready_ok := false
var _pos := Vector3.ZERO
var _yaw := 0.0
var _vel := Vector3.ZERO
var _acc := Vector3.ZERO
var _yawrate := 0.0
var _speed_f := 0.0
var _slope_f := 0.0
var _slope_l := 0.0
var _moving := 0.0
# springs: value, velocity
var _a := Vector2.ZERO          # ground-following height of the body origin
var _b := Vector2.ZERO          # fore-aft slope of the hip plane (+ = nose up)
var _c := Vector2.ZERO          # lateral slope of the hip plane (+ = left side up)
var _sx := Vector2.ZERO         # lateral balance shift
var _sz := Vector2.ZERO         # fore-aft balance shift
var _y := Vector2.ZERO          # spring-mass vertical bounce
var _p := Vector2.ZERO          # spring-mass pitch
var _lean := Vector2.ZERO       # pitch from acceleration
var _bank := Vector2.ZERO       # roll from turning
var _neck_p := Vector2.ZERO
var _neck_y := Vector2.ZERO
var _tail_p := Vector2.ZERO
var _tail_y := Vector2.ZERO
var _drop := 0.0
var _f_avg := 1.0
var _y_amp := 0.0
var _t_avg := 0.0
var _wave_phase := 0.0
var _omega := 10.0
var _zeta := 0.8
var _ref_h := 0.3
var _stride_mult := 1.0

func _init(morphology = null, ground_fn: Callable = Callable()) -> void:
	if morphology != null:
		setup(morphology, ground_fn)

func setup(morphology, ground_fn: Callable = Callable()) -> void:
	morph = morphology
	ground = ground_fn
	_ref_h = morph.hip_height
	# Heavier bodies: lower natural frequency and more damping than dynamic
	# similarity alone gives (stocky bodies ride lower and settle slower).
	var rob: float = clamp(morph.robustness, 0.2, 8.0)
	_omega = 12.0 * sqrt(G / _ref_h) * pow(rob, -0.15)
	_zeta = clamp(0.7 + 0.15 * log(max(morph.mass, 1.0) / 10.0) / log(10.0), 0.6, 1.3)
	_stride_mult = clamp(pow(rob, 0.06), 0.9, 1.15)
	gait = Gait.base_gait(morph)
	_off = Gait.offsets(gait, morph)
	duty = Gait.duty(gait, 0.0)
	bounce = 0.0
	_legs = []
	for i in range(morph.legs.size()):
		_legs.append({"theta": -float(_off[i]), "swing": false, "th0": 0.0, "th1": 1.0,
			"foot": Vector3.ZERO, "from": Vector3.ZERO, "target": Vector3.ZERO, "g_to": 0.0,
			"lift": 0.0, "load": 1.0, "s": 0.5, "u": 0.0, "force": false, "err": 0.0, "rate": 0.0})
	_ready_ok = false

func _gy(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else 0.0

static func _wrap(x: float) -> float:
	return x - round(x)

static func _spring(s: Vector2, target: float, omega: float, zeta: float, h: float) -> Vector2:
	# implicit damped spring: stable for any omega * h
	var v := (s.y + h * omega * omega * (target - s.x)) / (1.0 + 2.0 * zeta * omega * h + omega * omega * h * h)
	return Vector2(s.x + v * h, v)

static func _lp(tau: float, h: float) -> float:
	return 1.0 - exp(-h / max(tau, 1e-5))

## Place the creature at rest (also used after a teleport).
func reset(pos: Vector3, yaw: float) -> void:
	_pos = Vector3(pos.x, 0.0, pos.z)
	_yaw = yaw
	_vel = Vector3.ZERO
	_acc = Vector3.ZERO
	_yawrate = 0.0
	_speed_f = 0.0
	_moving = 0.0
	var basis := Basis(Vector3.UP, yaw)
	for i in range(_legs.size()):
		var m: Dictionary = morph.legs[i]
		var f: Vector3 = _pos + basis * Vector3(m.home.x, 0.0, m.home.z)
		f.y = _gy(f.x, f.z) + m.ankle
		var l: Dictionary = _legs[i]
		l.foot = f
		l.swing = false
		l.theta = -float(_off[i])
		l.force = false
		l.g_to = f.y - m.ankle
	for s in ["_b", "_c", "_sx", "_sz", "_y", "_p", "_lean", "_bank", "_neck_p", "_neck_y", "_tail_p", "_tail_y"]:
		set(s, Vector2.ZERO)
	_a = Vector2(_gy(pos.x, pos.z), 0.0)
	_drop = 0.0
	_f_avg = 1.0
	_t_avg = 0.0
	_ready_ok = true
	_sub(1e-4, _pos, yaw, Vector3.ZERO, true)

## Advance by dt seconds. `pos` is the interpolated world position (y is
## ignored: height comes from the ground function), `yaw` the heading in
## radians, `vel` the world velocity (derived from positions when omitted).
func step(dt: float, pos: Vector3, yaw: float, vel = null) -> Dictionary:
	if not _ready_ok or Vector2(pos.x - _pos.x, pos.z - _pos.z).length() > 4.0 * max(morph.body_length, _ref_h) + 12.0 * dt:
		reset(pos, yaw)
		return pose
	if dt <= 0.0:
		return pose
	var p1 := Vector3(pos.x, 0.0, pos.z)
	var v: Vector3 = (p1 - _pos) / dt if vel == null else Vector3(vel.x, 0.0, vel.z)
	var n: int = max(1, int(ceil(dt / MAX_DT)))
	var h := dt / n
	var p0 := _pos
	var y0 := _yaw
	var dy := wrapf(yaw - y0, -PI, PI)
	for k in range(1, n + 1):
		var t := float(k) / n
		_sub(h, p0.lerp(p1, t), y0 + dy * t, v, false)
	return pose

func _sub(h: float, p: Vector3, yaw: float, v: Vector3, settle: bool) -> void:
	time += h
	var basis := Basis(Vector3.UP, yaw)
	var fwd := basis.z
	var left := basis.x
	# --- 1. kinematics of the driving pose
	_acc = _acc.lerp((v - _vel) / h, _lp(0.18, h))
	_vel = v
	_yawrate = lerpf(_yawrate, wrapf(yaw - _yaw, -PI, PI) / h, _lp(0.1, h))
	_pos = p
	_yaw = yaw
	var speed := v.length()
	_speed_f = lerpf(_speed_f, speed, _lp(0.12, h))
	fr = Gait.froude(_speed_f, _ref_h)
	var v_eps := 0.03 * sqrt(G * _ref_h)
	var moving := _speed_f > v_eps
	_moving = lerpf(_moving, 1.0 if moving else 0.0, _lp(0.15, h))
	# --- 2. terrain under the body
	var ell: float = max(0.35 * morph.body_length, 0.5 * _ref_h)
	var sf := (_gy(p.x + fwd.x * ell, p.z + fwd.z * ell) - _gy(p.x - fwd.x * ell, p.z - fwd.z * ell)) / (2.0 * ell)
	var sl := (_gy(p.x + left.x * ell, p.z + left.z * ell) - _gy(p.x - left.x * ell, p.z - left.z * ell)) / (2.0 * ell)
	var kt := 1.0 if settle else _lp(0.15, h)
	_slope_f = lerpf(_slope_f, sf, kt)
	_slope_l = lerpf(_slope_l, sl, kt)
	var dir := v / speed if speed > 1e-4 else fwd
	var grade := _slope_f * dir.dot(fwd) + _slope_l * dir.dot(left)
	# --- 3. gait and timing
	var g := Gait.select(morph, gait, fr)
	if g != gait:
		var old := gait
		gait = g
		_off = Gait.offsets(gait, morph)
		gait_changed.emit(old, gait, fr)
	var legless: bool = _legs.is_empty()
	var f_nat_c := 0.25 * sqrt(G / _ref_h)
	var duty_t := Gait.duty(gait, fr)
	var stride_t := Gait.stride_length(gait, fr, _ref_h) * _stride_mult
	# slopes: shorter strides uphill (more) and downhill (less)
	stride_t *= 1.0 / (1.0 + 1.6 * grade) if grade > 0.0 else 1.0 / (1.0 - 0.6 * grade)
	var bounce_t := Gait.bounce(gait)
	# Reach. A walking leg stays straight and the hip vaults over it (step 8),
	# so only the leg angle limits the stride. A bouncing gait needs the hips
	# low enough for a straight leg to reach touchdown and lift-off: crouch,
	# then clip the stride to what the legs allow.
	var crouch_max := 0.18
	var crouch_t := 0.0
	_y_amp = max(abs(_y.x), _y_amp * exp(-h * max(cadence, f_nat_c)))
	for i in range(_legs.size()):
		var m: Dictionary = morph.legs[i]
		var lr: float = STRAIGHT * m.length
		var off_x: float = abs(m.home.x - m.hip.x)     # sprawl
		var off: float = abs(m.home.z - m.hip.z)       # feet carried ahead of or behind the hip
		var d_lim: float = sqrt(max(0.36 * lr * lr - off_x * off_x, 0.0)) - off
		var d_half: float = 0.5 * duty_t * stride_t / 0.92
		if d_half > d_lim:
			stride_t = max(2.0 * 0.92 * d_lim, 0.1 * _ref_h) / duty_t
			d_half = 0.5 * duty_t * stride_t / 0.92
		var d_req: float = sqrt(off_x * off_x + (off + d_half) * (off + d_half))
		var need: float = bounce_t * (1.0 - (sqrt(max(lr * lr - d_req * d_req, 0.0)) - _y_amp) / m.rest_h)
		if need > crouch_max:
			var hh: float = m.rest_h * (1.0 - crouch_max / max(bounce_t, 0.05)) + _y_amp
			var d_max: float = sqrt(max(lr * lr - hh * hh - off_x * off_x, 0.0))
			if d_max - off < d_half:
				stride_t = max(2.0 * 0.92 * (d_max - off), 0.1 * _ref_h) / duty_t
			need = crouch_max
		crouch_t = max(crouch_t, need)
	var f_nat := f_nat_c
	var kg := 1.0 if settle else _lp(0.35 / max(cadence, f_nat), h)
	duty = lerpf(duty, duty_t, kg)
	bounce = lerpf(bounce, bounce_t, kg)
	crouch = lerpf(crouch, crouch_t, kg)
	stride = stride_t if settle else lerpf(stride, stride_t, _lp(0.15, h))
	cadence = _speed_f / max(stride, 1e-4)
	# --- 4. clock: keep stepping while a foot is in the air or out of place
	var need_fix := false
	for l in _legs:
		if l.swing or l.err > 0.12 * _ref_h:
			need_fix = true
	var f_eff: float = cadence if moving else (max(f_nat, cadence) if need_fix else 0.0)
	phase += f_eff * h
	# --- 5/6. leg oscillators and footsteps
	var hip_w: Array = []
	var root_prev: Transform3D = pose.get("root", Transform3D(basis, p))
	for i in range(_legs.size()):
		var l: Dictionary = _legs[i]
		var m: Dictionary = morph.legs[i]
		var rate: float = f_eff * clamp(1.0 + 3.0 * _wrap(phase - _off[i] - l.theta), 0.5, 1.8)
		l.theta += rate * h
		l.rate = rate
		var home_l := Vector3(m.home.x, 0.0, m.home.z)
		var home_now: Vector3 = p + basis * home_l
		var hip_now: Vector3 = root_prev * m.hip
		hip_w.append(hip_now)
		var frac: float = l.theta - floor(l.theta)
		if not l.swing:
			l.err = Vector2(l.foot.x - home_now.x, l.foot.z - home_now.z).length()
			var in_window: bool = frac >= duty and frac < duty + 0.4 * (1.0 - duty)
			var want: bool = moving or l.err > 0.12 * _ref_h
			if l.force and (moving or l.err > 0.05 * _ref_h):
				l.theta = floor(l.theta) + duty
				in_window = true
				want = true
			l.force = false
			if in_window and want:
				l.swing = true
				l.th0 = l.theta
				l.th1 = floor(l.theta) + 1.0
				l.from = l.foot
				l.lift = 0.0
				l.u = 0.0
				liftoff.emit(i, l.foot)
		if l.swing:
			var u: float = clamp((l.theta - l.th0) / max(l.th1 - l.th0, 1e-5), 0.0, 1.0)
			l.u = u
			var t_td: float = (1.0 - u) * (l.th1 - l.th0) / max(rate, 1e-4)
			var t_mid: float = t_td
			if moving:
				t_mid += 0.5 * duty / max(f_eff, 1e-4)
			t_mid = min(t_mid, 2.0)
			var yaw_p: float = yaw + clamp(_yawrate * t_mid, -0.9, 0.9)
			var target: Vector3 = p + v * t_mid + Basis(Vector3.UP, yaw_p) * home_l
			# keep the touchdown inside the leg's reach from where the hip will be
			var hip_td: Vector3 = hip_now + v * t_td
			var lr: float = 0.97 * m.length
			var hh: float = m.rest_h * (1.0 - crouch) - (1.0 - bounce) * 0.1 * m.rest_h
			var d_max: float = sqrt(max(lr * lr - hh * hh, 0.0))
			var dv := Vector2(target.x - hip_td.x, target.z - hip_td.z)
			if dv.length() > d_max:
				dv = dv.normalized() * d_max
				target.x = hip_td.x + dv.x
				target.z = hip_td.z + dv.y
			l.g_to = _gy(target.x, target.z)
			target.y = l.g_to + m.ankle
			l.target = target
			var e := u * u * u * (10.0 - 15.0 * u + 6.0 * u * u)   # minimum jerk
			var q: Vector3 = l.from.lerp(target, e)
			var gq: float = _gy(q.x, q.z) + m.ankle
			# swing arc: grows with speed, with step length and with what is in the way
			var dist := Vector2(target.x - l.from.x, target.z - l.from.z).length()
			var base_h: float = (0.05 + 0.09 * min(1.0, fr / 1.5)) * m.rest_h * m.lift
			base_h *= clamp(dist / (0.25 * m.rest_h), 0.0, 1.0)
			if l.lift == 0.0:
				var need_h := 0.0
				for k in range(1, 6):
					var uk := k / 6.0
					var ek := uk * uk * uk * (10.0 - 15.0 * uk + 6.0 * uk * uk)
					var qk: Vector3 = l.from.lerp(target, ek)
					var over: float = _gy(qk.x, qk.z) + m.ankle + 0.02 * m.rest_h - lerpf(l.from.y, target.y, ek)
					need_h = max(need_h, over / sin(PI * uk))
				l.lift = max(need_h, 1e-4)
			var shape := sin(PI * u)
			if u > 0.08 and u < 0.92:
				l.lift = max(l.lift, (gq + 0.01 * m.rest_h - q.y) / shape)
			var lift: float = min(max(base_h, l.lift), 0.7 * m.length)
			q.y = max(q.y + lift * shape, gq)
			l.foot = q
			if u >= 1.0:
				l.swing = false
				l.foot = target
				l.err = 0.0
				footfall.emit(i, target)
		# load taken by this leg (ramps in after touchdown, out before lift-off)
		if l.swing:
			l.s = 0.0
			l.load = 0.0
		else:
			frac = l.theta - floor(l.theta)
			l.s = clamp(frac / max(duty, 1e-3), 0.0, 1.0)
			var ramp: float = smoothstep(0.0, 0.2, l.s) * (1.0 - smoothstep(0.8, 1.0, l.s))
			l.load = lerpf(1.0, ramp, _moving)
	# --- 8. support plane through the hips (terrain + inverted-pendulum vault)
	var kp: float = {&"upright_biped": 0.25, &"horizontal_biped": 0.5}.get(morph.plan, 1.0)
	var bt := _slope_f * kp
	var ct := _slope_l * (0.35 if kp >= 1.0 else 0.15)
	var a_t := _gy(p.x, p.z)
	var b_t := bt
	var c_t := ct
	var cx := 0.0
	var cz := 0.0
	var cw := 0.0
	var f_sum := 0.0
	var tq := 0.0
	if legless:
		var gsum := 0.0
		for k in range(5):
			var o: float = (k / 4.0 - 0.5) * morph.body_length * 0.8
			gsum += _gy(p.x + fwd.x * o, p.z + fwd.z * o) / 5.0
		a_t = gsum
	else:
		var sw := 0.0; var swz := 0.0; var swx := 0.0; var swzz := 0.0; var swxx := 0.0; var swzx := 0.0
		var swe := 0.0; var swze := 0.0; var swxe := 0.0
		var nl := float(_legs.size())
		for i in range(_legs.size()):
			var l: Dictionary = _legs[i]
			var m: Dictionary = morph.legs[i]
			var e: float = l.g_to
			var w := 0.12
			var at: Vector3 = basis.inverse() * (l.target - p) if l.swing else basis.inverse() * (l.foot - p)
			if not l.swing:
				# inverted pendulum: the hip rides an arc whose radius is the
				# straight leg, so a walking stance leg stays extended
				# (sprawled legs are not pendulums: they vault less)
				var hn: Vector3 = p + basis * Vector3(m.hip.x, 0.0, m.hip.z)
				var lp: float = STRAIGHT * m.length
				var d: float = min(Vector2(l.foot.x - hn.x, l.foot.z - hn.z).length(), 0.95 * lp)
				var d0: float = min(Vector2(m.home.x - m.hip.x, m.home.z - m.hip.z).length(), 0.95 * lp)
				var erect: float = 1.0 - clamp(abs(m.home.x - m.hip.x) / (0.5 * lp), 0.0, 1.0)
				var vault: float = sqrt(lp * lp - d * d) - sqrt(lp * lp - d0 * d0)
				e = l.foot.y - m.ankle + (1.0 - bounce) * vault_gain * erect * vault
				w += m.share * l.load * nl
				var wl: float = m.share * l.load
				cx += at.x * wl
				cz += at.z * wl
				cw += wl
				var force: float = m.share * (PI / (2.0 * max(duty, 0.05))) * sin(PI * l.s)
				f_sum += force
				tq += force * (m.hip.z - morph.com.z)
			# the plane is fitted at the feet's neutral positions; a foot away
			# from neutral is brought back along the local terrain slope
			var z: float = m.home.z
			var x: float = m.home.x
			e -= _slope_f * (at.z - z) + _slope_l * (at.x - x)
			sw += w; swz += w * z; swx += w * x; swzz += w * z * z; swxx += w * x * x; swzx += w * z * x
			swe += w * e; swze += w * z * e; swxe += w * x * e
		var lb: float = 0.02 * sw * morph.body_length * morph.body_length
		var lc: float = 0.6 * sw * morph.track_width * morph.track_width
		var mat := Basis(Vector3(sw, swz, swx), Vector3(swz, swzz + lb, swzx), Vector3(swx, swzx, swxx + lc))
		if abs(mat.determinant()) > 1e-12:
			var sol: Vector3 = mat.inverse() * Vector3(swe, swze + lb * bt, swxe + lc * ct)
			a_t = sol.x
			b_t = clamp(sol.y, -1.2, 1.2)
			c_t = clamp(sol.z, -0.6, 0.6)
	if settle:
		_a = Vector2(a_t, 0.0); _b = Vector2(b_t, 0.0); _c = Vector2(c_t, 0.0)
	else:
		_a = _spring(_a, a_t, _omega, _zeta, h)
		_b = _spring(_b, b_t, _omega, _zeta, h)
		_c = _spring(_c, c_t, _omega * 0.7, _zeta, h)
	# --- 10. balance: shift the centre of mass toward the loaded feet when slow
	var tx := 0.0
	var tz := 0.0
	if cw > 0.05:
		var biped: bool = morph.plan == &"upright_biped" or morph.plan == &"horizontal_biped"
		var ks: float = stability_gain / (1.0 + pow(fr / 0.12, 2.0))
		var klat: float = 0.55 / (1.0 + fr / 0.15) if biped else ks
		var kfa: float = 0.0 if biped else ks
		tx = clamp(klat * (cx / cw - morph.com.x), -0.45 * morph.track_width, 0.45 * morph.track_width)
		tz = clamp(kfa * (cz / cw - morph.com.z), -0.15 * morph.body_length, 0.15 * morph.body_length)
	var ws: float = max(0.6 * sqrt(G / _ref_h) * 2.0, TAU * f_eff * 3.0)
	_sx = _spring(_sx, tx, ws, 1.0, h)
	_sz = _spring(_sz, tz, ws, 1.0, h)
	# --- 11. spring-mass: vertical bounce and pitch from the leg forces
	var wc: float = 0.45 * TAU * max(f_eff, f_nat)
	var drive := bounce * _moving
	var zc: float = clamp(_zeta * 0.7, 0.4, 1.0)
	var den := 1.0 + 2.0 * zc * wc * h + wc * wc * h * h
	# only the fluctuation of the leg forces about their running mean moves the
	# body: in a steady gait that mean is body weight (f_sum = 1)
	var kf := _lp(1.0 / max(f_eff, f_nat), h)
	_f_avg = lerpf(_f_avg, f_sum, kf)
	_t_avg = lerpf(_t_avg, tq, kf)
	_y.y = (_y.y + h * (drive * G * (f_sum - _f_avg) - wc * wc * _y.x)) / den
	_y.x = clamp(_y.x + _y.y * h, -0.3 * _ref_h, 0.3 * _ref_h)
	_p.y = (_p.y + h * (drive * leg_axis_torque * morph.mass * G * (tq - _t_avg) / morph.inertia.x - wc * wc * _p.x)) / den
	_p.x = clamp(_p.x + _p.y * h, -0.22, 0.22)
	# --- 12. lean from acceleration, bank from turning
	var a_fwd := _acc.dot(fwd)
	var lean_t := 0.0
	match morph.plan:
		&"upright_biped": lean_t = -0.8 * a_fwd / G
		&"horizontal_biped": lean_t = -0.5 * a_fwd / G
		&"legless": lean_t = 0.0
		_:
			var wb: float = max(morph.body_length * 0.5, 0.1)
			if morph.stations.size() >= 2:
				wb = max(morph.stations[-1].z - morph.stations[0].z, 0.1)
			lean_t = 0.6 * a_fwd * morph.com.y / (G * wb)
	lean_t = clamp(lean_t, -0.25, 0.25)
	var bank_k: float = bank_gain * (0.4 if morph.plan == &"multi" or legless else 1.0)
	var bank_t: float = clamp(-atan(_speed_f * _yawrate / G) * bank_k, -0.4, 0.4)
	_lean = _spring(_lean, lean_t, _omega * 0.4, 1.0, h)
	_bank = _spring(_bank, bank_t, _omega * 0.4, 1.0, h)
	# --- 13. compose the body transform
	var slope_b := _b.x + _p.x + _lean.x
	var pitch := -atan(slope_b)                    # rotation about +X (left)
	var roll := atan(_c.x) + _bank.x               # rotation about +Z (forward)
	var piv := Vector3(0.0, morph.com.y, morph.com.z)
	var height: float = _a.x + _b.x * morph.com.z + _y.x - crouch * _ref_h
	if legless:
		height = _a.x
	var origin: Vector3 = p + left * (_sx.x - morph.com.y * sin(_bank.x) * 0.5) + fwd * _sz.x + Vector3.UP * height
	var rot := Basis(Vector3.RIGHT, pitch) * Basis(Vector3.BACK, roll)
	var root := Transform3D(basis, origin) * Transform3D(Basis(), piv) * Transform3D(rot, Vector3.ZERO) * Transform3D(Basis(), -piv)
	# --- 14. legs must reach: pull the body down, lift a foot that cannot
	var drop := 0.0
	for i in range(_legs.size()):
		var l: Dictionary = _legs[i]
		if l.swing:
			continue
		var m: Dictionary = morph.legs[i]
		var hw: Vector3 = root * m.hip
		var lmax: float = 0.995 * m.length
		var dh := Vector2(hw.x - l.foot.x, hw.z - l.foot.z).length()
		var dyv: float = hw.y - l.foot.y
		if dh * dh + dyv * dyv > lmax * lmax:
			var need: float = dyv - sqrt(max(lmax * lmax - dh * dh, 0.0))
			if need > 0.3 * _ref_h or dh > 0.9 * lmax:
				l.force = true
			drop = max(drop, min(need, 0.6 * _ref_h))
	_drop = max(drop, _drop * exp(-h / 0.12))
	root.origin.y -= _drop
	# --- 15. girdles, neck and tail
	var st_yaw := PackedFloat32Array()
	for s in morph.stations:
		var zl := 0.0; var zr := 0.0; var nl2 := 0; var nr := 0
		for idx in s.legs:
			var fl: Vector3 = basis.inverse() * (_legs[idx].foot - p)
			if morph.legs[idx].side >= 0:
				zl += fl.z; nl2 += 1
			else:
				zr += fl.z; nr += 1
		var yw := 0.0
		if nl2 > 0 and nr > 0:
			# the girdle turns toward the leading foot: left foot ahead -> yaw to the right
			yw = -0.3 * atan2(zl / nl2 - zr / nr, max(morph.track_width, 0.05) * 2.0)
		st_yaw.append(yw)
	var hind_yaw: float = st_yaw[0] if st_yaw.size() > 0 else 0.0
	var vy := _y.y + _a.y
	var nose_up := slope_b - bt
	# tail: counter-rotates against the pelvis and lags behind turns and bounces
	var tl: float = max(morph.tail.length, 0.05)
	var wt: float = clamp(1.6 * sqrt(G / tl), 3.0, 25.0)
	_tail_y = _spring(_tail_y, clamp(-0.9 * hind_yaw - 1.4 * _yawrate / wt, -0.9, 0.9), wt, 0.45, h)
	_tail_p = _spring(_tail_p, clamp(0.8 * nose_up * 0.5 - 1.2 * vy / (tl * wt) + 0.15 * min(1.0, fr), -0.7, 0.7), wt, 0.5, h)
	# neck: keeps the head level, looks into the turn, lags the bounce
	var nk: float = max(morph.neck.length, 0.05)
	var wn: float = clamp(2.2 * sqrt(G / nk), 4.0, 30.0)
	var stretch: float = -0.25 * min(1.0, fr / 2.0) if morph.plan != &"upright_biped" else 0.0
	_neck_p = _spring(_neck_p, clamp(-0.7 * (slope_b - bt * 0.5) - 0.8 * vy / (nk * wn) + stretch, -0.8, 0.8), wn, 0.7, h)
	_neck_y = _spring(_neck_y, clamp(0.35 * _yawrate, -0.6, 0.6), wn, 0.8, h)
	# --- 16. undulation for legless bodies
	var wave_amp := 0.0
	if legless:
		var lam: float = morph.body_length / 1.5
		_wave_phase += _speed_f / lam * 1.1 * h
		wave_amp = 0.09 * morph.body_length * clamp(_speed_f / (0.25 * sqrt(G * morph.body_length)), 0.0, 1.0)
	# --- output
	var feet := PackedVector3Array()
	var contact: Array = []
	var swing_u := PackedFloat32Array()
	for l in _legs:
		feet.append(l.foot)
		contact.append(not l.swing)
		swing_u.append(l.u if l.swing else 0.0)
	pose = {
		"root": root, "feet": feet, "contact": contact, "swing_u": swing_u,
		"station_yaw": st_yaw,
		"neck": {"pitch": _neck_p.x, "yaw": _neck_y.x, "roll": -0.8 * roll},
		"tail": {"pitch": _tail_p.x, "yaw": _tail_y.x},
		"wave": {"amp": wave_amp, "phase": _wave_phase, "waves": 1.5},
		"com": root * morph.com, "gait": gait, "froude": fr, "duty": duty,
		"cadence": cadence, "stride": stride, "speed": _speed_f,
		"pitch": pitch, "roll": roll, "bounce": _y.x,
	}

## Lateral offset (metres, +left) of the spine at arc coordinate u (0 tail tip,
## 1 head) for legless undulation. Zero for legged bodies.
func wave_offset(u: float) -> float:
	var w: Dictionary = pose.get("wave", {})
	if w.is_empty() or w.amp <= 0.0:
		return 0.0
	return w.amp * (0.4 + 0.6 * (1.0 - u)) * sin(TAU * (w.waves * u + w.phase))
