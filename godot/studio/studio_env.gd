extends Node3D
## The scene around the creature in the studio (port of the web studio's stage): hero sky with sun, ground with the
## circular dirt path, wind grass, rocks, three mountain rings, warm sun with shadows.
## Uses the game's public files (game/island/environment.gd, look.gd, shaders/sky + look include) when they exist;
## in a standalone studio project it falls back to a plain background.

const ENV_SCRIPT := "res://game/island/environment.gd"
const INC := "res://game/shaders/look.gdshaderinc"
const FOG := Color(0.93, 0.74, 0.56)
const PATH_CENTER := Vector2(-7.0, 0.0)
const PATH_RADIUS := 7.0

var world_env: WorldEnvironment
var sun: DirectionalLight3D
var ground: MeshInstance3D
var grass: MultiMeshInstance3D
var rocks: Node3D
var mountains: Node3D
var full := false

static func available() -> bool:
	return ResourceLoader.exists(ENV_SCRIPT) and ResourceLoader.exists(INC)

func _ready() -> void:
	if ResourceLoader.exists("res://creature/render_tier.gd"):
		load("res://creature/render_tier.gd").apply_viewport(get_viewport())

func _init(blade_count := 52000) -> void:
	name = "StudioEnv"
	full = available()
	world_env = WorldEnvironment.new()
	if full:
		var E = load(ENV_SCRIPT)
		var env: Environment = E.make_environment()
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = FOG
		env.fog_depth_begin = 60.0
		env.fog_depth_end = 700.0
		env.fog_sky_affect = 0.0
		world_env.environment = env
		sun = E.make_sun()
		sun.directional_shadow_max_distance = 45.0
	else:
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color("1b3446")
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color("a9c4d0")
		e.ambient_light_energy = .7
		world_env.environment = e
		sun = DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50, 35, 0)
		sun.light_color = Color("ffe2b8")
	add_child(world_env)
	add_child(sun)
	if not full:
		return
	_build_ground()
	_build_grass(blade_count)
	_build_rocks()
	_build_mountains()

func _build_ground() -> void:
	ground = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1500, 1500)
	ground.mesh = pm
	var m := ShaderMaterial.new()
	m.shader = load("res://studio/shaders/studio_ground.gdshader") if ResourceLoader.exists("res://studio/shaders/studio_ground.gdshader") else null
	ground.material_override = m
	ground.position.y = -0.0
	add_child(ground)

## y of the floor in view space is set by the studio (creature ground_offset); the env sits on y = 0 of its own space.
func set_floor(y: float) -> void:
	position.y = y

func _build_grass(n: int) -> void:
	var sh = load("res://studio/shaders/studio_grass.gdshader")
	if sh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-.5, 0, 0), Vector3(.5, 0, 0), Vector3(-.34, .5, 0), Vector3(.34, .5, 0), Vector3(0, 1, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 2, 1, 3, 2, 3, 4])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	var buf := PackedFloat32Array()
	var R := 48.0
	var k := 0
	var tries := 0
	while k < n and tries < n * 3:
		tries += 1
		var an := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * R
		var gx := sin(an) * rr
		var gz := cos(an) * rr
		var r := Vector2(gx, gz).distance_to(PATH_CENTER)
		if r > 5.5 and r < 8.5:
			continue
		var e := minf(absf(r - 5.5), absf(r - 8.5))
		var hs := (.35 + rng.randf() * .6) * (.45 + .55 * smoothstep(0.0, 2.5, e))
		# identity transform (12 floats) + custom data (x, z, random, height)
		buf.append_array(PackedFloat32Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, gx, gz, rng.randf(), hs]))
		k += 1
	mm.instance_count = k
	mm.buffer = buf
	grass = MultiMeshInstance3D.new()
	grass.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = sh
	grass.material_override = m
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	grass.custom_aabb = AABB(Vector3(-60, -1, -60), Vector3(120, 4, 120))
	add_child(grass)

func _lerp_c(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, t)

func _rock(rng: RandomNumberGenerator, x: float, z: float, s: float, sy: float, mat: Material) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 24
	sm.rings = 14
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var o := rng.randf() * 50.0
	for i in v.size():
		var p := v[i]
		var d := 1.0 + .22 * sin(p.x * 3 + o) * cos(p.z * 2.6 + o) + .13 * sin(p.y * 5 + p.x * 4 + o)
		v[i] = Vector3(p.x * d, p.y * d * sy, p.z * d)
	arr[Mesh.ARRAY_VERTEX] = v
	var nrm := PackedVector3Array()
	nrm.resize(v.size())
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var fn := (v[idx[t + 1]] - v[idx[t]]).cross(v[idx[t + 2]] - v[idx[t]])
		for q in 3:
			nrm[idx[t + q]] += fn
	var cols := PackedColorArray()
	var gr := Color("6f675c")
	var ms := Color("4a5a28")
	for i in v.size():
		nrm[i] = nrm[i].normalized()
		var tt := smoothstep(.55, .9, nrm[i].y)
		var f := .8 + .3 * rng.randf()
		var c := gr.lerp(ms, tt)
		cols.append(Color(c.r * f, c.g * f, c.b * f))
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = Vector3(x, s * sy * .25, z)
	mi.scale = Vector3.ONE * s
	mi.rotation.y = rng.randf() * 6.0
	rocks.add_child(mi)

func _build_rocks() -> void:
	rocks = Node3D.new()
	rocks.name = "Rocks"
	add_child(rocks)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = .92
	_rock(rng, -7, 0, 1.7, .75, mat)
	_rock(rng, -5.1, .9, .8, .7, mat)
	_rock(rng, -8.5, 1.4, .6, .6, mat)
	for i in 34:
		var a := rng.randf() * TAU
		var r := 11.0 + rng.randf() * 30.0
		var qx := -7.0 + sin(a) * r
		var qz := cos(a) * r
		if Vector2(qx, qz).length() < 19.0:
			continue
		_rock(rng, qx, qz, .5 + rng.randf() * rng.randf() * 3.2, .6 + rng.randf() * .5, mat)

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
