extends Node3D
## Quiet creator stage. Floor is the creature's rest floor; the plinth top is y=0.
## No foreground scatter. Test locomotion keeps its existing circular path on the ground.
const ENV_SCRIPT := "res://game/island/environment.gd"
const INC := "res://game/shaders/look.gdshaderinc"
const PATH_CENTER := Vector2(-7.0, 0.0)
const PATH_RADIUS := 7.0
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var ground: MeshInstance3D
var grass: MultiMeshInstance3D  # interface retained; deliberately absent in the creator
var rocks: Node3D
var mountains: Node3D
var pedestal: Node3D
var full := false

static func available() -> bool:
	return ResourceLoader.exists(ENV_SCRIPT) and ResourceLoader.exists(INC)

func _ready() -> void:
	if ResourceLoader.exists("res://creature/render_tier.gd"):
		load("res://creature/render_tier.gd").apply_viewport(get_viewport())

func _init(_blade_count := 0) -> void:
	name = "StudioEnv"
	full = available()
	world_env = WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("668faa")
	sky_mat.sky_horizon_color = Color("c6d8d5")
	sky_mat.ground_horizon_color = Color("c6d8d5")
	sky_mat.ground_bottom_color = Color("7c9185")
	sky.sky_material = sky_mat
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c1d4df")
	e.ambient_light_energy = .65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_mode = Environment.FOG_MODE_DEPTH
	e.fog_light_color = Color("c6d8d5")
	e.fog_depth_begin = 45.0
	e.fog_depth_end = 520.0
	world_env.environment = e
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -35, 0)
	sun.light_color = Color("fff0d7")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35.0
	sun.directional_shadow_blend_splits = true
	add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 145, 0)
	rim.light_color = Color("c7e2ed")
	rim.light_energy = .65
	add_child(rim)
	ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1500, 1500)
	ground.mesh = plane
	ground.material_override = _mat(Color("71816a"))
	ground.position.y = -.38
	add_child(ground)
	pedestal = Node3D.new()
	pedestal.name = "Pedestal"
	add_child(pedestal)
	_disc(1.0, .16, -.08, Color("b5b9af"))
	_disc(1.04, .09, -.205, Color("88978e"))
	_disc(1.09, .12, -.31, Color("a0aaa0"))
	_build_mountains()
	_build_trees()

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = .96
	return m

func _disc(radius: float, height: float, y: float, c: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 96
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position.y = y
	mi.material_override = _mat(c)
	pedestal.add_child(mi)

func set_extent(box: AABB) -> void:
	var radius := maxf(1.2, Vector2(box.size.x, box.size.z).length() * .65)
	pedestal.scale = Vector3(radius, 1, radius)
	pedestal.position.z = box.get_center().z

func set_test_mode(on: bool) -> void:
	pedestal.visible = not on
	ground.position.y = 0.0 if on else -.38

func set_floor(y: float) -> void:
	position.y = y

func _build_trees() -> void:
	# Sparse trees beyond the entire orbit, never between camera and subject.
	for i in 9:
		var a := float(i) * TAU / 9.0 + .35
		var tree := Node3D.new()
		tree.position = Vector3(sin(a) * 65, -.38, cos(a) * 65)
		var trunk := MeshInstance3D.new()
		var stem := CylinderMesh.new()
		stem.top_radius = .32
		stem.bottom_radius = .55
		stem.height = 6
		trunk.mesh = stem
		trunk.position.y = 3
		trunk.material_override = _mat(Color("626857"))
		tree.add_child(trunk)
		var crown := MeshInstance3D.new()
		var leaves := SphereMesh.new()
		leaves.radius = 3.5
		leaves.height = 8
		leaves.radial_segments = 16
		leaves.rings = 8
		crown.mesh = leaves
		crown.position.y = 7
		crown.material_override = _mat(Color("647d68"))
		tree.add_child(crown)
		add_child(tree)

func _build_mountains() -> void:
	mountains = Node3D.new()
	mountains.name = "Mountains"
	add_child(mountains)
	for cfg in [[250.0, 55.0, "#52604a", 3.0], [380.0, 120.0, "#4b5870", 8.0], [520.0, 200.0, "#5a6688", 15.0]]:
		var R: float = cfg[0]
		var hh: float = cfg[1]
		var sd: float = cfg[3]
		var n := 420
		var pos := PackedVector3Array()
		var idx := PackedInt32Array()
		for i in n + 1:
			var a := float(i) / n * TAU
			var h := hh * (.45 + .3 * sin(a * 3 + sd) + .22 * sin(a * 7 + sd * 2) + .12 * sin(a * 13 + sd) + .07 * sin(a * 29 + sd * 3) + .04 * sin(a * 61 + sd))
			pos.append(Vector3(sin(a) * R, -4, cos(a) * R))
			pos.append(Vector3(sin(a) * (R + hh * .6), h, cos(a) * (R + hh * .6)))
		for i in n:
			var a := i * 2
			idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 2, a + 1, a + 3]))
		var nrm := PackedVector3Array()
		nrm.resize(pos.size())
		for t in range(0, idx.size(), 3):
			var fn := (pos[idx[t + 1]] - pos[idx[t]]).cross(pos[idx[t + 2]] - pos[idx[t]])
			for q in 3:
				nrm[idx[t + q]] += fn
		for i in nrm.size():
			nrm[i] = nrm[i].normalized()
			if nrm[i].y < 0:
				nrm[i] = -nrm[i]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = pos
		arr[Mesh.ARRAY_NORMAL] = nrm
		arr[Mesh.ARRAY_INDEX] = idx
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(cfg[2])
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mountains.add_child(mi)
