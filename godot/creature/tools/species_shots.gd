extends SceneTree
## Species body evidence: godot --path godot --script res://creature/tools/species_shots.gd -- <outdir> [files...]
## One chase and one close JPG per genome file (res:// paths), plus a lineup of all of them side by side with the player.
func _initialize() -> void:
	_run()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://species"
	var files: Array = Array(a.slice(1)) if a.size() > 1 else ["rondo", "zanco", "espinodo", "garfio", "merodeador"]
	DirAccess.make_dir_recursive_absolute(out)
	var stage := CreaturePreview.new(self, Vector2i(960, 540))
	for id in files:
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))
		var c := Creature.new()
		stage.world_root.add_child(c)
		var r := c.load_genome(g)
		if not r["ok"]:
			push_error("%s: %s" % [id, r["error"]])
			continue
		var mid: Vector3 = CreaturePreview.mid_target(c)
		var len: float = c.rest[0].distance_to(c.rest[Creature.NS - 1])
		var head: Vector3 = c.rest[Creature.NS - 1] + Vector3(0, c.ground_offset, 0)
		print(id, " len ", snappedf(len, .01), " aabb ", c.rest_aabb())
		var views := {"chase": [mid + Vector3(0, .2, 0), .75, .2, len * 1.9 + 3.0, 42.0], "side": [mid, 1.5708, .06, len * 1.3 + 1.0, 42.0], "close": [head - Vector3(0, .1, 0), .6, .1, maxf(len * .42, 1.8), 36.0]}
		for i in 3:
			await process_frame
		for v in views:
			var p: Array = views[v]
			stage.orbit(p[0], p[1], p[2], p[3], p[4])
			var img: Image = await stage.capture(self, 4)
			img.save_jpg("%s/%s_%s.jpg" % [out, id, v], .9)
		c.queue_free()
	quit()
