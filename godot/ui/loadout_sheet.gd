extends Control
## The loadout (docs/godot/UI-DIEGETIC.md 7.14, key L at the nest): a light veil, a title, a row of the moves you know as
## tokens and four slots below with their keys. A token is a glyph inside an outline whose SHAPE is its role (circle basic,
## triangle engage, diamond poke, square control, dome defence, hexagon signature). A move not learned yet is its role
## outline dashed with no glyph (no spoilers). Click a token then a slot, or with keys: Left/Right to focus a token, 1-4 to
## put it in that slot, Backspace to empty the focused slot. Every choice is the C order `loadout SLOT MOVE` (the stage sends
## it); a refusal shakes the token. Replaces loadout_panel.gd with the same calls and signals.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")

signal assign(slot: int, move: int)
signal opened
signal closed

const R_TOKEN := 23.0
const R_SLOT := 27.0

var moves: Array = []                # the slottable moves of the C table
var visible_open := false
var focus := 0                       # focused token index
var picked := -1                     # the token chosen with the mouse, waiting for a slot
var can_edit := false
var nest_radius := 12.0
var slots: Array = [-1, -1, -1, -1]
var known := 0
var signature_slot := -1
var _last: Dictionary = {}
var _alpha := 0.0
var _shake := {}                     # move id -> seconds left
var _press_consumed := false

func _init() -> void:
	name = "LoadoutSheet"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	if not _last.is_empty():
		refresh(_last)

func setup(move_table: Array) -> void:
	moves = []
	for m in move_table:
		if bool(m.get("slottable", false)):
			moves.append(m)

func is_known(move: int, known_mask: int) -> bool:
	return move >= 0 and (known_mask & (1 << move)) != 0

## state.loadout: {slots, known, can_edit, signature_slot, nest_radius}.
func refresh(lo: Dictionary) -> void:
	_last = lo
	slots = lo.get("slots", [-1, -1, -1, -1])
	known = int(lo.get("known", 0))
	can_edit = bool(lo.get("can_edit", false))
	signature_slot = int(lo.get("signature_slot", -1))
	nest_radius = float(lo.get("nest_radius", 12.0))
	queue_redraw()

# --- model (what the tests read) ---------------------------------------------------------------------------------------

func token_count() -> int:
	return moves.size()

func token_id(i: int) -> String:
	return str(moves[i].name) if i >= 0 and i < moves.size() else ""

func token_move(i: int) -> int:
	return int(moves[i].id) if i >= 0 and i < moves.size() else -1

## A token's glyph: "" for a move not learned yet (no spoiler).
func token_glyph(i: int) -> String:
	if i < 0 or i >= moves.size() or not is_known(token_move(i), known):
		return ""
	return Glyphs.for_move(str(moves[i].name))

func token_shape(i: int) -> StringName:
	return Palette.ROLE_SHAPES.get(str(moves[i].role_name), &"circle") if i >= 0 and i < moves.size() else &"circle"

func token_enabled(i: int) -> bool:
	return can_edit and i >= 0 and i < moves.size() and is_known(token_move(i), known)

func slot_move(slot: int) -> int:
	return int(slots[slot]) if slot >= 0 and slot < slots.size() else -1

## For tests and keyboard users: choose `move` (id or -1) for `slot` exactly as clicking would.
func choose(slot: int, move: int) -> void:
	if slot < 0 or slot > 3:
		return
	assign.emit(slot, move)       # C decides: a move that is not known comes back refused

func open_panel() -> void:
	visible_open = true
	visible = true
	picked = -1
	focus = clampi(focus, 0, maxi(moves.size() - 1, 0))
	opened.emit()

func close_panel() -> void:
	if visible_open:
		visible_open = false
		picked = -1
		closed.emit()

func toggle() -> void:
	if visible_open:
		close_panel()
	else:
		open_panel()

func refuse(move: int) -> void:
	_shake[move] = 0.2

# --- geometry ----------------------------------------------------------------------------------------------------------

func _c() -> Vector2:
	return size * 0.5 if size != Vector2.ZERO else Vector2(640, 360)

func token_pos(i: int) -> Vector2:
	var n := moves.size()
	return _c() + Vector2((float(i) - (n - 1) * 0.5) * Style.u(64.0), -Style.u(50.0))

func slot_pos(k: int) -> Vector2:
	return _c() + Vector2((float(k) - 1.5) * Style.u(80.0), Style.u(88.0))

func token_at(p: Vector2) -> int:
	for i in moves.size():
		if p.distance_to(token_pos(i)) <= Style.u(R_TOKEN + 4.0):
			return i
	return -1

func slot_at(p: Vector2) -> int:
	for k in 4:
		if p.distance_to(slot_pos(k)) <= Style.u(R_SLOT + 4.0):
			return k
	return -1

# --- input -------------------------------------------------------------------------------------------------------------

func handle_input(e: InputEvent) -> bool:
	if not visible_open:
		return false
	if e is InputEventMouseMotion:
		var t := token_at(e.position)
		if t >= 0:
			focus = t
		return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			return true
		var t := token_at(e.position)
		if t >= 0:
			focus = t
			picked = t if token_enabled(t) else -1
			return true
		var k := slot_at(e.position)
		if k >= 0:
			if picked >= 0:
				choose(k, token_move(picked))
				picked = -1
			return true
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		var code: Key = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		if e.is_action_pressed("loadout") or e.is_action_pressed("pause_menu"):
			close_panel()
		elif code == KEY_LEFT or code == KEY_A:
			focus = (focus - 1 + maxi(moves.size(), 1)) % maxi(moves.size(), 1)
		elif code == KEY_RIGHT or code == KEY_D:
			focus = (focus + 1) % maxi(moves.size(), 1)
		elif code >= KEY_1 and code <= KEY_4:
			if token_enabled(focus):
				choose(code - KEY_1, token_move(focus))
		elif code == KEY_BACKSPACE:
			choose(0 if picked < 0 else 0, -1)
		return true
	return false

# --- drawing -----------------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if visible_open else 0.0, dt, Style.IN if visible_open else Style.OUT)
	for k in _shake.keys():
		_shake[k] -= dt
		if _shake[k] <= 0.0:
			_shake.erase(k)
	if _alpha <= 0.003 and not visible_open:
		visible = false
		return
	visible = true
	queue_redraw()

func _draw() -> void:
	var a := _alpha
	var c := _c()
	var title := Strings.t("loadout_title")
	var ft := Style.font_italic()
	var tw := Style.text_width(ft, title, Style.u(24.0))
	Style.text(self, ft, c + Vector2(-tw * 0.5, -Style.u(112.0)), title, Style.u(24.0), Color(Palette.BONE, a))
	for i in moves.size():
		var p := token_pos(i)
		if _shake.has(token_move(i)):
			p.x += sin(_shake[token_move(i)] / 0.2 * TAU * 2.0) * Style.u(3.0)
		var r := Style.u(R_TOKEN)
		var kn := is_known(token_move(i), known)
		var shape := token_shape(i)
		var focused := i == focus
		var picked_now := i == picked
		var col := Color(Palette.COPPER, a) if (focused or picked_now) else Color(Palette.BONE, 0.8 * a)
		draw_circle(p, r, Color(Palette.INK, 0.24 * a))
		if kn:
			Style.shape_outline(self, shape, p, r, col, Style.u(2.6 if focused else 1.4), false, str(moves[i].role_name) == "signature")
			Glyphs.draw(self, token_glyph(i), p, 25.0, Color(Palette.BONE, a * (1.0 if can_edit else 0.5)))
		else:
			Style.shape_outline(self, shape, p, r, Color(Palette.BONE, 0.45 * a), Style.u(1.4), true)
	if focus >= 0 and focus < moves.size():
		var m: Dictionary = moves[focus]
		var kn2 := is_known(token_move(focus), known)
		var nm := String(m.name).replace("_", " ").capitalize() if kn2 else "?"
		var f := Style.font_sans(true)
		var w := Style.text_width(f, nm, Style.u(19.0))
		Style.text(self, f, c + Vector2(-w * 0.5, Style.u(-1.0)), nm, Style.u(19.0), Color(Palette.BONE, a))
		var role := Strings.t("role_" + str(m.role_name)) if Strings.has("role_" + str(m.role_name)) else str(m.role_name)
		var desc := Strings.t("move_" + str(m.name)) if (kn2 and Strings.has("move_" + str(m.name))) else Strings.t("move_unknown")
		var line := "%s · %s" % [role, desc]
		var f2 := Style.font_sans()
		var w2 := Style.text_width(f2, line, Style.u(14.5))
		Style.text(self, f2, c + Vector2(-w2 * 0.5, Style.u(19.0)), line, Style.u(14.5), Color(Palette.FOG, a))
	Style.line(self, c + Vector2(-Style.u(170.0), Style.u(34.0)), c + Vector2(Style.u(170.0), Style.u(34.0)), Color(Palette.BONE, 0.3 * a), Style.u(1.0))
	for k in 4:
		var p := slot_pos(k)
		var r := Style.u(R_SLOT)
		var mv := slot_move(k)
		var sig := k == signature_slot
		draw_circle(p, r, Color(Palette.INK, 0.24 * a))
		if mv >= 0:
			var role_name := ""
			var nm2 := ""
			for m in moves:
				if int(m.id) == mv:
					role_name = str(m.role_name)
					nm2 = str(m.name)
			var shape: StringName = Palette.ROLE_SHAPES.get(role_name, &"circle")
			Style.shape_outline(self, shape, p, r, Color(Palette.BONE, 0.9 * a), Style.u(1.6), false, sig)
			Glyphs.draw(self, Glyphs.for_move(nm2), p, 27.0, Color(Palette.BONE, a))
		else:
			Style.shape_outline(self, &"circle", p, r, Color(Palette.BONE, 0.3 * a), Style.u(1.4), true)
		Style.key_cap(self, str(k + 1), p + Vector2(0, r + Style.u(16.0)), Style.u(14.5), Color(Palette.BONE, 0.9 * a))
		if picked >= 0:
			Style.line(self, token_pos(picked), p, Color(Palette.COPPER, 0.0), 1.0)
	if picked >= 0:
		var pp := token_pos(picked)
		for k in 4:
			var q := slot_pos(k)
			var steps := int(pp.distance_to(q) / Style.u(9.0))
			for s in steps:
				var t := float(s) / maxf(steps, 1)
				draw_circle(pp.lerp(q, t), Style.u(1.3), Color(Palette.COPPER, 0.35 * a))
	if not can_edit:
		var msg := Strings.t("loadout_far")
		var mw := Style.text_width(Style.font_sans(), msg, Style.u(14.5))
		Style.text(self, Style.font_sans(), c + Vector2(-mw * 0.5, Style.u(150.0)), msg, Style.u(14.5), Color(Palette.OCHRE, a))
