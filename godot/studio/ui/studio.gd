extends Control
## The creature studio shell (G42-G45, G48): Build / Paint / Test over a creature view.
## `view` is any node implementing creature_view.gd; the placeholder is used until the real builder lands.

const Model := preload("../model.gd")
const PartsDB := preload("../parts_db.gd")
const I18n := preload("../i18n.gd")
const Storage := preload("../storage.gd")
const Genome := preload("../genome.gd")
const Thumbs := preload("../thumbnails.gd")
const ThemeFactory := preload("theme_factory.gd")
const PlaceholderView := preload("../placeholder/placeholder_view.gd")
const RealView := preload("../creature_view_real.gd")

signal creature_saved(path: String)
signal exit_requested

var model: RefCounted
var parts_db: RefCounted
var i18n: RefCounted
var storage: RefCounted
var view: Node3D                      # creature_view.gd interface
var camera: Camera3D
var viewport: SubViewport
var stage: SubViewportContainer
var overlay: Control
var hud: Control
var hint_label: Label
var panel_box: VBoxContainer
var name_edit: LineEdit
var undo_btn: Button
var redo_btn: Button
var mode_buttons := {}
var category_tabs := {}
var category_grids := {}
var palette_buttons := {}             # part id -> Button
var thumbnails := {}                  # part id -> Texture2D
var current_category := "mouths"
var lang := "es"

var _yaw := 1.15
var _pitch := .22
var _dist := 11.0
var _target := Vector3(0, 2.0, 0)
var _drag := {}
var _pending_type := ""
var _hover_node := -1
var _mouse := Vector2.ZERO
var _flash_timer := 0.0
var _wheel_open := false
var _wheel_timer: Timer
var _rebuild_queued := false
var _slider_tx := false
var _file_dialog: FileDialog
var _file_menu: PopupMenu
var _load_menu: PopupMenu
var _file_mode := ""
var _ghost: Label

func _init(db: RefCounted = null, view_node: Node3D = null) -> void:
	parts_db = db if db else PartsDB.new()
	view = view_node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeFactory.make()
	i18n = I18n.new()
	i18n.parts = parts_db
	var game := get_node_or_null("/root/Game")
	storage = Storage.new(str(game.studio_dir) if game != null and "studio_dir" in game else "user://studio")
	model = Model.new(parts_db)
	model.changed.connect(_on_model_changed)
	model.selection_changed.connect(_on_selection_changed)
	model.history_changed.connect(_sync_history)
	_build_stage()
	_build_hud()
	_wheel_timer = Timer.new()
	_wheel_timer.one_shot = true
	_wheel_timer.wait_time = .4
	_wheel_timer.timeout.connect(_close_wheel_tx)
	add_child(_wheel_timer)
	_apply_model()
	frame_creature()

func _process(dt: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= dt
		if _flash_timer <= 0.0:
			_set_hint("")
	if overlay and (model.selected >= 0 or not _drag.is_empty() or _pending_type != ""):
		overlay.queue_redraw()

# =================================================================== stage
func _build_stage() -> void:
	stage = SubViewportContainer.new()
	stage.stretch = true
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_stage_input)
	stage.mouse_exited.connect(func(): _set_hover(-1))
	add_child(stage)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	stage.add_child(viewport)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("1b3446")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("a9c4d0")
	e.ambient_light_energy = .7
	env.environment = e
	viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("ffe2b8")
	viewport.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 42
	camera.current = true
	viewport.add_child(camera)
	if view == null:
		view = RealView.make_default(parts_db)
	viewport.add_child(view)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_ghost = Label.new()
	_ghost.visible = false
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.add_theme_color_override("font_color", ThemeFactory.AMBER)
	add_child(_ghost)

func _on_exit() -> void:
	exit_requested.emit()
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("goto_menu"):
		game.goto_menu()

func frame_creature() -> void:
	var pts: PackedVector3Array = view.spine_node_positions()
	if pts.size() >= 2:
		_target = pts[pts.size() >> 1]
		_dist = clampf(5.0 + pts[0].distance_to(pts[pts.size() - 1]) * 1.15, 6.0, 40.0)
	_place_camera()

func _place_camera() -> void:
	var cp := cos(_pitch)
	camera.position = _target + Vector3(sin(_yaw) * cp, sin(_pitch), cos(_yaw) * cp) * _dist
	camera.look_at(_target, Vector3.UP)
	if overlay:
		overlay.queue_redraw()

func _stage_ray(pos: Vector2) -> Array:
	return [camera.project_ray_origin(pos), camera.project_ray_normal(pos)]

func _hit_body(pos: Vector2) -> Dictionary:
	var r := _stage_ray(pos)
	return view.hit_body(r[0], r[1])

func _apply_model() -> void:
	view.set_genome(model.doc)
	view.set_selection(model.selected)
	view.set_spine_visible(model.mode == "build")
	view.set_playing(model.playing)

# =================================================================== model events
func _on_model_changed(live: bool) -> void:
	_apply_model()
	if name_edit and not name_edit.has_focus():
		name_edit.text = str(model.doc.get("name", ""))
	if not live:
		_queue_rebuild()

func _on_selection_changed() -> void:
	if overlay:
		overlay.queue_redraw()
	view.set_selection(model.selected)
	_queue_rebuild()

func _sync_history() -> void:
	if undo_btn:
		undo_btn.disabled = not model.can_undo()
		redo_btn.disabled = not model.can_redo()

func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild_panel.call_deferred()

# =================================================================== HUD
func _build_hud() -> void:
	if hud:
		hud.queue_free()
		hud = null
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	_build_top_bar()
	_build_palette()
	_build_right_panel()
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.offset_bottom = -16
	hint_label.add_theme_color_override("font_color", ThemeFactory.MUTED)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint_label)
	_set_hint("")
	_rebuild_panel()
	_sync_history()

func T(s: String) -> String:
	return i18n.tr_(s)

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.offset_top = 14
	hud.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	mode_buttons.clear()
	var group := ButtonGroup.new()
	for m in [["build", "Construir"], ["paint", "Pintar"], ["test", "Probar"]]:
		var b := Button.new()
		b.text = T(m[1])
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = model.mode == m[0]
		b.custom_minimum_size = Vector2(96, 34)
		b.pressed.connect(set_mode.bind(m[0]))
		row.add_child(b)
		mode_buttons[m[0]] = b
	row.add_child(VSeparator.new())
	undo_btn = Button.new()
	undo_btn.text = "↶ " + T("Deshacer")
	undo_btn.pressed.connect(on_undo)
	row.add_child(undo_btn)
	redo_btn = Button.new()
	redo_btn.text = "↷ " + T("Rehacer")
	redo_btn.pressed.connect(on_redo)
	row.add_child(redo_btn)
	# left corner: name, file menu
	var left := PanelContainer.new()
	left.offset_left = 14; left.offset_top = 14
	hud.add_child(left)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 6)
	left.add_child(lrow)
	var menu_btn := Button.new()
	menu_btn.text = "← " + T("Menú")
	menu_btn.tooltip_text = T("Guarda con Ctrl+S; Jugar usa la última criatura guardada")
	menu_btn.pressed.connect(_on_exit)
	lrow.add_child(menu_btn)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(150, 0)
	name_edit.placeholder_text = T("Ponle nombre")
	name_edit.text = str(model.doc.get("name", ""))
	name_edit.max_length = 80
	name_edit.text_submitted.connect(func(t): model.set_name_(t); name_edit.release_focus())
	name_edit.focus_exited.connect(func(): if name_edit.text != model.doc.get("name", ""): model.set_name_(name_edit.text))
	lrow.add_child(name_edit)
	var file_btn := MenuButton.new()
	file_btn.text = T("Archivo")
	_file_menu = file_btn.get_popup()
	_file_menu.add_item(T("Nueva"), 0)
	_file_menu.add_item(T("Guardar") + "  Ctrl+S", 1)
	_load_menu = PopupMenu.new()
	_load_menu.name = "loadmenu"
	_load_menu.about_to_popup.connect(_fill_load_menu)
	_load_menu.index_pressed.connect(func(i): load_saved(_load_menu.get_item_text(i)))
	_file_menu.add_child(_load_menu)
	_file_menu.add_submenu_node_item(T("Cargar"), _load_menu)
	_file_menu.add_item(T("Importar JSON"), 3)
	_file_menu.add_item(T("Exportar JSON"), 4)
	_file_menu.id_pressed.connect(_on_file_menu)
	lrow.add_child(file_btn)
	# right corner: language
	var lang_box := PanelContainer.new()
	lang_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	lang_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lang_box.offset_top = 14; lang_box.offset_right = -14
	hud.add_child(lang_box)
	var lrow2 := HBoxContainer.new()
	lang_box.add_child(lrow2)
	for l in ["es", "en"]:
		var b := Button.new()
		b.text = l.to_upper()
		b.toggle_mode = true
		b.button_pressed = lang == l
		b.pressed.connect(set_lang.bind(l))
		lrow2.add_child(b)

func _build_palette() -> void:
	var card := PanelContainer.new()
	card.offset_left = 14; card.offset_top = 66
	card.offset_right = 262
	card.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	card.offset_bottom = -52
	hud.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var title := Label.new()
	title.text = T("Piezas").to_upper() if false else "—"
	title.add_theme_color_override("font_color", ThemeFactory.AMBER)
	col.add_child(title)
	var tabs := GridContainer.new()
	tabs.columns = 3
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 4)
	col.add_child(tabs)
	category_tabs.clear()
	category_grids.clear()
	palette_buttons.clear()
	var group := ButtonGroup.new()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	for c in parts_db.categories:
		var tb := Button.new()
		tb.text = i18n.category(c)
		tb.toggle_mode = true
		tb.button_group = group
		tb.button_pressed = c == current_category
		tb.add_theme_font_size_override("font_size", 12)
		tb.custom_minimum_size = Vector2(0, 30)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(select_category.bind(c))
		tabs.add_child(tb)
		category_tabs[c] = tb
		var grid := GridContainer.new()
		grid.columns = 2
		grid.visible = c == current_category
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		holder.add_child(grid)
		category_grids[c] = grid
		for id in parts_db.ids_in(c):
			grid.add_child(_make_part_button(id, c))
	title.text = i18n.category(current_category).to_upper()
	title.name = "CategoryTitle"

func _make_part_button(id: String, category: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(104, 98)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = i18n.part_name(id)
	b.toggle_mode = false
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var tex := TextureRect.new()          # thumbnail slot
	tex.name = "Thumb"
	tex.custom_minimum_size = Vector2(64, 64)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not thumbnails.has(id):
		thumbnails[id] = Thumbs.make(id, category)
	tex.texture = thumbnails[id]
	v.add_child(tex)
	var lab := Label.new()
	lab.text = i18n.part_name(id)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 11)
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lab)
	b.gui_input.connect(_palette_input.bind(id))
	palette_buttons[id] = b
	return b

## Integration hook: replace a placeholder thumbnail with a real render.
func set_thumbnail(id: String, tex: Texture2D) -> void:
	thumbnails[id] = tex
	if palette_buttons.has(id):
		palette_buttons[id].get_node("VBoxContainer/Thumb").texture = tex if false else tex

func palette_button_count() -> int:
	return palette_buttons.size()

func category_count() -> int:
	return category_tabs.size()

func mode_button_text(m: String) -> String:
	return mode_buttons[m].text

func select_category(c: String) -> void:
	current_category = c
	for k in category_grids:
		category_grids[k].visible = k == c
		category_tabs[k].set_pressed_no_signal(k == c)
	var t := hud.find_child("CategoryTitle", true, false)
	if t:
		t.text = i18n.category(c).to_upper()

# =================================================================== right panel
func _build_right_panel() -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -282; card.offset_right = -14
	card.offset_top = 66; card.offset_bottom = -52
	hud.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 8)
	scroll.add_child(panel_box)

func _h2(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_color_override("font_color", ThemeFactory.AMBER)
	l.add_theme_font_size_override("font_size", 13)
	return l

func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(226, 0)
	l.add_theme_color_override("font_color", ThemeFactory.MUTED)
	l.add_theme_font_size_override("font_size", 12)
	return l

func _slider_row(label: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo; s.max_value = hi; s.step = step
	s.set_value_no_signal(value)
	s.custom_minimum_size = Vector2(226, 20)
	s.drag_started.connect(func(): model.begin(); _slider_tx = true)
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_c): if _slider_tx: _slider_tx = false; model.end())
	box.add_child(s)
	return box

func _rebuild_panel() -> void:
	_rebuild_queued = false
	if panel_box == null or _slider_tx:
		return
	for c in panel_box.get_children():
		panel_box.remove_child(c)
		c.queue_free()
	match model.mode:
		"build": _panel_build()
		"paint": _panel_paint()
		"test": _panel_test()
	_sync_history()

func _panel_build() -> void:
	var sel: int = model.selected
	if sel >= 0 and sel < model.doc["parts"].size():
		var p: Dictionary = model.doc["parts"][sel]
		panel_box.add_child(_h2(i18n.part_name(p["type"])))
		for k in parts_db.param_keys(p["type"]):
			var r: Array = PartsDB.RANGES[k]
			panel_box.add_child(_slider_row(T(PartsDB.LABELS[k]), clampf(p.get(k, 0.0), r[0], r[1]), r[0], r[1], .01,
				func(v): if sel < model.doc["parts"].size(): model.set_param(sel, k, v)))
		if not parts_db.is_leg(p["type"]):
			panel_box.add_child(_note(T("Arrastra la cuenta verde para girar la pieza.")))
		var mirrored: bool = absf(sin(p["ang"])) >= .14 or parts_db.is_lateral(p["type"])
		if mirrored:
			panel_box.add_child(_note("⇋ " + T("Piezas en pareja: se reflejan a ambos lados")))
		var del := Button.new()
		del.text = T("Quitar pieza") + "  (Del)"
		del.pressed.connect(on_key_delete)
		panel_box.add_child(del)
	else:
		panel_box.add_child(_h2(T("Pieza")))
		panel_box.add_child(_note(T("Toca una pieza de la criatura para ajustarla. Arrástrala fuera del cuerpo para quitarla.")))
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(_h2(T("Columna")))
	var nrow := VBoxContainer.new()
	var addb := Button.new()
	addb.text = "+ " + T("Añadir vértebra")
	addb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	addb.disabled = not model.can_add_vertebra()
	addb.pressed.connect(func(): model.add_vertebra(clampi(_hover_node if _hover_node >= 0 else model.doc["nodes"].size() / 2, 0, model.doc["nodes"].size() - 2)))
	nrow.add_child(addb)
	var remb := Button.new()
	remb.text = "− " + T("Quitar vértebra")
	remb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remb.disabled = not model.can_remove_vertebra()
	remb.pressed.connect(func(): model.remove_vertebra(_hover_node if _hover_node >= 0 else model.doc["nodes"].size() / 2))
	nrow.add_child(remb)
	panel_box.add_child(nrow)
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(_h2(T("Criatura")))
	var chips := HFlowContainer.new()
	for s in Model.SEEDS:
		var b := Button.new()
		b.text = s
		b.pressed.connect(func(): model.new_from_seed(s); frame_creature())
		chips.add_child(b)
	panel_box.add_child(chips)

func _panel_paint() -> void:
	var s: Dictionary = model.doc["skin"]
	panel_box.add_child(_h2(T("Piel")))
	panel_box.add_child(_note(T("Dibujo")))
	var seg := HBoxContainer.new()
	for i in 4:
		var b := Button.new()
		b.text = T(Model.PATTERNS[i])
		b.toggle_mode = true
		b.button_pressed = int(s["pat"]) == i
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func(): model.set_skin("pat", i))
		seg.add_child(b)
	panel_box.add_child(seg)
	panel_box.add_child(_note(T("Colores")))
	var cols := HBoxContainer.new()
	var labels := ["Color base", "Color del dibujo", "Color del vientre"]
	var keys := ["cA", "cB", "cC"]
	for i in 3:
		var cb := ColorPickerButton.new()
		cb.color = Color(s[keys[i]])
		cb.edit_alpha = false
		cb.custom_minimum_size = Vector2(70, 32)
		cb.tooltip_text = T(labels[i])
		cb.name = "Color_" + keys[i]
		cb.pressed.connect(func(): if not _slider_tx: model.begin(); _slider_tx = true)
		cb.color_changed.connect(func(c): model.set_skin(keys[i], "#" + c.to_html(false)))
		cb.popup_closed.connect(func(): if _slider_tx: _slider_tx = false; model.end())
		cols.add_child(cb)
	panel_box.add_child(cols)
	panel_box.add_child(_slider_row(T("Escama"), s["scale"], 3, 14, .5, func(v): model.set_skin("scale", v)))
	panel_box.add_child(_slider_row(T("Brillo"), s["wet"], 0, 1, .01, func(v): model.set_skin("wet", v)))
	panel_box.add_child(HSeparator.new())
	panel_box.add_child(_h2(T("Combinaciones")))
	var chips := HFlowContainer.new()
	for i in Model.PALETTES.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(54, 26)
		b.icon = _palette_swatch(Model.PALETTES[i])
		b.expand_icon = true
		b.pressed.connect(func(): model.apply_palette(i))
		chips.add_child(b)
	panel_box.add_child(chips)

func _palette_swatch(p: Array) -> ImageTexture:
	var img := Image.create(54, 20, false, Image.FORMAT_RGBA8)
	for x in 54:
		var c := Color(p[0]) if x < 27 else (Color(p[1]) if x < 42 else Color(p[2]))
		for y in 20:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _panel_test() -> void:
	panel_box.add_child(_h2(T("Animación")))
	var play := Button.new()
	play.name = "PlayButton"
	play.toggle_mode = true
	play.button_pressed = model.playing
	play.text = ("■ " + T("Parar")) if model.playing else ("▶ " + T("Reproducir"))
	play.custom_minimum_size = Vector2(0, 38)
	play.pressed.connect(toggle_play)
	panel_box.add_child(play)
	panel_box.add_child(_note(T("Tu criatura camina sola: nada está animado a mano")))
	panel_box.add_child(_note(T("Cosmético")))

# =================================================================== actions (shared by UI, keys and tests)
func set_mode(m: String) -> void:
	_cancel_drag()
	_pending_type = ""
	model.set_mode(m)
	overlay.queue_redraw()
	for k in mode_buttons:
		mode_buttons[k].set_pressed_no_signal(k == m)
	_set_hint("")
	_queue_rebuild()

func set_lang(l: String) -> void:
	lang = l
	i18n.lang = l
	_build_hud()
	_apply_model()

func toggle_play() -> void:
	model.set_playing(not model.playing)
	_queue_rebuild()

func on_undo() -> void:
	_cancel_drag()
	model.undo()

func on_redo() -> void:
	_cancel_drag()
	model.redo()

func on_key_delete() -> void:
	if model.mode == "build" and model.selected >= 0:
		model.remove_part(model.selected)

## Add a part from the palette at a spine position/angle (what a drop does after hit-testing).
func drop_part_at_t(type: String, t: float, ang: float) -> int:
	return model.add_part(type, t, ang)

func save_current() -> String:
	var path: String = storage.save(model.get_doc())
	if path != "":
		model.dirty = false
		_flash(T("Guardado") + ": " + path.get_file())
		creature_saved.emit(path)
	return path

func load_saved(file: String) -> bool:
	var r: Dictionary = storage.load_named(file, parts_db.by_id)
	return _apply_import(r)

func import_path(path: String) -> bool:
	return _apply_import(storage.import_from(path, parts_db.by_id))

func export_path(path: String) -> bool:
	return storage.export_to(model.get_doc(), path) != ""

func _apply_import(r: Dictionary) -> bool:
	if not r["ok"]:
		_flash(T("Genoma no válido") + ": " + str(r["error"]))
		return false
	var w: Array = r.get("warnings", [])
	if model.import_doc(r["genome"])["ok"]:
		frame_creature()
		_flash(" · ".join(w.map(func(x): return T(x))) if not w.is_empty() else T("Diseño cargado"))
		return true
	return false

func _fill_load_menu() -> void:
	_load_menu.clear()
	for f in storage.list():
		_load_menu.add_item(f)

func _on_file_menu(id: int) -> void:
	match id:
		0: model.new_from_seed("Merodeador"); frame_creature()
		1: save_current()
		3: _open_dialog("import")
		4: _open_dialog("export")

func _open_dialog(kind: String) -> void:
	_file_mode = kind
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.use_native_dialog = true
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.add_filter("*.json", "cpore.creature JSON")
		_file_dialog.file_selected.connect(func(p): if _file_mode == "import": import_path(p) else: export_path(p))
		add_child(_file_dialog)
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if kind == "import" else FileDialog.FILE_MODE_SAVE_FILE
	_file_dialog.current_file = "primigenia-creature.json"
	_file_dialog.popup_centered(Vector2i(720, 480))

# =================================================================== hints
func _set_hint(t: String) -> void:
	if hint_label == null:
		return
	if t == "":
		match model.mode:
			"build": t = "Pasa el cursor por el cuerpo para ver la columna · arrastra una vértebra para esculpir · rueda sobre ella para engordar"
			"paint": t = "Arrastra para girar la cámara"
			"test": t = "Tu criatura camina sola: nada está animado a mano"
	hint_label.text = T(t)

func _flash(t: String) -> void:
	hint_label.text = t
	_flash_timer = 2.6

# =================================================================== input
func _set_hover(n: int) -> void:
	_hover_node = n

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	match e.keycode:
		KEY_ESCAPE:
			_cancel_drag()
			_pending_type = ""
			_set_hint("")
		KEY_Z:
			if ctrl:
				if e.shift_pressed: on_redo()
				else: on_undo()
				get_viewport().set_input_as_handled()
		KEY_Y:
			if ctrl:
				on_redo()
				get_viewport().set_input_as_handled()
		KEY_S:
			if ctrl:
				save_current()
				get_viewport().set_input_as_handled()
		KEY_O:
			if ctrl:
				_open_dialog("import")
		KEY_DELETE, KEY_BACKSPACE:
			if model.mode == "build" and model.selected >= 0:
				on_key_delete()
				get_viewport().set_input_as_handled()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			if model.mode == "build" and model.selected >= 0:
				var dt := .02 * (1 if e.keycode == KEY_RIGHT else (-1 if e.keycode == KEY_LEFT else 0))
				var da := .05 * (1 if e.keycode == KEY_DOWN else (-1 if e.keycode == KEY_UP else 0))
				model.nudge_part(model.selected, dt, da)
				get_viewport().set_input_as_handled()

func _input(e: InputEvent) -> void:
	# palette drags end anywhere on screen
	if _drag.get("kind", "") == "new":
		if e is InputEventMouseMotion:
			_mouse = e.position
			_ghost.position = e.position + Vector2(14, 10)
			overlay.queue_redraw()
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			_finish_new_drag(e.position)

func _palette_input(e: InputEvent, id: String) -> void:
	if model.mode != "build":
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_cancel_drag()
		_drag = {"kind": "new", "type": id, "start": get_viewport().get_mouse_position(), "moved": false}
		_pending_type = ""
		_ghost.text = i18n.part_name(id)
		_ghost.visible = true
		_ghost.position = get_viewport().get_mouse_position() + Vector2(14, 10)
		_set_hint("Llévala hasta el cuerpo de la criatura")
	elif e is InputEventMouseMotion and _drag.get("kind", "") == "new":
		if (get_viewport().get_mouse_position() - _drag["start"]).length() > 6.0:
			_drag["moved"] = true

func _finish_new_drag(pos: Vector2) -> void:
	var d := _drag
	_drag = {}
	_ghost.visible = false
	var local := pos - stage.global_position
	if not d["moved"]:
		_pending_type = d["type"]          # click: then click the body to place
		_flash(T("Toca el cuerpo para colocar"))
	else:
		var h := _hit_body(local) if Rect2(Vector2.ZERO, stage.size).has_point(local) and not _over_hud(pos) else {}
		if not h.is_empty():
			model.add_part(d["type"], h["t"], h["ang"])
		_set_hint("")
	overlay.queue_redraw()

func _over_hud(global_pos: Vector2) -> bool:
	for c in hud.get_children():
		if c is PanelContainer and c.get_global_rect().has_point(global_pos):
			return true
	return false

func _cancel_drag() -> void:
	if _drag.get("tx", false):
		model.cancel()
	_drag = {}
	if _ghost:
		_ghost.visible = false
	if _wheel_open:
		_close_wheel_tx()

func _stage_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		_mouse = e.position
		_stage_motion(e)
	elif e is InputEventMouseButton:
		_mouse = e.position
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _stage_press(e)
			else: _stage_release(e)
		elif e.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if e.pressed: _drag = {"kind": "cam", "last": e.position, "moved": false}
			else: _drag = {}
		elif e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and e.pressed:
			_stage_wheel(1.0 if e.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0, e.position)

func _handles() -> Dictionary:
	# screen-space handles for the selected part: {c: centre, rot: Vector2, tilt: Vector2 or null}
	if model.mode != "build" or model.selected < 0 or model.selected >= model.doc["parts"].size():
		return {}
	var a: Dictionary = view.part_anchor(model.selected)
	if a.is_empty() or camera.is_position_behind(a["pos"]):
		return {}
	var p: Dictionary = model.doc["parts"][model.selected]
	var c := camera.unproject_position(a["pos"])
	var out := {"c": c}
	if not parts_db.is_leg(p["type"]):
		out["rot"] = c + Vector2(cos(p.get("rot", 0.0)), -sin(p.get("rot", 0.0))) * 52.0
		out["tilt"] = c + Vector2(-64.0, -p.get("tilt", 0.0) * 40.0)
	return out

func _stage_press(e: InputEventMouseButton) -> void:
	_cancel_drag()
	var pos: Vector2 = e.position
	if model.mode != "build":
		_drag = {"kind": "cam", "last": pos, "moved": false}
		return
	if _pending_type != "":
		var h := _hit_body(pos)
		if not h.is_empty():
			model.add_part(_pending_type, h["t"], h["ang"])
		_pending_type = ""
		_set_hint("")
		return
	var hs := _handles()
	if not hs.is_empty():
		if hs.has("rot") and pos.distance_to(hs["rot"]) < 11.0:
			model.begin()
			_drag = {"kind": "rot", "tx": true}
			return
		if hs.has("tilt") and pos.distance_to(hs["tilt"]) < 11.0:
			model.begin()
			_drag = {"kind": "tilt", "tx": true, "origin": hs["c"]}
			return
	var r := _stage_ray(pos)
	var n: int = view.hit_node(r[0], r[1])
	if n >= 0:
		model.begin()
		_drag = {"kind": "node", "node": n, "tx": true}
		return
	var pi: int = view.hit_part(r[0], r[1])
	if pi >= 0:
		model.select(pi)
		_drag = {"kind": "part", "part": pi, "start": pos, "moved": false}
		return
	_drag = {"kind": "cam", "last": pos, "moved": false}

func _stage_motion(e: InputEventMouseMotion) -> void:
	var pos: Vector2 = e.position
	var k: String = _drag.get("kind", "")
	match k:
		"":
			if model.mode == "build" and not _over_hud(e.global_position):
				var r := _stage_ray(pos)
				var n: int = view.hit_node(r[0], r[1])
				if n != _hover_node:
					_hover_node = n
				stage.mouse_default_cursor_shape = Control.CURSOR_MOVE if n >= 0 else (Control.CURSOR_POINTING_HAND if view.hit_part(r[0], r[1]) >= 0 else Control.CURSOR_ARROW)
		"cam":
			_yaw -= e.relative.x * .006
			_pitch = clampf(_pitch + e.relative.y * .004, -.02, 1.2)
			_drag["moved"] = true
			_place_camera()
		"node":
			var o: Vector3 = _stage_ray(pos)[0]
			var d: Vector3 = _stage_ray(pos)[1]
			if absf(d.x) > 1e-4:
				var s := -o.x / d.x
				if s > 0.0:
					_drag["node"] = model.move_node(_drag["node"], o.y + d.y * s, o.z + d.z * s)
		"part":
			if not _drag["moved"] and pos.distance_to(_drag["start"]) < 5.0:
				return
			if not _drag["moved"]:
				_drag["moved"] = true
				model.begin()
				_drag["tx"] = true
			var h := _hit_body(pos)
			_drag["over"] = not h.is_empty()
			if _drag["over"]:
				model.place_part(_drag["part"], h["t"], h["ang"])
			_set_hint("Suelta para colocar" if _drag["over"] else "Suelta fuera del cuerpo para quitar la pieza")
		"rot":
			var hs := _handles()
			if hs.has("c"):
				var d: Vector2 = pos - hs["c"]
				model.set_param(model.selected, "rot", atan2(-d.y, d.x))
		"tilt":
			model.set_param(model.selected, "tilt", -(pos.y - _drag["origin"].y) / 40.0)

func _stage_release(_e: InputEventMouseButton) -> void:
	var d := _drag
	_drag = {}
	match d.get("kind", ""):
		"cam":
			if not d["moved"] and model.mode == "build":
				model.select(-1)
		"part":
			if d["moved"]:
				if d.get("over", true):
					model.end()
				else:
					model.remove_part(d["part"])
					model.end()
				_set_hint("")
		"node", "rot", "tilt":
			model.end()
	overlay.queue_redraw()

func _stage_wheel(dir: float, pos: Vector2) -> void:
	if model.mode == "build":
		var r := _stage_ray(pos)
		var n: int = view.hit_node(r[0], r[1])
		if n >= 0:
			_wheel_tx()
			model.set_node_radius(n, model.doc["nodes"][n]["r"] * (1.0 + dir * .08))
			return
		var pi: int = view.hit_part(r[0], r[1])
		if pi >= 0 and pi == model.selected and model.doc["parts"][pi].has("size"):
			_wheel_tx()
			model.set_param(pi, "size", model.doc["parts"][pi]["size"] * (1.0 + dir * .06))
			return
	_dist = clampf(_dist * (1.0 - dir * .08), 3.0, 60.0)
	_place_camera()

func _wheel_tx() -> void:
	if not _wheel_open:
		model.begin()
		_wheel_open = true
	_wheel_timer.start()

func _close_wheel_tx() -> void:
	if _wheel_open:
		_wheel_open = false
		model.end()

# =================================================================== overlay (handles, ghost, placement cursor)
func _draw_overlay() -> void:
	var off := stage.global_position - overlay.global_position
	var hs := _handles()
	if not hs.is_empty():
		var c: Vector2 = hs["c"] + off
		overlay.draw_arc(c, 15, 0, TAU, 32, ThemeFactory.AMBER, 2.5, true)
		overlay.draw_circle(c, 3, ThemeFactory.AMBER)
		if hs.has("rot"):
			overlay.draw_arc(c, 52, 0, TAU, 48, Color(ThemeFactory.MOSS, .35), 1.5, true)
			overlay.draw_line(c, hs["rot"] + off, Color(ThemeFactory.MOSS, .6), 1.5)
			overlay.draw_circle(hs["rot"] + off, 8, ThemeFactory.MOSS)
			var tc: Vector2 = hs["c"] + off + Vector2(-64, 0)
			overlay.draw_line(tc + Vector2(0, -52), tc + Vector2(0, 52), Color(ThemeFactory.SKY, .35), 1.5)
			overlay.draw_circle(hs["tilt"] + off, 8, ThemeFactory.SKY)
	if _drag.get("kind", "") == "new" and _drag["moved"] or _pending_type != "":
		var pos := (_mouse - stage.global_position) if _drag.get("kind", "") == "new" else _mouse
		var h := _hit_body(pos)
		if not h.is_empty():
			var sp := camera.unproject_position(h["point"]) + off
			overlay.draw_arc(sp, 14, 0, TAU, 32, ThemeFactory.MOSS, 3.0, true)
