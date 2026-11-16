extends SceneTree
## Side-by-side evidence (Godot half): idle, palette hover, drag over the body, selected part, paint, test.
## LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
##   --script res://studio/tests/parity_shots.gd -- <out_dir>

const Studio := preload("../ui/studio.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	DirAccess.make_dir_recursive_absolute(out)
	var ui = Studio.new()
	root.add_child(ui)
	await _frames(90)                      # thumbnails bake one per frame
	_shot(out.path_join("godot-idle.png"))
	ui.select_category("weapons")
	await _frames(6)
	var id := "asta"
	ui._palette_hover(id, true)
	var b: Control = ui.palette_buttons[id]
	await _frames(30)
	_shot(out.path_join("godot-hover.png"))
	ui._palette_hover(id, false)
	# drag: press on the palette button, then move over the body
	ui._palette_input(_press(), id)
	var body_pt: Vector2 = ui.camera.unproject_position(ui.view.part_anchor_at(.62, 0.2)) + ui.stage.global_position
	ui._drag["moved"] = true
	ui._update_new_drag(body_pt)
	await _frames(6)
	ui._update_new_drag(body_pt + Vector2(2, 0))
	await _frames(6)
	_shot(out.path_join("godot-drag.png"))
	ui._finish_new_drag(body_pt)
	await _frames(70)
	_shot(out.path_join("godot-selected.png"))
	ui.set_mode("paint")
	await _frames(10)
	_shot(out.path_join("godot-paint.png"))
	ui.set_mode("test")
	ui.toggle_play()
	await _frames(90)
	_shot(out.path_join("godot-test.png"))
	quit()

func _press() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	return e

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(path: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
