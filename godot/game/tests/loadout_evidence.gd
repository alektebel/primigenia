extends SceneTree
# make godot-loadout-evidence: software screenshots of the hotbar and the loadout panel (A21), xvfb.
# Usage: godot ... --script res://game/tests/loadout_evidence.gd -- <output dir>
# The stock creature only knows bite and charge (hotbar_real.png is its real C loadout); the other shots feed the HUD a four-move kit (one move per role the
# build ships) to show every role colour; the first slot also shows a cooldown sweep at 60 % (no shipped move has a
# cooldown yet, so the sweep is driven by hand here).

const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/loadout-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 600:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	var sui = island.stage_ui
	var ui = sui.ui
	await shot("hotbar_real.png")          # the real C loadout of the stock creature: bite and charge
	game.stage.paused = true               # from here the HUD is fed by hand, so no tick rebuilds it
	var kit := [
		{"id": "bite", "name": "Bite", "move": 0, "role": "basic", "stamina": 9, "cooldown": 0},
		{"id": "charge", "name": "Charge", "move": 1, "role": "engage", "stamina": 18, "cooldown": 0},
		{"id": "spit", "name": "Spit", "move": 3, "role": "poke", "stamina": 12, "cooldown": 0},
		{"id": "tail_strike", "name": "Tail", "move": 4, "role": "control", "stamina": 10, "cooldown": 50},
	]
	ui.set_loadout_abilities(kit)
	ui.set_cooldowns([0.0, 0.0, 0.0, 0.6])
	await shot("hotbar.png")
	var lo: Dictionary = game.stage.cur.loadout
	ui.loadout_panel.refresh(lo)
	ui.loadout_panel.open_panel()
	await shot("loadout_panel.png")
	quit(0)
