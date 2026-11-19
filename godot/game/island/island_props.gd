extends Node3D

const Placement := preload("res://game/island/flora_placement.gd")
const Generator := preload("res://game/island/flora_mesh.gd")
const Terrain := preload("res://game/island/terrain_chunks.gd")
const ROCK_SHADER := preload("res://game/shaders/prop_rock.gdshader")
const ROCKS := ["boulder","scree","outcrop"]
const DENSITY := [0.34, 0.57, 0.87]
const NEAR := [90.0, 135.0, 190.0]
const FAR := [460.0, 720.0, 1050.0]

var meshes := {}
var recipe := {}
var tier := 0
var setup_signature := []
var counts := {}
var records := []
var lod_scale := 1.0

func geometry(id: String, variant: int, close: bool) -> ArrayMesh:
	var woody: bool = recipe.get(id, {}).get("form", "") in ["tree", "shrub"]
	var key := [id, variant, close, tier if woody and close else 0]
	if meshes.has(key):
		return meshes[key]
	var gen := Generator.new()
	var shape_seed := hash([id, variant])
	var mesh: ArrayMesh
	if id in ROCKS:
		gen.begin(shape_seed)
		var axes := Vector3(1.7, 1, 0.78) if id == "outcrop" else Vector3(0.96, 1, 0.84)
		for i in (6 if id == "scree" else 4):
			var offset := Vector3.ZERO if i == 0 else gen.radial(i * 2.4) * (gen.rng.randf_range(0.8, 2.6) if id == "scree" else gen.rng.randf_range(0.35, 0.6))
			gen.lump(offset, axes * (gen.rng.randf_range(0.75, 1.1) if id == "scree" else (1.0 if i == 0 else gen.rng.randf_range(0.45, 0.7))), Color.WHITE, (8 if id == "scree" else 13) if close else 5)
		mesh = gen.finish()
		var material := ShaderMaterial.new()
		material.shader = ROCK_SHADER
		material.set_shader_parameter("atlas", Terrain.PHOTO_ALBEDO)
		material.set_shader_parameter("layer", 4.0 if id == "scree" else (1.0 if id == "outcrop" else float(variant * 2)))
		mesh.surface_set_material(0, material)
	else:
		var r: Dictionary = recipe[id].duplicate()
		if variant == 0 and r.has("sheltered_colour"):
			r.colour = r.sheltered_colour
		mesh = gen.plant(r, shape_seed, close, tier)
	meshes[key] = mesh
	return mesh

func batch(items: Array, close: bool, tall: bool) -> void:
	var item: Dictionary = items[0]
	var mesh := geometry(item.id, item.variant, close)
	var bounds := mesh.get_aabb()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = items.size()
	var origin: Vector3 = item.p
	for i in items.size():
		var obj: Dictionary = items[i]
		var form: String = recipe.get(obj.id, {}).get("form","rock")
		var h: float = obj.height / maxf(0.001, bounds.end.y)
		var footprint := h
		var up := Vector3.UP
		if form == "moss_lichen":
			footprint = 0.70 + 0.35 * obj.height / float(recipe[obj.id].height[1])
		if form in ["rock","moss_lichen","fungus_like","rosette","herb","grass"]:
			up = obj.up
		var basis := Basis(Quaternion(Vector3.UP, up)) * Basis(Vector3.UP, obj.yaw)
		var lift := up * 0.012 if form == "moss_lichen" else Vector3.ZERO
		mm.set_instance_transform(i, Transform3D(basis.scaled_local(Vector3(footprint, h, footprint)), obj.p - origin + lift))
	var node := MultiMeshInstance3D.new()
	node.position = origin
	node.multimesh = mm
	node.visibility_range_begin = NEAR[tier] * lod_scale if not close else 0.0
	node.visibility_range_end = NEAR[tier] * lod_scale if close else FAR[tier] * lod_scale
	if not tall:
		node.visibility_range_end = NEAR[tier] * lod_scale
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if tall and close else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func build(d, setup: Dictionary, world_seed: int, quality: int, settings: Dictionary) -> void:
	var signature := [setup.nest, world_seed, quality, settings.get("flora_density", -1), settings.get("flora_lod_scale", 1)]
	for w in setup.wild:
		signature.append(Vector2(w.x, w.z))
	if signature == setup_signature:
		return
	setup_signature = signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	counts.clear()
	tier = clampi(quality - 1, 0, 2)
	var rows := Placement.recipes()
	for r in rows:
		recipe[r.id] = r
	var groups := {}
	var density := float(settings.get("flora_density", -1.0))
	density = DENSITY[tier] if density < 0 else clampf(density, 0, 1)
	lod_scale = clampf(float(settings.get("flora_lod_scale", 1.0)), 0.25, 3.0)
	records = Placement.generate(d, setup, world_seed, density, rows)
	for item in records:
		var point: Vector3 = item.p
		var chunk_width := minf(64 * d.cell, NEAR[tier] * lod_scale)
		var chunk := Vector2i(floori((point.x + d.half) / chunk_width), floori((point.z + d.half) / chunk_width))
		var key := [chunk, item.id, item.variant]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(item)
		counts[item.id] = counts.get(item.id, 0) + 1
	for key in groups:
		var tall: bool = key[1] in ["outcrop","boulder"] or recipe.get(key[1], {}).get("form","") in ["tree","shrub","vine"]
		batch(groups[key], true, tall)
		if tall:
			batch(groups[key], false, true)
	build_nest(d, setup.nest, world_seed)

# The earth and the weave follow the same rounded cross-section. Short fibres
# cross the ridge tangentially without spanning the hollow.
func nest_point(d, at: Vector2, base: float, angle: float, radius: float) -> Vector3:
	var ripple := 0.04 * sin(5.0 * angle) + 0.022 * cos(9.0 * angle)
	var p := Vector3(cos(angle), 0, sin(angle) * 0.82) * radius
	var t := clampf(1.0 - absf(radius - 1.68 - ripple) / 0.72, 0.0, 1.0)
	p.y = d.visual_ground(at.x + p.x, at.y + p.z) - base + 0.025 + smoothstep(0.0, 1.0, t) * 0.45
	return p

func build_nest(d, at: Vector2, world_seed: int) -> void:
	var gen := Generator.new()
	gen.begin(world_seed)
	var base: float = d.visual_ground(at.x, at.y)
	var soil := Color("7b6548").srgb_to_linear()
	var straw := Color("c5a36a").srgb_to_linear()
	var radii := [0.94, 1.24, 1.51, 1.70, 1.92, 2.15, 2.42]
	var rings := []
	for radius: float in radii:
		var ring := PackedVector3Array()
		for j in 48:
			ring.append(nest_point(d, at, base, TAU * j / 48, radius))
		rings.append(ring)
	# Smooth vertex normals from the neighbouring ring and angular samples, so the bed reads as one rounded earth surface.
	var centre := Vector3.UP * 0.025
	var normals := []
	for i in rings.size():
		var nr := PackedVector3Array()
		for j in 48:
			var inner: Vector3 = rings[i - 1][j] if i > 0 else centre
			var outer: Vector3 = rings[i + 1][j] if i + 1 < rings.size() else rings[i][j] + (rings[i][j] - inner)
			var around: Vector3 = rings[i][(j + 1) % 48] - rings[i][(j + 47) % 48]
			var n := (outer - inner).cross(around)
			nr.append((n if n.y > 0.0 else -n).normalized())
		normals.append(nr)
	for i in rings.size():
		for j in 48:
			var k := (j + 1) % 48
			if i == 0:
				var a: Vector3 = rings[0][j]
				var b: Vector3 = rings[0][k]
				gen.triangle(centre, a, b, soil, -4, 0.0,
					[Vector2.ZERO, Vector2(a.x,a.z), Vector2(b.x,b.z)], [Vector3.UP, normals[0][j], normals[0][k]])
			else:
				var pr: PackedVector3Array = rings[i - 1]
				var cr: PackedVector3Array = rings[i]
				gen.triangle(pr[j], cr[j], cr[k], soil, 0, 0.0, [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], [normals[i-1][j], normals[i][j], normals[i][k]])
				gen.triangle(pr[j], cr[k], pr[k], soil, 0, 0.0, [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE], [normals[i-1][j], normals[i][k], normals[i-1][k]])
	# Bent twig ribs run across the bank. Staggered lengths of dry Paja
	# dulce wrap around them, crossing alternately above and below each rib.
	const RIBS := 32
	const COURSES := 15
	for j in RIBS:
		var angle := TAU * j / RIBS
		var last := nest_point(d, at, base, angle, 1.06)
		for k in range(1, 9):
			var radius := lerpf(1.06, 2.32, k / 8.0)
			var p := nest_point(d, at, base, angle + 0.08 * (radius - 1.06), radius)
			p.y += 0.053
			gen.rod(last, p, 0.027 - 0.0015 * (k-1), 0.027 - 0.0015 * k, gen.bark, 4)
			last = p
	for course in COURSES:
		var radius := lerpf(1.09, 2.29, course / float(COURSES - 1))
		for section in 8:
			var colour := straw.darkened(gen.rng.randf_range(0.03, 0.37))
			var start := section * 4.0 + course * 0.57
			var last := Vector3.ZERO
			for k in 10:
				var rib := start + k * 0.47
				var angle := rib * TAU / RIBS + 0.08 * (radius - 1.06)
				var r := radius + 0.022 * sin(3.0 * angle + course * 0.6)
				var p := nest_point(d, at, base, angle, r)
				p.y += 0.066 + 0.039 * cos(PI * (rib + course))
				if k > 0:
					gen.rod(last, p, 0.034 if k > 1 else 0.017, 0.034 if k < 9 else 0.009, colour, 3)
				last = p
	# Pockets of pale down gather on the inner shoulder around the bare scrape.
	for j in 56:
		var angle := gen.rng.randf() * TAU
		var r := gen.rng.randf_range(0.80, 1.21)
		var a := nest_point(d, at, base, angle, r) + Vector3.UP * 0.027
		var b := nest_point(d, at, base, angle + gen.rng.randf_range(0.11, 0.27), r + 0.04) + Vector3.UP * 0.053
		gen.blade(a, b, gen.rng.randf_range(0.023, 0.047), 0.023, -3, Color("bcb299").srgb_to_linear())
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	nest.mesh = gen.finish()
	nest.position = Vector3(at.x, base, at.y)
	add_child(nest)
