extends Node
## Glue of the first end-to-end chain (docs/godot/FIRST-QUEST.md): the task model (quest.gd), its card and whispers, the dig verb
## (key X and the chip at your feet), the beds and holes (dig_site.gd), the finds, the burn a flame leaves on a creature and the
## minimap ping. The world is C's; this node only reads `stage.cur` once per tick and sends the same orders a player would.

const Quest := preload("res://game/stage/quest.gd")
const DigSite := preload("res://game/stage/dig_site.gd")
const FlameFx := preload("res://game/actors/flame_fx.gd")
const Strings := preload("res://ui/strings.gd")
const Palette := preload("res://ui/palette.gd")

const V_DIG := 20
const EV_DUG := 28
const EV_MOVE_USED := 29
const EV_PART_FOUND := 21
const FIND_NAMES := ["dig_nothing", "dig_grub", "dig_pebble", "dig_wing", "dig_bone"]

signal task_done(id: String)

var island: Node3D
var stage: Node
var ui                       # GameUI
var quest := Quest.new()
var dig_site: Node3D
var enabled := true
var log: Array = []          # [{tick, id}] completed tasks, for tests and the evidence
var _burning := {}           # entity id -> true while its host carries flames
var _pending: Array = []     # completion announcements waiting for the previous whisper to clear
var _announce_clock := 0.0

func setup(isl: Node3D) -> void:
	island = isl
	stage = isl.stage
	ui = isl.stage_ui.ui
	enabled = bool(Game.settings.get("first_quest", true))
	dig_site = DigSite.new()
	dig_site.name = "DigSite"
	island.add_child(dig_site)
	dig_site.setup(stage, Callable(Game, "visual_ground"))
	ui.dig_pressed.connect(dig)
	stage.ticked.connect(_on_tick)
	ui.quest_card.enabled = enabled
	_refresh(stage.cur)

# --- the dig verb ----------------------------------------------------------------------------------------------------------

## The same order the key sends: one input at the next tick; C answers (hard ground, already dug, tired) and the refusal is a whisper.
func dig() -> void:
	if stage == null or stage.paused or ui.paused or ui.journal.open:
		return
	stage.queue_order({"verb": V_DIG})
	_check_refusal()

func _check_refusal() -> void:
	await stage.ticked        # the order is applied on the next step; C's answer is in `error` after it
	match int(stage.cur.get("error", 0)):
		-25:
			ui.show_message(Strings.t("dig_hard"), "info")
		-26:
			ui.show_message(Strings.t("dig_again"), "info")
		-19:
			ui.show_message(Strings.t("dig_tired"), "info")
			ui.signs.poke("stamina")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.is_action_pressed("dig"):
		dig()
		get_viewport().set_input_as_handled()

# --- every tick ------------------------------------------------------------------------------------------------------------

func _on_tick(state: Dictionary) -> void:
	for ev in state.get("social_events", []):
		match int(ev.type):
			EV_DUG:
				_dug(ev, state)
			EV_PART_FOUND:
				if int(ev.target) == _part_index(state, "fire_gland"):
					ui.show_message(Strings.t("fire_gland_found"), "info")
	if enabled:
		for id in quest.update(state):
			_complete(id, state)
	_refresh(state)
	_burn_fx(state)
	_announce_clock = maxf(_announce_clock - 0.1, 0.0)
	if _announce_clock <= 0.0 and not _pending.is_empty():
		var line: String = _pending.pop_front()
		ui.show_message(line, "info")
		_announce_clock = 2.4

func _part_index(state: Dictionary, id: String) -> int:
	for p in state.get("parts", {}).get("discovered", []):
		if String(p.id) == id:
			return int(p.index)
	return -999

func _dug(ev: Dictionary, state: Dictionary) -> void:
	var find := int(ev.move)
	if find < 0:
		ui.show_message(Strings.t("dig_stopped"), "info")
		return
	ui.show_message(Strings.t(FIND_NAMES[clampi(find, 0, FIND_NAMES.size() - 1)]), "info")
	# the creature lowers its head to the hole
	if island.hosts.has(0) and island.hosts[0].layer() != null:
		pass

func _complete(id: String, state: Dictionary) -> void:
	var i := quest.step_index(id)
	var step: Dictionary = quest.steps()[i]
	var dna := quest.reward_of(id)
	if dna > 0:
		stage.world.quest_award(i, dna)
	var lang := Strings.language()
	log.append({"tick": int(state.tick), "id": id})
	_pending.append(quest.text_of(step.get("done", ""), lang))
	if quest.finished():
		_pending.append(Strings.t("quest_done_whisper"))
	ui.show_moment(Strings.t("quest_task_done", [quest.text_of(step.title, lang)]), "journal")
	task_done.emit(id)

## The card's model and the minimap ping, from the quest and the state.
func _refresh(state: Dictionary) -> void:
	var lang := Strings.language()
	var marks: Array = []
	for i in quest.steps().size():
		marks.append(i < quest.step)
	var m := {"title": quest.text_of(quest.chain.get("title", ""), lang), "index": quest.step, "total": quest.steps().size(),
		"marks": marks, "finished": quest.finished(), "step_title": "", "hint": "", "parts": []}
	if not quest.finished():
		var s: Dictionary = quest.current()
		m.step_title = quest.text_of(s.title, lang)
		m.hint = quest.text_of(s.hint, lang)
		var parts: Array = []
		for p in quest.parts_of(state):
			parts.append({"text": Strings.t("q_sub_" + String(p.type)), "done": bool(p.done)})
		m.parts = parts
	ui.quest_card.set_model(m)
	ui.minimap.quest_ping = quest.marker(state) if enabled else Vector2.INF
	# the dig chip: soft soil under you, free, nothing selected
	var dig_state: Dictionary = state.get("dig", {})
	var free := int(state.active) < 0 and not bool(state.get("player", {}).get("falling", false)) and int(state.respawn_ticks) == 0
	ui.dig_chip.want = bool(dig_state.get("soft", false)) and free and ui.selected.is_empty() and int(dig_state.get("digging", 0)) == 0
	ui.dig_chip.digging = float(int(dig_state.get("digging", 0))) / float(maxi(int(dig_state.get("ticks", 20)), 1))
	var cam: Camera3D = Game.camera
	if cam != null and island.hosts.has(0):
		var p: Vector3 = island.hosts[0].global_position
		var fwd := Vector3(float(state.entities[0].fx), 0.0, float(state.entities[0].fz))
		var at := p + fwd * 1.6
		if not cam.is_position_behind(at):
			ui.dig_chip.centre = cam.unproject_position(at)

# --- the flame's burn --------------------------------------------------------------------------------------------------------

func _burn_fx(state: Dictionary) -> void:
	var now := {}
	for f in state.combat.fighters:
		if int(f.get("burn", 0)) > 0:
			now[int(f.world_id)] = true
	for id in now.keys():
		if not _burning.has(id) and island.hosts.has(id):
			FlameFx.burn_on(island.hosts[id], float(island.hosts[id].height()))
			_burning[id] = true
	for id in _burning.keys():
		if not now.has(id):
			if island.hosts.has(id) and is_instance_valid(island.hosts[id]):
				FlameFx.burn_off(island.hosts[id])
			_burning.erase(id)

# --- save and console ----------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	quest.collapsed = ui.quest_card.collapsed
	return quest.to_dict()

func from_dict(d: Dictionary) -> void:
	quest.from_dict(d)
	ui.quest_card.set_collapsed(quest.collapsed)
	_pending.clear()
	_refresh(stage.cur)

func skip() -> String:
	var id := quest.skip()
	if id != "":
		_refresh(stage.cur)
		task_done.emit(id)
	return id

func reset_quest() -> void:
	quest.reset()
	_pending.clear()
	_refresh(stage.cur)
