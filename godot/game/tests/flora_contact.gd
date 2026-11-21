extends SceneTree
# Contact sheet of the food-web batch plants (JPG, software GL under xvfb):
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1600x500 --path godot \
#     --script res://game/tests/flora_contact.gd -- <out.jpg> [id,id,...]
# Meshes are drawn at one display size (not true height) so moss and algae films are legible.

const Placement := preload("res://game/island/flora_placement.gd")
const Generator := preload("res://game/island/flora_mesh.gd")
const IDS := ["cancro_madera","ceniza_ciega","cicatriz_alta","drifting_ash","manto_negro","pozo_de_agua","sangre_de_hierro","suspiro"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "foodweb-flora.jpg"
	var ids: Array = Array(args[1].split(",")) if args.size() > 1 else IDS
	var rows := {}
	for r in Placement.recipes():
		rows[r.id] = r
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 8)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("5a5448")
	gm.roughness = 1.0
	ground.material_override = gm
	root.add_child(ground)
	for i in ids.size():
		var m := MeshInstance3D.new()
		m.mesh = Generator.new().plant(rows[ids[i]], 7, true)
		var size := 1.6
		m.scale = Vector3.ONE * size
		m.position = Vector3((i - (ids.size() - 1) * 0.5) * 2.3, 0.02, 0)
		root.add_child(m)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a9b0b3")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("9a9a9a")
	root.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 4.2, 8.5)
	root.add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0))
	for i in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out, 0.9)
	print("wrote ", out)
	quit(0)
