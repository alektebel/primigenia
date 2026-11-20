extends SceneTree
## Measures a genome's body with the locomotion adapter and the gaits it reaches at the play speeds.
##   godot --headless --path godot --script res://game/tests/hatchling_measure.gd -- [genome=res://game/data/hatchling.json]
const Morph := preload("res://locomotion/loco_morphology.gd")
const Gait := preload("res://locomotion/loco_gait.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const SPEEDS := {"roam 4.0": 4.0, "jog 5.2": 5.2, "sprint 8.84": 8.84}

func _initialize() -> void:
	var path := "res://game/data/hatchling.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("genome="): path = a.substr(7)
	var g = JSON.parse_string(FileAccess.get_file_as_string(path))
	var c = load("res://creature/creature.gd").new()
	root.add_child(c)
	var res = c.load_genome(g)
	if not res.ok:
		print("genome failed: ", res)
		quit(1)
		return
	var desc := Adapter.loco_describe(c, 1.0)
	var m = Morph.analyse(desc)
	var box: AABB = c.rest_aabb()
	print("%s: aabb %s  body_length %.2f m  hip_height %.2f m  mass %.1f kg  plan %s graviportal %s" % [g.name, box.size, m.body_length, m.hip_height, m.mass, m.plan, m.graviportal])
	var ProfileS := load("res://game/stage/profile.gd")
	print("C radius_cm %d (0 = default 60)" % ProfileS.body_radius_cm(g.nodes))
	var prev: StringName = &"walk"
	for k in SPEEDS:
		var v: float = SPEEDS[k]
		var fr := Gait.froude(v, m.hip_height)
		var gait := Gait.select(m, &"walk", fr)
		print("  %-12s Fr %.1f  gait %s" % [k, fr, gait])
	print("  v at Fr 0.5 %.2f, Fr 2.5 %.2f, Fr 1.8 %.2f m/s" % [sqrt(0.5 * 9.81 * m.hip_height), sqrt(2.5 * 9.81 * m.hip_height), sqrt(1.8 * 9.81 * m.hip_height)])
	quit()
