extends SceneTree
## Evidence frames of the creator top bar at 1024x600, 1280x720 and 1920x1080 (each in its own SubViewport, no stretch).
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --rendering-driver opengl3 --path godot --script res://studio/tests/topbar_evidence.gd -- <out_dir>

const Studio := preload("../ui/studio.gd")
var out := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await _frames(2)
	for sz in [Vector2i(1024, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var sv := SubViewport.new()
		sv.size = sz
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(sv)
		var st = Studio.new()
		sv.add_child(st)
		await _frames(25)
		var img := sv.get_texture().get_image()
		img.save_png(out.path_join("topbar-%dx%d.png" % [sz.x, sz.y]))
		print("saved ", sz, " ", img.get_size())
		sv.queue_free()
		await _frames(3)
	quit(0)
