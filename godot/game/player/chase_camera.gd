extends RefCounted
# Spore-style chase camera, port of web/stage/camera.js (G72 numbers). Pure maths: feed it the
# player pose each frame; it returns where the camera goes. ground: Callable(x, z) -> float.

var height: float
var yaw: float
var pitch := 0.24
var min_distance: float
var max_distance: float
var distance: float
var orbit_pitch := 0.0
var manual := 0.0
var target = null            # Vector3, eased look-at point
var boom = null              # float, eased boom length
var fight_blend := 0.0
var view_yaw: float
var ground: Callable
# Calm follow (PLAN-feel S6)
const LEAD := 0.12             # s: the look-at point leads the creature by this much of its velocity
const POS_TAU := 0.12          # s: first-order follow of the look-at point
const VEL_TAU := 0.15          # s: low-pass of the creature's velocity
const YAW_TAU := 0.5           # s: the yaw closes 1/e of its error in this time...
const YAW_MAX := 1.74          # rad/s: ...but never faster than this (100 deg/s)
const YAW_ACC := 6.0           # rad/s2: angular acceleration limit
const AWAY_MAX := 1.9199       # rad (110 deg): follow only when running away from or across the camera
const PIVOT_RATE := 2.5        # rad/s: no swing while the creature pivots
const ENGAGE_TIME := 0.25      # s: the heading must have been steady (within 20 deg) over this time
const ENGAGE_TOL := 0.3491     # rad (20 deg)
var kick := false              # optional speed cues (settings camera/kick): wider fov and boom near sprint speed
var top_speed := 8.84
var fov_add := 0.0
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
	min_distance = height * 2.8
	max_distance = height * 12.0
	distance = height * 6.0
	ground = ground_fn

func orbit(dx: float, dy: float) -> void:
	yaw -= dx * 0.006
	view_yaw -= dx * 0.006
	orbit_pitch = clampf(orbit_pitch + dy * 0.004, -0.2, 0.5)
	manual = 0.15

func zoom(delta: float) -> void:
	distance = clampf(distance + delta, min_distance, max_distance)

# player: {x, z, yaw, speed}; enemy: {x, z} or null. Returns {position, target, yaw, pitch, distance, actual_distance}.
func update(player: Dictionary, enemy, fighting: bool, dt: float, aspect: float = 1.6) -> Dictionary:
	manual = maxf(0.0, manual - dt)
	_clock += dt
	_follow(player, dt)
	var wide := clampf((distance / height - 6.0) / 6.0, 0.0, 1.0)
	pitch = clampf(0.24 + wide * 0.6 + orbit_pitch, 0.04, 1.15)
	var h := height
	# the discrete first-order follow (player moved first, then eased) lags by dt (1-k)/k = about tau - dt/2: lead by exactly that
	var kf := 1.0 - exp(-dt / POS_TAU) if dt > 0.0 else 1.0
	var lead := LEAD if dt <= 0.0 else dt * (1.0 - kf) / kf
	var tgt := Vector3(player.x + _vel_s.x * lead, ground.call(player.x, player.z) + h * 1.5, player.z + _vel_s.y * lead)
	fight_blend = lerpf(fight_blend, 1.0 if fighting else 0.0, 1.0 - exp(-dt / 0.25) if dt > 0.0 else 1.0)
	view_yaw = yaw + fight_blend * 0.85
	var desired := distance * (1.25 if aspect < 0.7 else 1.0)
	var kick_goal := clampf((float(player.speed) - 0.8 * top_speed) / (0.2 * top_speed), 0.0, 1.0) if kick else 0.0
	_kick_k = lerpf(_kick_k, kick_goal, 1.0 - exp(-dt / 0.3) if dt > 0.0 else 1.0)
	fov_add = 5.0 * _kick_k
	desired *= 1.0 + 0.06 * _kick_k
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
	boom = desired if boom == null else lerpf(boom, desired, 1.0 - exp(-dt / 0.3) if dt > 0.0 else 1.0)
	var dir := Vector3(sin(view_yaw) * cos(pitch), sin(pitch), cos(view_yaw) * cos(pitch))
	var length: float = boom
	var d := 0.2
	while d <= float(boom) + 0.2:
		var s := minf(d, float(boom))
		var sx := tv.x + dir.x * s
		var sz := tv.z + dir.z * s
		if tv.y + dir.y * s < ground.call(sx, sz) + 0.65:
			length = maxf(0.0, s - 0.25)
			break
		d += 0.2
	var pos := tv + dir * length
	pos.y = maxf(pos.y, ground.call(pos.x, pos.z) + 0.65)
	return {"fov_add": fov_add, "position": pos, "target": tv, "yaw": view_yaw, "pitch": pitch, "distance": boom, "actual_distance": length}

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
	if player.speed > 0.4 and manual == 0.0 and absf(_player_rate) < PIVOT_RATE and absf(e) < AWAY_MAX and steady:
		w_goal = clampf(e / YAW_TAU, -YAW_MAX, YAW_MAX)
	if manual > 0.0:
		yaw_rate = 0.0
	else:
		yaw_rate = move_toward(yaw_rate, w_goal, YAW_ACC * dt)
	yaw += yaw_rate * dt
