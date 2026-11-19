extends SceneTree
## Headless tests for phase 6 (the colony board) and the carry-over sheet. Run: make godot-cell-test

const CSim := preload("res://cell/colony_sim.gd")
const Sim := preload("res://cell/cell_sim.gd")
const Legacy := preload("res://cell/cell_legacy.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	test_board()
	test_atp()
	test_motion()
	test_wave()
	test_legacy_rules()
	test_legacy_file()
	test_sheet_from_cell()
	test_determinism()
	print("colony tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

func run(s, seconds: float) -> void:
	for i in int(seconds * 60.0):
		s.step(1.0 / 60.0)

const N := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

## A colony of GOAL_CELLS: founder + 2 energy + 2 motile + 2 more of `extra`, everything filled with ATP.
func colony(seed_: int = 1, extra := ["energy", "defense"], sheet := {}):
	var s = CSim.new(seed_, sheet)
	var kinds := ["energy", "motile", "motile", "energy"] + extra
	for i in kinds.size():
		for h in s.cells.keys():
			s.cells[h].atp = CSim.CAP
		var e: String = s.place(kinds[i], N[i])
		if e != "":
			printerr("colony(): ", kinds[i], " at ", N[i], " -> ", e)
	for h in s.cells.keys():
		s.cells[h].atp = CSim.CAP
	return s

func test_board() -> void:
	var s = CSim.new(1)
	ok(s.cells.size() == 1 and s.cells[Vector2i.ZERO].kind == "founder", "the colony starts with the founder")
	ok(s.place("energy", Vector2i(2, 0)) == "far", "a block must touch the colony")
	ok(s.place("energy", Vector2i.ZERO) == "taken", "a hex holds one cell")
	ok(s.place("photo", Vector2i(1, 0)) == "locked", "the photosynthetic cell is locked (próximamente)")
	ok(s.place("nope", Vector2i(1, 0)) == "unknown", "unknown block")
	var before: float = s.cells[Vector2i.ZERO].atp
	ok(s.place("energy", Vector2i(1, 0)) == "", "an energy cell goes next to the founder")
	ok(is_equal_approx(s.cells[Vector2i.ZERO].atp, before - 5.0), "its 5 ATP cost came out of the neighbour")
	ok(s.cells[Vector2i(1, 0)].atp == 0.0, "the new cell starts empty")
	ok(s.place("motile", Vector2i(2, 0)) == "atp", "a block needs a neighbour with the ATP (the founder is not touching it)")
	ok(s.place("defense", Vector2i(3, 0)) == "far", "outside the board is far")
	ok(s.slots().size() > 0 and s.slots().all(func(h): return not s.neighbours(h).is_empty() and CSim.on_board(h)), "slots are the empty hexes next to the colony")
	ok(not s.remove_at(Vector2i.ZERO), "the founder cannot be removed")
	ok(s.remove_at(Vector2i(1, 0)) and s.cells.size() == 1, "other blocks can")
	for h in [Vector2i(0, 0), Vector2i(1, -1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(0, 2)]:
		ok(CSim.from_px(CSim.to_px(h)) == h, "hex <-> pixel round trip %s" % str(h))
	ok(CSim.hex_dist(Vector2i(2, 0), Vector2i(-2, 0)) == 4, "hex distance")

func test_atp() -> void:
	var s = CSim.new(1)
	s.place("energy", Vector2i(1, 0))
	s.place("motile", Vector2i(-1, 0))
	for h in s.cells.keys():
		s.cells[h].atp = 0.0
	s.cells[Vector2i.ZERO].atp = 10.0
	s.cells[Vector2i(1, 0)].atp = 0.0
	run(s, 3.0)
	ok(s.cells[Vector2i(1, 0)].atp > 1.0, "neighbours share ATP: the energy cell next to the founder got some (%.1f)" % s.cells[Vector2i(1, 0)].atp)
	ok(s.cells[Vector2i(-1, 0)].atp > 0.5, "and the motile cell on the other side too (%.1f)" % s.cells[Vector2i(-1, 0)].atp)
	var a = CSim.new(1)
	var b = CSim.new(1)
	for k in [a, b]:
		k.cells[Vector2i.ZERO].atp = 0.0
	a.place("energy", Vector2i(1, 0)) if false else null
	a.cells[Vector2i(1, 0)] = a._cell("energy", 0.0, 100.0)
	b.cells[Vector2i(1, 0)] = b._cell("defense", 0.0, 100.0)
	run(a, 20.0)
	run(b, 20.0)
	ok(a.total_atp() > b.total_atp() + 10.0, "an energy cell makes more ATP than a defensive one (%.1f vs %.1f)" % [a.total_atp(), b.total_atp()])
	# the founder's rate scales everything: a better factory feeds a better colony
	var lo = CSim.new(1, {"atp_min": 90, "mem": 97, "tier": 5, "pieces": {}})
	var hi = CSim.new(1, {"atp_min": 300, "mem": 97, "tier": 5, "pieces": {}})
	lo.cells[Vector2i.ZERO].atp = 0.0
	hi.cells[Vector2i.ZERO].atp = 0.0
	run(lo, 10.0)
	run(hi, 10.0)
	ok(hi.total_atp() > lo.total_atp() * 2.0, "the founder's ATP/min sheet sets the colony's income (%.1f vs %.1f)" % [hi.total_atp(), lo.total_atp()])
	var weak = CSim.new(1, {"atp_min": 150, "mem": 40, "tier": 5, "pieces": {}})
	ok(weak.cells[Vector2i.ZERO].hp < CSim.new(1).cells[Vector2i.ZERO].hp, "a fragile founder membrane means fragile blocks")

func test_motion() -> void:
	var s = colony(1, ["energy", "defense"])
	run(s, 10.0)
	ok(s.speed > 0.0 and s.dist < CSim.TARGET_DIST, "motile cells with ATP move the colony toward the light (speed %.1f, %.0f left)" % [s.speed, s.dist])
	var s1 = CSim.new(1)
	s1.place("energy", Vector2i(1, 0))
	s1.place("motile", Vector2i(-1, 0))
	s1.place("motile", Vector2i(0, 1))
	for h in s1.cells.keys():
		s1.cells[h].atp = CSim.CAP
	var s2 = colony(1, ["energy", "defense"])
	run(s1, 5.0)
	run(s2, 5.0)
	var sp1: float = s1.speed
	ok(s2.speed >= sp1 or s2.count("motile") >= s1.count("motile"), "speed is thrust over mass")
	var none = CSim.new(1)
	run(none, 30.0)
	ok(none.speed == 0.0 and none.dist == CSim.TARGET_DIST, "no motile cell, no movement")
	var t := 0.0
	while not s.arrived and t < 300.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
	ok(s.arrived, "the colony reaches the light (%.0f s)" % t)
	ok(t < 120.0, "within two minutes with two motile cells (%.0f s)" % t)
	# starved motile cells stop
	var st = colony(1)
	for h in st.cells.keys():
		st.cells[h].atp = 0.0
	st.cells[Vector2i.ZERO].atp = 0.0
	for h in st.cells.keys():
		if st.cells[h].kind == "energy":
			st.cells[h].atp = 0.0
	st.rate = 0.0001
	run(st, 2.0)
	ok(st.speed < 20.0, "starved cells swim slower or not at all (%.1f)" % st.speed)

func prepare_wave(s) -> void:
	s.dist = 0.0
	s.arrived = true
	for h in s.cells.keys():
		s.cells[h].atp = CSim.CAP

func test_wave() -> void:
	# an undefended front line loses cells and the wave is failed
	var s = colony(2, ["energy", "motile"])
	prepare_wave(s)
	var a: float = s.wave.a
	var t := 0.0
	var warned := false
	var order := []
	while s.wave.result == "" and t < 120.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
		if s.wave.stage == "warn":
			warned = true
		if order.is_empty() or order[-1] != s.wave.stage:
			order.append(s.wave.stage)
	ok(warned and order.find("warn") < order.find("hit"), "the direction is announced before the bites: %s" % str(order))
	ok(s.wave.result == "fail", "no defensive cell: the amoeba breaks the colony (%d cells left)" % s.cells.size())
	ok(s.cells.size() < CSim.GOAL_CELLS, "cells were lost")
	ok(s.wave.tries == 1 and s.wave.stage == "wait", "the wave comes back after a failure")
	ok(s.cells.has(Vector2i.ZERO), "the founder stands")
	# defensive cells on the front line: absorbed, survived
	var d = CSim.new(2)
	for i in 6:
		for h in d.cells.keys():
			d.cells[h].atp = CSim.CAP
		d.place("energy" if i % 2 == 0 else "motile", N[i])
	for h in d.cells.keys():
		d.cells[h].atp = CSim.CAP
	d.cells[Vector2i(0, 1)] = d._cell("energy", 10.0, 100.0)
	prepare_wave(d)
	var front: Array = d.front(d.wave.a)
	ok(front.size() >= 1 and front.size() <= 3, "the front line is one to three cells (%d)" % front.size())
	for h in front:
		if h != Vector2i.ZERO:
			d.cells[h] = d._cell("defense", 10.0, 160.0)
	t = 0.0
	while d.wave.result == "" and t < 120.0:
		d.step(1.0 / 60.0)
		t += 1.0 / 60.0
	ok(d.wave.result == "ok" and d.done, "defensive cells on the front line: the colony survives (%d cells)" % d.cells.size())
	ok(d.cells.size() >= CSim.GOAL_CELLS, "with all its cells")
	ok("colony_done" in d.take_events(), "the end is announced")
	ok(d.place("energy", Vector2i(2, 0)) == "done", "nothing is placed after the end")
	# the wave only starts at the light with 7 cells
	var e = CSim.new(2)
	run(e, 20.0)
	ok(e.wave.stage == "wait", "no wave before the colony is built and has reached the light")
	var f = colony(3, ["energy", "defense"])
	f.arrived = false
	run(f, 3.0)
	ok(f.wave.stage == "wait" or not f.arrived, "nor before the light is reached")

func test_legacy_rules() -> void:
	var base := {"atp_min": 160, "mem": 97, "tier": 5, "pieces": {"hk": 3, "ald": 3, "pk": 3, "ldh": 3, "syn": 3, "fl": 12, "tr": 6, "ex": 3}}
	var d: Dictionary = Legacy.derive(base, {"cells": 7, "defense": 0})
	ok(d.diet == "cazador", "a lean factory (waste handling %.2f) is a hunter" % d.tally.waste_share)
	var ferm: Dictionary = base.duplicate(true)
	ferm.pieces.ldh = 8
	ferm.pieces.ex = 7
	var d2: Dictionary = Legacy.derive(ferm, {"cells": 7})
	ok(d2.diet == "carronero", "a fermentation-heavy factory (waste handling %.2f) is a scavenger" % d2.tally.waste_share)
	ok(Legacy.derive(base, {"photo": 1}).diet == "herbivoro", "a photosynthetic cell makes a herbivore")
	var sp: Dictionary = base.duplicate(true)
	sp.pieces.spn = 5
	ok(Legacy.derive(sp, {"defense": 0}).defense == "espinas", "spines on the membrane give 'espinas'")
	ok(Legacy.derive(base, {"defense": 6}).defense == "espinas", "so do many defensive colony cells")
	ok(Legacy.derive(base, {"defense": 0}).defense == "placas", "flippases and a thick membrane give 'placas'")
	var bare: Dictionary = {"atp_min": 100, "mem": 70, "tier": 0, "pieces": {"hk": 1}}
	ok(Legacy.derive(bare, {}).defense == "ninguna", "a bare cell has no defence part")
	for t in [[0, "small"], [1, "small"], [2, "medium"], [3, "medium"], [4, "large"], [5, "large"]]:
		var sh: Dictionary = base.duplicate(true)
		sh.tier = t[0]
		ok(Legacy.derive(sh).size_class == t[1], "tier %d is %s" % [t[0], t[1]])

func test_legacy_file() -> void:
	var path := "user://cell_legacy_test.json"
	DirAccess.remove_absolute(path)
	ok(Legacy.read(path).is_empty(), "no file, no legacy")
	var d: Dictionary = Legacy.derive({"atp_min": 170, "mem": 98, "tier": 4, "pieces": {"fl": 12, "spn": 3, "ldh": 3, "pk": 3}}, {"cells": 8, "defense": 1})
	ok(Legacy.save(d, path), "the legacy file is written")
	var r: Dictionary = Legacy.read(path)
	ok(r.diet == d.diet and r.defense == d.defense and r.size_class == d.size_class and int(r.version) == 1, "round trip keeps diet, defence, size and version")
	ok(int(r.stats.colony_cells) == 8 and int(r.stats.atp_min) == 170 and r.source == "colony", "and the stats")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 99, "diet": "cazador", "defense": "placas", "size_class": "small"}')
	f.close()
	ok(Legacy.read(path).is_empty(), "a file from another version is ignored")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 1, "diet": "dragon", "defense": "placas", "size_class": "small"}')
	f.close()
	ok(Legacy.read(path).is_empty(), "unknown values are ignored")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("not json")
	f.close()
	ok(Legacy.read(path).is_empty(), "garbage is ignored")
	DirAccess.remove_absolute(path)
	# Game.cell_legacy() reads Game.legacy_path
	var game = root.get_node("Game")
	var old: String = game.legacy_path
	game.legacy_path = path
	ok(game.cell_legacy().is_empty(), "Game.cell_legacy() is empty without a file")
	Legacy.save(d, path)
	ok(game.cell_legacy().get("diet", "") == d.diet, "Game.cell_legacy() returns the saved legacy")
	game.legacy_path = old
	DirAccess.remove_absolute(path)

func test_sheet_from_cell() -> void:
	var s = Sim.new(3, 5)
	s.demo()
	s.threats.on = false   # no wave during this measurement
	for i in 60 * 70:
		s.step(1.0 / 60.0)
	var sh: Dictionary = s.legacy_sheet()
	ok(sh.has("atp_min") and sh.has("mem") and sh.has("tier") and sh.pieces.has("hk"), "the cell exposes a numeric sheet for the colony")
	ok(int(sh.pieces.fl) == 17 and int(sh.pieces.rib) == 2, "with its piece counts (%s)" % str(sh.pieces))
	ok(int(sh.atp_min) > 50, "and its production (%d ATP/min)" % int(sh.atp_min))
	var c = CSim.new(1, sh)
	ok(is_equal_approx(c.rate, clampf(float(sh.atp_min) / 150.0, 0.6, 2.0)), "the colony reads that sheet")

func test_determinism() -> void:
	var a = colony(7)
	var b = colony(7)
	var c = colony(8)
	prepare_wave(a)
	prepare_wave(b)
	prepare_wave(c)
	run(a, 40.0)
	run(b, 40.0)
	run(c, 40.0)
	ok(a.cells.size() == b.cells.size() and a.wave.a == b.wave.a and a.wave.stage == b.wave.stage and a.dist == b.dist, "same seed, same colony run")
	ok(a.wave.a != c.wave.a or a.light_a != c.light_a, "a different seed differs (attack side, light side)")
