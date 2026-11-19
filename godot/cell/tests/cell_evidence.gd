extends SceneTree
## Screenshots of the cell stage (xvfb, software GL). Run: make godot-cell-evidence
## Usage: ... --script res://cell/tests/cell_evidence.gd -- <out dir> [WxH]

var out_dir := ""
var stage

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/cell"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())

func _run() -> void:
	await process_frame
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "es"   # after Game._ready has read the player's settings
	stage = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(stage)
	await process_frame
	var args := OS.get_cmdline_user_args()
	var suffix := ""
	if args.size() > 1:
		suffix = "_" + args[1]
		var wh := args[1].split("x")
		root.size = Vector2i(int(wh[0]), int(wh[1]))
		await process_frame
	var seeds := {1: 3, 2: 4, 3: 5, 4: 6}
	if suffix != "":
		# a single phase-3 frame at the requested size
		stage.sim.seed_value = 3
		stage._apply_phase(3)
		stage.sim.demo()
		stage.advance(20.0)
		await _shot("size" + suffix)
		quit(0)
		return
	for ph in [1, 2, 3, 4]:
		stage.sim.seed_value = seeds[ph]
		stage._apply_phase(ph)
		stage.sim.demo()
		stage.advance(20.0)
		await _shot("phase%d" % ph)
	# mid-building view: nothing built, the hint and an unbuilt piece
	stage.sim.reset()
	stage._apply_phase(1)
	stage.sim.place("tr", stage.sim.pol(stage.sim.RO, -0.3))
	stage.sim.place("hk", Vector2(430, 330))
	stage.advance(3.0)
	await _shot("building")
	# the aggregation card
	stage.sim.reset()
	stage._apply_phase(4)
	stage.sim.demo()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 3:
		for t in ["hk", "ald", "pk", "ldh", "syn"]:
			stage.sim.add_piece(t, Vector2(360, 360) + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20, 120), true)
	for a in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.6, 0.35, 1.05, 1.75]:
		stage.sim.add_piece("fl", stage.sim.pol(stage.sim.RO, a), true)
	for a in [-0.8, 0.8, 1.2, 2.0, 2.5, -1.3]:
		stage.sim.add_piece("tr", stage.sim.pol(stage.sim.RO, a), true)
	for a in [PI, 3.5, 2.6]:
		stage.sim.add_piece("ex", stage.sim.pol(stage.sim.RO, a), true)
	var guard := 0
	while stage.sim.agg == null and guard < 400:
		stage.advance(5.0)
		guard += 1
	stage.advance(3.0)
	await _shot("aggregation_neighbours")
	stage.advance(3.5)
	for i in 30:
		await process_frame
	await _shot("aggregation_card")
	quit(0)
