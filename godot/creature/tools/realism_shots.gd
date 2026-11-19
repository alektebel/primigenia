extends SceneTree
## Realism pilot evidence: godot --path godot --script res://creature/tools/realism_shots.gd -- <outdir> [tag] [ids]
## Env: CPORE_REALISM=0 renders the pre-pilot look. One JPG per creature and view (chase, close).
const Creatures := preload("res://creature/tools/realism_creatures.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://realism"
	var tag := a[1] if a.size() > 1 else "after"
	var ids: Array = Array(a[2].split(",")) if a.size() > 2 else Creatures.ids()
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(960, 540)
	var stage := CreaturePreview.new(self, size)
	for id in ids:
		var c := Creature.new()
		stage.world_root.add_child(c)
		var r := c.load_genome(Creatures.genome(id))
		if not r["ok"]:
			push_error("%s: %s" % [id, r["error"]])
			continue
		var mid: Vector3 = CreaturePreview.mid_target(c)
		var len: float = c.rest[0].distance_to(c.rest[Creature.NS - 1])
		var head: Vector3 = c.rest[Creature.NS - 1] + Vector3(0, c.ground_offset, 0)
		var views := {"chase": [mid + Vector3(0, .2, 0), .75, .2, len * 1.25, 42.0], "side": [mid + Vector3(0, .1, 0), 1.5708, .06, len * 1.05, 42.0], "legs": [Vector3(mid.x, mid.y * .45, mid.z), 1.5708, .02, len * .62, 40.0], "close": [head - Vector3(0, .1, 0), .6, .1, maxf(len * .42, 1.8), 36.0]}
		if tag == "bent":
			for l in c.legs:
				l.solve_local(l.home + Vector3(0, .0, 0) + Vector3(0, l.upper_length * .55, 0))
		for i in 3:
			await process_frame
		for e in c.parts:
			if e["type"] in ["ojo", "tallo"]:
				var ep: Vector3 = (e["node"] as Node3D).global_position
				views["eye"] = [ep, 1.45, .35, 1.0, 32.0]
				break
		for v in views:
			var p: Array = views[v]
			stage.orbit(p[0], p[1], p[2], p[3], p[4])
			var img: Image = await stage.capture(self, 4)
			img.save_jpg("%s/%s_%s_%s.jpg" % [out, id, v, tag], .9)
		c.queue_free()
	print("shots done ", out)
	quit()
