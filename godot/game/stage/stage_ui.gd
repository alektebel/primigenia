extends Node
# Glue between the stage (C world bridge, island, actors) and the g-ui / g-audio modules (docs/godot/UI.md).
#
#   world tick   -> vitals, selection card, wind-up tell, damage numbers, flashes, combat sounds
#   click        -> Game.creature_clicked -> card + radial menu (G75)
#   mode / keys  -> C orders: attack #id <move> (keys 1-4 of the active mode), guard, dodge
#   frame        -> footsteps (locomotion foot contacts), ambience by height
#
# Orders reach the C world only through `provide()`, which replaces PlayerInput.sample as the stage's
# input provider: one-shot orders, a pending attack that keeps approaching until the fight starts, and
# keyboard / click movement otherwise (the same intents the web stage sent, web/stage/stage.js input()).

const GameUI := preload("res://ui/game_ui.gd")
const Modes := preload("res://ui/modes.gd")
const V_WAIT := 1
const V_ATTACK := 5
const V_GUARD := 8
const V_DODGE := 9
const DODGE_LEFT := 2       # web/stage: Q -> 2, E -> 6
const DODGE_RIGHT := 6
const MOVE_NAMES := ["Bite", "Charge", "Guard", "Spit", "Tail strike", "Dodge"]

var ui: CanvasLayer
var island: Node3D
var stage: Node
var player_input
var species: Array = []
var player_name := "Merodeador"
var selected_id := -1
var attack_orders: Array = []        # log of orders sent, for tests: {tick, text|input}
var last_outcome := 0
var _pending_attack = null           # {target, move}
var _oneshot = null                  # CpStageInput dictionary
var _was_active := false
var _slope := 0.0
var _ambience_started := false

func setup(island_node: Node3D, name_text: String) -> void:
	island = island_node
	stage = island.stage
	player_input = island.player_input
	player_name = name_text
	species = CporeWorld.species()
	ui = GameUI.new()
	ui.name = "GameUI"
	island.add_child(ui)
	ui.set_camera(Game.camera)
	if Engine.has_singleton("Audio") or get_tree().root.has_node("Audio"):
		ui.bind_audio(get_tree().root.get_node("Audio"))
	ui.mode_changed.connect(_on_mode)
	ui.ability_pressed.connect(_on_ability)
	ui.guard_pressed.connect(func() -> void: _send({"verb": V_GUARD}, "guard"))
	ui.dodge_pressed.connect(func(d: int) -> void:
		island.dodge_hint = {"dir": d, "until": Time.get_ticks_msec() + 700}      # which way the dodge animation leans
		_send({"verb": V_DODGE, "dir": DODGE_LEFT if d < 0 else DODGE_RIGHT}, "dodge"))
	ui.selection_changed.connect(func(id) -> void:
		selected_id = -1 if id == null else int(id)
		island.selected_id = selected_id)
	ui.pause_toggled.connect(_on_pause)
	ui.save_requested.connect(func() -> void: _toast(island.save_game(), "Game saved."))
	ui.load_requested.connect(func() -> void: _toast(island.load_game(), "Game loaded."))
	Game.creature_clicked.connect(_on_clicked)
	Game.world_ticked.connect(_on_tick)
	Game.combat_events.connect(_on_events)
	stage.input_provider = provide
	_on_tick(stage.cur)

# --- orders ---------------------------------------------------------------------

func _send(input: Dictionary, label: String) -> void:
	_oneshot = input
	attack_orders.append({"tick": stage.cur.tick, "order": label})

func _on_mode(mode: StringName) -> void:
	island.ui_mode = mode
	if selected_id <= 0:
		return
	if mode == Modes.ATTACK:
		_attack(0)
	else:
		ui.show_message("%s is not in this build yet; the valley only knows combat." % String(Modes.TITLES.get(mode, mode)), "info")

func _on_ability(index: int, ability: Dictionary) -> void:
	if ui.mode != Modes.ATTACK:
		# no C verb yet (WIRE.md): the creature still performs it, cosmetically, in rhythm with the P4 beat
		var layer = island.hosts[0].layer() if island.hosts.has(0) else null
		if layer != null:
			layer.trigger(str(ability.get("id", "")))
		ui.show_message("%s is not in this build yet." % String(ability.get("name", "")), "info")
		return
	if selected_id <= 0 and stage.cur.active >= 0:
		selected_id = stage.cur.active + 1
	if selected_id <= 0:
		ui.show_message("Click a creature first.", "info")
		return
	_attack(index)

func _attack(index: int) -> void:
	var moves: Array = Modes.abilities_for(Modes.ATTACK)
	var move_id := str(moves[clampi(index, 0, moves.size() - 1)].id)
	var move := ["bite", "charge", "guard", "spit", "tail_strike", "dodge"].find(move_id)
	var ent: Dictionary = stage.cur.entities[selected_id] if selected_id < stage.cur.entities.size() else {}
	if ent.is_empty() or ent.dead:
		return
	_pending_attack = {"target": selected_id, "move": move}
	player_input.clear_destination()
	attack_orders.append({"tick": stage.cur.tick, "order": "attack #%d %s" % [selected_id, move_id]})

# Replaces PlayerInput.sample as the input provider of the stage. As in web/stage/simulation.js action():
# a pending attack is sent every tick (the C verb only lasts while it is re-issued) until movement keys or a
# click-to-walk replace it, the target dies or the fight ends; guard and dodge are one tick each.
func provide() -> Dictionary:
	var s: Dictionary = player_input.sample()
	if s.verb == 3 or s.verb == 2:
		_pending_attack = null
	var st: Dictionary = stage.cur
	var active: bool = st.active >= 0
	if _was_active and not active:
		_pending_attack = null
	_was_active = active
	if _oneshot != null:
		var o: Dictionary = _oneshot
		_oneshot = null
		return o
	if _pending_attack != null:
		var tgt: int = _pending_attack.target
		if tgt >= st.entities.size() or st.entities[tgt].dead or (active and st.active + 1 != tgt):
			_pending_attack = null
		else:
			return {"verb": V_ATTACK, "target": tgt, "move": _pending_attack.move}
	return s

# --- selection ------------------------------------------------------------------

func info_for(id: int) -> Dictionary:
	var st: Dictionary = stage.cur
	var e: Dictionary = st.entities[id]
	var sp: Dictionary = species[e.species] if e.species >= 0 and e.species < species.size() else {}
	var pos := Vector3(e.x, Game.ground(e.x, e.z), e.z)
	var h := 1.5
	if island.hosts.has(id):
		h = island.hosts[id].height()
	return {"id": id, "name": sp.get("name", "Creature"), "species": sp.get("name", "Creature"),
		"temperament": int(sp.get("temperament", 1)), "diet": 1, "relationship": 0, "resolved": 0, "resolved_total": 4,
		"likes": "", "hp": e.hp, "hp_max": e.hp_max, "world_pos": pos + Vector3(0, h * 1.25, 0)}

func _on_clicked(id: int, _pos: Vector3) -> void:
	if id <= 0 or id >= stage.cur.entities.size():
		return
	ui.select(info_for(id), true, island.last_click)

func select_id(id: int, menu_pos: Variant = null) -> void:
	ui.select(info_for(id), true, menu_pos)

# --- world -> UI ----------------------------------------------------------------

func _on_tick(state: Dictionary) -> void:
	var p: Dictionary = state.entities[0]
	ui.set_player(player_name, p.hp, p.hp_max, p.stamina, p.stamina_max)
	if selected_id > 0 and selected_id < state.entities.size():
		var e: Dictionary = state.entities[selected_id]
		if e.dead:
			ui.clear_selection()
		else:
			var inf := info_for(selected_id)
			ui.update_target({"hp": inf.hp, "hp_max": inf.hp_max, "world_pos": inf.world_pos})
	# the enemy's wind-up tell
	var tell := -1.0
	var label := ""
	for f in state.combat.fighters:
		if f.world_id != 0 and f.phase == 1:
			tell = clampf(float(f.phase_tick) / maxf(float(f.phase_length), 1.0), 0.0, 1.0)
			label = MOVE_NAMES[f.move] if f.move >= 0 and f.move < MOVE_NAMES.size() else ""
	ui.set_windup(tell, label)
	if state.outcome != last_outcome:
		last_outcome = state.outcome
		match state.outcome:
			1:
				ui.show_dna(12)
				ui.show_message("A new trace of life. Keep exploring.", "good")
			2:
				ui.show_message("Back to the nest...", "bad")
			3:
				ui.show_message("Safe for now. The wild creature returns home.", "info")

func _entity_pos(state: Dictionary, fighter: int) -> Vector3:
	var id: int = 0 if fighter == 0 else int(state.active) + 1
	if id >= state.entities.size():
		id = 0
	var e: Dictionary = state.entities[id]
	return Vector3(e.x, Game.ground(e.x, e.z), e.z)

func _on_events(events: Array) -> void:
	var state: Dictionary = stage.cur
	var audio = get_tree().root.get_node_or_null("Audio")
	for ev in events:
		var at := _entity_pos(state, int(ev.b))
		var radius := 60.0
		var vid: int = 0 if ev.b == 0 else int(state.active) + 1
		if vid < state.entities.size():
			radius = float(state.entities[vid].get("radius_cm", 60))
		match int(ev.type):
			1:
				ui.show_damage(at + Vector3(0, 2.2, 0), ev.amount, ev.b == 0)
				if ev.b == 0:
					ui.flash("hit")
			2, 3:
				if ev.b == 0:
					ui.flash("guard")
			4:
				if ev.b == 0:
					ui.flash("dodge")
		if audio != null:
			audio.combat_event(int(ev.type), at, radius)

# err "" = success: show `ok_text`; otherwise the error sentence as a warning.
func _toast(err: String, ok_text: String) -> void:
	if err == "":
		ui.show_message(ok_text, "info")
		ui.set_paused(false)
	else:
		ui.show_message(err, "warn")

func _on_pause(paused: bool) -> void:
	stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

# --- per frame ------------------------------------------------------------------

func _process(_dt: float) -> void:
	Game.modal_open = ui.radial.visible or ui.paused
	Game.radial_open = ui.radial.visible
	Game.paused_ui = ui.paused
	var audio = get_tree().root.get_node_or_null("Audio")
	if audio == null or island.player_pos == Vector3.INF:
		return
	if not _ambience_started and Input.is_anything_pressed():
		audio.start_ambience()
		_ambience_started = true
	var pos: Vector3 = island.player_pos
	var n: Vector3 = Game.data.normal(pos.x, pos.z)
	_slope = sqrt(maxf(1.0 - n.y * n.y, 0.0)) / maxf(n.y, 0.05)
	var speed: float = stage.cur.entities[0].speed
	audio.update_ambience(pos, pos.y - float(Game.terrain.get("params", {}).get("valley_floor_m", 42.0)) + 5.0, _slope, speed)

func on_footfall(id: int, pos: Vector3, speed: float) -> void:
	var audio = get_tree().root.get_node_or_null("Audio")
	if audio == null:
		return
	var radius := 60.0
	if id < stage.cur.entities.size():
		radius = float(stage.cur.entities[id].get("radius_cm", 60))
	if id == 0 or (pos - island.player_pos).length() < 40.0:
		audio.footstep(pos, speed, radius)
