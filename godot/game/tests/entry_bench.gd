extends SceneTree
# Island entry times (brief creature-fixes 5): cold start, menu -> island again, studio -> "Jugar con esta criatura" -> island, after a load.
# nice -n 10 godot --headless --path godot --script res://game/tests/entry_bench.gd   (or under xvfb-run with software GL)
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var game
var capture := ""

func _initialize() -> void:
	_run.call_deferred()

func until(cond: Callable, frames: int = 6000) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return false

func _on_island() -> bool:
	return current_scene != null and current_scene.get("stage_ui") != null and game.stage != null and not current_scene._building

func _scene_is(name: String) -> bool:
	return current_scene != null and current_scene.scene_file_path.contains(name)

func _run() -> void:
	game = root.get_node("Game")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("capture="):
			capture = arg.substr(8)
	if capture != "":
		Engine.time_scale = 0.0
		game.island_ready.connect(_freeze_nest, CONNECT_ONE_SHOT)
	game.persist_settings = false
	game.settings.grass = 20000
	game.studio_dir = "user://entry-bench"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.studio_dir))
	var fails := 0
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island("cold")
	if not await until(_on_island):
		print("FAIL: cold entry never finished")
		quit(1)
		return
	await until(func(): return false, 5)
	if capture != "":
		if DisplayServer.get_name() == "headless":
			printerr("capture needs a rendering display")
			quit(1)
			return
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(capture, 0.95)
		print("nest capture: ", capture)
		quit()
		return
	# island -> menu -> island again
	game.goto_menu()
	await until(func(): return _scene_is("main_menu"))
	await until(func(): return false, 10)
	game.goto_island("menu again")
	if not await until(func(): return _on_island() and game.entry_log.size() >= 2):
		printerr("FAIL: menu re-entry never finished")
		quit(1)
		return
	await until(func(): return false, 5)
	# island -> studio -> Jugar con esta criatura
	game.goto_studio()
	await until(func(): return _scene_is("studio") and "model" in current_scene and current_scene.model != null)
	await until(func(): return false, 10)
	var studio = current_scene
	studio.model.set_name_("Bench Creature")
	studio.play_with_creature()
	if not await until(func(): return _on_island() and game.entry_log.size() >= 3):
		printerr("FAIL: studio re-entry never finished")
		quit(1)
		return
	await until(func(): return false, 5)
	# the same island again from the island: the in-game load path keeps working (props are not rebuilt)
	print("--- entry log")
	for row in game.entry_log:
		var parts: PackedStringArray = []
		for k in row.phases:
			parts.append("%s %d" % [k, int(row.phases[k])])
		print("%-12s %5d ms  [%s]" % [row.from, row.ms, ", ".join(parts)])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.studio_dir).path_join("bench_creature.json"))
	quit(fails)

# Freeze synchronously at island_ready, before the first gameplay tick. This
# optional path lets before/after builds capture the same initial nest pose.
func _freeze_nest() -> void:
	game.stage.paused = true
	var island = current_scene
	_freeze_node(island)
	island.stage_ui.ui.visible = false
	if game.veil != null and is_instance_valid(game.veil):
		game.veil.visible = false
	island.day_night.apply_state(game.stage.cur)
	island.day_night.k = island.day_night._light
	island.day_night.update_now()

func _freeze_node(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze_node(child)
