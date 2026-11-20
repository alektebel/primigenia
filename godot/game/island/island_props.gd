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

## The flora records `build` would generate (pure data: safe on a worker thread). Mirrors build's tier and density.
func records_for(d, setup: Dictionary, world_seed: int, quality: int, settings: Dictionary) -> Array:
	var t := clampi(quality - 1, 0, 2)
	var density := float(settings.get("flora_density", -1.0))
	density = DENSITY[t] if density < 0 else clampf(density, 0, 1)
	return Placement.generate(d, setup, world_seed, density, Placement.recipes())

## `records_in`: the flora records when already generated off the main thread (records_for, island.gd).
func build(d, setup: Dictionary, world_seed: int, quality: int, settings: Dictionary, records_in = null) -> void:
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
	records = Placement.generate(d, setup, world_seed, density, rows) if records_in == null else records_in
	for item in records:
		var point: Vector3 = item.p
		var chunk_width := minf(64 * d.cell, NEAR[tier] * lod_scale)
		var chunk := Vector2i(floori((point.x + d.half) / chunk_width), floori((point.z + d.half) / chunk_width))
		var key := [chunk, item.id, item.variant]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(item)
		counts[item.id] = counts.get(item.id, 0) + 1
	var slice_t := Time.get_ticks_msec()
	for key in groups:
		if Game.veil != null and is_instance_valid(Game.veil) and Time.get_ticks_msec() - slice_t > 24:
			await get_tree().process_frame          # a loading screen is up: one frame between batches of meshes
			slice_t = Time.get_ticks_msec()
		var tall: bool = key[1] in ["outcrop","boulder"] or recipe.get(key[1], {}).get("form","") in ["tree","shrub","vine"]
		batch(groups[key], true, tall)
		if tall:
			batch(groups[key], false, true)
	build_nest(d, setup.nest, world_seed)

# The earth and the weave follow the same rounded cross-section. Short fibres
# cross the ridge tangentially without spanning the hollow.
func nest_point(d, at: Vector2, base: float, angle: float, radius: float) -> Vector3:
	var k := _nk
	var ripple := 0.04 * sin(5.0 * angle) + 0.022 * cos(9.0 * angle)
	var p := Vector3(cos(angle), 0, sin(angle) * 0.82) * radius
	var t := clampf(1.0 - absf(radius / k - 1.68 - ripple) / 0.72, 0.0, 1.0)       # the cross-section of the unit nest, scaled by k
	p.y = d.visual_ground(at.x + p.x, at.y + p.z) - base + 0.025 * k + smoothstep(0.0, 1.0, t) * 0.45 * k
	return p

# The bank height under a local xz point (the same cross-section as nest_point), plus a layer offset.
func nest_pile(d, at: Vector2, base: float, q: Vector2, layer: float) -> Vector3:
	var radius := Vector2(q.x, q.y / 0.82).length()
	var angle := atan2(q.y / 0.82, q.x)
	var p := nest_point(d, at, base, angle, radius)
	p.x = q.x
	p.z = q.y
	p.y += layer
	return p

## The nest was drawn for the 6 m Merodeador (body radius 3 m); a smaller body gets a proportionally smaller nest.
const NEST_RADIUS_CM := 300.0
static func nest_scale_for(body_radius_cm: float) -> float:
	if body_radius_cm <= 0.0:
		return 1.0
	return clampf(sqrt(body_radius_cm / NEST_RADIUS_CM), 0.4, 1.0)

var nest_scale := 1.0              # set before `build`: the scale the nest is (to be) built at
var _nk := 1.0                     # the scale of the nest being generated
var _nest_built_scale := -1.0

## Rebuilds only the nest when the player's body size changed (the flora batches are untouched).
func set_nest_scale(k: float, d, at: Vector2, world_seed: int) -> void:
	nest_scale = k
	if is_equal_approx(_nest_built_scale, k):
		return
	var old := get_node_or_null("Nest")
	if old != null:
		remove_child(old)
		old.queue_free()
	build_nest(d, at, world_seed)

func build_nest(d, at: Vector2, world_seed: int) -> void:
	_nk = nest_scale
	_nest_built_scale = nest_scale
	var k0 := _nk
	var gen := Generator.new()
	gen.begin(world_seed)
	var base: float = d.visual_ground(at.x, at.y)
	var soil := Color("7b6548").srgb_to_linear()
	var straw := Color("c5a36a").srgb_to_linear()
	var radii := [0.94, 1.24, 1.51, 1.70, 1.92, 2.15, 2.42].map(func(r: float) -> float: return r * k0)
	var rings := []
	for radius: float in radii:
		var ring := PackedVector3Array()
		for j in 48:
			ring.append(nest_point(d, at, base, TAU * j / 48, radius))
		rings.append(ring)
	# Smooth vertex normals from the neighbouring ring and angular samples, so the bed reads as one rounded earth surface.
	var centre := Vector3.UP * 0.025 * k0
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
	# An irregular heap, not a lattice: thousands of loose Paja dulce strands and a few twigs thrown down at random
	# (seeded, so the same nest every run). Lengths, bearings, gaps and layers all vary; the rim is frayed.
	for n in 980:          # straw laid on the bank; thicker and denser towards the crest, scattered thin inside
		var rr := clampf(1.7 + gen.rng.randfn(0.0, 0.42), 0.95, 2.42)
		var th := gen.rng.randf() * TAU
		var c := Vector2(cos(th), sin(th) * 0.82) * rr * k0
		var dir := Vector2.from_angle(th + PI * 0.5 + gen.rng.randfn(0.0, 0.8))   # mostly around the bank, often askew
		var len := gen.rng.randf_range(0.22, 0.95) * k0
		var layer := gen.rng.randf_range(0.0, 0.085) * clampf(1.5 - absf(rr - 1.75), 0.0, 1.0) * k0 + 0.02 * k0
		var wob := gen.rng.randf_range(-0.12, 0.12)
		var colour := straw.darkened(gen.rng.randf_range(0.0, 0.42))
		var w := gen.rng.randf_range(0.011, 0.026) * sqrt(k0)
		var last := nest_pile(d, at, base, c, layer)
		var segs := 2 + (n & 1)
		for k in range(1, segs + 1):
			var f := float(k) / segs
			var q := c + dir * len * f + dir.orthogonal() * wob * sin(PI * f)
			if q.length() > 2.6 * k0:
				break
			var p := nest_pile(d, at, base, q, layer + 0.012 * k0 * sin(f * 3.0 + n))
			gen.rod(last, p, w, w * (0.45 if k == segs else 0.9), colour, 3)
			last = p
	for n in 34:           # twigs: stouter, darker, a few poking out over the rim
		var th := gen.rng.randf() * TAU
		var rr := gen.rng.randf_range(1.25, 2.35)
		var c := Vector2(cos(th), sin(th) * 0.82) * rr * k0
		var dir := Vector2.from_angle(gen.rng.randf() * TAU)
		var len := gen.rng.randf_range(0.35, 0.95) * k0
		var rise := (gen.rng.randf_range(0.0, 0.16) if rr > 2.0 else 0.0) * k0
		var a := nest_pile(d, at, base, c, (0.06 + gen.rng.randf() * 0.04) * k0)
		var m := nest_pile(d, at, base, c + dir * len * 0.55, 0.07 * k0 + rise * 0.4) + Vector3(gen.rng.randf_range(-0.03, 0.03) * k0, 0, 0)
		var z := nest_pile(d, at, base, c + dir * len, 0.06 * k0 + rise)
		var tw := gen.rng.randf_range(0.022, 0.04) * sqrt(k0)
		var wood := gen.bark.lerp(straw, gen.rng.randf_range(0.0, 0.3))
		gen.rod(a, m, tw, tw * 0.8, wood, 4)
		gen.rod(m, z, tw * 0.8, tw * 0.35, wood, 4)
	for n in 160:          # frayed rim: loose straw ends leaving the lip, flopping outwards and up
		var th := gen.rng.randf() * TAU
		var rr := gen.rng.randf_range(2.0, 2.4)
		var c := Vector2(cos(th), sin(th) * 0.82) * rr * k0
		var out := Vector2.from_angle(th + gen.rng.randfn(0.0, 0.7)) * Vector2(1, 0.82)
		var a := nest_pile(d, at, base, c, 0.04 * k0)
		var b := a + Vector3(out.x, 0, out.y) * gen.rng.randf_range(0.12, 0.38) * k0 + Vector3.UP * gen.rng.randf_range(-0.02, 0.1) * k0
		gen.rod(a, b, 0.013, 0.004, straw.darkened(gen.rng.randf_range(0.05, 0.4)), 3)
	# Pockets of pale down gather on the inner shoulder around the bare scrape.
	for j in 90:
		var angle := gen.rng.randf() * TAU
		var r := gen.rng.randf_range(0.80, 1.45)
		var a := nest_point(d, at, base, angle, r * k0) + Vector3.UP * 0.027 * k0
		var b := nest_point(d, at, base, angle + gen.rng.randf_range(0.11, 0.27), (r + 0.04) * k0) + Vector3.UP * 0.053 * k0
		gen.blade(a, b, gen.rng.randf_range(0.023, 0.047), 0.023, -3, Color("bcb299").srgb_to_linear())
	var nest := MeshInstance3D.new()
	nest.name = "Nest"
	nest.mesh = gen.finish()
	nest.position = Vector3(at.x, base, at.y)
	add_child(nest)
