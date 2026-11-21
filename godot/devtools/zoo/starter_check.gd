extends SceneTree
## Starter candidates: DNA cost, size, mass and part-fit of each (and today's hatchling), headless.
##   godot --headless --path godot --script res://devtools/zoo/starter_check.gd
const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")
const Morph := preload("res://locomotion/loco_morphology.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var bad := 0
	for id in Genomes.STARTER_SET:
		var g: Dictionary = Genomes.genome(id)
		var c := Creature.new()
		root.add_child(c)
		var r := c.load_genome(g)
		if not r["ok"]:
			print("%s INVALID: %s" % [id, r["error"]])
			bad += 1
			continue
		var m := CreatureFit.measure(c)
		var s: Dictionary = m["summary"]
		var mm = Morph.analyse(Adapter.loco_describe(c, 1.0))
		var fails: int = s["floating"] + s["teeth_out"] + s["eyes_bad"] + s["limbs_bad"]
		bad += 1 if fails > 0 else 0
		print("%s dna %d parts %d | len %.2f hip %.2f mass %.1f plan %s | fit fails %d (float %d teeth %d eyes %d limbs %d) horn %.2f/%.2f bulge %.2f" % [id, c.stats["dna"], g.parts.size(), mm.body_length, mm.hip_height, mm.mass, mm.plan, fails, s["floating"], s["teeth_out"], s["eyes_bad"], s["limbs_bad"], s["worst_horn_ratio"], s["worst_horn_base"], s["worst_emerge"]])
		c.queue_free()
		await process_frame
	quit(0 if bad == 0 else 1)
