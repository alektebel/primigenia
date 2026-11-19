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
const Strings := preload("res://ui/strings.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Profile := preload("res://game/stage/profile.gd")
const JournalModel := preload("res://ui/journal_model.gd")
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
var _fight_prev := false
var _dying := false
var _death_clock := 0.0
var _last_pressed := -1
var _whispers := {}                   # how many times a rule whisper was shown (only the first two)
var _bonded_species := {}
var _pearls := 0

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
	ui.set_ground_marks(island.ground_marks)
	ui.anchor_fn = _anchor
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
	ui.nest_requested.connect(open_nest_editor)
	ui.gift_pressed.connect(give_gift)
	ui.gift_cycle_pressed.connect(cycle_gift)
	ui.pause_toggled.connect(_on_pause)
	ui.journal.source = _journal_model
	ui.journal.opened.connect(_on_journal_toggled.bind(true))
	ui.journal.closed.connect(_on_journal_toggled.bind(false))
	ui.save_requested.connect(func() -> void: _toast(island.save_game(), Strings.t("saved")))
	ui.load_requested.connect(func() -> void: _toast(island.load_game(), Strings.t("loaded")))
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
	_last_pressed = index
	if selected_id <= 0 and stage.cur.active >= 0 and ui.mode == Modes.ATTACK:
		selected_id = stage.cur.active + 1
	if selected_id <= 0:
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
		return
	var items: Array = stage.cur.social.items
	if int(items[_gift]) <= 0:
		ui.petals.refuse(4)
		return
	social_order("gift", selected_id, _gift)

func cycle_gift() -> void:
	var items: Array = stage.cur.social.items
	for k in 4:
		_gift = (_gift + 1) % 4
		if int(items[_gift]) > 0:
			break
	ui.set_gift(_gift, int(items[_gift]))

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
		_refuse(-13)
		return
	stage.queue_order({"verb": V_LOADOUT, "target": slot + 1, "move": move})
	attack_orders.append({"tick": stage.cur.tick, "order": "loadout %d %s" % [slot + 1, MOVE_IDS[move] if move >= 0 else "none"]})

func toggle_loadout_panel() -> void:
	var lo: Dictionary = stage.cur.loadout
	if not ui.loadout_panel.visible_open and not bool(lo.can_edit):
		_refuse(-13)
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
	if int(st.get("parts", {}).get("inspecting", 0)) != 0 and s.verb != 2 and s.verb != 3:
		return {"verb": 0}
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

# The rendered position and height of a creature (the host node), for the ring and the signs anchored to it.
func _anchor(id: int) -> Dictionary:
	if not island.hosts.has(id):
		return {}
	var h = island.hosts[id]
	var p: Vector3 = h.global_position
	p.y = Game.ground(p.x, p.z)
	var ent: Dictionary = stage.cur.entities[id] if id < stage.cur.entities.size() else {}
	return {"pos": p, "height": h.height() * (0.45 if bool(ent.get("dead", false)) else 1.0)}

func info_for(id: int) -> Dictionary:
	var st: Dictionary = stage.cur
	var e: Dictionary = st.entities[id]
	var sp: Dictionary = species[e.species] if e.species >= 0 and e.species < species.size() else {}
	var pos := Vector3(e.x, Game.ground(e.x, e.z), e.z)
	var h := 1.5
	if island.hosts.has(id):
		h = island.hosts[id].height()
	var cousin: Dictionary = preload("res://game/stage/lineage_session.gd").cousin(stage.world, id)
	var shown_name: String = str(sp.get("name", "Creature")) if cousin.is_empty() else str(cousin.name)
	var soc: Dictionary = st.get("social", {})
	var carcass: bool = bool(e.get("dead", false))
	var temper := int(e.get("temperament", sp.get("temperament", 1)))
	return {"id": id, "name": shown_name, "species": shown_name, "cousin_generation": int(e.get("cousin_generation", 0)),
		"radius_m": maxf(0.6, float(e.get("radius_cm", 60)) * 0.01), "height": h, "body_pos": pos + Vector3(0, h * 0.5, 0),
		"refuses": not carcass and (int(e.get("mood", 0)) <= -20 or (temper == 2 and int(e.get("relationship", 0)) <= 0)),
		"temperament": int(e.get("temperament", sp.get("temperament", 1))) if cousin.is_empty() else int(cousin.temperament), "diet": (1 if int(e.species) >= 2 else 0) if cousin.is_empty() else int(cousin.diet),
		"relationship": int(e.get("relationship", 0)), "resolved": int(soc.get("resolved", 0)), "resolved_total": int(soc.get("resolved_total", 4)),
		"trust": int(e.get("trust", 0)), "mood": int(e.get("mood", 0)), "bonded": bool(e.get("bonded", false)),
		"likes": e.get("likes", []), "dislikes": e.get("dislikes", []), "beat_in": int(e.get("beat_in", 0)),
		"carcass_meat": int(e.get("meat", 0)) if carcass else -1,
		"hp": e.hp, "hp_max": e.hp_max, "world_pos": pos + Vector3(0, h * 1.25 if not carcass else 0.6, 0)}

func _on_clicked(id: int, _pos: Vector3) -> void:
	if id <= 0 or id >= stage.cur.entities.size():
		return
	if int(stage.cur.active) >= 0 and id == int(stage.cur.active) + 1:
		var inf := info_for(id)         # clicking the one you are fighting keeps Attack (no ring in the middle of a fight)
		inf["fight"] = true
		ui.select(inf, false)
		return
	ui.select(info_for(id), true, island.last_click)

func select_id(id: int, menu_pos: Variant = null) -> void:
	ui.select(info_for(id), true, menu_pos)

# --- world -> UI ----------------------------------------------------------------

# When C starts a fight the UI selects the attacker in Attack mode directly (no ring); UI state only, no order is sent.
func _fight_selection(state: Dictionary) -> void:
	var active: bool = int(state.active) >= 0
	if active and not _fight_prev:
		var aid := int(state.active) + 1
		if aid < state.entities.size():
			if selected_id != aid:
				var inf := info_for(aid)
				inf["fight"] = true
				ui.select(inf, false)
			elif ui.mode != Modes.ATTACK:
				ui.set_mode(Modes.ATTACK)
	_fight_prev = active
	ui.set_fight(active)


func _on_tick(state: Dictionary) -> void:
	if bool(state.get("parts", {}).get("lost", false)):
		_lineage_ended()
	var lo: Dictionary = state.get("loadout", {"slots": [0, 1, 3, 4], "known": 0, "can_edit": false})
	var key := "%s|%d" % [lo.slots, int(lo.known)]
	if key != _loadout_key:
		_loadout_key = key
		ui.set_loadout_abilities(_loadout_abilities(lo))
	ui.set_cooldowns(_cooldown_fractions(state, ui.loadout_abilities))
	ui.set_loadout_available(bool(lo.can_edit))
	if ui.loadout_panel.visible_open:
		ui.loadout_panel.refresh(lo)
		if not bool(lo.can_edit):
			ui.loadout_panel.close_panel()       # a fight started or the player walked away from the nest
	var p: Dictionary = state.entities[0]
	ui.set_player(player_name, p.hp, p.hp_max, p.stamina, p.stamina_max)
	_fight_selection(state)
	_on_social(state)
	if selected_id > 0 and selected_id < state.entities.size():
		var e: Dictionary = state.entities[selected_id]
		if bool(e.dead) and int(ui.selected.get("carcass_meat", -1)) < 0:
			ui.clear_selection()             # the one you selected fell: its ring breaks; the carcass can be selected next
			island.ground_marks.break_ring()
		elif (e.dead and int(e.get("meat", 0)) <= 0) or Vector2(float(e.x) - float(p.x), float(e.z) - float(p.z)).length() > 60.0:
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
	_update_world_signs(state)
	if state.outcome != last_outcome:
		last_outcome = state.outcome
		match state.outcome:
			1:
				ui.show_moment(Strings.t("trace_of_life"), "journal")
			2:
				ui.begin_death()
				_death_clock = 0.0
				_dying = true
			3:
				pass          # the wild creature goes home: its ring fades as it leaves, no text

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
					island.ground_marks.windup_hit()
				else:
					island.ground_marks.hit(0.0)
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

# The field journal reads the latest world state when it opens (ui/journal_model.gd says what each page reads); the world
# waits while the book is open, as it does behind the menu.
var _parts_catalogue: Array = []

func _journal_model() -> Dictionary:
	if _parts_catalogue.is_empty():
		_parts_catalogue = Profile.load_json("res://game/data/parts.json").get("parts", [])
	return JournalModel.build(stage.cur, species, _chains, _parts_catalogue)

func _on_journal_toggled(open: bool) -> void:
	stage.process_mode = Node.PROCESS_MODE_DISABLED if open or ui.paused else Node.PROCESS_MODE_INHERIT

func _on_pause(paused: bool) -> void:
	stage.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_INHERIT

# --- per frame ------------------------------------------------------------------

func _process(dt: float) -> void:
	if _dying:
		_death_clock += dt
		if _death_clock > 2.6:
			_dying = false
			ui.end_death()
			ui.show_message(Strings.t("back_at_nest"), "info")
	Game.journal_open = ui.journal.open
	Game.modal_open = ui.paused or ui.journal.open or ui.loadout_panel.visible_open     # the ring is not modal: WASD keeps walking
	Game.radial_open = ui.ring.visible
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
const DNA_SOURCES := ["kill", "bond", "ally", "dominate", "carcass", "exploration", "new species", "duplicate part", "fossil", "old bones", "meteor shard"]

func _on_social(state: Dictionary) -> void:
	var soc: Dictionary = state.get("social", {})
	if soc.is_empty():
		return
	ui.set_meters(int(soc.dna_total), int(soc.dna_balance), int(soc.resolved), int(soc.resolved_total), int(soc.food), int(soc.food_max))
	ui.set_gift(_gift, int(soc.items[_gift]))
	# rejected order: say why
	if _pending_sent_tick >= 0 and int(state.tick) == _pending_sent_tick + 1:
		_pending_sent_tick = -1
		if int(state.error) < 0:
			_refuse(int(state.error))
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
	for ev in state.get("route_events", []):
		if ev.type == "arrived":
			ui.show_message("Arrived", "good")
		else:
			ui.show_message("Blocked: %s" % ev.reason, "bad")
	for ev in state.get("social_events", []):
		_social_event(ev, state)

func _error_text(code: int) -> String:
	return String(CporeWorld.order_error(code)).capitalize()

# C refused an order: show it on the mark first (a petal shakes, a line bumps, the ring flashes), words second and only
# the first two times (docs/godot/UI-DIEGETIC.md 7.10).
func _refuse(code: int) -> void:
	match code:
		-8, -9, -19:                       # on_cooldown, not_equipped, no_stamina
			ui.petals.refuse(_last_pressed)
			if code == -19:
				ui.signs.poke("stamina")
		-22:                               # full
			ui.signs.poke("hunger")
		-21:                               # cannot digest
			ui.petals.refuse(0)
			_whisper_once("cannot_digest")
		-15:                               # refuses social play
			island.ground_marks.flash_ember()
			_whisper_once("wont_listen")
		-13:                               # not at the nest
			ui.minimap.poke()
			_whisper_once("only_nest")
		-18:                               # staggered by a rival
			island.ground_marks.flash_ember()
		-14:
			pass
		_:
			if code < 0:
				ui.show_message(_error_text(code), "warn")

func _whisper_once(key: String) -> void:
	var n: int = int(_whispers.get(key, 0))
	if n < 2:
		_whispers[key] = n + 1
		ui.show_message(Strings.t(key), "info")

# Per tick: the round map, the rings under whoever hunts you, the fog of death.
func _update_world_signs(state: Dictionary) -> void:
	var p: Dictionary = state.entities[0]
	var mm = ui.minimap
	mm.data = Game.data
	mm.player = Vector2(float(p.x), float(p.z))
	mm.heading = atan2(float(p.fx), -float(p.fz))
	mm.nest = island._nest
	mm.target = Vector2.INF
	if selected_id > 0 and selected_id < state.entities.size():
		var te: Dictionary = state.entities[selected_id]
		mm.target = Vector2(float(te.x), float(te.z))
		mm.target_hostile = bool(te.get("hostile", false))
	mm.fade = clampf(float(island.icons.alpha), 0.0, 1.0) if island.icons != null else 0.0
	mm.enabled = bool(Game.settings.get("minimap", true))
	mm.refresh()
	var hunters := []
	for i in range(1, state.entities.size()):
		var e: Dictionary = state.entities[i]
		if bool(e.get("hostile", false)) and not bool(e.dead) and Vector2(float(e.x) - float(p.x), float(e.z) - float(p.z)).length() < 40.0:
			hunters.append(i)
	island.ground_marks.set_threats(hunters)

func _target_pos(state: Dictionary, id: int) -> Vector3:
	if id <= 0 or id >= state.entities.size():
		return island.player_pos
	var e: Dictionary = state.entities[id]
	return Vector3(e.x, Game.ground(e.x, e.z) + (2.0 if not bool(e.dead) else 0.8), e.z)

func _species_name(i: int) -> String:
	return String(species[i].name) if i >= 0 and i < species.size() else "Creature"

func _social_event(ev: Dictionary, state: Dictionary) -> void:
	if int(ev.type) == 21:
		for part in state.get("parts", {}).get("discovered", []):
			if int(part.index) == int(ev.target):
				ui.show_message(Strings.t("part_found", [part.id]), "info")
		return
	if int(ev.type) == 25:       # shard_found: the story line, one whisper (en/es), the shard's name as the moment
		var items: Array = state.get("shards", {}).get("items", [])
		var k := int(ev.move)
		if k >= 0 and k < items.size() and items[k].has("line"):
			ui.show_message(String(items[k].line_es if Strings.language() == "es" else items[k].line), "info")
			ui.show_moment(Strings.t("shard_found", [Strings.t("shard_%d" % k), int(ev.value)]), "journal")
		return
	if int(ev.type) == 26:       # the cave: the passage, then the chamber
		ui.show_message(Strings.t("cave_chamber" if int(ev.move) == 2 else "cave_passage"), "info")
		return
	var at := _target_pos(state, int(ev.target))
	var gm = island.ground_marks
	match int(ev.type):
		EV_SKILL:
			var gain := int(ev.value)
			var mv := int(ev.move)
			var in_rhythm := gain > 0 and (mv & 256) != 0
			if gain >= 0:
				ui.show_float(at, "+%d" % gain, Palette.LICHEN)
			else:
				ui.show_float(at, "%d" % gain, Palette.DANGER)
			if in_rhythm:
				_pearls = mini(_pearls + 1, 5)
				gm.ripple()
			else:
				if _pearls > 0 or gain <= 0:
					gm.wobble()
				_pearls = 0
			gm.set_pearls(_pearls)
		EV_GIFT:
			var d := int(ev.value)
			ui.show_float(at, "%+d" % d, Palette.LICHEN if d >= 0 else Palette.DANGER)
			if d <= -20:
				gm.flash_ember()
		EV_BOND_MADE:
			gm.ripple()
			_pearls = 0
			gm.set_pearls(0)
			var sp := int(ev.move)
			if not _bonded_species.has(sp):
				_bonded_species[sp] = true
				ui.show_moment(Strings.t("bonded", [_species_name(sp)]), "befriend")
		EV_BOND_BROKEN:
			gm.wobble()
			ui.show_message(Strings.t("bond_broken"), "warn")
		EV_SPECIES_RESOLVED:
			ui.show_moment(Strings.t("alliance" if int(ev.value) == 1 else "dominated", [_species_name(int(ev.move))]), "befriend" if int(ev.value) == 1 else "attack")
		EV_DNA:
			var src: int = int(ev.move)
			ui.show_dna(int(ev.value), DNA_SOURCES[src] if src >= 0 and src < DNA_SOURCES.size() else "", at)
		EV_OBSERVE:
			var sp2 := int(ev.value)
			var clue: String = String(_chains[sp2].observe[int(ev.move)]) if sp2 < _chains.size() else ""
			ui.show_clue(at, "%s: %s" % [_species_name(sp2), clue])
		EV_CHAIN_DONE:
			var mv2 := int(ev.move)
			var mname: String = String(_moves[mv2].name) if mv2 >= 0 and mv2 < _moves.size() else ""
			ui.show_moment(Strings.t("learned", [mname.replace("_", " ").capitalize() if mname != "" else "?"]), Glyphs.for_move(mname) if mname != "" else "journal")
		EV_INTIMIDATE:
			gm.shock(island.player_pos, at, float(ev.value) > 0.0)
			if float(ev.value) > 0.0:
				gm.ripple()
			else:
				gm.flash_ember()
		EV_CANCELLED:
			var r := int(ev.value)
			if r == 2:
				gm.flash_ember()
			elif r == 5:
				gm.flash_bone()
			elif r < 0 and r != -2:
				_refuse(r)
		EV_EAT:
			var l = island.hosts[0].layer() if island.hosts.has(0) else null
			if l != null:
				l.trigger("eat")
			# the last bite (ev.move <= 0): the design's rising bone glyph is deferred; the ring is simply gone with the meat

func open_nest_editor() -> void:
	if not bool(stage.world.state().get("parts", {}).get("can_edit", false)):
		_refuse(-13)
		return
	var editor = preload("res://studio/ui/studio.gd").new()
	editor.nest_world = stage.world
	editor.nest_genome = island._genome
	stage.paused = true
	var layer := CanvasLayer.new()
	layer.layer = 30
	island.add_child(layer)
	layer.add_child(editor)
	var reload := func(genome: Dictionary) -> void:
		stage.paused = false                 # the scenario records the time state: save it running
		var built = preload("res://devtools/scenario.gd").build(stage, island.scenario_ctx(), "save", "nest edit", "", false)
		built.json.genome = genome
		layer.queue_free()
		island.load_scenario({"dict": built.json, "state": built.state, "recipe": ""})
		stage.paused = false                 # a loaded scenario starts paused; the nest edit resumes play
	editor.exit_requested.connect(func() -> void:
		if not editor.applied_genome.is_empty():
			reload.call(editor.applied_genome)       # free repaint/rearrange kept on leaving
			return
		stage.restore_from(stage.world.snapshot())
		stage.paused = false
		layer.queue_free())
	editor.nest_confirmed.connect(func(genome: Dictionary) -> void: reload.call(genome))

# A25: no eggs left. The stage is frozen by C; show the end of the lineage and return to the last save.
var _lineage_end: CanvasLayer
func _lineage_ended() -> void:
	if _lineage_end != null:
		return
	stage.paused = true
	_lineage_end = CanvasLayer.new()
	_lineage_end.layer = 40
	island.add_child(_lineage_end)
	var Style := preload("res://ui/style.gd")
	var dim := ColorRect.new()              # the fog closing in: a veil, as in the menu
	dim.color = Color(0.094, 0.133, 0.122, 0.86)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lineage_end.add_child(dim)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 18)
	dim.add_child(box)
	var title := Label.new()
	title.text = Strings.t("lineage_end")
	title.add_theme_font_override("font", Style.font_italic())
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Palette.BONE)
	title.add_theme_color_override("font_outline_color", Color(Palette.INK, 0.55))
	title.add_theme_constant_override("outline_size", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := Label.new()
	sub.text = Strings.t("lineage_end_sub")
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_override("font", Style.font_sans())
	sub.add_theme_font_size_override("font_size", 19)
	sub.add_theme_color_override("font_color", Palette.FOG)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var back := Button.new()
	back.text = Strings.t("lineage_end_back")
	back.flat = true
	back.custom_minimum_size = Vector2(0, 52)
	back.add_theme_font_override("font", Style.font_sans(true))
	back.add_theme_font_size_override("font_size", 23)
	back.add_theme_color_override("font_color", Palette.COPPER)
	back.add_theme_color_override("font_hover_color", Palette.BONE)
	back.add_theme_color_override("font_focus_color", Palette.BONE)
	back.add_theme_color_override("font_pressed_color", Palette.BONE)
	var line := StyleBoxFlat.new()          # focus is a copper line under the words, not a box
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Palette.COPPER
	line.border_width_bottom = 2
	line.content_margin_bottom = 6
	var none := StyleBoxEmpty.new()
	back.add_theme_stylebox_override("focus", line)
	for n in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(n, none)
	back.pressed.connect(return_to_last_save)
	box.add_child(back)
	back.grab_focus()

## Loads the last save (no wipe, no new game). Without a save the stage goes back to the menu.
func return_to_last_save() -> String:
	var err: String = island.load_game()
	if err != "":
		var game := get_node_or_null("/root/Game")
		if game != null and game.has_method("goto_menu"):
			game.goto_menu()
		return err
	if _lineage_end != null:
		_lineage_end.queue_free()
		_lineage_end = null
	stage.paused = false
	return ""
