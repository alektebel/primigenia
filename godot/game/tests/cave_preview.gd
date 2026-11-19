extends SceneTree
# Cave interior preview on a plain scene (no island): the shell, the lights and the dark, from the mouth, the passage and the chamber.
# godot --rendering-driver opengl3 --path godot --script res://game/tests/cave_preview.gd -- <out dir>
const CaveSite := preload("res://game/island/cave_site.gd")
const DayNight := preload("res://game/island/day_night.gd")

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(960, 540)
	var site = CaveSite.from_state({"enabled": true, "x": 0.0, "z": 0.0, "fx": 0.0, "fz": 1.0, "floor": 10.0, "half": 4.0, "length": 14.0, "radius": 10.0, "chamber_x": 0.0, "chamber_z": -24.0})
	var scene := Node3D.new()
	root.add_child(scene)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.6, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.75, 0.92)
	env.ambient_light_energy = 1.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.926
	var we := WorldEnvironment.new()
	we.environment = env
	scene.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 4.4
	scene.add_child(sun)
	# a hillside in front of the cliff: a sloped box so the mouth sits in something
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	ground.position = Vector3(0, 10, 40)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.3, 0.45, 0.2)
	ground.material_override = gm
	scene.add_child(ground)
	site.build(scene)
	var dn = DayNight.new()
	dn.env = env
	dn.sun = sun
	scene.add_child(dn)
	var cam := Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.2
	scene.add_child(cam)
	cam.current = true
	var views := [
		["mouth", Vector3(9, 13, 24), Vector3(0, 11.5, 0), 0.0, 0.0],
		["passage", Vector3(0, 11.4, 3), Vector3(0, 11.2, -10), 0.0, 1.0],
		["chamber", Vector3(0, 11.6, -14), Vector3(0, 11.0, -26), 0.0, 1.0],
		["chamber_high", Vector3(3, 12.8, -17), Vector3(0, 11.0, -27), 0.0, 1.0],
	]
	for v in views:
		cam.position = v[1]
		cam.look_at(v[2])
		dn.force_light = 1.0
		dn._inside = v[4]
		dn.inside = v[4]
		dn.k = 1.0
		dn.update_now()
		await settle(6)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join("cave_preview_%s.jpg" % v[0]), 0.9)
	quit()
