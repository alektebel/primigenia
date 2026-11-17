extends Control
## Radial menu with the four G75 modes. Full-rect click catcher; draws a ring
## around `centre`. Emits chosen(mode) or closed().

const Palette := preload("res://ui/palette.gd")
const Modes := preload("res://ui/modes.gd")

signal chosen(mode: StringName)
signal closed

const R_IN := 56.0
const R_OUT := 160.0
## North, east, south, west.
const ORDER: Array[StringName] = [Modes.ATTACK, Modes.BEFRIEND, Modes.OBSERVE, Modes.INTIMIDATE]
## InputMap actions of the four modes, in ORDER (A, B, O, I).
const ACTIONS: Array[StringName] = [&"radial_attack", &"radial_befriend", &"radial_observe", &"radial_intimidate"]

var centre := Vector2.ZERO
var current: StringName = Modes.ATTACK
var hover := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	focus_mode = Control.FOCUS_ALL

func open_at(pos: Vector2, mode: StringName = current) -> void:
	current = mode
	centre = pos
	hover = -1
	visible = true
	queue_redraw()

func close() -> void:
	if visible:
		visible = false
		closed.emit()

## Mode at an offset from the centre, or -1.
static func sector_at(offset: Vector2) -> int:
	var d := offset.length()
	if d < R_IN or d > R_OUT * 1.25:
		return -1
	var a := fposmod(atan2(offset.x, -offset.y), TAU)  # 0 = north, clockwise
	return int(floor(fposmod(a + PI / 4.0, TAU) / (PI / 2.0))) % 4

func choose(i: int) -> void:
	if i < 0 or i > 3:
		return
	current = ORDER[i]
	visible = false
	chosen.emit(current)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var h := sector_at(e.position - centre)
		if h != hover:
			hover = h
			queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			var s := sector_at(e.position - centre)
			if s >= 0:
				choose(s)
			else:
				close()
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			close()
		accept_event()
	elif e is InputEventKey and e.pressed:
		# Ctrl/Alt/Meta combos belong to other bindings (Ctrl+B is the dev bookmark, not Befriend).
		if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
			return
		var found := false
		for i in ACTIONS.size():
			if e.is_action_pressed(ACTIONS[i]):
				choose(i)
				found = true
				break
		if not found and e.is_action_pressed("pause_menu"):
			close()
		accept_event()

func _arc_poly(a0: float, a1: float, r0: float, r1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(centre + Vector2(sin(a), -cos(a)) * r1)
	for i in n + 1:
		var a := lerpf(a1, a0, float(i) / n)
		pts.append(centre + Vector2(sin(a), -cos(a)) * r0)
	return pts

func _draw() -> void:
	if not visible:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.1, 0.08, 0.35))
	var font := get_theme_default_font()
	for i in 4:
		var mid := i * PI / 2.0
		var a0 := mid - PI / 4.0 + 0.03
		var a1 := mid + PI / 4.0 - 0.03
		var active := ORDER[i] == current
		var col := Palette.PANEL_ACTIVE if (i == hover) else (Palette.PANEL_HOVER if active else Palette.PANEL_SOLID)
		col.a = 0.94
		var poly := _arc_poly(a0, a1, R_IN, R_OUT)
		draw_colored_polygon(poly, col)
		var outline := poly.duplicate()
		outline.append(poly[0])
		draw_polyline(outline, Palette.GOLD if (i == hover or active) else Palette.BORDER_BTN, 1.5, true)
		var c := centre + Vector2(sin(mid), -cos(mid)) * (R_IN + R_OUT) * 0.5
		var title := Modes.title(ORDER[i])
		var ts := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17)
		draw_string(font, c + Vector2(-ts.x / 2.0, 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Palette.TEXT)
		var hint: String = Modes.HINTS[ORDER[i]]
		var hs := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
		draw_string(font, c + Vector2(-hs.x / 2.0, 19), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Palette.MUTED)
	draw_circle(centre, R_IN - 6, Color(Palette.PANEL_SOLID, 0.95))
	var ct := Modes.title(current)
	var cs := font.get_string_size(ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	draw_string(font, centre + Vector2(-cs.x / 2.0, 5), ct, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Palette.GOLD)
