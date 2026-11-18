extends SceneTree
# make godot-zoo-evidence: frame strips of the locomotion zoo (software GL).
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
#     --script res://devtools/tests/zoo_evidence.gd -- <out dir>
# zoo_strip.png: six creatures, course "all", 8 frames; uturn_strip.png: the U-turn lane of mite, hero and giant, 8 frames.

const TW := 640
const TH := 360

func _initialize() -> void:
	_run.call_deferred()

func _shoot(z, ticks: int) -> Image:
	for i in ticks:
		z.step_ticks(1)
		z._process(0.1)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
	return img

func _strip(z, name: String, frames: int, every: int, out_dir: String, start_ticks: int = 0) -> void:
	var strip := Image.create(TW * 2, TH * ((frames + 1) / 2), false, Image.FORMAT_RGB8)
	await _shoot(z, start_ticks)
	for f in frames:
		var img: Image = await _shoot(z, every)
		strip.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i((f % 2) * TW, (f / 2) * TH))
	strip.save_png(out_dir.path_join(name))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/zoo-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var Zoo = load("res://devtools/zoo/zoo.gd")
	var z = Zoo.new()
	z.course_name = "all"
	z.morph_ids = ["mite", "trotter", "giant", "longneck", "centipede", "hero"]
	z.paused = true
	root.add_child(z)
	z.cam_dist = 110.0
	z.cam_pitch = 0.6
	await process_frame
	await _strip(z, "zoo_strip.png", 8, 60, out_dir, 20)
	z.queue_free()
	await process_frame
	await process_frame
	var u = Zoo.new()
	u.course_name = "uturn"
	u.morph_ids = ["mite", "hero", "giant"]
	u.paused = true
	root.add_child(u)
	u.cam_dist = 70.0
	u.cam_pitch = 0.9
	u.cam_yaw = 0.0
	await process_frame
	await _strip(u, "uturn_strip.png", 8, 8, u_dir(out_dir), 430)
	quit(0)

func u_dir(d: String) -> String:
	return d
