extends SceneTree
# Re-entry from the kit looks the same as a cold entry, and the studio has "Jugar con esta criatura" (brief creature-fixes 5).
# LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/entry_evidence.gd -- <out dir>
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Clouds := preload("res://game/island/clouds.gd")
var game

func _initialize() -> void:
	_run.call_deferred()

func until(cond: Callable, frames: int = 2400) -> bool:
	for i in frames:
		if cond.call():
			return true
		await process_frame
	return false

func _on_island() -> bool:
	return current_scene != null and current_scene.get("stage_ui") != null and game.stage != null

func shot(out: String, name: String) -> void:
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(name), 0.9)
	print("saved ", name)

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 20000
	game.studio_dir = "user://entry-evidence"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(game.studio_dir))
	Clouds.frozen_time = 600.0
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island("cold")
	await until(_on_island)
	current_scene.chase_enabled = false
	current_scene.debug_camera.global_position = current_scene.player_pos + Vector3(8, 4, 8)
	current_scene.debug_camera.look_at(current_scene.player_pos + Vector3(0, 1, 0))
	await shot(out, "entry_cold.jpg")
	game.goto_studio()
	await until(func(): return current_scene != null and "model" in current_scene and current_scene.model != null)
	var studio = current_scene
	await shot(out, "studio_play_button.jpg")
	studio.model.set_name_("Evidence Creature")
	studio.play_with_creature()
	await until(func(): return _on_island() and game.entry_log.size() >= 2)
	current_scene.chase_enabled = false
	current_scene.debug_camera.global_position = current_scene.player_pos + Vector3(8, 4, 8)
	current_scene.debug_camera.look_at(current_scene.player_pos + Vector3(0, 1, 0))
	print("kit reused: ", current_scene.kit_reused, " build ms ", current_scene.build_ms)
	await shot(out, "entry_from_studio.jpg")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.studio_dir).path_join("evidence_creature.json"))
	quit()
