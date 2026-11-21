extends SceneTree
# Software-GL screenshots of F10 option mode: the HUD on two groups and the corner line.
# Usage: xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/tests/options_evidence.gd -- <output dir>

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

func key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	root.get_node("Dev").options_hud.handle_key(e)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/options-evidence"
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
	var tn = dev.tuning
	print("options: ", tn.choice_order)
	# 1. Creature group open: starter cycled once (respawns the body), light jumped to dusk
	key(KEY_F10)
	key(KEY_2)
	key(KEY_RIGHT)
	await settle(40)
	print("starter now ", tn.choice_value("starter"), " blocked=", game.movement_blocked())
	await shot("options-creature.jpg")
	# 2. Light group: dusk
	key(KEY_4)
	key(KEY_RIGHT)
	key(KEY_RIGHT)
	key(KEY_RIGHT)
	await settle(10)
	await shot("options-light.jpg")
	# 3. closed: the corner line with the non-default choices
	key(KEY_ESCAPE)
	tn.set_choice("path", "on")
	await settle(20)
	print("line: ", tn.choices_line())
	await shot("options-corner-line.jpg")
	quit(0)
