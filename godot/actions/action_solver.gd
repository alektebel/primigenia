extends RefCounted
## Retargeter (docs/godot/PLAN-actions.md 1.4, Hecker et al. 2008 adapted): turns semantic channel values into
## a root delta (guarded so planted feet stay reachable) and per-bone rotation deltas for the head and tail
## chains of THIS body.  One instance per actor, it keeps the warm start of the reach solve.

const UP := Vector3.UP

var map
var go := 0.0                       # ground_offset of the rig (skeleton space -> creature local)
var k_prev := 1.0                   # reach guard, last frame
var extra_lunge := 0.0              # metres the body adds when the neck cannot reach
var rdy := PackedFloat32Array()     # reach (CCD) deltas, warm start
var rdp := PackedFloat32Array()
var debug := {}

func setup(body_map, ground_offset: float) -> void:
	map = body_map
	go = ground_offset
	rdy.resize(map.n)
	rdp.resize(map.n)

static func _quat_yaw(pose_root: Transform3D) -> float:
	return atan2(pose_root.basis.z.x, pose_root.basis.z.z)

func _root_for(k: float, R0: Transform3D, piv: Vector3, rot_q: Quaternion, trans_b: Vector3, B: Basis, lift: float) -> Transform3D:
	var rot := Basis(Quaternion.IDENTITY.slerp(rot_q, k))
	var r := R0 * Transform3D(Basis(), piv) * Transform3D(rot, Vector3.ZERO) * Transform3D(Basis(), -piv)
	r.origin += B * (trans_b * k) + UP * lift * k
	return r

## ch: channel values (post spring). goals: {name: world Vector3 or null}; moving 0..1 (plant actions scale translations).
## Writes pose.root / hips / com and returns the act dictionary (bone deltas + part values come from the layer).
func apply(pose: Dictionary, ch: Dictionary, goals: Dictionary, dt: float, moving: float, translate_scale: float) -> Dictionary:
	var R0: Transform3D = pose.root
	var piv := Vector3(0.0, map.com.y, map.com.z)
	var B := Basis(UP, _quat_yaw(R0))
	var ts := (1.0 - moving) * translate_scale
	var lift_m: float = ch["root.lift"] * map.height
	lift_m = maxf(lift_m, -(map.belly_clear - 0.03))
	var rq := Quaternion(UP, ch["root.yaw"]) * Quaternion(Vector3.RIGHT, -ch["root.pitch"]) * Quaternion(Vector3.BACK, ch["root.roll"])
	var lunge_m: float = ch["root.lunge"] * map.lunge_cap + extra_lunge
	var trans := Vector3(ch["root.side"] * map.side_cap * ts, 0.0, lunge_m * ts)
	lift_m *= maxf(ts, 0.35)
	var k := _guard(pose, R0, piv, rq, trans, B, lift_m, dt)
	var R1 := _root_for(k, R0, piv, rq, trans, B, lift_m)
	var Rd := R1 * R0.affine_inverse()
	var hips: PackedVector3Array = pose.hips
	for i in hips.size():
		hips[i] = Rd * hips[i]
	pose.hips = hips
	pose.com = Rd * (pose.com as Vector3)
	pose.root = R1
	debug["k"] = k
	var n: int = map.n
	var dy := PackedFloat32Array(); dy.resize(n)
	var dp := PackedFloat32Array(); dp.resize(n)
	var dr := PackedFloat32Array(); dr.resize(n)
	_posture(ch, dy, dp, dr)
	var inv := R1.affine_inverse()
	var to_local := func(w) -> Variant:
		return null if w == null else (inv * (w as Vector3)) - Vector3(0.0, go, 0.0)
	var aim_goal = to_local.call(goals.get("head.aim"))
	if aim_goal != null and ch["head.aim"] > 0.01:
		_aim(ch["head.aim"], aim_goal, dy, dp)
	var reach_goal = to_local.call(goals.get("head.reach"))
	_reach(float(ch["head.reach"]), reach_goal, dy, dp, dr, dt)
	_tail(ch, dy, dp)
	_ground_clear(dy, dp)
	return {"bone_dy": dy, "bone_dp": dp, "bone_dr": dr, "root_delta": Rd, "k": k}

func _guard(pose: Dictionary, R0: Transform3D, piv: Vector3, rq: Quaternion, trans: Vector3, B: Basis, lift: float, dt: float) -> float:
	var hips: PackedVector3Array = pose.hips
	var feet: PackedVector3Array = pose.feet
	var contact: Array = pose.contact
	var inv0 := R0.affine_inverse()
	var lim := PackedFloat32Array()
	var any := false
	for j in hips.size():
		var L: float = map.leg_len[j] if j < map.leg_len.size() else 0.0
		lim.append(maxf(0.985 * L, hips[j].distance_to(feet[j]) + 1e-3))
		if contact[j]:
			any = true
	var ok := func(k: float) -> bool:
		if not any:
			return true
		var r := _root_for(k, R0, piv, rq, trans, B, lift)
		var d := r * inv0
		for j in hips.size():
			if contact[j] and (d * hips[j]).distance_to(feet[j]) > lim[j]:
				return false
		return true
	var k_found := 1.0
	if not ok.call(1.0):
		var lo := 0.0
		var hi := 1.0
		for _i in 6:
			var mid := 0.5 * (lo + hi)
			if ok.call(mid):
				lo = mid
			else:
				hi = mid
		k_found = lo
	var k_out := k_found if k_found < k_prev else minf(k_found, k_prev + dt / 0.1)
	k_prev = k_out
	return k_out

func _posture(ch: Dictionary, dy: PackedFloat32Array, dp: PackedFloat32Array, dr: PackedFloat32Array) -> void:
	var hc: Array = map.head_chain
	var hs := 0.0
	for l in map.head_limit:
		hs += l
	var g := minf(1.0, 1.4 / maxf(hs, 1e-3))
	for i in hc.size():
		var b: int = hc[i]
		var lim: float = map.head_limit[i]
		dp[b] += -(ch["head.pitch"] * lim * g + ch["neck.coil"] * 0.8 * lim * cos(PI * map.head_arc[i]))
		dy[b] += ch["head.yaw"] * lim * g
		if i >= hc.size() - 2:
			dr[b] += ch["head.roll"] * 0.5 * lim

func _tail(ch: Dictionary, dy: PackedFloat32Array, dp: PackedFloat32Array) -> void:
	var tc: Array = map.tail_chain
	var ts := 0.0
	for l in map.tail_limit:
		ts += l
	var g := minf(1.0, 2.2 / maxf(ts, 1e-3))
	for i in tc.size():
		var b: int = tc[i]
		var lim: float = map.tail_limit[i]
		dy[b] += -(ch["tail.yaw"] * lim * g + ch["tail.curl"] * lim)
		dp[b] += ch["tail.pitch"] * lim * g

func _aim(w: float, goal: Vector3, dy: PackedFloat32Array, dp: PackedFloat32Array) -> void:
	var hc: Array = map.head_chain
	if hc.is_empty():
		return
	var S := 0.0
	for i in hc.size():
		if map.head_arc[i] >= 0.4:
			S += map.head_limit[i]
	if S <= 0.0:
		return
	for _pass in 2:
		var g: Array = map.fk(dy, dp, _zeros())
		var last: int = hc[hc.size() - 1]
		var f: Vector3 = (g[last] as Transform3D).basis.z
		var d: Vector3 = (goal - (g[last] as Transform3D).origin).normalized()
		var ey := atan2(d.x, d.z) - atan2(f.x, f.z)
		ey = wrapf(ey, -PI, PI)
		var ep := asin(clampf(d.y, -1.0, 1.0)) - asin(clampf(f.y, -1.0, 1.0))
		for i in hc.size():
			if map.head_arc[i] >= 0.4:
				var share: float = map.head_limit[i] / S
				dy[hc[i]] += w * ey * share * 0.6
				dp[hc[i]] -= w * ep * share * 0.6

var _zero: PackedFloat32Array
func _zeros() -> PackedFloat32Array:
	if _zero.size() != map.n:
		_zero = PackedFloat32Array()
		_zero.resize(map.n)
	return _zero

func _reach(v: float, goal, dy: PackedFloat32Array, dp: PackedFloat32Array, dr: PackedFloat32Array, dt: float) -> void:
	var hc: Array = map.head_chain
	var n: int = map.n
	if absf(v) < 0.005:
		var f := exp(-dt / 0.06)
		for b in hc:
			rdy[b] *= f
			rdp[b] *= f
			dy[b] += rdy[b]
			dp[b] += rdp[b]
		extra_lunge = lerpf(extra_lunge, 0.0, 1.0 - exp(-dt / 0.08))
		return
	# mouth with posture and aim, before the reach
	var g0: Array = map.fk(dy, dp, dr)
	var M0: Vector3 = map.mouth_point(g0)
	var nrm := Vector3(0, 0, 1)
	var dist := 0.0
	if goal != null:
		nrm = ((goal as Vector3) - M0)
		dist = nrm.length()
		nrm = nrm.normalized() if dist > 1e-4 else Vector3(0, 0, 1)
	var P: Vector3
	var t_want := 0.0
	if v >= 0.0:
		var min_l: float = 0.15 * map.reach_fwd
		t_want = v * clampf(dist if goal != null else map.reach_fwd, min_l, map.reach_fwd + map.lunge_cap)
		P = M0 + nrm * t_want
	else:
		var nh := Vector3(nrm.x, 0, nrm.z)
		nh = nh.normalized() if nh.length() > 1e-3 else Vector3(0, 0, 1)
		P = M0 - nh * absf(v) * map.reach_back + UP * 0.15 * absf(v) * map.reach_back
	var maxlim := 0.0
	for l in map.head_limit:
		maxlim = maxf(maxlim, l)
	var base_dy := dy.duplicate()
	var base_dp := dp.duplicate()
	for b in hc:
		dy[b] += rdy[b]
		dp[b] += rdp[b]
	for _it in 3:
		for i in range(hc.size() - 1, -1, -1):
			var b: int = hc[i]
			var lim: float = map.head_limit[i]
			var wgt := 0.6 * lim / maxlim
			for axis in 2:
				var g: Array = map.fk(dy, dp, dr)
				var mouth: Vector3 = map.mouth_point(g)
				var par: int = map.parent[b]
				var pb: Basis = ((g[par] as Transform3D).basis if par >= 0 else Basis()) * (map.rest_local[b] as Transform3D).basis
				var ax: Vector3 = pb.y if axis == 1 else (pb * Basis(UP, dy[b])).x
				var o: Vector3 = (g[b] as Transform3D).origin
				var v1 := (mouth - o)
				var v2 := (P - o)
				v1 -= ax * v1.dot(ax)
				v2 -= ax * v2.dot(ax)
				if v1.length() < 1e-4 or v2.length() < 1e-4:
					continue
				var ang := atan2(ax.dot(v1.cross(v2)), v1.dot(v2)) * wgt
				if axis == 1:
					dy[b] += ang
					dy[b] = clampf(dy[b], -1.15 * lim, 1.15 * lim)
				else:
					dp[b] += ang
					dp[b] = clampf(dp[b], -1.15 * lim, 1.15 * lim)
	for b in hc:
		rdy[b] = dy[b] - base_dy[b]
		rdp[b] = dp[b] - base_dp[b]
	var Mf: Vector3 = map.mouth_point(map.fk(dy, dp, dr))
	var got := (Mf - M0).dot(nrm)
	if v >= 0.0:
		var short := maxf(0.0, t_want - got)
		var target_extra := minf(short * 0.9, map.lunge_cap)
		extra_lunge = lerpf(extra_lunge, target_extra, 1.0 - exp(-dt / 0.04))
	else:
		extra_lunge = lerpf(extra_lunge, 0.0, 1.0 - exp(-dt / 0.08))
	debug["mouth"] = Mf
	debug["reach_got"] = got
	debug["reach_want"] = t_want

func _ground_clear(dy: PackedFloat32Array, dp: PackedFloat32Array) -> void:
	for _pass in 2:
		var g: Array = map.fk(dy, dp, _zeros())
		for chain_kind in 2:
			var chain: Array = map.head_chain if chain_kind == 0 else map.tail_chain
			for i in range(1, chain.size()):
				var b: int = chain[i]
				var prev: int = chain[i - 1]
				var low: float = (g[b] as Transform3D).origin.y + go - map.radius[b]
				if low < 0.01:
					var seg: float = ((g[b] as Transform3D).origin - (g[prev] as Transform3D).origin).length()
					var a := asin(clampf((0.01 - low) / maxf(seg, 0.05), 0.0, 0.5))
					dp[prev] += -a if chain_kind == 0 else a

