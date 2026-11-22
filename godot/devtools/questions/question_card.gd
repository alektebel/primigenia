extends CanvasLayer
## Owner questions inside the game (docs/briefs/owner-questions.md). A small card at the bottom right while playing, never modal.
##   1-4 answer   T free text (Enter saves, Esc backs out)   Tab shows the thing it asks about (again: puts it back)
##   N adds a note (the Shift+F8 box, pre-tagged with the question id)   L answer later   Esc dismisses it for this session
## One card at a time and at most one every 3 minutes unless the question is `when: now` (question_store.gd pick_next). Game input is
## suspended (Game.options_open) only while typing. The pause menu's "Questions" entry opens the list (open_list): a number picks one.
## All decisions live in handle_key() / commit() / tick() so tests drive them without a window.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Store := preload("res://devtools/questions/question_store.gd")
const Scrim := preload("res://devtools/scrim.gd")
const Scenario := preload("res://devtools/scenario.gd")

signal answered(id: String)
signal list_closed

const POLL_SEC := 1.0
const FADE_SEC := 0.16

var base_dir := ""                   # tests point it elsewhere
var open: Array = []                 # unanswered questions on disk
var current: Dictionary = {}         # the card on screen, or {}
var list_mode := false               # the pause-menu list is showing
var typing := false
var events: Dictionary = {}          # fired event names
var dismissed: Dictionary = {}       # ids hidden for this session
var session_sec := 0.0
var last_shown := -1.0
var previewing := false
var message := ""
var note_mark := ""                  # flag.last_saved when the note box was opened for this card
var note_asked := false
var from_list := false               # the card was picked from the list: Esc and L go back to it
var _prev_opts: Dictionary = {}
var _poll := 0.0
var _mtime := -1
var _root: Control
var _panel: PanelContainer
var _box: VBoxContainer
var _edit: LineEdit
var _hold_opts := false              # we hold Game.options_open

func _init() -> void:
	layer = 34

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Palette.make_diegetic_theme()
	add_child(_root)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", Scrim.box(12, 12))
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_right = -16
	_panel.offset_bottom = -44
	_panel.visible = false
	_root.add_child(_panel)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 4)
	_panel.add_child(_box)
	_edit = LineEdit.new()
	_edit.placeholder_text = "your answer"
	_edit.visible = false
	_box.add_child(_edit)
	_refresh()

# --- model ---------------------------------------------------------------------------------------------

func store_dir() -> String:
	return base_dir if base_dir != "" else Store.questions_dir()

func reload() -> void:
	open = Store.open_questions(store_dir())
	var p := Store.pending_path(store_dir())
	_mtime = FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
	if not current.is_empty() and Store.find(open, current.id).is_empty():
		current = {}                   # answered elsewhere (questions.py)
		_after_close()

## Pending questions the pause list shows (those hidden this session still count: the owner can answer them there).
func pending() -> Array:
	return open

func pending_count() -> int:
	return open.size()

func notify_event(name: String) -> void:
	events[name] = true

## Shows a question now, whatever the timing rules say (the Tab-less path of `ask <id>` and the pause list).
func ask(id: String) -> String:
	reload()
	var q := Store.find(open, id)
	if q.is_empty():
		return "no pending question '%s'" % id
	_show(q)
	return ""

func _show(q: Dictionary) -> void:
	_end_typing()
	current = q
	list_mode = false
	previewing = false
	message = ""
	note_mark = ""
	note_asked = false
	last_shown = session_sec
	_refresh()

func hide_card() -> void:
	if previewing:
		_unpreview()
	_end_typing()
	current = {}
	_after_close()

func _after_close() -> void:
	if from_list and list_mode == false and not open.is_empty():
		list_mode = true
	else:
		if list_mode and open.is_empty():
			list_mode = false
			list_closed.emit()
	_refresh()

func dismiss() -> void:
	if current.is_empty():
		return
	dismissed[current.id] = true
	hide_card()

func later() -> void:
	# answer later: it stays pending and the pacing starts over
	last_shown = session_sec
	hide_card()

## Called every frame by _process and by tests: advances the clock and pops the next card when the rules allow.
func tick(dt: float, can_show := true) -> void:
	session_sec += dt
	_poll += dt
	if _poll < POLL_SEC:
		return
	_poll = 0.0
	var p := Store.pending_path(store_dir())
	var mt := FileAccess.get_modified_time(p) if FileAccess.file_exists(p) else -1
	if mt != _mtime or open.is_empty() and mt >= 0:
		reload()
	if not can_show or not current.is_empty() or list_mode:
		return
	var q := Store.pick_next(open, {"now": session_sec, "last_shown": last_shown, "showing": false, "dismissed": dismissed,
		"session_sec": session_sec, "events": events})
	if not q.is_empty():
		_show(q)

func _can_show() -> bool:
	return Dev.enabled and Game.stage != null and not Game.paused_ui and not Game.console_open and not Game.options_open

# --- answering -------------------------------------------------------------------------------------------

## Writes the answer line (option is 1-based; 0 with text for a free answer). Takes the screenshot first when there is a window.
func commit(option: int, text := "") -> String:
	if current.is_empty():
		return "no card"
	var q := current
	var shot := ""
	if is_inside_tree() and DisplayServer.get_name() != "headless":
		_panel.visible = false
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null:
			var dir := store_dir().path_join("shots")
			DirAccess.make_dir_recursive_absolute(dir)
			shot = "shots/%s.jpg" % q.id
			img.save_jpg(store_dir().path_join(shot), 0.9)
	var st = Game.stage
	var dev := get_node_or_null("/root/Dev")
	var opts: Dictionary = dev.tuning.current_choices() if dev != null and dev.tuning != null else {}
	var note := ""
	if note_asked and Dev.flag != null and Dev.flag.last_saved != "" and Dev.flag.last_saved != note_mark:
		note = Dev.flag.last_saved
	var ans := Store.make_answer(q, option, text, {"tick": int(st.cur.tick) if st != null else 0, "options": opts, "screenshot": shot, "note": note})
	if not Store.append_answer(store_dir(), ans):
		_panel.visible = true
		message = "could not write the answer under " + store_dir()
		_refresh()
		return message
	last_shown = session_sec
	open = open.filter(func(x): return x.id != q.id)
	hide_card()
	answered.emit(str(q.id))
	return ""

func answer_option(i: int) -> String:
	if current.is_empty() or i < 1 or i > current.options.size():
		return "no option %d" % i
	return await commit(i)

func start_typing() -> void:
	if current.is_empty() or not bool(current.allow_free_text):
		return
	typing = true
	_edit.visible = true
	_edit.text = ""
	if not Game.options_open:
		Game.options_open = true
		_hold_opts = true
	_refresh()
	if is_inside_tree():
		_edit.grab_focus()

func _end_typing() -> void:
	if typing:
		typing = false
		_edit.release_focus()
		_edit.text = ""
	if _hold_opts:
		Game.options_open = Dev.options_hud != null and Dev.options_hud.is_open or Dev.flag != null and Dev.flag.active
		_hold_opts = false
	if _edit != null:
		_edit.visible = false

func submit_text(text := "") -> String:
	var t := (text if text != "" else _edit.text).strip_edges()
	if t == "":
		message = "write a line first"
		_refresh()
		return message
	_end_typing()
	return await commit(0, t)

# --- showing the thing ----------------------------------------------------------------------------------

## Tab: load the question's `where` (a scenario, F10 options, a spot). Again: put the options back.
func preview() -> String:
	if current.is_empty():
		return "no card"
	var w: Dictionary = current.where
	if w.is_empty():
		message = "nothing to show for this one"
		_refresh()
		return message
	if previewing:
		_unpreview()
		return ""
	var err := ""
	if w.has("scenario"):
		var isl := get_tree().current_scene if is_inside_tree() else null
		if isl == null or not isl.has_method("load_scenario"):
			err = "the island is not running"
		else:
			var parsed := Scenario.read(Scenario.resolve(str(w.scenario)))
			err = str(parsed.error) if not parsed.ok else isl.load_scenario(parsed)
	if err == "" and w.has("pos") and w.pos is Array and w.pos.size() >= 2:
		var r: Dictionary = Dev.console.registry.execute("tp %s %s" % [str(w.pos[0]), str(w.pos[1])])
		err = "" if r.ok else str(r.error)
	if err == "" and w.has("opts") and typeof(w.opts) == TYPE_DICTIONARY:
		var tn = Dev.tuning
		_prev_opts = {}
		for k in w.opts:
			var key: String = tn.resolve_key(str(k))
			if key != "" and key != "?" and tn.is_choice(key):
				_prev_opts[key] = tn.choice_value(key)
			var e: String = tn.set_option(str(k), str(w.opts[k]))
			if e != "":
				err = e
				break
	previewing = err == ""
	message = err if err != "" else "showing it (Tab puts it back)"
	_refresh()
	return err

func _unpreview() -> void:
	previewing = false
	if Dev.tuning != null:
		for k in _prev_opts:
			Dev.tuning.set_option(str(k), str(_prev_opts[k]))
	_prev_opts = {}
	message = ""
	_refresh()

## N: the note box of flag mode, tagged with the question id.
func open_note() -> void:
	if current.is_empty() or Dev.flag == null:
		return
	note_mark = Dev.flag.last_saved
	note_asked = true
	Dev.flag.open_question_note(str(current.id))

# --- list --------------------------------------------------------------------------------------------------

func open_list() -> void:
	reload()
	if current.is_empty():
		list_mode = true
		from_list = true
	_refresh()

func close_list() -> void:
	from_list = false
	if list_mode:
		list_mode = false
		list_closed.emit()
	_refresh()

func is_active() -> bool:
	return list_mode or not current.is_empty()

# --- keys ---------------------------------------------------------------------------------------------------

## One key press. Returns true when used. Typing: only Enter and Esc are ours (the rest goes to the LineEdit).
func handle_key(e: InputEventKey) -> bool:
	if not e.pressed or e.echo:
		return false
	var code: int = e.physical_keycode if e.physical_keycode != 0 else e.keycode
	if typing:
		if code == KEY_ENTER or code == KEY_KP_ENTER:
			submit_text()
			return true
		if code == KEY_ESCAPE:
			_end_typing()
			_refresh()
			return true
		return false
	if e.ctrl_pressed or e.alt_pressed or e.meta_pressed:
		return false
	if current.is_empty():
		if list_mode:
			if code == KEY_ESCAPE:
				close_list()
				return true
			if code >= KEY_F1 and code <= KEY_F12:
				return false
			if code >= KEY_1 and code <= KEY_9:
				var i := code - KEY_1
				if i < open.size():
					_show(open[i])
				return true
			return true
		return false
	match code:
		KEY_1, KEY_2, KEY_3, KEY_4:
			var n := code - KEY_1 + 1
			if n <= current.options.size():
				answer_option(n)
			return true
		KEY_T:
			start_typing()
			return true
		KEY_TAB:
			preview()
			return true
		KEY_N:
			open_note()
			return true
		KEY_L:
			later()
			return true
		KEY_ESCAPE:
			if from_list:
				hide_card()          # back to the list
			else:
				dismiss()
			return true
	return false

# --- drawing --------------------------------------------------------------------------------------------------

func _label(text: String, color: Color, size := 15, italic := false) -> Label:
	var l := Scrim.readable(Label.new())
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(388, 0)
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if italic:
		l.add_theme_font_override("font", Style.font_italic())
	return l

func _refresh() -> void:
	if _box == null:
		return
	for c in _box.get_children():
		if c != _edit:
			_box.remove_child(c)
			c.queue_free()
	var show_it := not current.is_empty() or list_mode
	_panel.visible = show_it
	if not show_it:
		return
	if current.is_empty():
		_build_list()
	else:
		_build_card()

func _add(c: Control) -> void:
	_box.add_child(c)
	if _edit.visible:
		_box.move_child(_edit, _box.get_child_count() - 1)

func _build_list() -> void:
	_add(_label("Questions  (%d pending)" % open.size(), Palette.GOLD, 20, true))
	if open.is_empty():
		_add(_label("Nothing pending.", Palette.FOG, 15, true))
	for i in mini(open.size(), 9):
		_add(_label("%d  %s" % [i + 1, open[i].text], Palette.BONE, 15))
	_add(_label("1-9 open one   Esc close", Palette.FOG, 12, true))

func _build_card() -> void:
	var q := current
	_add(_label("A question for you", Palette.GOLD, 13, true))
	_add(_label(str(q.text), Palette.BONE, 18))
	if str(q.context) != "":
		_add(_label(str(q.context), Palette.FOG, 13, true))
	for i in q.options.size():
		var o: Dictionary = q.options[i]
		var rec := "  (recommended)" if bool(o.recommended) else ""
		var txt := "%d  %s%s" % [i + 1, o.label, rec]
		if str(o.desc) != "":
			txt += "\n     " + str(o.desc)
		_add(_label(txt, Palette.LICHEN if bool(o.recommended) else Palette.BONE, 15))
	var keys := PackedStringArray()
	if bool(q.allow_free_text):
		keys.append("T write")
	if not q.where.is_empty():
		keys.append("Tab show it" if not previewing else "Tab put it back")
	keys.append("N attach a note")
	keys.append("L later")
	keys.append("Esc dismiss")
	if typing:
		_add(_label("Enter saves   Esc back", Palette.FOG, 12, true))
	else:
		_add(_label("   ".join(keys), Palette.FOG, 12, true))
	if message != "":
		_add(_label(message, Palette.COPPER, 13, true))

func _process(dt: float) -> void:
	if not Dev.enabled:
		return
	tick(dt, _can_show())

func _input(e: InputEvent) -> void:
	if not Dev.enabled or not (e is InputEventKey):
		return
	if Dev.flag != null and Dev.flag.box_open:
		return
	if not is_active():
		return
	if Game.console_open:
		return
	if e.pressed and not typing and e.is_action_pressed("dev_console"):
		return
	if e.pressed and not typing and (e.physical_keycode >= KEY_F1 and e.physical_keycode <= KEY_F12):
		return      # dev keys keep working
	var used := handle_key(e)
	if used and is_inside_tree():
		get_viewport().set_input_as_handled()
