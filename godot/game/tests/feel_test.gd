extends SceneTree
# make godot-feel-test: how the creature feels to steer (PLAN-feel S1). Two parts.
#  1. C only: CporeWorld.step() on flat ground with the real Merodeador profile: top speeds, time to
#     50/90/99 %, peak acceleration, 90 degree turn, tightest circle, reversal, stop.
#  2. The real Godot pipeline at 60 fps (StageWorld + PlayerInput + ActorHost with the real rig and
#     LocoController + ChaseCamera, view_yaw fed back every frame as island.gd does): W, S, A, D tap,
#     click behind, figure eight. Per scenario: yaw rates, camera yaw, camera lag, foot slide, roll.
# Writes docs/evidence/godot/feel/measurements.json (path from the first user arg, else the default).
# godot --headless --fixed-fps 60 --path godot --script res://game/tests/feel_test.gd

const StageWorld := preload("res://game/stage/stage_world.gd")
const Profile := preload("res://game/stage/profile.gd")
const PlayerInput := preload("res://game/player/player_input.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")

const DT := 0.1
const FRAME := 1.0 / 60.0

var checks := 0
var failures := 0
var gates_on := true
var profile: Dictionary = {}
var genome: Dictionary = {}
var results := {"c": {}, "scenarios": {}}

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func _flat(_x: float, _z: float) -> float:
	return 0.0

func make_setup() -> Dictionary:
	var setup: Dictionary = CporeWorld.default_setup(1)
	setup.terrain = 1
	setup.flat_height = 0.0
	setup.nest = Vector2.ZERO
	setup.water = Vector3.ZERO
	setup.player = profile
	setup.wild = []
	setup.obstacles = []
	return setup

# ---------------------------------------------------------------- C part

func c_world() -> CporeWorld:
	var w := CporeWorld.new()
	var rc := w.reset(make_setup())
	if rc != 0:
		push_error("feel: reset failed %d" % rc)
	return w

func hd(v: Vector2, sprint: int = 0) -> Dictionary:
	var h := PlayerInput.heading(v)
	return {"verb": 3, "hx": h.x, "hz": h.y, "sprint": sprint}

func c_state(w: CporeWorld) -> Dictionary:
	return w.state().entities[0]

# Steady run along the initial facing; returns the world.
func c_steady(sprint: int, ticks: int = 30) -> CporeWorld:
	var w := c_world()
	var f := Vector2(c_state(w).fx, c_state(w).fz)
	for i in ticks:
		w.step(hd(f, sprint))
	return w

func measure_c() -> void:
	var out := {}
	for mode in ["jog", "sprint"]:
		var sp := 1 if mode == "sprint" else 0
		var w := c_world()
		var f := Vector2(c_state(w).fx, c_state(w).fz)
		var speeds: Array = []
		for i in 50:
			w.step(hd(f, sp))
			speeds.append(float(c_state(w).speed))
		var top: float = speeds[speeds.size() - 1]
		var m := {"top_speed": top}
		for frac in [0.5, 0.9, 0.99]:
			var tt := -1.0
			for i in speeds.size():
				if speeds[i] >= frac * top:
					tt = (i + 1) * DT
					break
			m["t%d" % int(frac * 100)] = tt
		var peak: float = speeds[0] / DT
		for i in range(1, speeds.size()):
			peak = maxf(peak, (speeds[i] - speeds[i - 1]) / DT)
		m["peak_accel"] = peak
		# 90 degree turn from steady speed (hold the new heading)
		var w2 := c_steady(sp)
		var s0 := c_state(w2)
		var f0 := Vector2(s0.fx, s0.fz)
		var d := Vector2(-f0.y, f0.x)
		var t90 := -1.0
		var vmin := 1e9
		for i in 40:
			w2.step(hd(d, sp))
			var s := c_state(w2)
			vmin = minf(vmin, s.speed)
			if t90 < 0.0 and Vector2(s.fx, s.fz).dot(d) > 0.98:
				t90 = (i + 1) * DT
				break
		m["turn90_time"] = t90
		m["turn90_min_speed"] = vmin
		# tightest circle: always command the heading 90 degrees off the current facing
		var w3 := c_steady(sp)
		var prev := Vector2(c_state(w3).fx, c_state(w3).fz)
		var rates: Array = []
		var sps: Array = []
		for i in 40:
			var s := c_state(w3)
			var fc := Vector2(s.fx, s.fz)
			w3.step(hd(Vector2(-fc.y, fc.x), sp))
			var s2 := c_state(w3)
			var f2 := Vector2(s2.fx, s2.fz)
			if i >= 25:
				rates.append(absf(fc.angle_to(f2)) / DT)
				sps.append(s2.speed)
			prev = f2
		var rate_m := 0.0
		var sp_m := 0.0
		for k in rates.size():
			rate_m += rates[k] / rates.size()
			sp_m += sps[k] / sps.size()
		m["circle_yaw_rate"] = rate_m
		m["circle_speed"] = sp_m
		m["circle_radius"] = sp_m / maxf(rate_m, 1e-6)
		# reversal
		var w4 := c_steady(sp)
		var r0 := c_state(w4)
		var fr0 := Vector2(r0.fx, r0.fz)
		var p0 := Vector2(r0.x, r0.z)
		var vtop: float = r0.speed
		var t_face := -1.0
		var t_back := -1.0
		var over := 0.0
		var ppos := p0
		var pivoted := false
		for i in 30:
			w4.step(hd(-fr0, sp))
			var s := c_state(w4)
			var pos := Vector2(s.x, s.z)
			over = maxf(over, (pos - p0).dot(fr0))
			if int(s.pivot) != 0:
				pivoted = true
			if t_face < 0.0 and Vector2(s.fx, s.fz).dot(-fr0) > 0.98:
				t_face = (i + 1) * DT
			var back := (pos - ppos).dot(-fr0) / DT
			if t_back < 0.0 and back >= 0.9 * vtop:
				t_back = (i + 1) * DT
			ppos = pos
		m["reverse_face_time"] = t_face
		m["reverse_back90_time"] = t_back
		m["reverse_overshoot"] = over
		m["reverse_pivoted"] = pivoted
		# stop
		var w5 := c_steady(sp)
		var q0 := c_state(w5)
		var qp := Vector2(q0.x, q0.z)
		var t_stop := -1.0
		for i in 30:
			w5.step({"verb": 1})
			if c_state(w5).speed == 0.0:
				t_stop = (i + 1) * DT
				break
		var q1 := c_state(w5)
		m["stop_time"] = t_stop
		m["stop_distance"] = (Vector2(q1.x, q1.z) - qp).length()
		out[mode] = m
	out["radius_cm"] = profile.radius_cm
	out["speed_profile"] = profile.speed
	results.c = out

# ---------------------------------------------------------------- Godot pipeline

class Run:
	var name := ""
	var t := 0.0
	var ctx := {}

func new_host(stage_ground: Callable) -> Node3D:
	var host := ActorHost.new()
	host.name = "FeelHost"
	root.add_child(host)
	host.setup(genome, 0, profile, stage_ground)
	return host

# keys_fn(t, run) -> keys dict; may call run.ctx.input.set_destination. head_fn(t) -> Vector2 world heading or null.
func scenario(name: String, duration: float, keys_fn: Callable, head_fn: Callable = Callable()) -> Dictionary:
	var ground := Callable(self, "_flat")
	var stage := StageWorld.new()
	stage.ground_fn = ground
	var input := PlayerInput.new()
	if stage.reset(make_setup()) != 0:
		push_error("feel: stage reset")
	var host := new_host(ground)
	var ctl = host.driver.controller
	var s0: Dictionary = stage.cur.entities[0]
	var cam := ChaseCamera.new(host.height(), atan2(s0.fx, s0.fz) + PI, ground)
	var run := Run.new()
	run.name = name
	run.ctx = {"input": input, "stage": stage}
	var keys := {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	input.keys_override = keys
	var ov := {"head": null}
	stage.input_provider = func() -> Dictionary:
		if ov.head != null:
			return hd(ov.head)
		return input.sample()
	stage.after_tick = input.after_tick
	var gaits := [0]
	if ctl != null:
		ctl.gait_changed.connect(func(_a, _b, _f) -> void: gaits[0] += 1)
	var frames := int(round(duration / FRAME))
	var prev_yaw := 0.0
	var yaw_unwrap := 0.0
	var prev_cam := cam.yaw
	var prev_rate := 0.0
	var m := {"name": name, "duration": duration}
	var max_body := 0.0
	var body_travel := 0.0
	var cam_travel := 0.0
	var cam_max := 0.0
	var cam_acc_max := 0.0
	var prev_cam_rate := 0.0
	var max_roll := 0.0
	var no_foot := 0
	var max_speed := 0.0
	var max_rate_jump := 0.0
	var lag_sum := 0.0
	var lag_n := 0
	var slide_max := 0.0
	var stance_start: Array = []        # per leg: Vector3 or null
	var path: Array = []
	var speeds: Array = []
	var lags: Array = []
	var prev_vel := Vector3.ZERO
	var max_vel_jump := 0.0
	var t_yaw: Array = []
	for fi in frames:
		var t := fi * FRAME
		run.t = t
		var k: Dictionary = keys_fn.call(t, run)
		for kk in k:
			keys[kk] = k[kk]
		ov.head = head_fn.call(t) if head_fn.is_valid() else null
		input.view_yaw = cam.view_yaw
		stage.advance(FRAME)
		var sm: Dictionary = stage.sample(0)
		host.update(FRAME, sm)
		var r: Dictionary = cam.update({"x": sm.pos.x, "z": sm.pos.z, "yaw": sm.yaw, "speed": sm.speed, "vx": sm.vel.x, "vz": sm.vel.z}, null, false, FRAME, 1.78)
		input.view_yaw = cam.view_yaw
		if fi > 0:
			var dy := wrapf(sm.yaw - prev_yaw, -PI, PI)
			var rate := dy / FRAME
			max_body = maxf(max_body, absf(rate))
			body_travel += absf(dy)
			if fi > 1:
				max_rate_jump = maxf(max_rate_jump, absf(rate - prev_rate))
			prev_rate = rate
			var dc := wrapf(cam.yaw - prev_cam, -PI, PI)
			var crate := dc / FRAME
			cam_travel += absf(dc)
			cam_max = maxf(cam_max, absf(crate))
			cam_acc_max = maxf(cam_acc_max, absf(crate - prev_cam_rate) / FRAME)
			prev_cam_rate = crate
			max_vel_jump = maxf(max_vel_jump, (sm.vel - prev_vel).length())
		prev_yaw = sm.yaw
		prev_cam = cam.yaw
		prev_vel = sm.vel
		max_speed = maxf(max_speed, sm.speed)
		speeds.append(sm.speed)
		var lag := Vector2(r.target.x - sm.pos.x, r.target.z - sm.pos.z).length()
		lags.append(lag)
		path.append(Vector2(sm.pos.x, sm.pos.z))
		t_yaw.append(sm.yaw)
		if ctl != null and ctl.pose.has("roll"):
			max_roll = maxf(max_roll, absf(rad_to_deg(ctl.pose.roll)))
		if ctl != null and ctl.pose.has("contact"):
			var any := false
			var legs: Array = host.body.legs
			if stance_start.size() != legs.size():
				stance_start.resize(legs.size())
			for i in legs.size():
				var flat: bool = ctl.pose.contact[i] and ctl.pose.foot_pitch[i] < 0.01
				if flat:
					any = true
					var gp: Vector3 = legs[i].foot.global_position
					if stance_start[i] == null:
						stance_start[i] = gp
					else:
						slide_max = maxf(slide_max, Vector2(gp.x - stance_start[i].x, gp.z - stance_start[i].z).length())
				else:
					stance_start[i] = null
			if not any and fi > 60:
				no_foot += 1
	# camera lag: mean while the creature runs near its top speed
	for i in speeds.size():
		if speeds[i] >= 0.95 * max_speed and max_speed > 1.0:
			lag_sum += lags[i]
			lag_n += 1
	m["max_speed"] = max_speed
	m["body_yaw_rate_max_deg"] = rad_to_deg(max_body)
	m["body_yaw_travel_deg"] = rad_to_deg(body_travel)
	m["yaw_rate_jump_max_deg"] = rad_to_deg(max_rate_jump)
	m["cam_yaw_travel_deg"] = rad_to_deg(cam_travel)
	m["cam_yaw_rate_max_deg"] = rad_to_deg(cam_max)
	m["cam_yaw_acc_max"] = cam_acc_max
	m["cam_lag_steady"] = lag_sum / maxf(lag_n, 1)
	m["cam_lag_max"] = lags.max() if not lags.is_empty() else 0.0
	m["frames_no_planted_foot"] = no_foot
	m["max_roll_deg"] = max_roll
	m["slide_mm"] = slide_max * 1000.0
	m["gait_changes"] = gaits[0]
	m["vel_jump_max"] = max_vel_jump
	m["path"] = path
	m["end_yaw"] = prev_yaw
	host.queue_free()
	await process_frame
	return m

func no_keys() -> Dictionary:
	return {"forward": false, "back": false, "left": false, "right": false, "sprint": false}

func key(name: String, sprint := false) -> Dictionary:
	var k := no_keys()
	k[name] = true
	k.sprint = sprint
	return k

# Max distance of the points from the line through the first and last point.
func lateral_deviation(pts: Array) -> float:
	if pts.size() < 3:
		return 0.0
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var dir := (b - a)
	if dir.length() < 1e-6:
		return 0.0
	dir = dir.normalized()
	var worst := 0.0
	for p in pts:
		worst = maxf(worst, absf((p - a).cross(dir)))
	return worst

func measure_pipeline() -> void:
	var sc := {}
	sc["W"] = await scenario("W", 4.0, func(t, _r): return key("forward"))
	sc["S"] = await scenario("S", 6.0, func(t, _r): return key("forward") if t < 2.0 else key("back"))
	sc["A"] = await scenario("A", 6.0, func(t, _r): return key("forward") if t < 2.0 else key("left"))
	sc["D_tap"] = await scenario("D_tap", 4.0, func(t, _r):
		if t < 2.0:
			return key("forward")
		return key("right") if t < 2.3 else no_keys())
	sc["click_behind"] = await scenario("click_behind", 6.0, func(t, r):
		if t < 2.0:
			return key("forward")
		if not r.ctx.has("clicked"):
			r.ctx.clicked = true
			var s0: Dictionary = r.ctx.stage.cur.entities[0]
			r.ctx.input.set_destination(Vector2(s0.x - s0.fx * 20.0, s0.z - s0.fz * 20.0))
		return no_keys())
	sc["fig8"] = await scenario("fig8", 10.0, func(_t, _r): return no_keys(), func(t): return Vector2(cos(1.2 * t), cos(2.4 * t)))
	# straightness of S after the reversal completes (t >= 3.5 s .. 6 s)
	var sp: Array = sc.S.path
	sc.S["lateral_dev_after_reversal"] = lateral_deviation(sp.slice(int(3.5 / FRAME)))
	# the S path summary: displacement behind the start
	for k in sc:
		var p: Array = sc[k].path
		var start: Vector2 = p[0]
		var end: Vector2 = p[p.size() - 1]
		sc[k]["net_displacement"] = (end - start).length()
		sc[k].erase("path")
	results.scenarios = sc

# ---------------------------------------------------------------- output and gates

func fmt(d: Dictionary) -> String:
	var parts: Array = []
	for k in d:
		var v = d[k]
		parts.append("%s=%s" % [k, ("%.3f" % v) if typeof(v) == TYPE_FLOAT else str(v)])
	return " ".join(parts)

func finite_all(d) -> bool:
	if typeof(d) == TYPE_DICTIONARY:
		for k in d:
			if not finite_all(d[k]):
				return false
	elif typeof(d) == TYPE_ARRAY:
		for v in d:
			if not finite_all(v):
				return false
	elif typeof(d) == TYPE_FLOAT:
		return is_finite(d)
	return true

func _run() -> void:
	var game = root.get_node("Game")
	var manifest := Profile.load_json("res://game/data/parts.json")
	genome = game.player_genome()
	var pr := Profile.from_studio(genome, manifest)
	if not pr.ok:
		push_error("no profile")
		quit(2)
		return
	profile = pr.profile
	measure_c()
	print("C part (radius_cm %s, profile speed %s)" % [profile.radius_cm, profile.speed])
	for mode in ["jog", "sprint"]:
		print("  ", mode, ": ", fmt(results.c[mode]))
	await measure_pipeline()
	for k in results.scenarios:
		print("  ", k, ": ", fmt(results.scenarios[k]))
	check(finite_all(results), "every measurement is finite")
	if gates_on:
		Gates.run(self)
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://").path_join("../docs/evidence/godot/feel").simplify_path()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var f := FileAccess.open(out_dir.path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(results, "\t"))
	f.close()
	print("feel test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

# Acceptance gates, added step by step (PLAN-feel section 5).
class Gates:
	static func run(t) -> void:
		var c: Dictionary = t.results.c
		var j: Dictionary = c.jog
		var sp: Dictionary = c.sprint
		# S2: the C motion rule
		t.check(absf(j.top_speed - 5.2) <= 0.05, "jog top speed 5.2 m/s (%.3f)" % j.top_speed)
		t.check(absf(sp.top_speed - 8.84) <= 0.05, "sprint top speed 8.84 m/s (%.3f)" % sp.top_speed)
		t.check(j.t90 <= 0.4 + 1e-6, "jog t90 <= 0.4 s (%.2f)" % j.t90)
		t.check(sp.t90 <= 0.6 + 1e-6, "sprint t90 <= 0.6 s (%.2f)" % sp.t90)
		t.check(j.peak_accel <= 15.01 and sp.peak_accel <= 15.01, "peak acceleration <= 15 m/s2 (%.2f, %.2f)" % [j.peak_accel, sp.peak_accel])
		t.check(j.turn90_time <= 0.8, "90 degree turn at jog <= 0.8 s (%.2f)" % j.turn90_time)
		t.check(j.circle_radius >= 1.5, "tightest circle at jog >= 1.5 m (%.2f)" % j.circle_radius)
		t.check(sp.circle_radius >= 2.5, "tightest circle at sprint >= 2.5 m (%.2f)" % sp.circle_radius)
		t.check(j.reverse_face_time <= 1.0 + 1e-6 and j.reverse_back90_time <= 1.2 + 1e-6, "reversal at jog: facing %.1f s, 90 %% speed back %.1f s" % [j.reverse_face_time, j.reverse_back90_time])
		t.check(j.reverse_overshoot <= 0.6, "reversal overshoot <= 0.6 m (%.2f)" % j.reverse_overshoot)
		t.check(j.stop_time <= 0.8 and j.stop_distance <= 0.6, "stop from jog <= 0.8 s and 0.6 m (%.2f s, %.2f m)" % [j.stop_time, j.stop_distance])
