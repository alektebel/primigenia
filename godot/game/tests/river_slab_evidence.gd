extends SceneTree
# River-slab evidence (INTEGRATION-QA): frames of lake quads that sit on river cells near the nest, before/after the fix.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
#     --script res://game/tests/river_slab_evidence.gd -- <out dir> <tag before|after>

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Water := preload("res://game/island/water.gd")

var game
var island

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, pos: Vector3, look: Vector3) -> void:
	island.chase_enabled = false
	island.camera.fov = 60.0
	island.camera.position = pos
	island.camera.look_at(look)
	await settle(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out, 0.9)
	print("wrote ", out)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/river-slab"
	var tag: String = args[1] if args.size() > 1 else "before"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.wild = true
	var params := {"seed": 1}
	var entry := TerrainCache.load_entry(params)
	if entry.is_empty():
		entry = TerrainCache.build(params, CporeTerrain.new())
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	await settle(40)
	var data = game.data
	var nest: Vector2 = island._nest
	var cells := Water.lake_cells(data)
	var on_river := 0
	var cand: Array = []
	for k in data.n * data.n:
		var near_pond := false
		for d in [-1, 1, -data.n, data.n, -data.n - 1, -data.n + 1, data.n - 1, data.n + 1]:
			var q: int = k + d
			if q >= 0 and q < data.n * data.n and data.is_pond(q) and not data.is_river(q):
				near_pond = true
		if near_pond and data.is_river(k):
			on_river += 1
			var x: float = data.cell_center(k % data.n)
			var z: float = data.cell_center(k / data.n)
			cand.append([Vector2(x - nest.x, z - nest.y).length(), k, x, z])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	print("lake quads ", cells.size(), " of which on river cells ", on_river)
	for i in mini(cand.size(), 6):
		var c = cand[i]
		var k: int = c[1]
		print("cand ", i, " dist ", c[0], " cell ", k, " pond ", data.is_pond(k), " level ", Water.lake_level(data, k), " river_level ", data.water_level[k])
	for i in mini(cand.size(), 4):
		var c = cand[i]
		var gy: float = game.visual_ground(c[2], c[3])
		await shot(out_dir.path_join("%s_%d.jpg" % [tag, i]), Vector3(c[2] + 18.0, gy + 9.0, c[3] + 18.0), Vector3(c[2], gy, c[3]))
	quit(0)
