extends RefCounted
# One baked surface per reusable crown/tuft/prop. Coordinates are in species-height
# units until baked; instance transforms supply the final height in metres.
const SURFACE := preload("res://game/shaders/flora.gdshader")
var rng := RandomNumberGenerator.new()
var st := SurfaceTool.new()
var tint := Color.WHITE
var bark := Color("7d6c59").srgb_to_linear()
var width := 0.5
var detail := true
var fruit := Color.TRANSPARENT
var leaflet_pairs := 6
var berry_sites := []
var r_tree := false

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
		var c := colour.darkened(0.22 * fposmod(sin(i * 78.233 + base * 910.0) * 437.5, 1.0)) if sides >= 6 else colour
		triangle(a + u * base, b + v * tip, a + v * base, c)
		triangle(a + u * base, b + u * tip, b + v * tip, c)

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

	if detail and fruit.a > 0 and r_tree and rng.randf() < 0.4:
		lump(p - Vector3.UP * 0.01, Vector3(0.009, 0.014, 0.009), fruit, 6)

func branch(a: Vector3, dir: Vector3, length_m: float, radius: float, depth: int, angle: float) -> void:
	var b := a + dir * length_m
	rod(a, b, radius, radius * 0.62, bark, 5 if detail else 3)
	if not r_tree and detail and depth >= 1:
		crown(a.lerp(b, 0.85), width * 0.3)
	if depth <= 1 and b.y < 0.85 and (b - Vector3(0, b.y, 0)).length() > 0.05:
		berry_sites.append(b)
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
	rod(Vector3.DOWN * 0.03, top, 0.04 if tree else 0.065, 0.02, bark, 12 if detail else 7)
	if tree:
		for j in 7:
			var ray := radial(j * TAU / 7 + rng.randf() * 0.3)
			triangle(ray * 0.12, Vector3.UP * 0.12, ray * 0.03 + ray.cross(Vector3.UP) * 0.014, bark)
	for j in (8 if detail else 5):
		var dir := radial(j * 2.4 + rng.randf() * 0.5) * width * (2.0 if tree else 1.1) + Vector3.UP * ((0.48 + j * 0.09) if tree else (1.0 + j * 0.12))
		branch(top * (0.55 + j * 0.06), dir.normalized(), 0.32 if tree else 0.54, 0.021, clampi(int(r.levels) - 2, 1, 2) if detail else 0, deg_to_rad(r.angle))
	if detail and not tree and fruit.a > 0:
		# Low pendant clusters on the lower lateral twigs (perlilla: wax-white berries 10-15 mm).
		for site in berry_sites:
			if rng.randf() < 0.85:
				for k in rng.randi_range(6, 11):
					var at: Vector3 = site + Vector3(rng.randf_range(-0.03, 0.03), -rng.randf_range(0.01, 0.06), rng.randf_range(-0.03, 0.03))
					lump(at, Vector3(0.013, 0.013, 0.013), fruit, 6)

# Soft upright stem with opposite pairs of serrated leaves; veins drawn as a second narrow blade.
func opposite_herb(r: Dictionary) -> void:
	var nodes := 5 if detail else 3
	rod(Vector3.ZERO, Vector3.UP * 0.96, 0.012, 0.006, tint.darkened(0.1), 4)
	var turn := rng.randf() * TAU
	for n in nodes:
		var y := 0.1 + 0.8 * n / float(nodes - 1 if nodes > 1 else 1)
		var reach := width * (1.05 - 0.55 * y) * 1.15
		for side in 2:
			var dir := radial(turn + n * 1.57 + side * PI)
			var base := Vector3.UP * y
			var end := base + dir * reach + Vector3.UP * (0.07 - 0.03 * y)
			blade(base, end, reach * 0.34, 0.05, 1, tint.lightened(rng.randf() * 0.05))
			if detail:
				if r.has("veins"):
					var vc := Color(r.veins).srgb_to_linear()
					blade(base + Vector3.UP * 0.001, end, 0.006, 0.051, 1, vc)
					for t in 3:
						var f := 0.28 + 0.22 * t
						var side_dir := dir.cross(Vector3.UP) * (reach * 0.22)
						var m := base.lerp(end, f) + Vector3.UP * 0.05 * sin(PI * f)
						blade(m, m + side_dir + dir * reach * 0.12, 0.004, 0.0, 0, vc)
						blade(m, m - side_dir + dir * reach * 0.12, 0.004, 0.0, 0, vc)
				for t in 4:
					var f2 := 0.2 + 0.2 * t
					var edge := dir.cross(Vector3.UP) * reach * 0.3 * sin(PI * f2)
					var q := base.lerp(end, f2) + Vector3.UP * 0.05 * sin(PI * f2)
					for e in [-1, 1]:
						triangle(q + edge * e, q + edge * e * 1.12 + dir * 0.02, q + edge * e + dir * 0.04, tint.lightened(0.04), 0)

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
	berry_sites.clear()
	r_tree = r.form == "tree"
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
			for j in ((7 if fungus else 70) if detail else (5 if fungus else 14)):
				var p := radial(rng.randf() * TAU) * rng.randf() * width
				var thick := rng.randf_range(0.45, 1)
				var span := rng.randf_range(0.35, 0.59) if fungus else rng.randf_range(0.06, 0.12)
				lump(p, Vector3(span, thick * (1.0 if fungus else 0.22), span * 0.86), tint.darkened(0.1 + rng.randf() * 0.2) if not fungus else tint.darkened(rng.randf() * 0.12), 10 if fungus else 6)
		"herb" when r.get("arrangement", "") == "opposite":
			opposite_herb(r)
		_:
			var count := 24 if detail else 9
			var caudex := float(r.get("caudex", 0.0))
			if caudex > 0:
				var dead := Color(r.get("dead", "8a7656")).srgb_to_linear()
				rod(Vector3.ZERO, Vector3.UP * caudex, 0.05, 0.06, dead.darkened(0.2), 8)
				for j in 14:
					var ray := radial(j * 2.4 + rng.randf() * 0.3)
					blade(Vector3.UP * caudex * 0.95, ray * rng.randf_range(0.18, 0.3) + Vector3.UP * caudex * rng.randf_range(0.2, 0.6), 0.04, 0.0, 1, dead.darkened(rng.randf() * 0.25))
			for j in count:
				var ray := radial(j * 2.39996 + rng.randf() * 0.16)
				var t := float(j + 1) / count
				var base := Vector3.UP * caudex + ray * 0.035
				var end := ray * width * (1.06 - t * 0.76) + Vector3.UP * lerpf(0.18 + caudex, 0.5 if r.has("flower") else 1.0, t)
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
					blade(base.lerp(end, 0.55), end, w * 0.7, 0.05, style, edge)
				if r.has("veins"):
					blade(base, end, 0.008, 0.123, 1, Color(r.veins).srgb_to_linear())
				if r.has("tips"):
					lump(end, Vector3.ONE * 0.027, Color(r.tips).srgb_to_linear(), 5)
	if r.has("flower"):
		var center := Vector3.UP * 0.97
		rod(Vector3.ZERO, center, 0.013, 0.008, tint)
		var petals := 8
		var cream := Color(r.flower).srgb_to_linear()
		for j in petals:
			var pa := j * TAU / petals + rng.randf() * 0.1
			var tip := center + radial(pa) * rng.randf_range(0.12, 0.16) + Vector3.UP * rng.randf_range(0.05, 0.1)
			blade(center, tip, 0.045, -0.03, 1, cream.darkened(rng.randf() * 0.06))
		if r.has("flower_centre"):
			lump(center + Vector3.UP * 0.005, Vector3(0.05, 0.03, 0.05), Color(r.flower_centre).srgb_to_linear(), 8)
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
