extends RefCounted
## Builds StageWorld-shaped state dictionaries from a script, with the phase automaton of core/src/combat.c
## (advance_phase), so tests and evidence need no GDExtension.
##   var f := ScriptedFeed.new(); f.begin(0, 0); f.step()  -> f.prev, f.cur
## Entities: 0 = player, 1 = the wild creature (active = 0).

const Clock := preload("../action_clock.gd")

var tick := 0
var prev: Dictionary = {}
var cur: Dictionary = {}
var fighters := [{"move": -1, "phase": 0, "ptick": 0, "plen": 0}, {"move": -1, "phase": 0, "ptick": 0, "plen": 0}]
var pos := [Vector2(0, 0), Vector2(3.0, 0)]     # entity x,z
var face := [Vector2(1, 0), Vector2(-1, 0)]     # facing (fx, fz) -> toward the other
var dead := [false, false]
var in_fight := true
var _events: Array = []
var _pending: Array = []

func _init() -> void:
	cur = _state()
	prev = cur

func begin(k: int, move: int) -> void:
	_pending.append(["begin", k, move])

func interrupt(k: int, stagger_ticks: int) -> void:
	_pending.append(["interrupt", k, stagger_ticks])

func release_guard(k: int) -> void:
	_pending.append(["release", k, 0])

func event(type: int, a: int, b: int, move := 0, amount := 10.0) -> void:
	_events.append({"type": type, "a": a, "b": b, "move": move, "amount": amount})

func die(k: int) -> void:
	_pending.append(["die", k, 0])

func end_fight() -> void:
	_pending.append(["end", 0, 0])

func _advance(f: Dictionary) -> void:
	f.ptick += 1
	if f.ptick < f.plen:
		return
	if f.move < 0:
		f.phase = 0; f.ptick = 0; f.plen = 0
		return
	var t: Array = Clock.TICKS[f.move]
	f.ptick = 0
	if f.phase == 1:
		f.phase = 2; f.plen = t[1]
	elif f.phase == 2:
		f.phase = 3; f.plen = t[2]
	else:
		f.move = -1; f.phase = 0; f.plen = 0

func step() -> void:
	var events: Array = _events
	_events = []
	for p in _pending:
		var f: Dictionary = fighters[p[1]]
		match p[0]:
			"begin":
				var t: Array = Clock.TICKS[p[2]]
				f.move = p[2]; f.phase = 1; f.ptick = 0; f.plen = t[0]
			"interrupt":
				f.move = -1; f.phase = 3; f.ptick = 0; f.plen = p[2]
			"release":
				f.move = -1; f.phase = 0; f.ptick = 0; f.plen = 0
			"die":
				dead[p[1]] = true
				f.move = -1; f.phase = 0
			"end":
				in_fight = false
	_pending = []
	for f in fighters:
		if f.phase != 0:
			_advance(f)
	tick += 1
	prev = cur
	cur = _state()
	cur.combat.events = events

func _state() -> Dictionary:
	var ents := []
	for i in 2:
		ents.append({"x": pos[i].x, "z": pos[i].y, "fx": face[i].x, "fz": face[i].y, "hp": 100.0, "speed": 0.0,
			"dead": dead[i], "species": 0, "radius_cm": 300})
	var fl := []
	if in_fight:
		for k in 2:
			var f: Dictionary = fighters[k]
			fl.append({"world_id": k, "move": f.move, "phase": f.phase, "phase_tick": f.ptick, "phase_length": f.plen, "hp": 100.0, "stamina": 10.0})
	return {"tick": tick, "entities": ents, "active": 0 if in_fight else -1, "combat": {"tick": tick, "fighters": fl, "events": []}}
