extends Control
## HUD: player vitals, move bar (keys 1-4 + guard + dodge), toasts, DNA toasts,
## enemy marker above the selected creature, wind-up tell, flashes, floating damage.

const Palette := preload("res://ui/palette.gd")
const Sweep := preload("res://ui/cooldown_sweep.gd")

signal ability_clicked(index: int)
signal guard_clicked
signal dodge_clicked(dir: int)
signal pause_clicked

var camera: Camera3D
var player_name: Label
var player_hp_text: Label
var hp_bar: ProgressBar
var st_bar: ProgressBar
var slots: Array[Button] = []
var sweeps: Array = []          # one cooldown sweep per slot button
var slot_abilities: Array = []
var guard_btn: Button
var toasts: VBoxContainer
var dna_box: VBoxContainer
var target_panel: PanelContainer
var target_name: Label
var target_hp: ProgressBar
var windup_bar: ProgressBar
var windup_label: Label
var flash_rect: Panel
var damage_layer: Control
var _numbers: Array = []
var _anchor = null  # Vector3 world position or null
var _flash_tween: Tween
var move_row: HBoxContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()

func _build() -> void:
	flash_rect = Panel.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.modulate.a = 0.0
	add_child(flash_rect)
	# Header
	var head := HBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 28
	head.offset_right = -28
	head.offset_top = 22
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = "Primigenia"
	t.add_theme_font_size_override("font_size", 26)
	tv.add_child(t)
	var s := Label.new()
	s.text = "THE FIRST VALLEY"
	s.add_theme_font_size_override("font_size", 10)
	s.add_theme_color_override("font_color", Palette.MUTED)
	tv.add_child(s)
	head.add_child(tv)
	var pb := Button.new()
	pb.text = "Pause"
	pb.custom_minimum_size = Vector2(0, 40)
	pb.pressed.connect(func() -> void: pause_clicked.emit())
	head.add_child(pb)
	add_child(head)
	# DNA toasts (top-right under header)
	dna_box = VBoxContainer.new()
	dna_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	dna_box.offset_left = -220
	dna_box.offset_right = -28
	dna_box.offset_top = 80
	dna_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dna_box)
	# Player vitals
	var vit := PanelContainer.new()
	vit.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 16, Palette.BORDER, 12))
	vit.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	vit.offset_left = 28
	vit.offset_bottom = -26
	vit.offset_top = -100
	vit.offset_right = 262
	vit.grow_vertical = Control.GROW_DIRECTION_BEGIN
	vit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 4)
	var row := HBoxContainer.new()
	player_name = Label.new()
	player_name.text = "Your creature"
	player_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_name.add_theme_font_size_override("font_size", 16)
	row.add_child(player_name)
	player_hp_text = Label.new()
	player_hp_text.add_theme_color_override("font_color", Palette.MUTED)
	row.add_child(player_hp_text)
	vv.add_child(row)
	hp_bar = Palette.bar(Palette.LEAF, 9)
	st_bar = Palette.bar(Palette.EMBER, 5)
	vv.add_child(hp_bar)
	vv.add_child(st_bar)
	vit.add_child(vv)
	add_child(vit)
	# Move bar
	move_row = HBoxContainer.new()
	move_row.add_theme_constant_override("separation", 7)
	move_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	move_row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	move_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	move_row.offset_bottom = -26
	move_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(move_row)
	for i in 4:
		var b := _slot_button()
		var idx := i
		b.pressed.connect(func() -> void: ability_clicked.emit(idx))
		move_row.add_child(b)
		slots.append(b)
		var sw := Sweep.new()
		sw.visible = false
		b.add_child(sw)
		sweeps.append(sw)
	var sep := VSeparator.new()
	move_row.add_child(sep)
	guard_btn = _slot_button()
	guard_btn.text = "Space\nGuard"
	guard_btn.pressed.connect(func() -> void: guard_clicked.emit())
	move_row.add_child(guard_btn)
	var dl := _slot_button()
	dl.text = "Q\nDodge L"
	dl.pressed.connect(func() -> void: dodge_clicked.emit(-1))
	move_row.add_child(dl)
	var dr := _slot_button()
	dr.text = "E\nDodge R"
	dr.pressed.connect(func() -> void: dodge_clicked.emit(1))
	move_row.add_child(dr)
	# Message toasts (above move bar)
	toasts = VBoxContainer.new()
	toasts.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toasts.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toasts.offset_bottom = -110
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)
	# Target marker (name + hp + wind-up tell), follows the selected creature
	target_panel = PanelContainer.new()
	target_panel.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_SOLID, 10, Palette.BORDER, 7))
	target_panel.custom_minimum_size = Vector2(170, 0)
	target_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tvv := VBoxContainer.new()
	tvv.add_theme_constant_override("separation", 3)
	target_name = Label.new()
	target_name.add_theme_color_override("font_color", Palette.GOLD)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tvv.add_child(target_name)
	target_hp = Palette.bar(Palette.DANGER, 8)
	tvv.add_child(target_hp)
	windup_label = Label.new()
	windup_label.add_theme_font_size_override("font_size", 11)
	windup_label.add_theme_color_override("font_color", Palette.EMBER)
	windup_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	windup_label.visible = false
	tvv.add_child(windup_label)
	windup_bar = Palette.bar(Palette.EMBER, 5)
	windup_bar.visible = false
	tvv.add_child(windup_bar)
	target_panel.add_child(tvv)
	target_panel.visible = false
	add_child(target_panel)
	damage_layer = Control.new()
	damage_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(damage_layer)
	set_abilities([])

func _slot_button() -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(66, 54)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 12)
	return b

# --- player ------------------------------------------------------------------

func set_player(pname: String, hp: float, hp_max: float, stamina: float, stamina_max: float) -> void:
	player_name.text = pname
	hp_bar.max_value = maxf(hp_max, 1.0)
	hp_bar.value = clampf(hp, 0.0, hp_bar.max_value)
	st_bar.max_value = maxf(stamina_max, 1.0)
	st_bar.value = clampf(stamina, 0.0, st_bar.max_value)
	player_hp_text.text = "%d" % ceili(maxf(hp, 0.0))

## Each ability: {id, name, stamina?, enabled?, role?, empty?}. `role` colours the slot border (Palette.ROLE_COLORS);
## an empty loadout slot ({empty: true}) shows its key and a dash.
func set_abilities(list: Array) -> void:
	slot_abilities = list.slice(0, 4)
	for i in 4:
		var b := slots[i]
		if i < slot_abilities.size():
			var a: Dictionary = slot_abilities[i]
			var empty := bool(a.get("empty", false))
			b.text = "%d\n%s" % [i + 1, "-" if empty else a.get("name", a.get("id", "?"))]
			b.disabled = empty or not bool(a.get("enabled", true))
			b.tooltip_text = "Stamina %d" % int(a.get("stamina", 0)) if a.has("stamina") and not empty else ""
			b.visible = true
		else:
			b.text = "%d\n-" % [i + 1]
			b.disabled = true
			b.visible = false
		_style_slot(i)
		sweeps[i].set_frac(0.0)
	guard_btn.disabled = false

## fractions 0..1 of the cooldown still to wait, one per slot (1 = just used); missing entries mean ready.
func set_cooldowns(fracs: Array) -> void:
	for i in 4:
		sweeps[i].set_frac(float(fracs[i]) if i < fracs.size() else 0.0)

func _slot_role(i: int) -> String:
	return str(slot_abilities[i].get("role", "")) if i < slot_abilities.size() else ""

# The role colour is the border of the slot; an empty or role-less slot keeps the theme's border.
func _style_slot(i: int) -> void:
	var b := slots[i]
	var role := _slot_role(i)
	if role == "":
		b.remove_theme_stylebox_override("normal")
		return
	var st := Palette.box(Palette.PANEL_SOLID, 12, Palette.role_color(role), 8)
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)

func press_slot(i: int) -> void:
	if i < 0 or i >= 4:
		return
	var b := slots[i]
	b.add_theme_stylebox_override("normal", Palette.box(Palette.PANEL_ACTIVE, 12, Palette.GOLD, 8))
	get_tree().create_timer(0.15).timeout.connect(func() -> void:
		if is_instance_valid(b):
			_style_slot(i))

# --- toasts ------------------------------------------------------------------

func show_message(text: String, kind: String = "info", seconds: float = 3.0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var col: Color = Palette.DANGER if kind == "bad" else (Palette.LEAF if kind == "good" else Palette.TEXT)
	l.add_theme_color_override("font_color", col)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Palette.box(Color("17281fe6"), 20, Palette.BORDER, 7))
	pc.add_child(l)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(pc)
	_fade_out(pc, seconds)
	while toasts.get_child_count() > 4:
		toasts.get_child(0).queue_free()
		toasts.remove_child(toasts.get_child(0))
	return l

func show_dna(amount: int) -> void:
	var l := Label.new()
	l.text = "+%d DNA" % amount
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Palette.LEAF)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dna_box.add_child(l)
	_fade_out(l, 2.2)

func _fade_out(n: Control, seconds: float) -> void:
	if not is_inside_tree():
		return
	var tw := n.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(n, "modulate:a", 0.0, 0.4)
	tw.tween_callback(n.queue_free)

# --- target ------------------------------------------------------------------

func set_target(info: Dictionary) -> void:
	if info.is_empty():
		target_panel.visible = false
		_anchor = null
		return
	target_name.text = String(info.get("name", info.get("species", "")))
	target_hp.max_value = maxf(float(info.get("hp_max", 100)), 1.0)
	target_hp.value = clampf(float(info.get("hp", target_hp.max_value)), 0.0, target_hp.max_value)
	target_hp.visible = info.has("hp")
	_anchor = info.get("world_pos", null)
	target_panel.visible = true
	_place_target()

## progress 0..1 of the enemy's wind-up; negative hides the tell.
func set_windup(progress: float, label: String = "") -> void:
	var on := progress >= 0.0
	windup_bar.visible = on
	windup_label.visible = on and label != ""
	windup_label.text = label
	windup_bar.max_value = 1.0
	windup_bar.value = clampf(progress, 0.0, 1.0)

func _place_target() -> void:
	if not target_panel.visible:
		return
	var p := Vector2(size.x * 0.5, 90.0)
	if _anchor is Vector3 and camera and not camera.is_position_behind(_anchor):
		p = camera.unproject_position(_anchor)
		p.y -= 34.0
	target_panel.reset_size()
	target_panel.position = p - Vector2(target_panel.size.x * 0.5, target_panel.size.y)

# --- feedback ----------------------------------------------------------------

func flash(kind: String) -> void:
	var col: Color = {"hit": Palette.DANGER, "guard": Palette.GUARD, "dodge": Palette.GOLD}.get(kind, Palette.TEXT)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(col, 0.07)
	s.border_color = col
	s.set_border_width_all(10)
	s.draw_center = true
	flash_rect.add_theme_stylebox_override("panel", s)
	flash_rect.modulate.a = 1.0
	if _flash_tween:
		_flash_tween.kill()
	if is_inside_tree():
		_flash_tween = create_tween()
		_flash_tween.tween_property(flash_rect, "modulate:a", 0.0, 0.35)

## pos: Vector3 world position (needs set_camera) or Vector2 screen position.
func show_damage(pos, amount: float, on_player: bool = false) -> void:
	var l := Label.new()
	l.text = str(int(round(amount)))
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("ffb5a0") if on_player else Color("ffe3b4"))
	l.add_theme_color_override("font_outline_color", Color("481f18"))
	l.add_theme_constant_override("outline_size", 5)
	damage_layer.add_child(l)
	_numbers.append({"label": l, "pos": pos, "age": 0.0})
	_place_number(_numbers[-1])

func _place_number(n: Dictionary) -> void:
	var l: Label = n.label
	var p := size * 0.5
	if n.pos is Vector2:
		p = n.pos
	elif n.pos is Vector3 and camera:
		if camera.is_position_behind(n.pos):
			l.visible = false
			return
		p = camera.unproject_position(n.pos)
	l.visible = true
	l.position = p + Vector2(-l.size.x * 0.5, -l.size.y * 0.5 - n.age * 60.0)
	l.modulate.a = clampf(1.6 - n.age * 1.6, 0.0, 1.0)

func _process(dt: float) -> void:
	_place_target()
	for i in range(_numbers.size() - 1, -1, -1):
		var n: Dictionary = _numbers[i]
		n.age += dt
		if n.age > 1.0:
			n.label.queue_free()
			_numbers.remove_at(i)
		else:
			_place_number(n)
