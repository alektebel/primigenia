extends SceneTree
# make godot-nest-family-test: the siblings at the nest and the edit prompt at the nest (docs/briefs/verb-target.md, parts 2 and 3).
#   family: 2-4 siblings of the player's genome with a colour variation, near the nest, wandering, greeting, not C entities.
#   nest edit: "E: Edit creature" only inside the nest radius, the editor shows only found parts (plus the basics) with their DNA
#   cost, a found part gives a hint back to the nest, and leaving the editor returns to the nest at the same time of day.
# With an output dir argument it also writes the evidence JPGs (software GL under xvfb).
# godot --headless --fixed-fps 60 --path godot --script res://game/tests/nest_family_test.gd -- [<output dir>]

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
	game.settings.edit_anywhere = false          # the nest rule is what is under test
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
	stage.timescale = 1.0 if out_dir == "" else 4.0
	stage.debug_now({"op": 6, "a": 2})        # the wild stands still: nothing interrupts the nest tests

	# --- pure parts -------------------------------------------------------------------------------------------------------
	var n_seed: int = Family.count_for(1)
	check(n_seed >= 2 and n_seed <= 4, "the family size is 2..4 from the seed (%d)" % n_seed)
	var counts := {}
	for s in 40:
		counts[Family.count_for(s)] = true
	check(counts.has(2) and counts.has(3) and counts.has(4) and counts.size() == 3, "across seeds the family is 2, 3 or 4")
	var g0: Dictionary = island._genome
	var v1: Dictionary = Family.varied_genome(g0, 1, 0)
	var v2: Dictionary = Family.varied_genome(g0, 1, 1)
	check(v1.skin.cA != g0.skin.cA or v1.skin.cB != g0.skin.cB, "a sibling's colours differ from the player's")
	check(v1.skin.cA != v2.skin.cA, "two siblings differ from each other")
	check(v1.nodes == g0.nodes and v1.parts == g0.parts, "the body (nodes and parts) is the player's, only the colour varies")
	check(Family.varied_genome(g0, 1, 0).skin == v1.skin, "the variation is deterministic")
	var sp1: Array = Family.spots(1, Vector2.ZERO, 3, func(_p): return true)
	check(sp1.size() == 3 and sp1.all(func(p): return p.length() >= 3.4 and p.length() <= Family.HOME_RADIUS + 0.01), "the spots lie 3.5..%d m from the nest" % int(Family.HOME_RADIUS))

	# --- 2. family in the scene ---------------------------------------------------------------------------------------
	var fam = island.family
	check(fam != null and fam.sibs.size() >= 2 and fam.sibs.size() <= 4, "the island has a family of %d siblings" % (fam.sibs.size() if fam != null else 0))
	check(fam.sibs.size() == n_seed or fam.sibs.size() >= 2, "...as many as the spots allowed (%d of %d)" % [fam.sibs.size(), n_seed])
	var nest: Vector2 = island._nest
	var near := true
	for s in fam.sibs:
		if s.pos.distance_to(nest) > Family.HOME_RADIUS + 0.5:
			near = false
	check(near, "every sibling starts inside the wander circle round the nest")
	check(fam.sibs.all(func(s): return s.host.uses_module and s.host.body != null), "each sibling has a real creature body")
	var ents0: int = stage.cur.entities.size()
	check(not island.hosts.has(100000) and not island.hosts.has(100001), "they are not C entities (hosts hold only C ids)")
	var p0 := []
	for s in fam.sibs:
		p0.append(s.pos)
	await ticks(150)
	var moved := 0.0
	for i in fam.sibs.size():
		moved += (fam.sibs[i].pos as Vector2).distance_to(p0[i])
	check(moved > 1.0, "they wander: %.1f m of movement over 15 s of game time" % moved)
	var stay := true
	for s in fam.sibs:
		if s.pos.distance_to(nest) > Family.HOME_RADIUS + 6.0:
			stay = false
	check(stay, "they stay near the nest")
	check(stage.cur.entities.size() == ents0, "the C world's entity list is unchanged (%d)" % ents0)
	var greeted: bool = fam.sibs.any(func(s): return s.greet > 0.0 or s.greet_cool > 0.0)
	check(greeted, "they greet the player when he is near the nest")
	await shot("family_at_nest")
	# they follow a little: the player walks 18 m off, a sibling that is willing comes after
	var pl: Dictionary = me()
	var far_d := 20.0
	stage.debug_now({"op": 1, "id": 0, "x": float(pl.x) + far_d, "z": float(pl.z)})
	var d_before := 0.0
	for s in fam.sibs:
		d_before += s.pos.distance_to(Vector2(float(pl.x) + far_d, float(pl.z)))
	await ticks(300)
	var d_after := 0.0
	for s in fam.sibs:
		d_after += s.pos.distance_to(Vector2(float(me().x), float(me().z)))
	check(d_after < d_before - 2.0, "the siblings drift toward the player 20 m away (%.0f -> %.0f m summed)" % [d_before, d_after])
	stage.debug_now({"op": 1, "id": 0, "x": nest.x, "z": nest.y})
	await ticks(5)

	# --- 3. the prompt shows only at the nest --------------------------------------------------------------------------------
	await settle(30)
	check(ui.nest_prompt.shown(), "at the nest the prompt shows: '%s'" % ui.nest_prompt.line())
	await shot("nest_prompt")
	stage.debug_now({"op": 1, "id": 0, "x": nest.x + 40.0, "z": nest.y})
	await ticks(8)
	await settle(40)
	check(not ui.nest_prompt.shown() and not ui.loadout_available, "40 m away the prompt is gone")
	ui._unhandled_input(key(KEY_E))
	await settle(5)
	check(editor() == null, "E away from the nest opens nothing")
	stage.debug_now({"op": 1, "id": 0, "x": nest.x + 3.0, "z": nest.y})
	await ticks(8)
	await settle(40)
	check(ui.nest_prompt.shown(), "back at the nest the prompt returns")

	# --- the found-part hint ------------------------------------------------------------------------------------------------
	var rows0: Array = stage.cur.parts.discovered
	var ids0 := rows0.map(func(r): return str(r.id))
	check(ids0.has("pico") and ids0.has("pata") and ids0.has("ojo"), "the basics are available from the start (%s)" % str(ids0))
	check(not ids0.has("fire_gland"), "the fire gland is not found yet")
	var day0: Dictionary = stage.cur.day.duplicate()
	var grc: int = stage.debug_now({"op": 8, "id": 0, "a": _part_index("fire_gland")})
	print("   grant fire_gland: index %d rc %d" % [_part_index("fire_gland"), grc])
	await ticks(2)
	var found_row := {}
	for r in stage.cur.parts.discovered:
		if str(r.id) == "fire_gland":
			found_row = r
	check(not found_row.is_empty(), "a found part joins the list of discovered parts")
	sui._social_event({"type": 21, "target": int(found_row.index), "move": 0, "value": 0, "x": 0.0, "z": 0.0}, stage.cur)
	check(ui.nest_prompt.new_parts.has("fire gland"), "a found part is named under the prompt (%s)" % ui.nest_prompt.extra())
	await settle(30)
	await shot("nest_prompt_new_part")

	# --- E opens the editor with the found parts -----------------------------------------------------------------------------
	ui._unhandled_input(key(KEY_E))
	await settle(12)
	var ed = editor()
	if not check(ed != null, "E at the nest opens the editor"):
		return finish()
	check(stage.paused, "the world is paused while the editor is open")
	var shown := []
	for id in ed.palette_buttons:
		if ed.palette_buttons[id].visible:
			shown.append(id)
	shown.sort()
	var want := []
	for r in stage.cur.parts.discovered:
		want.append(str(r.id))
	want.sort()
	check(shown == want, "the palette shows exactly the found parts and the basics: %s" % str(shown))
	check(shown.has("fire_gland") and shown.has("pico") and not shown.has("wing_vane"), "the new part is there, an unfound one is not")
	check(ed.nest_cost != null and ed.dna_label.text.contains(str(int(stage.cur.social.dna_balance))), "the DNA balance is on the editor (%s)" % ed.dna_label.text)
	await shot("editor_found_parts")
	var dna0 := int(stage.cur.social.dna_balance)
	ed.model.add_part("fire_gland")
	ed._nest_refresh()
	await settle(3)
	var cost_text: String = ed.nest_cost.text
	check(cost_text.contains("DNA") or cost_text.contains("ADN"), "adding the part shows its DNA cost: '%s'" % cost_text)
	print("   dna balance %d, evolve button disabled: %s" % [dna0, str(ed.nest_evolve_button.disabled)])
	check(ed.nest_evolve_button.disabled == (int(cost_text.get_slice(":", 1).strip_edges().get_slice(" ", 0)) > dna0), "Evolve is enabled only when the DNA balance covers the cost")
	# leave without evolving: the same time of day, back at the nest
	ed.exit_requested.emit()
	await settle(30)
	await ticks(3)
	check(editor() == null and not stage.paused, "leaving the editor returns to the game, running")
	var day1: Dictionary = stage.cur.day
	check(absf(float(day1.hour) - float(day0.hour)) < (0.5 if out_dir == "" else 2.0), "the same time of day (hour %.2f -> %.2f)" % [float(day0.hour), float(day1.hour)])
	var d := Vector2(float(me().x) - nest.x, float(me().z) - nest.y).length()
	check(d < 13.0, "back at the nest (%.1f m)" % d)
	finish()

## The C part table puts wing_vane and fire_gland last (world.h: "47 + wing_vane, fire_gland"); the manifest order is not the C one.
func _part_index(id: String) -> int:
	return 48 if id == "fire_gland" else (47 if id == "wing_vane" else -1)
