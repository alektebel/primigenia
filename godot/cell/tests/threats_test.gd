extends SceneTree
## Headless tests for phase 5 (the four threats and their counters, the wave, determinism). Run: make godot-cell-test

const Sim := preload("res://cell/cell_sim.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	test_places_and_gates()
	test_phage()
	test_antibiotic()
	test_oxidation()
	test_amoeba()
	test_retry()
	test_wave()
	test_determinism()
	print("cell threat tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

## A phase 5 cell with the phase-3 demo factory, two ribosomes and the given free (already built) counters.
func make(seed_: int, kind: int, counters: Array = [], tier := 0):
	var s = Sim.new(seed_, 5)
	s.demo()
	if tier > 0:
		s.set_tier(tier)
	for c in counters:
		if Sim.PIECES[c[0]].has("mem"):
			s.add_piece(c[0], s.pol(s.RO, c[1]), true)
		else:
			s.add_piece(c[0], Vector2(360 + c[1], 360 + c[2]), true)
	s.start_threats(1.0, kind)
	return s

func until_verdict(s, kind: int, limit := 200.0) -> float:
	var t := 0.0
	while s.threats.results[kind] == "" and t < limit:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
	return t

func run(s, seconds: float) -> void:
	for i in int(seconds * 60.0):
		s.step(1.0 / 60.0)

const CAS := [["cas", -40, -90]]
const PUMP := [["pump", -0.35]]
const CATS := [["cat", -50, -100], ["cat", 20, -110], ["cat", 60, -90]]
const SPN := [["spn", 0.0], ["spn", 0.3], ["spn", -0.3]]

func test_places_and_gates() -> void:
	var s = Sim.new(4, 4)
	ok(s.place("rib", Vector2(380, 360)) == "phase", "ribosome is locked before phase 5")
	ok(not s.threats_unlocked(), "threats are locked before the aggregation")
	s.set_phase(5)
	ok(s.place("cas", Vector2(380, 360)) == "need_rib", "a Cas cannot be started without a ribosome")
	ok(s.place("spn", s.pol(s.RO, 1.0)) == "need_rib", "spines cannot be started without a ribosome")
	ok(s.place("rib", s.pol(s.RO, 1.0)) == "where", "a ribosome goes inside the cell")
	ok(s.place("rib", Vector2(380, 360)) == "", "a ribosome is placeable in phase 5")
	ok(s.place("cas", Vector2(340, 330)) == "need_rib", "an unbuilt ribosome does not count")
	# the ribosome builds, then the counter proteins are built with ATP
	s.demo()
	var cas = s.pieces.filter(func(p): return p.type == "cas")
	ok(cas.is_empty(), "no Cas yet")
	ok(s.place("cas", Vector2(340, 330)) == "", "with a built ribosome a Cas can start")
	ok(s.place("pump", s.pol(s.RO, -0.3)) == "", "pump goes on the membrane")
	ok(s.place("cat", Vector2(330, 300)) == "", "catalase goes inside")
	ok(s.place("spn", s.pol(s.RO, 1.0)) == "", "spines go on the membrane")
	for p in s.pieces:
		if p.type == "cas":
			cas = p
	run(s, 40.0)
	ok(cas is Object and cas.built and cas.got == 4, "the Cas paid its 4 ATP once a ribosome was free (got %d)" % cas.got)
	# a hijacked ribosome stops the building of counter proteins
	var s2 = Sim.new(4, 5)
	s2.demo()
	for r in s2.built_of("rib"):
		r.hij = 30.0
	s2.place("cat", Vector2(330, 300))
	run(s2, 6.0)
	var ct = s2.pieces.filter(func(p): return p.type == "cat")[0]
	ok(ct.got == 0 and ct.claim == 0, "no counter protein is built while every ribosome is hijacked (got %d claim %d)" % [ct.got, ct.claim])
	for r in s2.built_of("rib"):
		r.hij = 0.0
	run(s2, 30.0)
	ok(ct.built, "it is built once a ribosome is free again")
	var rib = s2.built_of("rib")[0]
	ok(rib.st in ["listo", "trabaja"], "a free ribosome reports ready or working (%s)" % rib.st)

func test_phage() -> void:
	var s = make(1, 0)
	var t := until_verdict(s, 0)
	ok(s.threats.results[0] == "fail", "a phage without Cas breaks the membrane under 60 %% (min %d)" % s.threats.min)
	ok(s.built_of("rib").size() < 2, "a hijacked ribosome that is not cut is lost (%d left)" % s.built_of("rib").size())
	var s2 = make(1, 0, CAS)
	var hijacks := 0
	var cuts := 0
	var seen_hij := false
	var t2 := 0.0
	while s2.threats.results[0] == "" and t2 < 120.0:
		s2.step(1.0 / 60.0)
		t2 += 1.0 / 60.0
		for e in s2.take_events():
			if e == "hijack":
				hijacks += 1
			elif e == "cut":
				cuts += 1
		if s2.built_of("rib").any(func(r): return r.hij > 0.0):
			seen_hij = true
	ok(seen_hij, "the first phage does hijack a ribosome even with Cas (it only learns afterwards)")
	ok(s2.threats.results[0] == "ok", "Cas lets the cell survive the phage (min %d)" % s2.threats.min)
	ok(s2.cas_primed, "Cas learned the phage after the first infection")
	ok(hijacks == 1 and cuts == 2, "the second phage is cut before it arrives: %d hijack, %d cuts" % [hijacks, cuts])
	ok(s2.built_of("rib").size() == 2, "both ribosomes survive with Cas")

func test_antibiotic() -> void:
	var s = make(1, 1)
	var blocked := false
	var t := 0.0
	while s.threats.results[1] == "" and t < 120.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if s.built_of("rib").any(func(r): return r.st == "bloqueada"):
			blocked = true
	ok(blocked, "the antibiotic blocks the ribosomes (they report 'bloqueada')")
	ok(s.threats.results[1] == "fail", "no pump: the membrane gets holes (min %d)" % s.threats.min)
	var s2 = make(1, 1, PUMP)
	var peak := 0
	t = 0.0
	var clear_at := -1.0
	while s2.threats.results[1] == "" and t < 120.0:
		s2.step(1.0 / 60.0)
		t += 1.0 / 60.0
		var n: int = s2.count("abx", "stuck") + s2.count("abx", "free") + s2.count("abx", "pump")
		peak = maxi(peak, n)
		if s2.threats.n >= 8 and n == 0 and clear_at < 0.0:
			clear_at = t
	ok(peak >= 3, "the antibiotic gets inside (peak %d molecules at once)" % peak)
	ok(clear_at > 0.0 and clear_at < 30.0, "the pump clears it all out (at %.0f s)" % clear_at)
	ok(s2.threats.results[1] == "ok", "pump: survived (min %d)" % s2.threats.min)
	ok(s2.built_of("rib").all(func(r): return r.abx == 0), "ribosomes are free of antibiotic after the pump")
	# the pump pays ATP per molecule: with no free ATP at all it cannot pump
	var s3 = make(1, 1, PUMP)
	for i in 60 * 24:
		s3.step(1.0 / 60.0)
		for m in s3.mols:
			if m.type == "atp":
				m.dead = true
		s3.store = 0
	var waiting: int = s3.count("abx", "stuck") + s3.count("abx", "free")
	ok(waiting >= 4 and s3.count("abx", "pump") == 0, "the pump does nothing without ATP (%d molecules stay)" % waiting)

func test_oxidation() -> void:
	var s = make(1, 2)
	until_verdict(s, 2)
	ok(s.threats.results[2] == "fail", "oxidation with no catalase breaks the membrane (min %d)" % s.threats.min)
	var s2 = make(1, 2, CATS)
	var absorbed := 0
	var t := 0.0
	while s2.threats.results[2] == "" and t < 120.0:
		s2.step(1.0 / 60.0)
		t += 1.0 / 60.0
	ok(s2.threats.results[2] == "ok", "three catalases neutralise the wave (min %d)" % s2.threats.min)
	ok(int(s2.threats.min) > int(s.threats.min) + 20, "catalase is worth >20 points of membrane (%d vs %d)" % [s2.threats.min, s.threats.min])
	var s3 = make(1, 2)
	run(s3, 1.0 + 10.0 + 6.0)
	ok(s3.pieces.any(func(p): return p.ox > 0.0), "unneutralised radicals oxidise enzymes")

func test_amoeba() -> void:
	var s = make(1, 3)
	until_verdict(s, 3)
	ok(s.threats.results[3] == "fail", "an amoeba that holds on swallows the cell (min %d)" % s.threats.min)
	var s2 = make(1, 3, SPN)
	until_verdict(s2, 3)
	ok(s2.threats.results[3] == "ok", "three spines make the amoeba let go (min %d)" % s2.threats.min)
	var s3 = make(1, 3, [], 3)
	until_verdict(s3, 3)
	ok(s3.threats.results[3] == "ok", "size 3 is too big to swallow (min %d)" % s3.threats.min)
	var s4 = make(1, 3, [["spn", 0.0], ["spn", 0.3]])
	until_verdict(s4, 3)
	ok(s4.threats.results[3] == "fail", "two spines are not enough")

func test_retry() -> void:
	var s = make(2, 0)
	s.wait_gap = 60.0
	until_verdict(s, 0)
	ok(s.threats.results[0] == "fail" and s.threats.tries == 1, "a failed threat is counted")
	ok(s.threats.idx == 0 and s.threats.stage == "wait", "and it waits to come back")
	ok(s.diagnose() == "d_threat", "the diagnosis says what happened")
	var info: Dictionary = s.threat_info()
	ok(info.kind == "phage" and info.counter == "cas" and not info.has_counter, "the schedule names the threat and its missing counter")
	# build the Cas now: the retry is survived
	s.add_piece("cas", Vector2(320, 270), true)
	run(s, 60.0 + 1.0)
	ok(s.threats.stage == "warn" or s.threats.stage == "hit", "the phage comes back")
	var t := 0.0
	while s.threats.results[0] != "ok" and t < 120.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
	ok(s.threats.results[0] == "ok" and s.threats.idx == 1, "with Cas the retry is survived and the schedule moves on (%s)" % str(s.threats.results))

func test_wave() -> void:
	var s = Sim.new(9, 5)
	s.demo()
	s.wait_first = 2.0
	s.wait_gap = 2.0
	for c in CAS + CATS:
		s.add_piece(c[0], Vector2(360 + c[1], 360 + c[2]), true)
	s.add_piece("pump", s.pol(s.RO, -0.35), true)
	for c in SPN:
		s.add_piece("spn", s.pol(s.RO, c[1]), true)
	s.start_threats(2.0)
	var kinds := []
	var t := 0.0
	var last := ""
	while not s.threats.done and t < 400.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
		var k: String = s.threat_kind()
		if k != last:
			kinds.append(k)
			last = k
	ok(s.threats.done, "one wave of the four threats is survived (%.0f s, results %s)" % [t, str(s.threats.results)])
	ok(kinds == ["phage", "abx", "ox", "amoeba"], "they arrive in the published order: %s" % str(kinds))
	ok(s.threats.tries == 0, "no threat had to come back")
	var g: Dictionary = s.goal()
	ok(g.id == "g_threats" and g.done and g.v == 4, "the phase 5 goal is complete (%d/4)" % g.v)
	ok(s.colony_unlocked(), "the colony unlocks")
	ok(s.mem_pct() >= 60, "the membrane holds at the end (%d %%)" % s.mem_pct())
	# the warning exists before every hit
	var s2 = make(1, 2)
	run(s2, 1.0 + 3.0)
	var info: Dictionary = s2.threat_info()
	ok(info.stage == "warn" and info.eta > 5.0 and info.eta < 10.0, "a warning comes first and counts down (%s %.1f)" % [info.stage, info.eta])
	ok(s2.flash > 0.0, "the oxidation warning flashes")
	var s3 = make(1, 1)
	run(s3, 1.0 + 5.0)
	ok(s3.tide > 0.3, "the antibiotic warning tints the water (%.2f)" % s3.tide)
	var s4 = make(1, 0)
	run(s4, 1.0 + 3.0)
	ok(s4.phages.size() == 1 and s4.phages[0].state == "in", "a phage drifts in during the warning")
	var s5 = make(1, 3)
	run(s5, 1.0 + 3.0)
	ok(s5.amoeba != null and s5.amoeba.state == "come", "an amoeba approaches during the warning")

func test_determinism() -> void:
	var a = make(5, 2, CATS)
	var b = make(5, 2, CATS)
	var c = make(6, 2, CATS)
	run(a, 30.0)
	run(b, 30.0)
	run(c, 30.0)
	ok(a.stats() == b.stats() and a.mols.size() == b.mols.size() and a.threats == b.threats and a.integ == b.integ, "same seed, same wave, same membrane")
	ok(a.ox_a == b.ox_a and a.ox_a != c.ox_a, "the oxidation side depends on the seed")
	ok(a.integ != c.integ, "a different seed differs")
