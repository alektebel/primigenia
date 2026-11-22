extends SceneTree
## Close-camera clip of one zoo body through a scripted start/stop/turn/gallop sequence, with a numbers log (A54).
## LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 --write-movie <out.avi> \
##   --path godot --script res://devtools/zoo/loco_close.gd -- <body> <scenario> <cam> <log.csv>
## scenario: startstop | gallop | turnspot | slope.  cam: side | shoulder | front | hip.  Software GL only.
## The log has one line per rendered frame: t, C speed, visual speed, gait, stance feet slip (m/s), foot heights.

var _zoo
var _cam: Camera3D
var _mode := "side"
var _scen := "startstop"
var _log: FileAccess
var _frame := 0
var _last_tick := -1
var _secs := 12.0
var _prev_feet := {}
var _prev_knee := {}
var _prev_ank := {}
var _prev_ex := {}
var _vcache := {}
var _flat_start := {}
var _dbg_prev := {}
var _body_len := 1.0

# (tick, order) schedule; orders persist until the next one
func _schedule(scen: String) -> Dictionary:
	var f := 32767
	var s := {}
	match scen:
		"startstop":
			s[0] = {"verb": 1}
			s[6] = {"verb": 3, "hx": 0, "hz": f, "sprint": 0}      # walk from standstill
			s[36] = {"verb": 1}                                     # stop from a walk
			s[56] = {"verb": 3, "hx": 0, "hz": f, "sprint": 1}      # run from standstill
			s[96] = {"verb": 1}                                     # stop from a run
			s[120] = {"verb": 3, "hx": f, "hz": 0, "sprint": 0}     # turn on the spot, then walk
			s[150] = {"verb": 1}
		"gallop":
			s[0] = {"verb": 1}
			s[6] = {"verb": 3, "hx": 0, "hz": f, "sprint": 1}
			s[100] = {"verb": 1}
		"turnspot":
			s[0] = {"verb": 1}
			s[10] = {"verb": 3, "hx": 0, "hz": -f, "sprint": 0}     # turn round from rest: the creature pivots (C: back turn below pivot speed)
			s[34] = {"verb": 1}
			s[40] = {"verb": 3, "hx": 0, "hz": f, "sprint": 0}
			s[64] = {"verb": 1}
		"slope":
			s[0] = {"verb": 1}
			s[6] = {"verb": 3, "hx": 0, "hz": f, "sprint": 0}
			s[120] = {"verb": 1}
	return s

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var body: String = args[0] if args.size() > 0 else "startB"
	_scen = args[1] if args.size() > 1 else "startstop"
	_mode = args[2] if args.size() > 2 else "side"
	var log_path: String = args[3] if args.size() > 3 else ""
	var look: String = args[4] if args.size() > 4 else ""
	if look != "":
		load("res://locomotion/loco_gait.gd").gallop_look = look
	var Zoo = load("res://devtools/zoo/zoo.gd")
	var Course = load("res://devtools/zoo/zoo_course.gd")
	_zoo = Zoo.new()
	_zoo.course_name = "ramps" if _scen == "slope" else "figure8"
	_zoo.morph_ids = [body]
	_zoo.repeat = false
	root.add_child(_zoo)
	await process_frame
	_zoo.hud.get_parent().visible = false
	var r = _zoo.runners[0]
	r.steps = [Course.wait(100000000)]
	r.si = 0
	r.sw._order_queue.clear()
	if _scen == "slope":
		# start at the foot of the 20 degree ramp (course "ramps" lane 0), facing +z
		r.sw.debug_now({"op": 1, "id": 0, "x": r.x0 + Course.ramp_x(1), "z": Course.RAMP_Z0 - 2.0})
	if OS.get_environment("LC_SPRINT_K") != "":
		# the run Froude number through the logged PARAM debug op (7), e.g. 1.5 for the pre-A54 gallop
		for p in CporeWorld.params():
			if p.name == "sprint_k":
				r.sw.debug_now({"op": 7, "a": int(p.index), "v": float(OS.get_environment("LC_SPRINT_K"))})
	_body_len = r.host.height()
	if log_path != "":
		_log = FileAccess.open(log_path, FileAccess.WRITE)
		_log.store_line("frame,tick,c_speed,vis_speed,gait,slip_ms,sole_min_cm,sole_max_stance_cm,knee_jump_deg,knee_jump_ext60,foot_v_max,ext_min,ext_min_stance,toe_min_stance_cm,pitch_deg,yaw_deg,node_slide_mm,roots")
	_cam = Camera3D.new()
	_cam.fov = 48.0
	_cam.near = 0.05
	_cam.far = 1500.0
	root.add_child(_cam)
	_cam.current = true
	var tick := Node.new()
	tick.set_script(load("res://devtools/zoo/loco_clip_cam.gd"))
	tick.owner_clip = self
	tick.process_priority = 100
	root.add_child(tick)
	_secs = {"startstop": 6.5, "gallop": 5.0, "turnspot": 3.6, "slope": 6.0}.get(_scen, 6.0)
	for i in int(_secs * 30.0) + 10:
		await process_frame
	if _log:
		_log.close()
	quit(0)

func _legs() -> Array:
	var r = _zoo.runners[0]
	var b = r.host.body
	return b.legs if b != null and "legs" in b else []

func place_camera() -> void:
	var r = _zoo.runners[0]
	var sw = r.sw
	var tk := int(sw.cur.tick)
	var sch := _schedule(_scen)
	if tk != _last_tick:
		_last_tick = tk
		if sch.has(tk):
			sw.queue_order(sch[tk])
	var s: Dictionary = sw.sample(0)
	var tgt: Vector3 = r.host.global_position
	var legs := _legs()
	var fwd := Vector3(sin(float(s.get("yaw", 0.0))), 0.0, cos(float(s.get("yaw", 0.0))))
	var left := Vector3(fwd.z, 0.0, -fwd.x)
	var h: float = _body_len
	match _mode:
		"shoulder", "front", "hip":
			# aim at the first leg of the wanted end (front = the largest mount t)
			var pick = null
			for l in legs:
				if (_mode != "hip" and l.front and l.side > 0) or (_mode == "hip" and not l.front and l.side > 0):
					pick = l
			if pick != null:
				var hp: Vector3 = pick.hip_global()
				var dist := float(OS.get_environment("LC_DIST")) if OS.get_environment("LC_DIST") != "" else 0.55
				var dirv: Vector3
				if _mode == "front":
					dirv = (fwd * 0.9 + left * 0.35).normalized()
				else:
					dirv = (left * 1.0 + fwd * 0.25).normalized()
				_cam.position = hp + dirv * dist + Vector3.UP * 0.08
				_cam.look_at(hp + Vector3.DOWN * 0.04)
				return
		_:
			pass
	# side view, follows the body
	var yaw := float(s.get("yaw", 0.0)) + 1.5708
	if _scen == "turnspot":
		yaw = 0.7           # the camera does not turn with the creature, so the turn on the spot shows
	tgt.y += 0.45
	var dist := 3.2
	_cam.position = tgt + Vector3(sin(yaw) * dist, 0.5, cos(yaw) * dist)
	_cam.look_at(tgt)

func _process(_d: float) -> bool:
	if _zoo == null or _log == null:
		return false
	var r = _zoo.runners[0]
	var e: Dictionary = r.sw.cur.entities[0]
	var s: Dictionary = r.sw.sample(0)
	var legs := _legs()
	var slip := 0.0
	var miny := 1e9
	var roots := ""
	var driver = r.host.driver
	var pose: Dictionary = {}
	if driver != null and driver.controller != null:
		pose = driver.controller.pose
	var gait := str(pose.get("gait", ""))
	var vis := float(pose.get("speed", 0.0))
	if not pose.is_empty():
		var feet: PackedVector3Array = pose.feet
		var contact: Array = pose.contact
		for i in feet.size():
			if bool(contact[i]):
				var key := i
				if _prev_feet.has(key) and bool(_prev_feet[key].c):
					slip = maxf(slip, Vector2(feet[i].x - _prev_feet[key].p.x, feet[i].z - _prev_feet[key].p.z).length() * 30.0)
				_prev_feet[key] = {"p": feet[i], "c": true}
			else:
				_prev_feet[i] = {"p": feet[i], "c": false}
		var rt: Transform3D = pose.root
		roots = "%.3f" % rt.origin.y
	var stance_max := -1e9
	var nslide := 0.0
	var kjump := 0.0
	var fvmax := 0.0
	var kj60 := 0.0
	var extmin := 9.0
	var extst := 9.0
	var toemin := 9.0
	for i in legs.size():
		var l = legs[i]
		var fp: Vector3 = l.foot.global_position
		var gh: float = float(r.ground.call(fp.x, fp.z))
		var hgt := fp.y - gh
		miny = minf(miny, hgt)
		if not pose.is_empty() and bool(pose.contact[i]):
			stance_max = maxf(stance_max, hgt)
		var hip: Vector3 = l.hip
		var ank: Vector3 = l.ankle
		if not pose.is_empty() and bool(pose.contact[i]):
			for ch in l.foot.get_children():
				if ch is MeshInstance3D and ch.mesh != null:
					var xf: Transform3D = (ch as MeshInstance3D).global_transform
					var m: Mesh = (ch as MeshInstance3D).mesh
					if not _vcache.has(m):
						_vcache[m] = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] if m.get_surface_count() > 0 else PackedVector3Array()
					for v in (_vcache[m] as PackedVector3Array):
						var wv: Vector3 = xf * v
						toemin = minf(toemin, wv.y - float(r.ground.call(wv.x, wv.z)))
		if not pose.is_empty() and bool(pose.contact[i]) and float(pose.foot_pitch[i]) < 0.01:
			var gp: Vector3 = l.foot.global_position
			if _flat_start.has(i):
				nslide = maxf(nslide, Vector2(gp.x - _flat_start[i].x, gp.z - _flat_start[i].z).length() * 1000.0)
				if OS.get_environment("LC_DBG3") != "" and Vector2(gp.x - _flat_start[i].x, gp.z - _flat_start[i].z).length() > 0.02:
					print("SL f%d leg %d d %.3f pitch %.3f tilt %s ankle_c %s foot_c %s feet %s" % [_frame, i, Vector2(gp.x - _flat_start[i].x, gp.z - _flat_start[i].z).length(), float(pose.foot_pitch[i]), str(l.foot_tilt), str(l.ankle), str(l.foot.position), str(pose.feet[i]) + " ankle_w-foot_w " + str(l.creature.global_transform * l.ankle - l.foot.global_position) + " w " + str(l.width) + " target " + str(l.foot_target) + " ankle_w " + str(l.creature.global_transform * l.ankle) + " scale " + str(l.creature.global_transform.basis.get_scale())])
			else:
				_flat_start[i] = gp
		else:
			_flat_start.erase(i)
		var ex: float = (ank - hip).length() / l.total_length()
		extmin = minf(extmin, ex)
		if not pose.is_empty() and bool(pose.contact[i]):
			extst = minf(extst, ex)
		var ag: Vector3 = l.foot.global_position
		if _prev_ank.has(i):
			fvmax = maxf(fvmax, (ag - _prev_ank[i]).length() * 30.0)
		_prev_ank[i] = ag
		var ax := (ank - hip).normalized()
		var kn: Vector3 = l.knee - hip
		kn = kn - ax * kn.dot(ax)
		var bent: bool = kn.length() > 0.05 * l.total_length()
		kn = kn.normalized()
		if _prev_knee.has(i) and bent:
			var jd := rad_to_deg(acos(clampf(kn.dot(_prev_knee[i]), -1.0, 1.0)))
			if jd > 40.0:
				print("KNEE leg %d front %s jump %.0f frame %d pole.ax %.2f ankle_off %s knee_off %s ext %.3f" % [i, l.front, jd, _frame, l.pole.dot(ax), str(l.ankle - hip), str(l.knee - hip), (l.ankle - hip).length() / l.total_length()])
			kjump = maxf(kjump, jd)
			if ex > 0.6 and float(_prev_ex.get(i, 0.0)) > 0.6:
				kj60 = maxf(kj60, jd)
		_prev_ex[i] = ex
		if bent:
			_prev_knee[i] = kn
		else:
			_prev_knee.erase(i)
	if OS.get_environment("LC_DEBUG") != "" and _frame >= int(OS.get_environment("LC_F0")) and _frame <= int(OS.get_environment("LC_F1")) and not pose.is_empty():
		var parts := []
		for i in legs.size():
			var l2 = legs[i]
			parts.append("L%d %s %.2f,%.2f,%.2f v%.1f" % [i, "sw" if not bool(pose.contact[i]) else "st", pose.feet[i].x, pose.feet[i].y, pose.feet[i].z, ((pose.feet[i] - _dbg_prev.get(i, pose.feet[i])).length() * 30.0)])
			_dbg_prev[i] = pose.feet[i]
		print("F%d spd %.2f fr %.2f cad %.2f stride %.2f theta | %s" % [_frame, vis, float(pose.get("froude", 0.0)), float(pose.get("cadence", 0.0)), float(pose.get("stride", 0.0)), " | ".join(parts)])
	_frame += 1
	_log.store_line("%d,%d,%.3f,%.3f,%s,%.3f,%.2f,%.2f,%.1f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%.1f,%s" % [_frame, int(r.sw.cur.tick), float(e.speed), vis, gait, slip, miny * 100.0 if miny < 1e8 else 0.0, stance_max * 100.0 if stance_max > -1e8 else 0.0, kjump, kj60, fvmax, extmin, extst, toemin * 100.0 if toemin < 8.0 else 0.0, rad_to_deg(float(pose.get("pitch", 0.0))), rad_to_deg(float(s.get("yaw", 0.0))), nslide, roots])
	return false
