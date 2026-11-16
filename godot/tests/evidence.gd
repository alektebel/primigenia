extends SceneTree
## Renders evidence screenshots (software GL): see docs/godot/UI.md.
## xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://tests/evidence.gd -- <outdir>

const GameUI := preload("res://ui/game_ui.gd")
const Mock := preload("res://ui/mock_source.gd")
const AudioManager := preload("res://audio/audio_manager.gd")

func _initialize() -> void:
	root.size = Vector2i(1280, 720)
	var out := "res://../docs/evidence/godot/ui"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	call_deferred("_run", out)

func _shot(path: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	print("wrote ", path)

func _run(out: String) -> void:
	# Neutral warm-grey background standing in for the 3D stage.
	var bg := ColorRect.new()
	bg.color = Color("6f8a6b")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 0
	layer.add_child(bg)
	root.add_child(layer)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(0, 1.5, 4)
	var am := AudioManager.new("user://evidence_settings.cfg")
	root.add_child(am)
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	ui.set_camera(cam)
	ui.bind_audio(am)
	ui.set_player("Pico", 74, 100, 36, 50)
	ui.show_message("Rondo is watching you")
	ui.show_message("A wild Garfio approaches", "bad")
	ui.show_dna(10)
	ui.show_damage(Vector2(640, 330), 17)
	ui.show_damage(Vector2(560, 400), 9, true)
	ui.hud.set_target({})
	ui.flash("guard")
	await _shot(out + "/hud.png")
	ui.set_mode("befriend")
	var info := Mock.creature(1)
	info.relationship = 1
	info.temperament = 1
	info.resolved = 2
	info.world_pos = Vector3(0.6, 1.2, -2)
	ui.select(info, true, Vector2(500, 380))
	ui.set_windup(0.6, "Rondo winds up")
	await _shot(out + "/radial_card.png")
	ui.radial.close()
	ui.set_paused(true)
	await _shot(out + "/pause.png")
	quit()
