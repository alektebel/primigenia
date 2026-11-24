extends SceneTree
# Polish evidence for the nest overlay and the end of the lineage (software GL under xvfb), lean version of parts_nest_evidence.gd:
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 1024x600 --path godot \
#     --script res://game/tests/journal_nest_evidence.gd -- <out dir> <lang> [suffix]
# Checks: the nest panel stacks above the stats column (no overlap), Esc with nothing in hand leaves the editor, the keyboard
# focus starts on the part chooser, and the end-of-lineage overlay uses the game font and strings.
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out := ""
var failures := 0

func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out.path_join(name + ".jpg"), 0.9)
	print("wrote ", name)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame

func editor_layer() -> CanvasLayer:
	for c in current_scene.get_children():
		if c is CanvasLayer and c.layer == 30 and not c.is_queued_for_deletion():
			return c
	return null

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	var lang := a[1] if a.size() > 1 else "es"
	var suffix := a[2] if a.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 1500
	game.settings.language = lang
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	var stage = game.stage
	var sui = island.stage_ui
	stage.debug_now({"op": 6, "a": 2})
	var n: Vector2 = stage.world.get_setup().nest
	stage.debug_now({"op": 1, "id": 0, "x": n.x + 2.0, "z": n.y + 2.0})
	stage.step_ticks(3)
	await settle(8)
	sui.open_nest_editor()
	await settle(30)
	var ed = editor_layer().get_child(0)
	ed.set_lang(lang)
	await settle(10)
	var panel: Control = ed.nest_panel
	var card: Control = ed.right_card
	var pr := panel.get_global_rect()
	var cr := card.get_global_rect()
	check(pr.end.y <= cr.position.y + 0.5, "the nest panel ends above the stats column (%.0f <= %.0f)" % [pr.end.y, cr.position.y])
	check(not pr.intersects(cr), "the nest panel and the stats column do not overlap")
	var vp := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	check(vp.encloses(pr) and vp.encloses(cr), "both stay inside the canvas %s" % vp.size)
	check(ed.get_viewport().gui_get_focus_owner() == ed.nest_choice, "keyboard focus starts on the part chooser")
	await shot("nest_stack" + suffix)
	ed._nest_try(0)
	await settle(10)
	await shot("nest_pending" + suffix)
	check(ed.nest_apply_button.get_global_rect().end.x <= vp.end.x and ed.nest_evolve_button.get_global_rect().end.x <= vp.end.x, "long button labels wrap inside the column")
	# cancel: Esc with nothing in hand leaves the editor like the Menu button
	var left := [false]
	ed.exit_requested.connect(func() -> void: left[0] = true)
	await key(KEY_ESCAPE)
	check(left[0], "Esc in the nest editor cancels and leaves")
	await settle(10)
	check(not sui.ui.paused, "Esc did not open the game menu behind the overlay")
	# the end of the lineage
	sui._lineage_ended()
	await settle(10)
	await shot("lineage_end" + suffix)
	var btn: Button = null
	for c in sui._lineage_end.find_children("*", "Button", true, false):
		btn = c
	check(btn != null and btn.has_focus(), "the return button has keyboard focus")
	check(btn.get_theme_font("font").resource_path.contains("Alegreya"), "the overlay uses the game font")
	print("journal nest evidence: %d failures" % failures)
	quit(1 if failures else 0)
