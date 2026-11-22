extends SceneTree
## Exclusive buckets; loading/warmup excluded. Fixed sim step for comparable C workload.
const Profile := preload("res://devtools/frame_profile.gd")
const Scenario := preload("res://devtools/scenario.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
var frames := 600
var warm_frames := 120
var scenario_name := "nest_start"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("frames="):
			frames = maxi(1, int(arg.trim_prefix("frames=")))
		if arg.begins_with("scenario="):
			scenario_name = arg.trim_prefix("scenario=")
		if arg.begins_with("warm="):
			warm_frames = maxi(1, int(arg.trim_prefix("warm=")))
		if arg == "baseline":
			preload("res://game/actors/actor_host.gd").visual_lod_enabled = false
			preload("res://locomotion/loco_rig_adapter.gd").yaw_only = false
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	game.settings.wild = true
	root.size = Vector2i(1280, 720)
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	for scenario in [scenario_name]:
		var parsed := Scenario.read("creature/" + scenario) if scenario != "nest_all" else {"ok": true}
		if not parsed.ok:
			printerr(parsed.error)
			quit(1)
			return
		game.pending_scenario = parsed if scenario != "nest_all" else {}
		var island = load("res://game/island/island.tscn").instantiate()
		island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
		root.add_child(island)
		while island._building:
			await process_frame
		if game.startup_error != "":
			printerr(game.startup_error)
			quit(1)
			return
		for i in warm_frames:
			await process_frame
		Profile.clear()
		var process_ms := 0.0
		var physics_ms := 0.0
		var nodes := 0.0
		var objects := 0.0
		var wall: Array = []
		Profile.enabled = true
		var previous := Time.get_ticks_usec()
		for i in frames:
			await process_frame
			var now := Time.get_ticks_usec()
			wall.append((now - previous) * 0.001)
			previous = now
			process_ms = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics_ms = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			nodes += Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
			objects += Performance.get_monitor(Performance.OBJECT_COUNT)
		Profile.enabled = false
		wall.sort()
		print("LOD final intervals: ", _lod_counts(island))
		print("FRAME BENCH %s renderer=%s creatures=%d radial=%d frames=%d" % [scenario, DisplayServer.get_name(), island.hosts.size(), island.get_node("RadialFauna").animals.size() if island.has_node("RadialFauna") else 0, frames])
		print("| System (exclusive) | ms/frame | calls/frame |")
		print("|---|---:|---:|")
		var total := 0.0
		for key in Profile.totals:
			var ms := float(Profile.totals[key]) / frames / 1000.0
			total += ms
			print("| %s | %.3f | %.2f |" % [key, ms, float(Profile.calls[key]) / frames])
		print("| Instrumented script total | %.3f | |" % total)
		print("Performance last process=%.3f ms physics=%.3f ms nodes=%.0f objects=%.0f frame_p95=%.3f ms" % [process_ms, physics_ms, nodes / frames, objects / frames, wall[int(frames * 0.95)]])
		game.stage = null
		island.queue_free()
		await process_frame
	quit()

func _lod_counts(island) -> Dictionary:
	var counts := {0: 0, 1: 0, 2: 0, 4: 0}
	var player: Vector3 = island.player_sample().pos
	for id in island.hosts:
		var host = island.hosts[id]
		var interval: int = host.visual_interval(island.camera, host.global_position.distance_to(player))
		counts[interval] += 1
	return counts
