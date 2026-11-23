extends SceneTree
# A54: the default camera before (chase band, z 0.15) and after (close band, z 0, the default now) on the real island, software GL only.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/default_camera_evidence.gd -- <out dir>
# Writes default_camera.jpg: left z 0.15 (the old default), right the new default.

const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/default-camera"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.wild = true
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.settings.grass = 60000
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	await settle(40)
	var frames: Array = []
	for zz in [0.15, island.chase.Z_CHASE]:
		island.chase.set_zoom(zz, true)
		await settle(25)
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		frames.append(img)
		print("z %.2f boom %.2f m" % [zz, island.chase.distance])
	var both := Image.create(1280, 360, false, Image.FORMAT_RGB8)
	both.blit_rect(frames[0], Rect2i(0, 0, 640, 360), Vector2i(0, 0))
	both.blit_rect(frames[1], Rect2i(0, 0, 640, 360), Vector2i(640, 0))
	both.save_jpg(out_dir.path_join("default_camera.jpg"), 0.9)
	quit(0)
