extends CanvasLayer
## D13 key legend (all builds). Every key name is generated from the InputMap, so a rebound key shows
## correctly; only the labels live in legend.json. F1 held: the full sheet, current context first.
## F1 tapped: the corner hint toggles (off by default now: the onboarding hints replace it in play).
## The pure functions are static so tests need no scene.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Strings := preload("res://ui/strings.gd")
const SPEC_PATH := "res://devtools/legend.json"
const TAP_SECONDS := 0.3

static var _spec: Dictionary = {}

static func spec() -> Dictionary:
	if _spec.is_empty():
		var v = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
		_spec = v if v is Dictionary else {}
	return _spec

## Readable names for Godot's key-name strings (OS.get_keycode_string gives enum names for punctuation).
const KEY_NAMES := {
	"QuoteLeft": "`", "BracketLeft": "[", "BracketRight": "]", "Period": ".", "Comma": ",", "Minus": "-",
	"Equal": "=", "Slash": "/", "BackSlash": "\\", "Semicolon": ";", "Apostrophe": "'", "Escape": "Esc",
	"Space": "Space", "PageUp": "PgUp", "PageDown": "PgDn", "BackSpace": "Backspace", "Delete": "Del",
	"Insert": "Ins", "Enter": "Enter", "Tab": "Tab", "Left": "Left arrow", "Right": "Right arrow",
	"Up": "Up arrow", "Down": "Down arrow", "Shift": "Shift", "Ctrl": "Ctrl", "Alt": "Alt", "Meta": "Meta",
}

## One mapping function: Godot key-name string -> label shown to the player.
static func pretty_key_name(name: String) -> String:
	return KEY_NAMES.get(name, name)

## Label of a physical key: the glyph printed on the user's layout when the display server knows it
## ("º" on a Spanish keyboard for the key left of 1), else the readable name of the physical key.
static func key_text(physical: int, layout_aware := true) -> String:
	var code: int = physical
	if layout_aware and DisplayServer.get_name() != "headless":
		var lab := DisplayServer.keyboard_get_label_from_physical(physical)
		if lab != KEY_NONE:
			code = lab
	return pretty_key_name(OS.get_keycode_string(code))

## "Ctrl+B", "W", "Left click" ... for one event.
static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		var name := key_text(code, ev.physical_keycode != 0)
		var pre := ""
		if ev.ctrl_pressed:
			pre += "Ctrl+"
		if ev.alt_pressed:
			pre += "Alt+"
		if ev.shift_pressed:
			pre += "Shift+"
		if ev.meta_pressed:
			pre += "Meta+"
		return pre + name
	if ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "Left click"
			MOUSE_BUTTON_RIGHT: return "Right click"
			MOUSE_BUTTON_MIDDLE: return "Middle click"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel down"
		return "Mouse %d" % ev.button_index
	return ev.as_text()

## All keys of an action, joined by " / "; "?" when the action has no event.
static func action_text(action: String, first_only := false) -> String:
	if not InputMap.has_action(action):
		return "?"
	var parts: PackedStringArray = []
	for ev in InputMap.action_get_events(action):
		parts.append(event_text(ev))
		if first_only:
			break
	return "?" if parts.is_empty() else " / ".join(parts)

## One row per legend entry for `context`: {label, keys, group, action, corner, dev, fixed}.
static func rows(context: StringName, dev_enabled: bool) -> Array:
	var out: Array = []
	var s := spec()
	var actions: Dictionary = s.get("actions", {})
	for a in actions:
		var e: Dictionary = actions[a]
		if bool(e.get("hidden", false)) or (bool(e.get("dev", false)) and not dev_enabled):
			continue
		if not (context in e.get("contexts", [])):
			continue
		var keys := action_text(a)
		if e.has("also"):
			var parts: PackedStringArray = [action_text(a, true)]
			for b in e.also:
				parts.append(action_text(b, true))
			keys = " ".join(parts)
		out.append({"label": e.label, "keys": keys, "group": e.group, "action": a,
			"corner": context in e.get("corner", []), "dev": bool(e.get("dev", false)), "fixed": false})
	for f in s.get("fixed", []):
		if context in f.get("contexts", []) and not (bool(f.get("dev", false)) and not dev_enabled):
			out.append({"label": f.label, "keys": f.keys, "group": f.group, "action": "", "corner": false, "dev": bool(f.get("dev", false)), "fixed": true})
	# Mouse gestures: not InputMap actions (drag thresholds, wheel, double click), listed from the spec.
	for g in s.get("gestures", []):
		if context in g.get("contexts", []) and not (bool(g.get("dev", false)) and not dev_enabled):
			out.append({"label": g.label, "keys": g.keys, "group": g.group, "action": "", "corner": context in g.get("corner", []),
				"dev": bool(g.get("dev", false)), "fixed": false, "gesture": true})
	return out

static func corner_rows(context: StringName, dev_enabled: bool) -> Array:
	return rows(context, dev_enabled).filter(func(r): return r.corner)

## Entries still hard-coded instead of reading the InputMap (flagged by a test so they are not forgotten).
static func fixed_entries() -> Array:
	return spec().get("fixed", [])

# --- the node ------------------------------------------------------------------

var corner_visible := false          # the corner hint is only the onboarding's now; F1 held shows the sheet
var corner: MarginContainer
var sheet: Control               # the veil with the key columns (no panel)
var header_extra := ""          # e.g. the tuning chip of step 10
var _corner_box: VBoxContainer
var _sheet_box: VBoxContainer
var _cols: HBoxContainer
var _held_at := -1.0
var _pinned := false
var _sig := ""

func _init() -> void:
	layer = 20

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.make_diegetic_theme()
	add_child(root)
	corner = MarginContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_left = 14
	corner.offset_bottom = -14
	_corner_box = VBoxContainer.new()
	_corner_box.add_theme_constant_override("separation", 1)
	corner.add_child(_corner_box)
	root.add_child(corner)
	# the sheet: a veil (the fog closing in) and the columns on it; no panel, no border
	sheet = Control.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	var veil := ColorRect.new()
	veil.color = Color(0.094, 0.133, 0.122, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(veil)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(centre)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	centre.add_child(outer)
	_sheet_box = outer
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 28)
	root.add_child(sheet)
	_refresh()

## The key sheet pinned open (the menu's "Keys") until Esc.
func pin_sheet(on: bool) -> void:
	_pinned = on
	sheet.visible = on or _held_at >= 0.0
	_refresh()

func context() -> StringName:
	return Game.legend_context()

func _dev() -> bool:
	return Dev.enabled

func _row_label(text: String, color: Color, size := 14, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if italic:
		l.add_theme_font_override("font", Style.font_italic())
	return l

## A key as a thin rounded outline (the only place besides hints where a key cap is drawn); no fill.
func _key_cap(text: String, color: Color) -> Control:
	var l := _row_label(text, color, 13)
	var st := StyleBoxFlat.new()
	st.draw_center = false
	st.set_border_width_all(1)
	st.border_color = Color(color, 0.7)
	st.set_corner_radius_all(4)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 1
	st.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", st)
	var box := HBoxContainer.new()
	box.add_child(l)
	box.custom_minimum_size = Vector2(130, 0)
	return box

func _refresh() -> void:
	var ctx := context()
	_sig = "%s|%s|%s" % [ctx, _dev(), header_extra]
	for c in _corner_box.get_children():
		c.queue_free()
		_corner_box.remove_child(c)
	var crows := corner_rows(ctx, _dev())
	for r in crows:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_row_label(Strings.legend(r.keys), Palette.COPPER, 13))
		h.add_child(_row_label(Strings.legend(r.label), Palette.FOG, 13))
		_corner_box.add_child(h)
	if header_extra != "":
		_corner_box.add_child(_row_label(header_extra, Palette.LICHEN, 12))
	corner.visible = corner_visible and not crows.is_empty()
	for c in _sheet_box.get_children():
		c.queue_free()
		_sheet_box.remove_child(c)
	_sheet_box.add_child(_row_label("%s: %s%s" % [Strings.legend("Keys"), Strings.legend(String(ctx)), "   " + header_extra if header_extra != "" else ""], Palette.BONE, 23, true))
	var all: Array = []
	var seen := {}
	for c in [ctx] + spec().get("contexts", []):
		if seen.has(c):
			continue
		seen[c] = true
		for r in rows(c, _dev()):
			var k: String = "%s|%s" % [r.label, r.keys]
			if not seen.has(k):
				seen[k] = true
				r["context"] = c
				all.append(r)
	var by_group := {}
	for r in all:
		if not by_group.has(r.group):
			by_group[r.group] = []
		by_group[r.group].append(r)
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 28)
	_sheet_box.add_child(_cols)
	var columns: Array = [VBoxContainer.new(), VBoxContainer.new(), VBoxContainer.new()]
	for col in columns:
		_cols.add_child(col)
	var filled := 0
	var half := int(ceil(float(all.size() + by_group.size()) / 3.0))
	var col_i := 0
	for g in spec().get("groups", []):
		if not by_group.has(g):
			continue
		if filled >= half and col_i < 2:
			col_i += 1
			filled = 0
		var col: VBoxContainer = columns[col_i]
		col.add_child(_row_label(Strings.legend(g), Palette.LICHEN, 17, true))
		filled += 1
		for r in by_group[g]:
			var h := HBoxContainer.new()
			h.add_child(_key_cap(Strings.legend(r.keys), Palette.BONE if r.context == ctx else Palette.FOG))
			var lab: String = Strings.legend(r.label) + ("" if r.context == ctx else "  (%s)" % Strings.legend(String(r.context)))
			h.add_child(_row_label(lab, Palette.BONE if r.context == ctx else Palette.FOG, 13))
			col.add_child(h)
			filled += 1

func _process(_dt: float) -> void:
	var sig := "%s|%s|%s" % [context(), _dev(), header_extra]
	if sig != _sig:
		_refresh()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or e.echo:
		return
	if e.is_action_pressed("legend_hold"):
		_held_at = Time.get_ticks_msec() / 1000.0
		_refresh()
		sheet.visible = true
		get_viewport().set_input_as_handled()
	elif e.is_action_released("legend_hold"):
		sheet.visible = _pinned
		if _held_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - _held_at < TAP_SECONDS:
			corner_visible = not corner_visible
		_held_at = -1.0
		_refresh()
