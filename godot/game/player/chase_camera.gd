extends RefCounted
# Spore-style chase camera, port of web/stage/camera.js (G72 numbers). Pure maths: feed it the
# player pose each frame; it returns where the camera goes. ground: Callable(x, z) -> float.

var height: float
var yaw: float
var pitch := 0.2618             # camera elevation above the look-at point (>= FLOOR_PITCH)
var look_pitch := 0.2618        # where the camera is aimed: equal to pitch when looking at the creature, below FLOOR_PITCH when looking up
var min_distance: float
var max_distance: float
var distance: float
var orbit_pitch := 0.0
var manual := 0.0
# One zoom parameter (docs/godot/CAMERA-ZOOM.md section 2): 0 = close-up ... 1 = strategic island map.
const Z_CHASE := 0.15            # the default gameplay view
const Z_KEYS := [0.0, 0.15, 0.40, 0.70, 1.0]
const KEY_DIST_H := [1.8, 4.0, 12.0]       # body heights, for z 0, 0.15, 0.40
const MIN_DISTANCE := 1.6                  # m: the closest view never gets nearer than this, whatever the body (a 0.65 m hatchling)
const KEY_PITCH_DEG := [8.0, 15.0, 35.0, 55.0, 70.0]
const TACTICAL_DISTANCE := 150.0           # m at z 0.7
const ICON_Z := 0.7              # strategic icons start to fade in above this
const ZOOM_STEP := 0.04          # z per wheel notch
const ZOOM_TAU := 0.2            # s: z closes 1/e of its error in this time...
const ZOOM_RATE := 1.4           # z/s: ...but never faster than this (a full zoom takes about 0.7 s)
const ORBIT_HOLD := 1.0          # s of moving before the camera comes back behind after an orbit
const PITCH_RETURN := 0.6        # rad/s cap of the orbit pitch easing back
const MAX_PITCH := 1.4
# Looking at the sky (docs/godot/CAMERA-ZOOM.md s5): the orbit pitch may go far below zero. The camera then sinks towards
# the ground and stops rising above its own floor, while its aim tilts past the horizon up to LOOK_MIN (-60 deg).
const ORBIT_PITCH_MIN := -1.6
const ORBIT_PITCH_MAX := 0.5
const LOOK_MIN := -1.0472
const FLOOR_PITCH := 0.04      # lowest camera elevation above the look-at point while it still looks at the creature
var z := Z_CHASE                 # eased
var z_target := Z_CHASE
var strategic_distance := 3000.0 # m at z = 1 (the island; the island sets it from its size)
var map_center := Vector2.ZERO   # where the strategic view looks (XZ)
var free_orbit := false          # setting camera/free_orbit: the camera never returns behind by itself
var mouse_walk := false          # the creature walks to a left click / follows the mouse: no auto-turn of the camera for that
var orbit_active := false        # the mouse is dragging the camera right now
var _orbited := false            # the player has orbited: the way back may pass the 110 deg "towards the camera" limit
var _reset := false
var _flick := 0.0
var _last_wheel := -10.0
var target = null            # Vector3, eased look-at point
var boom = null              # float, eased boom length
var fight_blend := 0.0
var view_yaw: float
var ground: Callable
# Calm follow (PLAN-feel S6)
var LEAD := 0.12             # s: the look-at point leads the creature by this much of its velocity
var POS_TAU := 0.12          # s: first-order follow of the look-at point
var VEL_TAU := 0.15          # s: low-pass of the creature's velocity
var YAW_TAU := 0.5           # s: the yaw closes 1/e of its error in this time...
var YAW_MAX := 1.74          # rad/s: ...but never faster than this (100 deg/s)
var YAW_ACC := 6.0           # rad/s2: angular acceleration limit
var AWAY_MAX := 1.9199       # rad (110 deg): follow only when running away from or across the camera
var PIVOT_RATE := 2.5        # rad/s: no swing while the creature pivots
var ENGAGE_TIME := 0.25      # s: the heading must have been steady (within 20 deg) over this time
var ENGAGE_TOL := 0.3491     # rad (20 deg)
var kick := false              # optional speed cues (settings camera/kick): wider fov and boom near sprint speed
var top_speed := 8.84
var fov_add := 0.0
# Flight (F1): the island sets `air_y` (world height of the flyer) and `air_on`; the camera pulls back x1.6, rises with the
# flyer and widens the fov by 8 degrees in a dive; it eases back to the chase curve in 0.5 s after landing. Roll is not followed.
var air_y := 0.0          # world height of the flyer's feet-level origin
var air_on := false
var air_dive := false
var air_bank := 0.0       # tan of the flyer's bank (+ = left); the camera rolls ROLL_FOLLOW of it, eased
const ROLL_FOLLOW := 0.3  # share of the bank angle the view rolls: the horizon tilt reads without turning the view over
const AIR_YAW_TAU := 0.7  # s: in the air the view yaw closes 1/e of its error to the flight path in this time (a smooth lag)
var roll := 0.0           # the view's roll about its forward axis (rad, + = left side down), output of update()
var _air_k := 0.0
var _air_dive_k := 0.0
var yaw_rate := 0.0            # the auto-follow's angular velocity (rad/s)
var _vel_s := Vector2.ZERO
var _clock := 0.0
var _ring: Array = []          # [time, player yaw] over the last 0.3 s
var _last_player_yaw = null
var _player_rate := 0.0
var _kick_k := 0.0

func _init(creature_height: float, start_yaw: float, ground_fn: Callable) -> void:
	height = maxf(0.5, creature_height)
	yaw = start_yaw
	view_yaw = start_yaw
	ground = ground_fn
	min_distance = curve_distance(0.0)
	max_distance = curve_distance(1.0)
	distance = curve_distance(z)

# ---- the zoom curve (pure functions of z) ---------------------------------------------------------
func _key_distances() -> Array:
	var d: Array = [maxf(MIN_DISTANCE, height * KEY_DIST_H[0]), height * KEY_DIST_H[1], height * KEY_DIST_H[2], maxf(TACTICAL_DISTANCE, height * KEY_DIST_H[2] * 1.5), 0.0]
	d[4] = maxf(strategic_distance, d[3] * 2.0)
	return d

# Interpolates in log space (each wheel notch is the same relative change) between the key distances.
func curve_distance(zz: float) -> float:
	zz = clampf(zz, 0.0, 1.0)
	var d := _key_distances()
	for i in 4:
		if zz <= Z_KEYS[i + 1]:
			var t: float = (zz - Z_KEYS[i]) / (Z_KEYS[i + 1] - Z_KEYS[i])
			return exp(lerpf(log(d[i]), log(d[i + 1]), t))
	return d[4]

func curve_pitch(zz: float) -> float:
	zz = clampf(zz, 0.0, 1.0)
	for i in 4:
		if zz <= Z_KEYS[i + 1]:
			var t: float = (zz - Z_KEYS[i]) / (Z_KEYS[i + 1] - Z_KEYS[i])
			return deg_to_rad(lerpf(KEY_PITCH_DEG[i], KEY_PITCH_DEG[i + 1], t))
	return deg_to_rad(KEY_PITCH_DEG[4])

# 0 up to the tactical band, 1 at the strategic map: the look-at point drifts to the island centre.
func map_blend() -> float:
	return smoothstep(0.75, 1.0, z)

# Strategic icon opacity: 0 at z <= 0.7, 1 near the map.
func icon_alpha() -> float:
	return icon_alpha_at(z)

static func icon_alpha_at(zz: float) -> float:
	return smoothstep(ICON_Z, 0.88, zz)

# ---- input ---------------------------------------------------------------------------------------
func orbit(dx: float, dy: float) -> void:
	yaw -= dx * 0.006
	view_yaw -= dx * 0.006
	orbit_pitch = clampf(orbit_pitch + dy * 0.004, ORBIT_PITCH_MIN, ORBIT_PITCH_MAX)
	manual = ORBIT_HOLD
	_orbited = true
	_reset = false

# Wheel notches: -1 in, +1 out. A fast flick (several notches within a quarter second) goes farther.
func zoom(steps: float) -> void:
	_flick = _flick * exp(-(_clock - _last_wheel) / 0.25) + absf(steps)
	_last_wheel = _clock
	var gain := 1.0 + minf(_flick - 1.0, 5.0) * 0.5
	z_target = clampf(z_target + steps * ZOOM_STEP * maxf(gain, 1.0), 0.0, 1.0)

func set_zoom(zz: float, immediate: bool = false) -> void:
	z_target = clampf(zz, 0.0, 1.0)
	if immediate:
		z = z_target
		distance = curve_distance(z)

# Home / middle click: back behind the creature at the default distance.
func reset_behind() -> void:
	_reset = true
	_orbited = false
	manual = 0.0
	z_target = Z_CHASE

# player: {x, z, yaw, speed}; enemy: {x, z} or null. Returns {position, target, yaw, pitch, distance, actual_distance}.
func update(player: Dictionary, enemy, fighting: bool, dt: float, aspect: float = 1.6) -> Dictionary:
	_clock += dt
	var moving: bool = float(player.speed) > 0.4
	if moving and not orbit_active and not free_orbit:
		manual = maxf(0.0, manual - dt)       # the orbit holds while you stand still; it counts down while you move
	elif orbit_active:
		manual = ORBIT_HOLD
	_follow(player, dt)
	# zoom: first-order with a rate cap
	var zerr := z_target - z
	if dt > 0.0:
		z += clampf(zerr * (1.0 - exp(-dt / ZOOM_TAU)), -ZOOM_RATE * dt, ZOOM_RATE * dt)
	else:
		z = z_target
	z = z_target if absf(z_target - z) < 1e-4 else clampf(z, 0.0, 1.0)
	distance = curve_distance(z)
	# the orbit pitch goes back with the yaw (not while standing still, not in free orbit)
	if (_reset or (moving and manual == 0.0 and not free_orbit)) and not orbit_active:
		if dt > 0.0:
			orbit_pitch += clampf(-orbit_pitch * (1.0 - exp(-dt / 0.5)), -PITCH_RETURN * dt, PITCH_RETURN * dt)
		else:
			orbit_pitch = 0.0
	look_pitch = clampf(curve_pitch(z) + orbit_pitch, LOOK_MIN, MAX_PITCH)
	pitch = maxf(look_pitch, FLOOR_PITCH)
	var mb := map_blend()
	var h := height
	# the discrete first-order follow (player moved first, then eased) lags by dt (1-k)/k = about tau - dt/2: lead by exactly that
	var kf := 1.0 - exp(-dt / POS_TAU) if dt > 0.0 else 1.0
	var lead := LEAD if dt <= 0.0 else dt * (1.0 - kf) / kf
	var roll_goal := ROLL_FOLLOW * atan(air_bank) if air_on else 0.0
	roll = roll_goal if dt <= 0.0 else lerpf(roll, roll_goal, 1.0 - exp(-dt / 0.35))
	_air_k = lerpf(_air_k, 1.0 if air_on else 0.0, 1.0 - exp(-dt / (0.3 if air_on else 0.17)) if dt > 0.0 else 1.0)
	_air_dive_k = lerpf(_air_dive_k, 1.0 if (air_on and air_dive) else 0.0, 1.0 - exp(-dt / 0.25) if dt > 0.0 else 1.0)
	var ground_y: float = ground.call(player.x, player.z)
	var tgt := Vector3(player.x + _vel_s.x * lead, lerpf(ground_y + h * 1.5, maxf(air_y, ground_y) + h * 0.8, _air_k), player.z + _vel_s.y * lead)
	if mb > 0.0:
		tgt.x = lerpf(tgt.x, map_center.x, mb)
		tgt.z = lerpf(tgt.z, map_center.y, mb)
		tgt.y = lerpf(tgt.y, ground.call(tgt.x, tgt.z), mb)
	fight_blend = lerpf(fight_blend, 1.0 if fighting else 0.0, 1.0 - exp(-dt / 0.25) if dt > 0.0 else 1.0)
	view_yaw = yaw + fight_blend * 0.85
	var desired := distance * (1.25 if aspect < 0.7 else 1.0)
	var kick_goal := clampf((float(player.speed) - 0.8 * top_speed) / (0.2 * top_speed), 0.0, 1.0) if kick else 0.0
	_kick_k = lerpf(_kick_k, kick_goal, 1.0 - exp(-dt / 0.3) if dt > 0.0 else 1.0)
	fov_add = 5.0 * _kick_k - 8.0 * smoothstep(0.7, 1.0, z)       # a flatter, map-like view at the far end
	desired *= 1.0 + 0.06 * _kick_k
	desired *= 1.0 + 0.6 * _air_k
	fov_add += 8.0 * _air_dive_k
	if fighting and enemy != null:
		tgt.x = (player.x + enemy.x) / 2.0
		tgt.z = (player.z + enemy.z) / 2.0
		tgt.y = (ground.call(player.x, player.z) + ground.call(enemy.x, enemy.z)) / 2.0 + h * 1.5
		var sep := Vector2(player.x - enemy.x, player.z - enemy.z).length()
		var half_fov := atan(tan(deg_to_rad(24.0)) * minf(1.0, aspect))
		desired = maxf(desired + sep * 0.6, (sep / 2.0 + h * 1.5) / sin(half_fov * 0.85))
	var ease_t := 1.0 - exp(-dt / POS_TAU) if dt > 0.0 else 1.0
	if target == null:
		target = tgt
	target = (target as Vector3).lerp(tgt, ease_t)
	# Never smooth the safety correction: a newly intersecting ridge pulls in now.
	var tv: Vector3 = target
	tv.y = maxf(tv.y, ground.call(tv.x, tv.z) + 0.8)
	target = tv
	var boom_tau := 0.3 if (fighting or fight_blend > 0.01) else 0.1
	boom = desired if boom == null else lerpf(boom, desired, 1.0 - exp(-dt / boom_tau) if dt > 0.0 else 1.0)
	var dir := Vector3(sin(view_yaw) * cos(pitch), sin(pitch), cos(view_yaw) * cos(pitch))
	var length: float = boom
	var d := 0.2
	while float(boom) <= 400.0 and d <= float(boom) + 0.2:      # far away the camera is high above the ground: only the floor clamp below
		var s := minf(d, float(boom))
		var sx := tv.x + dir.x * s
		var sz := tv.z + dir.z * s
		if tv.y + dir.y * s < ground.call(sx, sz) + 0.65:
			length = maxf(0.0, s - 0.25)
			break
		d += maxf(0.2, d * 0.02)
	var pos := tv + dir * length
	# Looking up: the camera sinks towards the ground (never under it) and its aim goes up past the horizon.
	var up_amount := clampf((FLOOR_PITCH - look_pitch) / (FLOOR_PITCH - LOOK_MIN), 0.0, 1.0)
	if up_amount > 0.0 and mb < 0.5:
		pos.y = lerpf(pos.y, minf(pos.y, ground.call(pos.x, pos.z) + 1.0 + h * 0.5), up_amount)
	pos.y = maxf(pos.y, ground.call(pos.x, pos.z) + 0.65)
	var aim := tv
	if look_pitch < pitch:
		var f := -look_pitch
		aim = pos + Vector3(-sin(view_yaw) * cos(f), sin(f), -cos(view_yaw) * cos(f)) * 20.0
	return {"fov_add": fov_add, "position": pos, "target": tv, "aim": aim, "look_pitch": look_pitch, "yaw": view_yaw, "pitch": pitch, "distance": boom, "actual_distance": length, "z": z, "roll": roll}

# Auto-follow of the creature's heading with a rate cap and an acceleration cap. It does not swing when the creature
# runs towards the camera (more than 110 degrees away), pivots, has not held its heading for a quarter of a second
# (a tap of a key), or while the player orbits by hand.
func _follow(player: Dictionary, dt: float) -> void:
	var pyaw: float = player.yaw
	_player_rate = 0.0 if _last_player_yaw == null or dt <= 0.0 else wrapf(pyaw - float(_last_player_yaw), -PI, PI) / dt
	_last_player_yaw = pyaw
	_ring.append([_clock, pyaw])
	while _ring.size() > 2 and _ring[1][0] <= _clock - ENGAGE_TIME:
		_ring.pop_front()
	var then: float = _ring[0][1]
	var steady: bool = absf(wrapf(pyaw - then, -PI, PI)) < ENGAGE_TOL and _clock - _ring[0][0] >= ENGAGE_TIME * 0.8
	var v := Vector2(player.get("vx", 0.0), player.get("vz", 0.0))
	_vel_s = v if dt <= 0.0 else _vel_s.lerp(v, 1.0 - exp(-dt / VEL_TAU))
	var e := wrapf(pyaw + PI - yaw, -PI, PI)
	var w_goal := 0.0
	var air := air_on and not _reset
	var away_max := PI if _orbited else AWAY_MAX       # after an orbit the way back behind the creature is allowed to pass 110 deg
	if _reset:
		w_goal = clampf(e / YAW_TAU, -YAW_MAX, YAW_MAX)
	elif air and manual == 0.0 and not free_orbit and absf(e) < away_max:
		# flying: the view follows the flight path continuously (a steady turn never counts as "steady" on the ground), smooth lag
		w_goal = clampf(e / AIR_YAW_TAU, -YAW_MAX, YAW_MAX)
	elif player.speed > 0.4 and manual == 0.0 and not free_orbit and not mouse_walk and absf(_player_rate) < PIVOT_RATE and absf(e) < away_max and steady:
		w_goal = clampf(e / YAW_TAU, -YAW_MAX, YAW_MAX)
	if manual > 0.0 and not _reset:
		yaw_rate = 0.0
	else:
		yaw_rate = move_toward(yaw_rate, w_goal, YAW_ACC * dt)
	yaw += yaw_rate * dt
	if (_orbited or _reset) and absf(e) < 0.03 and manual == 0.0:
		_orbited = false
		if _reset and absf(yaw_rate) < 0.1 and absf(orbit_pitch) < 0.01:
			_reset = false
