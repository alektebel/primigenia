extends RefCounted
# Player intent -> CpStageInput, sampled once per C tick (port of web/stage action()/input()).
# Combat keys are NOT handled here (the UI module reads raw keys); only movement.

const VERB_WAIT := 1
const VERB_GO := 2
const VERB_HEADING := 3
const LIMIT := 194.9

var view_yaw := 0.0          # camera yaw, set by the chase camera each frame
var destination = null       # Vector2 (x, z) or null
var blocked: Callable = Callable()   # () -> bool, e.g. Game.movement_blocked
var keys_override: Variant = null    # tests: {forward, back, left, right, sprint}

# JS Math.round(v / s * 32767) with floor(+.5), so negative halves round like JavaScript.
static func heading(v: Vector2) -> Vector2i:
	var s := maxf(absf(v.x), absf(v.y))
	if s <= 0.0:
		return Vector2i.ZERO
	return Vector2i(int(floor(v.x / s * 32767.0 + 0.5)), int(floor(v.y / s * 32767.0 + 0.5)))

static func camera_relative(x: float, z: float, yaw: float) -> Vector2:
	return Vector2(x * cos(yaw) + z * sin(yaw), -x * sin(yaw) + z * cos(yaw))

func _read_keys() -> Dictionary:
	if keys_override != null:
		return keys_override
	return {
		"forward": Input.is_action_pressed("move_forward"), "back": Input.is_action_pressed("move_back"),
		"left": Input.is_action_pressed("move_left"), "right": Input.is_action_pressed("move_right"),
		"sprint": Input.is_action_pressed("sprint"),
	}

func set_destination(p: Vector2) -> void:
	destination = Vector2(clampf(p.x, -LIMIT, LIMIT), clampf(p.y, -LIMIT, LIMIT))

func clear_destination() -> void:
	destination = null

func sample() -> Dictionary:
	var k := _read_keys()
	var is_blocked: bool = blocked.is_valid() and blocked.call()
	var x := 0.0
	var z := 0.0
	if not is_blocked:
		x = float(bool(k.right)) - float(bool(k.left))
		z = float(bool(k.back)) - float(bool(k.forward))
	var sprint := 1 if (bool(k.sprint) and not is_blocked) else 0
	if x != 0.0 or z != 0.0:
		destination = null
		var h := heading(camera_relative(x, z, view_yaw))
		return {"verb": VERB_HEADING, "hx": h.x, "hz": h.y, "sprint": sprint}
	if destination != null:
		var d: Vector2 = destination
		return {"verb": VERB_GO, "x": d.x, "z": d.y, "sprint": int(bool(k.sprint))}
	return {"verb": VERB_WAIT}

# Web: the destination is cleared once the world's standing order is no longer GO.
func after_tick(state: Dictionary) -> void:
	if state.order.verb != VERB_GO:
		destination = null
