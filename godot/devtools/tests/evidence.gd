extends SceneTree
# make godot-devtools-evidence: three software screenshots under docs/evidence/godot/devtools (xvfb).
# Usage: godot ... --script res://devtools/tests/evidence.gd -- <output dir>

const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out_dir := ""

func _initialize() -> void:
	_run.call_deferred()

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/devtools-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	var dev = root.get_node("Dev")
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 600:
		await process_frame
		if game.stage != null and dev.sites != null:
			break
	await settle(30)
	# 1. the F1 sheet over the walk context
	dev.legend._refresh()
	dev.legend.sheet.visible = true
	await shot("legend.png")
	dev.legend.sheet.visible = false
	# 2. console with a completion list, and the tuning panel with B active
	dev.tuning.set_value("camera/yaw_max", 2.6)
	dev.tuning.store_active()
	dev.tuning.swap()
	dev.tuning.set_value("sim/jog_k", 1.9)
	dev.tuning.slot_names["B"] = "jog-fast"
	dev.console.open()
	dev.console.submit("tune sim/jog_k")
	dev.console.submit("god on")
	dev.console.input.text = "tune sim/"
	dev.console._complete()
	dev.tuning_panel.toggle()
	await shot("console.png")
	dev.tuning_panel.toggle()
	dev.console.close()
	# 3. the site picker with a search
	dev.picker.open()
	dev.picker.search.text = "ca"
	dev.picker.refresh()
	await shot("picker.png")
	dev.picker.close()
	quit(0)
