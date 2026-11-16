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
	if player.speed > 0.4 and manual == 0.0:
		yaw += wrapf(player.yaw + PI - yaw, -PI, PI) * (1.0 - exp(-dt / 0.4))
	var wide := clampf((distance / height - 6.0) / 6.0, 0.0, 1.0)
	pitch = clampf(0.24 + wide * 0.6 + orbit_pitch, 0.04, 1.15)
	var h := height
	var tgt := Vector3(player.x, ground.call(player.x, player.z) + h * 1.5, player.z)
	fight_blend = lerpf(fight_blend, 1.0 if fighting else 0.0, 1.0 - exp(-dt / 0.25) if dt > 0.0 else 1.0)
	view_yaw = yaw + fight_blend * 0.85
	var desired := distance * (1.25 if aspect < 0.7 else 1.0)
	if fighting and enemy != null:
		tgt.x = (player.x + enemy.x) / 2.0
		tgt.z = (player.z + enemy.z) / 2.0
		tgt.y = (ground.call(player.x, player.z) + ground.call(enemy.x, enemy.z)) / 2.0 + h * 1.5
		var sep := Vector2(player.x - enemy.x, player.z - enemy.z).length()
		var half_fov := atan(tan(deg_to_rad(24.0)) * minf(1.0, aspect))
		desired = maxf(desired + sep * 0.6, (sep / 2.0 + h * 1.5) / sin(half_fov * 0.85))
	var ease_t := 1.0 - exp(-dt / 0.25) if dt > 0.0 else 1.0
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
	return {"position": pos, "target": tv, "yaw": view_yaw, "pitch": pitch, "distance": boom, "actual_distance": length}
