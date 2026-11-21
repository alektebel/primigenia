extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	assert(load("res://game/stage/stage_ui.gd").can_instantiate())
	assert(load("res://game/stage/part_nodes.gd").can_instantiate())
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	assert(w.reset(setup) == 0)
	assert(w.state().recipes.bone_spines.state == "unknown")
	var nodes: Array = w.state().parts.nodes
	for i in 2:
		assert(w.debug({"op": 1, "id": 0, "x": nodes[i].x, "z": nodes[i].z}) == 0)
		assert(w.command("inspect #%d" % nodes[i].id) == 0)
		for tick in 20:
			w.step({})
		assert(w.state().recipes.bone_spines.state == ("hinted" if i == 0 else "known"))
	assert(w.command("eat #3001") == 0)
	for tick in 5:
		w.step({})
	assert(w.state().recipes.meters.calcium.value == 20)
	var stone: Dictionary = w.state().recipes.stones[0]
	assert(w.debug({"op": 1, "id": 0, "x": stone.x, "z": stone.z}) == 0)
	assert(w.command("eat #%d" % stone.id) == 0)
	for tick in 5:
		w.step({})
	assert(w.state().recipes.meters.mineral.value == 25)
	var saved := w.snapshot()
	var hash_before := w.hash()
	w.step({})
	assert(w.restore(saved) == 0 and w.hash() == hash_before)
	var signs = load("res://ui/quiet_signs.gd").new()
	signs.calcium = 20
	signs.mineral = 25
	assert(signs.line_y("calcium") != signs.line_y("mineral"))
	signs.free()
	assert(CporeWorld.moves().size() == 14)
	w = null
	print("Godot moves/recipes: PASS")
	quit()
