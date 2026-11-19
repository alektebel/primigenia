extends SceneTree
## Realism pilot, studio evidence: the same look live while editing. Opens the studio, then edits the model like a
## player would (paint, add a venom part, remove the legs) and grabs the stage after each edit, with build times.
## LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
##   --script res://creature/tools/studio_live.gd -- <out_dir> [tag]   (CPORE_REALISM=0 for the old look)

const Studio := preload("res://studio/ui/studio.gd")

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp"
	var tag: String = args[1] if args.size() > 1 else "after"
	DirAccess.make_dir_recursive_absolute(out)
	var ui = Studio.new()
	root.add_child(ui)
	await _frames(90)
	# A player-painted creature: their colours must survive the realism layer.
	ui.model.set_skin("cA", "#2f6fd0")
	ui.model.set_skin("cB", "#f0a020")
	ui.model.set_skin("cC", "#f4f0d8")
	ui.model.set_skin("pat", 1)
	await _frames(12)
	await _shot(out, "studio_1_player_painted_" + tag, ui)
	ui.set_mode("paint")
	await _frames(8)
	await _shot(out, "studio_2_paint_controls_" + tag, ui)
	ui.model.set_skin("pat", 2)
	ui.model.set_skin("ros", 1)
	ui.model.set_skin("cs", .9)
	ui.model.set_skin("ps", 1.4)
	await _frames(12)
	await _shot(out, "studio_3_rosettes_countershade_" + tag, ui)
	ui.set_mode("build")
	ui.model.new_from_seed("Merodeador")
	var d: Dictionary = ui.model.get_doc()
	for i in 6:
		ui.model.add_part("pata", .2 + i * .1, 2.0)
	await _frames(12)
	await _shot(out, "studio_4_many_legs_actuation_" + tag, ui)
	var t0 := Time.get_ticks_usec()
	for i in 10:
		ui.model.set_skin("ps", 1.0 + i * .05)
		await process_frame
	print("10 live pattern-scale edits incl. frames: %.1f ms each (software GL)" % ((Time.get_ticks_usec() - t0) / 10000.0))
	quit()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(out: String, name: String, _ui) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_jpg(out.path_join(name + ".jpg"), .9)
