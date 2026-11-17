extends CanvasLayer
## D13 key legend (all builds). Every key name is generated from the InputMap, so a rebound key shows
## correctly; only the labels live in legend.json. F1 held: the full sheet, current context first.
## F1 tapped: the corner hint (3-4 keys for the current context) toggles.
## The pure functions are static so tests need no scene.

const Palette := preload("res://ui/palette.gd")
const SPEC_PATH := "res://devtools/legend.json"
const TAP_SECONDS := 0.3

static var _spec: Dictionary = {}

static func spec() -> Dictionary:
	if _spec.is_empty():
		var v = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
		_spec = v if v is Dictionary else {}
	return _spec

## "Ctrl+B", "W", "Left click" ... for one event.
static func event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var code: Key = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		if ev.physical_keycode != 0 and DisplayServer.get_name() != "headless":
			var lab := DisplayServer.keyboard_get_label_from_physical(ev.physical_keycode)
			if lab != KEY_NONE:
				code = lab
		var name := OS.get_keycode_string(code)
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
		if context in f.get("contexts", []):
			out.append({"label": f.label, "keys": f.keys, "group": f.group, "action": "", "corner": false, "dev": false, "fixed": true})
	return out

static func corner_rows(context: StringName, dev_enabled: bool) -> Array:
	return rows(context, dev_enabled).filter(func(r): return r.corner)

## Entries still hard-coded instead of reading the InputMap (flagged by a test so they are not forgotten).
static func fixed_entries() -> Array:
	return spec().get("fixed", [])

# --- the node ------------------------------------------------------------------

var corner_visible := true
var corner: PanelContainer
var sheet: PanelContainer
var header_extra := ""          # e.g. the tuning chip of step 10
var _corner_box: VBoxContainer
var _sheet_box: VBoxContainer
var _cols: HBoxContainer
var _held_at := -1.0
var _sig := ""

func _init() -> void:
	layer = 20

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.make_theme()
	add_child(root)
	corner = PanelContainer.new()
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL, 0.7), 10, Palette.BORDER, 6))
	corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_left = 14
	corner.offset_bottom = -14
	_corner_box = VBoxContainer.new()
	_corner_box.add_theme_constant_override("separation", 1)
	corner.add_child(_corner_box)
	root.add_child(corner)
	sheet = PanelContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 16, Palette.BORDER, 18))
	sheet.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.visible = false
	var outer := VBoxContainer.new()
	sheet.add_child(outer)
	_sheet_box = outer
	_cols = HBoxContainer.new()
	_cols.add_theme_constant_override("separation", 28)
	root.add_child(sheet)
	_refresh()

func context() -> StringName:
	return Game.legend_context()

func _dev() -> bool:
	return Dev.enabled

func _row_label(text: String, color: Color, size := 14) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	return l

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
		h.add_child(_row_label(r.keys, Palette.GOLD, 13))
		h.add_child(_row_label(r.label, Palette.MUTED, 13))
		_corner_box.add_child(h)
	if header_extra != "":
		_corner_box.add_child(_row_label(header_extra, Palette.LEAF, 12))
	corner.visible = corner_visible and not crows.is_empty()
	for c in _sheet_box.get_children():
		c.queue_free()
		_sheet_box.remove_child(c)
	_sheet_box.add_child(_row_label("Keys: %s%s" % [ctx, "   " + header_extra if header_extra != "" else ""], Palette.GOLD, 20))
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
	var columns: Array = [VBoxContainer.new(), VBoxContainer.new()]
	for col in columns:
		_cols.add_child(col)
	var filled := 0
	var half := (all.size() + by_group.size()) / 2
	var col_i := 0
	for g in spec().get("groups", []):
		if not by_group.has(g):
			continue
		if filled >= half and col_i == 0:
			col_i = 1
		var col: VBoxContainer = columns[col_i]
		col.add_child(_row_label(g, Palette.LEAF, 14))
		filled += 1
		for r in by_group[g]:
			var h := HBoxContainer.new()
			var k := _row_label(r.keys, Palette.GOLD if r.context == ctx else Palette.MUTED, 13)
			k.custom_minimum_size = Vector2(120, 0)
			h.add_child(k)
			var lab: String = r.label + ("" if r.context == ctx else "  (%s)" % r.context)
			h.add_child(_row_label(lab, Palette.TEXT if r.context == ctx else Palette.MUTED, 13))
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
		sheet.visible = false
		if _held_at >= 0.0 and Time.get_ticks_msec() / 1000.0 - _held_at < TAP_SECONDS:
			corner_visible = not corner_visible
		_held_at = -1.0
		_refresh()
