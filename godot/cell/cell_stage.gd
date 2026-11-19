extends Control
## The cell stage screen: the canvas (cell_canvas.gd) full screen, the phase tabs on top, the cream control column on the
## right (phase card, Crear tools, stats, Líneas, note), the aggregation card and the pause list.
## Port of art/reference/cell/fase-celula-escala.html. Keys: 1-4 phase, Space pause, F speed, L labels, Esc pause list.

const Sim := preload("res://cell/cell_sim.gd")
const Canvas := preload("res://cell/cell_canvas.gd")
const CS := preload("res://cell/cell_strings.gd")
const CSim := preload("res://cell/colony_sim.gd")
const Ghost := preload("res://cell/drag_ghost.gd")
const CCanvas := preload("res://cell/colony_canvas.gd")
const Legacy := preload("res://cell/cell_legacy.gd")

const INK := Color("3A352D")
const SUB := Color("6A6356")
const LINE := Color("CFC3A6")
const PANEL := Color("FBF7EC")
const SEL := Color("1F5F9E")
const WARN := Color("9E392C")
const GOOD := Color("3F6B2E")
const BRIDGE_FADE := 0.5   # the stage transition: the one motion allowed past 250 ms (and under 600)
const STEP := 1.0 / 60.0
const DRAG_START := 6.0     # px the pointer travels before a press on a card becomes a drag (a tap stays a tap)
const SIDE_W := 392.0

var sim
var canvas: Canvas
var ccanvas: CCanvas
var colony = null           # ColonySim, made when phase 6 is first opened
var _sheet := {}
var _leg_card: PanelContainer
var _leg_title: Label
var _leg_body: Label
var _leg_table: GridContainer
var _leg_why: Label
var _leg_go: Button
var _leg_cont: Button       # the primary button of the end card: continue as a creature (the bridge, docs/godot/CELL-BRIDGE.md)
var _leg_cur: Dictionary = {}
var _bridging := false
var _bridge_host: Control
var _bridge_veil: ColorRect
var _leg_stay: Button
var _leg_shown := false
var _lines_card: PanelContainer
var _create_card: PanelContainer
var _phase6 := false        # the colony board is the view (the cell sim is paused behind it)
var _ctool_btns := {}
var _tools_mode := "cell"
var speed := 1
var paused_by_key := false
var menu_open := false
var _acc := 0.0
var _hud_t := 1.0
var _side: ScrollContainer
var _phase_btns: Array = []
var _tool_btns := {}
var _tools_grid: GridContainer
var _del_btn: Button
var _sp1: Button
var _sp3: Button
var _lab: Button
var _step_lbl: Label
var _hint_lbl: Label
var _goal_lbl: Label
var _bar: ProgressBar
var _stat_lbls := {}
var _lines_grid: GridContainer
var _diag: Label
var _title: Label
var _note: Label
var _create_lbl: Label
var _th_card: PanelContainer
var _th_title: Label
var _th_grid: GridContainer
var _agg_card: PanelContainer
var _agg_title: Label
var _agg_body: Label
var _agg_table: GridContainer
var _agg_foot: Label
var _agg_go: Button
var _agg_new: Button
var _menu_layer: Control
var _menu_btns: Array = []
var _last_hint := ""
var _last_goal_v := -1
var _hint_tween: Tween
var _bar_tween: Tween
var _agg_shown := false
var _key_help: Label
var _theme: Theme
var _dot_cache := {}
var _prev_content := {}
var ghost: Control           # the piece that follows the pointer during a drag
var _cd := {}                # the card press in progress: {kind, card, start, active, dead}
var _swallow_frame := -1     # frame of a drag release: the card's own "pressed" is ignored then

func _ready() -> void:
	sim = Sim.new(int(Time.get_ticks_msec()) & 0xFFFF if not _has_seed_arg() else _seed_arg(), 1)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_theme = _make_theme()
	theme = _theme
	var bg := ColorRect.new()
	bg.color = Color("0F2229")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	canvas = Canvas.new()
	canvas.sim = sim
	canvas.still = bool(_game().settings.get("reduced_motion", false))
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.placed.connect(func(_k): _refresh_tools(); _hud_t = 1.0)
	canvas.tool_cleared.connect(_refresh_tools)
	canvas.removed.connect(func(_k): _hud_t = 1.0)
	add_child(canvas)
	ccanvas = CCanvas.new()
	ccanvas.still = canvas.still
	ccanvas.visible = false
	ccanvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ccanvas.placed.connect(func(_k): _refresh_tools(); _hud_t = 1.0)
	ccanvas.tool_cleared.connect(_refresh_tools)
	ccanvas.removed.connect(func(_k): _hud_t = 1.0)
	ccanvas.moved.connect(func(_k): _hud_t = 1.0)
	add_child(ccanvas)
	_build_top()
	_build_side()
	ghost = Ghost.new()
	ghost.instant = canvas.still
	add_child(ghost)
	ccanvas.ghost = ghost
	_build_agg()
	_build_legacy()
	_build_menu()
	resized.connect(_layout)
	_layout()
	_apply_phase(1)
	_refresh_texts()
	_refresh_hud(true)
	var jump: Dictionary = _game().cell_jump_end       # dev `cell finish`
	if not jump.is_empty():
		_game().cell_jump_end = {}
		jump_to_end.call_deferred(jump)

func _game() -> Node:
	return get_node("/root/Game")

func _has_seed_arg() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cell-seed="):
			return true
	return false

func _seed_arg() -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cell-seed="):
			return int(a.substr(12))
	return 1

# ---------- theme and small widgets
func _flat(bg: Color, border: Color, radius: int = 9, bw: int = 1, pad: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad + 2
	s.content_margin_right = pad + 2
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	s.anti_aliasing = true
	return s

func _make_theme() -> Theme:
	var t := Theme.new()
	var f: Font = load("res://ui/fonts/AlegreyaSans-Medium.ttf")
	t.default_font = f
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	for cls in ["Button"]:
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			t.set_color(c, cls, INK)
		t.set_font_size("font_size", cls, 15)
		t.set_color("icon_normal_color", cls, Color.WHITE)
		t.set_color("icon_pressed_color", cls, Color.WHITE)
		t.set_color("icon_hover_color", cls, Color.WHITE)
		t.set_color("icon_hover_pressed_color", cls, Color.WHITE)
		t.set_constant("h_separation", cls, 8)
	t.set_stylebox("normal", "Button", _flat(Color.WHITE, LINE))
	t.set_stylebox("hover", "Button", _flat(Color("FFFBF0"), Color("B9AB86")))
	t.set_stylebox("pressed", "Button", _flat(Color("E6EFF9"), SEL, 9, 2))
	t.set_stylebox("hover_pressed", "Button", _flat(Color("EDF3FA"), SEL, 9, 2))
	t.set_stylebox("focus", "Button", _flat(Color(0, 0, 0, 0), SEL, 9, 2))
	t.set_stylebox("disabled", "Button", _flat(Color("EEE8D8"), LINE))
	var tip := _flat(Color(0.985, 0.968, 0.925, 0.98), LINE, 8, 1, 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 15)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("E9E1CB")
	track.set_corner_radius_all(4)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("7FA65A")
	fill.set_corner_radius_all(4)
	t.set_stylebox("background", "ProgressBar", track)
	t.set_stylebox("fill", "ProgressBar", fill)
	return t

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(PANEL, LINE, 12, 1, 10))
	var s: StyleBoxFlat = p.get_theme_stylebox("panel") as StyleBoxFlat
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	return p

func _lbl(text: String = "", size: int = 15, col: Color = INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l

## Buttons press to 0.97 in 120 ms (ease out) and settle back; keyboard focus is off (the keys are the stage's).
func _pressable(b: Button, focus := false) -> Button:
	b.focus_mode = Control.FOCUS_ALL if focus else Control.FOCUS_NONE
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func(): _scale_to(b, 0.97, 0.12))
	b.button_up.connect(func(): _scale_to(b, 1.0, 0.12))
	b.mouse_exited.connect(func(): if b.scale.x < 1.0: _scale_to(b, 1.0, 0.12))
	return b

func _scale_to(b: Control, s: float, dur: float) -> void:
	if not is_instance_valid(b):
		return
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(s, s), dur).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _btn(text: String, toggle := false) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = toggle
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return _pressable(b)

func _dot(col: Color) -> Texture2D:
	if _dot_cache.has(col):
		return _dot_cache[col]
	var n := 28
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(n / 2.0, n / 2.0))
			if d <= n / 2.0 - 1.0:
				img.set_pixel(x, y, INK if d > n / 2.0 - 3.0 else col)
			elif d <= n / 2.0:
				var a := clampf(n / 2.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(INK, a))
	var tex := ImageTexture.create_from_image(img)
	_dot_cache[col] = tex
	return tex

# ---------- layout
func _build_top() -> void:
	var box := HBoxContainer.new()
	box.name = "Top"
	box.position = Vector2(16, 10)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = _lbl("", 22, Color("EDE8DA"))
	_title.add_theme_color_override("font_outline_color", Color(0.06, 0.13, 0.16, 0.8))
	_title.add_theme_constant_override("outline_size", 4)
	_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(_title)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(22, 0)
	box.add_child(sp)
	for i in range(1, 7):
		var b := _btn("", true)
		b.custom_minimum_size = Vector2(92, 40)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.pressed.connect(func(): _apply_phase(i); _hud_t = 1.0)
		box.add_child(b)
		_phase_btns.append(b)
	_key_help = _lbl("", 13, Color("9FB8B6"))
	_key_help.position = Vector2(18, 0)
	_key_help.name = "KeyHelp"
	add_child(_key_help)

func _build_side() -> void:
	_side = ScrollContainer.new()
	_side.name = "Side"
	_side.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_side.add_child(col)
	# phase card
	var c1 := _card()
	col.add_child(c1)
	var v1 := VBoxContainer.new()
	v1.add_theme_constant_override("separation", 4)
	c1.add_child(v1)
	_step_lbl = _lbl("", 12, SUB)
	v1.add_child(_step_lbl)
	_hint_lbl = _lbl("", 16)
	_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_lbl.custom_minimum_size = Vector2(0, 88)
	v1.add_child(_hint_lbl)
	_goal_lbl = _lbl("", 14, SEL)
	_goal_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v1.add_child(_goal_lbl)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.custom_minimum_size = Vector2(0, 8)
	v1.add_child(_bar)
	# threats card (phase 5): the schedule, readable at a glance
	_th_card = _card()
	_th_card.visible = false
	col.add_child(_th_card)
	var vt := VBoxContainer.new()
	vt.add_theme_constant_override("separation", 5)
	_th_card.add_child(vt)
	_th_title = _lbl("", 12, SUB)
	_th_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vt.add_child(_th_title)
	_th_grid = GridContainer.new()
	_th_grid.columns = 3
	_th_grid.add_theme_constant_override("h_separation", 12)
	_th_grid.add_theme_constant_override("v_separation", 3)
	vt.add_child(_th_grid)
	# create card
	var c2 := _card()
	_create_card = c2
	col.add_child(c2)
	var v2 := VBoxContainer.new()
	v2.add_theme_constant_override("separation", 8)
	c2.add_child(v2)
	_create_lbl = _lbl("", 12, SUB)
	v2.add_child(_create_lbl)
	_tools_grid = GridContainer.new()
	_tools_grid.columns = 2
	_tools_grid.add_theme_constant_override("h_separation", 8)
	_tools_grid.add_theme_constant_override("v_separation", 8)
	v2.add_child(_tools_grid)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	v2.add_child(r1)
	_del_btn = _btn("", true)
	_del_btn.toggled.connect(func(on: bool): if on: _set_tool("del") elif _active_tool() == "del": _set_tool(""))
	r1.add_child(_del_btn)
	var demo_b := _btn("")
	demo_b.name = "Demo"
	demo_b.pressed.connect(func(): _set_tool(""); _demo(); _hud_t = 1.0)
	r1.add_child(demo_b)
	var reset_b := _btn("")
	reset_b.name = "Reset"
	reset_b.pressed.connect(func(): _set_tool(""); _restart())
	r1.add_child(reset_b)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	v2.add_child(r2)
	_sp1 = _btn("", true)
	_sp1.pressed.connect(func(): _set_speed(1))
	r2.add_child(_sp1)
	_sp3 = _btn("", true)
	_sp3.pressed.connect(func(): _set_speed(3))
	r2.add_child(_sp3)
	_lab = _btn("", true)
	_lab.button_pressed = true
	_lab.toggled.connect(func(on: bool): canvas.labels = on; ccanvas.labels = on)
	r2.add_child(_lab)
	# stats
	var c3 := _card()
	col.add_child(c3)
	var g3 := GridContainer.new()
	g3.columns = 5
	g3.add_theme_constant_override("h_separation", 6)
	c3.add_child(g3)
	for k in ["s_free", "s_rate", "s_glu", "s_mem", "s_tier"]:
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		var name_l := _lbl("", 11, SUB)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.custom_minimum_size = Vector2(60, 28)
		var val := _lbl("0", 20)
		v.add_child(name_l)
		v.add_child(val)
		g3.add_child(v)
		_stat_lbls[k] = [name_l, val]
	# lines
	var c4 := _card()
	_lines_card = c4
	col.add_child(c4)
	var v4 := VBoxContainer.new()
	v4.add_theme_constant_override("separation", 6)
	c4.add_child(v4)
	_stat_lbls["lines"] = _lbl("", 12, SUB)
	v4.add_child(_stat_lbls["lines"])
	_lines_grid = GridContainer.new()
	_lines_grid.columns = 3
	_lines_grid.add_theme_constant_override("h_separation", 12)
	_lines_grid.add_theme_constant_override("v_separation", 3)
	v4.add_child(_lines_grid)
	_diag = _lbl("", 14, WARN)
	_diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v4.add_child(_diag)
	_note = _lbl("", 13, Color("B9C9C6"))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_note)

func _build_agg() -> void:
	_agg_card = PanelContainer.new()
	_agg_card.visible = false
	_agg_card.add_theme_stylebox_override("panel", _flat(Color(0.984, 0.969, 0.925, 0.97), LINE, 14, 1, 16))
	add_child(_agg_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_agg_card.add_child(v)
	_agg_title = _lbl("", 22)
	v.add_child(_agg_title)
	_agg_body = _lbl("", 14, SUB)
	_agg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_agg_body.custom_minimum_size = Vector2(408, 0)
	v.add_child(_agg_body)
	_agg_table = GridContainer.new()
	_agg_table.columns = 2
	_agg_table.add_theme_constant_override("h_separation", 24)
	_agg_table.add_theme_constant_override("v_separation", 6)
	v.add_child(_agg_table)
	_agg_foot = _lbl("", 14, SUB)
	_agg_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_agg_foot.custom_minimum_size = Vector2(408, 0)
	v.add_child(_agg_foot)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	v.add_child(r)
	_agg_go = _btn("")
	_agg_go.pressed.connect(func(): sim.continue_colony(); _hide_agg(); _save_legacy_aggregation(); _apply_phase(5); _hud_t = 1.0)
	r.add_child(_agg_go)
	_agg_new = _btn("")
	_agg_new.pressed.connect(func(): _hide_agg(); _restart())
	r.add_child(_agg_new)

func _build_menu() -> void:
	_menu_layer = Control.new()
	_menu_layer.visible = false
	_menu_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.09, 0.11, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_layer.add_child(cc)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(0.984, 0.969, 0.925, 0.98), LINE, 14, 1, 18))
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(260, 0)
	p.add_child(v)
	var t := _lbl("", 22)
	t.name = "MenuTitle"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 44)
		_pressable(b, true)
		v.add_child(b)
		_menu_btns.append(b)
	_menu_btns[0].pressed.connect(func(): _toggle_menu(false))
	_menu_btns[1].pressed.connect(func(): _toggle_menu(false); _restart())
	_menu_btns[2].pressed.connect(func(): _game().goto_menu())

func _layout() -> void:
	var sz := size
	var side_w := minf(SIDE_W, sz.x * 0.36)
	_side.position = Vector2(sz.x - side_w - 14.0, 10)
	_side.size = Vector2(side_w + 4.0, sz.y - 20.0)
	_key_help.position = Vector2(18, sz.y - 26.0)
	_title.visible = sz.x >= 1200.0
	var left_w := sz.x - side_w - 28.0
	canvas.play_rect = Rect2(0, 56, left_w, sz.y - 56.0 - 18.0)
	ccanvas.play_rect = canvas.play_rect
	if _agg_card != null:
		_place_agg()
		_place_leg()

func _place_agg() -> void:
	_agg_card.reset_size()
	var c := canvas.play_rect.get_center()
	_agg_card.position = c - _agg_card.size / 2.0
	_agg_card.pivot_offset = _agg_card.size / 2.0

# ---------- text refresh (language)
func _refresh_texts() -> void:
	_title.text = CS.t("title")
	for i in 6:
		_phase_btns[i].text = "%d  %s" % [i + 1, CS.phase_name(i + 1, Sim.PHASE_NAMES)]
	_create_lbl.text = CS.t("create").to_upper()
	_del_btn.text = CS.t("remove")
	(find_child("Demo", true, false) as Button).text = CS.t("demo")
	(find_child("Reset", true, false) as Button).text = CS.t("reset")
	_sp1.text = CS.t("speed1")
	_sp3.text = CS.t("speed3")
	_lab.text = CS.t("labels")
	for i in 5:
		var k: String = ["s_free", "s_rate", "s_glu", "s_mem", "s_tier"][i]
		_stat_lbls[k][0].text = CS.t(k)
	_stat_lbls["lines"].text = CS.t("lines").to_upper()
	_note.text = CS.t("note")
	_key_help.text = CS.t("key_help")
	_agg_title.text = CS.t("agg_title")
	_agg_body.text = CS.t("agg_body")
	_agg_foot.text = CS.t("agg_foot")
	_agg_go.text = CS.t("agg_go")
	_agg_new.text = CS.t("agg_new")
	(_menu_layer.find_child("MenuTitle", true, false) as Label).text = CS.t("pause_title")
	_menu_btns[0].text = CS.t("resume")
	_menu_btns[1].text = CS.t("restart")
	_menu_btns[2].text = CS.t("main_menu")
	_leg_title.text = CS.t("leg_title")
	_leg_body.text = CS.t("leg_body")
	_leg_cont.text = CS.t("leg_continue")
	_leg_go.text = CS.t("leg_menu")
	_leg_stay.text = CS.t("leg_stay")
	_refresh_tools()

# ---------- actions
func _active_tool() -> String:
	return ccanvas.tool if _phase6 else canvas.tool

func _set_tool(t: String) -> void:
	if _phase6:
		ccanvas.tool = t
	else:
		canvas.tool = t
	_refresh_tools()

func _refresh_tools() -> void:
	if _phase6:
		_refresh_colony_tools()
		return
	var want: Array = []
	for k in Sim.PIECES:
		if int(Sim.PIECES[k].ph) <= sim.phase:
			want.append(k)
	if _tool_btns.keys() != want or _tools_mode != "cell":
		_tools_mode = "cell"
		for c in _tools_grid.get_children():
			c.queue_free()
			_tools_grid.remove_child(c)
		_ctool_btns.clear()
		_tool_btns.clear()
		for k in want:
			var d: Dictionary = Sim.PIECES[k]
			var b := _btn("")
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = _dot(d.col)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 14)
			b.tooltip_text = CS.role(Sim.PIECES, k)
			b.pressed.connect(func(): _card_tap(func(): _set_tool("" if canvas.tool == k else k)))
			_wire_card(b, k)
			_tools_grid.add_child(b)
			_tool_btns[k] = b
	for k in _tool_btns:
		var b2: Button = _tool_btns[k]
		b2.text = "%s\n%s" % [CS.piece_name(Sim.PIECES, k), CS.t("atp_cost", [Sim.PIECES[k].c])]
		b2.tooltip_text = CS.role(Sim.PIECES, k)
		b2.set_pressed_no_signal(canvas.tool == k)
	_del_btn.set_pressed_no_signal(canvas.tool == "del")

# ---------- drag a card onto the cell (Emil's gestures: the ghost is the pointer, release hands over to ease-out)
func _card_tap(tap: Callable) -> void:
	if Engine.get_process_frames() == _swallow_frame:
		_refresh_tools()      # the release of a drag is not a tap: put the toggle back
		return
	tap.call()

func _wire_card(b: Button, kind: String) -> void:
	b.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP if not b.disabled else Control.CURSOR_ARROW
	b.gui_input.connect(func(ev: InputEvent): _card_input(b, kind, ev))

func _card_input(b: Button, kind: String, ev: InputEvent) -> void:
	if b.disabled:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_cd = {"kind": kind, "card": b, "start": ev.global_position, "active": false, "dead": false}
		else:
			if bool(_cd.get("active", false)):
				_swallow_frame = Engine.get_process_frames()
				_drag_release(ev.global_position)
				b.accept_event()
			elif not _cd.is_empty() and bool(_cd.get("dead", false)):
				_swallow_frame = Engine.get_process_frames()
			_cd = {}
	elif ev is InputEventMouseMotion and not _cd.is_empty() and _cd.card == b and not _cd.dead:
		if not _cd.active:
			if (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and _cd.start.distance_to(ev.global_position) >= DRAG_START:
				_drag_begin(ev.global_position)
		if _cd.active:
			_drag_move(ev.global_position)

func _cur_canvas() -> Control:
	return ccanvas if _phase6 else canvas

func is_dragging() -> bool:
	return bool(_cd.get("active", false))

func _drag_begin(gp: Vector2) -> void:
	_cd.active = true
	var kind: String = _cd.kind
	_set_tool("")
	var cv := _cur_canvas()
	cv.drag_kind = kind
	cv.drag_pos = gp - cv.global_position
	if _phase6:
		ghost.begin(kind, "colony", gp, 1.0, ccanvas.hsize())
	else:
		ghost.begin(kind, "cell", gp, canvas.scale_px())
	var card: Button = _cd.card
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG
	card.modulate.a = 0.55
	_drag_move(gp)

func _drag_eval(kind: String, gp: Vector2) -> Dictionary:
	var cv := _cur_canvas()
	var e: Dictionary = cv.drop_eval(kind, gp - cv.global_position)
	var mem: bool = not _phase6 and Sim.PIECES[kind].has("mem")
	e["why"] = CS.t("dr_cancel") if not e.in_play else CS.drop_why(e.err, mem)
	return e

func _drag_move(gp: Vector2) -> void:
	var kind: String = _cd.kind
	var cv := _cur_canvas()
	cv.drag_pos = gp - cv.global_position
	var e := _drag_eval(kind, gp)
	ghost.track(gp, e.ok or not e.in_play, e.why if not e.ok else "")
	var card: Button = _cd.card
	card.mouse_default_cursor_shape = Control.CURSOR_DRAG if (e.ok or not e.in_play) else Control.CURSOR_FORBIDDEN

func _drag_end_state() -> void:
	var card = _cd.get("card")
	if is_instance_valid(card):
		card.mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
		card.modulate.a = 1.0
	canvas.drag_kind = ""
	ccanvas.drag_kind = ""

func _drag_release(gp: Vector2) -> void:
	var kind: String = _cd.kind
	var card: Button = _cd.card
	var cv := _cur_canvas()
	var e := _drag_eval(kind, gp)
	_drag_end_state()
	_cd.active = false
	if e.ok:
		var err: String = cv.drop_place(kind, gp - cv.global_position)
		if err == "":
			ghost.land()
			_refresh_tools()
			return
	elif e.in_play:
		cv.drop_place(kind, gp - cv.global_position)   # refused: the stage says why where it was dropped
	ghost.send_back(card.global_position + card.size / 2.0)
	_refresh_tools()

## Esc during a drag: the ghost eases back to its card (or the picked-up piece returns), nothing is placed.
func cancel_drag() -> bool:
	if is_dragging():
		var card: Button = _cd.card
		_drag_end_state()
		_cd.active = false
		_cd.dead = true
		ghost.send_back(card.global_position + card.size / 2.0)
		return true
	if canvas.cancel_drag():
		return true
	return ccanvas.cancel_drag()

func _apply_phase(n: int) -> void:
	if n == 5 and not sim.threats_unlocked():
		return
	if n == 6 and not sim.colony_unlocked():
		return
	_set_tool("")
	_phase6 = n == 6
	canvas.visible = not _phase6
	ccanvas.visible = _phase6
	if _phase6:
		_enter_colony()
	else:
		sim.set_phase(n)
	for i in 6:
		_phase_btns[i].set_pressed_no_signal(i + 1 == n)
	if not _phase6 and canvas.tool != "" and canvas.tool != "del" and int(Sim.PIECES[canvas.tool].ph) > n:
		canvas.tool = ""
	_refresh_tools()
	_last_hint = ""
	_refresh_hud(true)

func _enter_colony() -> void:
	if colony == null:
		_sheet = sim.legacy_sheet()
		colony = CSim.new(sim.seed_value, _sheet)
		ccanvas.sim = colony
	_leg_shown = false

func _set_speed(n: int) -> void:
	speed = n
	_sp1.set_pressed_no_signal(n == 1)
	_sp3.set_pressed_no_signal(n == 3)

func _restart() -> void:
	if _phase6:
		colony = CSim.new(sim.seed_value, _sheet)
		ccanvas.sim = colony
		_hide_leg(true)
		_last_hint = ""
		_hud_t = 1.0
		return
	sim.reset()
	_agg_shown = false
	_hide_agg(true)
	_last_hint = ""
	_hud_t = 1.0

func _toggle_menu(on: bool) -> void:
	menu_open = on
	_menu_layer.visible = on
	canvas.paused = on or paused_by_key
	ccanvas.paused = canvas.paused
	if on:
		_menu_btns[0].grab_focus()

## Steps the sim by `seconds` of play time without waiting for frames (tests and evidence).
func advance(seconds: float) -> void:
	var n := int(seconds / STEP)
	for i in n:
		if _phase6:
			colony.step(STEP)
		else:
			sim.step(STEP)
	_hud_t = 1.0

func _process(delta: float) -> void:
	var run := not (paused_by_key or menu_open)
	if run:
		_acc += minf(delta, 0.05) * speed
		var n := 0
		while _acc >= STEP and n < 8:
			if _phase6:
				colony.step(STEP)
			else:
				sim.step(STEP)
			_acc -= STEP
			n += 1
		if n == 8:
			_acc = 0.0
	canvas.hover_piece = canvas.hover_piece if canvas.drag == null else canvas.drag
	if _phase6 and not run:
		pass
	_hud_t += delta
	if _hud_t >= 0.25:
		_hud_t = 0.0
		_refresh_hud()
	sim.take_events()
	if colony != null:
		colony.take_events()
		if colony.done and colony.done_t > 1.5 and not _leg_shown and _phase6:
			_show_leg()
	var ag: Dictionary = sim.aggregation()
	if ag.shown and not _agg_shown:
		_show_agg(ag)
	elif not ag.active and _agg_shown:
		_hide_agg(true)

func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			if not menu_open:
				_apply_phase(int(ev.keycode - KEY_0))
		KEY_SPACE:
			if not menu_open:
				paused_by_key = not paused_by_key
				canvas.paused = paused_by_key
				ccanvas.paused = paused_by_key
		KEY_F:
			if not menu_open:
				_set_speed(3 if speed == 1 else 1)
		KEY_L:
			if not menu_open:
				_lab.button_pressed = not _lab.button_pressed
		KEY_ESCAPE:
			if cancel_drag():
				pass
			elif _active_tool() != "" and not menu_open:
				_set_tool("")
			else:
				_toggle_menu(not menu_open)
		_:
			return
	get_viewport().set_input_as_handled()

# ---------- HUD
func _set_hint_text(txt: String, instant: bool) -> void:
	if txt == _last_hint:
		return
	_last_hint = txt
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	if instant or not is_inside_tree():
		_hint_lbl.text = txt
		_hint_lbl.modulate.a = 1.0
		return
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_lbl, "modulate:a", 0.0, 0.075).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_hint_tween.tween_callback(func(): _hint_lbl.text = txt)
	_hint_tween.tween_property(_hint_lbl, "modulate:a", 1.0, 0.075).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _refresh_hud(instant := false) -> void:
	_lines_card.visible = not _phase6
	_note.visible = not _phase6
	if _phase6 and colony != null:
		_refresh_threats()
		_refresh_colony_hud(instant)
		return
	for k in ["s_free", "s_rate", "s_glu", "s_mem", "s_tier"]:
		_stat_lbls[k][0].text = CS.t(k)
	var h: Dictionary = sim.hint()
	_set_hint_text(CS.t(h.key, h.args), instant)
	_step_lbl.text = CS.t("phase", [sim.phase, CS.phase_name(sim.phase, Sim.PHASE_NAMES)]).to_upper()
	var g: Dictionary = sim.goal()
	var gtxt: String = CS.t(g.id, g.args)
	if sim.phase < 4 and sim.goal_state.done:
		gtxt = CS.t("g_done", [sim.phase + 1]) if sim.phase < 4 else CS.t("g_done_last")
	elif g.id != "g_agg_done":
		gtxt += " · %d/%d%s" % [g.v, g.max, (" " + g.unit) if g.unit != "" else ""]
	_goal_lbl.text = gtxt
	_goal_lbl.add_theme_color_override("font_color", GOOD if g.done else SEL)
	var pct := minf(100.0, float(g.v) / float(g.max) * 100.0)
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	if instant:
		_bar.value = pct
	else:
		_bar_tween = create_tween()
		_bar_tween.tween_property(_bar, "value", pct, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var st: Dictionary = sim.stats()
	_stat_lbls["s_free"][1].text = str(st.atp)
	_stat_lbls["s_rate"][1].text = str(st.atp_min)
	_stat_lbls["s_glu"][1].text = str(st.glu_min)
	_stat_lbls["s_mem"][1].text = "%d%%" % st.mem
	_stat_lbls["s_tier"][1].text = "%d/%d" % [st.tier, st.tiers]
	for c in _lines_grid.get_children():
		c.queue_free()
		_lines_grid.remove_child(c)
	for r in sim.lines():
		if r.type == "membrane":
			_lines_grid.add_child(_lbl(CS.t("membrane"), 14))
			_lines_grid.add_child(_lbl("", 14))
			var m := _lbl(CS.t("mem_row", [r.tr, r.ex, r.fl]), 13, SUB)
			m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_lines_grid.add_child(m)
		else:
			var n := _lbl("%s ×%d" % [CS.piece_name(Sim.PIECES, r.type), r.n], 14)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_lines_grid.add_child(n)
			_lines_grid.add_child(_lbl("%d %%" % r.use, 14, SUB))
			var s := _lbl(CS.status(r.status), 14, Canvas.STT.get(r.status, SUB))
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_lines_grid.add_child(s)
	_refresh_threats()
	var dg: String = sim.diagnose()
	_diag.text = CS.t(dg) if dg != "" else (CS.t("no_bottleneck") if sim.has_piece("hk") else "")
	_diag.add_theme_color_override("font_color", WARN if dg != "" else GOOD)

# ---------- aggregation card
func _show_agg(ag: Dictionary) -> void:
	_agg_shown = true
	for c in _agg_table.get_children():
		c.queue_free()
		_agg_table.remove_child(c)
	for row in ag.stats:
		var key: String = row[0]
		var val: String = CS.num(row[1])
		match key:
			"s_atp": val += " /min"
			"s_glu": val += " /min"
			"s_up": val += " ATP/min"
			"s_mem": val += " %"
			"s_size": val = CS.t("u_radius", [CS.num(row[1])])
		var nk: String = {"s_glu": "s_glu_proc", "s_mem": "s_mem_int"}.get(key, key)
		var l := _lbl(CS.t(nk), 15)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_agg_table.add_child(l)
		var v := _lbl(val, 15)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_agg_table.add_child(v)
	_place_agg()
	_agg_card.visible = true
	_agg_card.pivot_offset = _agg_card.size / 2.0
	_agg_card.scale = Vector2(0.96, 0.96)
	_agg_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_agg_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_agg_card, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

func _hide_agg(instant := false) -> void:
	_agg_shown = false
	if instant or not _agg_card.visible:
		_agg_card.visible = false
		return
	var tw := create_tween()
	tw.tween_property(_agg_card, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _agg_card.visible = false)

# ---------- phase 5 card and the locks of phases 5 and 6
func _refresh_threats() -> void:
	_phase_btns[4].disabled = not sim.threats_unlocked()
	_phase_btns[4].tooltip_text = CS.t("locked_5") if _phase_btns[4].disabled else ""
	_phase_btns[5].disabled = not sim.colony_unlocked()
	_phase_btns[5].tooltip_text = CS.t("locked_6") if _phase_btns[5].disabled else ""
	_th_card.visible = sim.phase == 5 and not _phase6
	if not _th_card.visible:
		return
	_th_title.text = CS.t("threats_card").to_upper()
	for c in _th_grid.get_children():
		c.queue_free()
		_th_grid.remove_child(c)
	var info: Dictionary = sim.threat_info()
	for i in 4:
		var kind: String = Sim.THREAT_ORDER[i]
		var res: String = info.results[i]
		var active: bool = i == info.idx and not info.done
		_th_grid.add_child(_lbl(CS.t("kind_" + kind), 14, INK if active else SUB))
		var counter: String = {"phage": "cas", "abx": "pump", "ox": "cat", "amoeba": "spn"}[kind]
		var have: bool = sim.has_piece(counter) or (kind == "amoeba" and sim.tier >= 3)
		var cl := _lbl(CS.t("has_it") if have else CS.t("lacks_it"), 13, GOOD if have else WARN)
		cl.tooltip_text = CS.t("counter_" + counter)
		cl.mouse_filter = Control.MOUSE_FILTER_PASS
		_th_grid.add_child(cl)
		var txt := ""
		var tc := SUB
		if res == "ok":
			txt = CS.t("th_ok")
			tc = GOOD
		elif active and info.stage != "wait":
			txt = "%s · %d s" % [CS.t("th_now"), int(ceil(info.eta))]
			tc = WARN
		elif res == "fail" or (active and info.tries > 0):
			txt = CS.t("th_fail")
			tc = WARN
		else:
			txt = CS.t("th_pend") + ((" · %d s" % int(ceil(info.eta))) if active else "")
		var rl := _lbl(txt, 13, tc)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_th_grid.add_child(rl)

# ---------- phase 6: the colony card, tools and the carry-over card
func _refresh_colony_tools() -> void:
	if _tools_mode != "colony":
		_tools_mode = "colony"
		for c in _tools_grid.get_children():
			c.queue_free()
			_tools_grid.remove_child(c)
		_tool_btns.clear()
		_ctool_btns.clear()
		for k in CSim.ORDER:
			var d: Dictionary = CSim.BLOCKS[k]
			var b := _btn("")
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 46)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.icon = _dot(d.col)
			b.expand_icon = false
			b.add_theme_constant_override("icon_max_width", 14)
			b.disabled = d.get("locked", false)
			b.pressed.connect(func(): _card_tap(func(): _set_tool("" if ccanvas.tool == k else k)))
			_wire_card(b, k)
			_tools_grid.add_child(b)
			_ctool_btns[k] = b
	for k in _ctool_btns:
		var d2: Dictionary = CSim.BLOCKS[k]
		var b2: Button = _ctool_btns[k]
		b2.text = "%s\n%s" % [CS.block_name(k), CS.t("fx_no_locked") if d2.get("locked", false) else CS.t("atp_cost", [d2.cost])]
		b2.tooltip_text = CS.block_role(k)
		b2.set_pressed_no_signal(ccanvas.tool == k)
	_create_lbl.text = CS.t("colony_card").to_upper()
	_del_btn.set_pressed_no_signal(ccanvas.tool == "del")

func _refresh_colony_hud(instant: bool) -> void:
	_create_lbl.text = CS.t("colony_card").to_upper()
	var g: Dictionary = colony.goal()
	var h: Dictionary = colony.hint()
	_set_hint_text(CS.t(h.key, h.args), instant)
	_step_lbl.text = CS.t("phase", [6, CS.phase_name(6, Sim.PHASE_NAMES)]).to_upper()
	_goal_lbl.text = "%s · %d/%d · %d %%" % [CS.t("g_colony", [CSim.GOAL_CELLS]), mini(g.cells, g.goal_cells), g.goal_cells, int(round(g.frac * 100.0))]
	_goal_lbl.add_theme_color_override("font_color", GOOD if g.done else SEL)
	var pct: float = (minf(float(g.cells), float(g.goal_cells)) / g.goal_cells + g.frac + (1.0 if g.done else 0.0)) / 3.0 * 100.0
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	if instant:
		_bar.value = pct
	else:
		_bar_tween = create_tween()
		_bar_tween.tween_property(_bar, "value", pct, 0.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var names := {"s_free": "cs_atp", "s_rate": "cs_cells", "s_glu": "cs_speed", "s_mem": "cs_light", "s_tier": "cs_wave"}
	for k in names:
		_stat_lbls[k][0].text = CS.t(names[k])
	_stat_lbls["s_free"][1].text = str(int(round(colony.total_atp())))
	_stat_lbls["s_rate"][1].text = "%d/%d" % [g.cells, g.goal_cells]
	_stat_lbls["s_glu"][1].text = "%.0f" % colony.speed
	_stat_lbls["s_mem"][1].text = "%d%%" % int(round(g.frac * 100.0))
	var ws := "cw_wait"
	if g.done:
		ws = "cw_ok"
	elif g.wave == "warn":
		ws = "cw_warn_s"
	elif g.wave == "hit":
		ws = "cw_hit_s"
	_stat_lbls["s_tier"][1].text = CS.t(ws)
	_diag.text = ""

func _demo() -> void:
	if not _phase6:
		sim.demo()
		return
	var ring := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
	var kinds := ["energy", "motile", "motile", "energy", "defense", "defense"]
	for i in 6:
		if colony.cells.has(ring[i]):
			continue
		for hx in colony.cells.keys():
			colony.cells[hx].atp = CSim.CAP
		colony.place(kinds[i], ring[i])
	for hx in colony.cells.keys():
		colony.cells[hx].atp = CSim.CAP

func _save_legacy_aggregation() -> void:
	var have: Dictionary = _game().cell_legacy()
	if have.get("source", "") == "colony":
		return
	_game().save_cell_legacy(Legacy.derive(sim.legacy_sheet(), {}, "aggregation"))

func _build_legacy() -> void:
	_leg_card = PanelContainer.new()
	_leg_card.visible = false
	_leg_card.add_theme_stylebox_override("panel", _flat(Color(0.984, 0.969, 0.925, 0.97), LINE, 14, 1, 16))
	add_child(_leg_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_leg_card.add_child(v)
	_leg_title = _lbl("", 22)
	v.add_child(_leg_title)
	_leg_body = _lbl("", 14, SUB)
	_leg_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leg_body.custom_minimum_size = Vector2(430, 0)
	v.add_child(_leg_body)
	_leg_table = GridContainer.new()
	_leg_table.columns = 2
	_leg_table.add_theme_constant_override("h_separation", 28)
	_leg_table.add_theme_constant_override("v_separation", 6)
	v.add_child(_leg_table)
	_leg_why = _lbl("", 13, SUB)
	_leg_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_leg_why.custom_minimum_size = Vector2(430, 0)
	v.add_child(_leg_why)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	v.add_child(r)
	_leg_cont = _btn("")
	_leg_cont.name = "LegContinue"
	_leg_cont.custom_minimum_size = Vector2(0, 46)
	_leg_cont.add_theme_stylebox_override("normal", _flat(SEL, SEL, 10, 1, 8))
	_leg_cont.add_theme_stylebox_override("hover", _flat(SEL.lightened(0.12), SEL, 10, 1, 8))
	_leg_cont.add_theme_stylebox_override("pressed", _flat(SEL.darkened(0.12), SEL, 10, 1, 8))
	_leg_cont.add_theme_stylebox_override("focus", _flat(SEL, INK, 10, 2, 8))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_leg_cont.add_theme_color_override(c, Color.WHITE)
	_leg_cont.add_theme_font_size_override("font_size", 17)
	_leg_cont.focus_mode = Control.FOCUS_ALL
	_leg_cont.pressed.connect(_to_creature)
	v.add_child(_leg_cont)
	v.move_child(_leg_cont, r.get_index())      # the primary button above the secondary row
	_leg_go = _btn("")
	_leg_go.pressed.connect(func(): _game().goto_menu())
	r.add_child(_leg_go)
	_leg_stay = _btn("")
	_leg_stay.pressed.connect(func(): _hide_leg())
	r.add_child(_leg_stay)

func _place_leg() -> void:
	_leg_card.reset_size()
	_leg_card.position = canvas.play_rect.get_center() - _leg_card.size / 2.0
	_leg_card.pivot_offset = _leg_card.size / 2.0

## The carry-over sheet: what passes to the creature. It is also written to user://cell_legacy.json.
## `given` (dev `cell finish`) shows a ready legacy instead of deriving one from the colony.
func _show_leg(given: Dictionary = {}) -> void:
	_leg_shown = true
	var d: Dictionary = given if not given.is_empty() else Legacy.derive(_sheet, colony.composition(), "colony")
	_leg_cur = d
	_game().save_cell_legacy(d)
	for c in _leg_table.get_children():
		c.queue_free()
		_leg_table.remove_child(c)
	var rows := [["leg_diet", "leg_diet_" + d.diet], ["leg_def", "leg_def_" + d.defense], ["leg_size", "leg_size_" + d.size_class]]
	for row in rows:
		var l := _lbl(CS.t(row[0]), 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_leg_table.add_child(l)
		var val := _lbl(CS.t(row[1]), 18, GOOD)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_leg_table.add_child(val)
	_leg_why.text = CS.t("leg_from", [int(round(d.tally.waste_share * 100.0))]) + "\n" + CS.t("leg_from_def", [d.tally.spines, d.tally.plates])
	_leg_title.text = CS.t("leg_title")
	_place_leg()
	_leg_card.visible = true
	_leg_card.pivot_offset = _leg_card.size / 2.0
	_leg_card.scale = Vector2(0.96, 0.96)
	_leg_card.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_leg_card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(_leg_card, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)

## Dev (`cell finish`): open the end card of a finished cell with this legacy.
func jump_to_end(legacy: Dictionary) -> void:
	_show_leg(legacy)

## The bridge: a fade through the water colour (500 ms, ease-out), then the new creature game on the island (terrain cache or the
## loading screen). The legacy it takes is the one on the card.
func _to_creature() -> void:
	if _bridging:
		return
	_bridging = true
	_game().creature_legacy = _leg_cur.duplicate(true)
	_bridge_host = Control.new()
	_bridge_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bridge_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bridge_host)
	_bridge_veil = ColorRect.new()
	_bridge_veil.name = "BridgeVeil"
	_bridge_veil.color = Color("0F2229", 0.0)       # the water of the cell scene
	_bridge_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_bridge_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bridge_veil)
	var tw := create_tween()
	tw.tween_property(_bridge_veil, "color:a", 1.0, BRIDGE_FADE).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_game().enter_island_new(_bridge_host)       # a cache hit changes the scene here; a miss shows the loading screen under the veil
		var back := create_tween()
		back.tween_property(_bridge_veil, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
		back.tween_callback(func() -> void: _bridge_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE))

func _hide_leg(instant := false) -> void:
	if instant:
		_leg_shown = false
	if instant or not _leg_card.visible:
		_leg_card.visible = false
		return
	var tw := create_tween()
	tw.tween_property(_leg_card, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _leg_card.visible = false)
