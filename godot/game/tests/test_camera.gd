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

	# Auto-follow: after 0.4 s of steady motion with a 90 degree offset the yaw closes 1 - 1/e.
	var c2 = ChaseCamera.new(h, 0.0, flat)
	var mover = {"x": 0.0, "z": 0.0, "yaw": 0.0, "speed": 5.0}
	var start = c2.yaw
	var want = wrapf(mover.yaw + PI - start, -PI, PI)
	for i in 8:
		c2.update(mover, null, false, 0.05)
	var closed: float = (c2.yaw - start) / want
	t.check(absf(closed - (1.0 - exp(-1.0))) < 0.02, "yaw closes %.3f of the gap in 0.4 s (expected 0.632)" % closed)
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
