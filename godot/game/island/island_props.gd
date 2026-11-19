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
var lod_scale := 1.0

func geometry(id: String, variant: int, close: bool) -> ArrayMesh:
	var key := [id, variant, close]
	if meshes.has(key):
		return meshes[key]
	var gen := Generator.new()
	var shape_seed := hash([id, variant])
	var mesh: ArrayMesh
	if id in ROCKS:
		gen.begin(shape_seed)
		var axes := Vector3(1.7, 1, 0.78) if id == "outcrop" else Vector3(0.96, 1, 0.84)
		for i in (6 if id == "scree" else 1):
			var offset := Vector3.ZERO if i == 0 else gen.radial(i * 2.4) * gen.rng.randf_range(0.8, 2.6)
			gen.lump(offset, axes * gen.rng.randf_range(0.75, 1.1), Color.WHITE, 8 if close else 5)
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
		mesh = gen.plant(r, shape_seed, close)
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
			footprint = maxf(0.48, h)
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
	for item in Placement.generate(d, setup, world_seed, density, rows):
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

func build_nest(d, at: Vector2, world_seed: int) -> void:
	var gen := Generator.new()
	gen.begin(world_seed)
	var base: float = d.visual_ground(at.x, at.y)
	var soil := Color("61503b").srgb_to_linear()
	var straw := Color("b7985f").srgb_to_linear()
	var ring := []
	var lip := []
	var hollow := []
	for j in 48:
		var p := gen.radial(TAU * j / 48) * gen.rng.randf_range(2.32, 2.53)
		p.z *= 0.82
		p.y = d.visual_ground(at.x + p.x, at.y + p.z) - base + 0.045
		ring.append(p)
		var ridge := p * 0.70
		var inner := p * 0.46
		ridge.y = d.visual_ground(at.x + ridge.x, at.y + ridge.z) - base + gen.rng.randf_range(0.39, 0.47)
		inner.y = d.visual_ground(at.x + inner.x, at.y + inner.z) - base + 0.065
		lip.append(ridge)
		hollow.append(inner)
	for j in 48:
		var k := (j + 1) % 48
		var litter := straw.darkened(gen.rng.randf_range(0.46, 0.58))
		gen.triangle(Vector3.UP * 0.035, hollow[j], hollow[k], soil)
		gen.triangle(hollow[j], lip[j], lip[k], litter)
		gen.triangle(hollow[j], lip[k], hollow[k], litter)
		gen.triangle(lip[j], ring[j], ring[k], litter)
		gen.triangle(lip[j], ring[k], lip[k], litter)
	for j in 540:
		var angle := gen.rng.randf() * TAU
		var radius := gen.rng.randf_range(1.12, 2.15)
		var a := gen.radial(angle) * radius
		var b := gen.radial(angle + gen.rng.randf_range(0.21, 0.64)) * (radius + gen.rng.randf_range(-0.18, 0.18))
		var rim := 0.08 + 0.49 * maxf(0.0, 1.0 - absf(radius - 1.68) * 1.9) * gen.rng.randf_range(0.65, 1.0)
		a.z *= 0.82
		b.z *= 0.82
		a.y = d.visual_ground(at.x + a.x, at.y + a.z) - base + rim
		b.y = d.visual_ground(at.x + b.x, at.y + b.z) - base + rim * gen.rng.randf_range(0.55, 1.3)
		var twig := j % 7 == 0
		var colour := gen.bark if twig else straw.darkened(gen.rng.randf() * 0.36)
		gen.rod(a, b, 0.042 if twig else 0.017, 0.012 if twig else 0.006, colour, 4)
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	nest.mesh = gen.finish()
	nest.position = Vector3(at.x, base, at.y)
	add_child(nest)
