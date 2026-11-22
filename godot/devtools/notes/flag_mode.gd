extends CanvasLayer
## Flag mode (DT-NOTE): Shift+F8 (or "Flag something" in the F8 dialog) turns the cursor into a picker. The label under the mouse says
## what is there (creature, plant, prop or artifact, terrain or water); a click opens a one-line note box (Tab cycles the tag, Shift+Tab the
## severity 1-3, Enter saves, Esc cancels) and writes feedback/notes/<stamp>-<id>/ (see note_store.gd). Notes show as pins above their
## target, only in flag mode or when the F10 Overlays "notes" option is on; hover a pin for its text, click it to edit or mark it done
## (Ctrl+D in the box). Game input is suspended with Game.options_open while flag mode is active, like the F10 HUD.
## The logic (pick source, save, pins) is in plain functions so tests drive it without a window.

const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Store := preload("res://devtools/notes/note_store.gd")
const Pick := preload("res://devtools/notes/note_pick.gd")
const Meta := preload("res://devtools/notes/note_meta.gd")
const Scenario := preload("res://devtools/scenario.gd")

const PIN_HIT := 16.0
const CROP := Vector2i(384, 256)
const DAY_TICKS := 12000.0
const TICKS_PER_HOUR := 500.0

var active := false
var pins_overlay := false        # the F10 Overlays "notes" option
var hover: Dictionary = {}       # the pick under the mouse
var notes: Array = []            # open notes (note.json dictionaries)
var base_dir := ""               # tests point it elsewhere
var box_open := false
var editing: Dictionary = {}     # the note being edited, or {}
var target: Dictionary = {}      # target of the note being written
var tag_i := -1                  # -1 none, else index into Store.TAGS
var severity := 2
var last_saved := ""             # id of the last note written
var source_provider: Callable = Callable()   # () -> pick source dictionary (tests)
var _root: Control
var _hover_label: Label
var _panel: PanelContainer
var _edit: LineEdit
var _hint: Label
var _title: Label
var _pin_layer: Control
var _pin_tip := ""
var _q_hold := false             # the box was opened by a question card and holds Game.options_open

func _init() -> void:
	layer = 33

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = Palette.make_diegetic_theme()
	add_child(_root)
	_pin_layer = Control.new()
	_pin_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pin_layer.draw.connect(_draw_pins)
	_root.add_child(_pin_layer)
	_hover_label = Label.new()
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.add_theme_font_size_override("font_size", 15)
	_hover_label.visible = false
	_root.add_child(_hover_label)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL_SOLID, 0.96), 12, Palette.GOLD, 10))
	_panel.custom_minimum_size = Vector2(430, 0)
	_panel.visible = false
	var box := VBoxContainer.new()
	_panel.add_child(box)
	var title := Label.new()
	_title = title
	title.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(title)
	_edit = LineEdit.new()
	_edit.placeholder_text = "what is wrong, odd or good here?"
	box.add_child(_edit)
	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", Palette.FOG)
	box.add_child(_hint)
	_root.add_child(_panel)
	set_process(false)

# --- model ---------------------------------------------------------------------------------------------

func store_dir() -> String:
	return base_dir if base_dir != "" else Store.notes_dir()

func reload() -> void:
	notes = Store.list(store_dir(), true)

func enter() -> void:
	if active or Game.stage == null:
		return
	active = true
	Game.options_open = true
	reload()
	set_process(true)
	_pin_layer.queue_redraw()

func exit() -> void:
	if not active:
		return
	close_box()
	active = false
	Game.options_open = Dev.options_hud != null and Dev.options_hud.is_open
	hover = {}
	_hover_label.visible = false
	set_process(false)
	_pin_layer.queue_redraw()

func pins_visible() -> bool:
	return active or pins_overlay

func set_pins_overlay(on: bool) -> void:
	pins_overlay = on
	if on and notes.is_empty():
		reload()
	set_process(pins_visible())
	if _pin_layer != null:
		_pin_layer.queue_redraw()

func tag_name() -> String:
	return Store.TAGS[tag_i] if tag_i >= 0 else ""

func cycle_tag() -> void:
	tag_i += 1
	if tag_i >= Store.TAGS.size():
		tag_i = -1

func cycle_severity() -> void:
	severity = severity % 3 + 1

## The pick source from the running island.
func source() -> Dictionary:
	if source_provider.is_valid():
		return source_provider.call()
	var scene := get_tree().current_scene
	var st = Game.stage
	var props: Array = []
	if st != null:
		for n in st.cur.get("parts", {}).get("nodes", []):
			props.append({"kind": "node", "id": int(n.id), "name": "find %d" % int(n.id), "x": float(n.x), "z": float(n.z)})
		for n in st.cur.get("recipes", {}).get("stones", []):
			props.append({"kind": "stone", "id": int(n.id), "name": "stone %d" % int(n.id), "x": float(n.x), "z": float(n.z)})
		for n in st.cur.get("shards", {}).get("items", []):
			if not bool(n.found):
				props.append({"kind": "shard", "id": int(n.id), "name": "meteor shard %d" % int(n.id), "x": float(n.x), "z": float(n.z)})
	var species := {}
	for s in CporeWorld.species():
		species[int(s.id)] = str(s.name)
	return {"entities": st.cur.entities if st != null else [], "ground": Callable(Game, "visual_ground"),
		"species_name": func(i): return species.get(i, "species %d" % i), "props": props,
		"records": scene.props.records if scene != null and scene.get("props") != null else [], "gaze": scene.get("gaze") if scene != null else null,
		"water_depth": func(x, z): return st.world.water_depth(x, z) if st != null else 0.0,
		"nest": scene.get("_nest") if scene != null and scene.get("_nest") is Vector2 and scene.get("_nest") != Vector2.ZERO else null}

func pick_at(screen: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	return Pick.pick(cam.project_ray_origin(screen), cam.project_ray_normal(screen), source())

## World position of a note's pin: a creature target follows its body, anything else stays where it was.
static func pin_world(note: Dictionary, entities: Array, ground: Callable) -> Vector3:
	var tg: Dictionary = note.target
	var p := Vector3(note.pos[0], note.pos[1], note.pos[2])
	if str(tg.kind) == "creature" and int(tg.id) >= 0 and int(tg.id) < entities.size():
		var e: Dictionary = entities[int(tg.id)]
		if not bool(e.get("dead", false)):
			var r: float = maxf(0.6, float(e.get("radius_cm", 60)) / 100.0)
			return Vector3(e.x, ground.call(e.x, e.z) + r * 2.0, e.z)
	return p + Vector3(0, 1.2, 0)

func _pin_screen(note: Dictionary) -> Variant:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return null
	var st = Game.stage
	var w := pin_world(note, st.cur.entities if st != null else [], Callable(Game, "visual_ground"))
	if cam.is_position_behind(w):
		return null
	return cam.unproject_position(w)

func pin_at(screen: Vector2) -> Dictionary:
	if not pins_visible():
		return {}
	for n in notes:
		var s = _pin_screen(n)
		if s != null and (s as Vector2).distance_to(screen) <= PIN_HIT:
			return n
	return {}

## Opens the note box for a new note on `tg` (or, with `existing`, to edit it).
func open_box(tg: Dictionary, existing := {}) -> void:
	if tg.is_empty() and existing.is_empty():
		return
	box_open = true
	editing = existing
	target = tg
	tag_i = Store.TAGS.find(existing.tags[0]) if not existing.is_empty() and not existing.tags.is_empty() else -1
	severity = int(existing.severity) if not existing.is_empty() else 2
	_edit.text = str(existing.text) if not existing.is_empty() else ""
	_panel.visible = true
	_update_box()
	if is_inside_tree():
		var vs := get_viewport().get_visible_rect().size
		var m := get_viewport().get_mouse_position()
		_panel.position = Vector2(clampf(m.x + 24.0, 12.0, maxf(12.0, vs.x - 450.0)), clampf(m.y + 24.0, 12.0, maxf(12.0, vs.y - 110.0)))
	_edit.grab_focus()

## The note box on the player's creature, pre-filled with "[q <id>] " (the owner-question card's N key). Game input is suspended until it closes.
func open_question_note(qid: String) -> void:
	var st = Game.stage
	if st == null:
		return
	var p: Dictionary = st.cur.entities[0]
	var tg := {"kind": "creature", "id": 0, "species": "player", "part": "", "name": "player #0",
		"pos": Vector3(float(p.x), float(Game.visual_ground(float(p.x), float(p.z))), float(p.z))}
	open_box(tg)
	_edit.text = "[q %s] " % qid
	_edit.caret_column = _edit.text.length()
	if not Game.options_open:
		Game.options_open = true
		_q_hold = true

func close_box() -> void:
	if _q_hold:
		_q_hold = false
		Game.options_open = (Dev.options_hud != null and Dev.options_hud.is_open) or active
	box_open = false
	editing = {}
	_panel.visible = false
	_edit.release_focus()

func _update_box() -> void:
	var t: Dictionary = target if editing.is_empty() else editing.target
	_title.text = "%s %s: %s" % ["Edit note on" if not editing.is_empty() else "Note on", t.get("kind", "?"), t.get("name", "?")]
	_hint.text = "tag [%s] (Tab)   severity %d (Shift+Tab)   Enter saves   Esc cancels%s" % [tag_name() if tag_name() != "" else "none", severity,
		"   Ctrl+D done" if not editing.is_empty() else ""]

## Writes the note. Returns "" or an error sentence; the id is in last_saved.
func save_note(text: String, tags: Array, sev: int, tg: Dictionary, with_images := true) -> String:
	var st = Game.stage
	var scene := get_tree().current_scene if is_inside_tree() else null
	var pos: Vector3 = tg.get("pos", Vector3.ZERO)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_pose := {}
	if scene != null and scene.has_method("camera_state"):
		cam_pose = scene.camera_state().duplicate()
	if cam != null:
		var p := cam.global_position
		cam_pose["pos"] = [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]
		cam_pose["fov"] = cam.fov
	var tick := int(st.cur.tick) if st != null else 0
	var dev := get_node_or_null("/root/Dev")
	var opts: Dictionary = dev.tuning.current_choices() if dev != null and dev.tuning != null else {}
	var note := Store.make(text, tags, sev, tg, pos, {"tick": tick, "hour": fposmod(tick, DAY_TICKS) / TICKS_PER_HOUR,
		"camera": cam_pose, "options": opts, "build": Scenario.build_text(),
		"meta": Meta.collect(get_tree()) if is_inside_tree() else {}, "origin": "flag"})
	var dir := Store.write(store_dir(), note)
	if dir == "":
		return "could not write the note under " + store_dir()
	if with_images and cam != null and DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		if img != null:
			img.save_jpg(dir.path_join("screenshot.jpg"), 0.9)
			var r := crop_rect(cam.unproject_position(pos) if not cam.is_position_behind(pos) else Vector2(img.get_width() * 0.5, img.get_height() * 0.5), img.get_size())
			img.get_region(r).save_jpg(dir.path_join("crop.jpg"), 0.9)
	if with_images and st != null and scene != null and scene.has_method("scenario_ctx"):
		var err := Scenario.save(st, scene.scenario_ctx(), dir.path_join("scenario"), "note", text)
		if err != "":
			push_warning("note scenario: " + err)
	last_saved = str(note.id)
	reload()
	return ""

## The crop around a point: CROP size, kept inside the image.
static func crop_rect(centre: Vector2, size: Vector2i) -> Rect2i:
	var w := mini(CROP.x, size.x)
	var h := mini(CROP.y, size.y)
	var x := clampi(roundi(centre.x) - w / 2, 0, size.x - w)
	var y := clampi(roundi(centre.y) - h / 2, 0, size.y - h)
	return Rect2i(x, y, w, h)

## Saves the box. A new note hides the flag UI for one frame first, so the screenshot shows the game, not the box. Returns "" or a sentence.
func commit_box() -> String:
	var text := _edit.text.strip_edges()
	if text == "":
		return "write a line first"
	var tags: Array = [tag_name()] if tag_name() != "" else []
	var err := ""
	if editing.is_empty():
		var tg := target
		var sev := severity
		close_box()
		_hover_label.visible = false
		_pin_layer.visible = false
		if is_inside_tree() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		err = save_note(text, tags, sev, tg)
		_pin_layer.visible = true
	else:
		var n := editing.duplicate(true)
		n.text = text
		n.tags = tags
		n.severity = severity
		err = Store.save_edit(store_dir(), n)
		reload()
		if err == "":
			close_box()
	return err

func _commit_from_key() -> void:
	var err: String = await commit_box()
	if err != "" and box_open:
		_hint.text = err

func finish_box_done() -> void:
	if not editing.is_empty():
		Store.mark_done(store_dir(), str(editing.id))
		reload()
		close_box()

# --- input and drawing ---------------------------------------------------------------------------------

func _process(_dt: float) -> void:
	if not is_inside_tree():
		return
	if active and not box_open:
		var m := get_viewport().get_mouse_position()
		var pin := pin_at(m)
		_pin_tip = ""
		if not pin.is_empty():
			_pin_tip = "%s  (click to edit)" % Store.line(pin)
			hover = {}
			_set_hover_text(_pin_tip, m)
		else:
			hover = pick_at(m)
			_set_hover_text(("%s: %s" % [hover.kind, hover.name]) if not hover.is_empty() else "", m)
	elif pins_overlay:
		var m2 := get_viewport().get_mouse_position()
		var pin2 := pin_at(m2)
		_pin_tip = Store.line(pin2) if not pin2.is_empty() else ""
		_set_hover_text(_pin_tip, m2)
	_pin_layer.queue_redraw()

func _set_hover_text(text: String, at: Vector2) -> void:
	_hover_label.visible = text != ""
	_hover_label.text = text
	_hover_label.position = at + Vector2(16, 14)

func _draw_pins() -> void:
	if not pins_visible():
		return
	for n in notes:
		var s = _pin_screen(n)
		if s == null:
			continue
		var col: Color = [Palette.LICHEN, Palette.GOLD, Palette.DANGER][clampi(int(n.severity) - 1, 0, 2)]
		var p: Vector2 = s
		_pin_layer.draw_line(p, p + Vector2(0, 14), Color(Palette.INK, 0.8), 3.0)
		_pin_layer.draw_line(p, p + Vector2(0, 14), col, 1.5)
		_pin_layer.draw_circle(p, 6.0, Color(Palette.INK, 0.85))
		_pin_layer.draw_circle(p, 4.5, col)

func _input(e: InputEvent) -> void:
	if not Dev.enabled:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		if e.is_action_pressed("dev_flag") and not Game.console_open and not box_open:
			exit() if active else enter()
			get_viewport().set_input_as_handled()
			return
		if box_open:
			if e.keycode == KEY_ESCAPE:
				close_box()
			elif e.keycode == KEY_ENTER or e.keycode == KEY_KP_ENTER:
				_commit_from_key()
			elif e.keycode == KEY_TAB:
				if e.shift_pressed:
					cycle_severity()
				else:
					cycle_tag()
				_update_box()
			elif e.keycode == KEY_D and e.ctrl_pressed and not editing.is_empty():
				finish_box_done()
			else:
				return     # typing goes to the LineEdit
			get_viewport().set_input_as_handled()
		elif active and e.keycode == KEY_ESCAPE:
			exit()
			get_viewport().set_input_as_handled()
	elif active and not box_open and e is InputEventMouseButton:
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			var pin := pin_at(e.position)
			if not pin.is_empty():
				open_box({}, pin)
			else:
				var pk := pick_at(e.position)
				if not pk.is_empty():
					open_box(pk)
		get_viewport().set_input_as_handled()
