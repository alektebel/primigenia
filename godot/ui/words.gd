extends Control
## Words that pass (docs/godot/UI-DIEGETIC.md 7.10, 7.15): the whisper line (replaces the toasts: one line at a time, 3.5 s),
## the moment line (a few per session: Alegreya Italic 28, with its glyph, 3.5 s, queued) and the onboarding hint. No boxes.
## Floating numbers (damage, trust) exist only with Numbers: On.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")

const HOLD := 3.5

var whisper_text := ""
var moment_text := ""
var moment_glyph := ""
var hint_text := ""
var hint_keys := ""
var _w_t := 0.0                    # seconds left of the whisper
var _w_alpha := 0.0
var _m_t := 0.0
var _m_alpha := 0.0
var _m_queue: Array = []
var _h_alpha := 0.0
var _h_on := false
var camera: Camera3D
var _floats: Array = []            # numbers (Numbers: On): {text, pos, color, age}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## One whisper at a time; a newer one replaces it.
func whisper(text: String) -> void:
	whisper_text = text
	_w_t = HOLD

func moment(text: String, glyph: String = "") -> void:
	if moment_text != "" and _m_t > 0.0:
		_m_queue.append([text, glyph])
		return
	moment_text = text
	moment_glyph = glyph
	_m_t = HOLD

func set_hint(text: String, keys: String = "") -> void:
	hint_text = text
	hint_keys = keys
	_h_on = text != ""

func number(pos, text: String, color: Color) -> void:
	_floats.append({"text": text, "pos": pos, "color": color, "age": 0.0})

func _process(dt: float) -> void:
	_w_t = maxf(_w_t - dt, 0.0)
	_w_alpha = Style.approach(_w_alpha, 1.0 if _w_t > 0.0 else 0.0, dt, Style.IN if _w_t > 0.0 else Style.OUT)
	if _w_t <= 0.0 and _w_alpha <= 0.0:
		whisper_text = ""
	_m_t = maxf(_m_t - dt, 0.0)
	_m_alpha = Style.approach(_m_alpha, 1.0 if _m_t > 0.0 else 0.0, dt, 0.5 if _m_t > 0.0 else Style.OUT)
	if _m_t <= 0.0 and _m_alpha <= 0.0:
		moment_text = ""
		if not _m_queue.is_empty():
			var n: Array = _m_queue.pop_front()
			moment(n[0], n[1])
	_h_alpha = Style.approach(_h_alpha, 1.0 if _h_on else 0.0, dt, Style.IN if _h_on else Style.OUT)
	for i in range(_floats.size() - 1, -1, -1):
		_floats[i].age += dt
		if _floats[i].age > 1.2:
			_floats.remove_at(i)
	queue_redraw()

func _draw() -> void:
	var vp := size
	if whisper_text != "" and _w_alpha > 0.01:
		var f := Style.font_sans()
		var s := Style.u(16.0)
		var w := Style.text_width(f, whisper_text, s)
		Style.text(self, f, Vector2(vp.x * 0.5 - w * 0.5, vp.y - Style.u(44.0)), whisper_text, s, Color(Palette.BONE, 0.92 * _w_alpha))
	if moment_text != "" and _m_alpha > 0.01:
		var f2 := Style.font_italic()
		var s2 := Style.u(28.0)
		var w2 := Style.text_width(f2, moment_text, s2)
		var gw := Style.u(34.0) if moment_glyph != "" else 0.0
		var x := vp.x * 0.5 - (w2 + gw) * 0.5
		if moment_glyph != "":
			Glyphs.draw(self, moment_glyph, Vector2(x + Style.u(12.0), vp.y * 0.72 - Style.u(8.0)), 26.0, Color(Palette.BONE, _m_alpha))
		Style.text(self, f2, Vector2(x + gw, vp.y * 0.72), moment_text, s2, Color(Palette.BONE, _m_alpha))
	if hint_text != "" and _h_alpha > 0.01:
		var f3 := Style.font_sans()
		var s3 := Style.u(16.5)
		var w3 := Style.text_width(f3, hint_text, s3)
		var kw := 0.0
		if hint_keys != "":
			kw = Style.text_width(Style.font_sans(true), hint_keys, Style.u(14.5)) + Style.u(22.0)
		var x3 := vp.x * 0.5 - (w3 + kw) * 0.5
		var y3 := vp.y - Style.u(44.0)
		if hint_keys != "":
			var kr := Rect2(Vector2(x3, y3 - Style.u(17.0)), Vector2(kw - Style.u(8.0), Style.u(23.0)))
			Style.polyline(self, PackedVector2Array([kr.position, kr.position + Vector2(kr.size.x, 0), kr.end, kr.position + Vector2(0, kr.size.y), kr.position]), Color(Palette.BONE, 0.8 * _h_alpha), Style.u(1.2))
			Style.text(self, Style.font_sans(true), Vector2(x3 + Style.u(7.0), y3), hint_keys, Style.u(14.5), Color(Palette.BONE, _h_alpha))
		Style.text(self, f3, Vector2(x3 + kw, y3), hint_text, s3, Color(Palette.BONE, 0.92 * _h_alpha))
	for n in _floats:
		var p := size * 0.5
		if n.pos is Vector2:
			p = n.pos
		elif n.pos is Vector3 and camera != null and not camera.is_position_behind(n.pos):
			p = camera.unproject_position(n.pos)
		p.y -= n.age * Style.u(40.0)
		Style.text(self, Style.font_sans(true), p, n.text, Style.u(18.0), Color(n.color, clampf(1.5 - n.age * 1.5, 0.0, 1.0)))
