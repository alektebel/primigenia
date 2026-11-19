extends SceneTree
# Stage menu screenshots (software GL under xvfb). make godot-menu-evidence  /  ... -- <out dir>
# Three window sizes x states: rest, Criatura hovered, Celula focused (drawn as playable), Celula missing (as on this branch alone).

var out_dir := ""
var MenuScene: PackedScene

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.9)
	print("wrote ", name, " ", img.get_size())

func _menu(assume_cell: bool) -> Control:
	var m: Control = MenuScene.instantiate()
	m.assume_cell_scene = assume_cell
	root.add_child(m)
	await create_timer(0.7).timeout       # past the entrance
	return m

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/stage-menu"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "es"
	MenuScene = load("res://game/menu/main_menu.tscn")
	for sz in [Vector2i(1024, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = sz
		await settle(4)
		var tag := "%dx%d" % [sz.x, sz.y]
		var m: Control = await _menu(true)
		await shot("rest_" + tag)
		m._hover(m.play_button, true)
		await create_timer(0.3).timeout
		await shot("creature_hover_" + tag)
		m._hover(m.play_button, false)
		m.cell_button.grab_focus()
		await create_timer(0.1).timeout
		await shot("cell_focus_" + tag)
		m.queue_free()
		await settle(3)
		var m2: Control = await _menu(false)
		await shot("cell_missing_" + tag)
		m2.queue_free()
		await settle(3)
	quit()
