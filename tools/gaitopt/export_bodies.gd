extends SceneTree
## Run from the Godot project. Output is a single JSON object keyed by body id.
const Bodies := preload("res://locomotion/test/bodies.gd")
const Zoo := preload("res://devtools/zoo/zoo_genomes.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const Morph := preload("res://locomotion/loco_morphology.gd")

func _initialize() -> void:
	call_deferred("_export")

func json_value(value):
	if value is Vector3:
		return [value.x, value.y, value.z]
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = json_value(value[key])
		return result
	if value is Array:
		return value.map(json_value)
	return value

func describe(g: Dictionary) -> Dictionary:
	var rig := Creature.new()
	root.add_child(rig)
	var parsed := rig.load_genome(g)
	var ok: bool = parsed.ok
	if not ok:
		printerr("Genome validation failed: ", parsed.error)
	var desc := Adapter.loco_describe(rig, 1.0) if ok else {}
	rig.free()
	return desc

func sample_genome(i: int, rng: RandomNumberGenerator) -> Dictionary:
	var base := Zoo.genome("hero")
	var size := exp(lerpf(log(0.3), log(6.0), (i + rng.randf()) / 200.0))
	var g := Zoo.scaled(base, size / 6.0)
	if size < 0.6:
		g.nodes = [g.nodes[0], g.nodes[2], g.nodes[4], g.nodes[7]]
	for node in g.nodes:
		node.r = clampf(node.r * rng.randf_range(0.85, 1.15), 0.03, 3.0)
	return Zoo._with_legs(g, 1 + i % 4, 0.32, 0.70, rng.randf_range(0.75, 1.25))

func _export() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		printerr("Supply an output file path and optionally --catalog")
		quit(1)
		return
	var descriptions := {}
	for id in ["biped", "horizontal_biped", "light_quadruped", "heavy_quadruped", "hexapod", "octopod", "wader"]:
		descriptions[id] = Bodies.get_body(id)
	descriptions.merodeador = describe(Zoo.genome("hero"))
	descriptions.hatchling = describe(Zoo.scaled(Zoo.genome("hero"), 0.18))
	descriptions.garfio = describe(JSON.parse_string(FileAccess.get_file_as_string("res://game/data/garfio.json")))
	if "--catalog" in args:
		for id in Zoo.ids():
			descriptions["zoo_" + id] = describe(Zoo.genome(id))
		var rng := RandomNumberGenerator.new()
		rng.seed = 1901
		for i in 200:
			descriptions["sample_%03d" % i] = describe(sample_genome(i, rng))

	for id in descriptions:
		var desc: Dictionary = descriptions[id]
		if desc.is_empty() or not desc.get("problems", []).is_empty() or desc.legs.is_empty():
			printerr("Invalid body ", id, ": ", desc.get("problems", []))
			quit(1)
			return
		var morph = Morph.analyse(desc)
		desc.analysis = {"mass": morph.mass, "legs": morph.legs, "hip_height": morph.hip_height, "plan": morph.plan}
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("Cannot open output ", args[0])
		quit(1)
		return
	file.store_string(JSON.stringify(json_value(descriptions), "", true, true))
	file.close()
	print("Exported ", descriptions.size(), " bodies")
	quit()
