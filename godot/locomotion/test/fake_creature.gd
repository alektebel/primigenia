extends Node3D
## Stand-in for the real `Creature` (branch g-creature) with the same fields
## the adapter reads, built from a test body (metres) at a given scale.
## Rig units = metres / unit; the spine has 72 rings, tail first.

class FakeLeg:
	extends RefCounted
	var type := "pata"
	var side := 1
	var hip := Vector3.ZERO
	var upper_length := 1.0
	var lower_length := 1.0
	var width := 0.2
	var home := Vector3.ZERO
	var hang := 0.0
	var hip_bone := 0
	var foot_target := Vector3.ZERO
	var foot_yaw := 0.0
	var foot_pitch := 0.0
	var part := {"t": 0.5}
	var solved := 0
	func hip_local() -> Vector3:
		return hip
	func solve() -> void:
		solved += 1

class FakeMaker:
	extends RefCounted
	var foot := "garra"
	func meta(_type: String) -> Dictionary:
		return {"foot": foot}

class FakeSkeleton:
	extends RefCounted
	var rest: Array = []
	var parent: Array = []
	var pose: Array = []
	func get_bone_count() -> int:
		return rest.size()
	func get_bone_parent(b: int) -> int:
		return parent[b]
	func get_bone_rest(b: int) -> Transform3D:
		return rest[b]
	func set_bone_pose_rotation(b: int, q: Quaternion) -> void:
		pose[b] = q

var rest: Array = []
var rad := PackedFloat32Array()
var ground_offset := 0.03
var tail_bones := PackedInt32Array()
var neck_bones := PackedInt32Array()
var skeleton := FakeSkeleton.new()
var parts: Array = []
var legs: Array = []
var maker := FakeMaker.new()
var _spine_m: Array = []
var _unit := 1.0
var spine_reset := 0

func build(body: Dictionary, unit: float, foot_kind := "garra") -> void:
	_unit = unit
	maker.foot = foot_kind
	var sp: Array = body.spine
	var n := 72
	for i in range(n):
		var f := float(i) / (n - 1) * (sp.size() - 1)
		var a := int(min(floor(f), sp.size() - 2))
		var u := f - a
		var p: Vector3 = (sp[a].pos as Vector3).lerp(sp[a + 1].pos, u)
		rest.append(p / unit - Vector3(0.0, ground_offset, 0.0))
		rad.append(lerpf(sp[a].radius, sp[a + 1].radius, u) / unit)
	# bones: 8 along the spine, root in the middle, chains outward
	var nbones := 8
	for b in range(nbones):
		var idx := int(float(b) / (nbones - 1) * (n - 1))
		skeleton.rest.append(Transform3D(Basis(), rest[idx]))
		skeleton.parent.append(-1 if b == nbones / 2 else (b + 1 if b < nbones / 2 else b - 1))
		skeleton.pose.append(Quaternion())
	for b in range(nbones):
		var t := float(b) / (nbones - 1)
		if t < 0.35:
			tail_bones.append(b)
		elif t >= 0.68 and b < nbones - 1:
			neck_bones.append(b)
	for l in body.legs:
		var fl := FakeLeg.new()
		fl.side = 1 if l.hip.x >= 0.0 else -1
		fl.hip = l.hip / unit
		fl.upper_length = l.upper / unit
		fl.lower_length = l.lower / unit
		fl.width = 2.0 * l.get("radius", 0.05) / unit
		fl.home = l.get("foot_rest", Vector3(l.hip.x, 0.0, l.hip.z)) / unit
		fl.home.y = 0.0
		legs.append(fl)
		parts.append({"type": "pata", "category": "legs", "side": fl.side, "t": 0.5, "ang": 2.0, "size": 1.0})
	for p in body.get("parts", []):
		parts.append({"type": "cuerno", "category": "horns", "side": 1, "t": 0.9, "ang": 0.3, "size": 1.0, "pos": p.pos})

func anchor(_t: float, _ang: float) -> Dictionary:
	return {"p": Vector3(0.0, 0.5, 2.0) / _unit - Vector3(0.0, ground_offset, 0.0)}

func reset_spine_pose() -> void:
	spine_reset += 1

func bone_rest_global(b: int) -> Transform3D:
	return skeleton.rest[b]

func solve_legs() -> void:
	for l in legs:
		l.solve()
