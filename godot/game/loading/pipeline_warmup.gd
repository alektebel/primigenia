extends RefCounted
## Render real vertex formats and materials in an isolated, unshown viewport.
## Keep successful signatures across entries, including shader resource references.
## A material on an invisible node does not warm a rendering pipeline.
static var _warmed := {}
static var _fx_warmed := {}
var _context: Array = []
var _samples: Array = []
var _seen := {}

func _signature(mesh: Mesh, material: Material, multi: bool, skinned: bool, colors: bool = false, custom: bool = false) -> Array:
	var code := "default" if material == null else str(material.get_rid())
	if material is ShaderMaterial:
		code = material.shader.code if material.shader != null else "default"
		for property in material.get_property_list():
			if String(property.name).begins_with("shader_parameter/"):
				code += str(property.name) + "=" + str(material.get(property.name))
	elif material is BaseMaterial3D:
		# Includes transparency, billboard, vertex colour, textures, etc.
		code = material.get_class()
		for property in material.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				code += str(property.name) + "=" + str(material.get(property.name))
	var formats := []
	for i in mesh.get_surface_count():
		formats.append(mesh.surface_get_format(i) if mesh is ArrayMesh else [mesh.get_class(), mesh.get("add_uv2")])
	return [code, formats, multi, skinned, colors, custom, _context]

func _collect(node: Node) -> void:
	var mesh: Mesh
	var multi := node is MultiMeshInstance3D
	var skinned := node is MeshInstance3D and node.skin != null
	if node is MeshInstance3D:
		mesh = node.mesh
	elif multi and node.multimesh != null:
		mesh = node.multimesh.mesh
	elif node is CPUParticles3D:
		mesh = node.mesh
		multi = true # particle draw uses instanced vertex attributes
	if mesh != null:
		for i in mesh.get_surface_count():
			var material: Material = node.material_override if node is GeometryInstance3D else null
			if material == null:
				material = node.get_active_material(i) if node is MeshInstance3D else mesh.surface_get_material(i)
			var colors: bool = node.multimesh.use_colors if node is MultiMeshInstance3D else node is CPUParticles3D
			var custom: bool = node.multimesh.use_custom_data if node is MultiMeshInstance3D else node is CPUParticles3D
			var signature := _signature(mesh, material, multi, skinned, colors, custom)
			if not _warmed.has(signature) and not _seen.has(signature):
				_seen[signature] = true
				_samples.append({"mesh": mesh, "material": material, "multi": multi, "colors": colors, "custom": custom, "skin": node.skin if skinned else null, "source": node, "signature": signature})
	for child in node.get_children():
		_collect(child)

func _skin_variants(node: Node) -> void:
	if node is Creature:
		var creature: Creature = node
		for material in creature.materials.skin_materials():
			var signature := _signature(creature.body_mesh.mesh, material, false, true)
			if not _seen.has(signature) and not _warmed.has(signature):
				_seen[signature] = true
				_samples.append({"mesh": creature.body_mesh.mesh, "material": material, "multi": false, "skin": creature.body_mesh.skin, "source": creature.body_mesh, "signature": signature})
	for child in node.get_children():
		_skin_variants(child)

func render(island: Node3D, slice: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		return # the dummy renderer cannot warm pipelines
	var game := island.get_tree().root.get_node_or_null("Game")
	if game == null or game.veil == null or not is_instance_valid(game.veil):
		return # a fast entry without a veil must stay synchronous
	var viewport := prepare(island)
	# The viewport is unshown, but UPDATE_ALWAYS really draws it. Two slices
	# cover submission and completion, with stalls accounted by the island timer.
	await slice.call()
	await slice.call()
	for sample in _samples:
		_warmed[sample.signature] = sample.material # retain renderer resources across entries
	_fx_warmed[_context] = true
	viewport.free()
	_samples.clear()

## Kept separate so the real scene/skin/FX setup is checked with the dummy
## renderer too. Only render() records a signature as successfully drawn.
func prepare(island: Node3D) -> SubViewport:
	_context = [island.get_viewport().msaa_3d, island.sun.shadow_enabled]
	_collect(island)
	_skin_variants(island)
	# FX are normally created only on first use. Build them in the warm-up world.
	var viewport := SubViewport.new()
	viewport.name = "PipelineWarmup"
	viewport.size = Vector2i(128, 128)
	viewport.own_world_3d = true
	viewport.msaa_3d = island.get_viewport().msaa_3d
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	island.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = island.world_env.environment
	scene.add_child(environment)
	var sun: DirectionalLight3D = island.sun.duplicate()
	scene.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 16.0
	cam.position = Vector3(0, 0, 30)
	cam.far = 100.0
	cam.current = true
	scene.add_child(cam)
	if not _fx_warmed.has(_context):
		var fx := Node3D.new()
		scene.add_child(fx)
		preload("res://game/actors/flame_fx.gd").flame_cone(fx, Vector3.ZERO, Vector3.FORWARD)
		var dig := preload("res://game/stage/dig_site.gd").new()
		var soil = dig._soil_burst()
		fx.add_child(soil)
		soil.emitting = true
		dig.free()
		_collect(fx)
	var columns := ceili(sqrt(float(maxi(1, _samples.size()))))
	var cell := 14.0 / columns
	for i in _samples.size():
		var sample: Dictionary = _samples[i]
		var mesh: Mesh = sample.mesh
		var geometry: GeometryInstance3D
		if sample.multi:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = sample.get("colors", false)
			mm.use_custom_data = sample.get("custom", false)
			mm.mesh = mesh
			mm.instance_count = 1
			mm.set_instance_transform(0, Transform3D.IDENTITY)
			if mm.use_colors:
				mm.set_instance_color(0, Color.WHITE)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			geometry = instance
		else:
			var instance := MeshInstance3D.new()
			instance.mesh = mesh
			geometry = instance
		geometry.material_override = sample.material
		geometry.cast_shadow = sample.source.cast_shadow
		var bounds := mesh.get_aabb()
		var fit := cell * 0.75 / maxf(bounds.size.length(), 0.001)
		var slot := Node3D.new()
		slot.scale = Vector3.ONE * fit
		slot.position = Vector3((i % columns + 0.5) * cell - 7, (i / columns + 0.5) * cell - 7, 0) - bounds.get_center() * fit
		scene.add_child(slot)
		slot.add_child(geometry)
		if sample.skin != null:
			var original = sample.source.get_node_or_null(sample.source.skeleton)
			if original is Skeleton3D:
				var skeleton := Skeleton3D.new()
				for bone in original.get_bone_count():
					skeleton.add_bone(original.get_bone_name(bone))
				for bone in original.get_bone_count():
					skeleton.set_bone_parent(bone, original.get_bone_parent(bone))
					skeleton.set_bone_rest(bone, original.get_bone_rest(bone))
				slot.add_child(skeleton)
				geometry.skin = sample.skin
				geometry.skeleton = geometry.get_path_to(skeleton)
	return viewport
