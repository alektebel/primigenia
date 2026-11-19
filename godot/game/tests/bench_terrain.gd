extends SceneTree
# Terrain benchmark: godot --path godot --script res://game/tests/bench_terrain.gd -- <out dir> [tier] [frames] [warmup] [grass]
# (make godot-rock-bench; run it on the real GPU, windowed). vsync off, uncapped. Per view it prints the mean and p95 frame
# time and, when the backend reports it, the GPU render time. BENCH_VIEWS=chase,mid restricts the views. Writes <out dir>/bench-<tier>-<adapter>.json.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Views := preload("res://game/tests/rock_views.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/rock-bench"
	var tier: String = args[1] if args.size() > 1 else "auto"
	var frames: int = int(args[2]) if args.size() > 2 else 600
	var warm: int = int(args[3]) if args.size() > 3 else 120
	var grass: int = int(args[4]) if args.size() > 4 else 252000
	DirAccess.make_dir_recursive_absolute(out_dir)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	root.size = Vector2i(1920, 1080) if not RenderingServer.get_video_adapter_name().to_lower().contains("llvmpipe") else Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.settings.grass = grass
	game.settings.quality = tier
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	for i in 30:
		await process_frame
	var adapter := RenderingServer.get_video_adapter_name()
	print("island props: ", island.props.counts, " in ", island.props.get_child_count() - 1, " batches; nest ", island.props.get_node("Nest").position)
	var rid := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var result := {"adapter": adapter, "tier": tier, "frames": frames, "grass": grass, "resolution": [root.size.x, root.size.y], "views": {}}
	var views: PackedStringArray = OS.get_environment("BENCH_VIEWS").split(",", false) if OS.get_environment("BENCH_VIEWS") != "" else PackedStringArray(["chase", "mid", "far", "cliff_lit"])
	# BENCH_SET="name=value,..." sets float shader uniforms of the terrain materials (A/B runs without editing shaders).
	for kv in OS.get_environment("BENCH_SET").split(",", false):
		var kvp := kv.split("=")
		island.terrain_chunks.set_uniform(kvp[0], float(kvp[1]))
	if OS.get_environment("BENCH_ANISO") != "":
		root.anisotropic_filtering_level = int(OS.get_environment("BENCH_ANISO")) as Viewport.AnisotropicFiltering   # 0 off, 1 2x, 2 4x, 3 8x, 4 16x
	for v in views:
		Views.apply(island, game.data, v)
		for i in warm:
			await process_frame
		var ms := []
		var gpu := 0.0
		var t_prev := Time.get_ticks_usec()
		for i in frames:
			await process_frame
			var t := Time.get_ticks_usec()
			ms.append((t - t_prev) / 1000.0)
			t_prev = t
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		ms.sort()
		var mean := 0.0
		for m in ms:
			mean += m
		mean /= ms.size()
		var r := {"mean_ms": snappedf(mean, 0.01), "p95_ms": snappedf(ms[int(ms.size() * 0.95)], 0.01), "gpu_ms": snappedf(gpu / frames, 0.01)}
		result.views[v] = r
		print("%-10s mean %.2f ms  p95 %.2f ms  gpu %.2f ms  (%s, %s)" % [v, r.mean_ms, r.p95_ms, r.gpu_ms, tier, adapter])
	var safe := RegEx.create_from_string("[^a-z0-9]+").sub(adapter.to_lower().split(" (")[0], "-", true)
	var path := out_dir.path_join("bench-%s-%s.json" % [tier, safe])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
	f.close()
	print("wrote ", path)
	quit()
