extends SceneTree
# A83 design lab: renders one island layout candidate in the real game scene and saves camera shots.
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot --script res://game/tests/island_layout_shots.gd -- <layout.json> <shots.json> <out dir>
# layout.json: the "params" object printed by `terrain_cli layout-json --layout N` (layout, valley_radius_m, stream_iters, droplets).
# shots.json: [{"name": "flyover", "pos": [x, y, z], "look": [x, y, z], "agl": 2.0, "look_agl": 3.0}]; with "agl" the y of pos is
# ground + agl (the same for look); x and z are map metres (z is the map's y axis, south positive).

const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func _read_json(path: String) -> Variant:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot read " + path)
		quit(2)
		return null
	return JSON.parse_string(f.get_as_text())

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 3:
		push_error("usage: -- <layout.json> <shots.json> <out dir>")
		quit(2)
		return
	var params: Dictionary = _read_json(args[0])
	var shots: Array = _read_json(args[1])
	var out_dir: String = args[2]
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.settings.grass = 6000
	game.settings.wild = false
	var p := {"seed": 1}
	for k in params:
		p[k] = params[k]
	var t0 := Time.get_ticks_msec()
	var entry := TerrainCache.build(p, CporeTerrain.new())
	if entry.is_empty() or entry.get("error", 0) != 0:
		push_error("terrain build failed: %s" % [entry.get("error", "?")])
		quit(3)
		return
	print("layout ", p.get("layout"), " built in ", Time.get_ticks_msec() - t0, " ms, hash ", entry.get("hash"))
	game.set_island(entry)
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	for i in 30:
		await process_frame
	island.chase_enabled = false
	for layer in root.find_children("*", "CanvasLayer", true, false):   # no HUD in the design shots
		layer.visible = false
	for s in shots:
		var pos := Vector3(s.pos[0], s.pos[1], s.pos[2])
		var look := Vector3(s.look[0], s.look[1], s.look[2])
		if s.has("agl"):
			pos.y = game.ground(pos.x, pos.z) + float(s.agl)
		if s.has("look_agl"):
			look.y = game.ground(look.x, look.z) + float(s.look_agl)
		island.camera.position = pos
		island.camera.look_at(look)
		if s.has("fov"):
			island.camera.fov = float(s.fov)
		island.camera.far = 9000.0
		island.terrain_chunks.update_lods(island.camera.global_position, true)
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var path := out_dir.path_join("%s.jpg" % s.name)
		img.save_jpg(path, 0.86)
		print("shot ", s.name, " ", path)
	quit()
