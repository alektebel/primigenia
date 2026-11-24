extends SceneTree
# make godot-camera-evidence: the zoom strip z = 0 .. 1 on the real island plus frame times, software GL only.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot \
#     --script res://game/tests/camera_evidence.gd -- <out dir>
# Writes zoom_strip.png (5 frames, z = 0, 0.25, 0.5, 0.75, 1), icons_z1.png (full size map) and frame_times.json.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const TW := 640
const TH := 360
const ZS := [0.0, 0.25, 0.5, 0.75, 1.0]

var out_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/camera-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.settings.wild = true
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.settings.grass = 60000
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	await settle(30)
	var strip := Image.create(TW * ZS.size(), TH, false, Image.FORMAT_RGB8)
	var times := {}
	for i in ZS.size():
		var zz: float = ZS[i]
		island.chase.set_zoom(zz, true)
		await settle(12)
		var t0 := Time.get_ticks_usec()
		var n := 8
		for k in n:
			await process_frame
			await RenderingServer.frame_post_draw
		var ms := (Time.get_ticks_usec() - t0) / 1000.0 / n
		times["z%.2f" % zz] = {"frame_ms": snappedf(ms, 0.1), "triangles": island.terrain_chunks.triangle_count(), "icons": island.icons.icon_count(), "camera_distance_m": snappedf(island.chase.distance, 0.1)}
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if zz == 1.0:
			img.save_png(out_dir.path_join("icons_z1.png"))
		img.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
		strip.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i(i * TW, 0))
		print("z %.2f  %.0f ms/frame  distance %.0f m  icons %d" % [zz, ms, island.chase.distance, island.icons.icon_count()])
	strip.save_png(out_dir.path_join("zoom_strip.png"))
	var f := FileAccess.open(out_dir.path_join("frame_times.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(times, "  "))
	f.close()
	quit(0)
