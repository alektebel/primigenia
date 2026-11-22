extends Node3D
# One creature of the C world on the island. Uses the g-creature module when it is present and the
# genome loads; otherwise the M0 placeholder. Looks the module up at runtime (no preload).

const Placeholder := preload("res://game/actors/placeholder_creature.gd")
const Driver := preload("res://game/actors/actor_driver.gd")
const Look := preload("res://game/island/look.gd")

const CREATURE_MODULE := "res://creature/creature.gd"

var entity_id := 0
var profile: Dictionary = {}
var module_path := CREATURE_MODULE   # tests point this at a fake module
var driver
var body: Node3D
var uses_module := false
var _height := 1.0
var screen_notifier: VisibleOnScreenNotifier3D
static var visual_lod_enabled := true # benchmark reference path
var _visual_dt := 0.0
var _visual_skipped := false

# Starting LOD distances for T15: near/player always full; benchmark and owner review tune these.
func visual_interval(camera: Camera3D, player_distance: float) -> int:
	if not visual_lod_enabled or entity_id == 0:
		return 1
	if not is_visible_in_tree():
		return 0
	if player_distance < 40.0 or camera.global_position.distance_to(global_position) < 40.0:
		return 1
	var on_screen := screen_notifier.is_on_screen() if screen_notifier != null else true
	# The headless renderer never emits visibility signals. Use the same camera's frustum there.
	if DisplayServer.get_name() == "headless":
		on_screen = camera.is_position_in_frustum(global_position + Vector3.UP * _height * 0.5)
	if not on_screen:
		return 0
	return 2 if camera.global_position.distance_to(global_position) < 80.0 else 4

## Root motion always follows C. Invisible time is discarded; resume resets feet at the current root.
func update_visual(dt: float, s: Dictionary, ctx: Dictionary, interval: int, frame: int) -> void:
	if interval == 0:
		position = s.pos
		rotation = Vector3(0, s.yaw, 0)
		_visual_dt = 0.0
		_visual_skipped = true
		return
	if _visual_skipped:
		driver.rebase()
		_visual_skipped = false
	_visual_dt += dt
	if interval > 1 and posmod(frame + entity_id, interval) != 0:
		# Rig poses use world space, so leave the last solved pose until its next update.
		position = s.pos
		rotation = Vector3(0, s.yaw, 0)
		return
	update(_visual_dt, s, ctx)
	_visual_dt = 0.0

signal footfall(entity_id: int, position: Vector3, speed: float)

func setup(genome: Dictionary, id: int, prof: Dictionary, ground: Callable, cache = null) -> void:
	entity_id = id
	profile = prof
	driver = Driver.new()
	body = cache.instantiate(genome) if cache != null and module_path == CREATURE_MODULE else _try_module(genome)
	if body != null and body.has_method("set_sun_direction"):
		body.set_sun_direction(Look.sun_dir())
	if body == null:
		var ph := Placeholder.new()
		ph.build(genome)
		body = ph
		_height = maxf(0.5, ph.rest_aabb().size.y)
		uses_module = false
	else:
		uses_module = true
		_height = maxf(0.5, (body.rest_aabb() as AABB).size.y)
	add_child(body)
	screen_notifier = VisibleOnScreenNotifier3D.new()
	# Rest bounds include the entire body; a generous margin covers gait and action excursions.
	var bounds: AABB = body.rest_aabb()
	screen_notifier.aabb = bounds.grow(maxf(_height, 2.0))
	add_child(screen_notifier)
	driver.setup(self, body, not uses_module, ground)
	driver.footfall.connect(func(_leg: int, pos: Vector3) -> void: footfall.emit(entity_id, pos, _speed))

func _try_module(genome: Dictionary) -> Node3D:
	if not ResourceLoader.exists(module_path):
		return null
	var script = load(module_path)
	if script == null:
		return null
	var c = script.new()
	if not c.has_method("load_genome"):
		return null
	var res = c.load_genome(genome)
	if typeof(res) != TYPE_DICTIONARY or not res.get("ok", false):
		push_warning("creature module rejected the genome: %s" % [res.get("error", "?") if typeof(res) == TYPE_DICTIONARY else res])
		if c is Node:
			c.free()
		return null
	if c.has_method("set_sun_direction"):
		c.set_sun_direction(Look.sun_dir())
	return c if c is Node3D else null

func height() -> float:
	return _height

var _speed := 0.0

func update(dt: float, s: Dictionary, ctx: Dictionary = {}) -> void:
	_speed = s.speed
	driver.update(dt, s, ctx)

## Bodies without an action layer (radial): a small squash on every bite so the meal still reads.
func driver_eat_pulse() -> void:
	driver.eat_pulse()

func layer():
	return driver.layer

## World position of the mouth tip as the action solver last placed it (Vector3.ZERO without an action layer).
func mouth_world() -> Vector3:
	return driver.layer._mouth_world if driver.layer != null else Vector3.ZERO

# Up to 12 occluder spheres (x, y, z, r) in world space for the contact shadow.
func occluders() -> Array:
	var out := []
	if uses_module and "rest" in body and "rad" in body:
		var n: int = body.rest.size()
		var go: float = body.ground_offset
		for k in 8:
			var i: int = 6 + int(round(k * (n - 13) / 7.0))
			var w: Vector3 = body.to_global(body.rest[i] + Vector3(0, go, 0))
			out.append(Vector4(w.x, w.y, w.z, body.rad[i] * 1.05))
		for leg in body.legs:
			if out.size() >= 12:
				break
			var f: Vector3 = leg.foot.global_position
			out.append(Vector4(f.x, f.y + leg.width * 0.6, f.z, maxf(0.15, leg.width * 1.1)))
	elif body.has_method("spine_points"):
		for sp in body.spine_points(8):
			var w: Vector3 = to_global(sp.pos)
			out.append(Vector4(w.x, w.y, w.z, sp.r * 1.05))
		if body.has_method("foot_points"):
			for f in body.foot_points():
				if out.size() >= 12:
					break
				var w: Vector3 = to_global(f)
				out.append(Vector4(w.x, w.y + FOOT_Y, w.z, 0.25))
	else:
		var c := global_position + Vector3(0, _height * 0.5, 0)
		out.append(Vector4(c.x, c.y, c.z, _height * 0.4))
	return out

const FOOT_Y := 0.2
