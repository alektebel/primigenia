extends SceneTree
## Visual scorecard, creature close-ups (docs/briefs/look-score.md): the four realism-pilot creatures, chase and close views, at four
## times of day. Lighting follows the game's day_night.gd (same sun/ambient/exposure numbers) on the CreaturePreview stage.
##   godot --rendering-driver opengl3 --fixed-fps 30 --path godot --script res://creature/tools/look_score_creatures.gd -- <out dir>
## Writes <out>/creature_<tod>_<id>_<view>.jpg
const Creatures := preload("res://creature/tools/realism_creatures.gd")
const DayNight := preload("res://game/island/day_night.gd")
const LIGHT := {"dawn": 0.50, "midday": 1.0, "dusk": 0.50, "night": 0.0}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	var out := a[0] if a.size() > 0 else "/tmp/look-score"
	DirAccess.make_dir_recursive_absolute(out)
	var stage := CreaturePreview.new(self, Vector2i(1280, 720))
	var env: Environment = (stage.world_root.get_child(0) as WorldEnvironment).environment
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var dn := DayNight.new()
	dn.env = env
	dn.sun = stage.sun
	for id in Creatures.ids():
		var c := Creature.new()
		stage.world_root.add_child(c)
		var r := c.load_genome(Creatures.genome(id))
		if not r["ok"]:
			push_error("%s: %s" % [id, r["error"]])
			continue
		var mid: Vector3 = CreaturePreview.mid_target(c)
		var len: float = c.rest[0].distance_to(c.rest[Creature.NS - 1])
		var head: Vector3 = c.rest[Creature.NS - 1] + Vector3(0, c.ground_offset, 0)
		var views := {"chase": [mid + Vector3(0, .2, 0), .75, .2, len * 1.25, 42.0], "close": [head - Vector3(0, .1, 0), .6, .1, maxf(len * .42, 1.8), 36.0]}
		for i in 3:
			await process_frame
		for tod in LIGHT:
			dn.k = LIGHT[tod]
			dn.update_now()
			for v in views:
				var p: Array = views[v]
				stage.orbit(p[0], p[1], p[2], p[3], p[4])
				var img: Image = await stage.capture(self, 4)
				img.convert(Image.FORMAT_RGB8)
				var nm := "%s/creature_%s_%s_%s" % [out, tod, id, v]
				img.save_jpg(nm + ".jpg", .85)
				# Mask: pixels that change when the creature is hidden (the preview floor and sky are not the game's, so metrics use the creature only).
				c.visible = false
				var bg: Image = await stage.capture(self, 2)
				bg.convert(Image.FORMAT_RGB8)
				c.visible = true
				var px := img.get_data()
				var pb := bg.get_data()
				var md := PackedByteArray()
				md.resize(img.get_width() * img.get_height())
				for i in md.size():
					var d := absi(px[i * 3] - pb[i * 3]) + absi(px[i * 3 + 1] - pb[i * 3 + 1]) + absi(px[i * 3 + 2] - pb[i * 3 + 2])
					md[i] = 255 if d > 12 else 0
				var mask := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_L8, md)
				mask.save_png(nm + "_mask.png")
		c.queue_free()
	print("creature shots done ", out)
	quit()
