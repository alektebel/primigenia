extends SceneTree
# The cumulus layer seen from the ground at three pitches / headings (brief creature-fixes 3), frozen wind.
# LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/clouds_evidence.gd -- <out dir> <prefix>
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Clouds := preload("res://game/island/clouds.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var prefix := args[1] if args.size() > 1 else "clouds"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(20)
	var island = current_scene
	island.chase_enabled = false
	island.stage_ui.ui.visible = false
	Clouds.frozen_time = 600.0
	Clouds.apply({"tod": 0.5, "cover": 0.75, "fog": 0.0})
	var cam: Camera3D = island.debug_camera
	var p: Vector3 = island.player_pos + Vector3(0, 3, 0)
	var views := [["a", 0.0, 0.35, 3.0], ["e", 3.6, 0.55, 3.0]]
	for v in views:
		cam.global_position = p + Vector3(0, v[3] - 3.0, 0)
		cam.rotation = Vector3(v[2], v[1], 0)
		cam.fov = 70.0
		await settle(10)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join("%s_%s.jpg" % [prefix, v[0]]), 0.92)
		print("saved ", v[0])
	quit()
