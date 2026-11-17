extends RefCounted
## The body as the action solver sees it (docs/godot/PLAN-actions.md 1.4.1): bone chains, limits, capabilities
## and capacities, built once from the real `Creature` rig.  Metres == rig units (loco unit 1).
##
## Chain order: `head_chain` base -> head (increasing bone index), `tail_chain` base -> tip (decreasing index).
## Bone deltas are local rotations about each bone's own Y (yaw), X (pitch) and Z (roll), applied after the
## rest rotation, exactly as loco_rig_adapter._bend_spine does.

var n := 0
var parent := PackedInt32Array()
var rest_local: Array = []      # Transform3D per bone (relative to its parent; roots relative to the body)
var rest_global: Array = []     # Transform3D per bone, rig space
var order: Array = []           # bone indices, parents first
var radius := PackedFloat32Array()
var root_bone := 0
var head_chain: Array = []
var tail_chain: Array = []
var head_limit := PackedFloat32Array()   # per chain joint, rad per axis
var tail_limit := PackedFloat32Array()
var head_arc := PackedFloat32Array()     # 0 base .. 1 tip
var tail_arc := PackedFloat32Array()
var head_range := 0.0
var tail_range := 0.0
var mouth_local := Vector3.ZERO          # in the frame of bone `mouth_bone`
var mouth_bone := 0
var height := 1.0
var length := 1.0
var com := Vector3.ZERO
var plan := &"quadruped"
var caps: Array = []
var lunge_cap := 0.3
var side_cap := 0.2
var belly_clear := 0.3
var reach_fwd := 0.5
var reach_back := 0.3
var leg_len := PackedFloat32Array()      # per described leg: upper + lower (the controller's, with its margin)
var neck_len := 0.0
var rest_low := PackedFloat32Array()     # per bone: clearance of the rest pose (y - radius, creature space)

static func from_rig(c, desc: Dictionary, morph = null) -> RefCounted:
	var m: RefCounted = load("res://actions/action_body_map.gd").new()
	m._build(c, desc, morph)
	return m

func _build(c, desc: Dictionary, morph) -> void:
	var sk: Skeleton3D = c.skeleton
	n = sk.get_bone_count()
	parent.resize(n)
	radius.resize(n)
	for b in n:
		parent[b] = sk.get_bone_parent(b)
		rest_local.append(sk.get_bone_rest(b))
		rest_global.append(c.bone_rest_global(b))
		radius[b] = float(c.rad[c.bone_ring[b]]) * float(desc.unit)
	root_bone = c.root_bone
	rest_low.resize(n)
	for b in n:
		rest_low[b] = (rest_global[b] as Transform3D).origin.y + float(c.ground_offset) - radius[b]
	_order()
	var legs: Array = c.legs
	var hip_bones := []
	for i in desc.leg_ids:
		hip_bones.append(int(legs[i].hip_bone))
	var front := root_bone
	var hind := root_bone
	for hb in hip_bones:
		front = maxi(front, hb)
		hind = mini(hind, hb)
	if hip_bones.is_empty():
		front = root_bone
		hind = root_bone
	# chains: strictly beyond the anchors
	for b in range(front + 1, n):
		head_chain.append(b)
	for b in range(hind - 1, -1, -1):
		tail_chain.append(b)
	head_limit = _limits(head_chain)
	tail_limit = _limits(tail_chain)
	head_arc = _arcs(head_chain)
	tail_arc = _arcs(tail_chain)
	var hs := 0.0
	for l in head_limit:
		hs += l
	var ts := 0.0
	for l in tail_limit:
		ts += l
	head_range = minf(hs, 1.4)
	tail_range = minf(ts, 2.2)
	var hi: Array = c.rest
	var rest_ground: float = c.ground_offset
	length = float(c.rest[c.rest.size() - 1].distance_to(c.rest[0])) * desc.unit
	var legged: bool = not desc.leg_ids.is_empty()
	var hip_y := 0.0
	for lg in desc.legs:
		hip_y = maxf(hip_y, lg.hip.y)
	if legged:
		height = hip_y
	else:
		var wr := 0.0
		for r in c.rad:
			wr = maxf(wr, r)
		height = maxf(wr * desc.unit, 0.2)
	for lg in desc.legs:
		leg_len.append(float(lg.upper) + float(lg.lower))
	# mouth: front-most point of the mouth part, else the tip joint plus its radius ahead
	mouth_bone = n - 1
	var mp: Vector3 = (rest_global[n - 1] as Transform3D).origin + (rest_global[n - 1] as Transform3D).basis.z * radius[n - 1]
	var best_t := -1.0
	for e in c.parts:
		if str(e.get("category", "")) == "mouths" and float(e.t) > best_t:
			best_t = float(e.t)
			var A: Dictionary = c.anchor(float(e.t), 0.0)
			mp = A.p + (A.t as Vector3).normalized() * float(e.size) * 0.55 * 0.5 + A.p * 0.0
	mouth_local = (rest_global[mouth_bone] as Transform3D).affine_inverse() * mp
	var lo := 1e9
	for b in n:
		lo = minf(lo, (rest_global[b] as Transform3D).origin.y + c.ground_offset - radius[b])
	belly_clear = maxf(0.05, height - 0.0 if legged else height)
	var lowest := 1e9
	for i in range(front, hind - 1, -1) if front >= hind else []:
		lowest = minf(lowest, (rest_global[i] as Transform3D).origin.y + c.ground_offset - radius[i])
	belly_clear = maxf(0.05, lowest) if lowest < 1e8 else maxf(0.05, height * 0.5)
	if morph != null:
		plan = morph.plan
		com = morph.com
		length = maxf(length, morph.body_length)
		height = maxf(height, morph.hip_height) if legged else height
	_caps(c, desc, morph, legged)
	var track := 0.5
	if morph != null:
		track = maxf(float(morph.track_width), 0.1)
	if not legged or caps.has("legless") or plan == &"monopod":
		lunge_cap = 0.12 * length
		side_cap = 0.10 * length
	elif caps.has("biped"):
		lunge_cap = 0.25 * height
		side_cap = 0.4 * track
	else:
		lunge_cap = 0.35 * height
		side_cap = 0.4 * track
	# neck: distance from the front anchor joint to the head joint, mouth ahead of the head
	var base_p: Vector3 = (rest_global[front] as Transform3D).origin
	var tip_p: Vector3 = mp
	neck_len = _chain_len([front] + head_chain) if head_chain.size() > 0 else 0.0
	reach_fwd = 0.45 * neck_len
	reach_back = 0.5 * reach_fwd
	if legged and neck_len > 1.2 and neck_len > 1.25 * height:
		caps.append("long_neck")

func _order() -> void:
	var done := {}
	var left := range(n)
	while not left.is_empty():
		var rest_left := []
		for b in left:
			if parent[b] < 0 or done.has(parent[b]):
				order.append(b)
				done[b] = true
			else:
				rest_left.append(b)
		left = rest_left

func _limits(chain: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in chain.size():
		var b: int = chain[i]
		var nxt: int = parent[b] if b < root_bone else (b + 1 if b + 1 < n else -1)
		var len := 0.1
		if nxt >= 0:
			len = ((rest_global[b] as Transform3D).origin - (rest_global[nxt] as Transform3D).origin).length()
		elif i > 0:
			len = ((rest_global[b] as Transform3D).origin - (rest_global[chain[i - 1]] as Transform3D).origin).length()
		out.append(clampf(0.5 * len / maxf(radius[b], 0.02), 0.06, 0.55))
	return out

func _arcs(chain: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in chain.size():
		out.append(float(i) / maxf(chain.size() - 1, 1))
	return out

func _caps(c, desc: Dictionary, morph, legged: bool) -> void:
	var has := func(cat: String) -> bool:
		for e in c.parts:
			if str(e.get("category", "")) == cat:
				return true
		return false
	var hooks := {}
	for e in c.parts:
		for k in e.hooks:
			hooks[k] = true
	if hooks.has("jaw"): caps.append("jaw")
	if hooks.has("pinch"): caps.append("pinch")
	if has.call("mouths"): caps.append("mouth")
	if tail_chain.size() > 0 and _chain_len(tail_chain) > 0.15 * length: caps.append("tail")
	if hooks.has("tail"): caps.append("tail_weapon")
	if hooks.has("arm"): caps.append("arms")
	if hooks.has("wing"): caps.append("wings")
	if hooks.has("lid"): caps.append("lids")
	if hooks.has("sacs"): caps.append("sacs")
	if hooks.has("sway"): caps.append("crest")
	for e in c.parts:
		var cat := str(e.get("category", ""))
		if cat == "weapons" and float(e.t) > 0.6: caps.append("horns"); break
	for e in c.parts:
		if str(e.get("category", "")) == "plates" or str(e.type).find("placa") >= 0 or str(e.type).find("plate") >= 0:
			caps.append("plates"); break
	if not legged: caps.append("legless")
	if morph != null:
		match morph.plan:
			&"upright_biped": caps.append("biped"); caps.append("upright")
			&"horizontal_biped": caps.append("biped")
			&"quadruped", &"light_quadruped": caps.append("quadruped")
			&"multi", &"hexapod": caps.append("multi")
		if morph.get("robustness") != null and float(morph.robustness) > 2.5: caps.append("graviportal")
	var nl: int = desc.leg_ids.size()
	if nl >= 2: caps.append("legs2")
	if nl >= 4: caps.append("legs4")
	if head_chain.size() < 2: caps.append("rigid_head")

func _chain_len(chain: Array) -> float:
	var s := 0.0
	for i in range(1, chain.size()):
		s += ((rest_global[chain[i]] as Transform3D).origin - (rest_global[chain[i - 1]] as Transform3D).origin).length()
	return s

func has_cap(k: String) -> bool:
	return caps.has(k)

## Forward kinematics. dy, dp, dr: per-bone local deltas (PackedFloat32Array of size n). -> Array[Transform3D] (rig space)
func fk(dy: PackedFloat32Array, dp: PackedFloat32Array, dr: PackedFloat32Array) -> Array:
	var g: Array = []
	g.resize(n)
	for b in order:
		var rl: Transform3D = rest_local[b]
		var q := rl.basis.get_rotation_quaternion() * Quaternion(Vector3.UP, dy[b]) * Quaternion(Vector3.RIGHT, dp[b]) * Quaternion(Vector3.BACK, dr[b])
		var loc := Transform3D(Basis(q), rl.origin)
		g[b] = loc if parent[b] < 0 else (g[parent[b]] as Transform3D) * loc
	return g

func mouth_point(g: Array) -> Vector3:
	return (g[mouth_bone] as Transform3D) * mouth_local
