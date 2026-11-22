extends CanvasLayer

const FrameProfile := preload("res://devtools/frame_profile.gd")
## F10 option mode (docs/briefs/dev-options.md): a small corner HUD, no panel, same style as the F1 sheet.
##   1-9 pick a group, Up/Down an option, Left/Right cycle the value (instant, no animation; numeric: one step, Shift x10),
##   Backspace resets the option, Ctrl+Backspace resets all, Ctrl+1-4 saves a preset, Alt+1-4 recalls it, Esc / F10 closes.
## While it is open every key but the F-keys and the console key is eaten here and Game.options_open blocks movement,
## so the digits and the arrows do not also move the creature or fire moves.
## Closed, a line in the corner lists the active non-default choices ("gait froude · skin v1 · light day").
## All decisions live in handle_key() (pure on the registry) so tests drive it without a window.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")

const GROUPS := ["Movement", "Creature", "Look", "Light", "Camera", "World", "Overlays", "Tuning", "Presets"]
## Numeric entries (registry.order) go to a group by key prefix; "Tuning" lists all of them.
const NUMERIC_GROUP := {"loco/": "Movement", "camera/": "Camera"}

var tuning                      # the registry
var is_open := false
var group := 0                  # index in GROUPS
var row := 0                    # selected option inside the group
var message := ""               # last result ("preset 2 saved", an error sentence)
var _root: Control
var _hud: VBoxContainer
var _line: Label
var _sig := ""
var _last_choices: Dictionary = {}

func _init() -> void:
	layer = 31

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Palette.make_diegetic_theme()
	add_child(_root)
	_hud = VBoxContainer.new()
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_theme_constant_override("separation", 2)
	_hud.position = Vector2(18, 190)    # below the task card
	_hud.visible = false
	_root.add_child(_hud)
	_line = Label.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_line.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_line.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_line.offset_right = -16
	_line.offset_bottom = -12
	_line.add_theme_color_override("font_color", Palette.LICHEN)
	_line.add_theme_font_size_override("font_size", 13)
	_line.add_theme_font_override("font", Style.font_italic())
	_root.add_child(_line)
	_refresh()

# --- model (pure on the registry) ---------------------------------------------------------------------

## Option keys of a group: choices first, then numeric entries.
func keys_of(g: int) -> Array:
	var name: String = GROUPS[g]
	var out: Array = []
	if tuning == null or name == "Presets":
		return out
	for k in tuning.choice_order:
		if str(tuning.choices[k].group).to_lower() == name.to_lower():
			out.append(k)
	for k in tuning.order:
		if name == "Tuning":
			out.append(k)
			continue
		for pre in NUMERIC_GROUP:
			if k.begins_with(pre) and NUMERIC_GROUP[pre] == name:
				out.append(k)
	return out

func row_count() -> int:
	return tuning.PRESET_SLOTS if GROUPS[group] == "Presets" else keys_of(group).size()

func current_key() -> String:
	var ks := keys_of(group)
	return ks[row] if row >= 0 and row < ks.size() else ""

func open() -> void:
	if is_open:
		return
	is_open = true
	Game.options_open = true
	_refresh()

func close() -> void:
	if not is_open:
		return
	is_open = false
	Game.options_open = Dev.flag != null and Dev.flag.active
	_refresh()

func toggle() -> void:
	close() if is_open else open()

func select_group(g: int) -> void:
	group = clampi(g, 0, GROUPS.size() - 1)
	row = 0
	message = ""

func _step_numeric(k: String, dir: int, shift: bool) -> void:
	var e: Dictionary = tuning.entries[k]
	var err: String = tuning.set_value(k, tuning.value(k) + dir * float(e.step) * (10.0 if shift else 1.0))
	message = err

## Handles one key press while the HUD is open (or F10 when closed). Returns true when the key was used.
func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo or tuning == null:
		return false
	var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if not is_open:
		if code == KEY_F10 and not Game.console_open:
			open()
			return true
		return false
	if code == KEY_F10 or code == KEY_ESCAPE:
		close()
		return true
	if code >= KEY_1 and code <= KEY_9:
		var n := code - KEY_1 + 1
		if e.ctrl_pressed and n <= tuning.PRESET_SLOTS:
			message = ("preset %d saved" % n) if tuning.save_preset(n) != "" else "could not save preset %d" % n
		elif e.alt_pressed and n <= tuning.PRESET_SLOTS:
			var err: String = tuning.recall_preset(n)
			message = err if err != "" else "preset %d recalled" % n
		elif not e.ctrl_pressed and not e.alt_pressed:
			select_group(n - 1)
		return true
	var count := row_count()
	match code:
		KEY_UP:
			row = posmod(row - 1, count) if count > 0 else 0
			message = ""
		KEY_DOWN:
			row = posmod(row + 1, count) if count > 0 else 0
			message = ""
		KEY_LEFT, KEY_RIGHT:
			var dir := -1 if code == KEY_LEFT else 1
			if GROUPS[group] == "Presets":
				if dir > 0 or e.alt_pressed:
					var err2: String = tuning.recall_preset(row + 1)
					message = err2 if err2 != "" else "preset %d recalled" % (row + 1)
			else:
				var k := current_key()
				if k != "":
					if tuning.is_choice(k):
						message = tuning.cycle_choice(k, dir)
					else:
						_step_numeric(k, dir, e.shift_pressed)
		KEY_ENTER, KEY_KP_ENTER:
			if GROUPS[group] == "Presets":
				var err3: String = tuning.recall_preset(row + 1)
				message = err3 if err3 != "" else "preset %d recalled" % (row + 1)
		KEY_BACKSPACE:
			if e.ctrl_pressed:
				tuning.apply({"format": tuning.FORMAT, "values": {}})
				message = "all options reset"
			else:
				var k2 := current_key()
				if k2 != "":
					tuning.reset(k2)
					message = ""
		_:
			pass
	_refresh()
	return true

# --- drawing --------------------------------------------------------------------------------------------

## Text of one option row: "Gait: froude ▸ 2/3" for choices, "value (default d)" for numeric ones.
func row_text(k: String) -> String:
	var name := k.get_slice("/", k.get_slice_count("/") - 1).replace("_", " ").capitalize()
	if tuning.is_choice(k):
		var e: Dictionary = tuning.choices[k]
		var cur: String = tuning.choice_value(k)
		return "%s: %s ▸ %d/%d" % [name, cur, e.values.find(cur) + 1, e.values.size()]
	var v := snappedf(tuning.value(k), 0.001)
	return "%s: %s%s" % [name, v, "  (default %s)" % snappedf(tuning.entries[k].default, 0.001) if tuning.is_changed(k) else ""]

func describe(k: String) -> String:
	if not tuning.is_choice(k):
		var e: Dictionary = tuning.entries[k]
		return "%s to %s, step %s (Shift x10)" % [snappedf(e.min, 0.001), snappedf(e.max, 0.001), snappedf(e.step, 0.001)]
	var c: Dictionary = tuning.choices[k]
	var parts := PackedStringArray()
	for v in c.values:
		parts.append(v if not c.disabled.has(v) else "%s (%s)" % [v, c.disabled[v]])
	return "%s%s" % [(c.desc + "  ") if c.desc != "" else "", " / ".join(parts)]

func _label(text: String, color: Color, size := 15, italic := false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if italic:
		l.add_theme_font_override("font", Style.font_italic())
	return l

func _refresh() -> void:
	if _hud == null:
		return
	_hud.visible = is_open
	var line: String = tuning.choices_line() if tuning != null else ""
	_line.text = line
	_line.visible = line != "" and not is_open
	_sig = line
	_last_choices = tuning.current_choices() if tuning != null else {}
	for c in _hud.get_children():
		c.queue_free()
		_hud.remove_child(c)
	if not is_open or tuning == null:
		return
	_hud.add_child(_label("Options", Palette.BONE, 22, true))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 14)
	for i in GROUPS.size():
		tabs.add_child(_label("%d %s" % [i + 1, GROUPS[i]], Palette.GOLD if i == group else Palette.FOG, 15))
	_hud.add_child(tabs)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_hud.add_child(spacer)
	if GROUPS[group] == "Presets":
		for n in tuning.PRESET_SLOTS:
			var txt := "Preset %d: %s" % [n + 1, "saved" if tuning.has_preset(n + 1) else "empty"]
			_hud.add_child(_label(("▸ " if n == row else "   ") + txt, Palette.BONE if n == row else Palette.FOG, 16))
		_hud.add_child(_label("Right or Enter recalls the selected slot; Ctrl+1-4 saves the current set, Alt+1-4 recalls", Palette.FOG, 13, true))
	else:
		var ks := keys_of(group)
		if ks.is_empty():
			_hud.add_child(_label("nothing here yet (start the island)", Palette.FOG, 14, true))
		for i in ks.size():
			var changed: bool = tuning.choice_changed(ks[i]) if tuning.is_choice(ks[i]) else tuning.is_changed(ks[i])
			var col: Color = Palette.GOLD if changed else (Palette.BONE if i == row else Palette.FOG)
			_hud.add_child(_label(("▸ " if i == row else "   ") + row_text(ks[i]), col, 16))
		if not ks.is_empty():
			_hud.add_child(_label(describe(ks[row]), Palette.FOG, 13, true))
	_hud.add_child(_label("Left/Right value   Up/Down option   Backspace reset (Ctrl all)   Esc close", Palette.FOG, 12, true))
	if message != "":
		_hud.add_child(_label(message, Palette.COPPER, 13, true))

func _process(_dt: float) -> void:
	if not FrameProfile.enabled:
		_profile__process(_dt)
		return
	FrameProfile.begin()
	_profile__process(_dt)
	FrameProfile.end(&"options HUD")

func _profile__process(_dt: float) -> void:
	if tuning != null and tuning.current_choices() != _last_choices:
		_refresh()

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not Dev.enabled:
		return
	var used := false
	if e.pressed and (e.is_action_pressed("dev_options") or is_open):
		var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
		var fkey: bool = code >= KEY_F1 and code <= KEY_F12 and code != KEY_F10
		if is_open and (fkey or e.is_action_pressed("dev_console")):
			return    # the other dev keys keep working
		used = handle_key(e)
		if not used and is_open:
			used = true    # any other key is eaten while the HUD is open
	elif is_open and not e.pressed:
		used = true       # releases of the eaten keys too
	if used and is_inside_tree():
		get_viewport().set_input_as_handled()
