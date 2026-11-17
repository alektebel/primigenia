extends CanvasLayer
## F3 tuning panel: groups movement / camera / locomotion / combat (empty in DT0), a slider + value + reset per row,
## a "changed only" filter, Save A / Save B (store the current values in a slot), Save file. F4 swaps A/B (dev.gd).

const Palette := preload("res://ui/palette.gd")

var tuning       # the registry
var panel: PanelContainer
var box: VBoxContainer
var changed_only := false
var is_open := false
var _rows := {}   # key -> {row, slider, label}

func _init() -> void:
	layer = 32

func _ready() -> void:
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Palette.box(Color(Palette.PANEL_SOLID, 0.95), 14, Palette.BORDER, 10))
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -430
	panel.offset_top = 50
	panel.offset_bottom = -50
	panel.visible = false
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	add_child(panel)

func rebuild() -> void:
	for c in box.get_children():
		c.queue_free()
		box.remove_child(c)
	_rows.clear()
	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "Tuning"
	title.add_theme_color_override("font_color", Palette.GOLD)
	head.add_child(title)
	var only := CheckBox.new()
	only.text = "changed only"
	only.button_pressed = changed_only
	only.toggled.connect(func(on): changed_only = on; refresh())
	head.add_child(only)
	box.add_child(head)
	var btns := HBoxContainer.new()
	for item in [["Save as A", "A"], ["Save as B", "B"]]:
		var b := Button.new()
		b.text = item[0]
		var slot: String = item[1]
		b.pressed.connect(func():
			tuning.slots[slot] = tuning.current_values()
			tuning.active = slot)
		btns.add_child(b)
	var sv := Button.new()
	sv.text = "Save file"
	sv.pressed.connect(func(): tuning.save_file("tuning-%s" % Time.get_datetime_string_from_system(false).replace(":", "").replace("-", "")))
	btns.add_child(sv)
	box.add_child(btns)
	var group := ""
	for k in tuning.order:
		var e: Dictionary = tuning.entries[k]
		if e.group != group:
			group = e.group
			var l := Label.new()
			l.text = group
			l.add_theme_color_override("font_color", Palette.LEAF)
			box.add_child(l)
		var row := HBoxContainer.new()
		var name := Label.new()
		name.text = k.get_slice("/", 1)
		name.custom_minimum_size = Vector2(120, 0)
		name.add_theme_font_size_override("font_size", 12)
		row.add_child(name)
		var s := HSlider.new()
		s.min_value = e.min
		s.max_value = e.max
		s.step = e.step
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(120, 22)
		s.set_value_no_signal(tuning.value(k))
		var key: String = k
		var val := Label.new()
		val.custom_minimum_size = Vector2(52, 0)
		val.add_theme_font_size_override("font_size", 12)
		s.value_changed.connect(func(v):
			tuning.set_value(key, v)
			val.text = str(snappedf(tuning.value(key), 0.001)))
		row.add_child(s)
		row.add_child(val)
		var r := Button.new()
		r.text = "x"
		r.pressed.connect(func():
			tuning.reset(key)
			refresh())
		row.add_child(r)
		box.add_child(row)
		_rows[k] = {"row": row, "slider": s, "label": val}
	refresh()

func refresh() -> void:
	for k in _rows:
		var rr: Dictionary = _rows[k]
		rr.slider.set_value_no_signal(tuning.value(k))
		rr.label.text = str(snappedf(tuning.value(k), 0.001))
		rr.row.visible = not changed_only or tuning.is_changed(k)

func toggle() -> void:
	is_open = not is_open
	panel.visible = is_open
	if is_open:
		rebuild()

func _unhandled_input(e: InputEvent) -> void:
	if tuning == null or not (e is InputEventKey) or not e.pressed or e.echo or not Dev.enabled:
		return
	if e.is_action_pressed("dev_tuning"):
		toggle()
	elif e.is_action_pressed("dev_ab_swap"):
		var err: String = tuning.swap()
		if err != "":
			push_warning(err)
		if is_open:
			refresh()
	else:
		return
	get_viewport().set_input_as_handled()
