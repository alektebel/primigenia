extends SceneTree
# Rock frames: godot --path godot --rendering-driver opengl3 --script res://game/tests/rock_evidence.gd -- <out dir> [views] [grass] [masks]
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
	var masks: bool = args.size() > 3 and args[3].contains("masks")
	var extra: String = args[3] if args.size() > 3 else ""
	var flicker: bool = args.size() > 3 and args[3].contains("flicker")
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
		if masks and v != "chase":
			await debug_frame(island, 6, out_dir.path_join("mask_" + v + ".png"))
		if v == "cliff_lit" and extra.contains("cells"):
			write_cells(island, game.data, out_dir.path_join("relief_cells.json"))
		for m in range(1, 10):
			if extra.contains("m%d" % m) and v != "chase":
				await debug_frame(island, m, out_dir.path_join("mode%d_%s.png" % [m, v]))
		if flicker and v == "cliff_lit":
			# Two frames of the ramp bands (mode 8), the camera moved 0.25 m sideways, for the flicker metric.
			await debug_frame(island, 8, out_dir.path_join("flicker_a.png"))
			island.camera.global_position += island.camera.global_transform.basis.x * 0.25
			await debug_frame(island, 8, out_dir.path_join("flicker_b.png"))
			await debug_frame(island, 6, out_dir.path_join("flicker_mask.png"))
			island.camera.global_position -= island.camera.global_transform.basis.x * 0.25
	quit()

# One frame of a debug mode on a black background with a linear tone map (values are read back as written).
func debug_frame(island: Node3D, mode: int, path: String) -> void:
	var env: Environment = island.world_env.environment
	var saved := [env.background_mode, env.tonemap_mode, env.tonemap_exposure]
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = 1.0
	island.water.visible = false
	island.terrain_chunks.set_rock_debug(mode)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	island.terrain_chunks.set_rock_debug(0)
	island.water.visible = true
	env.background_mode = saved[0]
	env.tonemap_mode = saved[1]
	env.tonemap_exposure = saved[2]

# Strongest gully (most concave fine curvature) and ridge (most convex) rock cells within 35 m of the cliff point that face the
# camera, as screen positions for the luminance comparison (rock_metrics.gd cells).
func write_cells(island: Node3D, td, path: String) -> void:
	var c: Dictionary = Views.find_cliff(td, true)
	var cam: Camera3D = island.camera
	var best_g := {"v": -1e9}
	var best_r := {"v": 1e9}
	for dj in range(-12, 13):
		for di in range(-12, 13):
			var i: int = c.i + di
			var j: int = c.j + dj
			var k: int = j * td.n + i
			if td.material[k] != 1:
				continue
			var p := Vector3(td.cell_center(i), td.height[k], td.cell_center(j))
			if cam.is_position_behind(p):
				continue
			var sp := cam.unproject_position(p)
			if sp.x < 40 or sp.x > 1240 or sp.y < 40 or sp.y > 680:
				continue
			var rv: float = float(td.relief[k * 4]) - 128.0
			if rv > best_g.v:
				best_g = {"v": rv, "x": p.x, "z": p.z, "sx": sp.x, "sy": sp.y}
			if rv < best_r.v:
				best_r = {"v": rv, "x": p.x, "z": p.z, "sx": sp.x, "sy": sp.y}
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"gully": best_g, "ridge": best_r}, "\t"))
	f.close()
	print("gully cell ", best_g, " ridge cell ", best_r)
