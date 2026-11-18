extends PanelContainer
## The loadout panel (docs/COMBAT-MOVES.md, A21): at the nest the player picks which known attack moves sit on
## keys 1-4. It only shows and asks: every change is an order `loadout SLOT MOVE` that the stage sends to the C
## world (so it is logged, replayed and validated there). Key L opens and closes it (InputMap action "loadout").
##
##   setup(moves)      CporeWorld.moves(): the move table (id, name, role_name, stamina, cooldown, slottable)
##   refresh(lo)       state.loadout: {slots: [move id or -1] x4, known: bitmask, can_edit, signature_slot, nest_radius}
##   assign(slot, move)  signal; slot 0..3, move id or -1 (empty)

const Palette := preload("res://ui/palette.gd")

signal assign(slot: int, move: int)
signal closed

var moves: Array = []
var option_buttons: Array = []     # one OptionButton per slot
var role_chips: Array = []         # one ColorRect per slot, in the role colour of its move
var note: Label
var _ids: Array = []               # option index -> move id (-1 = empty), shared by the four slots
var _last: Dictionary = {}
var _refreshing := false

func _init() -> void:
	name = "LoadoutPanel"
	visible = false
	add_theme_stylebox_override("panel", Palette.box(Palette.PANEL_SOLID, 16, Palette.BORDER, 14))
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(380, 0)

func _ready() -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var title := Label.new()
	title.text = "Loadout"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.GOLD)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "The moves you bring to a fight, on keys 1-4. Guard (Space) and dodge (Q / E) are always with you."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(340, 0)
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", Palette.MUTED)
	v.add_child(sub)
	for i in 4:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var key := Label.new()
		key.text = "%d" % (i + 1)
		key.custom_minimum_size = Vector2(18, 0)
		row.add_child(key)
		var chip := ColorRect.new()
		chip.custom_minimum_size = Vector2(6, 26)
		chip.color = Palette.BORDER_BTN
		row.add_child(chip)
		role_chips.append(chip)
		var ob := OptionButton.new()
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.focus_mode = Control.FOCUS_NONE
		var slot := i
		ob.item_selected.connect(func(idx: int) -> void: _on_selected(slot, idx))
		row.add_child(ob)
		option_buttons.append(ob)
		v.add_child(row)
	note = Label.new()
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Palette.EMBER)
	v.add_child(note)
	var close := Button.new()
	close.text = "Done"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_panel)
	v.add_child(close)
	if not moves.is_empty():
		_build_options()
	if not _last.is_empty():
		refresh(_last)

func setup(move_table: Array) -> void:
	moves = []
	for m in move_table:
		if bool(m.get("slottable", false)):
			moves.append(m)
	if is_inside_tree():
		_build_options()

func _build_options() -> void:
	_ids = [-1]
	for ob in option_buttons:
		ob.clear()
		ob.add_item("- empty -")
	for m in moves:
		_ids.append(int(m.id))
		for ob in option_buttons:
			ob.add_item("%s  (%s)" % [_pretty(str(m.name)), str(m.role_name)])

static func _pretty(id: String) -> String:
	return id.replace("_", " ").capitalize()

func is_known(move: int, known_mask: int) -> bool:
	return move >= 0 and (known_mask & (1 << move)) != 0

## Shows the loadout; moves that are not known are disabled in the lists, and without `can_edit` the whole panel is read-only.
func refresh(lo: Dictionary) -> void:
	_last = lo
	if option_buttons.is_empty() or _ids.is_empty():
		return
	_refreshing = true
	var known: int = int(lo.get("known", 0))
	var slots: Array = lo.get("slots", [-1, -1, -1, -1])
	var can: bool = bool(lo.get("can_edit", false))
	for i in 4:
		var ob: OptionButton = option_buttons[i]
		var cur := int(slots[i]) if i < slots.size() else -1
		ob.select(maxi(_ids.find(cur), 0))
		ob.disabled = not can
		for k in _ids.size():
			ob.set_item_disabled(k, _ids[k] >= 0 and not is_known(int(_ids[k]), known))
		var role := ""
		for m in moves:
			if int(m.id) == cur:
				role = str(m.role_name)
		role_chips[i].color = Palette.role_color(role)
	note.text = "" if can else "Go back to your nest (within %d m) to change your moves; never in a fight." % int(lo.get("nest_radius", 12))
	_refreshing = false

func _on_selected(slot: int, idx: int) -> void:
	if _refreshing or idx < 0 or idx >= _ids.size():
		return
	assign.emit(slot, int(_ids[idx]))

## For tests and keyboard users: choose `move` (id or -1) for `slot` exactly as clicking would.
func choose(slot: int, move: int) -> void:
	var idx := _ids.find(move)
	if idx < 0 or slot < 0 or slot > 3:
		return
	option_buttons[slot].select(idx)
	_on_selected(slot, idx)

func open_panel() -> void:
	visible = true

func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()

func toggle() -> void:
	if visible:
		close_panel()
	else:
		open_panel()
