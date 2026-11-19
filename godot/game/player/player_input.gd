extends RefCounted
# Player intent -> CpStageInput, sampled once per C tick (port of web/stage action()/input()).
# Combat keys are NOT handled here (the UI module reads raw keys); only movement.

const VERB_WAIT := 1
const VERB_GO := 2
const VERB_HEADING := 3
var limit := 194.9             # destinations are clamped to +-limit (the island sets it to the C world's bound - 0.1)

var view_yaw := 0.0          # camera yaw, set by the chase camera each frame
var destination = null       # Vector2 (x, z) or null
var blocked: Callable = Callable()   # () -> bool, e.g. Game.movement_blocked
var keys_override: Variant = null    # tests: {forward, back, left, right, sprint}
# Controls (settings controls/strafe_latch and controls/tank, see Game.settings):
#  strafe_latch (default): the key frame is the camera yaw at the moment the key combination changed, so
#    holding S or A runs in a straight line instead of circling with the auto-following camera.
#  strafe_latch off: the live camera yaw is used every tick (the old behaviour, a held S circles).
#  tank: A/D turn the heading at TANK_TURN rad/s, W goes along it, S reverses; no camera involved.
var strafe_latch := true
var tank := false
var frame_yaw = null         # latched view yaw (null: nothing held)
var facing_yaw := 0.0        # the creature's heading, set by the island (tank mode, intent)
var position := Vector2.INF  # the creature's world x, z, set by the island (intent towards a destination)
var _last_keys := 0
var suspended := false       # flight test: the creature flies, C is told to wait (the island teleports it each tick)
var _tank_yaw = null
const TANK_TURN := 2.2       # rad/s
const K_FWD := 1
const K_BACK := 2
const K_LEFT := 4
const K_RIGHT := 8

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
	destination = Vector2(clampf(p.x, -limit, limit), clampf(p.y, -limit, limit))

# Hold to follow: the mouse target is re-sent while the button is held; a move of less than `min_move` metres is ignored,
# so a still mouse does not replan the path every tick.
func follow_to(p: Vector2, min_move: float = 0.6) -> void:
	var q := Vector2(clampf(p.x, -limit, limit), clampf(p.y, -limit, limit))
	if destination != null and (destination as Vector2).distance_to(q) < min_move:
		return
	destination = q

func clear_destination() -> void:
	destination = null

func _mask(k: Dictionary) -> int:
	return (K_FWD if k.forward else 0) | (K_BACK if k.back else 0) | (K_LEFT if k.left else 0) | (K_RIGHT if k.right else 0)

func _axes(k: Dictionary, is_blocked: bool) -> Vector2:
	if is_blocked:
		return Vector2.ZERO
	return Vector2(float(bool(k.right)) - float(bool(k.left)), float(bool(k.back)) - float(bool(k.forward)))

# The view yaw the current keys are relative to (pure: no latch update).
func _effective_yaw(mask: int) -> float:
	if not strafe_latch or tank:
		return view_yaw
	if frame_yaw == null or mask != _last_keys:
		return view_yaw
	return frame_yaw

# The world yaw (radians, atan2(x, z) bearing) the player is asking for right now, or null. Pure.
func intent_yaw() -> Variant:
	if suspended:
		return null
	var k := _read_keys()
	var is_blocked: bool = blocked.is_valid() and blocked.call()
	var a := _axes(k, is_blocked)
	if a != Vector2.ZERO:
		if tank:
			var y: float = facing_yaw if _tank_yaw == null else _tank_yaw
			y -= a.x * TANK_TURN * 0.1      # A (left) turns toward +X when facing +Z
			return y + PI if a.y > 0.0 else y
		var h := camera_relative(a.x, a.y, _effective_yaw(_mask(k)))
		return atan2(h.x, h.y)
	if destination != null and position.x < 1e8:
		var d: Vector2 = (destination as Vector2) - position
		if d.length() > 0.5:
			return atan2(d.x, d.y)
	return null

func sample() -> Dictionary:
	if suspended:
		return {"verb": VERB_WAIT}
	var k := _read_keys()
	var is_blocked: bool = blocked.is_valid() and blocked.call()
	var a := _axes(k, is_blocked)
	var sprint := 1 if (bool(k.sprint) and not is_blocked) else 0
	var mask := 0 if is_blocked else _mask(k)
	if mask == 0:
		frame_yaw = null
		_tank_yaw = null
	if a != Vector2.ZERO:
		destination = null
		var dir: Vector2
		if tank:
			if _tank_yaw == null:
				_tank_yaw = facing_yaw
			_tank_yaw = wrapf(_tank_yaw - a.x * TANK_TURN * 0.1, -PI, PI)
			var ty: float = _tank_yaw if a.y <= 0.0 else _tank_yaw + PI    # S reverses
			dir = Vector2(sin(ty), cos(ty))
		else:
			if strafe_latch and (frame_yaw == null or mask != _last_keys):
				frame_yaw = view_yaw
			dir = camera_relative(a.x, a.y, frame_yaw if (strafe_latch and frame_yaw != null) else view_yaw)
		_last_keys = mask
		var h := heading(dir)
		return {"verb": VERB_HEADING, "hx": h.x, "hz": h.y, "sprint": sprint}
	_last_keys = mask
	if destination != null:
		var d: Vector2 = destination
		return {"verb": VERB_GO, "x": d.x, "z": d.y, "sprint": int(bool(k.sprint))}
	return {"verb": VERB_WAIT}

# Web: the destination is cleared once the world's standing order is no longer GO.
func after_tick(state: Dictionary) -> void:
	if state.order.verb != VERB_GO:
		destination = null
