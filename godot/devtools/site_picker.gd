extends CanvasLayer
## D2 picker (F2): a search field and a list of sites with their distance; Enter teleports (tp <id>), Esc closes.
## Ctrl+B stores a bookmark at the player (ignored while a modal is open). Thumbnails are DT1.

const Palette := preload("res://ui/palette.gd")
const Scenario := preload("res://devtools/scenario.gd")

var sites          # Sites instance
var registry       # console registry (tp goes through it, so the picker and the console agree)
var panel: PanelContainer
var search: LineEdit
var list: ItemList
var is_open := false
var scenario_mode := false     # F6: the same widget lists scenarios; Enter loads one
var title_label: Label
var _rows: Array = []

func _init() -> void:
	layer = 31

func _ready() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL_SOLID, 0.96), 16, Palette.BORDER, 14))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(520, 380)
	panel.visible = false
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "Go to"
	title_label = title
	title.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(title)
	search = LineEdit.new()
	search.placeholder_text = "search sites (crater, cave, bookmark...)"
	search.text_changed.connect(func(_t): refresh())
	search.text_submitted.connect(func(_t): go())
	box.add_child(search)
	list = ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_activated.connect(func(_i): go())
	box.add_child(list)
	add_child(panel)

func _player_xz() -> Vector2:
	var st = Game.stage
	if st == null or st.cur.is_empty():
		return Vector2.ZERO
	return Vector2(st.cur.entities[0].x, st.cur.entities[0].z)

func refresh() -> void:
	list.clear()
	if scenario_mode:
		_rows = []
		for n in Scenario.list_names():
			if search.text.strip_edges() == "" or n.to_lower().contains(search.text.to_lower()):
				_rows.append({"site": {"id": n, "name": n, "kind": "scenario"}})
				list.add_item(n)
		if list.item_count > 0:
			list.select(0)
		return
	if sites == null:
		return
	var revealed: bool = registry != null and registry.flags.get("reveal", false)
	var bound := 195.0
	if Game.stage != null:
		bound = Game.stage.world.bound()
	_rows = sites.search(search.text, revealed, _player_xz())
	var extra: Array = []
	for i in sites.bookmarks.size():
		var s: Dictionary = sites.find("bookmark-%d" % (i + 1))
		if search.text.strip_edges() == "" or str(s.name).to_lower().contains(search.text.to_lower()) or "bookmark".contains(search.text.to_lower()):
			extra.append({"site": s, "score": 1, "dist": Vector2(s.pos.x, s.pos.z).distance_to(_player_xz())})
	_rows.append_array(extra)
	for r in _rows:
		var s: Dictionary = r.site
		var outside: bool = maxf(absf(s.pos.x), absf(s.pos.z)) > bound
		var t := "%s   [%s]   %d m" % [s.name, s.kind, int(r.dist)]
		if outside:
			t += "   outside the playable valley (F4)"
		list.add_item(t)
		if outside:
			list.set_item_disabled(list.item_count - 1, true)
	if list.item_count > 0:
		list.select(0)

func open_scenarios() -> void:
	scenario_mode = true
	title_label.text = "Load scenario"
	search.placeholder_text = "search scenarios"
	open()

func open() -> void:
	is_open = true
	panel.visible = true
	Game.console_open = true      # the keyboard belongs to the picker while it is open
	search.text = ""
	refresh()
	search.grab_focus()

func close() -> void:
	scenario_mode = false
	title_label.text = "Go to"
	search.placeholder_text = "search sites (crater, cave, bookmark...)"
	is_open = false
	panel.visible = false
	Game.console_open = false
	search.release_focus()

func go() -> void:
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var s: Dictionary = _rows[sel[0]].site
	if scenario_mode:
		var parsed := Scenario.read(s.id)
		var scene := get_tree().current_scene
		var err: String = parsed.error if not parsed.ok else scene.load_scenario(parsed)
		if err != "":
			push_warning(err)
			var gui = scene.get("stage_ui")
			if gui != null:
				gui.ui.show_message(err, "warn")
		close()
		return
	if registry != null:
		var res: Dictionary = registry.execute("tp %s" % s.id)
		if not res.ok:
			var gui = get_tree().current_scene.get("stage_ui") if get_tree().current_scene != null else null
			push_warning(res.error)
	close()

func bookmark_here() -> void:
	var st = Game.stage
	if st == null or sites == null:
		return
	var e: Dictionary = st.cur.entities[0]
	var cam := {}
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("camera_state"):
		cam = scene.camera_state()
	var n: int = sites.add_bookmark(Vector3(e.x, Game.ground(e.x, e.z), e.z), cam)
	var gui = scene.get("stage_ui") if scene != null else null
	if gui != null:
		gui.ui.show_message("bookmark %d saved" % n, "info")

func _input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo or not Dev.enabled:
		return
	if e.is_action_pressed("dev_sites") and (not Game.console_open or is_open):
		if is_open:
			close()
		elif sites != null:
			open()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("dev_quickload") and not Game.console_open and not is_open:
		open_scenarios()
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("dev_quicksave") and not Game.console_open and not is_open:
		quick_save()
		get_viewport().set_input_as_handled()
	elif is_open and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
	elif is_open and (e.keycode == KEY_DOWN or e.keycode == KEY_UP):
		var sel := list.get_selected_items()
		var i: int = (sel[0] if not sel.is_empty() else -1) + (1 if e.keycode == KEY_DOWN else -1)
		if list.item_count > 0:
			list.select(clampi(i, 0, list.item_count - 1))
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("dev_bookmark") and not Game.modal_open and not Game.console_open:
		bookmark_here()
		get_viewport().set_input_as_handled()

## F5: saves quick-<time> next to the curated scenarios when running from the source tree, else under user://scenarios.
func quick_save() -> void:
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("save_scenario"):
		return
	var stamp := Time.get_datetime_string_from_system(false).replace("-", "").replace(":", "").replace("T", "-")
	var dir := Scenario.DEV_DIR + "/creature" if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(Scenario.DEV_DIR)) else Scenario.USER_DIR
	var err: String = scene.save_scenario("%s/quick-%s" % [dir, stamp], "scenario", "quick save")
	var gui = scene.get("stage_ui")
	if gui != null:
		gui.ui.show_message("saved quick-%s" % stamp if err == "" else err, "info" if err == "" else "warn")
