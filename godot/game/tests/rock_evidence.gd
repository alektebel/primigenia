extends SceneTree
# Rock frames: godot --path godot --rendering-driver opengl3 --script res://game/tests/rock_evidence.gd -- <out dir> [views] [grass]
# (xvfb + software GL; make godot-rock-evidence). Views: comma list of chase, mid, far, cliff_lit, cliff_shade.
# Also prints the cliff coordinates found by rule (they must be (-68.6, 83, -392.0) and (290.0, 60, -226.8) on seed 1).

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Views := preload("res://game/tests/rock_views.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/rock-evidence"
	var views: PackedStringArray = (args[1] if args.size() > 1 else ",".join(Views.VIEWS)).split(",")
	var grass: int = int(args[2]) if args.size() > 2 else 60000
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.settings.grass = grass
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	for lit in [true, false]:
		var c: Dictionary = Views.find_cliff(game.data, lit)
		print("cliff_%s: (%.1f, h %.0f, %.1f) normal (%.2f, %.2f) slope %.1f" % ["lit" if lit else "shade", c.x, c.h, c.z, c.nx, c.nz, c.slope])
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	for i in 30:
		await process_frame
	for v in views:
		Views.apply(island, game.data, v)
		island.grass.visible = (v == "chase")
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out_dir.path_join(v + ".png"))
		print("wrote ", v)
	quit()
