extends Control
## The actuator ring: a circle of four choices (muscle, hydraulic, exoskeleton, hydrostat) drawn around a limb.
## Opened by a click on the limb. Choosing applies and closes; Esc or a click outside closes. The ring grows 0.96 -> 1
## with a fade over 160 ms, ease-out, from the limb (pivot = ring centre), never from the screen centre.

const ThemeFactory := preload("theme_factory.gd")

signal picked(id: String)
signal closed
signal hint(text: String)

const RADIUS := 66.0
const BTN_R := 24.0
const ANIM_TIME := .16
const ICONS := {"muscle": 0, "hydraulic": 1, "exo": 2, "hydrostat": 3}

var center := Vector2.ZERO
var options: Array = []           # [{id, allowed, current, label, why}]
var _hover := -1
var _pressed := -1
var _tween: Tween
var _anim := true

## `at` is in this control's own coordinates. `animate` false (tests, keyboard) shows the final state at once.
func open(at: Vector2, opts: Array, animate := true) -> void:
	center = at
	options = opts
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = at
	z_index = 60
	_anim = animate
	if animate:
		scale = Vector2(.96, .96)
		modulate.a = 0.0
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "scale", Vector2.ONE, ANIM_TIME)
		_tween.tween_property(self, "modulate:a", 1.0, ANIM_TIME)
	queue_redraw()

func settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	scale = Vector2.ONE
	modulate.a = 1.0

func button_center(i: int) -> Vector2:
	var a := -PI / 2.0 + TAU * float(i) / float(maxi(options.size(), 1))
	return center + Vector2(cos(a), sin(a)) * RADIUS

func _index_at(p: Vector2) -> int:
	for i in options.size():
		if p.distance_to(button_center(i)) <= BTN_R + 4.0:
			return i
	return -1

func close() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	closed.emit()
	queue_free()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var i := _index_at(e.position)
		if i != _hover:
			_hover = i
			hint.emit(String(options[i].get("why", "")) if i >= 0 and not options[i]["allowed"] else "")
			queue_redraw()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var i2 := _index_at(e.position)
		if e.pressed:
			_pressed = i2 if i2 >= 0 and options[i2]["allowed"] else -1
			queue_redraw()
		else:
			var was := _pressed
			_pressed = -1
			if was >= 0 and was == i2:
				picked.emit(String(options[was]["id"]))
				close()
			elif i2 < 0:
				close()
			else:
				queue_redraw()
	elif e is InputEventMouseButton and e.pressed:
		close()      # any other button outside or inside: dismiss
	accept_event()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close()

func _draw() -> void:
	draw_arc(center, RADIUS, 0, TAU, 64, Color(ThemeFactory.PAPER, .22), 1.5, true)
	draw_circle(center, 3.0, Color(ThemeFactory.AMBER, .9))
	var font := ThemeDB.fallback_font
	for i in options.size():
		var o: Dictionary = options[i]
		var c := button_center(i)
		var s := .97 if _pressed == i else (1.06 if _hover == i and o["allowed"] else 1.0)
		var a := 1.0 if o["allowed"] else .38
		draw_circle(c, BTN_R * s, Color(ThemeFactory.GLASS, .96 * a + .04))
		var edge: Color = ThemeFactory.AMBER if o["current"] else Color(ThemeFactory.SKY, .55 if _hover == i else .3)
		draw_arc(c, BTN_R * s, 0, TAU, 40, Color(edge, edge.a * a), 2.5 if o["current"] else 1.5, true)
		_icon(String(o["id"]), c, s, Color(ThemeFactory.PAPER, a))
		var lab := String(o["label"])
		var w := font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		var dirv := (c - center).normalized()
		var lp: Vector2
		if absf(dirv.x) < .5:     # top and bottom: above or below the button
			lp = c + Vector2(-w / 2.0, -(BTN_R + 8.0) if dirv.y < 0.0 else BTN_R + 15.0)
		else:                     # left and right: beside the button, away from the limb
			lp = c + Vector2(BTN_R + 8.0 if dirv.x > 0.0 else -(BTN_R + 8.0) - w, 4.0)
		draw_string(font, lp, lab, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(ThemeFactory.AMBER if o["current"] else ThemeFactory.PAPER, a))

func _icon(id: String, c: Vector2, s: float, col: Color) -> void:
	match ICONS.get(id, -1):
		0:   # muscle: a spindle belly with fibres
			var pts := PackedVector2Array()
			for k in 17:
				var x := lerpf(-13.0, 13.0, float(k) / 16.0)
				pts.append(c + Vector2(x, -7.0 * sin(PI * float(k) / 16.0)) * s)
			for k in 17:
				var x2 := lerpf(13.0, -13.0, float(k) / 16.0)
				pts.append(c + Vector2(x2, 7.0 * sin(PI * float(16 - k) / 16.0)) * s)
			draw_colored_polygon(pts, Color(col, col.a * .85))
			for k in range(-1, 2):
				draw_line(c + Vector2(k * 5.0 - 3.0, 3.0) * s, c + Vector2(k * 5.0 + 3.0, -3.0) * s, Color(ThemeFactory.INK, col.a * .55), 1.2)
		1:   # hydraulic: cylinder, piston rod and a fluid drop
			draw_rect(Rect2(c + Vector2(-13.0, -6.0) * s, Vector2(15.0, 12.0) * s), Color(col, col.a * .85))
			draw_line(c + Vector2(2.0, 0.0) * s, c + Vector2(13.0, 0.0) * s, col, 3.0 * s)
			draw_circle(c + Vector2(13.0, 0.0) * s, 2.8 * s, col)
			draw_circle(c + Vector2(-6.0, 0.0) * s, 3.0 * s, Color(ThemeFactory.SKY, col.a))
		2:   # exoskeleton: stacked segment plates
			for k in 3:
				var y := (k - 1) * 8.0
				var w := 26.0 - absf(k - 1) * 6.0
				draw_rect(Rect2(c + Vector2(-w / 2.0, y - 3.0) * s, Vector2(w, 6.0) * s), Color(col, col.a * (.9 - k * .12)))
		3:   # hydrostat: a soft wavy tube
			var wp := PackedVector2Array()
			for k in 19:
				var x3 := lerpf(-13.0, 13.0, float(k) / 18.0)
				wp.append(c + Vector2(x3, 5.0 * sin(float(k) / 18.0 * TAU)) * s)
			draw_polyline(wp, col, 4.0 * s, true)
