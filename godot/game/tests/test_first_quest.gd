extends RefCounted
# The first quest (docs/godot/FIRST-QUEST.md): the data chain, the task model against synthetic and real C states, saves, the
# dig verb and the task reward through the C world, the fire gland part and the flamethrower's table row.

const Quest := preload("res://game/stage/quest.gd")
const Profile := preload("res://game/stage/profile.gd")
const Strings := preload("res://ui/strings.gd")

func _species_state(kills: Array, bonded: Array) -> Dictionary:
	var sp: Array = []
	for i in 6:
		sp.append({"kills": kills[i] if i < kills.size() else 0, "bonded": bonded[i] if i < bonded.size() else 0})
	return {"tick": 100, "social": {"species": sp}, "dig": {"dug": 0, "flames": 0, "beds": []}, "parts": {"discovered": []},
		"loadout": {"known": 0b1001}, "entities": [{"x": 0.0, "z": 0.0}]}

func run(t) -> void:
	# --- the chain as data ---
	var chain: Dictionary = Quest.load_chain()
	var steps: Array = chain.steps
	t.eq(steps.size(), 5, "the chain has five tasks")
	var ids := []
	for s in steps:
		ids.append(s.id)
		for k in ["title", "hint", "done"]:
			t.check(String(s[k].en) != "" and String(s[k].es) != "", "%s.%s in English and Spanish" % [s.id, k])
		t.check(int(s.reward.dna) > 0 and s.cond.has("type"), "%s has a reward and a condition" % s.id)
	t.eq(ids, ["hunt", "friend", "dig", "wings", "fire"], "the tasks, in order: kill, befriend, dig, wings, fire")
	t.eq(String(steps[4].cond.type), "all", "the last task has two parts (the gland, then the flame)")
	for k in ["q_sub_move_known", "q_sub_move_used", "q_sub_kill", "q_sub_bond_other", "q_sub_dug", "q_sub_part_found", "jt_tasks", "quest_done", "dig_prompt", "dig_hard", "fire_gland_found"]:
		t.check(Strings.has(k) and Strings.t(k) != k, "string %s exists" % k)

	# --- the model: conditions are live, steps advance in order, one per tick ---
	var q := Quest.new()
	t.eq(q.step, 0, "starts at the first task")
	var st := _species_state([], [])
	t.eq(q.update(st), [], "nothing done at the start")
	st = _species_state([0, 0, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0])
	t.eq(q.update(st), [], "a bond does not count before the hunt (steps are in order)")
	st = _species_state([1, 0, 0, 0, 0, 0], [0, 1, 0, 0, 0, 0])
	t.eq(q.update(st), ["hunt"], "a kill completes the hunt")
	t.eq(int(q.flags.killed_species), 0, "the species killed is remembered")
	t.eq(q.update(st), ["friend"], "the bond is already there: the next tick completes the friend task (live check)")
	t.eq(q.step, 2, "now on the dig")
	var q2 := Quest.new()
	q2.update(_species_state([1], []))
	t.eq(q2.update(_species_state([1], [2])), [], "a bond with the killed species (0) does not count")
	t.eq(q2.update(_species_state([1], [1, 0])), [], "bonds are per species: species 0 is the killed one")
	t.eq(q2.update(_species_state([1], [0, 1])), ["friend"], "a bond with another species counts")

	# dig, wings, fire
	var s3: Dictionary = _species_state([1], [0, 1])
	s3.dig = {"dug": 1, "flames": 0, "beds": [{"id": 0, "kind": 0, "dug": false, "x": 30.0, "z": 10.0}]}
	var q3 := Quest.new()
	for i in 2:
		q3.update(s3)
	t.eq(q3.update(s3), ["dig"], "a hole completes the dig task")
	t.eq(q3.update(s3), [], "the wings are not found yet")
	s3.parts = {"discovered": [{"id": "wing_vane", "index": 46}]}
	t.eq(q3.update(s3), ["wings"], "wing_vane discovered completes the wings task")
	t.eq(q3.parts_of(s3).size(), 2, "the fire task has two parts")
	t.eq(q3.update(s3), [], "gland not in the body yet")
	s3.loadout = {"known": 0b1001 | (1 << 6)}
	t.eq(q3.update(s3), [], "the gland alone is not enough")
	t.check(q3.parts_of(s3)[0].done and not q3.parts_of(s3)[1].done, "the card ticks the first part")
	s3.dig.flames = 1
	t.eq(q3.update(s3), ["fire"], "gland and a used flame complete the chain")
	t.check(q3.finished() and q3.current().is_empty() and q3.update(s3) == [], "finished: nothing more to do")

	# markers: a soft ping, never a route
	var q4 := Quest.new()
	var ms := _species_state([], [])
	ms.entities = [{"x": 0.0, "z": 0.0}, {"x": 80.0, "z": 0.0, "species": 0, "dead": false}, {"x": 20.0, "z": 5.0, "species": 3, "dead": false}, {"x": 40.0, "z": 0.0, "species": 1, "dead": false}]
	t.eq(q4.marker(ms), Vector2(40.0, 0.0), "the hunt points at the nearest prey (Rondo or Zanco), not at Garfio")
	q4.step = 3
	ms.dig.beds = [{"id": 0, "kind": 0, "dug": false, "x": 30.0, "z": 10.0}]
	t.eq(q4.marker(ms), Vector2(30.0, 10.0), "the wings task points at the wing bed")
	ms.dig.beds[0].dug = true
	t.eq(q4.marker(ms), Vector2.INF, "a spent bed points nowhere")
	q4.step = 2
	t.eq(q4.marker(ms), Vector2.INF, "the dig task has no marker")

	# saves, skip, reset, status
	var q5 := Quest.new()
	q5.update(_species_state([1], []))
	q5.collapsed = true
	var d: Dictionary = JSON.parse_string(JSON.stringify(q5.to_dict()))
	var q6 := Quest.new()
	q6.from_dict(d)
	t.check(q6.step == 1 and q6.collapsed and int(q6.flags.killed_species) == 0 and q6.done_at.has("hunt"), "the quest survives JSON (a save)")
	t.eq(q6.skip(), "friend", "skip completes the current task")
	t.check(q6.skipped.has("friend") and q6.step == 2, "and remembers it was skipped")
	t.check(q6.status().contains("step 3/5"), "status names the step (%s)" % q6.status())
	q6.reset()
	t.check(q6.step == 0 and q6.done_at.is_empty(), "reset starts over")
	q6.from_dict({"id": "other", "step": 4})
	t.eq(q6.step, 0, "a save of another chain is ignored")

	# --- the real C world: dig, reward, part, move ---
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	t.eq(w.reset(setup), 0, "a flat world resets")
	var s0: Dictionary = w.state()
	t.check(s0.has("dig") and s0.dig.has("beds") and s0.dig.beds.size() >= 1 and s0.dig.beds[0].kind == 0, "state().dig carries the wing bed")
	t.check(bool(s0.dig.soft) and int(s0.dig.dug) == 0 and int(s0.dig.digging) == 0, "flat ground is soft, nothing dug")
	t.eq(w.step({"verb": 20}) != "", true, "the dig order is accepted")
	var done := false
	var find := -9
	for i in 30:
		w.step({"verb": 0})
		for ev in w.state().social_events:
			if int(ev.type) == 28:
				done = true
				find = int(ev.move)
	t.check(done, "the dig finishes after two seconds and says so (event 28)")
	t.check(find >= 0 and int(w.state().dig.dug) == 1 and w.state().dig.holes.size() == 1, "one hole, find %d" % find)
	t.eq(w.step({"verb": 20}) != "", true, "a second dig order in the same spot is sent")
	t.eq(int(w.state().error), -26, "and refused: already dug (%s)" % CporeWorld.order_error(int(w.state().error)))
	var before: int = int(w.state().social.dna_balance)
	t.eq(w.quest_award(2, 15), 0, "a task reward is paid by C")
	t.eq(int(w.state().social.dna_balance) - before, 15, "and lands in the balance")
	t.eq(w.quest_award(2, 15), -1, "once per task")
	var moves: Array = CporeWorld.moves()
	t.check(moves.size() == 7 and moves[6].name == "flame" and moves[6].role_name == "poke" and moves[6].slottable and int(moves[6].cooldown) == 60, "the move table has the flamethrower (poke, 60 tick cooldown)")
	t.check(Profile.load_json("res://game/data/parts.json").parts.any(func(p): return p.id == "fire_gland" and p.c_type == "CP4_FIRE"), "the manifest has the fire gland")
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var hatch: Dictionary = Profile.load_json("res://game/data/hatchling.json").duplicate(true)
	t.eq(int(Profile.from_studio(hatch, manifest).profile.fire), 0, "the hatchling has no fire")
	hatch.parts.append({"type": "fire_gland", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0})
	t.eq(int(Profile.from_studio(hatch, manifest).profile.fire), 1, "with the gland its profile has fire 1")
	var has_part := false
	for p in w.state().parts.discovered:
		if String(p.id) == "fire_gland":
			has_part = true
	t.check(not has_part, "the gland is not known before the bed is dug")
	t.check(ResourceLoader.exists("res://actions/data/flame.json") and ResourceLoader.exists("res://game/actors/flame_fx.gd"), "the flame action and effect exist")
