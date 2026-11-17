extends RefCounted
# chase_camera.gd on a synthetic ground.

const ChaseCamera := preload("res://game/player/chase_camera.gd")
const Gesture := preload("res://game/player/pointer_gesture.gd")
const StrategicIcons := preload("res://game/island/strategic_icons.gd")

func run(t) -> void:
	var flat = func(x: float, z: float) -> float: return 10.0
	var h = 2.0
	var cam = ChaseCamera.new(h, PI, flat)
	var player = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}
	var r: Dictionary = {}
	for i in 100:
		r = cam.update(player, null, false, 0.05)
	# CAMERA-ZOOM s2 changes the default view from 6h / 0.24 rad to the chase band: z 0.15 = 4h, 15 deg.
	t.check(absf(cam.distance - 4.0 * h) < 1e-9, "default distance is 4h (z 0.15)")
	t.check(absf(cam.pitch - deg_to_rad(15.0)) < 1e-9, "default pitch is 15 deg")
	t.check(absf(r.target.y - (10.0 + 1.5 * h)) < 0.01, "look-at is ground + 1.5h after settling")
	t.check(absf(r.actual_distance - 4.0 * h) < 0.3, "boom settles at 4h")
	# Horizon in the upper third for a 1280x720 viewport (fov 48 vertical).
	var fwd = (r.target - r.position).normalized()
	var up = Vector3.UP
	var right = fwd.cross(up).normalized()
	var cam_up = right.cross(fwd).normalized()
	var far = r.position + Vector3(fwd.x, 0, fwd.z).normalized() * 5000.0
	var rel = far - r.position
	var z = rel.dot(fwd)
	var y = rel.dot(cam_up)
	var ndc_y = (y / z) / tan(deg_to_rad(24.0))
	var screen_y = (1.0 - ndc_y) * 0.5   # 0 top, 1 bottom
	t.check(screen_y < 1.0 / 3.0, "the horizon sits in the upper third (%.2f of the height from the top)" % screen_y)
	t.check(screen_y > 0.1, "and is not at the very top (%.2f)" % screen_y)

	# Auto-follow (PLAN-feel S6): a rate cap, an acceleration cap, an engage delay, no swing towards the camera.
	var c2 = ChaseCamera.new(h, 0.0, flat)
	var mover = {"x": 0.0, "z": 0.0, "yaw": PI / 2.0, "speed": 5.0, "vx": 5.0, "vz": 0.0}
	var prev_w := 0.0
	var max_rate := 0.0
	var max_acc := 0.0
	var prev_yaw: float = c2.yaw
	for i in 120:
		mover.x += 5.0 * 0.05
		c2.update(mover, null, false, 0.05)
		var w: float = (c2.yaw - prev_yaw) / 0.05
		max_rate = maxf(max_rate, absf(w))
		max_acc = maxf(max_acc, absf(w - prev_w) / 0.05)
		prev_w = w
		prev_yaw = c2.yaw
	var goal := wrapf(mover.yaw + PI - c2.yaw, -PI, PI)
	t.check(absf(goal) < 0.05, "the yaw settles behind the creature after 6 s (error %.3f rad)" % goal)
	t.check(max_rate <= 1.75, "auto-follow yaw rate stays under 100 deg/s (max %.1f deg/s)" % rad_to_deg(max_rate))
	t.check(max_acc <= 6.0 + 1e-3, "auto-follow angular acceleration <= 6 rad/s2 (max %.2f)" % max_acc)
	# Running towards the camera does not swing it.
	var c2b = ChaseCamera.new(h, 0.0, flat)
	var toward = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0, "vx": 0.0, "vz": 0.0}
	for i in 80:
		c2b.update(toward, null, false, 0.05)
	t.eq(c2b.yaw, 0.0, "a creature running towards the camera does not swing it")
	# A tap (heading turns fast and comes back) does not swing it either: the heading must hold for a quarter second.
	var c2c = ChaseCamera.new(h, PI, flat)
	var tap = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0, "vx": 0.0, "vz": 5.0}
	for i in 20:
		c2c.update(tap, null, false, 0.05)
	var y_before: float = c2c.yaw
	for i in 6:
		tap.yaw += 0.15
		c2c.update(tap, null, false, 0.05)
	t.check(absf(wrapf(c2c.yaw - y_before, -PI, PI)) < deg_to_rad(5.0), "a 0.3 s tap of a turn key moves the camera less than 5 degrees (%.1f)" % rad_to_deg(absf(wrapf(c2c.yaw - y_before, -PI, PI))))
	# No swing while the creature pivots.
	var c2d = ChaseCamera.new(h, PI, flat)
	var piv = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0, "vx": 0.0, "vz": 5.0}
	for i in 20:
		c2d.update(piv, null, false, 0.05)
	var yd: float = c2d.yaw
	for i in 20:
		piv.yaw += 0.2
		c2d.update(piv, null, false, 0.05)
	t.check(absf(wrapf(c2d.yaw - yd, -PI, PI)) < deg_to_rad(5.0), "a pivoting creature (4 rad/s) does not swing the camera")
	# A scripted reversal: the camera yaw rate never exceeds the cap.
	var c2e = ChaseCamera.new(h, PI, flat)
	var rev = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0, "vx": 0.0, "vz": 5.0}
	var worst := 0.0
	var py: float = c2e.yaw
	for i in 200:
		rev.yaw = 0.0 if i < 40 else PI * minf(1.0, (i - 40) / 8.0)      # facing flips in 0.4 s
		if i >= 60:
			rev.yaw = PI
		c2e.update(rev, null, false, 1.0 / 60.0)
		worst = maxf(worst, absf(wrapf(c2e.yaw - py, -PI, PI)) * 60.0)
		py = c2e.yaw
	t.check(worst <= 1.75, "reversal: camera yaw rate <= 100 deg/s (max %.1f deg/s)" % rad_to_deg(worst))
	# The look-at point leads the creature: no steady lag at sprint speed.
	var c2f = ChaseCamera.new(h, PI, flat)
	var run = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 8.84, "vx": 0.0, "vz": 8.84}
	var lag := 0.0
	for i in 240:
		run.z += 8.84 / 60.0
		var rr: Dictionary = c2f.update(run, null, false, 1.0 / 60.0)
		lag = Vector2(rr.target.x - run.x, rr.target.z - run.z).length()
	t.check(lag < 0.05, "steady target lag at 8.84 m/s is %.3f m (< 0.05)" % lag)
	# Orbit gives a manual grace during which auto-follow is off.
	var c3 = ChaseCamera.new(h, 0.0, flat)
	c3.orbit(10.0, 0.0)
	var y0: float = c3.yaw
	c3.update(mover, null, false, 0.05)
	t.eq(c3.yaw, y0, "no auto-follow during the 0.15 s orbit grace")
	# Zoom: the ends of the curve (z 1 = the strategic map, z 0 = close-up).
	var c4 = ChaseCamera.new(h, 0.0, flat)
	c4.strategic_distance = 3000.0
	c4.zoom(1000.0)
	for i in 120:
		c4.update(player, null, false, 0.05)
	t.eq(c4.z, 1.0, "zoom clamps at z 1")
	t.check(absf(c4.distance - 3000.0) < 1e-6, "at z 1 the camera is the strategic distance (%.1f)" % c4.distance)
	t.check(absf(c4.pitch - deg_to_rad(70.0)) < 1e-6, "at z 1 the pitch is 70 deg")
	c4.zoom(-1000.0)
	for i in 120:
		c4.update(player, null, false, 0.05)
	t.eq(c4.z, 0.0, "zoom clamps at z 0")
	t.check(absf(c4.distance - 1.8 * h) < 1e-9, "at z 0 the camera is 1.8h away")
	t.check(absf(c4.pitch - deg_to_rad(8.0)) < 1e-9, "at z 0 the pitch is 8 deg")
	# A ridge between target and camera shortens the boom; the camera stays above ground.
	var ridge = func(x: float, zz: float) -> float: return 10.0 + (30.0 if (zz > 4.0 and zz < 9.0) else 0.0)
	var c5 = ChaseCamera.new(h, 0.0, ridge)
	var r5 = {}
	for i in 80:
		r5 = c5.update(player, null, false, 0.05)
	t.check(r5.actual_distance < c5.distance - 1.0, "a ridge behind the player shortens the boom (%.2f < %.2f)" % [r5.actual_distance, c5.distance])
	t.check(r5.position.y >= ridge.call(r5.position.x, r5.position.z) + 0.65 - 1e-6, "camera stays 0.65 m above the ground")
	# Fight framing keeps both fighters in the frustum.
	var c6 = ChaseCamera.new(h, 0.0, flat)
	var fighter = {"x": 14.0, "z": 3.0}
	var r6 = {}
	for i in 120:
		r6 = c6.update(player, fighter, true, 0.05, 1280.0 / 720.0)
	var inside = true
	var f6: Vector3 = (r6.target - r6.position).normalized()
	var right6: Vector3 = f6.cross(Vector3.UP).normalized()
	var up6: Vector3 = right6.cross(f6).normalized()
	for p in [Vector3(0, 10 + h, 0), Vector3(14, 10 + h, 3)]:
		var rel6: Vector3 = p - r6.position
		var zz: float = rel6.dot(f6)
		var xx: float = absf(rel6.dot(right6)) / zz / (tan(deg_to_rad(24.0)) * 16.0 / 9.0)
		var yy: float = absf(rel6.dot(up6)) / zz / tan(deg_to_rad(24.0))
		if zz <= 0.0 or xx > 1.0 or yy > 1.0:
			inside = false
	t.check(inside, "fight framing keeps both fighters inside the frustum")

	_zoom_curve(t)
	_orbit(t)
	_gesture(t)
	_icons(t)

# ---- CAMERA-ZOOM s4 -------------------------------------------------------------------------------
func _zoom_curve(t) -> void:
	var h := 2.0
	var flat = func(x: float, z: float) -> float: return 10.0
	# the curve is monotonic in distance and pitch, and passes through the spec's key points
	var cam = ChaseCamera.new(h, 0.0, flat)
	cam.strategic_distance = 3000.0
	var pd := -1.0
	var pp := -1.0
	var mono := true
	for i in 101:
		var zz := i / 100.0
		var d: float = cam.curve_distance(zz)
		var p: float = cam.curve_pitch(zz)
		if d <= pd or p <= pp:
			mono = false
		pd = d
		pp = p
	t.check(mono, "zoom curve: distance and pitch strictly increase with z over 101 samples")
	t.check(absf(cam.curve_distance(0.4) - 12.0 * h) < 1e-9 and absf(cam.curve_pitch(0.4) - deg_to_rad(35.0)) < 1e-9, "zoom curve: z 0.4 is 12h at 35 deg")
	t.check(absf(cam.curve_distance(0.7) - 150.0) < 1e-9 and absf(cam.curve_pitch(0.7) - deg_to_rad(55.0)) < 1e-9, "zoom curve: z 0.7 is 150 m at 55 deg")
	# a giant creature still gets an increasing curve
	var big = ChaseCamera.new(40.0, 0.0, flat)
	t.check(big.curve_distance(0.7) > big.curve_distance(0.4) and big.curve_distance(1.0) > big.curve_distance(0.7), "zoom curve: stays increasing for a 40 m creature")
	# the zoom is eased: a notch does not jump, a flick goes farther than the same notches spread out
	var c = ChaseCamera.new(h, 0.0, flat)
	c.update({"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}, null, false, 1.0 / 60.0)
	c.zoom(1.0)
	var z0: float = c.z
	c.update({"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}, null, false, 1.0 / 60.0)
	t.check(c.z - z0 < 0.02, "one notch moves z by less than 0.02 in a frame (%.4f)" % (c.z - z0))
	var slow = ChaseCamera.new(h, 0.0, flat)
	var fast = ChaseCamera.new(h, 0.0, flat)
	for i in 6:
		fast.zoom(1.0)
		fast.update({"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}, null, false, 0.02)
		slow.update({"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}, null, false, 0.5)
		slow.zoom(1.0)
	t.check(fast.z_target > slow.z_target + 0.05, "a fast flick goes farther (z target %.2f vs %.2f)" % [fast.z_target, slow.z_target])
	# the zoom rate cap
	var cz = ChaseCamera.new(h, 0.0, flat)
	cz.zoom(1000.0)
	var worst := 0.0
	var last: float = cz.z
	for i in 120:
		cz.update({"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}, null, false, 1.0 / 60.0)
		worst = maxf(worst, (cz.z - last) * 60.0)
		last = cz.z
	t.check(worst <= ChaseCamera.ZOOM_RATE + 1e-6, "zoom rate stays under %.1f z/s (max %.2f)" % [ChaseCamera.ZOOM_RATE, worst])
	# the camera never goes under the terrain: 200 random points x random z, a rolling synthetic terrain
	var hills = func(x: float, zz: float) -> float: return 40.0 + 25.0 * sin(x * 0.02) * cos(zz * 0.017) + 12.0 * sin(x * 0.11 + zz * 0.07)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var under := 0
	for k in 200:
		var cc = ChaseCamera.new(h, rng.randf() * TAU, hills)
		cc.strategic_distance = 3000.0
		cc.set_zoom(rng.randf(), true)
		var pl := {"x": rng.randf_range(-1700.0, 1700.0), "z": rng.randf_range(-1700.0, 1700.0), "yaw": 0.0, "speed": 0.0}
		cc.orbit(rng.randf_range(-200.0, 200.0), rng.randf_range(-200.0, 200.0))
		var rr: Dictionary = {}
		for i in 3:
			rr = cc.update(pl, null, false, 0.05)
		if rr.position.y < hills.call(rr.position.x, rr.position.z) + 0.65 - 1e-6:
			under += 1
	t.eq(under, 0, "the camera is never below the terrain (200 random points and zooms)")
	# frame time at z = 1: the camera's own CPU cost (ground probes included) stays well inside a 60 fps frame
	var cb = ChaseCamera.new(h, 0.0, hills)
	cb.strategic_distance = 3000.0
	cb.set_zoom(1.0, true)
	var t0 := Time.get_ticks_usec()
	for i in 300:
		cb.update({"x": 20.0, "z": 30.0, "yaw": 0.0, "speed": 3.0, "vx": 0.0, "vz": 3.0}, null, false, 1.0 / 60.0)
	var per := (Time.get_ticks_usec() - t0) / 300.0 / 1000.0
	t.check(per < 1.0, "camera update at z 1 costs %.3f ms (< 1 ms)" % per)
	# the strategic view looks at the island centre, not at the creature
	var cs = ChaseCamera.new(h, 0.0, flat)
	cs.map_center = Vector2(10.0, -20.0)
	cs.set_zoom(1.0, true)
	var rs: Dictionary = {}
	for i in 100:
		rs = cs.update({"x": 150.0, "z": 150.0, "yaw": 0.0, "speed": 0.0}, null, false, 0.05)
	t.check(Vector2(rs.target.x - 10.0, rs.target.z + 20.0).length() < 1.0, "at z 1 the camera looks at the island centre (%s)" % rs.target)

func _orbit(t) -> void:
	var h := 2.0
	var flat = func(x: float, z: float) -> float: return 10.0
	var still := {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}
	var run := {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0, "vx": 0.0, "vz": 5.0}
	var c = ChaseCamera.new(h, PI, flat)
	for i in 20:
		c.update(still, null, false, 0.05)
	c.orbit_active = true
	c.orbit(-100.0, 60.0)          # yaw +0.6, pitch up
	c.orbit_active = false
	var yaw_o: float = c.yaw
	var pit_o: float = c.orbit_pitch
	t.check(absf(yaw_o - PI) > 0.5 and pit_o > 0.2, "orbit moves yaw and pitch (%.2f, %.2f)" % [yaw_o - PI, pit_o])
	for i in 400:      # 20 s standing still
		c.update(still, null, false, 0.05)
	t.check(c.yaw == yaw_o and c.orbit_pitch == pit_o, "the orbit holds while the creature stands still")
	# moving: first the hold (1 s), then it eases back behind, with the old rate and acceleration caps
	var y_prev: float = c.yaw
	var w_prev := 0.0
	var max_w := 0.0
	var max_a := 0.0
	var held_ok := true
	for i in 400:
		run.z += 5.0 * 0.05
		c.update(run, null, false, 0.05)
		var w: float = (c.yaw - y_prev) / 0.05
		max_w = maxf(max_w, absf(w))
		max_a = maxf(max_a, absf(w - w_prev) / 0.05)
		w_prev = w
		y_prev = c.yaw
		if i < 18 and c.yaw != yaw_o:
			held_ok = false
	t.check(held_ok, "after an orbit the camera waits about a second before returning")
	t.check(absf(wrapf(c.yaw - (run.yaw + PI), -PI, PI)) < 0.05, "it comes back behind the creature (error %.3f rad)" % wrapf(c.yaw - (run.yaw + PI), -PI, PI))
	t.check(absf(c.orbit_pitch) < 0.01, "and the pitch offset returns to 0 (%.3f)" % c.orbit_pitch)
	t.check(max_w <= 1.75 and max_a <= 6.0 + 1e-3, "the way back keeps the F1 caps (%.0f deg/s, %.2f rad/s2)" % [rad_to_deg(max_w), max_a])
	# free orbit never returns
	var cf = ChaseCamera.new(h, PI, flat)
	cf.free_orbit = true
	cf.orbit(-100.0, 60.0)
	var yf: float = cf.yaw
	for i in 200:
		run.z += 0.25
		cf.update(run, null, false, 0.05)
	t.check(cf.yaw == yf and cf.orbit_pitch > 0.2, "free orbit: the camera stays where you put it while moving")
	# orbited all the way round to the front, the creature running away from where the camera was: still returns
	var cr = ChaseCamera.new(h, 0.0, flat)
	cr.orbit(-PI / 0.006 * 0.9, 0.0)         # nearly in front of the creature (it heads +Z, yaw 0)
	for i in 600:
		run.z += 0.25
		cr.update(run, null, false, 1.0 / 60.0 * 3.0)
	t.check(absf(wrapf(cr.yaw - (run.yaw + PI), -PI, PI)) < 0.1, "from the front the camera also finds its way behind (error %.2f rad)" % wrapf(cr.yaw - (run.yaw + PI), -PI, PI))
	# Home / middle click: back behind at the default distance, even standing still
	var ch = ChaseCamera.new(h, PI, flat)
	ch.set_zoom(0.9, true)
	ch.orbit(300.0, -40.0)
	ch.reset_behind()
	for i in 200:
		ch.update(still, null, false, 0.05)
	t.check(absf(wrapf(ch.yaw - (still.yaw + PI), -PI, PI)) < 0.05 and absf(ch.z - ChaseCamera.Z_CHASE) < 0.01 and absf(ch.orbit_pitch) < 0.01, "reset: behind the creature, default zoom, level pitch")

func _gesture(t) -> void:
	var g := Gesture.new()
	g.press(Vector2(100, 100))
	t.check(not g.motion(Vector2(103, 102)), "a 3 px wobble is not a drag")
	t.eq(g.release(), "click", "a press that stays put is a click (it moves the creature)")
	g.press(Vector2(100, 100))
	t.check(g.motion(Vector2(110, 100)), "10 px away is a drag")
	g.motion(Vector2(101, 100))
	t.eq(g.release(), "drag", "a drag released back on the press point is still a drag (no click)")
	g.press(Vector2(0, 0))
	g.tick(0.1)
	t.check(not g.holding, "0.1 s is not a hold")
	g.tick(0.15)
	t.check(g.holding, "0.25 s without moving is a hold (keeps steering)")
	t.eq(g.release(), "hold", "a hold is not also a click")
	t.eq(g.release(), "", "release without a press does nothing")
	g.press(Vector2(0, 0))
	g.tick(0.1)
	g.motion(Vector2(30, 0))
	g.tick(1.0)
	t.check(not g.holding, "a drag never turns into a hold")

func _icons(t) -> void:
	var cam = ChaseCamera.new(2.0, 0.0, func(x: float, z: float) -> float: return 0.0)
	t.eq(cam.icon_alpha(), 0.0, "icons: invisible at the default zoom")
	var below := true
	for i in 71:
		if cam.icon_alpha_at(i / 100.0) != 0.0:
			below = false
	t.check(below, "icons: alpha is 0 for every z <= 0.7")
	t.check(cam.icon_alpha_at(0.71) > 0.0 and cam.icon_alpha_at(0.8) > cam.icon_alpha_at(0.71) and cam.icon_alpha_at(1.0) == 1.0, "icons: fade in above z 0.7 and are solid at the map")
	var layer = StrategicIcons.new()
	layer.update_alpha(cam.icon_alpha_at(0.7))
	t.check(not layer.visible, "the icon layer is hidden at z 0.7")
	layer.update_alpha(cam.icon_alpha_at(0.75))
	t.check(layer.visible, "the icon layer shows above z 0.7")
	layer.free()
