extends CanvasLayer
## N notes (DT-NOTE-N). N at any time grabs the frame BEFORE the card exists, pauses the sim and opens a compact card:
##   a text box (Enter saves, Shift+Enter newline, Esc cancels), quick tags (Ctrl+1..6, or click), "Pin to entity" (Ctrl+P, then click a
##   thing in the world), default = a state note with no entity. Ctrl+N saves a note at once, no card, no pause (rapid capture).
## Shift+N opens the notes browser (notes_browser.gd). The card never animates on a key press (Emil rule); buttons press at 0.97.
## Not triggered while a text field has focus, the console or the F8 dialog is open, a question card is showing, or the F10 HUD is open.
## What it saves is note_store.gd's folder: note.json (primigenia.note/1 + "meta" + origin), screenshot.jpg, crop.jpg, scenario.*.
## All decisions live in plain functions (begin, commit, cancel, quick, handle_key) so tests drive them without a window.

const Palette := preload("res://ui/palette.gd")
const Scrim := preload("res://devtools/scrim.gd")
const Store := preload("res://devtools/notes/note_store.gd")
const Meta := preload("res://devtools/notes/note_meta.gd")
const Scenario := preload("res://devtools/scenario.gd")
const Flag := preload("res://devtools/notes/flag_mode.gd")

signal saved(id: String)
signal closed

const CARD_W := 560
const TOAST_HOLD := 1.4
const TOAST_FADE := 0.2        # ease-out, under the 250 ms ceiling
const PRESS_SCALE := 0.97

var is_open := false
var pinning := false
var base_dir := ""                       # tests point it elsewhere
var image_provider: Callable = Callable()   # () -> Image, tests (headless has no frame to grab)
var shot: Image = null                   # the frame grabbed when N was pressed
var meta: Dictionary = {}                # collected at that same instant
var tags: Array = []                     # toggled quick tags
var target: Dictionary = {}              # {} = a state note, else a note_pick result
var last_saved := ""                     # id of the last note written
var last_dir := ""
var last_error := ""
var _was_paused := false
var _text: TextEdit
var _title: Label
var _hint: Label
var _pin_label: Label
var _thumb: TextureRect
var _panel: PanelContainer
var _tag_buttons: Array = []
var _toast: Label
var _toast_tween: Tween
var _pin_tip: Label

func _init() -> void:
	layer = 36

func _ready() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.make_theme()
	add_child(root)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Scrim.box(12, 12))
	_panel.custom_minimum_size = Vector2(CARD_W, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_bottom = -26
	_panel.visible = false
	root.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	_panel.add_child(box)
	_title = Scrim.readable(Label.new())
	_title.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_thumb = TextureRect.new()
	_thumb.custom_minimum_size = Vector2(160, 90)
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_thumb)
	_text = TextEdit.new()
	_text.placeholder_text = "what is wrong, odd or good right now?"
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.custom_minimum_size = Vector2(0, 90)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_text)
	var tag_row := HFlowContainer.new()
	tag_row.add_theme_constant_override("h_separation", 6)
	box.add_child(tag_row)
	for i in Store.QUICK_TAGS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s  %d" % [Store.QUICK_TAGS[i], i + 1]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 13)
		b.toggled.connect(func(on: bool): _tag_toggled(i, on))
		_press_feel(b)
		tag_row.add_child(b)
		_tag_buttons.append(b)
	var pin_row := HBoxContainer.new()
	pin_row.add_theme_constant_override("separation", 10)
	box.add_child(pin_row)
	var pin := Button.new()
	pin.text = "Pin to entity  Ctrl+P"
	pin.focus_mode = Control.FOCUS_NONE
	pin.add_theme_font_size_override("font_size", 13)
	pin.pressed.connect(start_pin)
	_press_feel(pin)
	pin_row.add_child(pin)
	_pin_label = Scrim.readable(Label.new())
	_pin_label.add_theme_font_size_override("font_size", 13)
	_pin_label.add_theme_color_override("font_color", Palette.FOG)
	pin_row.add_child(_pin_label)
	_hint = Scrim.readable(Label.new())
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Palette.FOG)
	_hint.text = "Enter saves   Shift+Enter new line   Ctrl+1-6 tags   Esc cancels"
	box.add_child(_hint)
	_toast = Scrim.readable(Label.new())
	_toast.add_theme_font_size_override("font_size", 17)
	_toast.add_theme_color_override("font_color", Palette.LICHEN)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_toast.offset_bottom = -34
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)
	_pin_tip = Scrim.readable(Label.new())
	_pin_tip.add_theme_font_size_override("font_size", 15)
	_pin_tip.visible = false
	_pin_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pin_tip)
	set_process(false)

## Mouse press feel (Emil): 0.97 while held, back with ease-out. Keyboard never animates.
func _press_feel(b: Button) -> void:
	b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
	b.button_down.connect(func(): b.scale = Vector2(PRESS_SCALE, PRESS_SCALE))
	b.button_up.connect(func():
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))

# --- gate ------------------------------------------------------------------------------------------------

## True when a text field has the keyboard (a LineEdit or TextEdit with focus).
func typing_in_field() -> bool:
	var vp := get_viewport() if is_inside_tree() else null
	var f: Control = vp.gui_get_focus_owner() if vp != null else null
	return f != null and (f is LineEdit or f is TextEdit) and f.is_visible_in_tree() and (f.editable if "editable" in f else true)

## Why N would do nothing right now, or "".
func blocked_reason() -> String:
	if not Dev.enabled:
		return "dev tools are off"
	if is_open:
		return "the card is open"
	if Game.console_open:
		return "the console or the F8 dialog has the keyboard"
	if typing_in_field():
		return "typing in a text field"
	if Dev.questions != null and Dev.questions.is_active():
		return "a question card has focus"
	if Dev.flag != null and (Dev.flag.box_open or Dev.flag.active):
		return "flag mode is active"
	if Dev.options_hud != null and Dev.options_hud.is_open:
		return "the F10 HUD is open"
	if Dev.browser != null and Dev.browser.is_open:
		return "the notes browser is open"
	return ""

# --- the card --------------------------------------------------------------------------------------------

func store_dir() -> String:
	return base_dir if base_dir != "" else Store.notes_dir()

func _grab() -> Image:
	if image_provider.is_valid():
		return image_provider.call()
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return null
	var img := get_viewport().get_texture().get_image()
	return img if img != null and not img.is_empty() else null

## Opens the card. Returns false (and does nothing) when blocked. The grab comes first, before any UI appears.
func begin() -> bool:
	if blocked_reason() != "":
		return false
	shot = _grab()
	meta = Meta.collect(get_tree() if is_inside_tree() else null)
	tags = []
	target = {}
	last_error = ""
	is_open = true
	pinning = false
	var st = Game.stage
	_was_paused = st != null and bool(st.paused)
	if st != null:
		st.paused = true
	Game.options_open = true
	if _panel != null:
		_refresh_card()
		_panel.visible = true
		_text.text = ""
		_text.grab_focus()
	return true

func _refresh_card() -> void:
	_title.text = "Note   %s   tick %s   %s%s" % [str(meta.get("mode", "?")), str(meta.get("tick", "-")),
		str(meta.get("build", {}).get("commit", "")), "+dirty" if bool(meta.get("build", {}).get("dirty", false)) else ""]
	_pin_label.text = ("pinned: %s" % str(target.get("name", "?"))) if not target.is_empty() else "state note, no entity"
	for i in _tag_buttons.size():
		_tag_buttons[i].set_pressed_no_signal(tags.has(Store.QUICK_TAGS[i]))
	if shot != null and _thumb != null:
		_thumb.texture = ImageTexture.create_from_image(shot)
	elif _thumb != null:
		_thumb.texture = null

func _tag_toggled(i: int, on: bool) -> void:
	var t: String = Store.QUICK_TAGS[i]
	if on and not tags.has(t):
		tags.append(t)
	elif not on:
		tags.erase(t)

func toggle_tag(i: int) -> void:
	if i < 0 or i >= Store.QUICK_TAGS.size():
		return
	var t: String = Store.QUICK_TAGS[i]
	if tags.has(t):
		tags.erase(t)
	else:
		tags.append(t)
	if _panel != null:
		_refresh_card()

func _release() -> void:
	is_open = false
	pinning = false
	var st = Game.stage
	if st != null:
		st.paused = _was_paused
	Game.options_open = (Dev.options_hud != null and Dev.options_hud.is_open) or (Dev.flag != null and Dev.flag.active)
	if _panel != null:
		_panel.visible = false
		_pin_tip.visible = false
		_text.release_focus()
	set_process(false)
	shot = null
	closed.emit()

## Esc: nothing is written.
func cancel() -> void:
	if is_open:
		_release()

## Enter: writes the note. Returns "" or an error sentence (the card stays open on an error).
func commit(text := "") -> String:
	if not is_open:
		return "the card is not open"
	var t := text if text != "" else (_text.text.strip_edges() if _text != null else "")
	var err := write_note(t.strip_edges(), tags.duplicate(), target, "n")
	if err == "":
		_release()
		_show_toast("Note saved  #%s" % last_saved)
	else:
		last_error = err
		if _hint != null:
			_hint.text = err
	return err

## Ctrl+N: a note with screenshot and meta, no text, no card, no pause.
func quick() -> String:
	if blocked_reason() != "":
		return blocked_reason()
	shot = _grab()
	meta = Meta.collect(get_tree() if is_inside_tree() else null)
	var err := write_note("", [], {}, "quick")
	shot = null
	if err == "":
		_show_toast("Quick note saved  #%s" % last_saved)
	return err

## The files. Uses `shot` and `meta` captured when N was pressed. Returns "" or an error sentence; the id is in last_saved.
func write_note(text: String, ntags: Array, tg: Dictionary, origin: String) -> String:
	var st = Game.stage
	var scene := get_tree().current_scene if is_inside_tree() else null
	var pos := Vector3.ZERO
	var pl: Dictionary = meta.get("player", {})
	if tg.has("pos"):
		pos = tg.pos
	elif pl.has("pos"):
		pos = Vector3(pl.pos[0], pl.pos[1], pl.pos[2])
	var target_d := tg if not tg.is_empty() else {"kind": "state", "id": -1, "species": "", "part": "", "name": "state (%s)" % str(meta.get("mode", "?"))}
	var cam_pose: Dictionary = meta.get("camera", {})
	var note := Store.make(text, ntags, 2, target_d, pos, {"tick": int(meta.get("tick", 0)), "hour": float(meta.get("hour", 0.0)), "camera": cam_pose,
		"options": meta.get("options", {}), "build": str(meta.get("build", {}).get("text", "unknown")), "meta": meta, "origin": origin})
	var dir := Store.write(store_dir(), note)
	if dir == "":
		return "could not write the note under " + store_dir()
	if shot != null:
		shot.save_jpg(dir.path_join("screenshot.jpg"), 0.9)
		var centre := Vector2(shot.get_width() * 0.5, shot.get_height() * 0.5)
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if not tg.is_empty() and cam != null and not cam.is_position_behind(pos):
			centre = cam.unproject_position(pos)
		shot.get_region(Flag.crop_rect(centre, shot.get_size())).save_jpg(dir.path_join("crop.jpg"), 0.9)
	if st != null and scene != null and scene.has_method("scenario_ctx"):
		var err := Scenario.save(st, scene.scenario_ctx(), dir.path_join("scenario"), "note", text)
		if err != "":
			push_warning("note scenario: " + err)
		else:
			note["meta"]["scenario"] = "scenario.json"
			Store.save_edit(store_dir(), note)
	last_saved = str(note.id)
	last_dir = dir
	saved.emit(last_saved)
	if Dev.flag != null:
		Dev.flag.reload()
	return ""

func _show_toast(msg: String) -> void:
	if _toast == null:
		return
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.text = msg
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_HOLD)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

# --- pin to entity ---------------------------------------------------------------------------------------

func start_pin() -> void:
	if not is_open or pinning or Dev.flag == null:
		return
	pinning = true
	if _panel != null:
		_panel.visible = false
		_text.release_focus()
		_pin_tip.visible = true
		set_process(true)

func _pin_cancel() -> void:
	pinning = false
	if _panel != null:
		_panel.visible = true
		_pin_tip.visible = false
		_text.grab_focus()
	set_process(false)

## Takes the pick under `screen` as the target. Returns false when there is nothing there.
func pin_at(screen: Vector2) -> bool:
	var pk: Dictionary = Dev.flag.pick_at(screen) if Dev.flag != null else {}
	if pk.is_empty():
		return false
	target = pk
	pinning = false
	if _panel != null:
		_refresh_card()
		_panel.visible = true
		_pin_tip.visible = false
		_text.grab_focus()
		set_process(false)
	return true

func _process(_dt: float) -> void:
	if pinning and is_inside_tree():
		var m := get_viewport().get_mouse_position()
		var pk: Dictionary = Dev.flag.pick_at(m) if Dev.flag != null else {}
		_pin_tip.text = ("%s: %s   (click to pin)" % [pk.kind, pk.name]) if not pk.is_empty() else "click a creature, plant or prop   Esc back"
		_pin_tip.position = m + Vector2(16, 14)

# --- keys ------------------------------------------------------------------------------------------------

func _code(e: InputEventKey) -> int:
	return e.physical_keycode if e.physical_keycode != 0 else e.keycode

## One key press. Returns true when it was used (the caller then marks the event handled).
func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo:
		return false
	var code := _code(e)
	if is_open:
		if pinning:
			if code == KEY_ESCAPE:
				_pin_cancel()
				return true
			return true      # the world is paused and frozen: eat the rest while picking
		if code == KEY_ESCAPE:
			cancel()
			return true
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			if e.shift_pressed:
				return false      # the TextEdit inserts the newline
			commit()
			return true
		if e.ctrl_pressed and code >= KEY_1 and code <= KEY_6:
			toggle_tag(code - KEY_1)
			return true
		if e.ctrl_pressed and code == KEY_P:
			start_pin()
			return true
		return false
	if code != KEY_N or e.alt_pressed or e.meta_pressed:
		return false
	if e.ctrl_pressed and not e.shift_pressed:
		return quick() == ""
	if e.shift_pressed or e.ctrl_pressed:
		return false      # Shift+N is the browser
	return begin()

func _input(e: InputEvent) -> void:
	if not Dev.enabled:
		return
	if e is InputEventKey:
		if handle_key(e):
			get_viewport().set_input_as_handled()
	elif pinning and e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			pin_at(e.position)
		get_viewport().set_input_as_handled()
