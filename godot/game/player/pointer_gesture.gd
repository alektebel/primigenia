extends RefCounted
# Left-button gesture of the stage (docs/godot/CAMERA-ZOOM.md s1, docs/godot/FEEL.md "Hold to follow"):
#   - a press that moves more than DRAG_PX before HOLD_WALK is an orbit drag;
#   - one that stays put and is released before HOLD_WALK is a click (acted on at release: walk there / pick);
#   - one that stays put for HOLD_WALK becomes a HOLD: the creature follows the mouse for as long as the button is down,
#     and moving the mouse then steers it (it never turns into an orbit; release to orbit again).

const DRAG_PX := 6.0
const HOLD_WALK := 0.15

var down := false
var dragging := false
var holding := false
var double := false
var press_pos := Vector2.ZERO
var held := 0.0

func press(pos: Vector2, is_double: bool = false) -> void:
	down = true
	dragging = false
	holding = false
	double = is_double
	press_pos = pos
	held = 0.0

# Mouse moved to `pos` with the button down: true while the gesture is an orbit drag.
func motion(pos: Vector2) -> bool:
	if down and not dragging and not holding and pos.distance_to(press_pos) > DRAG_PX:
		dragging = true
		holding = false
	return dragging

func tick(dt: float) -> void:
	if down and not dragging and not holding:
		held += dt
		holding = held >= HOLD_WALK

# "click" (act at press_pos), "hold" (already steering), "drag" (was an orbit) or "" (no press).
func release() -> String:
	if not down:
		return ""
	var r := "drag" if dragging else ("hold" if holding else "click")
	down = false
	dragging = false
	holding = false
	return r
