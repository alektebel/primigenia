extends CanvasLayer
## Facade for the stage: HUD + creature card + radial menu + pause menu.
## Documented in docs/godot/UI.md. Add as a child of the stage; connect signals.

const Palette := preload("res://ui/palette.gd")
const Modes := preload("res://ui/modes.gd")
const Hud := preload("res://ui/hud.gd")
const Card := preload("res://ui/creature_card.gd")
const Radial := preload("res://ui/radial_menu.gd")
const Pause := preload("res://ui/pause_menu.gd")

signal mode_changed(mode: StringName)
signal ability_pressed(index: int, ability: Dictionary)
signal guard_pressed
signal dodge_pressed(dir: int)
signal selection_changed(creature_id: Variant)
signal pause_toggled(paused: bool)
signal ui_click

var mode: StringName = Modes.ATTACK
var abilities: Array = []
var selected: Dictionary = {}
var paused := false
var root: Control
var hud
var card
var radial
var pause_menu
var audio

func _init() -> void:
	layer = 10

func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.make_theme()
	add_child(root)
	hud = Hud.new()
	root.add_child(hud)
	card = Card.new()
	card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.offset_right = -28
	card.offset_top = 80
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.visible = false
	root.add_child(card)
	radial = Radial.new()
	root.add_child(radial)
	pause_menu = Pause.new()
	root.add_child(pause_menu)
	hud.ability_clicked.connect(func(i: int) -> void: _press(i))
	hud.guard_clicked.connect(func() -> void: guard_pressed.emit())
	hud.dodge_clicked.connect(func(d: int) -> void: dodge_pressed.emit(d))
	hud.pause_clicked.connect(func() -> void: set_paused(true))
	radial.chosen.connect(func(m: StringName) -> void: set_mode(m))
	pause_menu.resume_requested.connect(func() -> void: set_paused(false))
	set_mode(mode)

# --- stage -> UI -------------------------------------------------------------

func set_camera(cam: Camera3D) -> void:
	hud.camera = cam

func bind_audio(a) -> void:
	audio = a
	pause_menu.bind_audio(a)
	if a and not ui_click.is_connected(a.ui_click):
		ui_click.connect(a.ui_click)

func set_player(pname: String, hp: float, hp_max: float, stamina: float, stamina_max: float) -> void:
	hud.set_player(pname, hp, hp_max, stamina, stamina_max)

## info: see docs/godot/UI.md (id, name, species, temperament, diet, relationship, resolved, likes, hp, hp_max, world_pos).
## Shows the card and the marker; opens the radial menu unless open_menu is false.
func select(info: Dictionary, open_menu: bool = true, menu_pos: Variant = null) -> void:
	selected = info
	card.set_info(info)
	card.visible = true
	hud.set_target(info)
	selection_changed.emit(info.get("id", null))
	if open_menu:
		var p: Vector2 = menu_pos if menu_pos is Vector2 else root.size * Vector2(0.42, 0.5)
		open_radial(p)

## Refresh live fields (hp, relationship, world_pos) of the selected creature.
func update_target(info: Dictionary) -> void:
	if selected.is_empty():
		return
	selected.merge(info, true)
	card.set_info(selected)
	hud.set_target(selected)

func clear_selection() -> void:
	selected = {}
	card.visible = false
	hud.set_target({})
	hud.set_windup(-1.0)
	radial.close()
	selection_changed.emit(null)

func set_mode(m, emit: bool = true) -> void:
	if not Modes.is_mode(m):
		push_warning("unknown mode %s" % m)
		return
	mode = StringName(m)
	radial.current = mode
	set_abilities(Modes.abilities_for(mode))
	if emit:
		mode_changed.emit(mode)

## Replace the move bar content: Array of {id, name, stamina?, enabled?}, max 4.
func set_abilities(list: Array) -> void:
	abilities = list.slice(0, 4)
	hud.set_abilities(abilities)

func open_radial(pos: Vector2 = Vector2.ZERO) -> void:
	radial.open_at(pos if pos != Vector2.ZERO else root.size * 0.5, mode)

func show_damage(pos, amount: float, on_player: bool = false) -> void:
	hud.show_damage(pos, amount, on_player)

func show_message(text: String, kind: String = "info") -> void:
	hud.show_message(text, kind)

func show_dna(amount: int) -> void:
	hud.show_dna(amount)

func set_windup(progress: float, label: String = "") -> void:
	hud.set_windup(progress, label)

## kind: "hit", "guard", "dodge".
func flash(kind: String) -> void:
	hud.flash(kind)

func set_paused(on: bool) -> void:
	paused = on
	pause_menu.visible = on
	if on:
		pause_menu.refresh()
	if audio:
		audio.set_paused(on)
	pause_toggled.emit(on)

# --- input -------------------------------------------------------------------

func _press(i: int) -> void:
	if i < 0 or i >= abilities.size() or not bool(abilities[i].get("enabled", true)):
		return
	hud.press_slot(i)
	ui_click.emit()
	ability_pressed.emit(i, abilities[i])

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.keycode == KEY_ESCAPE:
		if radial.visible:
			radial.close()
		else:
			set_paused(not paused)
		get_viewport().set_input_as_handled()
		return
	if paused:
		return
	match e.keycode:
		KEY_1, KEY_2, KEY_3, KEY_4:
			_press(e.keycode - KEY_1)
		KEY_SPACE:
			guard_pressed.emit()
		KEY_Q:
			dodge_pressed.emit(-1)
		KEY_E:
			dodge_pressed.emit(1)
		KEY_TAB:
			if not selected.is_empty():
				open_radial()
