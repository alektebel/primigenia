extends Node3D
## A small lit stage for the test rigs: striped ground following a height
## function, a light, and a camera that tracks the creature.

const Rig = preload("capsule_rig.gd")
const Ctl = preload("../loco_controller.gd")
const Bodies = preload("bodies.gd")

var rig
var ctl
var camera: Camera3D
var ground_fn: Callable = func(_x, _z): return 0.0
var pos := Vector3.ZERO
var yaw := 0.0
var view := "side"       # side | quarter
var _ground: MeshInstance3D

func setup(plan: String, ground: Callable = Callable(), cam_view := "side") -> void:
	if ground.is_valid():
		ground_fn = ground
	view = cam_view
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.72, 0.82, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.9)
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, -140.0, 0.0)
	sun.light_energy = 1.1
	add_child(sun)
	rig = Rig.new()
	add_child(rig)
	rig.build(Bodies.get_body(plan))
	ctl = Ctl.new(rig.morph, ground_fn)
	rig.wave_fn = ctl.wave_offset
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	_build_ground()
	ctl.reset(pos, yaw)
	frame()

func _build_ground() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = max(rig.morph.hip_height, 0.15)
	var cell := 0.25 * h
	var nx := 28
	var nz := 700
	for iz in range(nz):
		for ix in range(nx):
			var x0 := (ix - nx / 2.0) * cell * 3.0
			var z0 := (iz - 40) * cell
			var dark: bool = (iz / 4 + ix) % 2 == 0
			var col := Color(0.42, 0.55, 0.36) if dark else Color(0.5, 0.63, 0.42)
			var q := [Vector3(x0, 0, z0), Vector3(x0 + cell * 3.0, 0, z0), Vector3(x0 + cell * 3.0, 0, z0 + cell), Vector3(x0, 0, z0 + cell)]
			for v in range(4):
				q[v].y = ground_fn.call(q[v].x, q[v].z)
			for t in [0, 2, 1, 0, 3, 2]:
				st.set_color(col)
				st.add_vertex(q[t])
	st.generate_normals()
	_ground = MeshInstance3D.new()
	_ground.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_ground.material_override = m
	add_child(_ground)

func advance(dt: float, speed: float, yaw_rate := 0.0) -> void:
	yaw += yaw_rate * dt
	var vel := Vector3(sin(yaw), 0.0, cos(yaw)) * speed
	pos += vel * dt
	ctl.step(dt, pos, yaw, vel)
	frame()

func frame() -> void:
	rig.loco_apply(ctl.pose)
	var m = rig.morph
	var size: float = max(m.body_length * 1.25, m.hip_height * 2.6)
	var top := 0.0
	for s in rig.desc.spine:
		top = max(top, s.pos.y + s.radius)
	size = max(size, top * 1.25)
	var c := Vector3(pos.x, ground_fn.call(pos.x, pos.z) + top * 0.5, pos.z) + Basis(Vector3.UP, yaw) * Vector3(0, 0, m.com.z)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	if view == "side":
		camera.global_position = c + Basis(Vector3.UP, yaw) * Vector3(-10.0, 0.6, 0.0)
	else:
		camera.global_position = c + Basis(Vector3.UP, yaw) * Vector3(-7.0, 4.0, 6.0)
	camera.look_at(c, Vector3.UP)
