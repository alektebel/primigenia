extends Node3D
## Minimal test rig: capsules for the spine, two-bone legs with analytic IK.
## It implements the two calls the real creature rig must provide:
##   loco_describe() -> Dictionary   (body description in rest space)
##   loco_apply(pose: Dictionary)    (pose from LocoController)

const IK = preload("../loco_ik.gd")
const Morph = preload("../loco_morphology.gd")

var desc := {}
var morph
var wave_fn: Callable = Callable()   # func(u) -> lateral offset, for legless bodies
var _segs: Array = []
var _joints: Array = []
var _legs: Array = []
var _com: MeshInstance3D
var _mat_body: StandardMaterial3D
var _mat_down: StandardMaterial3D
var _mat_up: StandardMaterial3D

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	return m

func build(body: Dictionary) -> void:
	desc = body
	morph = Morph.analyse(body)
	top_level = true
	_mat_body = _mat(Color(0.86, 0.62, 0.36))
	var mat_leg_l := _mat(Color(0.62, 0.36, 0.2))
	var mat_leg_r := _mat(Color(0.42, 0.25, 0.16))
	_mat_down = _mat(Color(0.95, 0.3, 0.15))
	_mat_up = _mat(Color(0.85, 0.85, 0.9))
	var spine: Array = desc.spine
	for i in range(spine.size()):
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = spine[i].radius
		sm.height = spine[i].radius * 2.0
		sm.radial_segments = 16
		sm.rings = 8
		s.mesh = sm
		s.material_override = _mat(Color(0.95, 0.75, 0.45)) if spine[i].get("region", "") == "head" else _mat_body
		add_child(s)
		_joints.append(s)
		if i + 1 < spine.size():
			_segs.append(_cyl(spine[i + 1].radius, spine[i].radius, _mat_body))
	for l in desc.legs:
		var mat: StandardMaterial3D = mat_leg_l if l.hip.x >= 0.0 else mat_leg_r
		var r: float = l.get("radius", 0.05)
		var foot := MeshInstance3D.new()
		var fm := SphereMesh.new()
		var fs: float = l.get("foot_size", r * 1.5)
		fm.radius = fs * 0.5
		fm.height = fs * 0.6
		fm.radial_segments = 12
		fm.rings = 6
		foot.mesh = fm
		add_child(foot)
		var knee := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = r * 0.85
		km.height = r * 1.7
		km.radial_segments = 10
		km.rings = 5
		knee.mesh = km
		knee.material_override = mat
		add_child(knee)
		_legs.append({"up": _cyl(r * 0.8, r, mat), "lo": _cyl(r * 0.55, r * 0.8, mat), "foot": foot, "knee": knee})
	_com = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.035 * max(morph.hip_height, 0.2)
	cm.height = cm.radius * 2.0
	_com.mesh = cm
	var mc := _mat(Color(0.1, 0.5, 1.0))
	mc.no_depth_test = true
	mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_com.material_override = mc
	add_child(_com)

func _cyl(top: float, bottom: float, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = 1.0
	c.radial_segments = 14
	c.rings = 1
	n.mesh = c
	n.material_override = mat
	add_child(n)
	return n

static func _between(n: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var l := d.length()
	if l < 1e-5:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD)
	if x.length() < 1e-3:
		x = y.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(y)
	n.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)

func loco_describe() -> Dictionary:
	return desc

func loco_apply(pose: Dictionary) -> void:
	var root: Transform3D = pose.root
	var spine: Array = desc.spine
	var n := spine.size()
	# local spine with neck and tail deflected progressively from their bases
	var pts: Array = []
	var first_trunk := 0
	var last_trunk := n - 1
	for i in range(n):
		if morph.spine_regions[i] == "tail":
			first_trunk = i + 1
	for i in range(n - 1, -1, -1):
		if morph.spine_regions[i] == "neck" or morph.spine_regions[i] == "head":
			last_trunk = i - 1
	first_trunk = clamp(first_trunk, 0, n - 1)
	last_trunk = clamp(last_trunk, 0, n - 1)
	for i in range(n):
		var p: Vector3 = spine[i].pos
		var bend: Dictionary = pose.spine_at.call(p.z)
		if i >= first_trunk and i <= last_trunk:
			p.x += bend.x
		if i < first_trunk:
			var base: Vector3 = spine[first_trunk].pos
			var base_bent: Vector3 = base + Vector3(pose.spine_at.call(base.z).x, 0.0, 0.0)
			var k := float(first_trunk - i) / first_trunk
			var rot := Basis(Vector3.UP, pose.tail.yaw * k) * Basis(Vector3.RIGHT, pose.tail.pitch * k)
			p = base_bent + rot * (p - base)
		elif i > last_trunk:
			var base2: Vector3 = spine[last_trunk].pos
			var base2_bent: Vector3 = base2 + Vector3(pose.spine_at.call(base2.z).x, 0.0, 0.0)
			var k2 := float(i - last_trunk) / (n - 1 - last_trunk)
			var rot2 := Basis(Vector3.UP, pose.neck.yaw * k2) * Basis(Vector3.RIGHT, -pose.neck.pitch * k2)
			p = base2_bent + rot2 * (p - base2)
		if wave_fn.is_valid():
			p.x += wave_fn.call(morph.spine_u[i])
		pts.append(root * p)
	for i in range(n):
		_joints[i].global_position = pts[i]
		if i + 1 < n:
			_between(_segs[i], pts[i], pts[i + 1])
	for i in range(_legs.size()):
		var m: Dictionary = morph.legs[i]
		var hip: Vector3 = pose.hips[i]
		# knees forward for hind legs and bipeds, elbows back for fore legs, up for sprawled legs
		var pole: Vector3 = root.basis.z
		if morph.plan == &"multi":
			pole = root.basis.y + root.basis.x * 0.5 * m.side
		elif morph.plan == &"quadruped" and m.station > 0:
			pole = -root.basis.z
		var sol := IK.two_bone(hip, pose.feet[i], m.upper, m.lower, pole)
		var g: Dictionary = _legs[i]
		_between(g.up, hip, sol.knee)
		_between(g.lo, sol.knee, sol.foot)
		g.knee.global_position = sol.knee
		g.foot.global_position = sol.foot
		g.foot.material_override = _mat_down if pose.contact[i] else _mat_up
	_com.global_position = pose.com
