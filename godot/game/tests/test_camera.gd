extends RefCounted
# chase_camera.gd on a synthetic ground.

const ChaseCamera := preload("res://game/player/chase_camera.gd")

func run(t) -> void:
	var flat = func(x: float, z: float) -> float: return 10.0
	var h = 2.0
	var cam = ChaseCamera.new(h, PI, flat)
	var player = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 0.0}
	var r: Dictionary = {}
	for i in 100:
		r = cam.update(player, null, false, 0.05)
	t.check(absf(cam.distance - 6.0 * h) < 1e-9, "default distance is 6h")
	t.check(absf(cam.pitch - 0.24) < 1e-9, "default pitch is 0.24 rad")
	t.check(absf(r.target.y - (10.0 + 1.5 * h)) < 0.01, "look-at is ground + 1.5h after settling")
	t.check(absf(r.actual_distance - 6.0 * h) < 0.3, "boom settles at 6h")
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
	# Zoom raises the pitch.
	var c4 = ChaseCamera.new(h, 0.0, flat)
	c4.zoom(1000.0)
	t.eq(c4.distance, 12.0 * h, "zoom clamps at 12h")
	c4.update(player, null, false, 0.05)
	t.check(absf(c4.pitch - 0.84) < 1e-9, "at 12h the pitch is 0.24 + 0.6")
	c4.zoom(-1000.0)
	t.eq(c4.distance, 2.8 * h, "zoom clamps at 2.8h")
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
