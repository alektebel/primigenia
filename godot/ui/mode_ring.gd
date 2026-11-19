extends Control
## The mode ring (docs/godot/UI-DIEGETIC.md 7.3): one hairline circle around the selected creature with four arcs. Click a
## side to choose how to meet it: the whole west side is Befriend (smooth, lichen), the east side Attack (teeth, ember;
## Eat on a carcass), north Observe (dots, ochre), south Intimidate (double, dusk). Mouse only (the owner's answer):
## W A S D keep walking while it is open. Not modal: no backdrop, a click outside the hit zones is a normal world click.
## Drawn in screen space so it is a true circle from any camera pitch.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")
const Modes := preload("res://ui/modes.gd")

signal chosen(mode: StringName)
signal closed

## Index -> arc. Index 0 north, 1 east, 2 south, 3 west (clockwise from north). Angles are degrees clockwise from north.
const ARCS := [
	{"a0": 335.0, "a1": 385.0, "mode": Modes.OBSERVE, "glyph": "observe", "glyph_at": 0.0},
	{"a0": 35.0, "a1": 145.0, "mode": Modes.ATTACK, "glyph": "attack", "glyph_at": 90.0},
	{"a0": 155.0, "a1": 205.0, "mode": Modes.INTIMIDATE, "glyph": "intimidate", "glyph_at": 180.0},
	{"a0": 215.0, "a1": 325.0, "mode": Modes.BEFRIEND, "glyph": "befriend", "glyph_at": 270.0},
]
const BAND_IN := 30.0
const BAND_OUT := 60.0
const SLACK := 5.0

var centre := Vector2.ZERO
var body_half_height := 90.0       # on-screen half height of the target (px), sets the radius
var current: StringName = Modes.NONE
var hover := -1
var carcass := false
var refuses := false               # a creature that refuses social play: the Befriend arc at 0.4 with a bar
var names_all := false             # first selections and onboarding: every name shows
var _t := 0.0                      # IN progress 0..1
var _chosen_flash := -1
var _flash_t := 0.0
var _press_consumed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func anchor() -> Vector2:
	return centre

## Radius R in px: 1.6 x the target's half height, clamped 84..150 u.
func radius() -> float:
	return clampf(1.6 * body_half_height, Style.u(84.0), Style.u(150.0))

func open_at(pos: Vector2, half_height: float = -1.0, mode: StringName = current) -> void:
	current = mode
	centre = pos
	if half_height > 0.0:
		body_half_height = half_height
	hover = -1
	_t = 0.0
	visible = true
	queue_redraw()

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func is_open() -> bool:
	return visible

# --- geometry (testable) -----------------------------------------------------------------------------------------

## Arc index (0 north, 1 east, 2 south, 3 west) at an offset from the centre, or -1 (outside the band or between arcs).
func sector_at(offset: Vector2) -> int:
	var d := offset.length()
	var r := radius()
	if d < r - Style.u(BAND_IN) or d > r + Style.u(BAND_OUT):
		return -1
	var a := rad_to_deg(fposmod(atan2(offset.x, -offset.y), TAU))
	for i in 4:
		var a0: float = ARCS[i].a0 - SLACK
		var a1: float = ARCS[i].a1 + SLACK
		if (a >= a0 and a <= a1) or (a + 360.0 >= a0 and a + 360.0 <= a1):
			return i
	return -1

func mode_at(i: int) -> StringName:
	return Modes.EAT if carcass and i == 1 else ARCS[i].mode

## A carcass has only Eat (east) and Observe (north); the other two arcs are absent, not dimmed.
func enabled_at(i: int) -> bool:
	return not carcass or i == 0 or i == 1

func choose(i: int) -> void:
	if i < 0 or i > 3 or not enabled_at(i):
		return
	current = mode_at(i)
	_chosen_flash = i
	_flash_t = 0.0
	visible = false
	chosen.emit(current)

func choose_mode(mode: StringName) -> void:
	for i in 4:
		if mode_at(i) == mode and enabled_at(i):
			choose(i)
			return

# --- input -------------------------------------------------------------------------------------------------------

## Called by the UI with every unhandled input event. Returns true when the ring used the click (so the world does not).
func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		if visible:
			var h := sector_at(e.position - centre)
			if h >= 0 and not enabled_at(h):
				h = -1
			if h != hover:
				hover = h
				queue_redraw()
		return false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			if not visible:
				return false
			var s := sector_at(e.position - centre)
			if s >= 0 and enabled_at(s):
				_press_consumed = true
				choose(s)
				return true
			return false
		elif _press_consumed:
			_press_consumed = false
			return true
	return false

# --- drawing -----------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	if visible:
		_t = minf(_t + dt / maxf(Style.dur(Style.IN), 0.001), 1.0)
		queue_redraw()

func _draw() -> void:
	if not visible:
		return
	var r := radius()
	var k := Style.ease_out(_t)
	var base := Color(Palette.BONE, 0.16 * k)
	Style.circle_outline(self, centre, r, base, Style.u(1.0))
	for i in 4:
		if not enabled_at(i):
			continue
		var arc: Dictionary = ARCS[i]
		var mode := mode_at(i)
		var col: Color = Palette.MODE_COLORS[mode]
		var dim := 1.0
		if hover >= 0 and hover != i:
			dim = 0.7
		if i == 3 and refuses:
			dim = 0.4
		var width := Style.u(4.0) if hover == i else Style.u(2.6)
		var mid := (float(arc.a0) + float(arc.a1)) * 0.5
		var half := (float(arc.a1) - float(arc.a0)) * 0.5 * k
		var c := Color(col, dim * k)
		var style: StringName = Palette.MODE_STYLES[mode]
		var count := 6 if style == &"teeth" else 0
		Style.arc_styled(self, centre, r, mid - half, mid + half, style, c, width, count)
		var gpos := Style.on_circle(centre, r + Style.u(30.0), float(arc.glyph_at))
		var gsize := 32.0 if hover == i else 28.0
		Glyphs.draw(self, "eat" if mode == Modes.EAT else String(arc.glyph), gpos, gsize, c)
		if i == 3 and refuses:
			Style.line(self, gpos + Vector2(-Style.u(11), Style.u(11)), gpos + Vector2(Style.u(11), -Style.u(11)), Color(Palette.BONE, 0.9 * k), Style.u(2.0))
		if hover == i or names_all or Style.names_always():
			_draw_name(i, gpos, c)
	if _chosen_flash >= 0:
		_chosen_flash = -1

func _draw_name(i: int, gpos: Vector2, col: Color) -> void:
	var s := Strings.t(String(mode_at(i)))
	var size := Style.u(17.0)
	var font := Style.font_sans(true)
	var w := Style.text_width(font, s, size)
	var pos := gpos
	var colr := Color(Palette.BONE, col.a)
	match i:
		1:
			pos += Vector2(Style.u(22.0), Style.u(5.0))
		3:
			pos += Vector2(-Style.u(22.0) - w, Style.u(5.0))
		0:
			pos += Vector2(-w * 0.5, -Style.u(22.0))
		2:
			pos += Vector2(-w * 0.5, Style.u(32.0))
	Style.text(self, font, pos, s, size, colr)
