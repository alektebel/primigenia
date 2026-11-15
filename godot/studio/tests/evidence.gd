extends SceneTree
## Evidence screenshots: xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --path godot/studio --rendering-driver opengl3 --script res://tests/evidence.gd -- <out_dir>

const Studio := preload("../ui/studio.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(out)
	var ui = Studio.new()
	root.add_child(ui)
	await _frames(6)
	var m = ui.model
	m.add_part("cuerno", .6, 1.0)           # selected, with handles
	m.set_param(m.selected, "tilt", .5)
	m.set_param(m.selected, "rot", .8)
	await _frames(6)
	_shot(out.path_join("build-part-selected.png"))
	ui.select_category("weapons")
	await _frames(4)
	_shot(out.path_join("palette-weapons.png"))
	ui.select_category("mouths")
	ui.set_mode("paint")
	m.apply_palette(2)
	m.set_skin("pat", 2)
	await _frames(6)
	_shot(out.path_join("paint.png"))
	ui.set_mode("test")
	ui.toggle_play()
	ui.set_lang("en")
	await _frames(6)
	_shot(out.path_join("test-en.png"))
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
