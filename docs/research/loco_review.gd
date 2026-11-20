extends SceneTree
# Close-up gait contact sheets per morph x scenario, for a motion review. Software GL only.
# args: <out dir> [morph,morph...] [scenario,scenario...]

const TW := 480
const TH := 270
const FRAMES := 12
const EVERY := 3          # rendered frames between shots (at --fixed-fps 30 = 0.1 s)

const SCEN := {
	"walk":   {"course": "figure8", "run": 1.0, "want": ["run", "turn"], "skip": 40},
	"gallop": {"course": "figure8", "run": 1.8, "want": ["run", "turn"], "skip": 40},
	"turn":   {"course": "uturn",   "run": 1.0, "want": ["turn", "pivot"], "skip": 0},
	"climb":  {"course": "ramps",   "run": 1.0, "want": ["climb", "stalled (too steep)", "slide"], "skip": 0},
	"steps":  {"course": "steps",   "run": 1.0, "want": ["climb", "descend", "stalled (too steep)"], "skip": 0},
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/loco-review"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var Genomes = load("res://devtools/zoo/zoo_genomes.gd")
	var morphs: Array = Array(args[1].split(",")) if args.size() > 1 else Genomes.INFO.keys()
	var scens: Array = Array(args[2].split(",")) if args.size() > 2 else SCEN.keys()
	high_cam = args.size() > 3 and args[3] == "high"
	root.size = Vector2i(1280, 720)
	var log := FileAccess.open(out_dir.path_join("review.log"), FileAccess.WRITE)
	for m in morphs:
		for sc in scens:
			await _one(str(m), str(sc), out_dir, log)
	log.close()
	quit(0)

func _one(m: String, sc: String, out_dir: String, log: FileAccess) -> void:
	var cfg: Dictionary = SCEN[sc]
	var Zoo = load("res://devtools/zoo/zoo.gd")
	var z = Zoo.new()
	z.course_name = cfg.course
	z.morph_ids = [m]
	z.run_speed = cfg.run
	root.add_child(z)
	await process_frame
	await process_frame
	z.follow = 0
	z.cam_pitch = 0.22
	# skip ahead in the sim (no render) until the wanted state shows
	var found := false
	var ticks := 0
	z.step_ticks(int(cfg.skip))
	ticks += int(cfg.skip)
	while ticks < 900:
		z.step_ticks(1)
		ticks += 1
		if z.stats(0).state in cfg.want:
			found = true
			break
	# back off a little so the shots start just before the event
	var r = z.runners[0]
	var h: float = r.host.height() if r.host != null else 1.5
	z.cam_dist = clampf(h * 3.2 + 2.0, 4.0, 25.0)
	# settle the procedural rig with rendered frames
	for i in 20:
		await process_frame
		_side_cam(z)
	var sheet := Image.create(TW * 4, TH * (FRAMES / 4), false, Image.FORMAT_RGB8)
	var states := PackedStringArray()
	for f in FRAMES:
		for k in EVERY:
			await process_frame
			_side_cam(z)
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.resize(TW, TH, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, TW, TH), Vector2i((f % 4) * TW, (f / 4) * TH))
		var s: Dictionary = z.stats(0)
		states.append("%s v%.1f w%.1f g%.0f%%" % [s.state, s.speed, s.omega, s.grade * 100.0])
	sheet.save_jpg(out_dir.path_join("%s_%s.jpg" % [m, sc]), 0.85)
	log.store_line("%s %s found=%s ticks=%d h=%.2f | %s" % [m, sc, found, ticks, h, " ; ".join(states)])
	log.flush()
	z.queue_free()
	await process_frame
	await process_frame

var high_cam := false

func _side_cam(z) -> void:
	# place the camera ourselves after the zoo's own update: no lag, above the ground on ramps
	var r = z.runners[0]
	var s: Dictionary = r.sw.sample(0)
	var yaw := float(s.get("yaw", 0.0)) + (0.75 if high_cam else 1.15)
	var pitch := 0.75 if high_cam else 0.22
	var tgt: Vector3 = r.host.global_position if r.host != null else s.pos
	tgt.y += 0.5
	var d: float = z.cam_dist
	var pos := tgt + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * d
	pos.y = maxf(pos.y, float(r.ground.call(pos.x, pos.z)) + 1.5)
	z.camera.position = pos
	z.camera.look_at(tgt)
