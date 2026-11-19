extends Control
## Guard and dodge at your creature's feet (docs/godot/UI-DIEGETIC.md 7.6), only in a fight or while Attack is chosen: a
## faint bone ring under you with three small marks (13 u, MIST outline): dodge left (Q) at its left, dodge right (E) at
## its right, guard (Space) in front, towards the camera. Pressed: the outline thickens for SWAP. Guard held: the front half
## of the ring becomes a thick MIST arc. Clickable; replaces the Guard / Dodge buttons of the old hotbar.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")

signal guard_pressed
signal dodge_pressed(dir: int)

const R_MARK := 13.0

var centre := Vector2.ZERO          # the player's feet on screen
var ring_radius := 56.0             # px
var shown := false
var guard_held := false
var _alpha := 0.0
var _pressed := {"dodgeL": 0.0, "dodgeR": 0.0, "guard": 0.0}
var _ripple := 0.0
var _press_consumed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_shown(on: bool) -> void:
	shown = on
	if on:
		visible = true

func mark_pos(which: String) -> Vector2:
	var r := ring_radius
	match which:
		"dodgeL":
			return centre + Vector2(-r, 0)
		"dodgeR":
			return centre + Vector2(r, 0)
		_:
			return centre + Vector2(0, r * 0.62)

func mark_at(pos: Vector2) -> String:
	if not shown:
		return ""
	for k in ["dodgeL", "dodgeR", "guard"]:
		if pos.distance_to(mark_pos(k)) <= Style.u(22.0):
			return k
	return ""

func press(which: String) -> void:
	_pressed[which] = Style.SWAP + 0.1

## A successful guard or dodge: one ripple leaves the ring.
func ripple() -> void:
	_ripple = 0.0001

func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var k := mark_at(e.position)
			if k != "":
				_press_consumed = true
				press(k)
				if k == "guard":
					guard_pressed.emit()
				else:
					dodge_pressed.emit(-1 if k == "dodgeL" else 1)
				return true
		elif _press_consumed:
			_press_consumed = false
			return true
	return false

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if shown else 0.0, dt, Style.IN if shown else Style.OUT)
	for k in _pressed:
		_pressed[k] = maxf(_pressed[k] - dt, 0.0)
	guard_held = shown and Input.is_action_pressed("guard")
	if _ripple > 0.0:
		_ripple += dt / 0.5
		if _ripple >= 1.0:
			_ripple = 0.0
	if _alpha <= 0.003 and not shown:
		visible = false
		return
	visible = true
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.003:
		return
	var a := _alpha
	var r := ring_radius
	Style.arc(self, centre, r, 0.0, 359.0, Color(Palette.BONE, 0.2 * a), Style.u(1.2), false)
	if guard_held:
		Style.arc(self, centre, r, 90.0, 270.0, Color(Palette.MIST, 0.95 * a), Style.u(4.5))
	if _ripple > 0.0:
		Style.arc(self, centre, r * (1.0 + 0.5 * Style.ease_out(_ripple)), 0.0, 359.0, Color(Palette.MIST, 0.6 * (1.0 - _ripple) * a), Style.u(1.6), false)
	for k in ["dodgeL", "dodgeR", "guard"]:
		var p := mark_pos(k)
		var pr: float = Style.u(R_MARK)
		var on: bool = _pressed[k] > 0.0
		draw_circle(p, pr, Color(Palette.INK, (0.42 if on else 0.24) * a))
		Style.circle_outline(self, p, pr, Color(Palette.MIST, 0.85 * a), Style.u(2.4 if on else 1.4))
		Glyphs.draw(self, k, p, 15.0, Color(Palette.BONE, a))
		var key: String = {"dodgeL": "Q", "dodgeR": "E", "guard": "Space"}[k]
		Style.key_cap(self, key, p + Vector2(0, pr + Style.u(13.0)), Style.u(13.5), Color(Palette.FOG, 0.9 * a))
