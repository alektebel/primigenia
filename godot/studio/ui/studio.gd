extends Control
## The creature studio shell (G42-G45, G48): Build / Paint / Test over a creature view.
## `view` is any node implementing creature_view.gd; the placeholder is used until the real builder lands.

const Model := preload("../model.gd")
const PartsDB := preload("../parts_db.gd")
const I18n := preload("../i18n.gd")
const Storage := preload("../storage.gd")
const Genome := preload("../genome.gd")
const WingPanel := preload("wing_panel.gd")
const Thumbs := preload("../thumbnails.gd")
const ThemeFactory := preload("theme_factory.gd")
const PlaceholderView := preload("../placeholder/placeholder_view.gd")
const RealView := preload("../creature_view_real.gd")
const Env := preload("../studio_env.gd")
const Baker := preload("../thumb_baker.gd")
const FlowIcons := preload("flow_icons.gd")
const Ring := preload("actuator_ring.gd")

signal creature_saved(path: String)
signal nest_confirmed(genome: Dictionary)
signal nest_applied(genome: Dictionary)
var applied_genome: Dictionary = {}
var nest_plan: Dictionary = {}
var nest_tiers_on := false
var nest_cost: Label
var nest_apply_button: Button
var play_creature_btn: Button
var nest_evolve_button: Button
signal exit_requested
## Test hook for the creator scorecard (tools/creator, studio/tests/creator_replay.gd): the editor reports what the player can see.
## Names: part_placed, drop_ring, handle_shown {kind}, puff_spawned, cost_popup_shown, cost_popup_hidden, head_target_changed.
## Only part_placed, drop_ring and handle_shown (spine arrows) exist today; the creator-flow branch emits the rest through creator_ev().
signal creator_event(ev_name: String, data: Dictionary)
func creator_ev(ev_name: String, data := {}) -> void:
	creator_event.emit(ev_name, data)

## What the player can see this frame (scorecard probe).
func creator_probe() -> Dictionary:
	return {"vertebra_spheres": view.sphere_count() if view.has_method("sphere_count") else 0,
		"part_ring": view.ring_visible() if view.has_method("ring_visible") else false, "popup": _popup != null}

# ---- drop feedback state (C4): puff, floating +N cost, counter tick, can't-fit shake
const PUFF_LEN := .35
const POPUP_DELAY := .3
const POPUP_LIFE := .45
const POPUP_RISE := 34.0
var _puff_fx := {}
var _popup_wait := {}
var _popup: Label
var _popup_t := 0.0
var _popup_point := Vector3.ZERO
var _dna_ref := 0
var _fx_tween: Tween

var nest_world: RefCounted
var nest_genome: Dictionary = {}
var nest_rows: Array = []
var nest_status: Label
var nest_panel: PanelContainer
var right_card: PanelContainer        # hidden Details drawer; nest controls stack above its stats
var nest_choice: OptionButton
var nest_actions: Array = []

var model: RefCounted
var parts_db: RefCounted
var i18n: RefCounted
var storage: RefCounted
var view: Node3D                      # creature_view.gd interface
var camera: Camera3D
var env_node: Node3D
var baker: Node
var cat_title: Label
var part_thumbs := {}                 # part id -> TextureRect
var _hover_part_id := ""
var _click_sound: AudioStreamPlayer
var viewport: SubViewport
var stage: SubViewportContainer
var overlay: Control
var hud: Control
var hint_label: Label
var drawer_content: VBoxContainer
var panel_box: VBoxContainer
var name_edit: LineEdit
var undo_btn: Button
var top_bar: HBoxContainer
var redo_btn: Button
var mode_buttons := {}
var category_tabs := {}
var category_grids := {}
var palette_buttons := {}             # part id -> Button
var thumbnails := {}                  # part id -> Texture2D
var current_category := "mouths"
var lang := "es"

var _yaw := .785                      # front three-quarter: head toward the camera, 135 deg between camera and creature forward
var _pitch := .21
var _dist := 13.0
var _dist_goal := 13.0
var _target := Vector3(0, 2.0, 0)     # smoothed camera target
var _target_goal := Vector3(0, 2.0, 0)
var _framed_bounds := AABB()
var _frame_pending := false
var _spine_mid := Vector3(0, 2.0, 0)
var _theta := 0.0                     # heading of the creature on the Test path (camera follows)
var _idle := 0.0                      # seconds since the last user input
const IDLE_ROTATE_AFTER := 6.0
const IDLE_ROTATE_SPEED := .18
const DIST_MIN := .6
const DIST_MAX := 60.0
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
var _ghost: TextureRect
var _spine_hover := false
var _hover_leg := -1                  # limb under the cursor: its joint handles show and can be grabbed
var _arrow_hot := ""                  # "head" | "tail" | "": spine arrow handle under the cursor
var _scale_fx := {}                   # wheel readout: {pos: Vector2 (stage), text, limit, t}
var _ring: Control
var _ring_part := -1
const CLICK_PX := 4.0
const CLICK_MS := 200
const HANDLE_PX := 14.0
const ARROW_PX := 18.0
const ARROW_NEAR_PX := 56.0
var _drop_fx := {}                    # {point: Vector3 (view space), t: seconds}
var _flash_dna := 0.0
var _girth_fx := 0.0
var palette_card: PanelContainer
var palette_body: VBoxContainer
var palette_open := false
var details_open := false
var details_button: Button
var _drawer_tween: Tween
var _paint_more := false
var _palette_timer: Timer
var dna_label: Label
var dna_fill: ColorRect
var dna_track: Control
const DNA_BUDGET := 320                # rig.js BUDGET

func _init(db: RefCounted = null, view_node: Node3D = null) -> void:
	parts_db = db if db else PartsDB.new()
	view = view_node

## The seed of the starter body: Game.STARTER (one line to switch), "Hatchling" without the autoload.
func _starter_seed() -> String:
	var game := get_node_or_null("/root/Game")
	var key: String = str(game.STARTER) if game != null and "STARTER" in game else "hatchling"
	return Model.STARTER_SEEDS.get(key, "Hatchling")

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = ThemeFactory.make()
	i18n = I18n.new()
	i18n.parts = parts_db
	var game := get_node_or_null("/root/Game")
	storage = Storage.new(str(game.studio_dir) if game != null and "studio_dir" in game else "user://studio")
	model = Model.new(parts_db)
	model.new_from_seed(_starter_seed(), false)       # the starter body (A29); Merodeador stays a seed in the list
	model.changed.connect(_on_model_changed)
	model.selection_changed.connect(_on_selection_changed)
	model.history_changed.connect(_sync_history)
	_build_stage()
	_build_baker()
	_build_hud()
	_wheel_timer = Timer.new()
	_wheel_timer.one_shot = true
	_wheel_timer.wait_time = .4
	_wheel_timer.timeout.connect(_close_wheel_tx)
	add_child(_wheel_timer)
	_apply_model()
	frame_creature()
	if nest_world != null:
		model.import_doc(nest_genome)
		_build_nest_shop()

func _process(dt: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= dt
		if _flash_timer <= 0.0:
			_set_hint("")
	_idle += dt
	_tick_drop_fx(dt)
	if _drag.get("kind", "") != "new":
		_dna_ref = dna_value()
	if not _drop_fx.is_empty():
		_drop_fx["t"] += dt
		if _drop_fx["t"] > .5:
			_drop_fx = {}
	_girth_fx = maxf(0.0, _girth_fx - dt)
	if not _scale_fx.is_empty():
		_scale_fx["t"] -= dt
		if _scale_fx["t"] <= 0.0:
			_scale_fx = {}
	if view.is_playing() if view.has_method("is_playing") else false:
		var bp: Vector3 = view.body_position()
		_theta = atan2(bp.z, bp.x - Env.PATH_CENTER.x)
		_target_goal = _spine_mid + Vector3(bp.x, 0, bp.z)
	else:
		_theta = 0.0
		_target_goal = _spine_mid
	if _idle > IDLE_ROTATE_AFTER and _drag.is_empty() and model.mode != "test":
		_yaw += IDLE_ROTATE_SPEED * dt
	var k := 1.0 - pow(.01, dt)
	_target = _target.lerp(_target_goal, k)
	_dist = lerpf(_dist, _dist_goal, 1.0 - pow(.002, dt))
	_place_camera()
	if env_node != null and env_node.has_method("set_floor"):
		env_node.set_floor(view.floor_y())
	if overlay:
		overlay.queue_redraw()

# =================================================================== stage
func _build_stage() -> void:
	stage = SubViewportContainer.new()
	stage.stretch = true
	stage.resized.connect(_schedule_frame)
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.mouse_filter = Control.MOUSE_FILTER_STOP
	stage.gui_input.connect(_stage_input)
	stage.mouse_exited.connect(func(): _set_hover(-1))
	add_child(stage)
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	stage.add_child(viewport)
	env_node = Env.new()
	viewport.add_child(env_node)
	camera = Camera3D.new()
	camera.fov = 42
	camera.current = true
	viewport.add_child(camera)
	if view == null:
		view = RealView.make_default(parts_db)
	viewport.add_child(view)
	if view.has_signal("handle_shown"):
		view.handle_shown.connect(func(kind: String, fade_ms: float): creator_ev("handle_shown", {"kind": kind, "fade_ms": fade_ms}))
	if view.has_signal("head_target_changed"):
		view.head_target_changed.connect(func(part: int): creator_ev("head_target_changed", {"part": part}))
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	_ghost = TextureRect.new()             # thumbnail that follows the cursor until the part touches the body
	_ghost.visible = false
	_ghost.custom_minimum_size = Vector2(104, 104)
	_ghost.size = Vector2(104, 104)
	_ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ghost.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 50
	add_child(_ghost)
	_click_sound = AudioStreamPlayer.new()
	_click_sound.volume_db = -8.0
	if ResourceLoader.exists("res://audio/sounds/click.ogg"):
		_click_sound.stream = load("res://audio/sounds/click.ogg")
	add_child(_click_sound)

func _build_baker() -> void:
	var cr = view.get("creature") if view != null else null
	baker = Baker.new(cr)
	baker.baked.connect(_on_thumb_baked)
	add_child(baker)

## Save the creature and drop into the island with it (the island takes the newest saved genome).
func play_with_creature() -> void:
	var path := save_current()
	if path == "":
		_flash(T("No se pudo guardar"))
		return
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("enter_island_now"):
		exit_requested.emit()
		game.enter_island_now("studio")

func _on_exit() -> void:
	if nest_world != null:
		exit_requested.emit()
		return
	exit_requested.emit()
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("goto_menu"):
		game.goto_menu()

## The stage available around the collapsed palette and the optional Details drawer.
func free_viewport() -> Rect2:
	var left_edge := 322.0 if palette_open else 88.0
	var right_edge: float = stage.size.x - (300.0 if details_open else 24.0)
	return Rect2(left_edge, 78.0, maxf(right_edge - left_edge, 200.0), maxf(stage.size.y - 110.0, 200.0))

## Rest bounds include legs, wings and placed parts, rather than spine length alone.
func creature_bounds() -> AABB:
	if "creature" in view and view.creature != null:
		return view.creature.transform * view.creature.rest_aabb()
	var box := AABB()
	var first := true
	for n in model.doc.nodes:
		var r := Vector3.ONE * float(n.r)
		var p := Vector3(0, n.y, n.z)
		var nb := AABB(p - r, r * 2)
		box = nb if first else box.merge(nb)
		first = false
	return box

func _schedule_frame() -> void:
	if _frame_pending:
		return
	_frame_pending = true
	_auto_frame.call_deferred()

func _auto_frame() -> void:
	_frame_pending = false
	if not is_inside_tree() or camera == null or not camera.is_inside_tree():
		return          # the deferred reframe outlived the editor (left the tree): nothing to frame
	if view == null or model == null or not _drag.is_empty() or _wheel_open:
		return
	frame_creature(false)

func frame_creature(snap := true) -> void:
	if camera == null or not camera.is_inside_tree():
		return
	if stage.size.y < 1 or stage.size.x < 1:
		return
	var box := creature_bounds()
	_framed_bounds = box
	_spine_mid = box.get_center() - Vector3(0, box.size.y * .19, 0)   # creature sits in the upper-middle, like the reference
	_target_goal = _spine_mid
	var old_target := _target
	var old_dist := _dist
	_target = _target_goal
	_dist = maxf(.6, box.size.y / (2.0 * tan(deg_to_rad(camera.fov) / 2.0) * .8))
	# Perspective depth changes apparent size: solve from all eight rest-bound corners.
	for i in 8:
		_place_camera()
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for j in 8:
			var p := camera.unproject_position(box.get_endpoint(j))
			lo = lo.min(p)
			hi = hi.max(p)
		var ratio := maxf((hi.y - lo.y) / (stage.size.y * .8), (hi.x - lo.x) / (free_viewport().size.x * 1.12))
		_dist = clampf(_dist * ratio, DIST_MIN, DIST_MAX)
	_dist_goal = _dist
	if env_node.has_method("set_extent"):
		env_node.set_extent(box)
	if not snap:
		_target = old_target
		_dist = old_dist
	_place_camera()

func _place_camera() -> void:
	var cp := cos(_pitch)
	var a := _yaw - _theta
	var floor_y: float = view.floor_y()
	# The reference keeps the creature right of centre (its parts shelf is on the left): slide the view target sideways.
	var look := _target - Vector3(cos(a), 0, -sin(a)) * _dist * .17
	camera.position = look + Vector3(sin(a) * cp, sin(_pitch), cos(a) * cp) * _dist
	camera.position.y = maxf(camera.position.y, floor_y + .3)
	camera.look_at(look, Vector3.UP)
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
	view.set_spine_visible(model.mode == "build" and _spine_hover)
	view.set_playing(model.playing)

# =================================================================== model events
func _on_model_changed(live: bool) -> void:
	_apply_model()
	_update_dna()
	if nest_world != null and nest_cost != null:
		_nest_labels()
	if name_edit and not name_edit.has_focus():
		name_edit.text = str(model.doc.get("name", ""))
	if not live:
		_queue_rebuild()
		if creature_bounds() != _framed_bounds:
			_schedule_frame()

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
	if _drawer_tween != null and _drawer_tween.is_valid(): _drawer_tween.kill()
	nest_panel = null
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
	_wire_presses(hud)
	hint_label = Label.new()
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)   # contextual feedback only; persistent instructions live on Help
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_label.offset_left = 88; hint_label.offset_right = -88
	hint_label.offset_bottom = -16
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.add_theme_color_override("font_color", ThemeFactory.MUTED)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(hint_label)
	_set_hint("")
	_rebuild_panel()
	_sync_history()

func T(s: String) -> String:
	return i18n.tr_(s)

## Compact mode and utility icons; names, language and stats live in Details.
func _icon_button(id: String, label: String) -> Button:
	var b := Button.new()
	b.icon = FlowIcons.make(id)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.tooltip_text = label
	b.custom_minimum_size = Vector2(40, 40)
	return b

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.name = "TopModes"
	bar.position = Vector2(14, 14)
	hud.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	bar.add_child(row)
	top_bar = row
	var back := _icon_button("back", T("Menú"))
	back.pressed.connect(_on_exit)
	row.add_child(back)
	mode_buttons.clear()
	var group := ButtonGroup.new()
	for m in [["build", "Construir"], ["paint", "Pintar"], ["test", "Probar"]]:
		var b := _icon_button(m[0], T(m[1]))
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = model.mode == m[0]
		b.pressed.connect(set_mode.bind(m[0]))
		row.add_child(b)
		mode_buttons[m[0]] = b
	row.add_child(VSeparator.new())
	undo_btn = _icon_button("undo", T("Deshacer") + " · Ctrl+Z")
	undo_btn.name = "UndoButton"
	undo_btn.pressed.connect(on_undo)
	row.add_child(undo_btn)
	redo_btn = _icon_button("redo", T("Rehacer") + " · Ctrl+Y")
	redo_btn.name = "RedoButton"
	redo_btn.pressed.connect(on_redo)
	row.add_child(redo_btn)
	var file_btn := MenuButton.new()
	file_btn.icon = FlowIcons.make("file")
	file_btn.tooltip_text = T("Archivo")
	file_btn.custom_minimum_size = Vector2(40, 40)
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
	row.add_child(file_btn)
	var help := _icon_button("help", T("Rueda sobre una pieza para escalarla · arrastra una articulación o las flechas de la columna · clic en una pata para elegir su actuador"))
	help.tooltip_text += "\n" + ("Botón derecho: orbitar · rueda en vacío: zoom · Ctrl+S: guardar" if lang == "es" else "Right-drag: orbit · wheel on empty space: zoom · Ctrl+S: save")
	help.pressed.connect(func(): _flash(help.tooltip_text))
	row.add_child(help)
	if nest_world == null:
		play_creature_btn = _icon_button("test", T("Jugar con esta criatura"))
		play_creature_btn.name = "PlayCreatureButton"
		play_creature_btn.pressed.connect(play_with_creature)
		row.add_child(play_creature_btn)

## Mouse presses only: keyboard activation never scales or slides a control.
func _wire_presses(node: Node) -> void:
	if node is Button and not node.has_meta("flow_press"):
		node.set_meta("flow_press", true)
		node.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
				node.pivot_offset = node.size / 2
				var prev = node.get_meta("flow_tween", null)
				if prev is Tween and prev.is_valid(): prev.kill()
				var tw := node.create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
				node.set_meta("flow_tween", tw)
				tw.tween_property(node, "scale", Vector2.ONE * (.97 if e.pressed else 1.0), .12))
	for child in node.get_children():
		_wire_presses(child)

func set_details_open(on: bool, animate := false) -> void:
	details_open = on
	if details_button != null: details_button.set_pressed_no_signal(on)
	if _drawer_tween != null and _drawer_tween.is_valid(): _drawer_tween.kill()
	var right := -14.0 if on else 286.0
	if on: right_card.show()
	if animate:
		_drawer_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		_drawer_tween.set_parallel(true)
		_drawer_tween.tween_property(right_card, "offset_left", right - 268, .2)
		_drawer_tween.tween_property(right_card, "offset_right", right, .2)
		if not on: _drawer_tween.chain().tween_callback(right_card.hide)
	else:
		right_card.offset_left = right - 268
		right_card.offset_right = right
		right_card.visible = on

func set_palette_open(on: bool) -> void:
	palette_open = on
	palette_body.visible = on
	palette_card.offset_right = 314 if on else 76
	if on and _palette_timer != null: _palette_timer.stop()

func _maybe_close_palette() -> void:
	if not is_instance_valid(palette_card) or not _drag.is_empty(): return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and palette_card.is_ancestor_of(focus): return
	if not palette_card.get_global_rect().has_point(get_viewport().get_mouse_position()):
		set_palette_open(false)

func _build_palette() -> void:
	var card := PanelContainer.new()
	card.offset_left = 14; card.offset_top = 82
	card.offset_right = 76
	card.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	card.offset_bottom = -16
	card.name = "PaletteCard"
	palette_card = card
	hud.add_child(card)
	_build_dna_card()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	var tab_scroll := ScrollContainer.new()
	tab_scroll.custom_minimum_size.x = 42
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(tab_scroll)
	var tabs := VBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(tabs)
	var col := VBoxContainer.new()
	palette_body = col
	col.custom_minimum_size.x = 224
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	cat_title = Label.new()
	cat_title.name = "CategoryTitle"
	cat_title.add_theme_font_size_override("font_size", 20)
	col.add_child(cat_title)
	_palette_timer = Timer.new()
	_palette_timer.one_shot = true
	_palette_timer.wait_time = .18
	_palette_timer.timeout.connect(_maybe_close_palette)
	card.add_child(_palette_timer)
	card.mouse_exited.connect(func(): _palette_timer.start())
	card.mouse_entered.connect(func(): if model.mode == "build": set_palette_open(true))
	category_tabs.clear()
	category_grids.clear()
	palette_buttons.clear()
	part_thumbs.clear()
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
		tb.name = "Tab_" + c
		tb.toggle_mode = true
		tb.button_group = group
		tb.button_pressed = c == current_category
		tb.tooltip_text = i18n.category(c)
		tb.custom_minimum_size = Vector2(38, 38)
		tb.icon = _thumb_tex(parts_db.ids_in(c)[0], c)
		tb.expand_icon = true
		tb.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tb.add_theme_stylebox_override("normal", ThemeFactory.box(Color(1, 1, 1, .07), Color(0, 0, 0, 0), 19))
		tb.add_theme_stylebox_override("hover", ThemeFactory.box(Color(1, 1, 1, .16), Color(0, 0, 0, 0), 19))
		tb.add_theme_stylebox_override("pressed", ThemeFactory.box(Color(ThemeFactory.AMBER, .18), ThemeFactory.AMBER, 19, 2))
		tb.add_theme_stylebox_override("hover_pressed", ThemeFactory.box(Color(ThemeFactory.AMBER, .26), ThemeFactory.AMBER, 19, 2))
		tb.pressed.connect(func(): select_category(c); set_palette_open(true))
		tb.mouse_entered.connect(func(): if model.mode == "build": select_category(c); set_palette_open(true))
		tb.focus_entered.connect(func(): if model.mode == "build": select_category(c); set_palette_open(true))
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
	cat_title.text = i18n.category(current_category)
	_request_category(current_category)
	set_palette_open(false)

## Compact top-right DNA budget: "129 / 320" and a bar that flashes red when over budget.
func _build_dna_card() -> void:
	var card := PanelContainer.new()
	card.name = "DnaCard"
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.offset_left = -224; card.offset_right = -14
	card.offset_top = 14; card.offset_bottom = 68
	card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	var t := _h2("ADN")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	dna_label = Label.new()
	dna_label.name = "DnaLabel"
	dna_label.add_theme_font_size_override("font_size", 17)
	row.add_child(dna_label)
	details_button = _icon_button("details", "Detalles" if lang == "es" else "Details")
	details_button.toggle_mode = true
	details_button.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			details_button.set_meta("mouse", true)
		elif e is InputEventKey:
			details_button.set_meta("mouse", false))
	details_button.pressed.connect(func():
		set_details_open(not details_open, bool(details_button.get_meta("mouse", false)))
		details_button.set_meta("mouse", false))
	row.add_child(details_button)
	dna_track = Control.new()
	dna_track.custom_minimum_size = Vector2(0, 3)
	var bg := ColorRect.new()
	bg.color = Color(1, 1, 1, .12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dna_track.add_child(bg)
	dna_fill = ColorRect.new()
	dna_fill.name = "DnaFill"
	dna_fill.color = ThemeFactory.AMBER
	dna_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	dna_fill.anchor_right = 0.0
	dna_track.add_child(dna_fill)
	col.add_child(dna_track)
	_update_dna()

func dna_value() -> int:
	var st: Dictionary = view.stats() if view != null and view.has_method("stats") else {}
	return int(st.get("dna", 0))

func _update_dna() -> void:
	if dna_label == null:
		return
	if nest_world != null:
		dna_label.text = "ADN  %d" % int(nest_world.state().social.dna_balance)
		return
	var v := dna_value()
	dna_label.text = "%d / %d" % [v, DNA_BUDGET]
	dna_fill.anchor_right = clampf(float(v) / DNA_BUDGET, 0.0, 1.0)
	dna_fill.color = ThemeFactory.AMBER if v <= DNA_BUDGET else Color("e0533d")

func _thumb_tex(id: String, category: String) -> Texture2D:
	if baker != null and baker.has_texture(id):
		return baker.textures[id]
	if not thumbnails.has(id):
		thumbnails[id] = Thumbs.make(id, category)
	return thumbnails[id]

func _part_tooltip(id: String) -> String:
	var info: Dictionary = parts_db.by_id[id]
	var t: String = i18n.part_name(id) + "  ·  " + str(info.get("dna_cost", 0)) + " " + T("ADN")
	var ab: Array = info.get("illustrative_abilities", [])
	t += "\n" + T("Cosmético") + ((" · " + ", ".join(ab.map(func(a): return T(str(a))))) if not ab.is_empty() else "")
	return t

func _make_part_button(id: String, category: String) -> Button:
	var b := Button.new()
	b.name = "Part_" + id
	b.custom_minimum_size = Vector2(104, 112)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = _part_tooltip(id)
	b.toggle_mode = false
	b.add_theme_stylebox_override("normal", ThemeFactory.box(Color(.44, .83, 1.0, .08), Color(0, 0, 0, 0), 16, 2))
	b.add_theme_stylebox_override("hover", ThemeFactory.box(Color(.44, .83, 1.0, .16), ThemeFactory.AMBER, 16, 2))
	b.add_theme_stylebox_override("pressed", ThemeFactory.box(Color(1, 1, 1, .12), ThemeFactory.AMBER, 16, 2))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var tex := TextureRect.new()          # thumbnail slot
	tex.name = "Thumb"
	tex.custom_minimum_size = Vector2(80, 80)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tex.texture = _thumb_tex(id, category)
	v.add_child(tex)
	var lab := Label.new()
	lab.text = i18n.part_name(id)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 11)
	lab.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lab)
	var badge := Label.new()               # DNA cost pill
	badge.name = "Cost"
	badge.text = str(int(parts_db.by_id[id].get("dna_cost", 0)))
	badge.add_theme_font_size_override("font_size", 11)
	badge.add_theme_color_override("font_color", ThemeFactory.INK)
	badge.add_theme_stylebox_override("normal", ThemeFactory.box(ThemeFactory.AMBER, Color(0, 0, 0, 0), 9))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.position = Vector2(70, 5)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(badge)
	b.gui_input.connect(_palette_input.bind(id))
	b.mouse_entered.connect(_palette_hover.bind(id, true))
	b.mouse_exited.connect(_palette_hover.bind(id, false))
	palette_buttons[id] = b
	part_thumbs[id] = tex
	return b

## Hover: the thumbnail turns live (spinning). Press feedback is shared by all buttons.
func _palette_hover(id: String, on: bool) -> void:
	var b: Button = palette_buttons.get(id)
	if b == null:
		return
	if on:
		_hover_part_id = id
		if baker != null:
			baker.start_hover(id)
			if baker.enabled:
				part_thumbs[id].texture = baker.hover_texture
	elif _hover_part_id == id:
		_hover_part_id = ""
		if baker != null:
			baker.stop_hover()
		part_thumbs[id].texture = _thumb_tex(id, parts_db.by_id[id]["category"])

func _request_category(c: String) -> void:
	if baker != null and baker.enabled:
		baker.request_front(parts_db.ids_in(c))
		for k in parts_db.categories:
			for id in parts_db.ids_in(k):
				baker.request(id)

func _on_thumb_baked(id: String) -> void:
	var cat: String = parts_db.by_id[id]["category"]
	if part_thumbs.has(id) and _hover_part_id != id:
		part_thumbs[id].texture = baker.textures[id]
	if category_tabs.has(cat) and parts_db.ids_in(cat)[0] == id:
		category_tabs[cat].icon = baker.textures[id]

## Integration hook: replace a placeholder thumbnail with a real render.
func set_thumbnail(id: String, tex: Texture2D) -> void:
	thumbnails[id] = tex
	if part_thumbs.has(id):
		part_thumbs[id].texture = tex

func palette_button_count() -> int:
	return palette_buttons.size()

func category_count() -> int:
	return category_tabs.size()

func mode_button_text(m: String) -> String:
	return mode_buttons[m].tooltip_text

func select_category(c: String) -> void:
	current_category = c
	for k in category_grids:
		category_grids[k].visible = k == c
		category_tabs[k].set_pressed_no_signal(k == c)
	if cat_title:
		cat_title.text = i18n.category(c)
	_request_category(c)

# =================================================================== right panel
func _build_right_panel() -> void:
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	card.offset_left = -282; card.offset_right = -14
	card.offset_top = 82; card.offset_bottom = -16
	right_card = card
	hud.add_child(card)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(scroll)
	var content := VBoxContainer.new()
	drawer_content = content
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = T("Ponle nombre")
	name_edit.text = str(model.doc.get("name", ""))
	name_edit.max_length = 80
	name_edit.text_submitted.connect(func(t): model.set_name_(t); name_edit.release_focus())
	name_edit.focus_exited.connect(func(): if name_edit.text != model.doc.get("name", ""): model.set_name_(name_edit.text))
	content.add_child(name_edit)
	var languages := HBoxContainer.new()
	for l in ["es", "en"]:
		var button := Button.new()
		button.text = l.to_upper()
		button.toggle_mode = true
		button.button_pressed = lang == l
		button.pressed.connect(set_lang.bind(l))
		languages.add_child(button)
	content.add_child(languages)
	panel_box = VBoxContainer.new()
	panel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_box.add_theme_constant_override("separation", 8)
	content.add_child(panel_box)
	set_details_open(false)

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
	_wire_presses(panel_box)
	_fit_drawer.call_deferred()

## Paint mode keeps the drawer only as tall as its compact content; every other mode uses the full-height drawer.
func _fit_drawer() -> void:
	if right_card == null or drawer_content == null:
		return
	var scroll := drawer_content.get_parent() as ScrollContainer
	name_edit.visible = model.mode != "paint"
	drawer_content.get_child(1).visible = model.mode != "paint"
	if model.mode == "paint":
		var h := drawer_content.get_combined_minimum_size().y + 20.0
		scroll.custom_minimum_size.y = h
		right_card.anchor_bottom = 0.0
		right_card.offset_bottom = right_card.offset_top + h
	else:
		scroll.custom_minimum_size.y = 0.0
		right_card.anchor_bottom = 1.0
		right_card.offset_bottom = -16.0

## A24: skeleton per body, actuation per limb. Readout "Actuación: <class> - <why>" for the body and for every limb,
## the count of actuation types (informational: the cost is a
## later sim rule). Purely visual for now (docs/godot/CREATURE-REALISM.md). Read-only here: a limb's actuation is
## changed only by clicking the limb (the actuator ring); there is no menu in this panel.
func _actuation_section() -> void:
	var bio: Dictionary = view.creature.bio if "creature" in view and view.creature != null else {}
	if bio.is_empty():
		return
	var C = load("res://creature/creature_bio.gd")
	panel_box.add_child(_h2(T("Actuación")))
	var sk := _note(T("Esqueleto") + ": " + T(C.label(bio["skeleton"])) + " - " + T(bio["skel_why"]))
	sk.name = "SkeletonReadout"
	panel_box.add_child(sk)
	# Identical limbs (same part type, actuation and reason) share one row and one choice.
	var groups := {}
	var order: Array = []
	for idx in bio["limbs"]:
		var L: Dictionary = bio["limbs"][idx]
		var key: String = "%s|%s|%s" % [L["type"], L["act"], L["why"]]
		if not groups.has(key):
			groups[key] = []
			order.append(key)
		groups[key].append(int(idx))
	for key in order:
		var ids: Array = groups[key]
		var L: Dictionary = bio["limbs"][ids[0]]
		var row := _note(T(parts_db_name(L["type"])) + (" x%d" % ids.size() if ids.size() > 1 else "") + ": " + T("Actuación") + ": " + T(C.label(L["act"])) + " - " + T(L["why"]))
		row.name = "Limb_%d" % ids[0]
		panel_box.add_child(row)
	var n := int(bio["act_types"])
	if n > 0:
		var mix := _note(("%d " % n) + (T("tipo de actuación") if n == 1 else T("tipos de actuación")) + (": +%d " % (n - 1) + T("metabolismo") if n > 1 else ""))
		mix.name = "ActuationMix"
		panel_box.add_child(mix)
	panel_box.add_child(HSeparator.new())

func parts_db_name(type: String) -> String:
	return i18n.part_name(type)

## Capabilities (web #caps): 1..5 pips per stat, plus the warnings from the part set.
func _caps_section() -> void:
	var st: Dictionary = view.stats() if view.has_method("stats") else {}
	if st.is_empty():
		return
	panel_box.add_child(_h2(T("Capacidades")))
	for pair in [["Velocidad", "vel"], ["Mordisco", "bite"], ["Canto", "sing"], ["Salud", "hp"]]:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = T(pair[0])
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var pips := HBoxContainer.new()
		pips.name = "Pips_" + pair[1]
		pips.add_theme_constant_override("separation", 3)
		for i in 5:
			var d := ColorRect.new()
			d.custom_minimum_size = Vector2(14, 8)
			d.color = Color("8fd14f") if i < int(st.get(pair[1], 0)) else Color(1, 1, 1, .12)
			d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pips.add_child(d)
		row.add_child(pips)
		panel_box.add_child(row)
	var grip: Dictionary = CporeWorld.grip_profile(JSON.stringify(model.doc))
	var grip_label := _note("Grip: %d°" % int(grip.get("grip_deg", 35)))
	grip_label.name = "GripLimit"
	panel_box.add_child(grip_label)
	_actuation_section()
	for w in st.get("warn", []):
		var wl := _note(T(String(w)))
		wl.add_theme_color_override("font_color", Color("e8a23a"))
		panel_box.add_child(wl)
	panel_box.add_child(HSeparator.new())

func _panel_build() -> void:
	_caps_section()
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
			if not parts_db.is_leg(p["type"]):
				# A24: any mirrored part can be made single (one giant claw, one eye). Which side matters later in the sim.
				var sob := OptionButton.new()
				sob.name = "SideChoice"
				for lbl in ["Pareja (ambos lados)", "Solo derecha", "Solo izquierda"]:
					sob.add_item(T(lbl))
				var cur := int(p.get("single", 0))
				sob.select(0 if cur == 0 else (1 if cur == 1 else 2))
				sob.item_selected.connect(func(i): model.set_part_key(sel, "single", [0, 1, -1][i]))
				panel_box.add_child(sob)
		if p["type"] in ["ojo", "tallo", "eye_triad"]:
			var pob := OptionButton.new()
			pob.name = "PupilChoice"
			var kinds := ["auto", "round", "slit", "bar"]
			for lbl in ["Pupila: según su vida", "Pupila redonda", "Pupila en rendija", "Pupila horizontal"]:
				pob.add_item(T(lbl))
			pob.select(maxi(kinds.find(String(p.get("pupil", "auto"))), 0))
			pob.item_selected.connect(func(i): model.set_part_key(sel, "pupil", kinds[i]))
			panel_box.add_child(pob)
		if WingPanel.is_wing(p):
			WingPanel.build(panel_box, model, view, sel, Callable(self, "T"))
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
	var rb := Button.new()
	rb.text = T("Al azar")
	rb.name = "RandomButton"
	rb.pressed.connect(func(): model.new_random(); frame_creature())
	chips.add_child(rb)
	var cb := Button.new()
	cb.text = T("Copiar genoma")
	cb.name = "CopyButton"
	cb.pressed.connect(copy_genome)
	chips.add_child(cb)
	panel_box.add_child(chips)
	panel_box.add_child(HSeparator.new())
	_regions_section()

func copy_genome() -> void:
	DisplayServer.clipboard_set(JSON.stringify(model.doc))
	_flash(T("Genoma copiado"))

const REGION_FAMILIES := [["horns", "Cuernos"], ["plates", "Placas"], ["tendrils", "Filamentos"]]
const REGION_SURFACES := [["torso", "Torso"], ["neck", "Cuello"], ["tail", "Cola"]]
const REGION_SLIDERS := [["position", "Posición", 0.0, 1.0, .01], ["coverage", "Cobertura", 0.0, 1.0, .01],
	["angle", "Ángulo", -3.14, 3.14, .01], ["length", "Largo", .2, 2.4, .05], ["count", "Cantidad", 1, 18, 1],
	["curve", "Curvatura", -1.0, 1.0, .05], ["branches", "Ramas", 0, 3, 1]]

## Growth regions (web growthPanel): horns, plates and tendrils laid on the body; cosmetic only.
func _regions_section() -> void:
	panel_box.add_child(_h2(T("Regiones")))
	var regs: Array = model.doc["regions"]
	var chips := HFlowContainer.new()
	for i in regs.size():
		var b := Button.new()
		b.name = "Region_%d" % i
		var fam := "Cuernos"
		for f in REGION_FAMILIES:
			if f[0] == regs[i]["family"]:
				fam = f[1]
		b.text = "%s %d" % [T(fam), i + 1]
		b.toggle_mode = true
		b.button_pressed = i == model.selected_region
		b.pressed.connect(func(): model.selected_region = i; model.selected = -1; model.selection_changed.emit())
		chips.add_child(b)
	panel_box.add_child(chips)
	var acts := HFlowContainer.new()
	var add := Button.new()
	add.name = "AddRegion"
	add.text = T("Añadir región")
	add.disabled = regs.size() >= Model.MAX_REGIONS
	add.pressed.connect(func(): model.add_region(false))
	acts.add_child(add)
	var r_ok: bool = model.selected_region >= 0 and model.selected_region < regs.size()
	if r_ok:
		var dup := Button.new()
		dup.text = T("Duplicar")
		dup.name = "DuplicateRegion"
		dup.disabled = regs.size() >= Model.MAX_REGIONS
		dup.pressed.connect(func(): model.add_region(true))
		acts.add_child(dup)
		var del := Button.new()
		del.text = T("Eliminar")
		del.name = "DeleteRegion"
		del.pressed.connect(func(): model.delete_region())
		acts.add_child(del)
	panel_box.add_child(acts)
	if r_ok:
		var r: Dictionary = regs[model.selected_region]
		for pair in [["family", REGION_FAMILIES, "Forma"], ["surface", REGION_SURFACES, "Superficie"]]:
			var row := HBoxContainer.new()
			var l := Label.new()
			l.text = T(pair[2])
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(l)
			var ob := OptionButton.new()
			ob.name = "Opt_" + pair[0]
			var sel_i := 0
			for j in pair[1].size():
				ob.add_item(T(pair[1][j][1]), j)
				if pair[1][j][0] == r[pair[0]]:
					sel_i = j
			ob.select(sel_i)
			var key: String = pair[0]
			var opts: Array = pair[1]
			ob.item_selected.connect(func(j): model.set_region(key, opts[j][0]))
			row.add_child(ob)
			panel_box.add_child(row)
		for sp in REGION_SLIDERS:
			var key: String = sp[0]
			panel_box.add_child(_slider_row(T(sp[1]), float(r[key]), sp[2], sp[3], sp[4], func(v): model.set_region(key, v)))
		var mir := CheckBox.new()
		mir.text = T("Espejo")
		mir.button_pressed = bool(r["mirror"])
		mir.toggled.connect(func(on): model.set_region("mirror", on))
		panel_box.add_child(mir)
		panel_box.add_child(_note("%s: %d" % [T("Semilla"), int(r["seed"])]))
		var vary := Button.new()
		vary.text = T("Nueva variante")
		vary.name = "VaryRegion"
		vary.pressed.connect(func(): model.vary_region())
		panel_box.add_child(vary)
	panel_box.add_child(_note(T("Detalles artísticos; no cambian las capacidades.")))

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
	var more_btn := Button.new()
	more_btn.name = "PaintMore"
	more_btn.toggle_mode = true
	more_btn.button_pressed = _paint_more
	more_btn.text = T("Más")
	more_btn.pressed.connect(func(): _paint_more = more_btn.button_pressed; _queue_rebuild())
	panel_box.add_child(more_btn)
	var more := VBoxContainer.new()
	more.name = "PaintMoreBox"
	more.visible = _paint_more
	panel_box.add_child(more)
	more.add_child(_slider_row(T("Escama"), s["scale"], 3, 14, .5, func(v): model.set_skin("scale", v)))
	more.add_child(_slider_row(T("Brillo"), s["wet"], 0, 1, .01, func(v): model.set_skin("wet", v)))
	# Realism pilot controls (optional genome keys, previewed live): countershading and pattern tuning.
	more.add_child(_note(T("Biología")))
	more.add_child(_slider_row(T("Contrasombreado"), s.get("cs", .5), 0, 1, .01, func(v): model.set_skin("cs", v)))
	if int(s["pat"]) > 0:
		more.add_child(_slider_row(T("Tamaño del dibujo"), s.get("ps", 1.0), .5, 2, .05, func(v): model.set_skin("ps", v)))
		more.add_child(_slider_row(T("Contraste del dibujo"), s.get("pc", 1.0), 0, 1, .01, func(v): model.set_skin("pc", v)))
	if int(s["pat"]) == 2:
		var ros := CheckBox.new()
		ros.text = T("Rosetas")
		ros.name = "Rosettes"
		ros.button_pressed = int(s.get("ros", 0)) == 1
		ros.toggled.connect(func(on): model.set_skin("ros", 1 if on else 0))
		more.add_child(ros)
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
	panel_box.add_child(HSeparator.new())
	_caps_section()
	panel_box.add_child(_h2(T("Acciones")))
	var acts := HFlowContainer.new()
	for a in [["bite", "Morder"], ["sing", "Cantar"]]:
		var ab := Button.new()
		ab.name = "Act_" + a[0]
		ab.text = T(a[1])
		var act: String = a[0]
		ab.pressed.connect(func(): do_action(act))
		acts.add_child(ab)
	var run := Button.new()
	run.name = "Act_run"
	run.toggle_mode = true
	run.button_pressed = _run
	run.text = T("Andar") if _run else T("Correr")
	run.pressed.connect(toggle_run)
	acts.add_child(run)
	panel_box.add_child(acts)
	panel_box.add_child(_note(T("Tu criatura camina sola: nada está animado a mano")))
	panel_box.add_child(_note(T("Cosmético")))

# =================================================================== actions (shared by UI, keys and tests)
var _run := false

func do_action(a: String) -> void:
	view.trigger(a)

func toggle_run() -> void:
	_run = not _run
	view.set_run(_run)
	_queue_rebuild()

func set_mode(m: String) -> void:
	_cancel_drag()
	_pending_type = ""
	model.set_mode(m)
	if env_node.has_method("set_test_mode"):
		env_node.set_test_mode(m == "test")
	overlay.queue_redraw()
	for k in mode_buttons:
		mode_buttons[k].set_pressed_no_signal(k == m)
	_set_hint("")
	if palette_card != null:               # the palette only works while building
		palette_card.modulate = Color.WHITE if m == "build" else Color(1, 1, 1, 0.0)
		palette_card.mouse_filter = Control.MOUSE_FILTER_STOP if m == "build" else Control.MOUSE_FILTER_IGNORE
	set_palette_open(false)
	set_details_open(m != "build")
	_queue_rebuild()

func set_lang(l: String) -> void:
	lang = l
	i18n.lang = l
	_build_hud()
	_apply_model()
	if nest_world != null:
		_build_nest_shop()

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
		0: model.new_from_seed(_starter_seed()); frame_creature()
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
	hint_label.text = T(t)
	hint_label.visible = t != ""

func _flash(t: String) -> void:
	hint_label.text = t
	hint_label.show()
	_flash_timer = 2.6

# =================================================================== input
func _set_hover(n: int) -> void:
	_hover_node = n
	if n < 0:
		_spine_hover = false
		_arrow_hot = ""
		_hover_leg = -1
		view.set_hover_leg(-1)
		view.set_hover_node(-1)
		view.set_hover_part(-1)
		view.set_bead_hot(false)
		view.set_spine_visible(false)

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	var ctrl: bool = e.ctrl_pressed or e.meta_pressed
	match e.keycode:
		KEY_ESCAPE:
			var busy: bool = not _drag.is_empty() or _pending_type != ""
			_cancel_drag()
			_pending_type = ""
			_set_hint("")
			if nest_world != null:
				get_viewport().set_input_as_handled()      # never reaches the game menu behind the overlay
				if not busy:
					_on_exit()             # in the nest, Esc with nothing in hand cancels the edit and leaves (the same as the Menu button)
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
	if e is InputEventMouseButton or e is InputEventKey:
		_idle = 0.0
	# palette drags end anywhere on screen
	if _drag.get("kind", "") == "new":
		if e is InputEventMouseMotion:
			_mouse = e.position
			if _drag["moved"]:
				_update_new_drag(e.position)
		elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			_finish_new_drag(e.position)

func _palette_input(e: InputEvent, id: String) -> void:
	if model.mode != "build":
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
		_cancel_drag()
		_drag = {"kind": "new", "type": id, "start": get_viewport().get_mouse_position(), "moved": false, "idx": -1, "tx": false, "over": false}
		_pending_type = ""
		_ghost.texture = _thumb_tex(id, parts_db.by_id[id]["category"])
		_ghost.modulate = Color.WHITE
		_ghost.visible = true
		_ghost.position = get_viewport().get_mouse_position() - Vector2(52, 52)
		_set_hint("Llévala hasta el cuerpo de la criatura")
		_click()
	elif e is InputEventMouseMotion and _drag.get("kind", "") == "new":
		if not _drag["moved"] and (get_viewport().get_mouse_position() - _drag["start"]).length() > 6.0:
			_drag["moved"] = true
			_update_new_drag(get_viewport().get_mouse_position())

## While a palette part is dragged: over the body the real part is in the document and follows the cursor
## (snapped, real orientation, mirrored); off the body only the thumbnail ghost follows.
func _update_new_drag(gpos: Vector2) -> void:
	var d := _drag
	var local := gpos - stage.global_position
	var inside := Rect2(Vector2.ZERO, stage.size).has_point(local) and not _over_hud(gpos)
	var h := _hit_body(local) if inside else {}
	d["over"] = not h.is_empty()
	if d["over"]:
		if d["idx"] < 0:
			model.begin()
			d["tx"] = true
			d["idx"] = model.add_part(d["type"], h["t"], h["ang"])
		else:
			model.place_part(d["idx"], h["t"], h["ang"])
		d["point"] = h["point"]
	elif d["idx"] >= 0:
		model.remove_part(d["idx"])
		d["idx"] = -1
	_ghost.visible = not d["over"]
	_ghost.position = gpos - Vector2(52, 52)
	_ghost.modulate = Color.WHITE if inside else Color(1, .55, .5, .9)
	_set_hint("Suelta para colocar" if d["over"] else "Llévala hasta el cuerpo de la criatura")
	overlay.queue_redraw()

func _finish_new_drag(pos: Vector2) -> void:
	var d := _drag
	_drag = {}
	_ghost.visible = false
	if not d["moved"]:
		_pending_type = d["type"]          # click: then click the body to place
		_flash(T("Toca el cuerpo para colocar"))
	else:
		if d["idx"] >= 0:
			model.end()
			_dropped(d["idx"], d.get("point", Vector3.ZERO))
		elif d["tx"]:
			model.cancel()
		_set_hint("")
	set_palette_open(false)
	overlay.queue_redraw()

## Drop feedback: the part pops, a ring spreads on the surface, a click.
func _dropped(idx: int, point: Vector3) -> void:
	view.pulse_part(idx)
	_drop_fx = {"point": point, "t": 0.0}
	creator_ev("part_placed", {"idx": idx})
	creator_ev("drop_ring", {"idx": idx})
	_click()
	_puff_fx = {"point": point, "t": 0.0}
	creator_ev("puff_spawned", {"idx": idx})
	_popup_wait = {"t": 0.0, "cost": maxi(0, dna_value() - _dna_ref), "point": point}
	_tick_counter(dna_value() > DNA_BUDGET)
	if view.has_method("look_at_part"):
		view.look_at_part(idx)
	if dna_value() > DNA_BUDGET:
		_flash(T("No cabe: supera el presupuesto de ADN"))

func _dna_panel() -> Control:
	var n: Node = dna_label
	while n != null and not (n is PanelContainer):
		n = n.get_parent()
	return n as Control

## Counter tick: a short press-style pulse (1 -> 1.06 -> 1, ease-out); a red shake when the part does not fit.
func _tick_counter(over: bool) -> void:
	var panel := _dna_panel()
	if panel == null:
		return
	if _fx_tween != null and _fx_tween.is_valid():
		_fx_tween.kill()
	panel.pivot_offset = panel.size / 2.0
	_fx_tween = create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if over:
		panel.modulate = Color(1.0, .55, .5)
		for k in 4:
			_fx_tween.tween_property(panel, "rotation_degrees", (3.0 if k % 2 == 0 else -3.0) * (1.0 - float(k) / 4.0), .045)
		_fx_tween.tween_property(panel, "rotation_degrees", 0.0, .05)
		_fx_tween.tween_property(panel, "modulate", Color.WHITE, .2)
	else:
		_fx_tween.tween_property(panel, "scale", Vector2.ONE * 1.06, .08)
		_fx_tween.tween_property(panel, "scale", Vector2.ONE, .16)

## Floating "+N": appears ~0.3 s after the drop beside the part, rises and fades over 0.45 s (ease-out), then is gone.
func _tick_drop_fx(dt: float) -> void:
	if not _puff_fx.is_empty():
		_puff_fx["t"] += dt
		if _puff_fx["t"] > PUFF_LEN:
			_puff_fx = {}
	if not _popup_wait.is_empty():
		_popup_wait["t"] += dt
		if _popup_wait["t"] >= POPUP_DELAY:
			_popup_point = _popup_wait["point"]
			_popup_t = 0.0
			if _popup != null:
				_popup.queue_free()
			_popup = Label.new()
			_popup.name = "CostPopup"
			_popup.text = "+%d" % int(_popup_wait["cost"])
			_popup.add_theme_font_size_override("font_size", 24)
			_popup.add_theme_color_override("font_color", Color("8fe36a"))
			_popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, .75))
			_popup.add_theme_constant_override("outline_size", 5)
			_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(_popup)
			_popup_wait = {}
			creator_ev("cost_popup_shown", {"cost": int(_popup.text.substr(1))})
	if _popup != null:
		_popup_t += dt
		var k := clampf(_popup_t / POPUP_LIFE, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		var off := stage.global_position - overlay.global_position
		if camera != null and not camera.is_position_behind(_popup_point):
			_popup.position = camera.unproject_position(_popup_point) + off + Vector2(10, -18 - POPUP_RISE * e)
		_popup.modulate.a = 1.0 if k < .4 else 1.0 - (k - .4) / .6
		if k >= 1.0:
			var c := int(_popup.text.substr(1))
			_popup.queue_free()
			_popup = null
			creator_ev("cost_popup_hidden", {"cost": c})

func _over_hud(global_pos: Vector2) -> bool:
	for c in hud.get_children():
		if c is PanelContainer and c.is_visible_in_tree() and c.get_global_rect().has_point(global_pos):
			return true
	return false

func _cancel_drag() -> void:
	_close_ring()
	if _drag.get("tx", false):
		model.cancel()
	if _drag.get("kind", "") == "part":
		view.hide_part(-1, false)
	view.set_active_node(-1)
	_drag = {}
	if _ghost:
		_ghost.visible = false
	if _wheel_open:
		_close_wheel_tx()

func _stage_input(e: InputEvent) -> void:
	_idle = 0.0
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
	# screen-space handles for the selected part: {c: centre, rot: Vector2 (3D bead projected), tilt: Vector2 or null, joints: [...]}
	if model.mode != "build" or model.selected < 0 or model.selected >= model.doc["parts"].size() or model.playing:
		return {}
	var a: Dictionary = view.part_anchor(model.selected)
	if a.is_empty() or camera.is_position_behind(a["pos"]):
		return {}
	var p: Dictionary = model.doc["parts"][model.selected]
	var c := camera.unproject_position(a["pos"])
	var out := {"c": c}
	if not parts_db.is_leg(p["type"]):
		var bp: Vector3 = view.rot_handle_pos(model.selected)
		if bp != Vector3.ZERO and not camera.is_position_behind(bp):
			out["rot"] = camera.unproject_position(bp)
		else:
			out["rot"] = c + Vector2(cos(p.get("rot", 0.0)), -sin(p.get("rot", 0.0))) * 52.0
		out["tilt"] = c + Vector2(-64.0, -p.get("tilt", 0.0) * 40.0)
	return out

## Joint handles of the limb under the cursor, else of the selected leg: always live, no mode switch.
func _joint_handles() -> Array:
	var js := []
	if model.mode != "build" or model.playing:
		return js
	var leg: int = view.handle_leg()
	if leg < 0:
		return js
	for h in view.leg_handles(leg):
		if not camera.is_position_behind(h.pos):
			js.append({"joint": h.joint, "side": h.side, "screen": camera.unproject_position(h.pos), "leg": leg})
	return js

func _near_joint(pos: Vector2) -> Dictionary:
	for j in _joint_handles():
		if pos.distance_to(j["screen"]) < HANDLE_PX:
			return j
	return {}

## The two spine arrows: {head|tail: {pos, dir, node, off}} in stage pixels. head = last node (neck and head), tail = node 0.
func spine_arrows() -> Dictionary:
	var out := {}
	if model.mode != "build" or model.playing:
		return out
	var pts: PackedVector3Array = view.spine_node_positions()
	var N: Array = model.doc["nodes"]
	if pts.size() < 4 or pts.size() != N.size():
		return out
	for head in [true, false]:
		var i: int = pts.size() - 1 if head else 0
		var j: int = i - 1 if head else 1
		var d3 := (pts[i] - pts[j]).normalized()
		var pixel_world := 2.0 * _dist * tan(deg_to_rad(camera.fov) / 2.0) / maxf(stage.size.y, 1.0)
		var off3 := d3 * (float(N[i]["r"]) + pixel_world * 34.0)
		if camera.is_position_behind(pts[i] + off3):
			continue
		var sp := camera.unproject_position(pts[i])
		var sa := camera.unproject_position(pts[i] + off3)
		var dir := (sa - sp).normalized() if sa.distance_to(sp) > 1.0 else Vector2.RIGHT
		out["head" if head else "tail"] = {"pos": sa, "dir": dir, "node": i, "off": Vector2(off3.y, off3.z)}
	return out

func _arrow_at(pos: Vector2, radius: float) -> String:
	var best := ""
	var bd := radius
	var arr := spine_arrows()
	for k in arr:
		var d: float = pos.distance_to(arr[k]["pos"])
		if d < bd:
			bd = d
			best = k
	return best

func _click() -> void:
	if _click_sound != null and _click_sound.stream != null:
		_click_sound.play()

func _stage_press(e: InputEventMouseButton) -> void:
	_cancel_drag()
	var pos: Vector2 = e.position
	if model.mode != "build":
		_drag = {"kind": "cam", "last": pos, "moved": false}
		return
	if _pending_type != "":
		var h := _hit_body(pos)
		if not h.is_empty():
			var idx: int = model.add_part(_pending_type, h["t"], h["ang"])
			_dropped(idx, h["point"])
			_pending_type = ""
			_set_hint("")
		else:
			_flash(T("Llévala hasta el cuerpo de la criatura"))
		return
	var hs := _handles()
	if not hs.is_empty():
		if hs.has("rot") and pos.distance_to(hs["rot"]) < 14.0:
			model.begin()
			_drag = {"kind": "rot", "tx": true}
			return
		if hs.has("tilt") and pos.distance_to(hs["tilt"]) < 11.0:
			model.begin()
			_drag = {"kind": "tilt", "tx": true, "origin": hs["c"]}
			return
	var jh := _near_joint(pos)
	if not jh.is_empty():
		if jh["leg"] != model.selected:
			model.select(jh["leg"])
		model.begin()
		_drag = {"kind": "joint", "tx": true, "joint": jh["joint"], "side": jh["side"], "leg": jh["leg"]}
		return
	var ak := _arrow_at(pos, ARROW_PX) if (_spine_hover or view.spine_alpha() > .3) else ""
	if ak != "":
		var arr: Dictionary = spine_arrows()[ak]
		model.begin()
		_drag = {"kind": "end", "tx": true, "head": ak == "head", "off": arr["off"]}
		view.set_active_node(arr["node"])
		_set_hint("Suelta para fijar")
		return
	var r := _stage_ray(pos)
	var n: int = view.hit_node(r[0], r[1])
	if n >= 0:
		model.begin()
		_drag = {"kind": "node", "node": n, "tx": true}
		view.set_active_node(n)
		_set_hint("Suelta para fijar")
		return
	var pi: int = view.hit_part(r[0], r[1])
	if pi >= 0:
		model.select(pi)
		_drag = {"kind": "part", "part": pi, "start": pos, "moved": false, "t0": Time.get_ticks_msec()}
		return
	_drag = {"kind": "cam", "last": pos, "moved": false}

func _stage_motion(e: InputEventMouseMotion) -> void:
	var pos: Vector2 = e.position
	var k: String = _drag.get("kind", "")
	match k:
		"":
			var over_hud := _over_hud(e.global_position)
			if model.mode == "build" and not over_hud:
				var r := _stage_ray(pos)
				var n: int = view.hit_node(r[0], r[1])
				var hs := _handles()
				var bead: bool = hs.has("rot") and pos.distance_to(hs["rot"]) < 14.0
				var joint: bool = not _near_joint(pos).is_empty()
				var raw: int = view.hit_part(r[0], r[1])
				var leg: int = raw if (raw >= 0 and parts_db.is_leg(model.doc["parts"][raw]["type"])) else -1
				if leg < 0 and joint:
					leg = _hover_leg      # the foot handle can sit off the mesh: keep the leg while the pointer is on it
				if leg != _hover_leg:
					_hover_leg = leg
					view.set_hover_leg(leg)
				var arrow := _arrow_at(pos, ARROW_PX) if (_spine_hover or view.spine_alpha() > .3) else ""
				var pi: int = -1 if (n >= 0 or bead or joint or arrow != "") else raw
				var over_body: bool = n >= 0 or not view.hit_body(r[0], r[1]).is_empty()
				_hover_node = n
				view.set_hover_node(n)
				view.set_hover_part(pi)
				view.set_bead_hot(bead)
				_arrow_hot = arrow
				# the arrows sit just beyond the body: stay in "spine hover" while travelling to them
				var was_hover := _spine_hover
				_spine_hover = over_body or arrow != "" or (_spine_hover and _arrow_at(pos, ARROW_NEAR_PX) != "")
				if _spine_hover and not was_hover:
					creator_ev("handle_shown", {"kind": "spine_arrows"})
				view.set_spine_visible(_spine_hover)
				if _pending_type != "":
					stage.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if not view.hit_body(r[0], r[1]).is_empty() else Control.CURSOR_FORBIDDEN
				else:
					stage.mouse_default_cursor_shape = Control.CURSOR_MOVE if (n >= 0 or bead or joint or arrow != "") else (Control.CURSOR_POINTING_HAND if pi >= 0 else Control.CURSOR_DRAG)
			elif model.mode != "build":
				stage.mouse_default_cursor_shape = Control.CURSOR_DRAG
		"cam":
			_yaw -= e.relative.x * .006
			_pitch = clampf(_pitch + e.relative.y * .004, -.02, 1.2)
			_drag["moved"] = true
		"node":
			var o: Vector3 = _stage_ray(pos)[0]
			var d: Vector3 = _stage_ray(pos)[1]
			if absf(d.x) > 1e-4:
				var s := -o.x / d.x
				if s > 0.0:
					_drag["node"] = model.move_node(_drag["node"], o.y + d.y * s, o.z + d.z * s)
					view.set_active_node(_drag["node"])
		"part":
			if not _drag["moved"] and pos.distance_to(_drag["start"]) < CLICK_PX:
				return
			if not _drag["moved"]:
				_drag["moved"] = true
				model.begin()
				_drag["tx"] = true
			var h := _hit_body(pos)
			_drag["over"] = not h.is_empty()
			if _drag["over"]:
				model.place_part(_drag["part"], h["t"], h["ang"])
				_drag["point"] = h["point"]
			# off the body the part is hidden and its thumbnail (tinted red = will be removed) follows the cursor
			view.hide_part(_drag["part"], not _drag["over"])
			_ghost.visible = not _drag["over"]
			if _ghost.visible:
				_ghost.texture = _thumb_tex(model.doc["parts"][_drag["part"]]["type"], "")
				_ghost.modulate = Color(1, .55, .5, .9)
				_ghost.position = get_viewport().get_mouse_position() - Vector2(52, 52)
			_set_hint("Suelta para colocar" if _drag["over"] else "Suelta fuera del cuerpo para quitar la pieza")
		"rot":
			var r2 := _stage_ray(pos)
			var a: float = view.rot_from_ray(model.selected, r2[0], r2[1])
			if not is_nan(a):
				model.set_param(model.selected, "rot", a)
			_set_hint("Gira la pieza alrededor de su base")
		"tilt":
			model.set_param(model.selected, "tilt", -(pos.y - _drag["origin"].y) / 40.0)
		"end":
			var re := _stage_ray(pos)
			if absf(re[1].x) > 1e-4:
				var se: float = -re[0].x / re[1].x
				if se > 0.0:
					var idx: int = model.doc["nodes"].size() - 1 if _drag["head"] else 0
					var o2: Vector2 = _drag["off"]
					idx = model.bend_end(idx, re[0].y + re[1].y * se - o2.x, re[0].z + re[1].z * se - o2.y)
					view.set_active_node(idx)
					_set_hint("Columna: %d vértebras · límite" % model.doc["nodes"].size() if model.end_capped else "")
		"joint":
			var r3 := _stage_ray(pos)
			var res: Dictionary = view.leg_drag(_drag["leg"], _drag["joint"], _drag["side"], r3[0], r3[1], -camera.global_transform.basis.z)
			if not res.is_empty():
				model.set_leg_joint(_drag["leg"], res["key"], res["value"])
			_set_hint("El pie se desliza por el suelo" if _drag["joint"] == "f" else "Suelta para fijar la rodilla")

func _stage_release(_e: InputEventMouseButton) -> void:
	var d := _drag
	_drag = {}
	_ghost.visible = false
	match d.get("kind", ""):
		"cam":
			if not d["moved"] and model.mode == "build":
				model.select(-1)
		"part":
			if not d["moved"]:
				if Time.get_ticks_msec() - int(d.get("t0", 0)) <= CLICK_MS:
					_open_ring(d["part"])
			if d["moved"]:
				view.hide_part(-1, false)
				if d.get("over", true):
					model.end()
					_dropped(d["part"], d.get("point", Vector3.ZERO))
				else:
					model.remove_part(d["part"])
					model.end()
					_click()
				_set_hint("")
		"node", "rot", "tilt", "joint", "end":
			model.end()
			view.set_active_node(-1)
			_set_hint("")
	overlay.queue_redraw()

func _stage_wheel(dir: float, pos: Vector2) -> void:
	if model.mode == "build" and not model.playing:
		var r := _stage_ray(pos)
		var n: int = view.hit_node(r[0], r[1])
		if n >= 0:
			_wheel_tx()
			_girth_fx = .6
			model.set_node_radius(n, model.doc["nodes"][n]["r"] * (1.0 + dir * .08))
			return
		var pi: int = view.hit_part(r[0], r[1])
		if pi >= 0 and pi < model.doc["parts"].size():
			wheel_scale_part(pi, dir, pos)
			return
	_dist_goal = clampf(_dist_goal * (1.0 - dir * .08), DIST_MIN, DIST_MAX)

## Wheel over a part scales it (up = in = bigger), clamped to the genome limits, both sides of a pair together.
func wheel_scale_part(pi: int, dir: float, pos := Vector2.ZERO) -> Dictionary:
	_wheel_tx()
	var res: Dictionary = model.scale_part(pi, 1.0 + dir * .06)
	if res.is_empty():
		return res
	var label := T("Largo") if res["kind"] == "reach" else T("Tamaño")
	_scale_fx = {"pos": pos, "text": "%s %.2f" % [label, res["value"]], "limit": res["at_limit"], "t": 1.2}
	return res

func _wheel_tx() -> void:
	if not _wheel_open:
		model.begin()
		_wheel_open = true
	_wheel_timer.start()

func _close_wheel_tx() -> void:
	if _wheel_open:
		_wheel_open = false
		model.end()
		_schedule_frame()

# =================================================================== actuator ring
## A click (not a drag) on a limb opens the ring of actuators around it.
func _limb_bio() -> Dictionary:
	if "creature" in view and view.creature != null and view.creature.bio is Dictionary:
		return view.creature.bio
	return {}

func _limb_centre(i: int) -> Vector2:
	var a: Dictionary = view.part_anchor(i)
	if a.is_empty():
		return Vector2.ZERO
	var pts := [camera.unproject_position(a["pos"])]
	if parts_db.is_leg(model.doc["parts"][i]["type"]):
		for h in view.leg_handles(i):
			if h.joint == "f" and h.side == 1 and not camera.is_position_behind(h.pos):
				pts.append(camera.unproject_position(h.pos))
	var c := Vector2.ZERO
	for q in pts:
		c += q
	return c / float(pts.size()) + stage.global_position - global_position

func _open_ring(i: int, animate := true) -> bool:
	if model.mode != "build" or model.playing:
		return false
	var bio := _limb_bio()
	var opts: Array = model.actuation_options(bio, i)
	if opts.is_empty():
		return false
	_close_ring()
	var labels := {"muscle": "Músculo", "hydraulic": "Hidráulico", "exo": "Exoesqueleto", "hydrostat": "Hidrostático"}
	for o in opts:
		o["label"] = T(labels[o["id"]])
		o["why"] = T(ring_why(o))
	_ring = Ring.new()
	_ring.name = "ActuatorRing"
	add_child(_ring)
	_ring_part = i
	_ring.open(_limb_centre(i), opts, animate)
	_ring.picked.connect(_ring_picked)
	_ring.hint.connect(func(t): _set_hint(t))
	_ring.closed.connect(func(): _ring = null; _ring_part = -1)
	return true

## Why a ring choice is dimmed (A31): it needs the body skeleton the body cannot take. Spanish source text, translated by T.
func ring_why(o: Dictionary) -> String:
	if "exo" in o.get("skels", []) and not "endo" in o.get("skels", []):
		return "Necesita exoesqueleto: añade placas"
	if "endo" in o.get("skels", []):
		return "Necesita esqueleto interno: quita las placas"
	return "Este cuerpo no puede llevar esa actuación"

func _ring_picked(id: String) -> void:
	if _ring_part >= 0:
		model.set_limb_actuation(_limb_bio(), _ring_part, id)
		_click()

func _close_ring() -> void:
	if _ring != null and is_instance_valid(_ring):
		_ring.close()
	_ring = null
	_ring_part = -1

func ring_open() -> bool:
	return _ring != null and is_instance_valid(_ring)

# =================================================================== overlay (handles, ghost, placement cursor)
func _draw_overlay() -> void:
	var off := stage.global_position - overlay.global_position
	var hs := _handles()
	_draw_arrows(off)
	_draw_scale_readout(off)
	if hs.has("tilt"):
		# blue tilt slider (Godot-only; the web studio has a slider for it)
		var tc: Vector2 = hs["c"] + off + Vector2(-64, 0)
		overlay.draw_line(tc + Vector2(0, -52), tc + Vector2(0, 52), Color(ThemeFactory.SKY, .35), 1.5)
		overlay.draw_circle(hs["tilt"] + off, 8, ThemeFactory.SKY)
	# placement marker: green ring when the cursor is on the body (valid), red when it is not
	var placing: bool = (_drag.get("kind", "") == "new" and _drag["moved"]) or _pending_type != ""
	if placing:
		var pos := (_mouse - stage.global_position)
		var h := _hit_body(pos)
		if not h.is_empty():
			var sp := camera.unproject_position(h["point"]) + off
			overlay.draw_arc(sp, 14, 0, TAU, 32, ThemeFactory.MOSS, 3.0, true)
		elif _pending_type != "":
			overlay.draw_arc(pos + off, 12, 0, TAU, 24, ThemeFactory.DANGER, 2.5, true)
	if not _drop_fx.is_empty():
		var t: float = _drop_fx["t"]
		var p3: Vector3 = _drop_fx["point"]
		if t < .5 and not camera.is_position_behind(p3):
			var sp2 := camera.unproject_position(p3) + off
			overlay.draw_arc(sp2, 10 + t * 70.0, 0, TAU, 40, Color(ThemeFactory.AMBER, 1.0 - t / .5), 3.0, true)
	if not _puff_fx.is_empty() and not camera.is_position_behind(_puff_fx["point"]):
		var pk: float = float(_puff_fx["t"]) / PUFF_LEN
		var pe := 1.0 - pow(1.0 - pk, 3.0)
		var pc := camera.unproject_position(_puff_fx["point"]) + off
		for i in 9:
			var a := float(i) / 9.0 * TAU + .4
			overlay.draw_circle(pc + Vector2(cos(a), sin(a) * .7) * (8.0 + 30.0 * pe), 4.0 + 6.0 * pe, Color(.96, .94, .88, .55 * (1.0 - pk)))
	if _girth_fx > 0.0 and _hover_node >= 0:
		var pts: PackedVector3Array = view.spine_node_positions()
		if _hover_node < pts.size() and not camera.is_position_behind(pts[_hover_node]):
			var rr: float = model.doc["nodes"][_hover_node]["r"]
			var sp3 := camera.unproject_position(pts[_hover_node]) + off
			var edge := camera.unproject_position(pts[_hover_node] + camera.global_transform.basis.x * rr) + off
			overlay.draw_arc(sp3, sp3.distance_to(edge), 0, TAU, 48, Color(ThemeFactory.AMBER, clampf(_girth_fx / .6, 0.0, 1.0)), 2.5, true)


# A25: the world stays paused. Trying parts, levels, paint and layout is free; "Aplicar" (apply) keeps the
# same generation and never spends DNA; "Evolucionar" (Evolve) is the only action that spends DNA and starts
# a new generation, and C prices and validates it atomically.
func _build_nest_shop() -> void:
	nest_actions = []
	var panel := PanelContainer.new()
	nest_panel = panel
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	drawer_content.add_child(panel)
	drawer_content.move_child(panel, panel_box.get_index())
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	nest_status = Label.new()
	nest_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nest_status.custom_minimum_size.x = 232
	rows.add_child(nest_status)
	nest_choice = OptionButton.new()
	nest_choice.custom_minimum_size.y = 44
	rows.add_child(nest_choice)
	for kind in 3:
		var b := Button.new()
		b.custom_minimum_size.y = 44
		b.pressed.connect(_nest_try.bind(kind))
		rows.add_child(b)
		nest_actions.append(b)
	nest_cost = Label.new()
	nest_cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(nest_cost)
	nest_apply_button = Button.new()
	nest_apply_button.custom_minimum_size.y = 44
	nest_apply_button.pressed.connect(_nest_apply)
	rows.add_child(nest_apply_button)
	nest_evolve_button = Button.new()
	nest_evolve_button.custom_minimum_size.y = 44
	nest_evolve_button.pressed.connect(_nest_confirm)
	rows.add_child(nest_evolve_button)
	nest_choice.item_selected.connect(func(_i: int) -> void: _nest_labels())
	nest_choice.clip_text = true
	for b in [nest_apply_button, nest_evolve_button] + nest_actions:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART      # long Spanish labels wrap inside the column instead of widening it
	_nest_refresh()
	_wire_presses(nest_panel)


func _nest_row(id: String) -> Dictionary:
	for row in nest_rows:
		if row.id == id:
			return row
	return {}

func _nest_target(id: String) -> Dictionary:
	var row := _nest_row(id)
	var t: Dictionary = nest_plan.get(id, {})
	return {"level": int(t.get("level", row.get("level", 1) if row.get("owned", false) else 1)), "tier": int(t.get("tier", row.get("tier", 0) if row.get("owned", false) else 0))}

## Pending DNA of everything the sketch adds (display only; C prices it again on Evolve).
func nest_pending_cost() -> int:
	var seen := {}
	var total := 0
	for part in model.doc.parts:
		var id: String = part.type
		if seen.has(id):
			continue
		seen[id] = true
		var row := _nest_row(id)
		if row.is_empty():
			continue
		var want := _nest_target(id)
		var owned: bool = row.owned
		var cur: int = row.level if owned else 1
		var ct: int = row.tier if owned else 0
		if not owned:
			total += int(row.cost)
		for l in range(cur, int(want.level)):
			total += int(row.cost) * (1 << l)
		for t in range(ct, int(want.tier)):
			total += 60 if t == 0 else 150
	return total

func _nest_refresh() -> void:
	var state: Dictionary = nest_world.state()
	nest_rows = state.parts.discovered
	nest_tiers_on = bool(state.parts.get("tiers_enabled", false))
	var selected := maxi(0, nest_choice.selected)
	nest_choice.clear()
	var unlocked := {}
	for row in nest_rows:
		unlocked[row.id] = row
		nest_choice.add_item("%s · L%d%s" % [parts_db.display_name(row.id, lang), _nest_target(row.id).level, "" if row.owned else (" (nuevo)" if lang == "es" else " (new)")])
	if not nest_rows.is_empty():
		nest_choice.select(mini(selected, nest_rows.size() - 1))
	for id in palette_buttons:
		palette_buttons[id].visible = unlocked.has(id)
		palette_buttons[id].disabled = not unlocked.has(id)
	for part in model.doc.parts:
		if unlocked.has(part.type):
			var want := _nest_target(part.type)
			part["level"] = want.level
			part["tier"] = want.tier if nest_tiers_on else 0
	_update_dna()
	_nest_labels()

func _nest_labels() -> void:
	nest_apply_button.text = "Aplicar pintura y disposición (gratis)" if lang == "es" else "Apply paint and layout (free)"
	var cost := nest_pending_cost()
	nest_evolve_button.text = ("Evolucionar · %d ADN" if lang == "es" else "Evolve · %d DNA") % cost
	nest_cost.text = ("Pendiente: %d ADN de %d" if lang == "es" else "Pending: %d DNA of %d") % [cost, int(nest_world.state().social.dna_balance)]
	nest_evolve_button.disabled = cost > int(nest_world.state().social.dna_balance)
	if nest_rows.is_empty():
		return
	var row: Dictionary = nest_rows[nest_choice.selected]
	var want := _nest_target(row.id)
	nest_status.text = ("ADN %d · %s · nivel %d · golpes %d / %d · victorias %d / %d" if lang == "es" else "DNA %d · %s · level %d · hits %d / %d · wins %d / %d") % [nest_world.state().social.dna_balance, parts_db.display_name(row.id, lang), want.level, row.hits, row.need_hits, row.fights, row.need_fights]
	nest_actions[0].text = ("Subir nivel (probar)" if lang == "es" else "Level up (try)")
	nest_actions[0].disabled = want.level >= 5
	nest_actions[1].text = ("Bajar nivel" if lang == "es" else "Level down")
	nest_actions[1].disabled = want.level <= (row.level if row.owned else 1)
	nest_actions[2].text = ("%s (probar)" if lang == "es" else "%s (try)") % row.next_form.capitalize()
	nest_actions[2].visible = nest_tiers_on
	nest_actions[2].disabled = not row.owned or want.tier >= 2 or row.hits < row.need_hits or row.fights < row.need_fights

func _nest_try(kind: int) -> void:
	var row: Dictionary = nest_rows[nest_choice.selected]
	var want := _nest_target(row.id)
	if kind == 0:
		want.level = mini(5, int(want.level) + 1)
	elif kind == 1:
		want.level = maxi(row.level if row.owned else 1, int(want.level) - 1)
	elif nest_tiers_on:
		want.tier = mini(2, int(want.tier) + 1)
	nest_plan[row.id] = want
	_nest_refresh()

func _nest_doc() -> Dictionary:
	_nest_refresh()
	var doc: Dictionary = model.get_doc()
	doc.schema = "cpore.creature/5"
	for part in doc.parts:
		var want := _nest_target(part.type)
		part["level"] = want.level
		part["tier"] = want.tier if nest_tiers_on else 0
	return doc

func _nest_apply() -> void:
	var doc := _nest_doc()
	var rc: int = nest_world.nest_apply(JSON.stringify(doc))
	if rc == -23:
		nest_status.text = "Este cambio altera piezas o niveles: usa Evolucionar." if lang == "es" else "This change alters parts or levels: use Evolve."
		return
	if rc != 0:
		nest_status.text = "Cambio rechazado (%d)." % rc if lang == "es" else "Change refused (%d)." % rc
		return
	applied_genome = doc
	nest_status.text = "Aplicado: misma generación, sin coste." if lang == "es" else "Applied: same generation, no cost."
	nest_applied.emit(doc)

func _nest_confirm() -> void:
	var doc := _nest_doc()
	var rc: int = nest_world.nest_edit(JSON.stringify(doc))
	if rc != 0:
		if rc == -24:
			nest_status.text = "Edición rechazada: ADN insuficiente." if lang == "es" else "Evolution refused: not enough DNA."
		else:
			nest_status.text = "Edición rechazada (%d). Revisa las piezas, hitos y el espacio para un primo." % rc if lang == "es" else "Evolution refused (%d). Check parts, milestones and room for a cousin." % rc
		return
	nest_confirmed.emit(doc)

func _draw_arrows(off: Vector2) -> void:
	var alpha: float = view.spine_alpha()
	var dragging: bool = _drag.get("kind", "") == "end"
	if alpha < .05 and not dragging:
		return
	var arr := spine_arrows()
	for k in arr:
		var a: Dictionary = arr[k]
		var hot: bool = _arrow_hot == k or (dragging and (_drag["head"] == (k == "head")))
		var col: Color = ThemeFactory.AMBER if hot else ThemeFactory.PAPER
		col.a = clampf(alpha if not dragging else 1.0, 0.0, 1.0) * (1.0 if hot else .8)
		var c: Vector2 = a["pos"] + off
		var d: Vector2 = a["dir"]
		var n := Vector2(-d.y, d.x)
		var sz := 18.0 if hot else 15.0
		var ink := Color(ThemeFactory.INK, col.a * .85)
		overlay.draw_line(c - d * sz * 1.6, c, ink, 7.0, true)
		overlay.draw_colored_polygon(PackedVector2Array([c + d * (sz + 3.0), c - d * sz * .3 + n * (sz * .8 + 3.0), c - d * sz * .3 - n * (sz * .8 + 3.0)]), ink)
		overlay.draw_line(c - d * sz * 1.6, c, Color(col, col.a * .9), 3.5, true)
		overlay.draw_colored_polygon(PackedVector2Array([c + d * sz, c - d * sz * .3 + n * sz * .8, c - d * sz * .3 - n * sz * .8]), col)

func _draw_scale_readout(off: Vector2) -> void:
	if _scale_fx.is_empty():
		return
	var font := ThemeDB.fallback_font
	var text: String = _scale_fx["text"] + (" · " + T("límite") if _scale_fx["limit"] else "")
	var a := clampf(float(_scale_fx["t"]) / .3, 0.0, 1.0)
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var p: Vector2 = _scale_fx["pos"] + off + Vector2(16, -22)
	overlay.draw_rect(Rect2(p - Vector2(7, sz.y - 2), sz + Vector2(14, 8)), Color(ThemeFactory.GLASS, .9 * a))
	overlay.draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(ThemeFactory.AMBER if _scale_fx["limit"] else ThemeFactory.PAPER, a))
