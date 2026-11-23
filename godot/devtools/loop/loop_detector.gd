extends RefCounted
## Turns the C world's per-tick state into creature-loop beats (docs/plans/creature-loop.md, T1). Pure: feed(state) returns the
## events that happened on that tick as [[name, data], ...]; the recorder publishes them through Game.loop_event. It reads the
## state dictionary the stage already built (no extra world.state() call, so the social event queue is left alone) and it never
## writes anything back, so a replay with and without the recorder is identical.
##
## Events (name: data):
##   spawn {x, z, hp, species, creatures, dna}      first tick of a run (a hatch: the player's body is placed)
##   first_move {dist}                              the body is 1 m from where it spawned
##   fight_start {target, species, name, dist, hp}  C opened a fight (state.active >= 0)
##   fight_end {result: kill|death|fled, target, species, name, ticks, hp}
##   kill {target, species, name}   player_death {cause: fight|world}
##   befriend_start {target, species, name, tries}  first skill or gift on a creature (again after 50 quiet ticks)
##   befriend_skill {target, gain}  gift {target, value}  bond_made {target, species}  first_bond {species}  bond_broken {target}
##   species_resolved {species, value}  dna {value, src}  move_learned {move}  eat_done {target}
##   dig {ok, find, bed, x, z}      part_found {part, index}  part_inspected  part_bought  edit_accepted
##   shard_found {index}  cave {move}  fell {drop_cm, damage}  move_used {move}
##   nest_enter / nest_exit {dist}  species_seen {species, name, count}  cousin_seen {generation, dist}
##   sample {x, z, dist, hp, dna, dna_total, species_seen, alive, creatures}   every SAMPLE_EVERY ticks
const SAMPLE_EVERY := 100
const MOVE_M := 1.0
const SOCIAL_QUIET := 50
const COUSIN_M := 60.0
const EV_SKILL := 10
const EV_GIFT := 11
const EV_BOND_MADE := 12
const EV_BOND_BROKEN := 13
const EV_SPECIES_RESOLVED := 14
const EV_DNA := 15
const EV_CHAIN_DONE := 17
const EV_EAT := 20
const EV_PART_FOUND := 21
const EV_INSPECTED := 22
const EV_PART_BOUGHT := 23
const EV_EDIT_ACCEPTED := 24
const EV_SHARD := 25
const EV_CAVE := 26
const EV_FELL := 27
const EV_DUG := 30
const EV_MOVE_USED := 31

var nest := Vector2.INF            # set by the recorder from the island
var started := false
var start_pos := Vector2.ZERO
var last_pos := Vector2.ZERO
var distance := 0.0
var moved := false
var fight_target := -1
var fight_tick := 0
var fights := 0
var kills := 0
var deaths := 0
var last_active := -1
var last_respawn := 0
var last_death_tick := -1000
var in_nest := false
var seen := {}                     # species -> true
var bonded := {}                   # species -> true
var social_tick := {}              # target -> last social event tick
var befriend_starts := 0
var cousin_gen_seen := {}
var species_names: Array = []

func _name(state: Dictionary, sp: int) -> String:
	var roster: Array = state.get("species", [])
	return str(roster[sp].get("name", "")) if sp >= 0 and sp < roster.size() else ""

func feed(state: Dictionary) -> Array:
	var out: Array = []
	var ents: Array = state.get("entities", [])
	if ents.is_empty():
		return out
	var tick := int(state.get("tick", 0))
	var me: Dictionary = ents[0]
	var pos := Vector2(float(me.x), float(me.z))
	var hp := float(me.get("hp", 0.0))
	var dna := int(state.get("social", {}).get("dna_balance", 0))
	if not started:
		started = true
		start_pos = pos
		last_pos = pos
		out.append(["spawn", {"x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1), "hp": hp, "species": int(me.get("species", -1)), "creatures": ents.size() - 1, "dna": dna}])
	distance += pos.distance_to(last_pos)
	last_pos = pos
	if not moved and pos.distance_to(start_pos) >= MOVE_M:
		moved = true
		out.append(["first_move", {"dist": snappedf(pos.distance_to(start_pos), 0.1)}])
	_fights(state, ents, pos, hp, tick, out)
	_social(state, tick, out)
	_species(state, out)
	_nest(state, pos, out)
	_cousins(ents, pos, out)
	if tick % SAMPLE_EVERY == 0:
		var alive := 0
		for i in range(1, ents.size()):
			if not bool(ents[i].get("dead", false)):
				alive += 1
		out.append(["sample", {"x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1), "dist": snappedf(distance, 0.1), "hp": snappedf(hp, 0.1), "dna": dna,
			"dna_total": int(state.get("social", {}).get("dna_total", 0)), "species_seen": seen.size(), "alive": alive, "creatures": ents.size() - 1}])
	return out

func _fights(state: Dictionary, ents: Array, pos: Vector2, hp: float, tick: int, out: Array) -> void:
	var active := int(state.get("active", -1))
	if active >= 0 and last_active < 0:
		fight_target = active + 1
		fight_tick = tick
		fights += 1
		var e: Dictionary = ents[fight_target] if fight_target < ents.size() else {}
		var sp := int(e.get("species", -1))
		out.append(["fight_start", {"target": fight_target, "species": sp, "name": _name(state, sp), "dist": snappedf(pos.distance_to(Vector2(float(e.get("x", pos.x)), float(e.get("z", pos.y)))), 0.1), "hp": hp}])
	elif active < 0 and last_active >= 0:
		var e2: Dictionary = ents[fight_target] if fight_target >= 0 and fight_target < ents.size() else {}
		var sp2 := int(e2.get("species", -1))
		var res: String = ["", "kill", "death", "fled"][clampi(int(state.get("outcome", 0)), 0, 3)]
		var d := {"result": res, "target": fight_target, "species": sp2, "name": _name(state, sp2), "ticks": tick - fight_tick, "hp": hp}
		out.append(["fight_end", d])
		if res == "kill" or (res == "death" and bool(e2.get("dead", false))):
			kills += 1
			out.append(["kill", {"target": fight_target, "species": sp2, "name": _name(state, sp2)}])
		if res == "death":
			deaths += 1
			last_death_tick = tick
			out.append(["player_death", {"cause": "fight", "target": fight_target, "species": sp2}])
	last_active = active
	var rt := int(state.get("respawn_ticks", 0))
	if rt > 0 and last_respawn == 0 and tick - last_death_tick > 30:
		deaths += 1
		last_death_tick = tick
		out.append(["player_death", {"cause": "world", "x": snappedf(pos.x, 0.1), "z": snappedf(pos.y, 0.1)}])
	last_respawn = rt

func _social(state: Dictionary, tick: int, out: Array) -> void:
	for ev in state.get("social_events", []):
		var t := int(ev.type)
		var target := int(ev.target)
		match t:
			EV_SKILL, EV_GIFT:
				var first_touch := not social_tick.has(target) or tick - int(social_tick[target]) > SOCIAL_QUIET
				social_tick[target] = tick
				if first_touch:
					befriend_starts += 1
					var ents: Array = state.get("entities", [])
					var sp := int(ents[target].get("species", -1)) if target >= 0 and target < ents.size() else -1
					out.append(["befriend_start", {"target": target, "species": sp, "name": _name(state, sp), "tries": befriend_starts}])
				if t == EV_SKILL:
					out.append(["befriend_skill", {"target": target, "gain": float(ev.value)}])
				else:
					out.append(["gift", {"target": target, "value": float(ev.value)}])
			EV_BOND_MADE:
				var sp2 := int(ev.move)
				out.append(["bond_made", {"target": target, "species": sp2, "name": _name(state, sp2)}])
				if bonded.is_empty():
					out.append(["first_bond", {"species": sp2}])
				bonded[sp2] = true
			EV_BOND_BROKEN:
				out.append(["bond_broken", {"target": target}])
			EV_SPECIES_RESOLVED:
				out.append(["species_resolved", {"species": int(ev.move), "value": float(ev.value)}])
			EV_DNA:
				out.append(["dna", {"value": int(ev.value), "src": int(ev.move)}])
			EV_CHAIN_DONE:
				out.append(["move_learned", {"move": int(ev.move)}])
			EV_EAT:
				if int(ev.move) <= 0:
					out.append(["eat_done", {"target": target}])
			EV_PART_FOUND:
				var pid := ""
				for p in state.get("parts", {}).get("discovered", []):
					if int(p.index) == target:
						pid = str(p.id)
				out.append(["part_found", {"part": pid, "index": target}])
			EV_INSPECTED:
				out.append(["part_inspected", {"index": target}])
			EV_PART_BOUGHT:
				out.append(["part_bought", {"index": target}])
			EV_EDIT_ACCEPTED:
				out.append(["edit_accepted", {}])
			EV_SHARD:
				out.append(["shard_found", {"index": int(ev.move)}])
			EV_CAVE:
				out.append(["cave", {"move": int(ev.move)}])
			EV_FELL:
				out.append(["fell", {"drop_cm": int(ev.move), "damage": float(ev.value)}])
			EV_DUG:
				out.append(["dig", {"ok": int(ev.move) >= 0, "find": int(ev.move), "bed": int(ev.value), "x": snappedf(float(ev.x), 0.1), "z": snappedf(float(ev.z), 0.1)}])
			EV_MOVE_USED:
				out.append(["move_used", {"move": int(ev.move)}])

func _species(state: Dictionary, out: Array) -> void:
	var roster: Array = state.get("species", [])
	for k in roster.size():
		if bool(roster[k].get("seen", false)) and not seen.has(k):
			seen[k] = true
			out.append(["species_seen", {"species": k, "name": str(roster[k].get("name", "")), "count": seen.size()}])

func _nest(state: Dictionary, pos: Vector2, out: Array) -> void:
	if nest == Vector2.INF:
		return
	var radius := float(state.get("loadout", {}).get("nest_radius", 8.0))
	var d := pos.distance_to(nest)
	var inside := d <= radius
	if inside != in_nest:
		in_nest = inside
		out.append(["nest_enter" if inside else "nest_exit", {"dist": snappedf(d, 0.1)}])

func _cousins(ents: Array, pos: Vector2, out: Array) -> void:
	for i in range(1, ents.size()):
		var g := int(ents[i].get("cousin_generation", 0))
		if g <= 0 or cousin_gen_seen.has(g) or bool(ents[i].get("hidden", false)) or bool(ents[i].get("dead", false)):
			continue
		var d := pos.distance_to(Vector2(float(ents[i].x), float(ents[i].z)))
		if d <= COUSIN_M:
			cousin_gen_seen[g] = true
			out.append(["cousin_seen", {"generation": g, "dist": snappedf(d, 0.1), "target": i}])
