extends SceneTree
## Screenshots of phases 5 and 6 and the carry-over card (xvfb, software GL). Run: make godot-cell2-evidence
## Usage: ... --script res://cell/tests/cell2_evidence.gd -- <out dir>

const Sim := preload("res://cell/cell_sim.gd")

var out_dir := ""
var stage

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/cell2"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())

## A phase 5 cell with the big factory and the given built counters; the schedule starts on `kind`.
func setup(seed_: int, kind: int, counters: Array, tier := 0) -> void:
	var s = stage.sim
	s.seed_value = seed_
	s.agg_done = true
	stage._apply_phase(5)
	s.demo()
	if tier > 0:
		s.set_tier(tier)
	for c in counters:
		if Sim.PIECES[c[0]].has("mem"):
			s.add_piece(c[0], s.pol(s.RO, c[1]), true)
		else:
			s.add_piece(c[0], Vector2(360 + c[1], 360 + c[2]), true)
	s.start_threats(1.0, kind)
	stage._refresh_hud(true)

func at(seconds: float) -> void:
	stage.advance(seconds)
	for i in 20:
		await process_frame

func _run() -> void:
	await process_frame
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "es"
	stage = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	stage.canvas.labels = false
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		var wh := args[1].split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
		await process_frame
	var cas := [["cas", -40, -90]]
	var pump := [["pump", -0.35]]
	var cats := [["cat", -50, -100], ["cat", 20, -110], ["cat", 60, -90]]
	var spn := [["spn", 0.5], ["spn", 0.85], ["spn", 1.2]]
	# 1 phage: the warning, the hijack, Cas cutting it
	setup(3, 0, cas)
	await at(1.0 + 6.0)
	await _shot("threat1_phage_warn")
	await at(7.6)
	await _shot("threat1_phage_hijack")
	await at(3.6)
	await _shot("threat1_phage_cas_cuts")
	# 2 antibiotic
	setup(3, 1, pump)
	await at(1.0 + 8.0)
	await _shot("threat2_antibiotic_warn")
	await at(11.0)
	await _shot("threat2_antibiotic_blocks")
	await at(1.5)
	await _shot("threat2_antibiotic_pump")
	# 3 oxidation
	setup(3, 2, cats)
	await at(1.0 + 8.0)
	await _shot("threat3_oxidation_warn")
	await at(5.0)
	await _shot("threat3_oxidation_hit")
	setup(3, 2, [])
	await at(1.0 + 10.0 + 9.0)
	await _shot("threat3_oxidation_no_catalase")
	# 4 amoeba (the amoeba comes in at angle ~ the seed's, spines are placed in the colliding arc by the test below)
	setup(3, 3, [])
	await at(1.0 + 6.0)
	await _shot("threat4_amoeba_warn")
	await at(4.0 + 6.0)
	await _shot("threat4_amoeba_bites")
	setup(3, 3, [])
	var a: float = 0.0
	await at(1.0 + 0.1)
	a = stage.sim.threats.a if stage.sim.threats.a != 0.0 else 0.0
	await at(9.0)
	a = stage.sim.threats.a
	stage.sim.add_piece("spn", stage.sim.pol(stage.sim.RO, a - 0.25), true)
	stage.sim.add_piece("spn", stage.sim.pol(stage.sim.RO, a), true)
	stage.sim.add_piece("spn", stage.sim.pol(stage.sim.RO, a + 0.25), true)
	await at(3.0)
	await _shot("threat4_amoeba_spines")
	# the cell stage panel with the threats card, the hint and the schedule
	setup(3, 0, cas)
	await at(1.0 + 3.0)
	await _shot("phase5_panel")
	quit(0)
