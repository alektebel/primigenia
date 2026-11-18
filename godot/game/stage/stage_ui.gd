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
const Palette := preload("res://ui/palette.gd")
const V_WAIT := 1
const V_ATTACK := 5
const V_GUARD := 8
const V_DODGE := 9
const V_LOADOUT := 10       # target = slot 1..4, move = move id or -1: instant, only at the nest (C: not_at_nest / in_fight)
const DODGE_LEFT := 2       # web/stage: Q -> 2, E -> 6
const DODGE_RIGHT := 6
const MOVE_IDS := ["bite", "charge", "guard", "spit", "tail_strike", "dodge"]
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
var _pending_social = null           # {verb, target, move, sent}: a C2 social order (befriend, gift, observe, intimidate, eat)
var _chains: Array = []               # CporeWorld.chains(): the observe clues per species
var _gift := 1                        # the gift item (Modes.ITEMS index) of the G key
var _style := "roar"                  # which intimidate animation the last Intimidate key chose
var _prev_action := 0
var _last_social_tick := -1
var _pending_sent_tick := -1
var _oneshot = null                  # CpStageInput dictionary
var _was_active := false
var _slope := 0.0
var _moves: Array = []                # CporeWorld.moves(), the C move table
var _loadout_key := ""                # last loadout state pushed to the hotbar (so it is rebuilt only on change)
var _ambience_started := false

func setup(island_node: Node3D, name_text: String) -> void:
	island = island_node
	stage = island.stage
	player_input = island.player_input
	player_name = name_text
	species = CporeWorld.species()
	_moves = CporeWorld.moves()
	_chains = CporeWorld.chains()
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
	ui.loadout_panel.setup(_moves)
	ui.loadout_panel.assign.connect(assign_loadout)
	ui.loadout_requested.connect(toggle_loadout_panel)
	ui.gift_pressed.connect(give_gift)
	ui.gift_cycle_pressed.connect(cycle_gift)
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

# Select first, then choose: picking a mode only changes the hotbar; nothing is ordered until an ability key (1-4) is pressed.
func _on_mode(mode: StringName) -> void:
	island.ui_mode = mode
	_pending_social = null

func _on_ability(index: int, ability: Dictionary) -> void:
	if selected_id <= 0 and stage.cur.active >= 0 and ui.mode == Modes.ATTACK:
		selected_id = stage.cur.active + 1
	if selected_id <= 0:
		ui.show_message("Click a creature first, then choose what to do.", "info")
		return
	if ui.mode == Modes.ATTACK:
		_attack(index)
		return
	var verb: String = Modes.VERBS[ui.mode]
	var move := 0
	if verb == "befriend":
		move = index                       # sing, dance, charm, pose = CP_SOC_*
	elif verb == "intimidate":
		_style = str(ability.get("id", "roar"))
	social_order(verb, selected_id, move)

# A C2 social order: sent once, then the C world keeps it (walking into range, performing, finishing) until another
# order replaces it; the UI only has to stop re-sending and say why when C refuses.
func social_order(verb: String, target: int, move: int = 0) -> void:
	_pending_attack = null
	_pending_social = {"verb": int(Modes.VERB_NUMBERS[verb]), "target": target, "move": move, "sent": false}
	player_input.clear_destination()
	attack_orders.append({"tick": stage.cur.tick, "order": "%s #%d %d" % [verb, target, move]})

func give_gift() -> void:
	if selected_id <= 0:
		ui.show_message("Click a creature first, then press G to give it a gift.", "info")
		return
	var items: Array = stage.cur.social.items
	if int(items[_gift]) <= 0:
		ui.show_message("You have no %s to give." % Modes.ITEMS[_gift], "warn")
		return
	social_order("gift", selected_id, _gift)

func cycle_gift() -> void:
	var items: Array = stage.cur.social.items
	for k in 4:
		_gift = (_gift + 1) % 4
		if int(items[_gift]) > 0:
			break
	ui.show_message("Gift: %s (x%d)" % [Modes.ITEMS[_gift], int(items[_gift])], "info")

# Keys 1-4 fire the move in loadout slot `index` (A21), not a fixed move: the hotbar entry carries the C move id.
func _attack(index: int) -> void:
	var list: Array = ui.abilities if not ui.abilities.is_empty() else Modes.abilities_for(Modes.ATTACK)
	if index < 0 or index >= list.size() or bool(list[index].get("empty", false)):
		return
	var move_id := str(list[index].id)
	var move: int = int(list[index].move) if list[index].has("move") else MOVE_IDS.find(move_id)
	if move < 0:
		return
	var ent: Dictionary = stage.cur.entities[selected_id] if selected_id < stage.cur.entities.size() else {}
	if ent.is_empty() or ent.dead:
		return
	_pending_attack = {"target": selected_id, "move": move}
	player_input.clear_destination()
	attack_orders.append({"tick": stage.cur.tick, "order": "attack #%d %s" % [selected_id, move_id]})

# --- loadout (A21) --------------------------------------------------------------

# The order goes to the C world like any other input (one tick, logged and replayed); C answers not_at_nest,
# in_fight, not_known, unknown_move. `slot` is 0..3 (key - 1), `move` a move id or -1 to empty the slot.
func assign_loadout(slot: int, move: int) -> void:
	var lo: Dictionary = stage.cur.loadout
	if not bool(lo.can_edit):
		ui.show_message("Go back to your nest to change your moves.", "warn")
		return
	stage.queue_order({"verb": V_LOADOUT, "target": slot + 1, "move": move})
	attack_orders.append({"tick": stage.cur.tick, "order": "loadout %d %s" % [slot + 1, MOVE_IDS[move] if move >= 0 else "none"]})

func toggle_loadout_panel() -> void:
	var lo: Dictionary = stage.cur.loadout
	if not ui.loadout_panel.visible and not bool(lo.can_edit):
		ui.show_message("Go back to your nest to change your moves.", "info")
		return
	ui.loadout_panel.refresh(lo)
	ui.loadout_panel.toggle()

# The hotbar of Attack mode: the slots of the C loadout, each with the role colour and its cooldown sweep.
func _loadout_abilities(lo: Dictionary) -> Array:
	var out: Array = []
	for i in 4:
		var id := int(lo.slots[i])
		if id < 0 or id >= _moves.size():
			out.append({"id": "", "name": "-", "empty": true, "enabled": false, "move": -1})
			continue
		var m: Dictionary = _moves[id]
		var shown := str(Modes.ABILITIES[Modes.ATTACK][0].name)
		for a in Modes.ABILITIES[Modes.ATTACK]:
			if a.id == m.name:
				shown = str(a.name)
		out.append({"id": str(m.name), "name": shown, "move": id, "role": str(m.role_name), "stamina": int(m.stamina),
			"cooldown": int(m.cooldown)})
	return out

func _cooldown_fractions(state: Dictionary, abilities: Array) -> Array:
	var fracs := []
	var left: Array = []
	for f in state.combat.fighters:
		if int(f.world_id) == 0:
			left = f.get("cooldowns", [])
	for a in abilities:
		var mv := int(a.get("move", -1))
		var total := int(a.get("cooldown", 0))
		fracs.append(0.0 if mv < 0 or total <= 0 or mv >= left.size() else clampf(float(left[mv]) / float(total), 0.0, 1.0))
	return fracs

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
	if _pending_social != null:
		var ps: Dictionary = _pending_social
		var gone: bool = ps.target >= st.entities.size() or active
		if s.verb == 3 or s.verb == 2 or gone:
			_pending_social = null        # keys or a click on the ground replace it; so does a fight
		elif not ps.sent:
			ps.sent = true
			_pending_sent_tick = int(st.tick)
			return {"verb": ps.verb, "target": ps.target, "move": ps.move}
		elif int(st.order.verb) == ps.verb:
			return {"verb": 0}            # still running in C: keep it (WAIT would cancel it)
		else:
			_pending_social = null        # finished or rejected
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
	var soc: Dictionary = st.get("social", {})
	var carcass: bool = bool(e.get("dead", false))
	return {"id": id, "name": sp.get("name", "Creature"), "species": sp.get("name", "Creature"),
		"temperament": int(e.get("temperament", sp.get("temperament", 1))), "diet": 1 if int(e.species) >= 2 else 0,
		"relationship": int(e.get("relationship", 0)), "resolved": int(soc.get("resolved", 0)), "resolved_total": int(soc.get("resolved_total", 4)),
		"trust": int(e.get("trust", 0)), "mood": int(e.get("mood", 0)), "bonded": bool(e.get("bonded", false)),
		"likes": e.get("likes", []), "dislikes": e.get("dislikes", []), "beat_in": int(e.get("beat_in", 0)),
		"carcass_meat": int(e.get("meat", 0)) if carcass else -1,
		"hp": e.hp, "hp_max": e.hp_max, "world_pos": pos + Vector3(0, h * 1.25 if not carcass else 0.6, 0)}

func _on_clicked(id: int, _pos: Vector3) -> void:
	if id <= 0 or id >= stage.cur.entities.size():
		return
	ui.select(info_for(id), true, island.last_click)

func select_id(id: int, menu_pos: Variant = null) -> void:
	ui.select(info_for(id), true, menu_pos)

# --- world -> UI ----------------------------------------------------------------

func _on_tick(state: Dictionary) -> void:
	var lo: Dictionary = state.get("loadout", {"slots": [0, 1, 3, 4], "known": 0, "can_edit": false})
	var key := "%s|%d" % [lo.slots, int(lo.known)]
	if key != _loadout_key:
		_loadout_key = key
		ui.set_loadout_abilities(_loadout_abilities(lo))
	ui.set_cooldowns(_cooldown_fractions(state, ui.loadout_abilities))
	if ui.loadout_panel.visible:
		ui.loadout_panel.refresh(lo)
		if not bool(lo.can_edit):
			ui.loadout_panel.close_panel()       # a fight started or the player walked away from the nest
	var p: Dictionary = state.entities[0]
	ui.set_player(player_name, p.hp, p.hp_max, p.stamina, p.stamina_max)
	_on_social(state)
	if selected_id > 0 and selected_id < state.entities.size():
		var e: Dictionary = state.entities[selected_id]
		if e.dead and int(e.get("meat", 0)) <= 0:
			ui.clear_selection()
		else:
			var inf := info_for(selected_id)
			inf.erase("id")
			ui.update_target(inf)
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
	Game.modal_open = ui.radial.visible or ui.paused or ui.loadout_panel.visible
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

# --- C2: social state and events -> HUD ---------------------------------------------------------

const EV_SKILL := 10
const EV_GIFT := 11
const EV_BOND_MADE := 12
const EV_BOND_BROKEN := 13
const EV_SPECIES_RESOLVED := 14
const EV_DNA := 15
const EV_OBSERVE := 16
const EV_CHAIN_DONE := 17
const EV_INTIMIDATE := 18
const EV_CANCELLED := 19
const EV_EAT := 20
const DNA_SOURCES := ["kill", "bond", "ally", "dominate", "carcass", "exploration", "new species"]

func _on_social(state: Dictionary) -> void:
	var soc: Dictionary = state.get("social", {})
	if soc.is_empty():
		return
	ui.set_meters(int(soc.dna_total), int(soc.dna_balance), int(soc.resolved), int(soc.resolved_total), int(soc.food), int(soc.food_max))
	ui.hud.set_gift("%s x%d" % [Modes.ITEMS[_gift], int(soc.items[_gift])])
	# rejected order: say why
	if _pending_sent_tick >= 0 and int(state.tick) == _pending_sent_tick + 1:
		_pending_sent_tick = -1
		if int(state.error) < 0:
			ui.show_message(_error_text(int(state.error)), "warn")
	# rings around the selected creature
	var observe := -1.0
	var beat := false
	var beat_in := 0
	var trust := -1.0
	if selected_id > 0 and selected_id < state.entities.size():
		var e: Dictionary = state.entities[selected_id]
		if not bool(e.dead):
			beat = ui.mode == Modes.BEFRIEND
			beat_in = int(e.get("beat_in", 0))
			trust = float(e.get("trust", 0)) / 100.0 if beat else -1.0
			if int(soc.observe_target) == selected_id:
				observe = float(soc.observe_ticks) / maxf(float(soc.observe_ticks_max), 1.0)
		ui.set_rings(beat, beat_in, observe, trust, bool(e.dead))
	else:
		ui.set_rings(false, 0, -1.0, -1.0)
	# the creature performs what C is performing (animation is cosmetic, timed by the C action)
	var act: Dictionary = soc.action
	var verb := int(act.verb)
	if verb != _prev_action and verb != 0 and island.hosts.has(0):
		var layer = island.hosts[0].layer()
		if layer != null:
			var id := ""
			match verb:
				11:
					id = ["sing", "dance", "charm", "pose"][clampi(int(act.arg), 0, 3)]
				12:
					id = "gift"
				14:
					id = _style
			if id != "":
				layer.trigger(id)
	_prev_action = verb
	for ev in state.get("social_events", []):
		_social_event(ev, state)

func _error_text(code: int) -> String:
	return String(CporeWorld.order_error(code)).capitalize()

func _target_pos(state: Dictionary, id: int) -> Vector3:
	if id <= 0 or id >= state.entities.size():
		return island.player_pos
	var e: Dictionary = state.entities[id]
	return Vector3(e.x, Game.ground(e.x, e.z) + (2.0 if not bool(e.dead) else 0.8), e.z)

func _species_name(i: int) -> String:
	return String(species[i].name) if i >= 0 and i < species.size() else "Creature"

func _social_event(ev: Dictionary, state: Dictionary) -> void:
	var at := _target_pos(state, int(ev.target))
	match int(ev.type):
		EV_SKILL:
			var gain := int(ev.value)
			var mv := int(ev.move)
			if gain >= 0:
				ui.show_float(at, "+%d trust" % gain, Palette.LEAF, 24)
			else:
				ui.show_float(at, "%d trust" % gain, Palette.DANGER, 24)
			if gain > 0 and (mv & 256) != 0:
				ui.show_float(at + Vector3(0, 0.5, 0), "In rhythm!", Palette.GOLD, 18)
			if gain > 0 and ((mv >> 9) & 3) > 0:
				ui.show_float(at + Vector3(0, 1.0, 0), "Combo x%.1f" % (1.5 if ((mv >> 9) & 3) == 1 else 2.0), Palette.EMBER, 18)
		EV_GIFT:
			var d := int(ev.value)
			ui.show_float(at, "%+d trust" % d, Palette.LEAF if d >= 0 else Palette.DANGER, 24)
			if float(ev.x) > 0.0:
				ui.show_message("It calms down.", "good")
			elif d <= -20:
				ui.show_message("That was an insult. Its herd saw it.", "bad")
		EV_BOND_MADE:
			ui.show_message("%s bonded!" % _species_name(int(ev.move)), "good")
		EV_BOND_BROKEN:
			ui.show_message("The bond is broken. Its pack turns on you.", "bad")
		EV_SPECIES_RESOLVED:
			ui.show_message("%s: %s" % [_species_name(int(ev.move)), "an alliance is made" if int(ev.value) == 1 else "dominated"], "good")
		EV_DNA:
			var src: int = int(ev.move)
			ui.show_dna(int(ev.value), DNA_SOURCES[src] if src >= 0 and src < DNA_SOURCES.size() else "")
		EV_OBSERVE:
			var sp := int(ev.value)
			var clue: String = String(_chains[sp].observe[int(ev.move)]) if sp < _chains.size() else ""
			ui.show_message("Observed: %s (%d/3)" % [clue, int(ev.x)], "info")
		EV_CHAIN_DONE:
			var mv2 := int(ev.move)
			ui.show_message("You understand how it moves. Learned: %s." % (String(_moves[mv2].name).capitalize() if mv2 >= 0 and mv2 < _moves.size() else "a move"), "good")
		EV_INTIMIDATE:
			if float(ev.value) > 0.0:
				ui.show_float(at, "It backs off!", Palette.GOLD, 24)
			else:
				ui.show_float(at, "It stands its ground", Palette.MUTED, 20)
		EV_CANCELLED:
			var r := int(ev.value)
			if r == 2:
				ui.show_message("A rival heckles you off.", "bad")
			elif r == 5:
				ui.show_float(at, "Seen! Back off and keep still.", Palette.EMBER, 18)
			elif r < 0 and r != -2:
				ui.show_message(_error_text(r), "warn")
		EV_EAT:
			var l = island.hosts[0].layer() if island.hosts.has(0) else null
			if l != null:
				l.trigger("eat")
			ui.show_float(at, "+%d food" % int(ev.value), Palette.LEAF, 20)
			if int(ev.move) <= 0:
				ui.show_message("Nothing left of it but bones.", "info")
