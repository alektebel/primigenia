extends RefCounted
## L0 locomotion scorecard core (docs/briefs/loco-score.md, docs/research/procedural-locomotion.md section L0).
## Runs one zoo body through one scenario with fixed ticks and samples the VISUAL rig every frame (30 fps, 3 frames per
## 10 Hz C tick, interpolated like the game does). Measure only: nothing here changes locomotion or animation.
##
## run_case(parent, body, scenario) -> {body, scenario, ticks, frames, fps, metrics, reasons}
## A metric that cannot be measured is null and `reasons[key]` says why (never a made up number).

const Zoo := preload("res://devtools/zoo/zoo.gd")
const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")

const FPS := 30.0
const SUB := 3                       # rendered frames per C tick (10 Hz)
const WARMUP_TICKS := 8              # settles the procedural rig before recording
const MOVING_SPEED := 0.35           # m/s, same threshold as Zoo.stats()
const SOLE := 0.6                    # the rig's sole sits width * SOLE under the ankle (loco_rig_adapter.gd)

# course, run (1 = walk, 1.8 = sprint orders + visual speed), want (C states to start just before), skip (ticks), ticks (recorded)
const SCEN := {
	"walk":   {"course": "figure8", "run": 1.0, "want": [], "skip": 40, "ticks": 240},
	"gallop": {"course": "figure8", "run": 1.8, "want": [], "skip": 40, "ticks": 240},
	"turn":   {"course": "uturn",   "run": 1.0, "want": [], "skip": 0, "ticks": 420},
	"climb":  {"course": "ramps",   "run": 1.0, "want": ["climb", "stalled (too steep)", "slide"], "skip": 0, "ticks": 240},
	"steps":  {"course": "steps",   "run": 1.0, "want": [], "skip": 0, "ticks": 230},
}
const SCENARIOS := ["walk", "gallop", "turn", "climb", "steps"]
static var last_rec: Dictionary = {}   # raw samples of the last case (debugging)
const BACK_OFF_TICKS := 20           # recording starts this long before the wanted state shows

# ---- the run ---------------------------------------------------------------------------------------
static func _find_start(parent: Node, body: String, cfg: Dictionary) -> int:
	if cfg.want.is_empty():
		return int(cfg.skip)
	var z = Zoo.new()
	z.with_visuals = false
	z.auto_build = false
	z.morph_ids = [body]
	z.course_name = cfg.course
	z.run_speed = cfg.run
	parent.add_child(z)
	z.build()
	var found := 900
	for t in 900:
		z.step_ticks(1)
		if z.stats(0).state in cfg.want:
			found = t + 1
			break
	parent.remove_child(z)
	z.free()
	return maxi(0, found - BACK_OFF_TICKS)

static func run_case(parent: Node, body: String, scenario: String, ticks_override: int = 0) -> Dictionary:
	var cfg: Dictionary = SCEN[scenario]
	var start := _find_start(parent, body, cfg)
	var z = Zoo.new()
	z.auto_build = false
	z.morph_ids = [body]
	z.course_name = cfg.course
	z.run_speed = cfg.run
	parent.add_child(z)
	z.build()
	z.set_process(false)             # we drive the ticks and the rig by hand
	var r: Dictionary = z.runners[0]
	r.sw.set_process(false)
	var host = r.host
	z.step_ticks(maxi(0, start - WARMUP_TICKS))
	var n_ticks: int = ticks_override if ticks_override > 0 else int(cfg.ticks)
	var legs := _legs(host)
	var rec := {"states": [], "speed": [], "omega": [], "grade": [], "contact": [], "foot": [], "hip": [], "root": [],
		"root_basis": [], "head_v": [], "gait": [], "verb": [], "flip": [], "pen": []}
	var dt := 1.0 / FPS
	for t in WARMUP_TICKS + n_ticks:
		z.step_ticks(1)
		var st: Dictionary = z.stats(0)
		for k in SUB:
			var s: Dictionary = r.sw.sample(0, float(k + 1) / float(SUB))
			host.update(dt, s, {})
			if t < WARMUP_TICKS:
				continue
			_sample(rec, r, host, legs, st)
	last_rec = rec
	var out := analyse(rec, legs, r)
	out["body"] = body
	out["scenario"] = scenario
	out["ticks"] = n_ticks
	out["start_tick"] = start
	out["frames"] = rec.states.size()
	out["fps"] = FPS
	parent.remove_child(z)
	z.free()
	return out

# Rig legs that the locomotion controller drives: [{leg: CreatureLegChain, side, pair, front: false}] (read only).
static func _legs(host) -> Array:
	var d = host.driver
	var out := []
	if d.controller == null or d.adapter == null:
		return out
	var body = host.body
	for j in d.desc.leg_ids.size():
		var l = body.legs[d.desc.leg_ids[j]]
		out.append({"leg": l, "side": int(l.side), "pair": int(l.pair_index), "len": float(l.upper_length + l.lower_length) * float(d.desc.unit)})
	return out

static func _sample(rec: Dictionary, r: Dictionary, host, legs: Array, st: Dictionary) -> void:
	var d = host.driver
	var pose: Dictionary = d.controller.pose
	var body = host.body
	rec.states.append(st.state)
	rec.speed.append(float(st.speed))
	rec.omega.append(float(st.omega))
	rec.grade.append(float(st.grade))
	rec.gait.append(String(pose.get("gait", "")))
	rec.verb.append(int(r.sw.cur.order.verb))
	var contact := PackedByteArray()
	var feet := PackedVector3Array()
	var hips := PackedVector3Array()
	for j in legs.size():
		contact.append(1 if bool(pose.contact[j]) else 0)
		var l = legs[j].leg
		feet.append(l.foot.global_position)
		hips.append(l.hip_global())
	rec.contact.append(contact)
	# knee bend direction against the rest bend (creature space), and how far the sole and the knee sit below the ground
	var inv: Transform3D = body.global_transform.affine_inverse()
	var flip := PackedByteArray()
	var pen := PackedFloat32Array()
	for j in legs.size():
		var l = legs[j].leg
		var hip_l: Vector3 = inv * hips[j]
		var knee_w: Vector3 = (l.lower as Node3D).global_position
		var knee_l: Vector3 = inv * knee_w
		var ankle_l: Vector3 = inv * (feet[j] + Vector3.UP * (float(l.width) * SOLE))
		var axis := ankle_l - hip_l
		var bend := knee_l - hip_l
		if axis.length() > 1e-6:
			bend -= axis * (bend.dot(axis) / axis.length_squared())
		var rax: Vector3 = l.rest_foot
		var rb: Vector3 = l.rest_knee
		if rax.length() > 1e-6:
			rb -= rax * (rb.dot(rax) / rax.length_squared())
		var bad := bend.length() > 0.005 and rb.length() > 1e-4 and bend.dot(rb) < 0.0
		flip.append(1 if bad else 0)
		var g1: float = float(r.ground.call(feet[j].x, feet[j].z)) - feet[j].y
		var g2: float = float(r.ground.call(knee_w.x, knee_w.z)) - knee_w.y
		pen.append(maxf(0.0, maxf(g1, g2)))
	rec.flip.append(flip)
	rec.pen.append(pen)
	rec.foot.append(feet)
	rec.hip.append(hips)
	var root: Transform3D = pose.root
	rec.root.append(root.origin)
	rec.root_basis.append(root.basis)
	# head forward = from the head bone to the last spine bone (the snout tip), world space
	var sk: Skeleton3D = body.skeleton
	var hb: int = body.head_bone
	var tip: int = body.spine_bones[body.spine_bones.size() - 1]
	var a: Vector3 = sk.global_transform * sk.get_bone_global_pose(hb).origin
	var b: Vector3 = sk.global_transform * sk.get_bone_global_pose(tip).origin
	rec.head_v.append(b - a)

# ---- statistics helpers ---------------------------------------------------------------------------------
static func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for v in a:
		s += float(v)
	return s / float(a.size())

static func _pct(a: Array, p: float) -> float:
	if a.is_empty():
		return 0.0
	var b := a.duplicate()
	b.sort()
	var x := p * float(b.size() - 1)
	var i := int(floor(x))
	var f := x - float(i)
	return float(b[i]) * (1.0 - f) + float(b[mini(i + 1, b.size() - 1)]) * f

static func _r(v: float, nd: int = 4) -> float:
	return snappedf(v, pow(10.0, -nd))

static func _hz(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)

# x - centred moving average over `w` frames (window truncated at the ends): the oscillation without the trend.
static func _detrend(x: Array, w: int) -> Array:
	var n := x.size()
	var out := []
	var h := w / 2
	var pre := [0.0]
	for v in x:
		pre.append(pre[-1] + float(v))
	for i in n:
		var a := maxi(0, i - h)
		var b := mini(n, i + h)
		out.append(float(x[i]) - (pre[b] - pre[a]) / float(b - a))
	return out

# ---- the metrics ---------------------------------------------------------------------------------------
static func analyse(rec: Dictionary, legs: Array, r: Dictionary) -> Dictionary:
	var m := {}
	var why := {}
	var n: int = rec.states.size()
	var ground: Callable = r.ground
	var dt := 1.0 / FPS
	var nl := legs.size()
	var moving := PackedInt32Array()
	for i in n:
		if float(rec.speed[i]) > MOVING_SPEED and rec.states[i] != "slide":
			moving.append(i)
	var nm := moving.size()
	m["moving_frac"] = _r(float(nm) / maxf(1.0, float(n)))
	m["speed_mean_mps"] = _r(_mean(Array(Array(moving).map(func(i): return rec.speed[i])))) if nm > 0 else null
	# state fractions (all frames)
	var cnt := {}
	for s in rec.states:
		cnt[s] = int(cnt.get(s, 0)) + 1
	m["pivot_frac"] = _r(float(cnt.get("pivot", 0)) / maxf(1.0, float(n)))
	var turning := int(cnt.get("pivot", 0)) + int(cnt.get("turn", 0))
	if turning >= 10:
		m["pivot_frac_of_turns"] = _r(float(cnt.get("pivot", 0)) / float(turning))
	else:
		m["pivot_frac_of_turns"] = null
		why["pivot_frac_of_turns"] = "fewer than 10 frames of turning in this window"
	# stalled = the C state "stalled (too steep)" or stuck: a go / heading order is active but the body is not moving and not pivoting
	# (the steps course parks a body on the stair top with the order still running; Zoo.stats() calls that "idle")
	var stuck := 0
	for i in n:
		if int(rec.verb[i]) in [2, 3] and float(rec.speed[i]) <= MOVING_SPEED and rec.states[i] != "pivot":
			stuck += 1
	m["stall_frac"] = _r(float(stuck + int(cnt.get("stalled (too steep)", 0))) / maxf(1.0, float(n)))
	m["stall_state_frac"] = _r(float(cnt.get("stalled (too steep)", 0)) / maxf(1.0, float(n)))
	m["stuck_frac"] = _r(float(stuck) / maxf(1.0, float(n)))
	m["slide_frac"] = _r(float(cnt.get("slide", 0)) / maxf(1.0, float(n)))
	var gcnt := {}
	for g in rec.gait:
		gcnt[g] = int(gcnt.get(g, 0)) + 1
	var gf := {}
	for g in gcnt:
		gf[g] = _r(float(gcnt[g]) / maxf(1.0, float(n)))
	m["gait_frac"] = gf
	# turn radius from the C state (ticks held for SUB frames)
	var rmin := INF
	for i in n:
		var sp: float = float(rec.speed[i])
		var w: float = absf(float(rec.omega[i]))
		if sp > 1.0 and w > 0.1:
			rmin = minf(rmin, sp / w)
	if is_inf(rmin):
		m["min_turn_radius_m"] = null
		why["min_turn_radius_m"] = "no frames with speed > 1 m/s and yaw rate > 0.1 rad/s (no turn in this scenario)"
	else:
		m["min_turn_radius_m"] = _r(rmin, 2)
	if nl == 0:
		for k in ["knee_flip_frac", "foot_penetration_cm", "gait_symmetry", "head_pitch_deg", "head_yaw_vs_body_deg", "shoulder_hip_ratio", "back_slope_deg", "torso_roll_deg", "roll_plant_lag", "torso_bob_cm", "torso_bob_frac",
				"foot_slip_cm", "duty_factor", "airborne_frac", "footfall", "stride_len_m", "cadence_hz", "leg_extension", "foot_spacing_ratio"]:
			m[k] = null
			why[k] = "no walking legs on the rig"
		return {"metrics": m, "reasons": why}
	# ---- head pitch (world, above horizontal)
	if nm < 10:
		m["head_pitch_deg"] = null
		m["head_yaw_vs_body_deg"] = null
		why["head_pitch_deg"] = "the body is not moving in this window"
		why["head_yaw_vs_body_deg"] = why["head_pitch_deg"]
	else:
		var hp := []
		for i in moving:
			var v: Vector3 = rec.head_v[i]
			hp.append(rad_to_deg(atan2(v.y, _hz(v).length())))
		m["head_pitch_deg"] = {"mean": _r(_mean(hp), 2), "p95": _r(_pct(hp, 0.95), 2)}
		var hy := []
		for i in moving:
			var v2: Vector3 = rec.head_v[i]
			var bz: Vector3 = (rec.root_basis[i] as Basis).z
			hy.append(absf(rad_to_deg(wrapf(atan2(v2.x, v2.z) - atan2(bz.x, bz.z), -PI, PI))))
		m["head_yaw_vs_body_deg"] = {"mean": _r(_mean(hy), 2), "p95": _r(_pct(hy, 0.95), 2)}
	# ---- limb groups by mount
	var pairs := {}
	for j in nl:
		pairs[legs[j].pair] = true
	var pair_ids: Array = pairs.keys()
	pair_ids.sort()
	var front_ids := []
	var rear_ids := []
	if pair_ids.size() >= 2:
		for j in nl:
			if legs[j].pair == pair_ids[-1]:
				front_ids.append(j)
			elif legs[j].pair == pair_ids[0]:
				rear_ids.append(j)
	var hgt := func(i: int, j: int) -> float:
		var p: Vector3 = rec.hip[i][j]
		return p.y - float(ground.call(p.x, p.z))
	if front_ids.is_empty() or nm < 10:
		var rsn := "one leg pair only: no distinct front and rear limb roots" if front_ids.is_empty() else "the body is not moving in this window"
		for k in ["shoulder_hip_ratio", "back_slope_deg"]:
			m[k] = null
			why[k] = rsn
	else:
		var sum_f := 0.0
		var sum_r := 0.0
		var slopes := []
		for i in moving:
			var hf := 0.0
			var hr := 0.0
			var pf := Vector3.ZERO
			var pr := Vector3.ZERO
			for j in front_ids:
				hf += hgt.call(i, j)
				pf += rec.hip[i][j]
			for j in rear_ids:
				hr += hgt.call(i, j)
				pr += rec.hip[i][j]
			hf /= float(front_ids.size())
			hr /= float(rear_ids.size())
			pf /= float(front_ids.size())
			pr /= float(rear_ids.size())
			sum_f += hf
			sum_r += hr
			slopes.append(rad_to_deg(atan2(hf - hr, _hz(pf - pr).length())))
		m["shoulder_hip_ratio"] = _r(sum_f / maxf(sum_r, 1e-3))      # ratio of the means (a mean of ratios explodes when a rear root touches the ground)
		m["back_slope_deg"] = _r(_mean(slopes), 2)
	# ---- touchdowns, strides
	var touch := []          # per foot: frame indices of swing -> stance
	for j in nl:
		var td := []
		for i in range(1, n):
			if rec.contact[i][j] == 1 and rec.contact[i - 1][j] == 0:
				td.append(i)
		touch.append(td)
	var periods := []
	var cadences := []
	var strides := []
	for j in nl:
		var td: Array = touch[j]
		var pj := []
		for k in range(1, td.size()):
			var f0: int = td[k - 1]
			var f1: int = td[k]
			pj.append(f1 - f0)
			strides.append(_hz((rec.root[f1] as Vector3) - (rec.root[f0] as Vector3)).length())
		if not pj.is_empty():
			cadences.append(1.0 / (_mean(pj) * dt))
			periods.append(_mean(pj))
	var T := 0
	if periods.is_empty():
		for k in ["stride_len_m", "cadence_hz"]:
			m[k] = null
			why[k] = "no complete stride (two touchdowns of one foot) in this window"
	else:
		T = int(round(_pct(periods, 0.5)))
		m["stride_len_m"] = _r(_mean(strides), 3)
		m["cadence_hz"] = _r(_mean(cadences), 3)
	# ---- duty factor and airborne fraction (moving frames)
	if nm < 10:
		m["duty_factor"] = null
		m["airborne_frac"] = null
		why["duty_factor"] = "the body is not moving in this window"
		why["airborne_frac"] = why["duty_factor"]
	else:
		var duty := []
		for j in nl:
			var c := 0
			for i in moving:
				c += int(rec.contact[i][j])
			duty.append(float(c) / float(nm))
		var air := 0
		for i in moving:
			var any := false
			for j in nl:
				if rec.contact[i][j] == 1:
					any = true
					break
			if not any:
				air += 1
		m["duty_factor"] = {"mean": _r(_mean(duty)), "per_foot": duty.map(func(v): return _r(v))}
		m["airborne_frac"] = _r(float(air) / float(nm))
	# ---- legs bent the wrong way (any stance leg) and feet / knees through the ground (every leg, every frame)
	var flipped := 0
	var stance_frames := 0
	for i in n:
		var anyc := false
		var anyf := false
		for j in nl:
			if rec.contact[i][j] == 1:
				anyc = true
				if rec.flip[i][j] == 1:
					anyf = true
		if anyc:
			stance_frames += 1
			if anyf:
				flipped += 1
	if stance_frames == 0:
		m["knee_flip_frac"] = null
		why["knee_flip_frac"] = "no stance frame in this window"
	else:
		m["knee_flip_frac"] = _r(float(flipped) / float(stance_frames))
	var depths := []
	for i in n:
		for j in nl:
			depths.append(float(rec.pen[i][j]) * 100.0)
	m["foot_penetration_cm"] = {"mean": _r(_mean(depths), 3), "p95": _r(_pct(depths, 0.95), 3), "max": _r(depths.max(), 3)}
	# ---- gait symmetry: left to right step time over right to left, per leg pair (1.0 = even steps), mean over the pairs
	var ratios := []
	for pr in pair_ids:
		var lt := []
		var rt := []
		for j in nl:
			if legs[j].pair == pr:
				(lt if legs[j].side > 0 else rt).append_array(touch[j])
		lt.sort()
		rt.sort()
		var lr := []
		var rl := []
		for f0 in lt:
			for f1 in rt:
				if f1 > f0:
					lr.append(f1 - f0)
					break
		for f0 in rt:
			for f1 in lt:
				if f1 > f0:
					rl.append(f1 - f0)
					break
		if lr.size() >= 2 and rl.size() >= 2 and _mean(rl) > 0.0:
			ratios.append(_mean(lr) / _mean(rl))
	if ratios.is_empty():
		m["gait_symmetry"] = null
		why["gait_symmetry"] = "no leg pair with left and right touchdowns in this window"
	else:
		m["gait_symmetry"] = _r(_mean(ratios), 3)
	# ---- foot slip: complete stances only (touchdown seen and lift-off seen): the largest horizontal distance of the visual foot
	# from its mid-stance position (a foot that arrives late or drifts counts)
	var slips := []
	for j in nl:
		var i := 1
		while i < n:
			if rec.contact[i][j] == 1 and rec.contact[i - 1][j] == 0:
				var e := i
				while e < n and rec.contact[e][j] == 1:
					e += 1
				if e < n and e - i >= 2:
					var p0: Vector3 = rec.foot[(i + e) / 2][j]     # anchor: where the foot sits mid stance
					var mx := 0.0
					for q in range(i, e):
						mx = maxf(mx, _hz((rec.foot[q][j] as Vector3) - p0).length())
					slips.append(mx * 100.0)
				i = e
			else:
				i += 1
	if slips.is_empty():
		m["foot_slip_cm"] = null
		why["foot_slip_cm"] = "no complete stance (touchdown and lift-off) in this window"
	else:
		m["foot_slip_cm"] = {"mean": _r(_mean(slips), 2), "p95": _r(_pct(slips, 0.95), 2), "stances": slips.size()}
	# ---- leg extension (stance, moving frames): hip to ankle over the leg's rest length
	var ext := []
	var spacing := []
	for i in moving:
		for j in nl:
			if rec.contact[i][j] == 1:
				var l = legs[j].leg
				var ankle: Vector3 = (rec.foot[i][j] as Vector3) + Vector3.UP * (float(l.width) * SOLE)
				ext.append(((rec.hip[i][j] as Vector3) - ankle).length() / maxf(float(l.upper_length + l.lower_length), 1e-3))
	if ext.is_empty():
		m["leg_extension"] = null
		why["leg_extension"] = "no foot in stance while moving"
	else:
		m["leg_extension"] = _r(_mean(ext))
	# ---- foot spacing: closest same-side feet along the body (stance, moving), over the mean leg length (bunched legs = small)
	var mean_len := 0.0
	for j in nl:
		mean_len += float(legs[j].len)
	mean_len /= float(nl)
	if pair_ids.size() < 2 or nm < 10:
		m["foot_spacing_ratio"] = null
		why["foot_spacing_ratio"] = "one leg pair only: no neighbouring feet" if pair_ids.size() < 2 else "the body is not moving in this window"
	else:
		for i in moving:
			var dmin := INF
			for j in nl:
				for k in range(j + 1, nl):
					if legs[j].side == legs[k].side and legs[j].pair != legs[k].pair:
						dmin = minf(dmin, _hz((rec.foot[i][j] as Vector3) - (rec.foot[i][k] as Vector3)).length())
			spacing.append(dmin)
		m["foot_spacing_ratio"] = _r(_mean(spacing) / maxf(mean_len, 1e-3))
	# ---- body root: roll, bob, pitch (detrended over two strides so turns and ramps do not count as oscillation)
	var roll := []
	var pitch := []
	var bobh := []
	for i in n:
		var b: Basis = rec.root_basis[i]
		roll.append(rad_to_deg(asin(clampf(b.x.y, -1.0, 1.0))))      # +X is the left side: left up = positive
		pitch.append(rad_to_deg(asin(clampf(b.z.y, -1.0, 1.0))))
		var p: Vector3 = rec.root[i]
		bobh.append(p.y - float(ground.call(p.x, p.z)))
	var sl := []
	for i in moving:
		sl.append(rad_to_deg(atan(float(rec.grade[i]))))
	m["body_pitch_deg"] = _r(_mean(Array(Array(moving).map(func(i): return pitch[i]))), 2) if nm >= 10 else null
	m["ground_slope_deg"] = _r(_mean(sl), 2) if nm >= 10 else null
	if nm < 10:
		why["body_pitch_deg"] = "the body is not moving in this window"
		why["ground_slope_deg"] = why["body_pitch_deg"]
	# pitch_follow: on the frames where the ground is steep (grade over 0.1) body pitch / ground slope (1 = the body tilts with the slope)
	var steep := []
	for i in moving:
		if absf(float(rec.grade[i])) > 0.1:
			steep.append(i)
	if steep.size() >= 10:
		var sp_ := _mean(Array(steep.map(func(i): return float(pitch[i]) * signf(float(rec.grade[i])))))
		var gs_ := _mean(Array(steep.map(func(i): return rad_to_deg(atan(absf(float(rec.grade[i])))))))
		m["pitch_follow"] = _r(sp_ / gs_, 3)
		m["steep_slope_deg"] = _r(gs_, 2)
	else:
		m["pitch_follow"] = null
		m["steep_slope_deg"] = null
		why["pitch_follow"] = "fewer than 10 moving frames on a slope steeper than 0.1: nothing to follow"
		why["steep_slope_deg"] = why["pitch_follow"]
	if T < 4 or n < 4 * T:
		for k in ["torso_roll_deg", "roll_plant_lag", "torso_bob_cm", "torso_bob_frac"]:
			m[k] = null
			why[k] = "no stride cycle long enough in this window (needs 4 strides of frames)"
	else:
		var droll := _detrend(roll, 2 * T)
		var dbob := _detrend(bobh, 2 * T)
		var lo := T
		var hi := n - T
		var rr := droll.slice(lo, hi)
		var amp := (_pct(rr, 0.975) - _pct(rr, 0.025)) * 0.5
		m["torso_roll_deg"] = _r(amp, 2)
		# bob: mean peak-to-peak of the height above ground per stride window
		var pp := []
		var w := lo
		while w + T <= hi:
			var seg: Array = dbob.slice(w, w + T)
			pp.append(seg.max() - seg.min())
			w += T
		var bob := _mean(pp)
		m["torso_bob_cm"] = _r(bob * 100.0, 2)
		var sh := 0.0
		if not front_ids.is_empty():
			var c := 0
			for i in moving:
				for j in front_ids:
					sh += hgt.call(i, j)
					c += 1
			sh /= maxf(1.0, float(c))
		if sh > 1e-3:
			m["torso_bob_frac"] = _r(bob / sh, 4)
		else:
			m["torso_bob_frac"] = null
			why["torso_bob_frac"] = "no distinct front limb roots to take a shoulder height from"
		# roll phase: where the lean toward the planted side peaks, relative to the front foot's touchdown (fraction of cycle)
		var fr := front_ids if not front_ids.is_empty() else range(nl)
		if amp < 0.2:
			m["roll_plant_lag"] = null
			why["roll_plant_lag"] = "roll amplitude %.2f deg is under 0.2 deg: no roll to phase (rigid torso)" % amp
		else:
			var sx := 0.0
			var sy := 0.0
			var cntp := 0
			for j in fr:
				var td: Array = touch[j]
				for f0 in td:
					if f0 - T / 2 < lo or f0 + T / 2 >= hi:
						continue
					var best: float = -1e9
					var bi: int = f0
					for q in range(f0 - T / 2, f0 + T / 2):
						var lean: float = -float(droll[q]) * float(legs[j].side)     # roll toward this foot's side
						if lean > best:
							best = lean
							bi = q
					var ph := float(bi - f0) / float(T)
					sx += cos(TAU * ph)
					sy += sin(TAU * ph)
					cntp += 1
			if cntp == 0:
				m["roll_plant_lag"] = null
				why["roll_plant_lag"] = "no front touchdown with a full cycle around it"
			else:
				m["roll_plant_lag"] = _r(atan2(sy, sx) / TAU, 3)
	# ---- footfall diagram: two strides of the contact sequence, from the first moving stride start
	var ff_labels := []
	for j in nl:
		ff_labels.append("%s%d" % ["L" if legs[j].side > 0 else "R", int(legs[j].pair)])
	if T < 4 or n < 2 * T + 2:
		m["footfall"] = null
		why["footfall"] = "no stride period to cut two strides from"
	else:
		var f_start := 0
		for j in nl:
			if not (touch[j] as Array).is_empty():
				f_start = int((touch[j] as Array)[0])
				break
		var f_end := mini(n, f_start + 2 * T)
		var seqs := []
		for j in nl:
			var sstr := ""
			for i in range(f_start, f_end):
				sstr += "1" if rec.contact[i][j] == 1 else "0"
			seqs.append(sstr)
		m["footfall"] = {"labels": ff_labels, "dt": _r(dt, 5), "start_frame": f_start, "stride_frames": T, "contact": seqs}
	return {"metrics": m, "reasons": why}
