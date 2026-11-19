extends RefCounted
# One baked surface per reusable crown/tuft/prop. Coordinates are in species-height
# units until baked; instance transforms supply the final height in metres.
const SURFACE := preload("res://game/shaders/flora.gdshader")
const GROUND_COVER := preload("res://game/shaders/flora_ground.gdshader")
var tier := 0
var rng := RandomNumberGenerator.new()
var st := SurfaceTool.new()
var tint := Color.WHITE
var bark := Color("6f5642").srgb_to_linear()
var width := 0.5
var detail := true
var fruit := Color.TRANSPARENT
var leaflet_pairs := 6
var berry_sites := []
var r_tree := false
var droop := 0.0

func begin(shape_seed: int) -> void:
	rng.seed = shape_seed
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

func triangle(a: Vector3, b: Vector3, c: Vector3, colour: Color, style := 0, bend := 0.0, uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], normals := []) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for i in 3:
		var p: Vector3 = [a, b, c][i]
		st.set_color(colour)
		st.set_normal(normal if normals.is_empty() else normals[i])
		st.set_uv(uvs[i])
		st.set_uv2(Vector2(style, bend * maxf(p.y, 0.0)))
		st.add_vertex(p)

# Clockwise winding, with shared radial normals and an unwrapped bark seam.
func rod(a: Vector3, b: Vector3, base: float, tip: float, colour: Color, sides := 5, wood := false) -> void:
	var axis := (b - a).normalized()
	var right := axis.cross(Vector3.FORWARD)
	if right.length_squared() < 0.01:
		right = axis.cross(Vector3.RIGHT)
	right = right.normalized()
	var slope := axis * (base - tip) / a.distance_to(b)
	for i in sides:
		var u := right.rotated(axis, TAU * i / sides)
		var v := right.rotated(axis, TAU * (i + 1) / sides)
		var nu := (u + slope).normalized()
		var nv := (v + slope).normalized()
		var left := float(i) / sides
		var edge := float(i + 1) / sides
		var style := -1 if wood else 0
		triangle(a + u * base, b + v * tip, a + v * base, colour, style, 0,
			[Vector2(left,a.y), Vector2(edge,b.y), Vector2(edge,a.y)], [nu,nv,nv])
		triangle(a + u * base, b + u * tip, b + v * tip, colour, style, 0,
			[Vector2(left,a.y), Vector2(left,b.y), Vector2(edge,b.y)], [nu,nu,nv])

func blade(base: Vector3, end: Vector3, half_width: float, sag: float, style: int, colour: Color, spray := false) -> void:
	var side := (end - base).cross(Vector3.UP).normalized() * half_width
	var mid := base.lerp(end, 0.5) + Vector3.UP * sag
	var prev := base
	for j in 2:
		var next := mid if j == 0 else end
		var v := float(j) * 0.5
		var normals := []
		var opposite := []
		var pigment := colour
		if spray:
			var radial_dir := (end - base).normalized()
			var shoulder := side.normalized() * 0.38
			var inner := (Vector3.UP * 0.8 + radial_dir * (0.4 + v)).normalized()
			var outer := (Vector3.UP * 0.7 + radial_dir * (0.85 + v)).normalized()
			normals = [(inner - shoulder).normalized(), (inner + shoulder).normalized(), (outer + shoulder).normalized()]
			opposite = [normals[0], normals[2], (outer - shoulder).normalized()]
			pigment = colour.darkened(0.12 * (1.0 - v))
		triangle(prev - side, prev + side, next + side, pigment, style, 0.65, [Vector2(0, v), Vector2(1, v), Vector2(1, v + 0.5)], normals)
		triangle(prev - side, next + side, next - side, pigment, style, 0.65, [Vector2(0, v), Vector2(1, v + 0.5), Vector2(0, v + 0.5)], opposite)
		prev = next

func radial(angle: float) -> Vector3:
	return Vector3(cos(angle), 0, sin(angle))

func crown(p: Vector3, extent: float) -> void:
	var cards := [5, 10, 16]
	var count := int(cards[tier]) if detail else 4
	var turn := rng.randf() * TAU
	for j in count:
		var dir := radial(turn + j * 2.4 + rng.randf_range(-0.35, 0.35))
		var lift := rng.randf_range(-0.55, 0.85)
		var axis := (dir + Vector3.UP * lift).normalized()
		var start := p + axis * extent * rng.randf_range(0.04, 0.22)
		var reach := extent * rng.randf_range(0.7, 1.05)
		blade(start, start + axis * reach, reach * 0.29, reach * 0.14, leaflet_pairs, tint.lightened(rng.randf() * 0.045), true)

	if detail and fruit.a > 0 and r_tree and rng.randf() < 0.4:
		lump(p - Vector3.UP * 0.01, Vector3(0.009, 0.014, 0.009), fruit, 6)

# The first tangent follows the parent out of its collar. Gravity bends the
# distal half of the limb. All rings share their neighbours' lighting normals.
func branch(a: Vector3, parent: Vector3, dir: Vector3, length_m: float, radius: float, depth: int, angle: float) -> void:
	var start := a - parent * radius * 0.65
	var b := a + (dir - Vector3.UP * droop * 0.32) * length_m
	var control_a := a + parent * length_m * 0.31
	var control_b := b - (dir - Vector3.UP * droop * 1.6).normalized() * length_m * 0.38
	var tangent := (b - control_b).normalized()
	if detail:
		var sides := 4 + tier
		var levels := [0.0, 0.24, 0.62, 1.0]
		var rings := []
		var normals := []
		var across := dir.cross(Vector3.UP).normalized()
		for t: float in levels:
			var center := start.bezier_interpolate(control_a, control_b, b, t)
			var axis := start.bezier_derivative(control_a, control_b, b, t).normalized()
			var right := axis.cross(across).normalized()
			var ring := PackedVector3Array()
			var nr := PackedVector3Array()
			# Bury the narrow first ring inside the parent; the next ring
			# rounds out the collar just beyond the attachment.
			var collar_offset := (t - 0.24) / 0.19
			var collar := 0.23 * exp(-collar_offset * collar_offset)
			var buried := 0.26 * pow(1.0 - t, 8.0)
			var taper := 0.48 + 2.0 * collar_offset * collar / 0.19 - 2.08 * pow(1.0 - t, 7.0)
			for j in sides:
				var outward := right.rotated(axis, -TAU * j / sides)
				ring.append(center + outward * radius * (1.0 - 0.48 * t + collar - buried))
				nr.append((outward + axis * radius / length_m * taper).normalized())
			rings.append(ring)
			normals.append(nr)
		wood_skin(rings, normals, levels, sides, length_m)
	else:
		rod(a, b, radius, radius * 0.52, bark, 3)
	if not r_tree and detail and depth >= 1:
		crown(start.bezier_interpolate(control_a, control_b, b, 0.85), width * 0.3)
	if depth <= 1 and b.y < 0.85 and Vector2(b.x, b.z).length() > 0.05:
		berry_sites.append(b)
	if depth <= 0:
		crown(b, width * 0.37)
		return
	var turn := rng.randf() * TAU
	for i in 2:
		var lateral := radial(turn + PI * i)
		var aim := (dir * 0.54 + Vector3.UP * cos(angle) * 0.45 + lateral * sin(angle)).normalized()
		branch(b, tangent, aim, length_m * 0.67, radius * (0.60 if i == 0 else 0.46), depth - 1, angle)

func ribbon(angle: float) -> void:
	var root := radial(angle) * 0.03
	var fork := radial(angle) * 0.35 + Vector3.UP * 0.37
	blade(root, fork, 0.036, 0.08, 0, tint)
	for side in [-1, 1]:
		var tip := radial(angle + side * 0.34) * rng.randf_range(0.60, 0.95) + Vector3.UP * rng.randf_range(0.59, 0.99)
		blade(fork, tip, 0.065, 0.16, 1, tint)

# A continuous trunk skin widens into lobed roots. The flare decays rapidly
# above the foot, leaving a round shaft. Normals follow the changing profile.
func trunk_point(t: float, angle: float, twist: float, top: Vector3) -> Vector3:
	var lobe := pow(0.5 + 0.5 * cos(5.0 * angle + twist + t * 2.0), 3.0)
	var flare := pow(maxf(0.0, 1.0 - t * 3.0), 2.6)
	var radius := lerpf(0.042, 0.019, t) + flare * (0.012 + 0.088 * lobe)
	return Vector3.DOWN * 0.024 * (1.0 - t) + top * t + radial(angle) * radius

func trunk(top: Vector3) -> void:
	var sides := int([16, 24, 36][tier]) if detail else 10
	var levels := [0.0, 0.08, 0.19, 0.37, 1.0] if detail else [0.0, 0.24, 1.0]
	var twist := rng.randf() * TAU
	var rings := []
	var normals := []
	for t: float in levels:
		var ring := PackedVector3Array()
		var normal_ring := PackedVector3Array()
		for j in sides:
			var angle := TAU * j / sides
			ring.append(trunk_point(t, angle, twist, top))
			var du := trunk_point(t, angle + 0.01, twist, top) - trunk_point(t, angle - 0.01, twist, top)
			var dv := trunk_point(minf(t + 0.01, 1.0), angle, twist, top) - trunk_point(maxf(t - 0.01, 0.0), angle, twist, top)
			normal_ring.append(dv.cross(du).normalized())
		rings.append(ring)
		normals.append(normal_ring)
	wood_skin(rings, normals, levels, sides, top.y)

func wood_skin(rings: Array, normals: Array, levels: Array, sides: int, length_m: float) -> void:
	for i in range(1, levels.size()):
		for j in sides:
			var k := (j + 1) % sides
			var u := float(j) / sides
			var v := float(j + 1) / sides
			var lo: float = levels[i-1] * length_m
			var hi: float = levels[i] * length_m
			triangle(rings[i-1][j], rings[i-1][k], rings[i][k], bark, -1, 0,
				[Vector2(u,lo),Vector2(v,lo),Vector2(v,hi)], [normals[i-1][j],normals[i-1][k],normals[i][k]])
			triangle(rings[i-1][j], rings[i][k], rings[i][j], bark, -1, 0,
				[Vector2(u,lo),Vector2(v,hi),Vector2(u,hi)], [normals[i-1][j],normals[i][k],normals[i][j]])

func woody(r: Dictionary) -> void:
	var tree: bool = r.form == "tree"
	var h := 0.52 if tree else 0.15
	var top := Vector3(0.014, h, -0.022)
	if tree:
		trunk(top)
	else:
		rod(Vector3.DOWN * 0.03, top, 0.065, 0.02, bark, (10 + 3 * tier) if detail else 5, detail)
	var limbs := (5 if tier == 0 else 8) if detail else 5
	for j in limbs:
		var dir := radial(j * 2.4 + rng.randf() * 0.5) * width * (2.0 if tree else 1.1) + Vector3.UP * ((0.48 + j * 0.09) if tree else (1.0 + j * 0.12))
		branch(top * (0.55 + 0.42 * j / (limbs - 1)), top.normalized(), dir.normalized(), 0.32 if tree else 0.54, 0.021, clampi(int(r.levels) - 2, 1, 2) if detail else 0, deg_to_rad(r.angle))
	if not tree and fruit.a > 0:
		# Hang compact bunches below the outer sprays, clear of the central stems.
		for site: Vector3 in berry_sites:
			var outward := Vector3(site.x, 0, site.z).normalized()
			var bunch := site + outward * width * 0.22 - Vector3.UP * 0.048
			rod(site, bunch, 0.005, 0.003, bark, 3)
			for k in ((4 + tier) if detail else 3):
				var offset := radial(k * 2.4) * (0.031 if k > 0 else 0.0)
				offset.y = -0.012 * k
				berry(bunch + offset, fruit.darkened(0.025 * k))

# A pendant berry is a smooth ellipsoid: latitude rings with sphere normals, pale on top and shaded at the blossom end.
func berry(center: Vector3, colour: Color) -> void:
	var radii := Vector3(0.026, 0.03, 0.026)
	var sides := (6 if tier == 0 else 10) if detail else 5
	var bands := (3 if tier == 0 else 4) if detail else 2
	var rows := []
	for i in range(bands + 1):
		var phi := PI * i / bands
		var ring := []
		for j in sides:
			var d := radial(TAU * j / sides) * sin(phi) + Vector3.UP * cos(phi)
			ring.append(d)
		rows.append(ring)
	for i in bands:
		for j in sides:
			var k := (j + 1) % sides
			var d00: Vector3 = rows[i][j]
			var d01: Vector3 = rows[i][k]
			var d10: Vector3 = rows[i + 1][j]
			var d11: Vector3 = rows[i + 1][k]
			var shade := colour.darkened(0.14 * float(i) / bands)
			var uvs := [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE]
			if i < bands - 1:
				triangle(center + d00 * radii, center + d10 * radii, center + d11 * radii, shade, 0, 0, uvs, [d00, d10, d11])
			if i > 0:
				triangle(center + d00 * radii, center + d11 * radii, center + d01 * radii, shade, 0, 0, uvs, [d00, d11, d01])

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

static func vine_point(step: int) -> Vector3:
	var t := step / 14.0
	# The vine is scaled to 72% of the host height. Clear the flared base,
	# then wind inwards as the shaft narrows.
	var radius := lerpf(0.074, 0.033, t) + 0.07 * pow(1.0 - t, 12.0)
	return Vector3(cos(step * 0.43) * radius, t, sin(step * 0.43) * radius)

# Sweep a cupped blade with a rounded keel. The width profile closes the
# silhouette in geometry and keeps the purple rim attached as the leaf bends.
func snow_leaf(ray: Vector3, base: Vector3, reach: float, rise: float, arch: float, half_width: float, pigment: Color, living: bool) -> void:
	var side := ray.cross(Vector3.UP)
	var previous := []
	var old_normals := []
	var steps := 4 if living else 3
	for i in range(steps + 1):
		var t := float(i) / steps
		var w := half_width * (0.025 + pow(sin(PI * t), 0.78))
		var center := base + ray * (reach * t) + Vector3.UP * (rise * t + arch * sin(PI * t))
		var tangent := (ray * reach + Vector3.UP * (rise + arch * PI * cos(PI * t))).normalized()
		var facing := side.cross(tangent).normalized()
		var row := [center - side * w, center - facing * w * 0.28, center + side * w]
		var nr := [(facing + side * 0.38).normalized(), facing, (facing - side * 0.38).normalized()]
		if i > 0:
			var lo := float(i - 1) / steps
			var style := -2 if living else 0
			for j in 2:
				var u := j * 0.5
				triangle(previous[j], row[j+1], previous[j+1], pigment, style, 0.18,
					[Vector2(u,lo),Vector2(u+0.5,t),Vector2(u+0.5,lo)], [old_normals[j],nr[j+1],old_normals[j+1]])
				triangle(previous[j], row[j], row[j+1], pigment, style, 0.18,
					[Vector2(u,lo),Vector2(u,t),Vector2(u+0.5,t)], [old_normals[j],nr[j],nr[j+1]])
		previous = row
		old_normals = nr

func snowshield(r: Dictionary) -> void:
	var top := Vector3.UP * float(r.caudex)
	rod(Vector3.ZERO, top, 0.095, 0.083, bark, 12, true)
	var dead := Color(r.dead).srgb_to_linear()
	var turn := rng.randf() * TAU
	for j in 34:
		var ray := radial(turn + j * 2.39996)
		var base := top * (0.74 + 0.24 * j / 33.0) + ray * 0.072
		snow_leaf(ray, base, rng.randf_range(0.10, 0.22), -rng.randf_range(0.19, 0.29),
			0.042, 0.052, dead.darkened(rng.randf_range(0.0, 0.42)), false)
	for j in 30:
		var t := j / 29.0
		var ray := radial(turn + j * 2.39996 + rng.randf_range(-0.09, 0.09))
		snow_leaf(ray, top + ray * 0.045, width * lerpf(0.91, 0.085, t),
			lerpf(0.08, 1.0 - top.y, t), lerpf(0.14, 0.04, t), lerpf(0.084, 0.038, t),
			tint.darkened(t * 0.24), true)

func plant(r: Dictionary, shape_seed: int, near_mesh: bool, near_tier := 0) -> ArrayMesh:
	begin(shape_seed)
	detail = near_mesh
	tier = clampi(near_tier, 0, 2) if detail else 0
	tint = Color(r.colour).srgb_to_linear()
	width = r.spread
	berry_sites.clear()
	r_tree = r.form == "tree"
	fruit = Color(r.fruit).srgb_to_linear() if r.has("fruit") else Color.TRANSPARENT
	leaflet_pairs = clampi(roundi(width * 0.37 * float(r.height[1]) / maxf(0.01, float(r.leaf_cm) / 100.0)), 3, 24) if detail else 4
	match str(r.form):
		"tree","shrub":
			droop = r.droop
			woody(r)
		"algae":
			for j in (7 if detail else 4):
				ribbon(j * 2.4)
		"vine":
			var prev := vine_point(0)
			for j in range(1, 15):
				var pos := vine_point(j)
				rod(prev, pos, 0.004, 0.004, bark, 4)
				var end := pos + radial(j) * 0.12 + Vector3.DOWN * 0.035
				blade(pos, end, 0.025, 0.03, 5, tint)
				if r.has("veins"):
					blade(pos, end, 0.002, 0.031, 1, Color(r.veins).srgb_to_linear())
				prev = pos
		"moss_lichen":
			# Thin shader layer, aligned to the terrain facet by the instance.
			var center := Vector3.UP
			for j in 12:
				var a := radial(j * TAU / 12) * width
				var b := radial((j + 1) * TAU / 12) * width
				triangle(center, a, b, tint, 0, 0, [Vector2.ZERO, Vector2(a.x,a.z)/width, Vector2(b.x,b.z)/width], [Vector3.UP,Vector3.UP,Vector3.UP])
		"fungus_like":
			for j in (7 if detail else 5):
				var p := radial(rng.randf() * TAU) * rng.randf() * width
				var thick := rng.randf_range(0.45, 1)
				var span := rng.randf_range(0.35, 0.59)
				lump(p, Vector3(span, thick, span * 0.86), tint.darkened(rng.randf() * 0.12), 10)
		"herb" when r.get("arrangement", "") == "opposite":
			opposite_herb(r)
		"rosette" when r.has("caudex"):
			snowshield(r)
		_:
			var count := 24 if detail else 9
			for j in count:
				var ray := radial(j * 2.39996 + rng.randf() * 0.16)
				var t := float(j + 1) / count
				var base := ray * 0.035
				var end := ray * width * (1.06 - t * 0.76) + Vector3.UP * lerpf(0.18, 0.5 if r.has("flower") else 1.0, t)
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
	var mesh := finish(GROUND_COVER if r.form == "moss_lichen" else SURFACE)
	if r.has("caudex"):
		mesh.surface_get_material(0).set_shader_parameter("leaf_margin", Color(r.margin))
	if r.form == "moss_lichen":
		var material := mesh.surface_get_material(0) as ShaderMaterial
		material.set_shader_parameter("relief_mm", r.relief_mm)
		material.set_shader_parameter("moss", r.has("glow"))
		if r.has("glow"):
			material.set_shader_parameter("glow", Color(r.glow))
	return mesh

func finish(shader: Shader = SURFACE) -> ArrayMesh:
	st.index()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mesh.surface_set_material(0, mat)
	return mesh
