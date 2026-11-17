extends RefCounted
## Turns StageWorld states into per-entity action signals. Read only: it never touches the world.
##   feed.read(prev, cur, alpha) -> {entity_id: signal}
## signal = {move, phase, e, plen, tau, fighter, events, dead, target_id, in_fight, marks: ["start"|"end"|"cancel"|"dead"],
##           stagger, stagger_len, w, a, r}
## Events (combat.events) are re-addressed to entity ids and delivered once per C tick.

const Clock := preload("action_clock.gd")

var _last_tick := -1
var _inst := {}          # entity id -> {move, e_last_seen, w, a, r, ended}

func reset() -> void:
	_last_tick = -1
	_inst.clear()

static func fighter_entity(cur: Dictionary, k: int) -> int:
	return 0 if k == 0 else int(cur.get("active", -1)) + 1

func read(prev: Dictionary, cur: Dictionary, alpha: float) -> Dictionary:
	var out := {}
	var combat: Dictionary = cur.get("combat", {})
	var tick := int(combat.get("tick", 0))
	var fresh := tick != _last_tick
	var active := int(cur.get("active", -1))
	var fighters: Array = combat.get("fighters", [])
	var evs: Array = combat.get("events", [])
	var ents: Array = cur.entities
	for id in ents.size():
		var ent: Dictionary = ents[id]
		var s := {"move": -1, "phase": 0, "e": 0, "plen": 0, "tau": 0.0, "fighter": -1, "events": [], "dead": bool(ent.get("dead", false)),
			"target_id": -1, "in_fight": false, "marks": [], "stagger": false, "stagger_len": 0, "w": 0, "a": 0, "r": 0, "alpha": alpha}
		out[id] = s
	for k in fighters.size():
		var f: Dictionary = fighters[k]
		var id := fighter_entity(cur, k)
		if not out.has(id):
			continue
		var s: Dictionary = out[id]
		s.fighter = k
		s.in_fight = true
		s.target_id = fighter_entity(cur, 1 - k)
		s.move = int(f.move)
		s.phase = int(f.phase)
		s.plen = int(f.phase_length)
		if s.move >= 0 and s.phase > 0:
			var t: Array = Clock.TICKS.get(s.move, [3, 1, 2])
			s.w = t[0]; s.a = t[1]; s.r = t[2]
			s.e = Clock.elapsed(s.move, s.phase, int(f.phase_tick), s.w, s.a)
			s.tau = Clock.tau(s.e, alpha)
		elif s.move < 0 and s.phase == 3:
			s.stagger = true
			s.stagger_len = s.plen
			s.tau = float(int(f.phase_tick)) + alpha
	if fresh:
		for ev in evs:
			var a_id := fighter_entity(cur, int(ev.a))
			var b_id := fighter_entity(cur, int(ev.b))
			var e2 := {"type": int(ev.type), "a": a_id, "b": b_id, "move": int(ev.move), "amount": float(ev.amount), "tick": tick}
			for id in [a_id, b_id]:
				if out.has(id):
					out[id].events.append(e2)
	# instance bookkeeping (1.7): marks are delivered once, with the first read of a new C tick
	for id in out:
		var s: Dictionary = out[id]
		var inst = _inst.get(id)
		var marks: Array = s.marks
		if not fresh:
			continue
		if s.move >= 0 and s.e > 0:
			var e_last: int = s.w + s.a + s.r - 1
			if inst != null and (inst.move != s.move or s.e < inst.e_seen):
				marks.append("end" if inst.e_seen >= inst.e_last else "cancel")
				inst = null
			if inst == null:
				marks.append("start")
				_inst[id] = {"move": s.move, "e_seen": s.e, "e_last": e_last}
			else:
				inst.e_seen = maxi(inst.e_seen, s.e)
		elif inst != null:
			marks.append("end" if inst.e_seen >= inst.e_last else "cancel")
			_inst.erase(id)
		if s.dead and not marks.has("dead"):
			marks.append("dead")
	_last_tick = tick
	return out
