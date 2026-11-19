extends SceneTree
## Screenshots of phases 5 and 6 and the carry-over card (xvfb, software GL). Run: make godot-cell2-evidence
## Usage: ... --script res://cell/tests/cell2_evidence.gd -- <out dir>

const Sim := preload("res://cell/cell_sim.gd")
const CSimC := preload("res://cell/colony_sim.gd")

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
	await at(8.4)
	await _shot("threat1_phage_hijack")
	await at(2.4)
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
	await _colony_shots()
	# the cell stage panel with the threats card, the hint and the schedule
	setup(3, 0, cas)
	await at(1.0 + 3.0)
	await _shot("phase5_panel")
	quit(0)

const RING := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

func fill_atp() -> void:
	for h in stage.colony.cells.keys():
		stage.colony.cells[h].atp = 10.0

func build(kinds: Array) -> void:
	for i in kinds.size():
		fill_atp()
		stage.colony.place(kinds[i], RING[i])
	fill_atp()

func _colony_shots() -> void:
	# a finished phase 5 cell hands its sheet to the colony
	var s = stage.sim
	s.seed_value = 3
	s.agg_done = true
	stage._apply_phase(5)
	s.demo()
	s.threats.on = false
	stage.advance(70.0)
	s.threats.done = true
	stage._refresh_hud(true)
	stage._apply_phase(6)
	await at(0.5)
	fill_atp()
	await at(0.2)
	await _shot("colony1_founder")
	# armed tool: free slots and a ghost
	stage.ccanvas.tool = "energy"
	stage.ccanvas.mouse_in = true
	stage.ccanvas.hover_hex = Vector2i(1, 0)
	stage.ccanvas.hover_pos = stage.ccanvas.hex_center(Vector2i(1, 0))
	await _shot("colony2_slots")
	stage.ccanvas.tool = ""
	stage.ccanvas.mouse_in = false
	# the colony of 7, swimming toward the light
	build(["energy", "motile", "motile", "energy", "energy", "motile"])
	await at(6.0)
	await _shot("colony3_swimming")
	# the amoeba: warning with the dotted front line
	stage.colony.dist = 0.0
	stage.colony.arrived = true
	fill_atp()
	await at(CSimC.WAVE_DELAY + 7.0)
	await _shot("colony4_warning")
	# defensive cells on the front line absorb the bites
	for h in stage.colony.front(stage.colony.wave.a):
		if h != Vector2i.ZERO:
			stage.colony.cells[h] = stage.colony._cell("defense", 10.0, 160.0)
	await at(CSimC.WARN_T - 7.0 + 2.6)
	await _shot("colony5_bites")
	await at(6.0)
	for i in 30:
		await process_frame
	await _shot("colony6_end_card")
	# a colony without defence loses cells
	stage._restart()
	build(["energy", "motile", "motile", "energy", "energy", "motile"])
	stage.colony.dist = 0.0
	stage.colony.arrived = true
	fill_atp()
	await at(CSimC.WAVE_DELAY + CSimC.WARN_T + 3.6)
	await _shot("colony7_undefended")
