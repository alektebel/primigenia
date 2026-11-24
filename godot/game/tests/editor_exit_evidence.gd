extends SceneTree
# A73 evidence + test: the nest editor's Done button, the discard panel and the hatch sequence on the real island.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Family := preload("res://game/island/family.gd")

class ErrorLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])

var out_dir := ""
var checks := 0
var failures := 0
var log := ErrorLog.new()
var game
var island
var sui
var ui
var stage

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	OS.add_logger(log)
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	if out_dir == "":
		return
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out_dir.path_join(name + ".jpg"), 0.9)
	print("wrote ", name)

func ticks(n: int) -> void:
	var t0: int = stage.cur.tick
	var guard := 0
	while stage.cur.tick - t0 < n and guard < 20000:
		await process_frame
		guard += 1

func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e

func me() -> Dictionary:
	return stage.cur.entities[0]

func editor():
	for c in island.get_children():
		if c is CanvasLayer:
			for k in c.get_children():
				if "nest_world" in k and k.nest_world != null:
					return k
	return null

func finish() -> void:
	check(log.errors.is_empty(), "no errors during the run (%d: %s)" % [log.errors.size(), str(log.errors.slice(0, 3))])
	OS.remove_logger(log)
	print("nest family test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	game.settings["onboarding"] = 0x1ff
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1), "user://terrain-secrets")
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new(), "user://terrain-secrets")
	game.set_island(entry)
	game.goto_island()
	var t_wait := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_wait < 150000:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null and not current_scene._building:
			break
	await settle(30)
	island = current_scene
	if island == null or island.get("stage_ui") == null:
		check(false, "the island did not open")
		return finish()
	sui = island.stage_ui
	ui = sui.ui
	stage = game.stage
	stage.debug_now({"op": 6, "a": 2})        # the wild stands still
	# walk-free: the player already stands at the nest at the start; open the editor the way E does
	sui.open_nest_editor()
	await settle(20)
	var ed = editor()
	check(ed != null and stage.paused, "the nest editor opened and the sim waits")
	await shot("01_editor_done_button")
	check(ed.done_button.visible and ed.done_button.size.y >= 48 and ed.done_button.get_global_rect().end.x > 1180, "the Done button is a large bottom-right control")
	# a part on the player's own body: default size in proportion
	var n0: int = ed.model.doc.parts.size()
	var ix: int = ed.model.add_part("ojo", .9, 1.0)
	await settle(10)
	check(ed.model.doc.parts[ix].size < 1.0, "a new eye on this body starts small (%.2f)" % ed.model.doc.parts[ix].size)
	await shot("02_new_part_default_size")
	ed.request_cancel()
	await settle(6)
	check(ed.confirm_open(), "Cancel with unsaved changes asks in game")
	await shot("03_discard_panel")
	ed._unhandled_key_input(key(KEY_ESCAPE))
	await settle(3)
	check(not ed.confirm_open(), "Esc keeps editing")
	ed.model.undo()
	# a free repaint: Done applies, the editor closes, the new body hatches
	var doc: Dictionary = ed.model.get_doc()
	doc.skin.cA = "#2f7ad6"
	doc.skin.cB = "#10253f"
	ed.model.import_doc(doc)
	await settle(6)
	var tick0: int = int(stage.cur.tick)
	ed._unhandled_key_input(key(KEY_ENTER))
	await settle(2)
	var seq = sui.hatch
	check(seq != null and is_instance_valid(seq), "leaving with changes starts the hatch sequence")
	check(stage.paused, "the sim waits while it plays (stage.paused)")
	var marks := [0.35, 1.0, 1.7, 2.0, 2.3, 2.6, 3.0, 3.4]
	var mi := 0
	var guard := 0
	while seq != null and is_instance_valid(seq) and not seq.done and guard < 4000:
		await process_frame
		guard += 1
		if mi < marks.size() and seq.t >= marks[mi]:
			await shot("hatch_%02d_t%03d" % [mi, int(marks[mi] * 100)])
			mi += 1
	check(mi >= 6, "frames captured along the sequence (%d)" % mi)
	await settle(3)
	check(not stage.paused and sui.hatch == null, "control returns: the sim runs again")
	check(int(stage.cur.tick) - tick0 < 10, "the sim did not advance during the sequence (%d ticks)" % (int(stage.cur.tick) - tick0))
	await shot("hatch_99_after")
	check(island.chase_enabled, "the chase camera is back")
	# skip with a key
	sui.open_nest_editor()
	await settle(20)
	ed = editor()
	var doc2: Dictionary = ed.model.get_doc()
	doc2.skin.cA = "#d6a02f"
	ed.model.import_doc(doc2)
	await settle(4)
	ed.request_done()
	await settle(2)
	seq = sui.hatch
	check(seq != null, "the second edit hatches too")
	await create_timer(0.4).timeout
	var t_skip := Time.get_ticks_msec()
	Input.parse_input_event(key(KEY_SPACE))
	await settle(3)
	check(sui.hatch == null and not stage.paused, "any key skips the sequence")
	# no changes, no sequence
	sui.open_nest_editor()
	await settle(20)
	ed = editor()
	ed.request_done()
	await settle(6)
	check(sui.hatch == null and not stage.paused and editor() == null, "leaving without changes: no sequence, straight back")
	finish()
