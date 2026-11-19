extends Control
## The ability petals (docs/godot/UI-DIEGETIC.md 7.4): the moves on keys 1-4 as small glyph discs on an arc above the
## target, left to right, with their key under them; in Befriend a smaller gift petal (G, H cycles the item). Replaces the
## bottom hotbar and its cooldown sweeps. A petal is a smoke disc, an outline in the mode colour (the role shape in Attack),
## the glyph in bone and the key. Cooling down: the outline is only the recharged part and closes. Not enough stamina:
## dashed and dim. Empty slot: a dashed circle. Pure drawing and hit testing; the UI feeds it.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")
const Modes := preload("res://ui/modes.gd")

signal petal_pressed(index: int)
signal gift_pressed
signal gift_cycled

const R_PETAL := 20.0
const R_GIFT := 15.0
const SPACING := 28.0

var centre := Vector2.ZERO
var body_half_height := 90.0
var mode: StringName = Modes.NONE
var items: Array = []                  # [{id, name, role, enabled, empty, stamina}]
var cooldowns: Array = []
var likes: Array = []
var dislikes: Array = []
var gift_item := -1                    # Modes.ITEMS index; -1 hides the gift petal
var gift_count := 0
var shown := false
var fight := false
var hover := -1
var _alpha := 0.0
var _rise_t := 0.0
var _pressed_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _shake: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _gift_glyph_t := 1.0
var _press_consumed := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

# --- model (what the tests read) -------------------------------------------------------------------------------------

func count() -> int:
	return items.size() if shown else 0

func id_at(i: int) -> String:
	return String(items[i].get("id", "")) if i >= 0 and i < items.size() else ""

func glyph_at(i: int) -> String:
	if i < 0 or i >= items.size() or bool(items[i].get("empty", false)):
		return ""
	return Glyphs.for_move(String(items[i].id))

## ready / cooling / off / empty / active
func state_at(i: int) -> StringName:
	if i < 0 or i >= items.size():
		return &"empty"
	var it: Dictionary = items[i]
	if bool(it.get("empty", false)):
		return &"empty"
	if _pressed_t[i] > 0.0:
		return &"active"
	if not bool(it.get("enabled", true)):
		return &"off"
	if cooldown_at(i) > 0.001:
		return &"cooling"
	return &"ready"

func cooldown_at(i: int) -> float:
	return clampf(float(cooldowns[i]), 0.0, 1.0) if i >= 0 and i < cooldowns.size() else 0.0

func shape_at(i: int) -> StringName:
	if mode != Modes.ATTACK or i < 0 or i >= items.size():
		return &"circle"
	var role := String(items[i].get("role", ""))
	return Palette.ROLE_SHAPES.get(role, &"circle")

func gift_visible() -> bool:
	return shown and mode == Modes.BEFRIEND and gift_item >= 0

func set_items(list: Array, new_mode: StringName) -> void:
	var was_shown := shown
	items = list
	mode = new_mode
	shown = new_mode != Modes.NONE and not list.is_empty()
	if shown and not was_shown:
		_rise_t = 0.0
	visible = shown or _alpha > 0.01
	queue_redraw()

func set_cooldowns(fracs: Array) -> void:
	cooldowns = fracs

func set_gift(item: int, n: int) -> void:
	if item != gift_item:
		_gift_glyph_t = 0.0
	gift_item = item
	gift_count = n

func press(i: int) -> void:
	if i >= 0 and i < 4:
		_pressed_t[i] = 0.18

func refuse(i: int) -> void:
	if i >= 0 and i < 4:
		_shake[i] = 0.2

# --- geometry --------------------------------------------------------------------------------------------------------

func petal_radius() -> float:
	return clampf(body_half_height + Style.u(62.0), Style.u(84.0), Style.u(150.0))

func petal_pos(i: int) -> Vector2:
	var n := maxi(items.size(), 1)
	var a := (float(i) - (n - 1) * 0.5) * SPACING
	return _clamp_margin(Style.on_circle(centre, petal_radius(), a))

func gift_pos() -> Vector2:
	return _clamp_margin(Style.on_circle(centre, petal_radius(), 74.0))

func _clamp_margin(p: Vector2) -> Vector2:
	var vp := get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var m := Style.u(24.0 + R_PETAL)
	return Vector2(clampf(p.x, m, vp.x - m), clampf(p.y, m, vp.y - m - Style.u(14.0)))

func petal_at(pos: Vector2) -> int:
	if not shown:
		return -1
	for i in items.size():
		if bool(items[i].get("empty", false)) and false:
			continue
		if pos.distance_to(petal_pos(i)) <= Style.u(22.0):
			return i
	if gift_visible() and pos.distance_to(gift_pos()) <= Style.u(R_GIFT + 6.0):
		return 100
	return -1

# --- input -----------------------------------------------------------------------------------------------------------

func handle_input(e: InputEvent) -> bool:
	if e is InputEventMouseMotion:
		var h := petal_at(e.position)
		if h != hover:
			hover = h
		return false
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			var i := petal_at(e.position)
			if i == 100:
				_press_consumed = true
				gift_pressed.emit()
				return true
			if i >= 0:
				_press_consumed = true
				petal_pressed.emit(i)
				return true
		elif _press_consumed:
			_press_consumed = false
			return true
	return false

# --- drawing ---------------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if shown else 0.0, dt, Style.IN if shown else Style.OUT)
	if shown:
		_rise_t += dt
	for i in 4:
		_pressed_t[i] = maxf(_pressed_t[i] - dt, 0.0)
		_shake[i] = maxf(_shake[i] - dt, 0.0)
	_gift_glyph_t = minf(_gift_glyph_t + dt / maxf(Style.dur(Style.SWAP), 0.001), 1.0)
	if _alpha <= 0.003 and not shown:
		visible = false
		return
	visible = true
	queue_redraw()

func _draw() -> void:
	if _alpha <= 0.003:
		return
	var col: Color = Palette.MODE_COLORS.get(mode, Palette.BONE)
	for i in items.size():
		_draw_petal(i, col)
	if gift_visible():
		_draw_gift(col)

func _rise_of(i: int) -> float:
	return clampf((_rise_t - i * 0.04) / maxf(Style.dur(Style.IN), 0.001), 0.0, 1.0)

func _petal_alpha(i: int) -> float:
	return _alpha * Style.ease_out(_rise_of(i))

func _draw_petal(i: int, col: Color) -> void:
	var it: Dictionary = items[i]
	var a := _petal_alpha(i)
	var st := state_at(i)
	var p := petal_pos(i)
	p.y += (1.0 - Style.ease_out(_rise_of(i))) * Style.u(8.0)
	if _shake[i] > 0.0:
		p.x += sin(_shake[i] / 0.2 * TAU * 2.0) * Style.u(3.0)
	var r := Style.u(R_PETAL)
	var shape := shape_at(i)
	var signature := String(it.get("role", "")) == "signature"
	var disc := 0.24 if st != &"active" else 0.42
	draw_circle(p, r, Color(Palette.INK, disc * a))
	var oc := Color(col, 0.8 * a)
	var w := Style.u(1.4)
	var glyph_a := a
	match st:
		&"empty":
			Style.shape_outline(self, &"circle", p, r, Color(col, 0.3 * a), w, true)
		&"off":
			Style.shape_outline(self, shape, p, r, Color(col, 0.35 * a), w, true)
			glyph_a = a * 0.38
		&"cooling":
			Style.shape_outline(self, shape, p, r, Color(col, 0.2 * a), w)
			Style.arc(self, p, r, 0.0, 360.0 * (1.0 - cooldown_at(i)), Color(col, 0.9 * a), w, false)
			glyph_a = a * 0.45
		&"active":
			Style.shape_outline(self, shape, p, r, Color(col, a), Style.u(2.6), false, signature)
		_:
			Style.shape_outline(self, shape, p, r, oc, w, false, signature)
	if st != &"empty":
		Glyphs.draw(self, glyph_at(i), p, 24.0, Color(Palette.BONE, glyph_a))
	var key := str(i + 1)
	Style.key_cap(self, key, p + Vector2(0, r + Style.u(15.0)), Style.u(14.5), Color(Palette.BONE, a * (0.5 if st == &"off" or st == &"empty" else 0.9)))
	if hover == i or Style.names_always():
		var nm := String(it.get("name", it.get("id", "")))
		if st != &"empty" and nm != "":
			Style.key_cap(self, nm, p + Vector2(0, -r - Style.u(8.0)), Style.u(14.5), Color(Palette.BONE, a))
	var id := String(it.get("id", ""))
	if mode == Modes.BEFRIEND and id != "":
		if likes.has(id):
			draw_circle(p + Vector2(0, -r - Style.u(6.0)), Style.u(3.0), Color(Palette.LICHEN, a))
		elif dislikes.has(id):
			Style.line(self, p + Vector2(-Style.u(5), -r - Style.u(6.0)), p + Vector2(Style.u(5), -r - Style.u(6.0)), Color(Palette.BONE, a), Style.u(2.0))

func _draw_gift(col: Color) -> void:
	var a := _alpha * Style.ease_out(_rise_of(4))
	var p := gift_pos()
	var r := Style.u(R_GIFT)
	var empty := gift_count <= 0
	draw_circle(p, r, Color(Palette.INK, 0.24 * a))
	Style.shape_outline(self, &"circle", p, r, Color(col, (0.3 if empty else 0.8) * a), Style.u(1.4), empty)
	var ga := a * (0.4 if empty else 1.0) * (0.35 + 0.65 * _gift_glyph_t)
	Glyphs.draw(self, Glyphs.for_item(gift_item), p, 18.0, Color(Palette.BONE, ga))
	Style.text(self, Style.font_sans(true), p + Vector2(r * 0.55, -r * 0.45), str(gift_count), Style.u(11.5), Color(Palette.BONE, a * (0.5 if empty else 1.0)))
	Style.key_cap(self, "G", p + Vector2(0, r + Style.u(13.0)), Style.u(13.5), Color(Palette.BONE, a * 0.8))
