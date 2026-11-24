extends SceneTree
## Part-fit check (docs/briefs/creature-fit.md): 4 pilot creatures + 10 fixed-seed random valid genomes.
##   godot --headless --path godot --script res://creature/tests/test_fit.gd [-- <report.json>]
## Prints one line per creature and the failing parts; exit 1 when a creature has a floating part, a tooth outside the
## mouth, an eye outside its socket depth range or a limb root that sticks out of the body.
const Creatures := preload("res://creature/tools/realism_creatures.gd")
const SEEDS := [101, 102, 103, 104, 105, 106, 107, 108, 109, 110]

var failures := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var report := {}
	var list: Array = []
	for id in Creatures.ids():
		list.append([id, Creatures.genome(id)])
	for s in SEEDS:
		list.append(["seed%d" % s, CreatureFit.random_genome(s)])
	print("%-8s %5s %5s | %-9s %-9s | %-9s | %-12s | %s" % ["creature", "parts", "float", "teeth out", "worst r", "eyes bad", "limbs bad/bulge", "horn len/base"])
	for e in list:
		var c := Creature.new()
		root.add_child(c)
		var r := c.load_genome(e[1])
		if not r["ok"]:
			print("%-8s INVALID genome: %s" % [e[0], r["error"]])
			c.queue_free()
			continue
		var m := CreatureFit.measure(c)
		var s: Dictionary = m["summary"]
		print("%-8s %5d %5d | %3d/%-5d %-9.2f | %2d/%-6d | %2d/%-2d %-7.2f | %.2f/%.2f" % [e[0], s["parts"], s["floating"], s["teeth_out"], s["teeth"], s["worst_tooth_r"], s["eyes_bad"], s["eyes"], s["limbs_bad"], s["limbs"], s["worst_emerge"], s["worst_horn_ratio"], s["worst_horn_base"]])
		for p in m["parts"]:
			if p["floating"]:
				print("    FLOATING %s side %d gap %.3f (tol %.3f)" % [p["type"], p["side"], p["gap"], p["tol"]])
		for ey in m["eyes"]:
			if not ey["ok"]:
				print("    EYE %s sink %.2f of radius (want %.2f..%.2f)" % [ey["type"], ey["sink"], CreatureFit.EYE_SINK_MIN, CreatureFit.EYE_SINK_MAX])
		for l in m["limbs"]:
			if not l["ok"]:
				print("    LIMB %s side %d gap %.3f bulge %.2f" % [l["type"], l["side"], l["gap"], l["emerge"]])
		if s["floating"] + s["teeth_out"] + s["eyes_bad"] + s["limbs_bad"] > 0:
			failures += 1
		report[e[0]] = m
		c.queue_free()
		await process_frame
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		var f := FileAccess.open(a[0], FileAccess.WRITE)
		f.store_string(JSON.stringify(report, "  "))
	print("part-fit: %d of %d creatures fail" % [failures, list.size()])
	quit(0 if failures == 0 else 1)
