extends SceneTree
# Software-GL screenshots of the N notes: overlay + hover, the N card, a pin pick, the Ctrl+N toast, the Shift+N browser. Usage:
# xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/tests/n_notes_evidence.gd -- <output dir> <scratch notes dir>

const TerrainCache := preload("res://game/island/terrain_cache.gd")
var out_dir := ""

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir.path_join(name), 0.9)
	print("wrote ", name)

func press(code: Key, ctrl := false, shift := false) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.ctrl_pressed = ctrl
		e.shift_pressed = shift
		e.pressed = down
		Input.parse_input_event(e)
		await process_frame

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/n-notes-evidence"
	var scratch: String = args[1] if args.size() > 1 else "/tmp/n-notes-scratch"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	var dev = root.get_node("Dev")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 600:
		await process_frame
		if game.stage != null and dev.sites != null:
			break
	await settle(30)
	for n in [dev.note_card, dev.browser, dev.flag]:
		n.base_dir = scratch
	print("spawn: ", dev.console.registry.execute("spawn garfio").out)
	await settle(60)
	var scene := current_scene
	var ents: Array = game.stage.cur.entities
	var e: Dictionary = ents[ents.size() - 1]
	var sp: Vector2 = scene.camera.unproject_position(Vector3(e.x, game.visual_ground(e.x, e.z) + 0.6, e.z))
	root.warp_mouse(sp)
	await press(KEY_F11)
	await settle(40)
	await shot("1-overlay-hover.jpg")
	# N: the frame is grabbed first, then the card
	await press(KEY_N)
	print("card open: ", dev.note_card.is_open, " paused: ", game.stage.paused)
	dev.note_card._text.text = "legs cross when it turns toward the water"
	await press(KEY_2, true)
	await press(KEY_3, true)
	await settle(4)
	await shot("2-card.jpg")
	# pin mode: pick the creature under the cursor
	await press(KEY_P, true)
	root.warp_mouse(sp)
	await settle(10)
	await shot("3-pin-pick.jpg")
	var pinned: bool = dev.note_card.pin_at(sp)
	print("pinned: ", pinned, " ", dev.note_card.target.get("name"))
	await press(KEY_ENTER)
	await settle(6)
	print("saved: ", dev.note_card.last_saved, " open: ", dev.note_card.is_open, " paused: ", game.stage.paused)
	await shot("4-saved-toast.jpg")
	# two more: a quick note and a typed state note
	await press(KEY_N, true)
	await settle(2)
	await shot("5-quick-toast.jpg")
	await press(KEY_N)
	dev.note_card._text.text = "the camera clips the slope here"
	await press(KEY_ENTER)
	await settle(3)
	await press(KEY_F11)
	await press(KEY_N, false, true)
	await settle(40)
	print("browser: ", dev.browser.is_open, " rows ", dev.browser.rows.size())
	await shot("6-browser.jpg")
	dev.browser.select(1)
	await settle(4)
	await shot("7-browser-second.jpg")
	await press(KEY_ESCAPE)
	print("browser closed: ", not dev.browser.is_open, " paused: ", game.stage.paused)
	# sample files
	var d := DirAccess.open(scratch)
	for sub in d.get_directories():
		var n = JSON.parse_string(FileAccess.get_file_as_string(scratch.path_join(sub).path_join("note.json")))
		if n.text.begins_with("legs cross"):
			DirAccess.make_dir_recursive_absolute(out_dir.path_join("note-sample"))
			for f in ["note.json", "crop.jpg", "scenario.json"]:
				DirAccess.copy_absolute(scratch.path_join(sub).path_join(f), out_dir.path_join("note-sample").path_join(f))
			print("files: ", DirAccess.open(scratch.path_join(sub)).get_files())
	quit(0)
