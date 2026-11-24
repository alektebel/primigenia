extends SceneTree
# make godot-evidence: screenshots + timings under docs/evidence/godot/m0 (software GL, xvfb).
# Usage: godot ... --script res://game/tests/m0_evidence.gd -- <output dir>

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const LoadingScene := preload("res://game/loading/loading_screen.tscn")

var out_dir := ""
var timings := {}
var game

func _initialize() -> void:
	_run.call_deferred()

func shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/m0-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")

	# 1. Loading screen on a forced miss (a throwaway seed so the real cache is untouched).
	var params := {"seed": 424242}
	var cache_file := TerrainCache.cache_path(params)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_file))
	var screen := LoadingScene.instantiate()
	root.add_child(screen)
	var done := [false]
	var gen_t0 := Time.get_ticks_msec()
	screen.finished.connect(func(entry: Dictionary) -> void: done[0] = true)
	screen.start(params)
	var captured := false
	while not done[0]:
		await process_frame
		if not captured and Time.get_ticks_msec() - gen_t0 > 1800:
			captured = true
			await shot("loading.png")
	timings["generate_and_store_ms"] = Time.get_ticks_msec() - gen_t0
	screen.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_file))

	# 2. Cache hit time for the real island (generate once if absent).
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	var t0 := Time.get_ticks_msec()
	entry = TerrainCache.load_entry(TerrainCache.game_params(1))
	timings["cache_hit_load_ms"] = Time.get_ticks_msec() - t0

	# 3. Island.
	game.settings.wild = false
	game.settings.grass = 60000
	game.set_island(entry)
	var IslandScene = load("res://game/island/island.tscn")
	t0 = Time.get_ticks_msec()
	var island: Node3D = IslandScene.instantiate()
	root.add_child(island)
	timings["island_build_ms"] = Time.get_ticks_msec() - t0
	await settle(45)
	await shot("chase.png")

	# Walking placeholder: hold W with sprint for a few seconds of game time.
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	await settle(70)
	# Side view of the stride (the chase view looks at the creature from behind).
	island.chase_enabled = false
	var pp: Vector3 = island.player_pos
	island.camera.position = pp + Vector3(9.0, 3.0, 2.0)
	island.camera.look_at(pp + Vector3(0, 1.6, 0))
	await settle(2)
	await shot("walk.png")
	island.chase_enabled = true
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}

	# Close: zoom to 2.8h.
	island.chase.zoom(-1000.0)
	await settle(45)
	await shot("close.png")
	island.chase.zoom(1000.0)

	# Free camera views.
	island.chase_enabled = false
	island.camera.position = Vector3(0, 900, 2600)
	island.camera.look_at(Vector3(0, 150, 0))
	island.terrain_chunks.update_lods(island.camera.global_position, true)
	await settle(3)
	await shot("far.png")

	var data = game.data
	var coast := Vector2(0, 0)
	var i: int = data.n / 2
	for j in range(data.n - 1, 0, -1):
		if data.height[j * data.n + i] > 0.3:
			coast = Vector2(data.cell_center(i), data.cell_center(j))
			break
	island.camera.position = Vector3(coast.x + 25.0, 10.0, coast.y + 45.0)
	island.camera.look_at(Vector3(coast.x, 1.0, coast.y))
	island.terrain_chunks.update_lods(island.camera.global_position, true)
	await settle(3)
	await shot("shore.png")

	island.camera.position = Vector3(0, 900, 2600)
	island.camera.look_at(Vector3(0, 150, 0))
	island.terrain_chunks.set_lod_debug(true)
	await settle(3)
	await shot("lod_debug.png")
	island.terrain_chunks.set_lod_debug(false)

	timings["triangles_far_view"] = island.terrain_chunks.triangle_count()
	timings["rendering_info_total_primitives"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	timings["note"] = "software GL (llvmpipe); grass 60000 blades for evidence; generation timed on a worker thread"
	var f := FileAccess.open(out_dir.path_join("timings.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(timings, "  "))
	f.close()
	print("timings ", timings)
	quit()
