extends SceneTree
## Starter candidates, stills at midday and dusk: side, 3/4 front, close-up per body (software GL only).
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://devtools/zoo/starter_shots.gd -- <out dir> [ids]
const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")

func _initialize() -> void:
	_run.call_deferred()

func _light(stage: CreaturePreview, mode: String) -> void:
	var we: WorldEnvironment = null
	for n in stage.world_root.get_children():
		if n is WorldEnvironment:
			we = n
	var sky: ProceduralSkyMaterial = we.environment.sky.sky_material
	if mode == "midday":
		sky.sky_top_color = Color("#6f97d6")
		sky.sky_horizon_color = Color("#bcd0e6")
		sky.ground_horizon_color = Color("#a9a592")
		stage.sun.light_color = Color("#fff4e2")
		stage.sun.light_energy = 2.4
		we.environment.ambient_light_energy = .9
		we.environment.tonemap_exposure = 1.05
		stage.sun.look_at_from_position(Vector3(-.25, 1.0, -.35).normalized() * 50, Vector3.ZERO)
	else:
		sky.sky_top_color = Color("#5d6aa8")
		sky.sky_horizon_color = Color("#f0a470")
		sky.ground_horizon_color = Color("#a8704f")
		stage.sun.light_color = Color("#ffab6a")
		stage.sun.light_energy = 2.0
		we.environment.ambient_light_energy = .6
		we.environment.tonemap_exposure = 1.2
		stage.sun.look_at_from_position(Vector3(-.9, .22, -.5).normalized() * 50, Vector3.ZERO)

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "user://starter"
	var ids: Array = Array(a[1].split(",")) if a.size() > 1 else Genomes.STARTER_SET
	DirAccess.make_dir_recursive_absolute(out)
	var stage := CreaturePreview.new(self, Vector2i(960, 540))
	for id in ids:
		var c := Creature.new()
		stage.world_root.add_child(c)
		var r := c.load_genome(Genomes.genome(id))
		if not r["ok"]:
			push_error("%s: %s" % [id, r["error"]])
			continue
		for i in 3:
			await process_frame
		var mid: Vector3 = CreaturePreview.mid_target(c)
		var len: float = c.rest[0].distance_to(c.rest[Creature.NS - 1])
		var head: Vector3 = c.rest[Creature.NS - 1] + Vector3(0, c.ground_offset, 0)
		var views := {"side": [mid, 1.5708, .06, len * 2.1, 38.0], "front34": [mid, 0.6, .12, len * 2.1, 38.0], "close": [head, 0.7, .1, maxf(len * .55, .9), 34.0]}
		for mode in ["midday", "dusk"]:
			_light(stage, mode)
			for v in views:
				var p: Array = views[v]
				stage.orbit(p[0], p[1], p[2], p[3], p[4])
				var img: Image = await stage.capture(self, 4)
				img.save_jpg("%s/%s_%s_%s.jpg" % [out, id, v, mode], .9)
		c.queue_free()
		await process_frame
	print("starter shots done ", out)
	quit()
