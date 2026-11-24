extends Control
## The piece that follows the pointer while a component is dragged (from a tool card, or a colony block between hexes).
## While the pointer is down the ghost IS the pointer: its position is written straight from the event, no easing.
## On release it either lands (fades where it was dropped) or eases back to its card / hex in 200 ms (ease-out).
## It sits above the whole stage and ignores the mouse. Pure drawing; the stage and canvases own the rules.

const CS := preload("res://cell/cell_strings.gd")
const Sim := preload("res://cell/cell_sim.gd")
const CSim := preload("res://cell/colony_sim.gd")

const RETURN_T := 0.2
const OK_COL := Color("F4EFDF")
const BAD_COL := Color("C0392B")

var active := false
var kind := ""
var mode := "cell"             # "cell" piece or "colony" block
var gpos := Vector2.ZERO       # where the ghost is, in stage coordinates
var ok := true
var text := ""                 # why it cannot go here ("" when it can)
var scale_px := 1.0            # sim units to pixels, so the ghost is as big as the piece will be
var alpha := 1.0
var hex_r := 40.0
var instant := false           # reduced motion: no easing back
var _tw: Tween
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_font = ThemeDB.fallback_font
	visible = false

func begin(kind_: String, mode_: String, at: Vector2, scale_: float, hex_r_ := 40.0) -> void:
	_stop()
	kind = kind_
	mode = mode_
	scale_px = scale_
	hex_r = hex_r_
	gpos = at
	ok = true
	text = ""
	alpha = 1.0
	active = true
	visible = true
	queue_redraw()

## Tracking: 1:1 with the pointer, no tween.
func track(at: Vector2, ok_: bool, text_: String) -> void:
	if not active:
		return
	gpos = at
	ok = ok_
	text = text_
	queue_redraw()

## Released on a valid target: it lands (the real piece appears), the ghost is gone.
func land() -> void:
	_stop()
	active = false
	visible = false

## Released on nothing / refused / Esc: ease back to `home` (ease-out, 200 ms), then gone.
func send_back(home: Vector2) -> void:
	_stop()
	if instant or not is_inside_tree():
		active = false
		visible = false
		return
	text = ""
	ok = true
	_tw = create_tween().set_parallel(true)
	_tw.tween_property(self, "gpos", home, RETURN_T).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tw.tween_property(self, "alpha", 0.0, RETURN_T).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_tw.chain().tween_callback(func():
		active = false
		visible = false)

func returning() -> bool:
	return _tw != null and _tw.is_valid() and _tw.is_running()

func _stop() -> void:
	if _tw != null and _tw.is_valid():
		_tw.kill()
	_tw = null

func _process(_d: float) -> void:
	if returning():
		queue_redraw()

func _draw() -> void:
	if not active:
		return
	var col := (BAD_COL if not ok else OK_COL)
	if mode == "colony":
		var c: Color = CSim.BLOCKS[kind].col
		var fill := c if ok else c.lerp(BAD_COL, 0.65)
		fill.a = 0.82 * alpha
		draw_circle(gpos, hex_r * 0.78, fill)
		draw_arc(gpos, hex_r * 0.78, 0, TAU, 40, Color(col.r, col.g, col.b, alpha), 2.5, true)
	else:
		var d: Dictionary = Sim.PIECES[kind]
		var c2: Color = d.col
		var fill2 := c2 if ok else c2.lerp(BAD_COL, 0.65)
		fill2.a = 0.82 * alpha
		var ol := Color(col.r, col.g, col.b, alpha)
		if d.has("lobes"):
			for l in d.lobes:
				var lp: Vector2 = gpos + Vector2(l[0], l[1]) * scale_px
				draw_circle(lp, (l[2] + 1.5) * scale_px, ol)
			for l in d.lobes:
				var lp2: Vector2 = gpos + Vector2(l[0], l[1]) * scale_px
				draw_circle(lp2, l[2] * scale_px, fill2)
		else:
			draw_circle(gpos, 17.0 * scale_px, ol)
			draw_circle(gpos, 14.0 * scale_px, fill2)
	if text != "" and alpha > 0.5:
		var fs := 15
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var r := Rect2(gpos + Vector2(-w / 2.0 - 10.0, 30.0 * maxf(scale_px, 0.8) + 8.0), Vector2(w + 20.0, 26.0))
		var vp := get_viewport_rect().size
		r.position.x = clampf(r.position.x, 6.0, vp.x - r.size.x - 6.0)
		r.position.y = minf(r.position.y, vp.y - r.size.y - 6.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.99, 0.96, 0.93, 0.96) if not ok else Color(0.98, 0.97, 0.925, 0.96)
		sb.border_color = BAD_COL if not ok else Color("CFC3A6")
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(7)
		draw_style_box(sb, r)
		draw_string(_font, r.position + Vector2(10, 18), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("9E392C") if not ok else Color("3A352D"))
