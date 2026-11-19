extends SceneTree
# Parts / nest / eggs evidence on the real island (software GL under xvfb), through the real C world and UI.
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
#     --script res://game/tests/parts_nest_evidence.gd -- <out dir> [width height lang]
# Checklist (docs/PARTS-NEST-REPORT.md): discovery + journal, the nest 12 m rule, the free creator and Evolve,
# inline refusal, the changed valley with its cousin, eggs and the end of the lineage.
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out := ""
var game
var island
var stage
var checks := 0
var failures := 0

func check(ok: bool, what: String) -> void:
	checks += 1
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
	root.get_texture().get_image().save_jpg(out.path_join(name + ".jpg"), 0.9)
	print("wrote ", name)

func key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.physical_keycode = code
		e.keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await process_frame

func parts() -> Dictionary:
	return stage.world.state().parts

func tp(x: float, z: float) -> int:
	return stage.debug_now({"op": 1, "id": 0, "x": x, "z": z})

func nest() -> Vector2:
	return stage.world.get_setup().nest

func editor_layer() -> CanvasLayer:
	for c in island.get_children():
		if c is CanvasLayer and c.layer == 30 and not c.is_queued_for_deletion():
			return c
	return null

func close_editor() -> void:
	var l := editor_layer()
	if l != null and l.get_child_count() > 0:
		l.get_child(0).exit_requested.emit()
	await settle(6)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var size := Vector2i(1280, 720)
	if args.size() >= 3:
		size = Vector2i(int(args[1]), int(args[2]))
	root.size = size
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	if args.size() >= 4:
		game.settings.lang = args[3]
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	island = current_scene
	stage = game.stage
	var sui = island.stage_ui
	stage.debug_now({"op": 6, "a": 2})    # freeze the wild: nothing wanders into the shots
	check(int(parts().eggs) == 3 and parts().discovered.size() == 3, "start: 3 eggs, only the three starter parts")
	check(not bool(parts().tiers_enabled), "tier forms are off by default")
	check(island.save_game() == "", "a save exists to return to")

	# 1. the creator at the start: only pico, pata, ojo; locked parts absent
	var n := nest()
	tp(n.x + 2.0, n.y + 2.0)
	stage.step_ticks(3)
	await settle(8)
	await shot("01_world_at_nest")
	sui.open_nest_editor()
	await settle(30)
	var ed = editor_layer().get_child(0)
	check(ed.nest_rows.size() == 3, "creator lists the 3 starter parts only")
	check(not ed.palette_buttons["pua"].visible, "a locked part is absent from the palette")
	await shot("02_creator_start_locked")
	await close_editor()
	check(editor_layer() == null, "creator closes with Cancel")

	# 2. outside the 12 m rule
	tp(n.x + 16.0, n.y)
	stage.step_ticks(3)
	await settle(8)
	sui.open_nest_editor()
	await settle(20)
	check(editor_layer() == null, "outside 12 m the editor does not open")
	await shot("03_outside_nest_refused")

	# 3. surface finds: inspect every fossil / old carcass with the real order
	var nodes: Array = parts().nodes
	check(nodes.size() > 0, "surface nodes exist (%d)" % nodes.size())
	var first := true
	for node in nodes:
		check(tp(node.x, node.z) == 0, "teleport next to node %d" % node.id)
		stage.step_ticks(2)
		await settle(6)
		if first:
			await shot("04_fossil_marker_before")
		stage.queue_order({"verb": 16, "target": int(node.id)})    # what the E key sends (part_nodes.gd)
		stage.step_ticks(12)
		await settle(6)
		if first:
			await shot("05_inspecting_ring")
		stage.step_ticks(10)
		await settle(10)
		if first:
			await shot("06_discovery_whisper")
			check(stage.world.command("inspect #%d" % node.id) < 0, "an exhausted node cannot be inspected twice")
			check(bool(parts().nodes[0].inspected), "the first node is exhausted")
			first = false
	var after: Dictionary = parts()
	check(after.discovered.size() > 3, "finds discovered new parts (%d known)" % after.discovered.size())
	check(int(after.clues) >= nodes.size() and int(after.recipes) >= 1, "clues counted (%d) and recipes (%d)" % [after.clues, after.recipes])
	await key(KEY_J)
	await settle(20)
	await shot("07_journal")
	await key(KEY_J)
	await settle(10)

	# 4. back at the nest: discovered parts priced, a pending sketch, a refusal, then a valid Evolve
	tp(n.x + 2.0, n.y + 2.0)
	stage.step_ticks(3)
	await settle(8)
	sui.open_nest_editor()
	await settle(30)
	ed = editor_layer().get_child(0)
	var dna0: int = int(stage.world.state().social.dna_balance)
	var total0: int = int(stage.world.state().social.dna_total)
	await shot("08_creator_discovered_priced")
	var buy := ""
	for row in ed.nest_rows:
		if not row.owned and int(row.cost) <= dna0 and int(row.cost) > 0:
			buy = row.id
			break
	check(buy != "", "an affordable discovered part exists (%s)" % buy)
	ed.model.add_part(buy)
	await settle(6)
	check(ed.nest_pending_cost() > 0, "the sketch shows a pending cost (%d)" % ed.nest_pending_cost())
	check(int(stage.world.state().social.dna_balance) == dna0, "trying a part is free: balance unchanged")
	await shot("09_sketch_pending_cost")
	var doc: Dictionary = ed.model.get_doc()
	doc.skin.cA = "#d8452e"
	var gens0: int = JSON.parse_string(stage.world.lineage()).generations.size()
	ed.model.import_doc(doc)
	ed.model.add_part(buy)
	ed.model.remove_part(ed.model.doc.parts.size() - 1)
	# an unaffordable Evolve shows its inline error and changes nothing
	ed.nest_plan[buy] = {"level": 5, "tier": 0}
	ed._nest_refresh()
	check(ed.nest_evolve_button.disabled, "an unaffordable Evolve is disabled (%d pending of %d)" % [ed.nest_pending_cost(), int(stage.world.state().social.dna_balance)])
	ed._nest_confirm()
	await settle(6)
	check(JSON.parse_string(stage.world.lineage()).generations.size() == gens0, "a refused Evolve changes nothing")
	await shot("10_evolve_refused_inline")
	for row in ed.nest_rows:
		ed.nest_plan.erase(row.id)
	ed._nest_refresh()
	ed._nest_confirm()
	await settle(40)
	var gens1: int = JSON.parse_string(stage.world.lineage()).generations.size()
	check(gens1 == gens0 + 1, "Evolve starts exactly one generation (%d -> %d)" % [gens0, gens1])
	check(int(stage.world.state().social.dna_total) >= total0, "lifetime DNA never decreases by spending")
	check(int(stage.world.state().social.dna_balance) < dna0, "DNA balance went down on Evolve")
	await settle(30)
	await shot("11_valley_after_evolve")
	await key(KEY_T)
	await settle(30)
	await shot("12_family_tree_ledger")
	await key(KEY_T)
	await settle(10)

	# 5. eggs: die with Garfios on top of the player
	check(island.save_game() == "", "save before the eggs run out")
	stage.debug_now({"op": 6, "a": 0})
	var guard := 0
	var shown_first := false
	while int(parts().eggs) > 0 and guard < 600:
		guard += 1
		var live := 0
		var p: Dictionary = stage.cur.entities[0]
		for i in range(1, stage.cur.entities.size()):
			var e: Dictionary = stage.cur.entities[i]
			if int(e.species) == 3 and not bool(e.dead) and Vector2(e.x - p.x, e.z - p.z).length() < 20.0:
				live += 1
		if live == 0 and float(p.hp) > 0.0:
			stage.debug_now({"op": 2, "a": 3, "x": p.x + 3.0, "z": p.z + 3.0})
		stage.step_ticks(10)
		if not shown_first and int(parts().eggs) == 2:
			shown_first = true
			await settle(10)
			check(int(parts().hatchling_ticks) > 0, "first death: hatchling form (%d ticks left)" % int(parts().hatchling_ticks))
			await shot("13_first_death_two_eggs")
		await process_frame
	await settle(30)
	check(bool(parts().lost) and int(parts().eggs) == 0, "third death: no eggs, lost")
	await shot("14_lineage_ends")
	check(sui._lineage_end != null, "the end-of-lineage moment is shown")
	var err: String = sui.return_to_last_save()
	check(err == "", "returns to the last save without wiping (%s)" % err)
	await settle(40)
	check(not bool(parts().lost) and int(parts().eggs) >= 1, "after returning: not lost, eggs restored from the save (%d)" % int(parts().eggs))
	await shot("15_back_at_last_save")
	print("parts nest evidence: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
