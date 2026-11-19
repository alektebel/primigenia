extends RefCounted
# One baked surface per reusable crown/tuft/prop. Coordinates are in species-height
# units until baked; instance transforms supply the final height in metres.
const SURFACE := preload("res://game/shaders/flora.gdshader")
var rng := RandomNumberGenerator.new()
var st := SurfaceTool.new()
var tint := Color.WHITE
var bark := Color("615349").srgb_to_linear()
var width := 0.5
var detail := true
var fruit := Color.TRANSPARENT
var leaflet_pairs := 6

func begin(shape_seed: int) -> void:
	rng.seed = shape_seed
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color, style := 0, bend := 0.0, uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for i in 3:
		var p: Vector3 = [a, b, c][i]
		st.set_color(colour)
		st.set_normal(normal)
		st.set_uv(uvs[i])
		st.set_uv2(Vector2(style, bend * maxf(p.y, 0.0)))
		st.add_vertex(p)

func rod(a: Vector3, b: Vector3, base: float, tip: float, colour: Color, sides := 5) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.FORWARD)
	if right.length_squared() < 0.01:
		right = axis.cross(Vector3.RIGHT)
	right = right.normalized()
	for i in sides:
		var u := right.rotated(axis, TAU * i / sides)
		var v := right.rotated(axis, TAU * (i + 1) / sides)
		triangle(a + u * base, b + v * tip, a + v * base, colour)
		triangle(a + u * base, b + u * tip, b + v * tip, colour)

func blade(base: Vector3, end: Vector3, half_width: float, sag: float, style: int, colour: Color) -> void:
	var side := (end - base).cross(Vector3.UP).normalized() * half_width
	var mid := base.lerp(end, 0.5) + Vector3.UP * sag
	var prev := base
	for j in 2:
		var next := mid if j == 0 else end
		var v := float(j) * 0.5
		triangle(prev - side, prev + side, next + side, colour, style, 0.65, [Vector2(0, v), Vector2(1, v), Vector2(1, v + 0.5)])
		triangle(prev - side, next + side, next - side, colour, style, 0.65, [Vector2(0, v), Vector2(1, v + 0.5), Vector2(0, v + 0.5)])
		prev = next

func radial(angle: float) -> Vector3:
	return Vector3(cos(angle), 0, sin(angle))

func crown(p: Vector3, extent: float) -> void:
	for j in (12 if detail else 5):
		var dir := radial(rng.randf() * TAU)
		blade(p, p + (dir + Vector3.UP * rng.randf_range(-0.4, 0.55)) * extent, extent * 0.46, extent * 0.22, leaflet_pairs, tint.lightened(rng.randf() * 0.038))

	if detail and fruit.a > 0 and rng.randf() < 0.4:
		lump(p - Vector3.UP * 0.01, Vector3(0.009, 0.014, 0.009), fruit, 6)

func branch(a: Vector3, dir: Vector3, length_m: float, radius: float, depth: int, angle: float) -> void:
	var b := a + dir * length_m
	rod(a, b, radius, radius * 0.62, bark, 5 if detail else 3)
	if depth <= 0:
		crown(b, width * 0.37)
		return
	var turn := rng.randf() * TAU
	for i in 2:
		var lateral := radial(turn + PI * i)
		branch(b, (dir * 0.54 + Vector3.UP * cos(angle) * 0.45 + lateral * sin(angle)).normalized(), length_m * 0.67, radius * 0.6, depth - 1, angle)

func ribbon(angle: float) -> void:
	var root := radial(angle) * 0.03
	var fork := radial(angle) * 0.35 + Vector3.UP * 0.37
	blade(root, fork, 0.036, 0.08, 0, tint)
	for side in [-1, 1]:
		var tip := radial(angle + side * 0.34) * rng.randf_range(0.60, 0.95) + Vector3.UP * rng.randf_range(0.59, 0.99)
		blade(fork, tip, 0.065, 0.16, 1, tint)

func woody(r: Dictionary) -> void:
	var tree: bool = r.form == "tree"
	var h := 0.52 if tree else 0.15
	var top := Vector3(0.014, h, -0.022)
	rod(Vector3.DOWN * 0.03, top, 0.047 if tree else 0.065, 0.022, bark, 8)
	if tree:
		for j in 7:
			var ray := radial(j * TAU / 7 + rng.randf() * 0.3)
			triangle(ray * 0.17, Vector3.UP * 0.17, ray * 0.035 + ray.cross(Vector3.UP) * 0.026, bark)
	for j in (8 if detail else 5):
		var dir := radial(j * 2.4 + rng.randf() * 0.5) * width * 2 + Vector3.UP * (0.48 + j * 0.09)
		branch(top * (0.55 + j * 0.06), dir.normalized(), 0.32 if tree else 0.54, 0.021, clampi(int(r.levels) - 2, 1, 2) if detail else 0, deg_to_rad(r.angle))

# Irregular layered rings give rock fracture planes, fungal cushions and lichen islands.
func lump(center: Vector3, radii: Vector3, colour: Color, sides: int) -> void:
	var lower := []
	var upper := []
	for j in sides:
		var ray := radial(TAU * j / sides) * rng.randf_range(0.82, 1.15)
		lower.append(center + (ray + Vector3.DOWN * 0.08) * radii)
		upper.append(center + (ray * rng.randf_range(0.56, 0.85) + Vector3.UP * rng.randf_range(0.48, 0.8)) * radii)
	for j in sides:
		var k := (j + 1) % sides
		triangle(lower[j], upper[k], upper[j], colour)
		triangle(lower[j], lower[k], upper[k], colour)
		triangle(upper[j], upper[k], center + Vector3.UP * radii.y, colour)

func plant(r: Dictionary, shape_seed: int, near_mesh: bool) -> ArrayMesh:
	begin(shape_seed)
	detail = near_mesh
	tint = Color(r.colour).srgb_to_linear()
	width = r.spread
	fruit = Color(r.fruit).srgb_to_linear() if r.has("fruit") else Color.TRANSPARENT
	leaflet_pairs = clampi(roundi(width * 0.37 * float(r.height[1]) / maxf(0.01, float(r.leaf_cm) / 100.0)), 3, 24) if detail else 4
	match str(r.form):
		"tree","shrub":
			woody(r)
		"algae":
			for j in (7 if detail else 4):
				ribbon(j * 2.4)
		"vine":
			var prev := Vector3.ZERO
			for j in range(1, 15):
				var pos := radial(j * 0.43) * 0.042 + Vector3.UP * j / 14.0
				rod(prev, pos, 0.004, 0.004, bark, 4)
				var end := pos + radial(j) * 0.12 + Vector3.DOWN * 0.035
				blade(pos, end, 0.025, 0.03, 5, tint)
				if r.has("veins"):
					blade(pos, end, 0.002, 0.031, 1, Color(r.veins).srgb_to_linear())
				prev = pos
		"moss_lichen","fungus_like":
			var fungus: bool = r.form == "fungus_like"
			for j in ((7 if fungus else 18) if detail else 5):
				var p := radial(rng.randf() * TAU) * rng.randf() * width
				var thick := rng.randf_range(0.45, 1)
				var span := rng.randf_range(0.35, 0.59) if fungus else 0.18
				lump(p, Vector3(span, thick, span * 0.86), tint.darkened(rng.randf() * 0.12), 10 if fungus else 6)
		_:
			var count := 24 if detail else 9
			var caudex := float(r.get("caudex", 0.0))
			if caudex > 0:
				rod(Vector3.ZERO, Vector3.UP * caudex, 0.14, 0.17, bark, 8)
			for j in count:
				var ray := radial(j * 2.39996 + rng.randf() * 0.16)
				var t := float(j + 1) / count
				var base := Vector3.UP * caudex + ray * 0.035
				var end := ray * width * (1.06 - t * 0.76) + Vector3.UP * lerpf(0.18 + caudex, 1, t)
				var w := 0.10
				var style := 1
				var colour := tint
				match str(r.form):
					"fern":
						style = 32
						w = 0.17
					"grass":
						w = 0.016
						colour = tint.darkened(rng.randf() * 0.3)
				blade(base, end, w, 0.12, style, colour)
				if r.has("margin"):
					var edge := Color(r.margin).srgb_to_linear()
					blade(base - Vector3.UP * 0.002, end, w * 1.07, 0.118, style, edge)
				if r.has("veins"):
					blade(base, end, 0.008, 0.123, 1, Color(r.veins).srgb_to_linear())
				if r.has("tips"):
					lump(end, Vector3.ONE * 0.027, Color(r.tips).srgb_to_linear(), 5)
	if r.has("flower"):
		var center := Vector3.UP * 0.97
		rod(Vector3.ZERO, center, 0.013, 0.008, tint)
		for j in 6:
			blade(center, center + radial(j * TAU / 6) * 0.14 + Vector3.UP * 0.03, 0.05, 0.028, 1, Color(r.flower).srgb_to_linear())
	var mesh := finish()
	if r.has("glow"):
		mesh.surface_get_material(0).set_shader_parameter("glow", Color(r.glow).srgb_to_linear())
	return mesh

func finish() -> ArrayMesh:
	st.index()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = SURFACE
	mesh.surface_set_material(0, mat)
	return mesh
