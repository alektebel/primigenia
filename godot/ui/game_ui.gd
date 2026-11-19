extends CanvasLayer
## Facade for the stage: the mode ring, the field note, the signs, the menu. Documented in docs/godot/UI.md and
## docs/godot/UI-DIEGETIC.md. Add as a child of the stage; connect signals.

const Palette := preload("res://ui/palette.gd")
const Modes := preload("res://ui/modes.gd")
const Style := preload("res://ui/style.gd")
const Ring := preload("res://ui/mode_ring.gd")
const Petals := preload("res://ui/petals.gd")
const Defence := preload("res://ui/defence_marks.gd")
const Signs := preload("res://ui/quiet_signs.gd")
const Minimap := preload("res://ui/minimap.gd")
const Motes := preload("res://ui/motes.gd")
const Words := preload("res://ui/words.gd")
const Veil := preload("res://ui/veil.gd")
const RingFx := preload("res://ui/ring_fx.gd")
const Note := preload("res://ui/field_note.gd")
const Menu := preload("res://ui/menu.gd")
const Stub := preload("res://ui/stub_view.gd")
const Onboarding := preload("res://ui/onboarding.gd")
const LoadoutSheet := preload("res://ui/loadout_sheet.gd")

signal mode_changed(mode: StringName)
signal ability_pressed(index: int, ability: Dictionary)
signal gift_pressed
signal gift_cycle_pressed
signal guard_pressed
signal dodge_pressed(dir: int)
signal selection_changed(creature_id: Variant)
signal pause_toggled(paused: bool)
signal menu_requested
signal save_requested
signal load_requested
signal ui_click
signal journal_requested
signal family_tree_requested
signal loadout_requested             # key L / the panel's own close: the stage decides whether the nest allows it
signal loadout_assign(slot: int, move: int)   # slot 0..3, move id or -1

## No mode until the player chooses one on the ring (a fight starts in Attack).
var mode: StringName = Modes.NONE
var abilities: Array = []
var selected: Dictionary = {}
var paused := false
var root: Control
var note
var ring
var petals
var defence
var signs
var minimap
var motes
var words
var veil
var ring_fx
var menu
var stub
var onboarding
var loadout_panel
var loadout_abilities: Array = []   # the 4 hotbar entries of Attack mode once the stage knows the loadout
var audio
var camera: Camera3D
var ground_marks                    # GroundMarks (the rings on the ground), set by the stage
var anchor_fn := Callable()         # (id) -> {pos: Vector3 (feet), height: float}; the stage gives the rendered position
var fight := false
var player_name := ""
var dying := false
var loadout_available := false
var keys_pinned := false
var last_dna_source := ""
var selections := 0                 # how many selections were made: the first three show every mode name

func _init() -> void:
	layer = 10

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.make_theme()
	add_child(root)
	veil = Veil.new()
	root.add_child(veil)
	signs = Signs.new()
	root.add_child(signs)
	minimap = Minimap.new()
	root.add_child(minimap)
	note = Note.new()
	root.add_child(note)
	ring = Ring.new()
	root.add_child(ring)
	note.ring = ring
	petals = Petals.new()
	root.add_child(petals)
	defence = Defence.new()
	root.add_child(defence)
	ring_fx = RingFx.new()
	root.add_child(ring_fx)
	words = Words.new()
	root.add_child(words)
	motes = Motes.new()
	root.add_child(motes)
	menu = Menu.new()
	root.add_child(menu)
	stub = Stub.new()
	root.add_child(stub)
	onboarding = Onboarding.new(get_node_or_null("/root/Game"))
	loadout_panel = LoadoutSheet.new()
	root.add_child(loadout_panel)
	loadout_panel.assign.connect(func(slot: int, move: int) -> void: loadout_assign.emit(slot, move))
	loadout_panel.opened.connect(func() -> void: veil.set_flat(0.42))
	loadout_panel.closed.connect(func() -> void: veil.set_flat(0.62 if paused else 0.0))
	petals.petal_pressed.connect(func(i: int) -> void: _press(i))
	petals.gift_pressed.connect(func() -> void: gift_pressed.emit())
	defence.guard_pressed.connect(func() -> void: guard_pressed.emit())
	defence.dodge_pressed.connect(func(d: int) -> void: dodge_pressed.emit(d))
	ring.chosen.connect(func(m: StringName) -> void: set_mode(m))
	signs.seed_pressed.connect(func() -> void: set_paused(true))
	motes.landed.connect(func(tag: Variant, amount: int) -> void:
		if tag == "dna":
			signs.land_dna(amount)
		elif tag == "seed":
			signs.mark_seed())
	menu.resume_requested.connect(func() -> void: set_paused(false))
	menu.menu_requested.connect(func() -> void: menu_requested.emit())
	menu.save_requested.connect(func() -> void: save_requested.emit())
	menu.load_requested.connect(func() -> void: load_requested.emit())
	menu.journal_requested.connect(func() -> void: open_view("journal"))
	menu.family_tree_requested.connect(func() -> void: open_view("tree"))
	menu.loadout_requested.connect(func() -> void:
		set_paused(false)
		loadout_requested.emit())
	menu.keys_requested.connect(show_keys)
	menu.setting_changed.connect(_on_setting)
	menu.hints_reset_requested.connect(func() -> void: onboarding.reset())
	stub.closed.connect(func() -> void: veil.set_flat(0.62 if paused else 0.0))
	set_mode(mode)

# --- stage -> UI -------------------------------------------------------------------------------------------------

func set_camera(cam: Camera3D) -> void:
	camera = cam
	words.camera = cam
	ring_fx.camera = cam

func set_ground_marks(gm) -> void:
	ground_marks = gm
	ring_fx.ground_marks = gm

func bind_audio(a) -> void:
	audio = a
	menu.bind_audio(a)
	if a and not ui_click.is_connected(a.ui_click):
		ui_click.connect(a.ui_click)

func set_player(pname: String, hp: float, hp_max: float, stamina: float, stamina_max: float) -> void:
	player_name = pname
	signs.set_player(hp, hp_max, stamina, stamina_max)
	veil.low_health = lerpf(0.6, 1.0, clampf((0.30 - hp / maxf(hp_max, 1.0)) / 0.20, 0.0, 1.0)) if hp > 0.0 and hp / maxf(hp_max, 1.0) < 0.30 else 0.0

## info: see docs/godot/UI.md (id, name, species, temperament, diet, relationship, resolved, likes, hp, hp_max, world_pos,
## body_pos, height, radius_m, fight). Shows the field note and the ground ring and opens the mode ring (no mode is chosen
## yet) unless open_menu is false; `info.fight` with open_menu false goes straight to Attack (a fight started).
func select(info: Dictionary, open_menu: bool = true, menu_pos: Variant = null) -> void:
	selected = info
	selections += 1
	onboarding.notify("select")
	note.set_info(info)
	var carcass := int(info.get("carcass_meat", -1)) >= 0
	ring.carcass = carcass
	ring.refuses = bool(info.get("refuses", false))
	ring.names_all = selections <= 3
	set_mode(Modes.NONE, false)
	if ground_marks != null:
		ground_marks.select(int(info.get("id", -1)), float(info.get("radius_m", 0.6)))
	selection_changed.emit(info.get("id", null))
	if open_menu:
		open_radial(menu_pos if menu_pos is Vector2 else Vector2.ZERO)
	else:
		ring.close()
		if bool(info.get("fight", false)):
			set_mode(Modes.ATTACK)

## Refresh live fields (hp, relationship, world_pos) of the selected creature.
func update_target(info: Dictionary) -> void:
	if selected.is_empty():
		return
	selected.merge(info, true)
	note.set_info(selected)
	ring.refuses = bool(selected.get("refuses", false))

func clear_selection() -> void:
	selected = {}
	if ground_marks != null:
		ground_marks.deselect()
	ring.carcass = false
	note.hide_note()
	ring.close()
	set_mode(Modes.NONE, false)
	selection_changed.emit(null)

func set_mode(m, emit: bool = true) -> void:
	if not Modes.is_mode(m):
		push_warning("unknown mode %s" % m)
		return
	mode = StringName(m)
	ring.current = mode
	if mode != Modes.NONE:
		note.mode_was_chosen()
		onboarding.notify("mode")
		if mode == Modes.EAT:
			onboarding.notify("eat")
	if ground_marks != null and not selected.is_empty():
		ground_marks.set_mode_style(mode)
	_sync_defence()
	petals.likes = selected.get("likes", []) if selected.get("likes", []) is Array else []
	petals.dislikes = selected.get("dislikes", []) if selected.get("dislikes", []) is Array else []
	if mode == Modes.NONE:
		set_abilities([])
	else:
		set_abilities(loadout_abilities if mode == Modes.ATTACK and not loadout_abilities.is_empty() else Modes.abilities_for(mode))
	if emit:
		mode_changed.emit(mode)

## Replace the move bar content: Array of {id, name, stamina?, enabled?}, max 4.
func set_abilities(list: Array) -> void:
	abilities = list.slice(0, 4)
	petals.set_items(abilities, mode)
	_sync_defence()

## The hotbar of Attack mode: 4 entries {id, name, move, role, stamina, cooldown, empty?}, in slot order (keys 1-4).
func set_loadout_abilities(list: Array) -> void:
	loadout_abilities = list.slice(0, 4)
	if mode == Modes.ATTACK:
		set_abilities(loadout_abilities)

## Cooldown fractions (1 = just used, 0 = ready) per hotbar slot.
func set_cooldowns(fracs: Array) -> void:
	petals.set_cooldowns(fracs)

## The gift of the G key: item index (Modes.ITEMS) and how many are carried; H cycles the item.
func set_gift(item: int, count: int) -> void:
	petals.set_gift(item, count)

## A fight is on: guard and dodge show at your feet whatever the mode.
func set_fight(on: bool) -> void:
	fight = on
	_sync_defence()

func _sync_defence() -> void:
	defence.set_shown(fight or mode == Modes.ATTACK)

## Open the mode ring on the selected creature (Tab reopens it); pos is a screen position, used when no camera can project
## the creature.
func open_radial(pos: Vector2 = Vector2.ZERO) -> void:
	if selected.is_empty():
		return
	_track_ring(pos)
	ring.open_at(ring.centre, ring.body_half_height, mode)

func show_damage(pos, amount: float, on_player: bool = false) -> void:
	if Style.numbers():
		words.number(pos, str(int(round(amount))), Palette.EMBER_HOT if on_player else Palette.BONE)

## A whisper line (one at a time, 3.5 s); `kind` only chooses the sound.
func show_message(text: String, kind: String = "info") -> void:
	words.whisper(text)
	if audio and kind != "info" and audio.has_method("ui_click"):
		audio.ui_click()

## A moment line (rare: a move learned, a bond): Alegreya Italic, with its glyph, queued.
func show_moment(text: String, glyph: String = "") -> void:
	words.moment(text, glyph)

## A clue was learned (observe): its text as a whisper, a mote from the creature to the seed (the journal).
func show_clue(world_pos: Variant, text: String) -> void:
	words.whisper(text)
	var from := root.size * Vector2(0.5, 0.6)
	if world_pos is Vector3 and camera != null and not camera.is_position_behind(world_pos):
		from = camera.unproject_position(world_pos)
	motes.fly(from, signs.seed_center(), "seed", 0)

## Death: time and colour drain into fog closing in from the edges; every sign but the seed goes (docs 7.12).
func begin_death() -> void:
	dying = true

func end_death() -> void:
	dying = false

## DNA gained: a copper mote flies from `world_pos` (a place in the world; the player if null) to the DNA sign, and the
## number waits for it. `source` is only a label for tests and the journal.
func show_dna(amount: int, source: String = "", world_pos: Variant = null) -> void:
	var from := Vector2.ZERO
	if world_pos is Vector3 and camera != null and not camera.is_position_behind(world_pos):
		from = camera.unproject_position(world_pos)
	elif defence.centre != Vector2.ZERO:
		from = defence.centre
	else:
		from = root.size * Vector2(0.5, 0.7)
	signs.hold_dna(amount)
	last_dna_source = source
	motes.fly(from, signs.dna_center(), "dna", amount)
	if Style.reduced_motion():
		signs.land_dna(amount)

## DNA total (journal), balance (the number), species resolved of those present, food.
func set_meters(dna_total: int, dna_balance: int, resolved: int, total: int, food: int, food_max: int) -> void:
	signs.set_meters(dna_total, dna_balance, resolved, total, food, food_max)

## Rings of the selected creature: the beat ring (befriend), observe progress, trust; observe/trust < 0 hide them.
func set_rings(beat: bool, beat_in: int, observe: float, trust: float, carcass: bool = false) -> void:
	if ground_marks == null or selected.is_empty():
		return
	match mode:
		Modes.BEFRIEND:
			ground_marks.set_value(maxf(trust, 0.0))
		Modes.OBSERVE:
			ground_marks.set_value(maxf(observe, 0.0))
		Modes.ATTACK:
			ground_marks.set_value(float(selected.get("hp", 1.0)) / maxf(float(selected.get("hp_max", 1.0)), 1.0))
		Modes.EAT:
			ground_marks.set_segments(4, maxi(int(selected.get("carcass_meat", 4)), 0))
	ground_marks.set_beat(beat_in if beat and mode == Modes.BEFRIEND else -1, ground_marks.in_window(beat_in))

## A short number at a world position: only with Numbers: On (the marks say it otherwise).
func show_float(pos, text: String, color: Color = Palette.LEAF, _size_px: int = 22) -> void:
	if Style.numbers():
		words.number(pos, text, color)

func set_windup(progress: float, _label: String = "") -> void:
	if ground_marks != null:
		ground_marks.set_windup(progress if not selected.is_empty() else -1.0)

## kind: "hit", "guard", "dodge".
func flash(kind: String) -> void:
	if kind == "hit":
		signs.set_hit()
		veil.trigger_hit()
	else:
		defence.ripple()

func set_paused(on: bool) -> void:
	paused = on
	if on:
		menu.open_menu()
		veil.set_flat(0.62)
	else:
		menu.close_menu()
		stub.open = false
		veil.set_flat(0.0)
	signs.menu_open = on
	if audio:
		audio.set_paused(on)
	pause_toggled.emit(on)

## Journal (J) or family tree (T): their pages are a later design; the view is a veil with a title.
func open_view(kind: String) -> void:
	if kind != "journal":
		family_tree_requested.emit()        # the real tree (game/stage/lineage_controller.gd) opens itself
		if not family_tree_requested.get_connections().is_empty():
			return
	else:
		journal_requested.emit()
	stub.open_view(kind, signs.dna_total)
	veil.set_flat(0.5)

func close_view() -> void:
	stub.close_view()
	veil.set_flat(0.62 if paused else 0.0)

## The key sheet (F1 held shows it too): pinned open from the menu until Esc.
func show_keys() -> void:
	var dev = get_node_or_null("/root/Dev")
	if dev != null and dev.legend != null:
		dev.legend.pin_sheet(true)
		keys_pinned = true
	notify_onboarding("f1")

func notify_onboarding(event: String) -> void:
	onboarding.notify(event)

func _on_setting(key: String, _v) -> void:
	if key in ["minimap", "language", "ui_scale", "names_always", "numbers", "strong_outlines", "reduced_motion"]:
		minimap.poke()
	if key == "ui_scale":
		for c in [signs, ring, petals, defence, words, note, minimap]:
			c.queue_redraw()

# --- ring placement ----------------------------------------------------------------------------------------------

# The ring sits on the target's body centre in screen space; its radius follows the body's on-screen height.
func _track_ring(fallback: Vector2 = Vector2.ZERO) -> void:
	var feet := Vector3.ZERO
	var h := 1.5
	var have := false
	if anchor_fn.is_valid() and selected.has("id"):
		var a: Dictionary = anchor_fn.call(int(selected.id))
		if not a.is_empty():
			feet = a.pos
			h = float(a.height)
			have = true
	if not have and selected.has("body_pos"):
		feet = selected.body_pos - Vector3(0, float(selected.get("height", 1.5)) * 0.5, 0)
		h = float(selected.get("height", 1.5))
		have = true
	if have and camera != null and not camera.is_position_behind(feet + Vector3(0, h * 0.5, 0)):
		var mid := camera.unproject_position(feet + Vector3(0, h * 0.5, 0))
		var top := camera.unproject_position(feet + Vector3(0, h, 0))
		ring.centre = mid
		ring.body_half_height = maxf(absf(mid.y - top.y), 24.0)
	elif fallback != Vector2.ZERO:
		ring.centre = fallback
	elif ring.centre == Vector2.ZERO:
		ring.centre = root.size * 0.5

func _process(dt: float) -> void:
	_onboard(dt)
	veil.death = move_toward(veil.death, 1.0 if dying else 0.0, dt / 1.2)
	signs.fade_all = veil.death
	if not selected.is_empty():
		_track_ring()
		petals.centre = ring.centre
		petals.body_half_height = ring.body_half_height
	_track_player()

# Guard and dodge sit on the player's own ground ring, projected to the screen.
func _track_player() -> void:
	if not defence.shown and not defence.visible:
		return
	if camera != null and anchor_fn.is_valid():
		var a: Dictionary = anchor_fn.call(0)
		if not a.is_empty() and not camera.is_position_behind(a.pos):
			defence.centre = camera.unproject_position(a.pos)
			var top := camera.unproject_position(a.pos + Vector3(0, float(a.height), 0))
			defence.ring_radius = clampf(absf(defence.centre.y - top.y) * 0.5, Style.u(40.0), Style.u(90.0))
	elif defence.centre == Vector2.ZERO:
		defence.centre = root.size * Vector2(0.5, 0.78)

# --- input -------------------------------------------------------------------------------------------------------

func _press(i: int) -> void:
	if mode == Modes.NONE or i < 0 or i >= abilities.size() or not bool(abilities[i].get("enabled", true)):
		return
	petals.press(i)
	onboarding.notify("ability")
	ui_click.emit()
	ability_pressed.emit(i, abilities[i])

func _unhandled_input(e: InputEvent) -> void:
	if keys_pinned and e is InputEventKey and e.pressed and e.is_action_pressed("pause_menu"):
		_unpin_keys()
		get_viewport().set_input_as_handled()
		return
	if stub.open:
		if stub.handle_input(e):
			if not stub.open:
				pass
			get_viewport().set_input_as_handled()
		return
	if paused:
		if menu.handle_input(e):
			get_viewport().set_input_as_handled()
		return
	if loadout_panel.visible_open:
		if loadout_panel.handle_input(e):
			get_viewport().set_input_as_handled()
		return
	if e is InputEventMouseButton or e is InputEventMouseMotion:
		if signs.handle_input(e) or ring.handle_input(e) or petals.handle_input(e) or defence.handle_input(e):
			get_viewport().set_input_as_handled()
		return
	if not (e is InputEventKey) or not e.pressed or e.echo:
		return
	if e.is_action_pressed("pause_menu"):
		if ring.visible:
			ring.close()               # Esc closes the ring first (the selection stays)
		elif not selected.is_empty():
			clear_selection()          # then deselects; a third Esc opens the menu
		else:
			set_paused(true)
		get_viewport().set_input_as_handled()
		return
	if e.is_action_pressed("journal"):
		open_view("journal")
		return
	if e.is_action_pressed("family_tree"):
		open_view("tree")
		return
	if e.is_action_pressed("gift"):
		gift_pressed.emit()
		return
	if e.is_action_pressed("gift_cycle"):
		gift_cycle_pressed.emit()
		return
	if e.is_action_pressed("loadout"):
		onboarding.notify("loadout")
		loadout_requested.emit()
		return
	for i in 4:
		if e.is_action_pressed("ability_%d" % (i + 1)):
			_press(i)
			return
	if e.is_action_pressed("guard"):
		onboarding.notify("guard")
		guard_pressed.emit()
	elif e.is_action_pressed("dodge_left"):
		onboarding.notify("guard")
		dodge_pressed.emit(-1)
	elif e.is_action_pressed("dodge_right"):
		onboarding.notify("guard")
		dodge_pressed.emit(1)
	elif e.is_action_pressed("radial_reopen"):
		if not selected.is_empty():
			open_radial()

func _unpin_keys() -> void:
	keys_pinned = false
	var dev = get_node_or_null("/root/Dev")
	if dev != null and dev.legend != null:
		dev.legend.pin_sheet(false)

# The hint line: one at a time, from the situation (docs 7.15); silent in menus and once everything is learned.
func _onboard(dt: float) -> void:
	var sit := {"ring": ring.visible, "mode": mode != Modes.NONE, "fight": fight,
		"carcass": int(selected.get("carcass_meat", -1)) >= 0, "nest": loadout_available}
	var h: Dictionary = onboarding.update(dt, sit) if not paused and not stub.open and not dying else {}
	words.set_hint(h.get("text", ""), h.get("keys", ""))
	ring.names_all = selections <= 3 or onboarding.current == 3

func set_loadout_available(on: bool) -> void:
	loadout_available = on
	menu.loadout_available = on
