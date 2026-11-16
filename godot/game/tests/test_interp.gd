extends RefCounted
# stage_world.gd sample(): C1 Hermite through the C ticks (PLAN-feel S4).

const StageWorld := preload("res://game/stage/stage_world.gd")

func fresh() -> Node:
	var sw := StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(7)
	setup.terrain = 1
	setup.flat_height = 0.0
	setup.wild = []
	setup.obstacles = []
	var rc: int = sw.reset(setup)
	if rc != 0:
		push_error("test_interp reset %d" % rc)
	sw.ground_fn = func(_x: float, _z: float) -> float: return 0.0
	return sw

func hdg(x: float, z: float, sprint: int = 0) -> Dictionary:
	var s := maxf(absf(x), absf(z))
	return {"verb": 3, "hx": int(round(x / s * 32767.0)), "hz": int(round(z / s * 32767.0)), "sprint": sprint}

func run(t) -> void:
	var sw = fresh()
	var tick := [0]
	# run at jog, then a held 90 degree heading change, then straight again
	var f0: Dictionary = sw.cur.entities[0]
	var fwd := Vector2(f0.fx, f0.fz)
	var side := Vector2(-fwd.y, fwd.x)
	sw.input_provider = func() -> Dictionary:
		tick[0] += 1
		return hdg(fwd.x, fwd.y) if tick[0] <= 20 else hdg(side.x, side.y)
	for i in 3:
		sw.step_once()
	t.check(Vector2(sw.sample(0, 0.0).pos.x - sw.prev.entities[0].x, sw.sample(0, 0.0).pos.z - sw.prev.entities[0].z).length() < 1e-6, "sample(0) is the previous tick's position")
	t.check(Vector2(sw.sample(0, 1.0).pos.x - sw.cur.entities[0].x, sw.sample(0, 1.0).pos.z - sw.cur.entities[0].z).length() < 1e-6, "sample(1) is the current tick's position")
	var last_end: Dictionary = sw.sample(0, 1.0)
	var worst_dv := 0.0
	var worst_dyaw := 0.0
	var yaws: Array = []
	var monotone := true
	var prev_yaw_end := 0.0
	for i in 40:
		sw.step_once()
		var st: Dictionary = sw.sample(0, 0.0)
		worst_dv = maxf(worst_dv, (st.vel - last_end.vel).length())
		worst_dyaw = maxf(worst_dyaw, absf(wrapf(st.yaw - last_end.yaw, -PI, PI)))
		last_end = sw.sample(0, 1.0)
		for k in 11:
			yaws.append(sw.sample(0, k / 10.0).yaw)
	t.check(worst_dv < 0.05, "velocity is continuous across ticks through a 90 degree turn at jog (worst jump %.3f m/s)" % worst_dv)
	t.check(worst_dyaw < 1e-6, "yaw is continuous across ticks (%.2g rad)" % worst_dyaw)
	# the turn is one direction: the unwrapped yaw series never reverses
	var dir := 0.0
	for i in range(1, yaws.size()):
		var d: float = wrapf(yaws[i] - yaws[i - 1], -PI, PI)
		if absf(d) < 1e-9:
			continue
		if dir == 0.0:
			dir = signf(d)
		elif signf(d) != dir and absf(d) > 1e-6:
			monotone = false
	t.check(monotone, "yaw is monotone through a constant-direction turn (no wobble when C snaps to the heading)")
	# a teleport (respawn, arena placement) is a straight line: no overshoot outside [prev, cur]
	var sj = fresh()
	var base: Dictionary = sj.cur
	var e0: Dictionary = (base.entities[0] as Dictionary).duplicate()
	sj.pprev = {"entities": [e0.merged({"x": -1.0, "z": 0.0}, true)], "active": -1}
	sj.prev = {"entities": [e0.merged({"x": 0.0, "z": 0.0}, true)], "active": -1}
	sj.cur = {"entities": [e0.merged({"x": 10.0, "z": 0.0}, true)], "active": -1}
	var inside := true
	for k in 11:
		var px: float = sj.sample(0, k / 10.0).pos.x
		inside = inside and px >= -1e-9 and px <= 10.0 + 1e-9
	t.check(inside, "a 10 m jump (respawn) has no overshoot")
	t.check(absf(sj.sample(0, 0.5).pos.x - 5.0) < 1e-5, "and is linear (%.6f at alpha .5)" % sj.sample(0, 0.5).pos.x)
	# a stop does not overshoot either: chords 0.5, 0.15, 0
	sj.pprev = {"entities": [e0.merged({"x": 0.0, "z": 0.0}, true)], "active": -1}
	sj.prev = {"entities": [e0.merged({"x": 0.5, "z": 0.0}, true)], "active": -1}
	sj.cur = {"entities": [e0.merged({"x": 0.5, "z": 0.0}, true)], "active": -1}
	var behind := false
	for k in 11:
		behind = behind or sj.sample(0, k / 10.0).pos.x > 0.5 + 1e-9
	t.check(not behind, "a stopped creature does not slide past its resting point")
	sw.free()
	sj.free()
