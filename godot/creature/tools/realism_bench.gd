extends SceneTree
## Build cost and (software-GL, ratio only) frame cost per pilot creature.
## CPORE_REALISM=0 for the old look. LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot \
##   --script res://creature/tools/realism_bench.gd
const Creatures := preload("res://creature/tools/realism_creatures.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var stage := CreaturePreview.new(self, Vector2i(640, 360))
	print("realism=%s" % CreatureMaterials.realism)
	for id in Creatures.ids():
		var g := Creatures.genome(id)
		var cold := 0.0
		var ms: Array = []
		for i in 6:
			var c := Creature.new()
			var t0 := Time.get_ticks_usec()
			c.load_genome(g)
			var dt := (Time.get_ticks_usec() - t0) / 1000.0
			if i == 0:
				cold = dt
			else:
				ms.append(dt)
			if i < 5:
				c.free()
			else:
				stage.world_root.add_child(c)
		ms.sort()
		var c: Creature = stage.world_root.get_child(stage.world_root.get_child_count() - 1)
		stage.orbit(CreaturePreview.mid_target(c), .75, .2, 9.0, 42.0)
		for i in 5:
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in 25:
			await RenderingServer.frame_post_draw
		var fr := (Time.get_ticks_usec() - t0) / 25000.0
		print("%-7s build cold %.1f ms, warm median %.1f ms; frame %.1f ms (software GL, ratio only)" % [id, cold, ms[2], fr])
		c.queue_free()
		await process_frame
	quit()
