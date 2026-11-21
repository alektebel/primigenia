extends Control
## The task card (docs/godot/FIRST-QUEST.md): a small note of the field journal pinned top-left, in the journal's paper and ink. It
## shows the chain's name, five marks (done, current, to come), the current task and its hint, and a few ticks for the parts of a
## task that has several. K folds it to a tab and back (instant: a key press is not animated). A new task fades in over 180 ms
## (ease-out); nothing grows from scale 0. It never takes the mouse and sits under the menus and the journal.

const Style := preload("res://ui/style.gd")
const Palette := preload("res://ui/palette.gd")
const Strings := preload("res://ui/strings.gd")

const PAPER := Color("#E9DFC6")
const PAPER_EDGE := Color("#B9A982")
const INK_T := Color("#2A2820")
const INK_SOFT := Color("#5A5444")
const INK_FAINT := Color("#8D8670")
const COPPER_D := Color("#9A5222")
const LICHEN_D := Color("#2D7555")
const WIDTH := 300.0
const MARGIN := 24.0

var model: Dictionary = {}          # {title, step_title, hint, index, total, marks: [bool], parts: [{text, done}], finished}
var collapsed := false
var enabled := true
var hide_now := false               # menus and the journal cover the card
var truncated := 0                  # hint lines cut with an ellipsis in the last draw
var _swap := 1.0                    # 0 -> 1 after the task changed
var _last_key := ""
var _flash := 0.0                   # a brief copper line when a task is done
var _alpha := 1.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func set_model(m: Dictionary) -> void:
	model = m
	var key := "%s|%d" % [m.get("step_title", ""), int(m.get("index", 0))]
	if key != _last_key:
		if _last_key != "":
			_swap = 0.0
			_flash = 1.0
		_last_key = key
	queue_redraw()

func toggle() -> void:
	collapsed = not collapsed
	queue_redraw()

func set_collapsed(on: bool) -> void:
	collapsed = on
	queue_redraw()

func _process(dt: float) -> void:
	var target := 0.0 if (hide_now or not enabled or model.is_empty()) else 1.0
	var a := Style.approach(_alpha, target, dt, 0.2)
	var moving := _swap < 1.0 or _flash > 0.0 or a != _alpha
	_alpha = a
	_swap = Style.approach(_swap, 1.0, dt, 0.18)
	_flash = maxf(_flash - dt / 1.6, 0.0)
	visible = _alpha > 0.01
	if moving:
		queue_redraw()

## The rectangle the card occupies now (tests and the evidence read it).
func card_rect() -> Rect2:
	var w := Style.u(WIDTH)
	var h := Style.u(36.0) if collapsed else _height()
	return Rect2(Vector2(Style.u(MARGIN), Style.u(MARGIN)), Vector2(Style.u(44.0) + Style.u(110.0) if collapsed else w, h))

func _height() -> float:
	var parts: Array = model.get("parts", [])
	var lines := _hint_lines()
	return Style.u(92.0) + Style.u(21.0) * lines.size() + (Style.u(22.0) * parts.size() if parts.size() > 1 else 0.0)

func _hint_lines() -> PackedStringArray:
	var f := Style.font_sans()
	var maxw := Style.u(WIDTH - 36.0)
	var words := String(model.get("hint", "")).split(" ")
	var lines := PackedStringArray()
	var cur := ""
	for w in words:
		var t := w if cur == "" else cur + " " + w
		if Style.text_width(f, t, Style.u(15.5)) > maxw and cur != "":
			lines.append(cur)
			cur = w
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines

func _draw() -> void:
	truncated = 0
	if model.is_empty() or _alpha <= 0.01:
		return
	var r := card_rect()
	var fi := Style.font_italic()
	var fs := Style.font_sans()
	var fm := Style.font_sans(true)
	var a := Style.ease_out(_alpha)
	draw_rect(Rect2(r.position + Vector2(0, Style.u(3.0)), r.size + Vector2(Style.u(2.0), 0)), Color(Palette.INK, 0.28 * a))
	draw_rect(r, Color(PAPER, 0.93 * a))
	draw_rect(r, Color(PAPER_EDGE, a), false, 1.5)
	draw_line(r.position + Vector2(Style.u(14.0), Style.u(3.0)), r.position + Vector2(Style.u(14.0), r.size.y - Style.u(3.0)), Color(COPPER_D, 0.3 * a), 1.0)
	var x := r.position.x + Style.u(24.0)
	var y := r.position.y + Style.u(24.0)
	var head := "K  " + Strings.t("jt_tasks")
	if collapsed:
		draw_string(fm, Vector2(x - Style.u(8.0), y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(16.0)), Color(COPPER_D, a))
		return
	draw_string(fm, Vector2(x, y), head, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(15.0)), Color(COPPER_D, a))
	# the marks of the chain
	var marks: Array = model.get("marks", [])
	var mx := r.end.x - Style.u(20.0) - Style.u(16.0) * marks.size()
	for i in marks.size():
		var c := Vector2(mx + Style.u(16.0) * i + Style.u(8.0), y - Style.u(5.0))
		if bool(marks[i]):
			draw_circle(c, Style.u(5.0), Color(LICHEN_D, a))
		elif i == int(model.get("index", 0)):
			draw_arc(c, Style.u(5.5), 0.0, TAU, 20, Color(COPPER_D, a), 2.0, true)
		else:
			draw_arc(c, Style.u(4.5), 0.0, TAU, 20, Color(INK_FAINT, 0.8 * a), 1.2, true)
	y += Style.u(10.0)
	draw_line(Vector2(x, y), Vector2(r.end.x - Style.u(16.0), y), Color(INK_FAINT, 0.6 * a), 1.0)
	var swap := Style.ease_out(_swap)
	var ca := a * swap
	y += Style.u(30.0)
	if bool(model.get("finished", false)):
		draw_string(fi, Vector2(x, y), Strings.t("quest_done"), HORIZONTAL_ALIGNMENT_LEFT, int(Style.u(WIDTH - 44.0)), int(Style.u(22.0)), Color(INK_T, ca))
		return
	var title := String(model.get("step_title", ""))
	draw_string(fi, Vector2(x, y), title, HORIZONTAL_ALIGNMENT_LEFT, int(Style.u(WIDTH - 44.0)), int(Style.u(24.0)), Color(INK_T, ca))
	y += Style.u(8.0)
	for line in _hint_lines():
		y += Style.u(21.0)
		draw_string(fs, Vector2(x, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(15.5)), Color(INK_SOFT, ca))
	var parts: Array = model.get("parts", [])
	if parts.size() > 1:
		y += Style.u(8.0)
		for p in parts:
			y += Style.u(22.0)
			var c := Vector2(x + Style.u(6.0), y - Style.u(5.0))
			if bool(p.done):
				draw_circle(c, Style.u(4.5), Color(LICHEN_D, ca))
			else:
				draw_arc(c, Style.u(4.5), 0.0, TAU, 16, Color(INK_FAINT, ca), 1.4, true)
			draw_string(fs, Vector2(x + Style.u(20.0), y), String(p.text), HORIZONTAL_ALIGNMENT_LEFT, -1, int(Style.u(15.5)), Color(INK_T if not bool(p.done) else INK_FAINT, ca))
	if _flash > 0.0:
		draw_line(Vector2(r.position.x + Style.u(14.0), r.end.y - Style.u(1.0)), Vector2(r.position.x + Style.u(14.0) + (r.size.x - Style.u(28.0)) * Style.ease_out(1.0 - _flash), r.end.y - Style.u(1.0)), Color(COPPER_D, _flash * a), 2.0)
