extends SceneTree
## Headless tests for the cell stage sim. Run: make godot-cell-test

const Sim := preload("res://cell/cell_sim.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func run(sim, seconds: float, until: Callable = Callable()) -> float:
	var t := 0.0
	while t < seconds:
		sim.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if until.is_valid() and until.call():
			break
	return t

func _initialize() -> void:
	test_goals()
	test_costs_and_remove()
	test_phase_lock()
	test_inhibition()
	test_determinism()
	test_aggregation()
	print("cell tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

func test_goals() -> void:
	var s = Sim.new(7, 1)
	s.demo()
	var t := run(s, 240.0, func(): return s.goal().done)
	ok(s.goal().done, "phase 1 demo reaches 40 ATP (%.0fs, %d)" % [t, s.goal_state.atp])
	ok(t < 120.0, "phase 1 goal within 120 s (took %.0f)" % t)
	s = Sim.new(7, 2)
	s.demo()
	t = run(s, 300.0, func(): return s.goal().done)
	ok(s.goal().done, "phase 2 demo exports 12 lactates (%.0fs, %d)" % [t, s.goal_state.lac])
	ok(t < 180.0, "phase 2 goal within 180 s (took %.0f)" % t)
	s = Sim.new(7, 3)
	s.demo()
	t = run(s, 400.0, func(): return s.goal().done)
	ok(s.goal().done, "phase 3 demo holds the membrane >=95%% for 60 s (%.0fs, mem %d)" % [t, s.mem_pct()])

func test_costs_and_remove() -> void:
	var s = Sim.new(3, 1)
	ok(s.place("tr", s.pol(s.RO, 0.0)) == "", "place transporter on the membrane")
	ok(s.place("hk", Vector2(400, 330)) == "", "place hexokinase inside")
	var hk = s.pieces[1]
	ok(not hk.built, "a new piece is not built yet")
	run(s, 40.0, func(): return s.pieces[0].built and hk.built)
	ok(s.pieces[0].built and s.pieces[0].got == 2, "transporter paid its 2 ATP (got %d)" % s.pieces[0].got)
	ok(hk.built and hk.got == 2, "hexokinase paid its 2 ATP (got %d)" % hk.got)
	ok(s.place("hk", s.pol(s.RO, 0.0)) == "where", "an enzyme cannot go on the membrane")
	ok(s.place("tr", Vector2(360, 360)) == "where", "a transporter cannot go in the middle")
	ok(s.place("nope", Vector2(360, 360)) == "unknown", "unknown kind")
	var n: int = s.pieces.size()
	ok(s.remove_at(Vector2(400, 330)), "remove_at finds the hexokinase")
	ok(s.pieces.size() == n - 1, "piece count dropped")
	ok(not s.remove_at(Vector2(100, 100)), "remove_at on empty space is false")

func test_phase_lock() -> void:
	var s = Sim.new(1, 1)
	ok(s.place("ldh", Vector2(380, 360)) == "phase", "lactate DH is not placeable in phase 1")
	ok(s.place("ex", s.pol(s.RO, 1.0)) == "phase", "exporter is not placeable in phase 1")
	s.set_phase(2)
	ok(s.place("ldh", Vector2(380, 360)) == "", "lactate DH placeable in phase 2")
	ok(s.place("syn", Vector2(340, 360)) == "phase", "synthase is not placeable in phase 2")
	ok(s.place("fl", s.pol(s.RO, 2.0)) == "phase", "flippase is not placeable in phase 2")
	s.set_phase(3)
	ok(s.place("syn", Vector2(340, 340)) == "", "synthase placeable in phase 3")
	ok(s.place("fl", s.pol(s.RO, 2.0)) == "", "flippase placeable in phase 3")

func test_inhibition() -> void:
	# hexokinase with no aldolase: g6p piles up and at 6 free g6p the hexokinase reports inhibida
	var s = Sim.new(5, 1)
	for a in [-0.35, 0.35]:
		s.add_piece("tr", s.pol(s.RO, a), true)
	s.add_piece("hk", Vector2(455, 320), true)
	s.add_piece("hk", Vector2(300, 400), true)
	var reached := false
	for i in 60 * 120:
		s.step(1.0 / 60.0)
		if s.count("g6p", "free") >= 6:
			s.step(1.0 / 60.0)
			var hk = s.built_of("hk")[0]
			ok(hk.block == "inhibida", "hexokinase is inhibited once 6 g6p pile up (status %s)" % hk.st)
			reached = true
			break
	ok(reached, "g6p reached the inhibition threshold")
	# below the threshold it is not inhibited
	var s2 = Sim.new(5, 1)
	s2.add_piece("hk", Vector2(455, 320), true)
	s2.step(1.0 / 60.0)
	ok(s2.built_of("hk")[0].block == "", "no inhibition with no g6p")

func test_determinism() -> void:
	var a = Sim.new(42, 3)
	var b = Sim.new(42, 3)
	var c = Sim.new(43, 3)
	a.demo()
	b.demo()
	c.demo()
	run(a, 60.0)
	run(b, 60.0)
	run(c, 60.0)
	ok(a.stats() == b.stats() and a.mols.size() == b.mols.size() and a.goal_state == b.goal_state, "same seed gives the same stats")
	ok(a.lines() == b.lines(), "same seed gives the same lines")
	ok(a.mols.size() != c.mols.size() or a.goal_state != c.goal_state or a.stats() != c.stats(), "a different seed differs")

func test_aggregation() -> void:
	# a big factory: many lines of every enzyme, many flippases; reach tier 5 and sustain 150 ATP/min for 20 s
	var s = Sim.new(11, 4)
	s.demo()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var n := 0
	for k in 3:
		for t in ["hk", "ald", "pk", "ldh", "syn"]:
			s.add_piece(t, Vector2(360, 360) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 120), true)
	for a in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.6, 0.35, 1.05, 1.75]:
		s.add_piece("fl", s.pol(s.RO, a), true)
	for a in [-0.8, 0.8, 1.2, 2.0, 2.5, -1.3]:
		s.add_piece("tr", s.pol(s.RO, a), true)
	for a in [PI, 3.5, 2.6]:
		s.add_piece("ex", s.pol(s.RO, a), true)
	var t := run(s, 1800.0, func(): return s.agg != null)
	ok(s.tier == s.TIERS, "reached tier %d (%d)" % [s.TIERS, s.tier])
	ok(s.agg_done and s.aggregation().active, "aggregation triggered after tier 5 sustained (%.0fs, rate %d)" % [t, s.stats().atp_min])
	run(s, 7.0)
	ok(s.aggregation().shown, "the aggregation card is shown ~5.5 s later")
	ok(s.aggregation().stats.size() == 8, "the sheet has eight rows")
	s.continue_colony()
	run(s, 2.0)
	ok(not s.aggregation().active, "continuing dismisses the colony")
