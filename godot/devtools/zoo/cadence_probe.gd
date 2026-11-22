extends SceneTree
## Steady-speed cadence probe: godot --headless --path godot --script res://devtools/zoo/_cad_probe.gd -- body v1,v2,...
var Zoo
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Zoo = load("res://devtools/zoo/zoo.gd")
	var args := OS.get_cmdline_user_args()
	var body: String = args[0] if args.size() > 0 else "hero"
	var speeds: Array = Array(args[1].split(",")) if args.size() > 1 else ["2.0", "4.97"]
	var Ctl = load("res://locomotion/loco_controller.gd")
	var z = Zoo.new()
	z.auto_build = false
	z.morph_ids = [body]
	z.course_name = "figure8"
	root.add_child(z)
	z.build()
	var ctl = Ctl.new(z.runners[0].host.driver.controller.morph, func(_x, _z): return 0.0)
	print("CAD %s hip %.3f legs %d" % [body, ctl._ref_h, ctl._legs.size()])
	for sv in speeds:
		var v := float(sv)
		ctl.reset(Vector3.ZERO, 0.0)
		var pos := Vector3.ZERO
		var dt := 1.0 / 60.0
		var td := 0
		var air := 0
		var n := 0
		var minh := 1e9
		var maxh := -1e9
		var fl0: int = ctl.forced_lifts
		var cnt := 0
		var prev := []
		var slip := 0.0
		var pf: Array = []
		for i in 1500:
			pos.z += v * dt
			ctl.step(dt, pos, 0.0, Vector3(0, 0, v))
			if i > 600:
				n += 1
				var any := false
				for c in ctl.pose.contact:
					any = any or c
				if not any: air += 1
				var hy: float = ctl.pose.root.origin.y
				if pf.size() == ctl.pose.feet.size():
					for k in pf.size():
						if ctl.pose.contact[k] and pf[k][1]:
							slip = maxf(slip, Vector2(ctl.pose.feet[k].x - pf[k][0].x, ctl.pose.feet[k].z - pf[k][0].z).length())
				pf = []
				for k in ctl.pose.feet.size():
					pf.append([ctl.pose.feet[k], ctl.pose.contact[k]])
				minh = minf(minh, hy); maxh = maxf(maxh, hy)
		print("CAD v %.2f Fr %.2f gait %s duty %.2f stride %.2f cadence %.2f Hz air %.2f hip y %.2f..%.2f crouch %.3f forced %d slip/frame %.1f mm" % [v, ctl.fr, ctl.gait, ctl.duty, ctl.stride, ctl.cadence, float(air) / n, minh, maxh, ctl.crouch, ctl.forced_lifts - fl0, slip * 1000.0])
	# rest: walk then stop
	ctl.reset(Vector3.ZERO, 0.0)
	var pz := 0.0
	for i in 600:
		pz += 2.0 / 60.0
		ctl.step(1.0 / 60.0, Vector3(0, 0, pz), 0.0, Vector3(0, 0, 2.0))
	for i in 1200:
		ctl.step(1.0 / 60.0, Vector3(0, 0, pz), 0.0, Vector3.ZERO)
		if i % 200 == 0:
			print("REST t %d err %s swing %s theta %s duty %.2f" % [i, str(ctl._legs.map(func(l): return snappedf(l.err, 0.001))), str(ctl._legs.map(func(l): return l.swing)), str(ctl._legs.map(func(l): return snappedf(l.theta - floor(l.theta), 0.01))), ctl.duty])
	quit(0)
