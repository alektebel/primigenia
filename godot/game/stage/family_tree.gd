extends Control
## A13 history: live creature meshes, never screenshots or borrowed UI art.
const Palette := preload("res://ui/palette.gd")
const CreatureMesh := preload("res://creature/creature.gd")
const Session := preload("res://game/stage/lineage_session.gd")
signal closed
signal cousin_pin_requested(generation: Dictionary)
var portraits: Array[SubViewport] = []
var generation_count := 0
var _row: HBoxContainer
var _close: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = Palette.make_theme()
	var back := ColorRect.new()
	back.color = Palette.PANEL_SOLID
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 16)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := Label.new()
	title.text = "Your lineage"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_close = Button.new()
	_close.text = "Return to the valley  ·  T"
	_close.custom_minimum_size.y = 44
	_close.pressed.connect(func() -> void: closed.emit())
	header.add_child(_close)
	var sub := Label.new()
	sub.text = "Every body leaves a branch. Your deeds shape what comes next."
	sub.add_theme_color_override("font_color", Palette.MUTED)
	page.add_child(sub)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(scroll)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 20)
	scroll.add_child(_row)

func show_lineage(data: Dictionary) -> void:
	for child in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	portraits.clear()
	var generations: Array = data.get("generations", [])
	generation_count = generations.size()
	var previous_traits := 0
	var previous_code := ""
	for g in generations:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 300
		col.add_theme_constant_override("separation", 8)
		_row.add_child(col)
		var current: bool = int(g.cousin_id) == 0
		_label(col, "GENERATION %d%s" % [g.generation, "  ·  living now" if current else "  ───→"], 16, Palette.GOLD)
		_portrait(col, JSON.parse_string(str(g.body_json)))
		_label(col, str(g.type_code) + "  ·  " + str(g.type_name), 20, Palette.LEAF)
		var drift: Array = []
		var code := str(g.type_code)
		if previous_code != "":
			var axes := ["Approach", "Diet", "Life", "Temper"]
			for axis in 4:
				if previous_code[axis * 2] != code[axis * 2]:
					drift.append("%s %s → %s" % [axes[axis], previous_code[axis * 2], code[axis * 2]])
		_label(col, " · ".join(drift) if not drift.is_empty() else "A new beginning" if previous_code == "" else "A familiar way of life", 14, Palette.GOLD)
		previous_code = code
		_label(col, str(g.name), 15, Palette.TEXT)
		var gained: Array = []
		var lost: Array = []
		var ids := Session.part_ids()
		for entry in data.get("entries", []):
			if int(entry.cause) != int(g.generation) - 1:
				continue
			var id := int(entry.id)
			var part: String = str(ids[id]) if id >= 0 and id < ids.size() else "part %d" % id
			if entry.kind == "part_gained":
				gained.append("+ %s ×%d" % [part, entry.value])
			elif entry.kind == "part_lost":
				lost.append("− %s ×%d" % [part, entry.value])
		_label(col, ", ".join(gained + lost) if not (gained + lost).is_empty() else "Founding body" if int(g.generation) == 1 else "Body proportions changed", 15, Palette.TEXT)
		var mask: int = int(data.get("trait_mask", 0)) if current else int(g.trait_mask)
		if current:
			mask = 0
			for name_text in data.get("traits", []):
				mask |= 1 << ["hunter", "social", "nocturnal", "burrower", "aquatic", "flyer", "void-adapted"].find(name_text)
		var earned: Array = []
		var trait_names := ["Hunter", "Social", "Nocturnal", "Burrower", "Aquatic", "Flyer", "Void-adapted"]
		for i in trait_names.size():
			if (mask & (1 << i)) != 0 and (previous_traits & (1 << i)) == 0:
				earned.append(trait_names[i])
		previous_traits = mask
		_label(col, "Traits earned: " + (", ".join(earned) if not earned.is_empty() else "still taking shape"), 15, Palette.MUTED)
		var stem := VSeparator.new()
		stem.custom_minimum_size = Vector2(1, 20)
		stem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		col.add_child(stem)
		if current:
			_label(col, "You are writing this chapter.", 15, Palette.GOLD)
		else:
			var pin := Button.new()
			pin.text = "Cousin branch · locate on map"
			pin.custom_minimum_size.y = 44
			pin.pressed.connect(func() -> void: cousin_pin_requested.emit(g))
			col.add_child(pin)
			_label(col, "Home: %.0f, %.0f m · +%d trust" % [g.home_cm[0] / 100.0, g.home_cm[1] / 100.0, g.trust_bonus], 14, Palette.MUTED)
	if generations.is_empty():
		_label(_row, "Your lineage begins when you enter the valley.", 20, Palette.MUTED)
	_close.grab_focus()

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 280
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _portrait(parent: Control, genome) -> void:
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(300, 180)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(container)
	var vp := SubViewport.new()
	vp.size = Vector2i(300, 180)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	portraits.append(vp)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("22372b")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c5d6b5")
	environment.environment.ambient_light_energy = 0.8
	vp.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -35, 0)
	light.light_energy = 1.5
	vp.add_child(light)
	if not genome is Dictionary:
		return
	var body := CreatureMesh.new()
	vp.add_child(body)
	var result: Dictionary = body.load_genome(genome)
	if not result.get("ok", false):
		return
	var radius := 1.0
	for n in genome.get("nodes", []):
		radius = maxf(radius, maxf(absf(float(n.get("z", 0))), float(n.get("r", 0))))
	var camera := Camera3D.new()
	vp.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = radius * 3.2
	var target := Vector3(0, body.ground_offset + radius * 0.15, 0)
	camera.position = target + Vector3(radius * 3, radius * 1.5, radius * 3)
	camera.look_at(target)
	camera.current = true
