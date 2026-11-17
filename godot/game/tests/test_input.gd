extends RefCounted
# player_input.gd and pointer.gd.

const PlayerInput := preload("res://game/player/player_input.gd")
const Pointer := preload("res://game/player/pointer.gd")

static func js_heading(vx: float, vz: float) -> Vector2i:
	# The JS rule, written with Math.round semantics: round half up.
	var s := maxf(absf(vx), absf(vz))
	return Vector2i(int(floor(vx / s * 32767.0 + 0.5)), int(floor(vz / s * 32767.0 + 0.5)))

func no_keys() -> Dictionary:
	return {"forward": false, "back": false, "left": false, "right": false, "sprint": false}

func run(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad := 0
	for i in 30:
		var v := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
		if i == 0:
			v = Vector2(-0.5 / 32767.0, 1.0)
		if i == 1:
			v = Vector2(-1.0, 0.5)
		var h: Vector2i = PlayerInput.heading(v)
		if h != js_heading(v.x, v.y) or absi(h.x) > 32767 or absi(h.y) > 32767:
			bad += 1
	t.eq(bad, 0, "heading() follows the JS rule on 30 vectors")
	t.eq(PlayerInput.heading(Vector2(-0.5 / 32767.0, 1.0)), Vector2i(0, 32767), "negative half rounds up like Math.round")
	t.eq(PlayerInput.heading(Vector2(-1.0, 0.5)), Vector2i(-32767, 16384), "x = -1 gives -32767 and 0.5 gives 16384 (round half up)")
	for pair in [[0.0, Vector2(0, -1)], [PI / 2.0, Vector2(-1, 0)], [PI, Vector2(0, 1)]]:
		var w: Vector2 = PlayerInput.camera_relative(0.0, -1.0, pair[0])
		t.check(w.distance_to(pair[1]) < 1e-9, "W at view yaw %.2f maps to %s (got %s)" % [pair[0], pair[1], w])
	var inp = PlayerInput.new()
	inp.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": true}
	var s: Dictionary = inp.sample()
	t.eq([s.verb, s.hx, s.hz, s.sprint], [3, 0, -32767, 1], "W with view yaw 0 heads -Z, sprinting")
	inp.set_destination(Vector2(500, -500))
	t.check((inp.destination as Vector2).distance_to(Vector2(194.9, -194.9)) < 1e-4, "destinations are clamped to +-194.9")
	inp.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	s = inp.sample()
	t.check(s.verb == 2 and absf(s.x - 194.9) < 1e-4 and absf(s.z + 194.9) < 1e-4, "destination gives GO")
	inp.keys_override = {"forward": false, "back": false, "left": true, "right": false, "sprint": false}
	s = inp.sample()
	t.check(s.verb == 3 and inp.destination == null, "WASD clears the destination")
	inp.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	t.eq(inp.sample().verb, 1, "release with no destination gives WAIT")
	inp.set_destination(Vector2(10, 10))
	inp.after_tick({"order": {"verb": 1}})
	t.eq(inp.destination, null, "destination cleared once the world's order is not GO")
	inp.keys_override = {"forward": true, "back": false, "left": false, "right": true, "sprint": true}
	inp.blocked = func() -> bool: return true
	s = inp.sample()
	t.eq([s.verb, s.get("sprint", 0)], [1, 0], "movement_blocked zeroes movement keys")

	# Input latch (PLAN-feel S3): a held key keeps its heading while the view yaw rotates.
	var lat = PlayerInput.new()
	var back := {"forward": false, "back": true, "left": false, "right": false, "sprint": false}
	lat.keys_override = back
	lat.view_yaw = 0.0
	var h0: Dictionary = lat.sample()
	var same := true
	for i in 40:
		lat.view_yaw = i * 0.3
		var hi: Dictionary = lat.sample()
		same = same and hi.hx == h0.hx and hi.hz == h0.hz
	t.check(same, "holding back for 40 ticks with a rotating view_yaw gives a constant heading")
	lat.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	lat.view_yaw = 1.0
	var hw: Dictionary = lat.sample()
	lat.view_yaw = 2.0
	lat.keys_override = back
	var hs: Dictionary = lat.sample()
	var expect: Vector2i = PlayerInput.heading(PlayerInput.camera_relative(0.0, 1.0, 2.0))
	t.check(hs.hx == expect.x and hs.hz == expect.y and (hw.hx != hs.hx or hw.hz != hs.hz), "W then S re-latches to the view at the S press")
	lat.keys_override = no_keys()
	lat.sample()
	t.check(lat.frame_yaw == null, "releasing the keys clears the latch")
	var iy = lat.intent_yaw()
	t.check(iy == null, "no keys, no destination: no intent")
	lat.keys_override = back
	lat.view_yaw = 0.7
	var iy2 = lat.intent_yaw()
	t.check(iy2 != null and absf(wrapf(iy2 - 0.7, -PI, PI)) < 1e-6, "intent while keys are held")
	lat.sample()
	lat.view_yaw = 2.5
	var iy3 = lat.intent_yaw()
	t.check(absf(wrapf(iy3 - iy2, -PI, PI)) < 1e-9, "intent_yaw is pure and follows the latched frame")
	var live = PlayerInput.new()
	live.strafe_latch = false
	live.keys_override = back
	live.view_yaw = 0.0
	var l0: Dictionary = live.sample()
	live.view_yaw = 1.0
	var l1: Dictionary = live.sample()
	t.check(l0.hx != l1.hx or l0.hz != l1.hz, "strafe_latch off keeps the old live-camera behaviour")
	var tk = PlayerInput.new()
	tk.tank = true
	tk.facing_yaw = 0.5
	tk.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	var th: Dictionary = tk.sample()
	var want: Vector2i = PlayerInput.heading(Vector2(sin(0.5), cos(0.5)))
	t.check(th.hx == want.x and th.hz == want.y, "tank: W goes along the creature's heading")
	tk.keys_override = {"forward": true, "back": false, "left": true, "right": false, "sprint": false}
	var tl: Dictionary = tk.sample()
	var yawl := atan2(float(tl.hx), float(tl.hz))
	t.check(absf(yawl - 0.5 - 0.22) < 0.01, "tank: A turns the heading left (+yaw) by 0.22 rad per tick (got %.3f)" % yawl)
	tk.keys_override = {"forward": false, "back": true, "left": false, "right": false, "sprint": false}
	var tb: Dictionary = tk.sample()
	var yawb := atan2(float(tb.hx), float(tb.hz))
	t.check(absf(wrapf(yawb - (0.5 + 0.22 + PI), -PI, PI)) < 0.01, "tank: S reverses")

	# Ray march on a plane and a slope.
	var plane := func(x: float, z: float) -> float: return 42.0
	var hit = Pointer.march(Vector3(0, 100, 0), Vector3(0.3, -1, 0.2).normalized(), plane)
	t.check(hit != null and absf(hit.y - 42.0) < 0.01, "ray hits the plane at y = 42 within 1 cm")
	var o := Vector3(0, 100, 0)
	var dir := Vector3(0.3, -1, 0.2).normalized()
	var expect_t := (100.0 - 42.0) / absf(dir.y)
	t.check(hit != null and absf(o.distance_to(hit) - expect_t) < 0.01, "plane hit distance matches the analytic value")
	var slope := func(x: float, z: float) -> float: return 20.0 + 0.3 * x
	var hit2 = Pointer.march(Vector3(0, 80, 0), Vector3(1, -1, 0).normalized(), slope)
	# ray y = 80 - x ; slope y = 20 + .3x -> x = 60 / 1.3
	t.check(hit2 != null and absf(hit2.x - 60.0 / 1.3) < 0.01, "ray hits the slope within 1 cm")
	t.eq(Pointer.march(Vector3(0, 100, 0), Vector3(0, 1, 0), plane), null, "a ray into the sky hits nothing")
	var ents := [{"id": 0, "x": 0, "z": 0, "dead": false}, {"id": 1, "x": 10, "z": 0, "dead": false, "radius_cm": 60}]
	var picked: Dictionary = Pointer.pick_entity(Vector3(10, 50, 6), Vector3(0, -0.9, -0.5).normalized() * 1.0 + Vector3.ZERO, ents, plane)
	t.check(picked.is_empty() or picked.id == 1, "pick never returns the player or a dead entity")
	var straight: Dictionary = Pointer.pick_entity(Vector3(10, 42.5, 10), Vector3(0, 0, -1), ents, plane)
	t.eq(straight.get("id", -1), 1, "a ray through the creature picks it before the ground")
