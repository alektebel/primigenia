extends SceneTree
# make godot-social-test: the C2 social loop through the real island, UI and C world (software GL under xvfb).
#   select first (a click opens the card and the radial, orders nothing), then choose: Befriend skills on keys 1-4,
#   Observe, Intimidate, Eat on a carcass; Esc deselects. With an output dir argument it also writes the evidence strip.
# xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/social_flow.gd -- <output dir or "">

const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out_dir := ""
var checks := 0
var failures := 0

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	_run.call_deferred()

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func shot(name: String) -> void:
	if out_dir == "":
		return
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)

func ticks(game, n: int) -> void:
	var t0: int = game.stage.cur.tick
	var guard := 0
	while game.stage.cur.tick - t0 < n and guard < 20000:
		await process_frame
		guard += 1

func key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
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
	var island = current_scene
	var sui = island.stage_ui
	var ui = sui.ui
	var stage = game.stage
	check(stage.cur.entities.size() >= 12, "the island holds Garfio and the three herds (%d entities)" % stage.cur.entities.size())
	var species_seen := {}
	for i in range(1, stage.cur.entities.size()):
		species_seen[int(stage.cur.entities[i].species)] = true
	check(species_seen.size() == 6, "all six species are present (C2 secrets added Acechalunas and Babosa)")
	# freeze the wild so the test is about the verbs, and bring a Rondo next to the player
	stage.debug_now({"op": 6, "a": 2})
	var rondo := -1
	for i in range(1, stage.cur.entities.size()):
		if int(stage.cur.entities[i].species) == 0:
			rondo = i
			break
	var p: Dictionary = stage.cur.entities[0]
	var placed := false
	for dx in [5.0, -5.0, 6.0, -6.0]:
		if stage.debug_now({"op": 1, "id": rondo, "x": float(p.x) + dx, "z": float(p.z)}) == 0:
			placed = true
			break
	check(placed, "a Rondo was brought within reach")
	await ticks(game, 3)
	# 1. select first: nothing is ordered
	var orders_before: int = sui.attack_orders.size()
	game.creature_clicked.emit(rondo, Vector3.ZERO)
	await settle(3)
	check(ui.selected.get("id", -1) == rondo and ui.note.visible and ui.ring.visible and ui.mode == &"", "a click selects: the field note and the mode ring open, no mode yet")
	await ticks(game, 20)
	check(sui.attack_orders.size() == orders_before and int(stage.cur.order.verb) <= 1 and stage.cur.active < 0, "selecting orders nothing (no approach, no attack)")
	await shot("1_select_card_radial.png")
	# 2. choose a mode: the hotbar changes, still nothing is ordered
	ui.ring.choose_mode(&"befriend")
	await settle(3)
	check(ui.mode == &"befriend" and ui.abilities.map(func(a): return a.id) == ["sing", "dance", "charm", "pose"], "Befriend puts sing, dance, charm and pose on keys 1-4")
	await ticks(game, 10)
	check(sui.attack_orders.size() == orders_before, "choosing a mode orders nothing")
	# 3. key 1 = sing: the C order runs; trust goes up; the card shows it
	var key := key_event(KEY_1)
	ui._unhandled_input(key)
	await ticks(game, 6)
	check(int(stage.cur.social.action.verb) == 11 or int(stage.cur.entities[rondo].trust) > 0, "key 1 starts the C sing order")
	await shot("2_befriend_beat_ring.png")
	await ticks(game, 40)
	var trust: int = stage.cur.entities[rondo].trust
	check(trust > 0, "sing raised trust (%d)" % trust)
	var gm = island.ground_marks
	check(absf(gm.value_target - float(trust) / 100.0) < 0.011 and gm.sel_mode == &"befriend", "the ground ring's arc is the trust (%.2f for trust %d)" % [gm.value_target, trust])
	check(gm.sel_mark.param("ring2") != null and float(gm.sel_mark.param("ring2")) > 0.0, "the beat ring closes in on the trust ring")
	check(int(stage.cur.social.dna_total) > 0, "meters: DNA arrived (exploration and first sight)")
	# a gift, G
	var g := key_event(KEY_G)
	var before_items: int = int(stage.cur.social.items[1])
	ui._unhandled_input(g)
	await ticks(game, 40)
	check(int(stage.cur.social.items[1]) == before_items - 1 and int(stage.cur.entities[rondo].trust) > trust, "G gives a fruit to the selected creature")
	await shot("3_trust_and_dna.png")
	# 4. observe: from far enough that it does not notice
	stage.debug_now({"op": 1, "id": rondo, "x": float(p.x) + 16.0, "z": float(p.z)})
	await ticks(game, 3)
	ui.ring.choose_mode(&"observe")
	ui._unhandled_input(key)
	await ticks(game, 30)
	check(float(stage.cur.social.observe_ticks) > 0.0, "observe progress runs")
	check(gm.sel_mode == &"observe" and gm.value_target > 0.0, "the observe ring's dots follow observe_ticks (%.2f)" % gm.value_target)
	await shot("4_observe_ring.png")
	await ticks(game, 150)
	check(int(stage.cur.social.species[0].observed) == 3 and int(stage.cur.social.learned) != 0, "three clues complete the chain and teach a move")
	# 5. Esc deselects
	var esc := key_event(KEY_ESCAPE)
	ui._unhandled_input(esc)
	check(ui.selected.is_empty() and not ui.paused, "Esc deselects (and does not pause)")
	# 6. intimidate and eat
	var garfio := 1
	game.creature_clicked.emit(garfio, Vector3.ZERO)
	await settle(2)
	ui.ring.choose_mode(&"intimidate")
	check(ui.abilities.map(func(a): return a.id) == ["roar", "display"], "Intimidate: roar and display")
	ui.ring.close()
	var victim := rondo + 1
	stage.debug_now({"op": 3, "id": victim})
	await ticks(game, 3)
	stage.debug_now({"op": 1, "id": victim, "x": float(p.x) + 5.0, "z": float(p.z) + 3.0})
	game.creature_clicked.emit(victim, Vector3.ZERO)
	await settle(3)
	check(ui.ring.carcass and ui.ring.mode_at(1) == &"eat" and ui.selected.get("carcass_meat", -1) == 4, "a carcass selects with the Eat ring and 4 bites")
	ui.ring.choose_mode(&"eat")
	await settle(2)
	check(ui.mode == &"eat" and gm.sel_mode == &"eat" and float(gm.sel_mark.param("lit")) == 4.0 and float(gm.sel_mark.param("count")) == 4.0, "the carcass ring is cut into 4 bites, all lit")
	await shot("5_carcass_eat_radial.png")
	var food0: int = int(stage.cur.social.food)
	ui._unhandled_input(key)
	await ticks(game, 70)
	check(int(stage.cur.entities[victim].meat) < 4 and int(stage.cur.social.food) > food0, "eating depletes the carcass and fills the food meter")
	check(island.hosts[victim].scale.x < island.hosts[victim].get_meta("base_scale", 1.0), "the carcass shrinks as it is eaten")
	await shot("6_eating.png")
	print("social flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
