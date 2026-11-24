extends SceneTree
## T2: shared geometry must retain independent animation and palette state.
const Cache = preload("res://creature/creature_cache.gd")
var fails := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		fails += 1
		printerr("FAIL: ", message)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var cache = Cache.new()
	for species in ["rondo", "zanco", "espinodo", "garfio", "acechalunas", "babosa", "corona", "brujula", "cuarteta"]:
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % species))
		var a = cache.instantiate(g)
		var b = cache.instantiate(g)
		var reference := Creature.new()
		reference.load_genome(g)
		_compare_visuals(reference, a, species)
		reference.free()
		check(a != b and a.skeleton != b.skeleton, species + " independent skeleton")
		check(a.body_mesh.mesh == b.body_mesh.mesh, species + " shared body geometry")
		check(a.rest_aabb() == b.rest_aabb(), species + " identical rest bounds")
		check(a.bio == b.bio, species + " identical seeded biology")
		check(a.materials.skin != b.materials.skin, species + " independent animated uniforms")
		for i in a.legs.size():
			check(a.legs[i].creature == a and b.legs[i].creature == b, species + " remapped leg owner")
			check(a.legs[i].foot != b.legs[i].foot, species + " independent feet")
		var before = b.skeleton.get_bone_pose_position(0)
		a.skeleton.set_bone_pose_position(0, Vector3(3, 4, 5))
		check(b.skeleton.get_bone_pose_position(0) == before, species + " animation isolated")
		a.materials.skin.set_shader_parameter("cA", Color.MAGENTA)
		check(b.materials.skin.get_shader_parameter("cA") != Color.MAGENTA, species + " palette isolated")
		a.free()
		b.free()
	check(cache.builds == 9, "one build per genome")
	var changed = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/rondo.json"))
	changed.skin.cA = "#abcdef"
	var c = cache.instantiate(changed)
	check(cache.builds == 10, "changed genome invalidates cache")
	c.free()
	await _warmup_samples()
	await _navigation()
	print("load time cache/navigation: %d checks, %d failed" % [checks, fails])
	quit(1 if fails else 0)

func _navigation() -> void:
	const TerrainCache = preload("res://game/island/terrain_cache.gd")
	var Props = load("res://game/island/island_props.gd")
	var Setup = load("res://game/stage/stage_setup.gd")
	const Profile = preload("res://game/stage/profile.gd")
	for seed_ in [1, 7, 11]:
		var terrain := CporeTerrain.new()
		var entry := TerrainCache.load_entry(TerrainCache.game_params(seed_))
		if entry.is_empty():
			entry = TerrainCache.build(TerrainCache.game_params(seed_), terrain)
		var data = preload("res://game/island/terrain_data.gd").new()
		data.setup(entry)
		var setup := CporeWorld.default_setup(seed_)
		setup.terrain = 2
		setup.wild = []
		setup.nest = Setup.find_nest(data)
		var world := CporeWorld.new()
		check(world.set_field(entry) == 0 and world.reset(setup) == 0, "navigation setup seed %d" % seed_)
		var initial := world.snapshot()
		var inputs: Array = []
		for k in 6:
			var angle := k * TAU / 6
			inputs.append({"verb": 2, "x": setup.nest.x + sin(angle) * 100, "z": setup.nest.y + cos(angle) * 100})
		var expected: Array = []
		for input in inputs:
			for tick in 30:
				var hash_ := world.step(input if tick == 0 else {})
				expected.append([hash_, world.path()])
		check(world.restore(initial) == 0, "restore before warming")
		var props = Props.new()
		var records: Array = props.records_for(data, setup, seed_, 1, {})
		var result := {"records": []}
		var task := WorkerThreadPool.add_task(func(): world.nav_warm())
		# This is the only work overlapped in the island: pure flora planning.
		result.records = props.records_for(data, setup, seed_, 1, {})
		while not WorkerThreadPool.is_task_completed(task):
			await process_frame
		WorkerThreadPool.wait_for_task_completion(task)
		check(records == result.records, "flora deterministic while navigation warms")
		check(world.snapshot() == initial, "warm does not change snapshot")
		var index := 0
		for input in inputs:
			for tick in 30:
				var hash_ := world.step(input if tick == 0 else {})
				check([hash_, world.path()] == expected[index], "warm/lazy hash and route seed %d tick %d" % [seed_, index])
				index += 1
		props.free()
		if seed_ == 1:
			var plan := {}
			var manifest := Profile.load_json("res://game/data/parts.json")
			var pr: Dictionary = Setup.garfio_profile(manifest)
			var planned: Dictionary = Setup.build(data, seed_, pr, pr, true, null, true, true, plan)
			check(not planned.has("radial_plan"), "presentation plan stays outside strict C setup")
			check(plan == load("res://game/island/radial_fauna.gd").plan(data, seed_, planned.nest), "passed habitat plan matches ambient planner")

func _compare_visuals(reference: Creature, cached: Creature, species: String) -> void:
	check(reference.bio == cached.bio and reference.rest == cached.rest, species + " same biology and spine as uncached build")
	var originals := reference.mesh_instances()
	var copies := cached.mesh_instances()
	check(originals.size() == copies.size(), species + " mesh count matches uncached build")
	for i in originals.size():
		var a: MeshInstance3D = originals[i]
		var b: MeshInstance3D = copies[i]
		check(a.transform == b.transform, species + " rest transform")
		for surface in a.mesh.get_surface_count():
			check(a.mesh.surface_get_arrays(surface) == b.mesh.surface_get_arrays(surface), species + " identical vertex/index/UV/skin arrays")
			var ma: Material = a.get_active_material(surface)
			var mb: Material = b.get_active_material(surface)
			if ma is ShaderMaterial and mb is ShaderMaterial:
				check(ma.shader == mb.shader, species + " same shader")
				for property in ma.get_property_list():
					if String(property.name).begins_with("shader_parameter/"):
						check(ma.get(property.name) == mb.get(property.name), species + " same uniform " + str(property.name))

class WarmIsland extends Node3D:
	var hosts := {}
	var world_env := WorldEnvironment.new()
	var sun := DirectionalLight3D.new()

func _warmup_samples() -> void:
	var warm = load("res://game/loading/pipeline_warmup.gd").new()
	var scene := Node3D.new()
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = "shader_type spatial; uniform vec4 tint : source_color = vec4(1.0); void fragment() { ALBEDO = tint.rgb; }"
	var mesh := QuadMesh.new()
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	scene.add_child(instance)
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_custom_data = true
	batch.multimesh.mesh = mesh
	batch.multimesh.instance_count = 1
	scene.add_child(batch)
	var particles := CPUParticles3D.new()
	particles.mesh = mesh
	scene.add_child(particles)
	var standard := MeshInstance3D.new()
	standard.mesh = SphereMesh.new()
	standard.material_override = StandardMaterial3D.new()
	scene.add_child(standard)
	warm._collect(scene)
	check(warm._samples.size() == 4, "warm-up retains mesh, multimesh format and particle variants")
	warm._collect(scene)
	check(warm._samples.size() == 4, "warm-up collection is idempotent")
	var variant: ShaderMaterial = material.duplicate()
	variant.set_shader_parameter("tint", Color.RED)
	check(warm._signature(mesh, material, false, false) != warm._signature(mesh, variant, false, false), "distinct skin palettes get separate samples")
	scene.free()
	var island := WarmIsland.new()
	root.add_child(island)
	island.world_env.environment = Environment.new()
	island.add_child(island.world_env)
	island.add_child(island.sun)
	var cache = Cache.new()
	var body = cache.instantiate(JSON.parse_string(FileAccess.get_file_as_string("res://game/data/garfio.json")))
	island.add_child(body)
	island.hosts[0] = {"uses_module": true, "body": body}
	var prepared = load("res://game/loading/pipeline_warmup.gd").new()
	var viewport: SubViewport = prepared.prepare(island)
	check(viewport.own_world_3d and viewport.size == Vector2i(128, 128), "isolated warm-up viewport assembled")
	var flame := false
	var soil := false
	var shimmer := false
	for sample in prepared._samples:
		if sample.source is CPUParticles3D and sample.material is StandardMaterial3D:
			flame = flame or sample.material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
			soil = soil or sample.material.blend_mode == BaseMaterial3D.BLEND_MODE_MIX
		shimmer = shimmer or sample.source.name == "HeatShimmer"
	check(flame and soil and shimmer, "warm-up includes flame, soil and screen-reading shimmer")
	for material_ in body.materials.skin_materials():
		check(prepared._seen.has(prepared._signature(body.body_mesh.mesh, material_, false, true)), "warm-up includes every skin variant")
	await process_frame
	viewport.free()
	island.free()
