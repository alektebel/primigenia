extends SceneTree
# First far click on the real island under software GL: times the order (C plan), the marker and the next frames.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot --script res://game/tests/first_click_probe.gd
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.wild = true
	var params := {"seed": 1}
	var entry := TerrainCache.load_entry(params)
	if entry.is_empty():
		entry = TerrainCache.build(params, CporeTerrain.new())
	game.set_island(entry)
	var island = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	var t0 := Time.get_ticks_usec()
	root.add_child(island)
	print("island ready in %.0f ms" % ((Time.get_ticks_usec() - t0) / 1000.0))
	for i in 60:
		await process_frame
	var p: Vector3 = island.player_pos
	var dests := [Vector2(p.x + 900.0, p.z - 700.0), Vector2(p.x - 800.0, p.z + 800.0)]
	for n in 2:
		var d: Vector2 = dests[n]
		var a := Time.get_ticks_usec()
		island.player_input.set_destination(d)
		var b := Time.get_ticks_usec()
		island.ground_marks.move_marker(Vector3(d.x, game.visual_ground(d.x, d.y), d.y))
		var c := Time.get_ticks_usec()
		print("click %d: set_destination %.1f ms, move_marker %.1f ms" % [n, (b - a) / 1000.0, (c - b) / 1000.0])
		var last := Time.get_ticks_usec()
		var worst := 0.0
		for f in 12:
			await process_frame
			var now := Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			print("  frame %d: %.1f ms" % [f, (now - last) / 1000.0])
			last = now
		print("click %d worst frame %.1f ms" % [n, worst])
	quit(0)
