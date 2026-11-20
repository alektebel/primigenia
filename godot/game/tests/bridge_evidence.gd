extends SceneTree
## Evidence of the cell -> creature bridge (software GL under xvfb): the end card with the new button, the mid-fade, the first island frames
## with the whisper, the menu's Criatura card with and without a legacy.
## LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/bridge_evidence.gd -- <out dir>

var out_dir := ""
var game

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.92)
	print("wrote ", name, " ", img.get_size())

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/bridge-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings["language"] = "es"
	game.settings.grass = 20000
	game.legacy_path = "user://cell_legacy_bridge_evidence.json"
	root.size = Vector2i(1280, 720)
	var Legacy = load("res://cell/cell_legacy.gd")
	var legacy := {"version": 1, "source": "colony", "diet": "cazador", "defense": "espinas", "size_class": "medium",
		"stats": {"atp_min": 170, "mem": 98, "tier": 3, "colony_cells": 7}, "tally": {"waste_share": 0.1, "spines": 4, "plates": 3}}
	# 1. the end card
	var st = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(st)
	current_scene = st
	await settle(3)
	st.sim.demo()
	st.advance(4.0)
	st.jump_to_end(legacy)
	await create_timer(0.6).timeout
	await shot("end_card")
	st._leg_cont.emit_signal("pressed")
	await create_timer(0.25).timeout
	await shot("fade_mid")
	# 2. the island, first frames (the fade ended in the scene change)
	await create_timer(0.4).timeout
	var tries := 0
	while not (current_scene != null and current_scene.scene_file_path.ends_with("island.tscn") and game.stage != null and game.stage.cur.has("tick") and int(game.stage.cur.tick) >= 3) and tries < 4000:
		await process_frame
		tries += 1
	await create_timer(1.2).timeout
	await shot("island_first_frames_whisper")
	var isl = current_scene
	# the family tree with the cell as its root
	for c in isl.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("lineage_controller.gd"):
			c.open()
	await create_timer(0.8).timeout
	await shot("family_tree_root")
	# 3. the menu card
	Legacy.save(legacy, game.legacy_path)
	game.goto_menu()
	await create_timer(1.5).timeout
	await shot("menu_card_legacy")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.legacy_path))
	quit()
