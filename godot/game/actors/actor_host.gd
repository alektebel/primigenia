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

signal footfall(entity_id: int, position: Vector3, speed: float)

func setup(genome: Dictionary, id: int, prof: Dictionary, ground: Callable) -> void:
	entity_id = id
	profile = prof
	driver = Driver.new()
	body = _try_module(genome)
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

func update(dt: float, s: Dictionary) -> void:
	_speed = s.speed
	driver.update(dt, s)

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
