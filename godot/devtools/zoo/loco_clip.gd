extends SceneTree
## Side-camera clip of one zoo body for the side-by-side with the reference (tools/loco/sidebyside.sh).
## xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 --write-movie <out.avi> --path godot --script res://devtools/zoo/loco_clip.gd -- <body> <scenario> <seconds>
## Software GL only. The camera is placed after the zoo's own update (loco_review.gd's _side_cam).

var _cam: Camera3D
var _zoo
var _high := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var body: String = args[0] if args.size() > 0 else "hero"
	var scen: String = args[1] if args.size() > 1 else "walk"
	var secs: float = float(args[2]) if args.size() > 2 else 6.0
	var Core = load("res://devtools/zoo/loco_score_core.gd")
	var Zoo = load("res://devtools/zoo/zoo.gd")
	var cfg: Dictionary = Core.SCEN[scen]
	_zoo = Zoo.new()
	_zoo.course_name = cfg.course
	_zoo.morph_ids = [body]
	_zoo.run_speed = cfg.run
	root.add_child(_zoo)
	await process_frame
	_zoo.hud.get_parent().visible = false
	_zoo.step_ticks(int(cfg.skip))
	var r = _zoo.runners[0]
	var h: float = r.host.height()
	_zoo.cam_dist = clampf(h * 3.2 + 2.0, 4.0, 25.0)
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.near = 0.3
	_cam.far = 1500.0
	root.add_child(_cam)
	_cam.current = true
	var tick := Node.new()
	tick.set_script(load("res://devtools/zoo/loco_clip_cam.gd"))
	tick.owner_clip = self
	tick.process_priority = 100
	root.add_child(tick)
	for i in int(secs * 30.0) + 20:
		await process_frame
	quit(0)

func place_camera() -> void:
	var z = _zoo
	var r = z.runners[0]
	var s: Dictionary = r.sw.sample(0)
	var yaw := float(s.get("yaw", 0.0)) + 1.15
	var pitch := 0.22
	var tgt: Vector3 = r.host.global_position
	tgt.y += 0.5
	var pos: Vector3 = tgt + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * z.cam_dist
	pos.y = maxf(pos.y, float(r.ground.call(pos.x, pos.z)) + 1.5)
	_cam.position = pos
	_cam.look_at(tgt)
