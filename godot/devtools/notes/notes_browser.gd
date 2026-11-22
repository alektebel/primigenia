extends CanvasLayer
## Notes browser (Shift+N): every saved note with a thumbnail, its text, tags and time. Pick one to see its screenshot and metadata,
## reload its scenario ("Load this moment", L) or close it (D marks it done). The sim is paused while it is open, like the N card.
## Keys: Up/Down select, L load the moment, D done, Esc closes. Opens and closes instantly (keyboard action, no animation).
## Plain functions (open, close, select, load_moment, mark_done) so tests drive it without a window.

const Palette := preload("res://ui/palette.gd")
const Scrim := preload("res://devtools/scrim.gd")
const Store := preload("res://devtools/notes/note_store.gd")
const Meta := preload("res://devtools/notes/note_meta.gd")
const Scenario := preload("res://devtools/scenario.gd")

const MAX_ROWS := 80
const THUMB := Vector2i(96, 54)
const THUMBS_PER_FRAME := 3
const PRESS_SCALE := 0.97

var is_open := false
var base_dir := ""
var rows: Array = []            # note.json dictionaries, newest first
var index := -1
var show_done := false
var last_error := ""
var loaded_scenario := ""       # path of the last scenario this browser asked the island to load
var scenario_loader: Callable = Callable()   # (parsed) -> error String; tests, else the current scene's load_scenario
var _was_paused := false
var _root: Control
var _list: VBoxContainer
var _row_nodes: Array = []
var _thumbs: Array = []         # [{rect, path}] waiting for their image
var _shot: TextureRect
var _head: Label
var _text: Label
var _meta: Label
var _status: Label
var _scroll: ScrollContainer

func _init() -> void:
	layer = 37

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = Palette.make_theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(Palette.INK, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Scrim.box(14, 14))
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 32
	panel.offset_bottom = -32
	_root.add_child(panel)
	var outer := VBoxContainer.new()
	panel.add_child(outer)
	_head = Scrim.readable(Label.new())
	_head.add_theme_color_override("font_color", Palette.GOLD)
	_head.add_theme_font_size_override("font_size", 20)
	outer.add_child(_head)
	var split := HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 14)
	outer.add_child(split)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(360, 0)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	split.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	split.add_child(right)
	_shot = TextureRect.new()
	_shot.custom_minimum_size = Vector2(0, 250)
	_shot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	right.add_child(_shot)
	_text = Scrim.readable(Label.new())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 17)
	right.add_child(_text)
	var ms := ScrollContainer.new()
	ms.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(ms)
	_meta = Scrim.readable(Label.new())
	_meta.add_theme_font_size_override("font_size", 12)
	_meta.add_theme_color_override("font_color", Palette.FOG)
	ms.add_child(_meta)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	right.add_child(buttons)
	for spec in [["Load this moment  L", "load"], ["Mark done  D", "done"], ["Close  Esc", "close"]]:
		var b := Button.new()
		b.text = spec[0]
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 14)
		b.pivot_offset = Vector2(60, 16)
		b.button_down.connect(func(): b.scale = Vector2(PRESS_SCALE, PRESS_SCALE))
		b.button_up.connect(func():
			var tw := b.create_tween()
			tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC))
		b.pressed.connect(func(): _button(spec[1]))
		buttons.add_child(b)
	_status = Scrim.readable(Label.new())
	_status.add_theme_font_size_override("font_size", 12)
	_status.add_theme_color_override("font_color", Palette.COPPER)
	outer.add_child(_status)
	set_process(false)

func _button(which: String) -> void:
	match which:
		"load":
			load_moment()
		"done":
			mark_done()
		"close":
			close()

func store_dir() -> String:
	return base_dir if base_dir != "" else Store.notes_dir()

func reload() -> void:
	rows = Store.list(store_dir(), not show_done).slice(0, MAX_ROWS)
	index = clampi(index, 0, rows.size() - 1) if not rows.is_empty() else -1
	_rebuild()

func open() -> bool:
	if is_open or not Dev.enabled or Game.console_open:
		return false
	if Dev.note_card != null and (Dev.note_card.is_open or Dev.note_card.typing_in_field()):
		return false
	if Dev.questions != null and Dev.questions.is_active():
		return false
	is_open = true
	var st = Game.stage
	_was_paused = st != null and bool(st.paused)
	if st != null:
		st.paused = true
	Game.options_open = true
	last_error = ""
	index = 0
	reload()
	if _root != null:
		_root.visible = true
		set_process(true)
	return true

func close() -> void:
	if not is_open:
		return
	is_open = false
	var st = Game.stage
	if st != null:
		st.paused = _was_paused
	Game.options_open = (Dev.options_hud != null and Dev.options_hud.is_open) or (Dev.flag != null and Dev.flag.active)
	if _root != null:
		_root.visible = false
	_thumbs.clear()
	set_process(false)

func current() -> Dictionary:
	return rows[index] if index >= 0 and index < rows.size() else {}

func note_dir(n: Dictionary) -> String:
	return store_dir().path_join(Store.folder_name(n))

func select(i: int) -> void:
	if rows.is_empty():
		index = -1
	else:
		index = clampi(i, 0, rows.size() - 1)
	_show_detail()

func toggle_done_filter() -> void:
	show_done = not show_done
	reload()

## "Wed 21:04" style stamp for a row from the stamp "20261121-210403".
static func when(n: Dictionary) -> String:
	var s := str(n.stamp)
	return "%s-%s-%s %s:%s" % [s.substr(0, 4), s.substr(4, 2), s.substr(6, 2), s.substr(9, 2), s.substr(11, 2)] if s.length() >= 13 else s

static func row_text(n: Dictionary) -> String:
	var t := str(n.text).strip_edges().replace("\n", " ")
	if t == "":
		t = "(no text)"
	var tg := ",".join(PackedStringArray(n.tags)) if not n.tags.is_empty() else "-"
	return "%s\n[%s]  %s" % [t.left(60), tg, when(n)]

## Reloads the scenario of the selected note into the running island. Returns "" or an error sentence.
func load_moment() -> String:
	var n := current()
	if n.is_empty():
		return _say("no note selected")
	var path := note_dir(n).path_join("scenario.json")
	if not FileAccess.file_exists(path):
		return _say("this note has no scenario (saved outside the island)")
	var parsed := Scenario.read(path)
	if not parsed.ok:
		return _say(str(parsed.error))
	loaded_scenario = path
	var err := ""
	if scenario_loader.is_valid():
		err = scenario_loader.call(parsed)
	else:
		var scene := get_tree().current_scene if is_inside_tree() else null
		err = scene.load_scenario(parsed) if scene != null and scene.has_method("load_scenario") else "the current scene cannot load a scenario"
	if err != "":
		return _say(err)
	_say("loaded the moment of #%s" % str(n.id))
	return ""

func mark_done() -> String:
	var n := current()
	if n.is_empty():
		return ""
	var err := Store.mark_done(store_dir(), str(n.id))
	reload()
	if Dev.flag != null:
		Dev.flag.reload()
	return _say(err) if err != "" else ""

func _say(msg: String) -> String:
	last_error = msg
	if _status != null:
		_status.text = msg
	return msg

# --- drawing ---------------------------------------------------------------------------------------------

func _rebuild() -> void:
	if _list == null:
		return
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_row_nodes.clear()
	_thumbs.clear()
	_head.text = "Notes   %d %s   (Shift+N)%s" % [rows.size(), "saved" if show_done else "open", "   showing done too" if show_done else ""]
	for i in rows.size():
		var n: Dictionary = rows[i]
		var row := PanelContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(h)
		var th := TextureRect.new()
		th.custom_minimum_size = Vector2(THUMB)
		th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		th.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(th)
		var l := Label.new()
		l.text = row_text(n)
		l.add_theme_font_size_override("font_size", 13)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220, 0)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(l)
		var ii := i
		row.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				select(ii))
		_list.add_child(row)
		_row_nodes.append(row)
		_thumbs.append({"rect": th, "path": note_dir(n).path_join("screenshot.jpg")})
	_show_detail()

func _row_style(selected: bool) -> StyleBoxFlat:
	return Palette.box(Color(Palette.PANEL_ACTIVE, 0.8) if selected else Color(Palette.INK, 0.35), 8, Palette.GOLD if selected else Palette.BORDER, 4)

func _show_detail() -> void:
	if _list == null:
		return
	for i in _row_nodes.size():
		_row_nodes[i].add_theme_stylebox_override("panel", _row_style(i == index))
	if index >= 0 and index < _row_nodes.size():
		_scroll.ensure_control_visible(_row_nodes[index])
	var n := current()
	if n.is_empty():
		_shot.texture = null
		_text.text = "No notes yet. Press N to leave one."
		_meta.text = ""
		return
	var p := note_dir(n).path_join("screenshot.jpg")
	_shot.texture = _load_tex(p, Vector2i(960, 540))
	_text.text = "%s\n#%s   %s   %s   %s%s" % [str(n.text) if str(n.text) != "" else "(no text)", n.id, when(n), ",".join(PackedStringArray(n.tags)),
		str(n.target.kind), ("  [done: %s]" % n.fix) if n.status == "done" else ""]
	var m: Dictionary = n.get("meta", {})
	_meta.text = "\n".join(Meta.lines(m)) if not m.is_empty() else "(an older note: no metadata)\ntick %s  %s" % [str(int(n.tick)), str(n.build)]
	_status.text = last_error

static func _load_tex(path: String, fit: Vector2i) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(path)
	if img == null or img.is_empty():
		return null
	if img.get_width() > fit.x:
		img.resize(fit.x, int(img.get_height() * float(fit.x) / img.get_width()), Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)

func _process(_dt: float) -> void:
	var n := 0
	while n < THUMBS_PER_FRAME and not _thumbs.is_empty():
		var t: Dictionary = _thumbs.pop_front()
		if is_instance_valid(t.rect):
			t.rect.texture = _load_tex(t.path, Vector2i(THUMB.x * 2, THUMB.y * 2))
		n += 1

func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo:
		return false
	var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if not is_open:
		if code == KEY_N and e.shift_pressed and not e.ctrl_pressed and not e.alt_pressed and not e.meta_pressed:
			return open()
		return false
	match code:
		KEY_ESCAPE:
			close()
		KEY_UP:
			select(index - 1)
		KEY_DOWN:
			select(index + 1)
		KEY_L:
			load_moment()
		KEY_D:
			mark_done()
		KEY_A:
			toggle_done_filter()
		_:
			pass
	return true     # modal: the rest of the keys do nothing

func _input(e: InputEvent) -> void:
	if not Dev.enabled or not (e is InputEventKey):
		return
	if not is_open and Dev.note_card != null and (Dev.note_card.typing_in_field() or Dev.note_card.is_open):
		return
	if handle_key(e):
		get_viewport().set_input_as_handled()
