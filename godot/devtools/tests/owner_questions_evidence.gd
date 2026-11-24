extends SceneTree
# Software-GL screenshots of the owner questions: a card on a bright sky and at night, the F10 HUD on a bright sky, the pause-menu list.
# Usage: xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/tests/owner_questions_evidence.gd -- <output dir> <questions dir> <queue json>

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
	out_dir = args[0] if args.size() > 0 else "/tmp/owner-questions-evidence"
	var qdir: String = args[1] if args.size() > 1 else "/tmp/owner-questions-queue"
	DirAccess.make_dir_recursive_absolute(out_dir)
	DirAccess.make_dir_recursive_absolute(qdir)
	if args.size() > 2:
		DirAccess.copy_absolute(args[2], qdir.path_join("pending.json"))
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	var dev = root.get_node("Dev")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 600:
		await process_frame
		if game.stage != null and dev.sites != null:
			break
	await settle(30)
	var card = dev.questions
	card.base_dir = qdir
	card.reload()
	print("pending questions loaded: ", card.pending_count())
	var tn = dev.tuning
	tn.set_option("light", "day")
	await settle(40)
	print("ask: ", card.ask("loop-04-buggy"), " card: ", card.current.get("id", ""))
	await shot("card-day.jpg")
	card.hide_card()
	tn.set_option("light", "night")
	await settle(40)
	card.ask("loop-01-walk")
	await shot("card-night.jpg")
	card.hide_card()
	tn.set_option("light", "day")
	await settle(40)
	key(KEY_F10)
	key(KEY_3)
	await settle(10)
	await shot("f10-hud-day.jpg")
	key(KEY_ESCAPE)
	tn.set_choice("path", "on")
	await settle(10)
	await shot("f10-corner-line-day.jpg")
	tn.set_choice("path", "off")
	var ui = game.get_tree().current_scene.stage_ui.ui
	ui.set_paused(true)
	await settle(30)
	ui.show_questions()
	await settle(10)
	await shot("pause-list.jpg")
	quit(0)
