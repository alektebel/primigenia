extends Control
## The field note (docs/godot/UI-DIEGETIC.md 7.2): the species name in Alegreya Italic, under it the diet glyph and four
## short dashes for the relationship (stranger, neutral, trusted, ally). No box, no other rows: the rest is the journal's.
## Sits beside the mode ring on the side with more free screen; once a mode is chosen, to the right of the creature.

const Style := preload("res://ui/style.gd")
const Palette := preload("res://ui/palette.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")
const JournalData := preload("res://ui/journal_data.gd")

var info: Dictionary = {}
var camera: Camera3D
var ring                     # the mode ring, for the anchor
var alpha := 0.0
var _show := false
var _delay := 0.0
var _sign_alpha := 1.0       # the diet and relationship row fades after a mode is chosen
var _since_mode := 0.0
var mode_chosen := false
var _anchor := Vector2.ZERO

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func set_info(d: Dictionary) -> void:
	var fresh: bool = info.get("id", -2) != d.get("id", -3)
	info = d
	if fresh:
		_show_note(true)

func _show_note(on: bool) -> void:
	_show = on
	if on:
		_delay = 0.1
		_since_mode = 0.0
		_sign_alpha = 1.0
		mode_chosen = false
		visible = true

func hide_note() -> void:
	_show = false
	info = {}

func mode_was_chosen() -> void:
	mode_chosen = true
	_since_mode = 0.0

func is_carcass() -> bool:
	return int(info.get("carcass_meat", -1)) >= 0

## {name, diet, relationship, sub}: what is on the note, for tests.
func snapshot() -> Dictionary:
	if info.is_empty():
		return {}
	var p := JournalData.page(info)
	return {"name": p.species, "diet": "" if is_carcass() else p.diet, "relationship": -1 if is_carcass() else JournalData.index_of(info.get("relationship", 0), JournalData.RELATIONSHIPS),
		"sub": Strings.t("remains") if is_carcass() else ""}

func _process(dt: float) -> void:
	if _show and _delay > 0.0:
		_delay -= dt
	else:
		alpha = Style.approach(alpha, 1.0 if _show else 0.0, dt, Style.IN if _show else Style.OUT)
	if mode_chosen and _show:
		_since_mode += dt
		if _since_mode > 4.0:
			_sign_alpha = Style.approach(_sign_alpha, 0.0, dt, Style.OUT)
	if alpha <= 0.002 and not _show:
		visible = false
		return
	_place()
	queue_redraw()

func _place() -> void:
	var vp := get_viewport_rect().size
	var centre := Vector2(vp.x * 0.5, vp.y * 0.45)
	var half_h := 90.0
	if ring != null and ring.has_method("anchor"):
		centre = ring.centre
		half_h = ring.body_half_height
	if mode_chosen:
		var pr := clampf(half_h + Style.u(62.0), Style.u(84.0), Style.u(150.0))      # the petals' radius: the note sits beyond the gift petal
		_anchor = centre + Vector2(pr * 0.96 + Style.u(40.0), -pr * 0.1)
	else:
		var side := 1.0 if centre.x < vp.x * 0.6 else -1.0
		_anchor = centre + Vector2(sin(deg_to_rad(50.0)) * side, -cos(deg_to_rad(50.0))) * Style.u(130.0) + Vector2(0, 0)
	var m := Style.u(24.0)
	_anchor.x = clampf(_anchor.x, m, vp.x - m - Style.u(150.0))
	_anchor.y = clampf(_anchor.y, m + Style.u(30.0), vp.y - m - Style.u(30.0))

func _draw() -> void:
	if info.is_empty() or alpha <= 0.002:
		return
	var p := JournalData.page(info)
	var a := alpha
	var name_col := Color(Palette.BONE, a)
	var size := Style.u(23.0)
	Style.text(self, Style.font_italic(), _anchor, p.species, size, name_col)
	var y := _anchor.y + Style.u(20.0)
	if is_carcass():
		Style.text(self, Style.font_sans(), Vector2(_anchor.x, y + Style.u(6.0)), Strings.t("remains"), Style.u(13.5), Color(Palette.FOG, a))
		return
	var sa := a * _sign_alpha
	if sa <= 0.003:
		return
	var x := _anchor.x + Style.u(9.0)
	var diet := JournalData.index_of(info.get("diet", 0), JournalData.DIETS)
	var col := Color(Palette.BONE, sa)
	if diet == 0 or diet == 2:
		Glyphs.draw(self, "leaf", Vector2(x, y), 17.0, col)
		x += Style.u(20.0)
	if diet == 1 or diet == 2:
		Glyphs.draw(self, "fang", Vector2(x, y), 17.0, col)
		x += Style.u(20.0)
	x += Style.u(8.0)
	var rel := JournalData.index_of(info.get("relationship", 0), JournalData.RELATIONSHIPS)
	for i in 4:
		var c := Color(Palette.BONE, sa * 0.3)
		if i <= rel:
			c = Color(Palette.LICHEN if rel >= 2 else Palette.BONE, sa)
		Style.line(self, Vector2(x + i * Style.u(10.0), y), Vector2(x + i * Style.u(10.0) + Style.u(6.0), y), c, Style.u(2.2))
