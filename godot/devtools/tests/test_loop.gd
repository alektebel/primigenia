extends RefCounted
# T1: the loop detector turns C states into beats (synthetic states, no island) and the recorder writes JSONL.

const Detector := preload("res://devtools/loop/loop_detector.gd")
const Recorder := preload("res://devtools/loop/loop_recorder.gd")

func _state(tick: int, x := 0.0, active := -1, outcome := 0, events: Array = [], extra := {}) -> Dictionary:
	var s := {"tick": tick, "active": active, "outcome": outcome, "respawn_ticks": 0, "social_events": events,
		"entities": [{"x": x, "z": 0.0, "hp": 100.0}, {"x": 5.0, "z": 0.0, "species": 3, "dead": false, "hp": 50.0}, {"x": 90.0, "z": 0.0, "species": 1, "dead": false, "cousin_generation": 1, "hidden": false}],
		"species": [{"name": "Rondo", "seen": false}, {"name": "Zanco", "seen": false}, {"name": "Cria", "seen": false}, {"name": "Garfio", "seen": false}],
		"social": {"dna_balance": 5, "dna_total": 5}, "loadout": {"nest_radius": 8.0}, "parts": {"discovered": [{"id": "fire_gland", "index": 48}]}}
	s.merge(extra, true)
	return s

func _names(evs: Array) -> Array:
	return evs.map(func(e): return e[0])

func run(t) -> void:
	var d = Detector.new()
	d.nest = Vector2(0, 0)
	var e1: Array = d.feed(_state(1))
	t.check("spawn" in _names(e1) and "nest_enter" in _names(e1), "the first tick is a spawn, at the nest")
	t.check("first_move" not in _names(d.feed(_state(2, 0.5))), "half a metre is not a first move")
	var e2: Array = d.feed(_state(3, 12.0))
	t.check("first_move" in _names(e2) and "nest_exit" in _names(e2), "1 m from the spawn is the first move; leaving the radius exits the nest")
	t.check("first_move" not in _names(d.feed(_state(4, 13.0))), "first_move fires once")
	t.check(absf(d.distance - 13.0) < 0.01, "distance walked adds up (%.1f)" % d.distance)
	var f1: Array = d.feed(_state(5, 13.0, 0))
	t.eq(_names(f1), ["fight_start"], "a fight opens when state.active turns >= 0")
	t.eq(f1[0][1].name, "Garfio", "the opponent is named from the roster")
	var f2: Array = d.feed(_state(9, 13.0, -1, 1))
	t.check(_names(f2) == ["fight_end", "kill"] and f2[0][1].result == "kill" and int(f2[0][1].ticks) == 4, "outcome 1 closes the fight as a kill")
	var f3: Array = d.feed(_state(20, 13.0, 0))
	var f4: Array = d.feed(_state(25, 13.0, -1, 2))
	t.check("player_death" in _names(f4) and d.deaths == 1 and d.fights == 2, "outcome 2 is a death")
	var ev := [{"type": 10, "target": 1, "move": 0, "value": 9.0}, {"type": 11, "target": 1, "move": 0, "value": 5.0}]
	var s1: Array = d.feed(_state(30, 13.0, -1, 0, ev))
	t.check(_names(s1).count("befriend_start") == 1 and "befriend_skill" in _names(s1) and "gift" in _names(s1), "skill and gift on one creature start one befriend try")
	t.eq(d.feed(_state(40, 13.0, -1, 0, [{"type": 10, "target": 1, "move": 0, "value": 4.0}])).filter(func(e): return e[0] == "befriend_start").size(), 0, "a skill soon after is the same try")
	t.eq(d.feed(_state(200, 13.0, -1, 0, [{"type": 10, "target": 1, "move": 0, "value": 4.0}])).filter(func(e): return e[0] == "befriend_start").size(), 1, "after a quiet spell it is a new try")
	var b: Array = d.feed(_state(210, 13.0, -1, 0, [{"type": 12, "target": 1, "move": 3, "value": 0.0}, {"type": 21, "target": 48, "move": 0, "value": 0.0}, {"type": 30, "target": 0, "move": 0, "value": -1.0, "x": 1.0, "z": 2.0}]))
	t.check("bond_made" in _names(b) and "first_bond" in _names(b) and "part_found" in _names(b) and "dig" in _names(b), "bond, first bond, part found and dig events")
	t.eq(b[_names(b).find("part_found")][1].part, "fire_gland", "the part is named from the discovered list")
	var sp: Array = d.feed(_state(220, 13.0, -1, 0, [], {"species": [{"name": "Rondo", "seen": true}, {"name": "Zanco", "seen": false}, {"name": "Cria", "seen": false}, {"name": "Garfio", "seen": false}]}))
	t.check("species_seen" in _names(sp), "a newly seen species is announced once")
	var smp: Array = d.feed(_state(300, 13.0))
	t.check("sample" in _names(smp), "a sample every 100 ticks")
	d = Detector.new()
	t.check("cousin_seen" not in _names(d.feed(_state(1))), "a cousin 90 m away is not seen")
	var near := _state(2)
	near.entities[2].x = 30.0
	t.check("cousin_seen" in _names(d.feed(near)), "a cousin within 60 m is seen")
	t.eq(_names(d.feed(_state(3, 0.0, -1, 0, [], {"respawn_ticks": 20}))), ["player_death"], "a respawn countdown outside a fight is a world death")

	# the recorder writes one JSON object per line and the `loop` summary reads them back
	var path := OS.get_user_data_dir().path_join("test-feedback").path_join(str(OS.get_process_id())).path_join("loop_test.jsonl")
	OS.set_environment("CPORE_LOOP_FILE", path)
	var rec = Recorder.new()
	rec._open()
	rec._on_event("quest_done:hunt", {"x": 1})
	rec._on_event("select", {"id": 2})
	rec._file = null
	var lines := FileAccess.get_file_as_string(path).strip_edges().split("\n")
	OS.set_environment("CPORE_LOOP_FILE", "")
	t.eq(lines.size(), 3, "session_start plus two events are three JSONL lines")
	var rows := []
	for l in lines:
		rows.append(JSON.parse_string(l))
	t.check(rows[1].n == "quest_done:hunt" and rows[1].d.x == 1 and rows[2].n == "select" and rows[0].n == "session_start", "each line is {n, tick, ms, ts, d}")
	t.check(rec.summary().contains("quest_done:hunt") and rec.dump(1).contains("select"), "summary and dump read the session")
	rec.free()
