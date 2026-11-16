extends Node3D
# M0 stand-in for the g-creature module: a swept tube through the genome spine, two eyes and
# straight legs that swing while walking. Origin on the ground, +Z forward, +Y up, metres.
# Deliberately simple: g-creature owns the real rig; do not extend this.

const SIDES := 12
const SAMPLES := 6
const FOOT_RADIUS := 0.25

var genome: Dictionary = {}
var aabb := AABB()
var _legs: Array = []         # {pivot: Node3D, base: Vector3}
var _phase := 0.0
var _spine: Array = []        # Vector3 points (x = 0) with radius in w via _radii
var _radii: Array = []

static func parse_color(text, fallback: Color) -> Color:
	if typeof(text) == TYPE_STRING and Color.html_is_valid(text):
		return Color.html(text)
	return fallback

# Catmull-Rom between p1 and p2.
static func _cr(p0: float, p1: float, p2: float, p3: float, t: float) -> float:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

func build(g: Dictionary) -> void:
	genome = g
	var nodes: Array = g.nodes
	var count := nodes.size()
	_spine = []
	_radii = []
	for i in count - 1:
		var a: Dictionary = nodes[maxi(i - 1, 0)]
		var b: Dictionary = nodes[i]
		var c: Dictionary = nodes[i + 1]
		var d: Dictionary = nodes[mini(i + 2, count - 1)]
		for s in SAMPLES:
			var t := float(s) / SAMPLES
			_spine.append(Vector3(0.0, _cr(a.y, b.y, c.y, d.y, t), _cr(a.z, b.z, c.z, d.z, t)))
			_radii.append(maxf(0.02, _cr(a.r, b.r, c.r, d.r, t)))
	var last: Dictionary = nodes[count - 1]
	_spine.append(Vector3(0.0, last.y, last.z))
	_radii.append(maxf(0.02, last.r))
	var skin := Color(0.6, 0.35, 0.3)
	if typeof(g.get("skin")) == TYPE_DICTIONARY:
		skin = parse_color(g.skin.get("cA"), skin)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin
	mat.roughness = 0.8
	add_child(_tube(mat))
	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.05, 0.04, 0.05)
	eye_mat.roughness = 0.3
	for part in g.get("parts", []):
		match part.get("type", ""):
			"ojo":
				_add_eye(part, eye_mat)
			"pata", "zanca":
				_add_leg(part, mat)
	aabb = _compute_aabb()

func _anchor(t: float) -> Dictionary:
	var f := clampf(t, 0.0, 1.0) * (_spine.size() - 1)
	var i := mini(int(f), _spine.size() - 2)
	var u := f - i
	return {"pos": (_spine[i] as Vector3).lerp(_spine[i + 1], u), "r": lerpf(_radii[i], _radii[i + 1], u)}

func _tube(mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: Array = []
	for i in _spine.size():
		var p: Vector3 = _spine[i]
		var r: float = _radii[i]
		var row := []
		for k in SIDES:
			var a := TAU * k / SIDES
			row.append(Vector3(sin(a) * r, p.y + cos(a) * r, p.z))
		ring.append(row)
	for i in _spine.size() - 1:
		for k in SIDES:
			var k2 := (k + 1) % SIDES
			var a: Vector3 = ring[i][k]
			var b: Vector3 = ring[i][k2]
			var c: Vector3 = ring[i + 1][k2]
			var d: Vector3 = ring[i + 1][k]
			for v in [a, c, b, a, d, c]:
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi

func _add_eye(part: Dictionary, mat: Material) -> void:
	var anchor := _anchor(part.get("t", 0.9))
	var p: Vector3 = anchor.pos
	var r: float = anchor.r
	var ang: float = part.get("ang", 0.95)
	var size: float = part.get("size", 1.0)
	for sgn in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.09 * size
		sp.height = 0.18 * size
		eye.mesh = sp
		eye.material_override = mat
		eye.position = Vector3(sgn * sin(ang) * r, p.y + cos(ang) * r, p.z)
		add_child(eye)

func _add_leg(part: Dictionary, mat: Material) -> void:
	var anchor := _anchor(part.get("t", 0.5))
	var p: Vector3 = anchor.pos
	var r: float = anchor.r
	var ang: float = part.get("ang", 2.1)
	var w: float = part.get("w", 0.2)
	for sgn in [-1.0, 1.0]:
		var base := Vector3(sgn * sin(ang) * r, p.y + cos(ang) * r, p.z)
		var length := maxf(base.y, 0.2)
		var pivot := Node3D.new()
		pivot.position = base
		var cap := MeshInstance3D.new()
		var cm := CapsuleMesh.new()
		cm.radius = maxf(0.05, w * 0.5)
		cm.height = maxf(length, cm.radius * 2.0 + 0.01)
		cap.mesh = cm
		cap.material_override = mat
		cap.position = Vector3(0, -length * 0.5, 0)
		pivot.add_child(cap)
		add_child(pivot)
		_legs.append({"pivot": pivot, "base": base, "length": length, "side": sgn})

func _compute_aabb() -> AABB:
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for i in _spine.size():
		var p: Vector3 = _spine[i]
		var r: float = _radii[i]
		lo = lo.min(Vector3(-r, p.y - r, p.z))
		hi = hi.max(Vector3(r, p.y + r, p.z))
	for leg in _legs:
		var b: Vector3 = leg.base
		lo = lo.min(Vector3(b.x - 0.05, b.y - leg.length, b.z))
		hi = hi.max(Vector3(b.x + 0.05, b.y, b.z))
	return AABB(lo, hi - lo)

func rest_aabb() -> AABB:
	return aabb

# Feet in local space at rest (for occluders).
func foot_points() -> Array:
	var out := []
	for leg in _legs:
		var b: Vector3 = leg.base
		out.append(Vector3(b.x, 0.0, b.z))
	return out

func spine_points(count: int) -> Array:
	var out := []
	for k in count:
		var i := int(round(float(k) / maxf(count - 1, 1) * (_spine.size() - 1)))
		out.append({"pos": _spine[i], "r": _radii[i]})
	return out

# Swing legs in opposite phase while moving; speed in m/s.
func animate(dt: float, speed: float) -> void:
	_phase += dt * speed * 2.2
	var amp := clampf(speed / 4.0, 0.0, 1.0) * 0.55
	for i in _legs.size():
		var leg: Dictionary = _legs[i]
		var offset := PI * (0.0 if (i % 2 == 0) else 1.0) + (0.0 if leg.side < 0 else PI * 0.5)
		(leg.pivot as Node3D).rotation.x = sin(_phase + offset) * amp
