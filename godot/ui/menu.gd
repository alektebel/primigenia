extends Control
## The menu (docs/godot/UI-DIEGETIC.md 7.13): a text list that rises from the seed, over the veil. No panel, no buttons.
## The focused item is Medium weight at full opacity with a copper tick to its left; the others 0.82; unavailable 0.40 with
## its reason beside it. "Settings" opens a second column: a title in Alegreya Italic, then a row per setting (a choice is
## its options as words with a copper underline on the chosen one; a slider is a hairline with a bone knob).
## Keyboard: Up/Down or W/S move, Enter/Space choose, Left/Right or A/D change a setting, Esc goes back one level.
## Hover is focus. Replaces pause_menu.gd; keeps its signals.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const Scenario := preload("res://devtools/scenario.gd")

signal resume_requested
signal menu_requested
signal save_requested
signal load_requested
signal journal_requested
signal family_tree_requested
signal loadout_requested
signal keys_requested
signal hints_reset_requested
signal setting_changed(key: String, value)

const ROW_H := 33.0
const LIST_X := 64.0
const KEY_X := 214.0
const SET_X := 330.0
const CTRL_X := 480.0
const BUSES := ["master", "music", "sfx", "ambience"]

## id, label key, key hint, always enabled
const ITEMS := [
	["resume", "resume", "Esc"],
	["journal", "journal", "J"],
	["family_tree", "family_tree", "T"],
	["loadout", "loadout", "L"],
	["settings", "settings", ""],
	["keys", "keys", "F1"],
	["save", "save", ""],
	["load", "load", ""],
	["main_menu", "main_menu", ""],
]

var audio
var open := false
var column := 0                       # 0 the list, 1 the settings
var focus := 0                        # index in the list
var row_focus := 0                    # index in the settings
var loadout_available := false
var rows: Array = []                  # the settings rows: {key, label, kind, options?, min, max}
var _alpha := 0.0
var _hover_t := 0.0
var _drag := ""                       # the slider being dragged

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_rows()

func _build_rows() -> void:
	rows = [
		{"key": "language", "label": "language", "kind": "choice", "options": ["english", "spanish"]},
		{"key": "ui_scale", "label": "size_signs", "kind": "slider", "min": 0.85, "max": 1.5},
		{"key": "names_always", "label": "names_signs", "kind": "choice", "options": ["on_hover", "always"]},
		{"key": "numbers", "label": "numbers", "kind": "choice", "options": ["off", "on"]},
		{"key": "strong_outlines", "label": "outlines", "kind": "choice", "options": ["off", "on"]},
		{"key": "reduced_motion", "label": "less_motion", "kind": "choice", "options": ["off", "on"]},
		{"key": "minimap", "label": "minimap", "kind": "choice", "options": ["off", "on"]},
		{"key": "master", "label": "master", "kind": "slider", "min": 0.0, "max": 1.0},
		{"key": "music", "label": "music", "kind": "slider", "min": 0.0, "max": 1.0},
		{"key": "sfx", "label": "sfx", "kind": "slider", "min": 0.0, "max": 1.0},
		{"key": "ambience", "label": "ambience", "kind": "slider", "min": 0.0, "max": 1.0},
		{"key": "mute", "label": "mute", "kind": "choice", "options": ["off", "on"]},
		{"key": "show_hints", "label": "show_hints", "kind": "action"},
	]

func bind_audio(a) -> void:
	audio = a

# --- state (also what the tests read) ----------------------------------------------------------------------------------

func slot_exists() -> bool:
	return FileAccess.file_exists("%s/%s.json" % [Scenario.save_dir, Scenario.SAVE_SLOT])

func item_enabled(id: String) -> bool:
	match id:
		"load":
			return slot_exists()
		"loadout":
			return loadout_available
		"family_tree", "journal", "keys":
			return true
	return true

func item_ids() -> Array:
	return ITEMS.map(func(r): return r[0])

func focused_id() -> String:
	return ITEMS[focus][0]

func _game_settings() -> Dictionary:
	var tree := get_tree()
	return tree.root.get_node("Game").settings if tree != null and tree.root.has_node("Game") else {}

## The value of a setting row: a bool, a float, or the language ("en" / "es").
func value_of(key: String) -> Variant:
	if key in BUSES:
		return audio.get_volume(key) if audio else 0.5
	if key == "mute":
		return audio.is_muted() if audio else false
	if key == "language":
		return Strings.language()
	return _game_settings().get(key, false if key != "ui_scale" else 1.0)

func choice_index(row: Dictionary) -> int:
	var v: Variant = value_of(row.key)
	if row.key == "language":
		return 1 if v == "es" else 0
	return 1 if bool(v) else 0

## Write a setting through the right place: audio buses to the audio manager, the rest to Game.settings (saved).
func set_value(key: String, v: Variant) -> void:
	if key in BUSES:
		if audio:
			audio.set_volume(key, float(v))
	elif key == "mute":
		if audio:
			audio.set_mute(bool(v))
	else:
		var s := _game_settings()
		s[key] = v
		var tree := get_tree()
		if tree != null and tree.root.has_node("Game"):
			tree.root.get_node("Game").save_settings()
	setting_changed.emit(key, v)
	queue_redraw()

func set_choice(key: String, index: int) -> void:
	if key == "language":
		set_value(key, "es" if index == 1 else "en")
	else:
		set_value(key, index == 1)

func row_by_key(key: String) -> Dictionary:
	for r in rows:
		if r.key == key:
			return r
	return {}

func slider_fraction(row: Dictionary) -> float:
	return clampf((float(value_of(row.key)) - float(row.min)) / (float(row.max) - float(row.min)), 0.0, 1.0)

func activate(id: String) -> void:
	if not item_enabled(id):
		return
	match id:
		"resume":
			resume_requested.emit()
		"journal":
			journal_requested.emit()
		"family_tree":
			family_tree_requested.emit()
		"loadout":
			loadout_requested.emit()
		"settings":
			column = 1
			row_focus = 0
		"keys":
			keys_requested.emit()
		"save":
			save_requested.emit()
		"load":
			load_requested.emit()
		"main_menu":
			menu_requested.emit()
	queue_redraw()

func open_menu() -> void:
	open = true
	column = 0
	focus = 0
	visible = true
	_alpha = 0.0

func close_menu() -> void:
	open = false
	visible = false

# --- geometry ----------------------------------------------------------------------------------------------------------

func list_y(i: int) -> float:
	return size.y - Style.u(84.0) - (ITEMS.size() - 1 - i) * Style.u(ROW_H)

func row_y(i: int) -> float:
	return size.y - Style.u(84.0) - (rows.size() - 1 - i) * Style.u(ROW_H)

func item_at(pos: Vector2) -> int:
	if pos.x < Style.u(LIST_X - 24.0) or pos.x > Style.u(KEY_X + 90.0):
		return -1
	for i in ITEMS.size():
		if absf(pos.y - (list_y(i) - Style.u(6.0))) <= Style.u(ROW_H) * 0.5:
			return i
	return -1

func row_at(pos: Vector2) -> int:
	if pos.x < Style.u(SET_X - 12.0):
		return -1
	for i in rows.size():
		if absf(pos.y - (row_y(i) - Style.u(6.0))) <= Style.u(ROW_H) * 0.5:
			return i
	return -1

func _choice_rects(row: Dictionary, y: float) -> Array:
	var rects: Array = []
	var x := Style.u(CTRL_X)
	for o in row.options:
		var w := Style.text_width(Style.font_sans(), Strings.t(o), Style.u(16.5))
		rects.append(Rect2(x - 4, y - Style.u(20.0), w + 8, Style.u(26.0)))
		x += w + Style.u(18.0)
	return rects

func _slider_rect(y: float) -> Rect2:
	return Rect2(Style.u(CTRL_X), y - Style.u(14.0), Style.u(150.0), Style.u(18.0))

# --- input -------------------------------------------------------------------------------------------------------------

func handle_input(e: InputEvent) -> bool:
	if not open:
		return false
	if e is InputEventMouseMotion:
		var i := item_at(e.position)
		if i >= 0:
			focus = i
		var r := row_at(e.position)
		if r >= 0 and column == 1:
			row_focus = r
		if _drag != "":
			_drag_to(e.position)
		queue_redraw()
		return true
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if not e.pressed:
			_drag = ""
			return true
		var i := item_at(e.position)
		if i >= 0:
			focus = i
			column = 0 if ITEMS[i][0] != "settings" else column
			activate(ITEMS[i][0])
			return true
		var r := row_at(e.position)
		if r >= 0 and column == 1:
			row_focus = r
			var row: Dictionary = rows[r]
			if row.kind == "action":
				hints_reset_requested.emit()
			elif row.kind == "choice":
				var rects := _choice_rects(row, row_y(r))
				for k in rects.size():
					if rects[k].has_point(e.position):
						set_choice(row.key, k)
			else:
				_drag = row.key
				_drag_to(e.position)
		return true
	if e is InputEventKey and e.pressed and not e.echo:
		return _key(e)
	return false

func _drag_to(pos: Vector2) -> void:
	var r := row_by_key(_drag)
	if r.is_empty():
		return
	var rect := _slider_rect(row_y(rows.find(r)))
	var f := clampf((pos.x - rect.position.x) / rect.size.x, 0.0, 1.0)
	set_value(_drag, snappedf(lerpf(float(r.min), float(r.max), f), 0.05))

func _key(e: InputEventKey) -> bool:
	var code: Key = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	var up := code == KEY_UP or code == KEY_W
	var down := code == KEY_DOWN or code == KEY_S
	var left := code == KEY_LEFT or code == KEY_A
	var right := code == KEY_RIGHT or code == KEY_D
	var go := code == KEY_ENTER or code == KEY_KP_ENTER or code == KEY_SPACE
	if column == 0:
		if up:
			focus = (focus - 1 + ITEMS.size()) % ITEMS.size()
		elif down:
			focus = (focus + 1) % ITEMS.size()
		elif go or right:
			if right and ITEMS[focus][0] != "settings":
				return true
			activate(ITEMS[focus][0])
		elif code == KEY_ESCAPE:
			resume_requested.emit()
		else:
			return false
	else:
		if up:
			row_focus = (row_focus - 1 + rows.size()) % rows.size()
		elif down:
			row_focus = (row_focus + 1) % rows.size()
		elif left or right or go:
			_change(rows[row_focus], -1 if left else 1)
		elif code == KEY_ESCAPE:
			column = 0
		else:
			return false
	queue_redraw()
	return true

func _change(row: Dictionary, dir: int) -> void:
	if row.kind == "action":
		hints_reset_requested.emit()
		return
	if row.kind == "choice":
		var n: int = (choice_index(row) + dir + row.options.size()) % row.options.size()
		set_choice(row.key, n)
	else:
		var v := float(value_of(row.key)) + dir * 0.05 * (float(row.max) - float(row.min)) / (1.0 if row.key in BUSES else 1.0)
		set_value(row.key, clampf(snappedf(v, 0.05), float(row.min), float(row.max)))

# --- drawing -----------------------------------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_alpha = Style.approach(_alpha, 1.0 if open else 0.0, dt, Style.OUT)
	if open:
		queue_redraw()

func _draw() -> void:
	if not open or _alpha < 0.01:
		return
	var f := Style.font_sans()
	var fm := Style.font_sans(true)
	var s := Style.u(22.0)
	for i in ITEMS.size():
		var id: String = ITEMS[i][0]
		var y := list_y(i)
		var on := item_enabled(id)
		var focused := i == focus and (column == 0 or id == "settings")
		var a := (1.0 if focused else 0.82) * (1.0 if on else Style.DISABLED_ALPHA / 0.82 * 0.82) * _alpha
		if not on:
			a = Style.DISABLED_ALPHA * _alpha
		var col := Color(Palette.BONE, a)
		if focused:
			Style.line(self, Vector2(Style.u(LIST_X - 22.0), y - Style.u(7.0)), Vector2(Style.u(LIST_X - 8.0), y - Style.u(7.0)), Color(Palette.COPPER, _alpha), Style.u(2.0))
		Style.text(self, fm if focused else f, Vector2(Style.u(LIST_X), y), Strings.t(ITEMS[i][1]), s, col)
		var kh: String = ITEMS[i][2]
		if kh != "":
			Style.text(self, f, Vector2(Style.u(KEY_X), y), kh, Style.u(13.5), Color(Palette.FOG, a))
		if not on and id == "loadout":
			Style.text(self, Style.font_italic(), Vector2(Style.u(KEY_X + 34.0), y), Strings.t("at_nest"), Style.u(14.0), Color(Palette.FOG, _alpha * 0.8))
	if column == 1:
		_draw_settings()

func _draw_settings() -> void:
	var f := Style.font_sans()
	Style.text(self, Style.font_italic(), Vector2(Style.u(SET_X), row_y(0) - Style.u(ROW_H + 4.0)), Strings.t("settings"), Style.u(23.0), Color(Palette.BONE, _alpha))
	for i in rows.size():
		var row: Dictionary = rows[i]
		var y := row_y(i)
		var focused := i == row_focus
		Style.text(self, Style.font_sans(focused), Vector2(Style.u(SET_X), y), Strings.t(row.label), Style.u(16.5), Color(Palette.BONE, (1.0 if focused else 0.82) * _alpha))
		if focused:
			Style.line(self, Vector2(Style.u(SET_X - 18.0), y - Style.u(5.0)), Vector2(Style.u(SET_X - 8.0), y - Style.u(5.0)), Color(Palette.COPPER, _alpha), Style.u(2.0))
		if row.kind == "action":
			pass
		elif row.kind == "choice":
			var rects := _choice_rects(row, y)
			var ci := choice_index(row)
			for k in rects.size():
				var r: Rect2 = rects[k]
				var chosen := k == ci
				Style.text(self, Style.font_sans(chosen), Vector2(r.position.x + 4, y), Strings.t(row.options[k]), Style.u(16.5), Color(Palette.BONE, (1.0 if chosen else 0.7) * _alpha))
				if chosen:
					Style.line(self, Vector2(r.position.x + 4, y + Style.u(5.0)), Vector2(r.end.x - 4, y + Style.u(5.0)), Color(Palette.COPPER, _alpha), Style.u(1.6))
		else:
			var rect := _slider_rect(y)
			var cy := y - Style.u(5.0)
			Style.line(self, Vector2(rect.position.x, cy), Vector2(rect.end.x, cy), Color(Palette.BONE, 0.5 * _alpha), Style.u(1.2))
			var kx := rect.position.x + rect.size.x * slider_fraction(row)
			draw_circle(Vector2(kx, cy), Style.u(5.0) + 1.5, Color(Palette.INK, 0.5 * _alpha))
			draw_circle(Vector2(kx, cy), Style.u(5.0), Color(Palette.BONE, _alpha))
