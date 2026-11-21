extends RefCounted
## The first end-to-end chain as data (godot/game/data/quests/first.json, docs/godot/FIRST-QUEST.md): kill a creature, befriend
## another species, dig, unearth the wings, edit in the fire gland and use the flamethrower. A pure model of the C state: every
## condition is a function of `CporeWorld.state()`, evaluated live each tick; steps advance in order, one per tick, and the
## rewards (DNA) are paid by C (`CporeWorld.quest_award`, once per step). Saved with the game (`to_dict` / `from_dict`).
##
## Conditions (cond.type):
##   kill {count}        creatures killed, any species        state.social.species[].kills
##   bond_other          a bond with a species other than the first one killed   state.social.species[].bonded
##   dug {count}         holes dug                            state.dig.dug
##   part_found {id}     a part discovered                    state.parts.discovered[].id
##   move_known {move}   the move is in the known set         state.loadout.known (bit = 1 << move)
##   move_used {move,count}   the move was started (the flamethrower counter)   state.dig.flames
##   all {of}            every sub-condition at once

const CHAIN_PATH := "res://game/data/quests/first.json"

var chain: Dictionary = {}
var step := 0                       # index of the current step; steps.size() once the chain is done
var done_at: Dictionary = {}        # step id -> tick of completion
var flags: Dictionary = {}          # remembered facts: killed_species
var collapsed := false              # the card is folded to its tab (key K)
var skipped: Dictionary = {}        # step ids completed by `quest skip` (no reward paid)

static func load_chain(path: String = CHAIN_PATH) -> Dictionary:
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if typeof(v) == TYPE_DICTIONARY else {}

func _init(path: String = CHAIN_PATH) -> void:
	chain = load_chain(path)

func steps() -> Array:
	return chain.get("steps", [])

func finished() -> bool:
	return step >= steps().size()

func current() -> Dictionary:
	return steps()[step] if not finished() else {}

func text_of(v: Variant, lang: String) -> String:
	if v is Dictionary:
		return String(v.get(lang, v.get("en", "")))
	return String(v)

# --- conditions ------------------------------------------------------------------------------------------------------

static func _species(state: Dictionary) -> Array:
	return state.get("social", {}).get("species", [])

func total_kills(state: Dictionary) -> int:
	var n := 0
	for sp in _species(state):
		n += int(sp.get("kills", 0))
	return n

func holds(cond: Dictionary, state: Dictionary) -> bool:
	match String(cond.get("type", "")):
		"kill":
			return total_kills(state) >= int(cond.get("count", 1))
		"bond_other":
			var killed := int(flags.get("killed_species", -1))
			var sp := _species(state)
			for i in sp.size():
				if i != killed and int(sp[i].get("bonded", 0)) >= 1:
					return true
			return false
		"dug":
			return int(state.get("dig", {}).get("dug", 0)) >= int(cond.get("count", 1))
		"part_found":
			for p in state.get("parts", {}).get("discovered", []):
				if p is Dictionary and String(p.get("id", "")) == String(cond.get("id", "")):
					return true
			return false
		"move_known":
			return (int(state.get("loadout", {}).get("known", 0)) >> int(cond.get("move", 0))) & 1 == 1
		"move_used":
			return int(state.get("dig", {}).get("flames", 0)) >= int(cond.get("count", 1))
		"all":
			for c in cond.get("of", []):
				if not holds(c, state):
					return false
			return true
	return false

## The sub-conditions of the current step as [{label_key, done}] for the card's dots (a plain step has one).
func parts_of(state: Dictionary) -> Array:
	if finished():
		return []
	var cond: Dictionary = current().cond
	var out: Array = []
	if String(cond.type) == "all":
		for c in cond.of:
			out.append({"type": String(c.type), "done": holds(c, state)})
	else:
		out.append({"type": String(cond.type), "done": holds(cond, state)})
	return out

func _remember(state: Dictionary) -> void:
	if not flags.has("killed_species"):
		var sp := _species(state)
		for i in sp.size():
			if int(sp[i].get("kills", 0)) > 0:
				flags["killed_species"] = i
				break

## One tick: returns the ids of the steps completed by this state (at most one; the next is checked on the next tick, so each
## completion gets its own whisper). `tick` is the world tick, kept for the save.
func update(state: Dictionary) -> Array:
	_remember(state)
	if finished():
		return []
	var s: Dictionary = current()
	if holds(s.cond, state):
		return [_complete(String(s.id), int(state.get("tick", 0)))]
	return []

func _complete(id: String, tick: int) -> String:
	done_at[id] = tick
	step += 1
	return id

func step_index(id: String) -> int:
	for i in steps().size():
		if String(steps()[i].id) == id:
			return i
	return -1

func reward_of(id: String) -> int:
	var i := step_index(id)
	return int(steps()[i].get("reward", {}).get("dna", 0)) if i >= 0 else 0

# --- markers (a soft ping, not an arrow) ---------------------------------------------------------------------------------

## World position (x, z) the current step points toward, or Vector2.INF. Only the minimap shows it and only as a quiet dot.
func marker(state: Dictionary) -> Vector2:
	if finished():
		return Vector2.INF
	var kind := String(current().get("marker", ""))
	if kind == "":
		return Vector2.INF
	var ents: Array = state.get("entities", [])
	if ents.is_empty():
		return Vector2.INF
	var me := Vector2(float(ents[0].x), float(ents[0].z))
	var best := Vector2.INF
	var best_d := INF
	if kind == "wing_bed":
		for b in state.get("dig", {}).get("beds", []):
			if int(b.kind) == 0 and not bool(b.dug):
				return Vector2(float(b.x), float(b.z))
		return Vector2.INF
	for i in range(1, ents.size()):
		var e: Dictionary = ents[i]
		if bool(e.dead) or bool(e.get("hidden", false)):
			continue
		var sp := int(e.species)
		if kind == "nearest_prey" and sp not in [0, 1]:
			continue
		if kind == "nearest_other" and (sp == int(flags.get("killed_species", -1)) or bool(e.get("hostile", false))):
			continue
		var p := Vector2(float(e.x), float(e.z))
		if me.distance_to(p) < best_d:
			best_d = me.distance_to(p)
			best = p
	return best

# --- testing and the console -----------------------------------------------------------------------------------------

## Completes the current step without a reward (console `quest skip`); returns its id or "".
func skip() -> String:
	if finished():
		return ""
	var id := String(current().id)
	skipped[id] = true
	return _complete(id, 0)

func reset() -> void:
	step = 0
	done_at = {}
	flags = {}
	skipped = {}

func status(state: Dictionary = {}) -> String:
	if finished():
		return "quest %s: done (%d/%d)" % [chain.get("id", "?"), step, steps().size()]
	var s: Dictionary = current()
	var line := "quest %s: step %d/%d '%s' (%s)" % [chain.get("id", "?"), step + 1, steps().size(), s.id, s.cond.type]
	if not state.is_empty():
		var bits: PackedStringArray = []
		for p in parts_of(state):
			bits.append("%s=%s" % [p.type, "yes" if p.done else "no"])
		line += " [%s]" % ", ".join(bits)
	return line

# --- save ---------------------------------------------------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {"id": String(chain.get("id", "first")), "step": step, "done_at": done_at.duplicate(), "flags": flags.duplicate(),
		"collapsed": collapsed, "skipped": skipped.duplicate()}

func from_dict(d: Dictionary) -> void:
	if d.is_empty() or String(d.get("id", "")) != String(chain.get("id", "first")):
		return
	step = clampi(int(d.get("step", 0)), 0, steps().size())
	done_at = {}
	for k in d.get("done_at", {}):
		done_at[String(k)] = int(d.done_at[k])
	flags = {}
	for k in d.get("flags", {}):
		flags[String(k)] = int(d.flags[k])
	collapsed = bool(d.get("collapsed", false))
	skipped = {}
	for k in d.get("skipped", {}):
		skipped[String(k)] = true
