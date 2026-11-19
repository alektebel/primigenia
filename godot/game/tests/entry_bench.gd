extends SceneTree
# Island entry times (brief creature-fixes 5): cold start, menu -> island again, studio -> "Jugar con esta criatura" -> island, after a load.
# nice -n 10 godot --headless --path godot --script res://game/tests/entry_bench.gd   (or under xvfb-run with software GL)
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var game

func _initialize() -> void:
	_run.call_deferred()

func until(cond: Callable, frames: int = 1800) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return false

func _on_island() -> bool:
	return current_scene != null and current_scene.get("stage_ui") != null and game.stage != null

func _scene_is(name: String) -> bool:
	return current_scene != null and current_scene.scene_file_path.contains(name)

func _run() -> void:
	game = root.get_node("Game")
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
	# island -> menu -> island again
	game.goto_menu()
	await until(func(): return _scene_is("main_menu"))
	await until(func(): return false, 10)
	game.goto_island("menu again")
	await until(func(): return _on_island() and game.entry_log.size() >= 2)
	await until(func(): return false, 5)
	# island -> studio -> Jugar con esta criatura
	game.goto_studio()
	await until(func(): return _scene_is("studio") and "model" in current_scene and current_scene.model != null)
	await until(func(): return false, 10)
	var studio = current_scene
	studio.model.set_name_("Bench Creature")
	studio.play_with_creature()
	await until(func(): return _on_island() and game.entry_log.size() >= 3)
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
