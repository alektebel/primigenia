extends SceneTree
# Starter hatchling evidence: four sites (nest, meadow, cliff, near Garfio) at the default chase camera, plus the closest zoom
# at the meadow. Software GL only. `--genome=res://game/data/merodeador.json` gives the BEFORE frames.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1920x1080x24" godot --rendering-driver opengl3 --resolution 1920x1080 \
#     --path godot --script res://game/tests/hatchling_evidence.gd -- <out dir> [prefix] [--genome=<path>]
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(path: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("wrote ", path)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0]
	var prefix: String = args[1] if args.size() > 1 and not args[1].begins_with("--") else "after"
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1920, 1080)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 40000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	var stage = game.stage
	stage.debug_now({"op": 6, "a": 2})      # freeze the wild: Garfio stays where it is
	var setup: Dictionary = stage.world.get_setup()
	var nest: Vector2 = setup.nest
	var data = game.data
	var sites := {"1_nest": nest + Vector2(2, 2)}
	for d in [Vector2(40, 0), Vector2(-40, 0), Vector2(0, 40), Vector2(0, -40)]:
		var q: Vector2 = nest + d
		if data.ground(q.x, q.y) > 1.0 and not sites.has("2_meadow"):
			sites["2_meadow"] = q
	if data.caves.size() > 0:
		var c = data.caves[0]
		sites["3_cliff"] = Vector2(c.position.x, c.position.z) + Vector2(c.facing.x, c.facing.z) * 12.0
	var home := Vector2(setup.wild[0].home_x, setup.wild[0].home_z)
	sites["4_garfio"] = home + (nest - home).normalized() * 9.0
	for k in sites:
		var p: Vector2 = sites[k]
		stage.debug_now({"op": 1, "id": 0, "x": p.x, "z": p.y})
		stage.step_ticks(3)
		island.chase.set_zoom(island.chase.Z_CHASE, true)
		island.chase.reset_behind()
		await settle(12)
		await shot(out.path_join("%s_%s.png" % [prefix, k]))
		if k == "2_meadow":
			island.chase.set_zoom(0.0, true)
			await settle(12)
			await shot(out.path_join("%s_%s_closest.png" % [prefix, k]))
	quit(0)
