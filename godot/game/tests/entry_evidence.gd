extends SceneTree
## Evidence of the island entry loading screen: frames of the screen at several progress values, and the fade into the island.
##   make godot-entry-evidence   (software GL under xvfb; out=<dir>)
var out_dir := "res://../docs/evidence/godot/eat-loading"

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	_run.call_deferred()

func _shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var path := (ProjectSettings.globalize_path(out_dir) if out_dir.begins_with("res://") else out_dir).path_join(name + ".png")
	img.save_png(path)
	print("wrote ", path, " ", img.get_size())

func _veil_shots() -> void:
	var Veil = load("res://game/loading/entry_veil.gd")
	var v = Veil.new()
	root.add_child(v)
	v.begin("evidence")
	var plan := ["environment", "terrain_meshes", "water", "rivers", "grass", "camera", "stage_setup", "props_flora", "stage_reset", "nav_warm", "creatures", "ui_and_rest"]
	v.set_plan(plan)
	var stops := {"terrain_meshes": "loading_a", "props_flora": "loading_b", "nav_warm": "loading_c"}
	for p in plan:
		v.phase_done(p)
		if stops.has(p):
			for i in 90:
				await process_frame        # the bar eases to the real value and creeps a little into the next phase
			await _shot(stops[p])
	v.queue_free()
	await process_frame

func _run() -> void:
	await process_frame
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.language = "es"
	game.settings.grass = 3000
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	await _veil_shots()
	var menu = load("res://game/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	current_scene = menu
	for i in 5:
		await process_frame
	menu.play_button.emit_signal("pressed")
	var n0: int = game.entry_log.size()
	var guard := 0
	while game.entry_log.size() == n0 and guard < 40000:
		guard += 1
		await process_frame
	for i in 90:
		await process_frame
	var isl = current_scene
	if isl != null and isl.has_method("player_sample"):
		var p: Vector3 = isl.player_sample().pos
		isl.chase.distance = 7.0
	for i in 30:
		await process_frame
	await _shot("island_nest")
	quit()
