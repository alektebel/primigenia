extends SceneTree
# C2 moves / recipes / meters evidence on the real island (software GL under xvfb), through the real C world and UI.
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
#     --script res://game/tests/moves_recipes_evidence.gd -- <out dir> [lang]
# Shots: quill volley, roar fear, pounce, calcium filling from bones and spent on bone spines,
# recipe states in the journal, rock-armour stones eaten and the mineral meter.
const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out := ""
var game
var island
var stage
var sui
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

func st() -> Dictionary:
	return stage.world.state()

func tp(id: int, x: float, z: float) -> int:
	return stage.debug_now({"op": 1, "id": id, "x": x, "z": z})

func tick(n: int, every: int = 0) -> void:
	for i in n:
		stage.step_ticks(1)
		if every > 0 and i % every == 0:
			await process_frame

func fight_move(target: int, move: int) -> void:
	sui._pending_attack = {"target": target, "move": move}

var kit_setup: Dictionary = {}
var skip_fights := false

func fresh(slots: Array) -> void:
	# a new world with the same C2 kit; the loadout is set at the nest, then the player walks to dry ground
	check(stage.reset(kit_setup.duplicate(true)) == 0, "fresh world")
	stage.debug_now({"op": 6, "a": 3})
	stage.paused = true
	var n: Vector2 = stage.world.get_setup().nest
	tp(0, n.x + 2.0, n.y + 2.0)
	stage.step_ticks(2)
	for i in slots.size():
		sui.assign_loadout(i, slots[i])
		stage.step_ticks(2)
	await settle(6)

func spawn_near(species: int, dist: float) -> int:
	# the island's own wild of that species (it has a body on screen): walk the player to `dist` metres from it
	var best := -1
	var bd := 1e9
	var p: Dictionary = st().entities[0]
	for i in range(1, st().entities.size()):
		var e: Dictionary = st().entities[i]
		if int(e.species) != species or bool(e.dead):
			continue
		var d := Vector2(float(e.x) - float(p.x), float(e.z) - float(p.z)).length()
		if d < bd:
			bd = d
			best = i
	var w: Dictionary = st().entities[best]
	var rc := -1
	for ang in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
		rc = tp(0, float(w.x) + cos(ang) * dist, float(w.z) + sin(ang) * dist)
		if rc == 0:
			break
	print("wild #", best, " species ", species, " at ", w.x, ",", w.z, " player placed rc ", rc)
	stage.step_ticks(2)
	await settle(6)
	return best

func clean_up(id: int) -> void:
	# finish the fight: the wild is left with one hit point, the player walks in and claws it
	if st().active >= 0:
		stage.debug_now({"op": 4, "id": id, "x": 1.0, "z": -1.0})
		for i in 300:
			var p: Dictionary = st().entities[0]
			var e: Dictionary = st().entities[id]
			if Vector2(float(p.x) - float(e.x), float(p.z) - float(e.z)).length() > 2.6:
				sui._pending_attack = null
				stage.queue_order({"verb": 4, "target": id})
			else:
				fight_move(id, 6)
			stage.step_ticks(1)
			if st().active < 0:
				break
	stage.step_ticks(4)
	check(st().active < 0, "the fight ended")
	stage.debug_now({"op": 4, "id": 0, "x": -1.0, "z": -1.0})

# one fight: order a move and shoot at its active frame, its recovery and `later` ticks after the active frame
func fight_shots(tag: String, target: int, move: int, later: int = 6) -> void:
	fight_move(target, move)
	var seen_active := -1
	var shots := 0
	for i in 120:
		stage.step_ticks(1)
		if st().active < 0 and seen_active >= 0:
			break
		if st().active < 0:
			continue
		var f: Dictionary = st().combat.fighters[0]
		if int(f.move) == move:
			sui._pending_attack = null
		if int(f.move) == move and int(f.phase) == 2 and seen_active < 0:
			seen_active = i
			await settle(2)
			await shot("%s_a_active" % tag)
		elif seen_active >= 0 and i == seen_active + later and shots == 0:
			shots = 1
			await settle(2)
			await shot("%s_b_after" % tag)
			break
	check(seen_active >= 0, "%s: the move reached its active frame" % tag)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	if args.size() >= 2:
		game.settings.lang = args[1]
	skip_fights = args.size() >= 3 and args[2] == "recipes"
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
	island = current_scene
	stage = game.stage
	sui = island.stage_ui
	# a carnivore with every C2 part: claw, beak, legs, quills, throat, heavy legs, rock, back spines
	var setup: Dictionary = stage.world.get_setup()
	var prof: Dictionary = setup.player
	prof.extra = [2, 2, 3, 3, 3, 2, 2, 2]
	prof.carnivore = 1
	prof.mouth = 2
	prof.hp = 120.0
	prof.stamina = 120.0
	kit_setup = setup.duplicate(true)
	check(stage.reset(setup) == 0, "reset with the C2 kit")
	await settle(10)
	var n: Vector2 = stage.world.get_setup().nest
	stage.debug_now({"op": 6, "a": 3})    # god mode, wild AI off: they only fight when ordered to
	stage.paused = true
	var nodes: Array = st().parts.nodes
	check(nodes.size() >= 2, "surface nodes exist (%d)" % nodes.size())
	# the journal before any clue: the recipe is unknown
	await open_journal("10_journal_recipe_unknown")
	# at the nest: a kit of new moves in the hotbar
	tp(0, n.x + 2.0, n.y + 2.0)
	stage.step_ticks(2)
	for pair in [[0, 9], [1, 8], [2, 10], [3, 6]]:
		sui.assign_loadout(pair[0], pair[1])
		stage.step_ticks(2)
	check(str(st().loadout.slots) == "[9, 8, 10, 6]", "loadout is quill, pounce, roar, claw: %s" % str(st().loadout.slots))
	# a dry spot: next to the first surface node
	var dry := Vector2(nodes[0].x, nodes[0].z)
	tp(0, dry.x + 2.0, dry.y)
	stage.step_ticks(2)
	await settle(6)
	var rid := 0
	if not skip_fights:
		rid = await spawn_near(0, 9.0)
		sui.select_id(rid)
		await settle(8)
		await shot("01_hotbar_c2_kit_target")
		await fight_shots("02_quill_volley", rid, 9, 8)
		await fresh([9, 8, 10, 6])
		dry = Vector2(st().parts.nodes[0].x, st().parts.nodes[0].z)
		tp(0, dry.x + 2.0, dry.y)
		stage.step_ticks(2)
		rid = await spawn_near(1, 6.0)
		sui.select_id(rid)
		await fight_shots("03_roar_fear", rid, 10, 8)
		await fresh([9, 8, 10, 6])
		tp(0, dry.x + 2.0, dry.y)
		stage.step_ticks(2)
		rid = await spawn_near(0, 7.0)
		sui.select_id(rid)
		await fight_shots("04_pounce", rid, 8, 4)
		await fresh([9, 8, 10, 6])
	await fresh([9, 8, 10, 6])
	# recipes: inspect the spined fossil, the quill-wounded carcass
	for i in 2:
		print("tp rc ", tp(0, nodes[i].x + 1.5, nodes[i].z), " active ", st().active)
		stage.step_ticks(2)
		stage.queue_order({"verb": 16, "target": int(nodes[i].id)})    # what the E key sends
		stage.step_ticks(22)
		await settle(4)
		check(st().recipes.bone_spines.state == ("hinted" if i == 0 else "known"), "recipe state after clue %d: %s" % [i, st().recipes.bone_spines.state])
		await shot("11_recipe_%s" % st().recipes.bone_spines.state)
		await open_journal("12_journal_recipe_%s" % st().recipes.bone_spines.state)
	# eat the old carcass: calcium fills 20 a bite
	tp(0, nodes[1].x + 1.0, nodes[1].z)
	stage.step_ticks(2)
	stage.queue_order({"verb": 15, "target": int(nodes[1].id)})
	for k in 5:
		stage.step_ticks(1)
		await settle(2)
	await shot("20_calcium_eaten_once")
	check(int(st().recipes.meters.calcium.value) == 20, "calcium 20 after one bite (%d)" % int(st().recipes.meters.calcium.value))
	stage.queue_order({"verb": 15, "target": int(nodes[1].id)})
	stage.step_ticks(6)
	await settle(4)
	await shot("21_calcium_eaten_twice")
	check(int(st().recipes.meters.calcium.value) == 40, "calcium 40 after two bites")
	# spend it: the recipe makes the bone-spine volley learnable at the nest
	tp(0, n.x + 2.0, n.y + 2.0)
	stage.step_ticks(2)
	sui.assign_loadout(3, 13)
	stage.step_ticks(2)
	check(int(st().loadout.slots[3]) == 13, "spine volley in the signature slot: %s" % str(st().loadout.slots))
	tp(0, dry.x + 2.0, dry.y)
	stage.step_ticks(2)
	rid = await spawn_near(0, 8.0)
	sui.select_id(rid)
	await settle(8)
	await shot("22_calcium_before_spines")
	stage.debug_now({"op": 4, "id": rid, "x": -1.0, "z": 0.5})    # a winded wild cannot dodge: the volley lands
	await fight_shots("23_bone_spines", rid, 13, 6)
	await settle(6)
	await shot("24_calcium_after_spines")
	check(int(st().recipes.meters.calcium.value) == 20, "firing spent 20 calcium (%d)" % int(st().recipes.meters.calcium.value))
	for i in 150:
		if st().recipes.bone_spines.state == "mastered":
			break
		if st().active >= 0 and int(st().recipes.meters.calcium.value) >= 20 and int(st().combat.fighters[0].cooldowns[13]) == 0 and int(st().combat.fighters[0].move) != 13:
			fight_move(rid, 13)
		elif st().active >= 0 and int(st().combat.fighters[0].move) == 13:
			sui._pending_attack = null
		stage.step_ticks(1)
	print("recipe after the volley: ", st().recipes.bone_spines.state, " calcium ", st().recipes.meters.calcium.value)
	await open_journal("13_journal_recipe_after_use")
	# rock armour: stones on the alpine slopes
	await fresh([9, 8, 10, 6])
	var stones: Array = st().recipes.stones
	check(stones.size() > 0, "stone nodes exist (%d)" % stones.size())
	if stones.size() > 0:
		var s0: Dictionary = stones[0]
		tp(0, s0.x + 1.0, s0.z)
		stage.step_ticks(2)
		await settle(6)
		await shot("30_stone_node")
		stage.queue_order({"verb": 15, "target": int(s0.id)})
		for k in 4:
			stage.step_ticks(1)
			await settle(2)
		await shot("31_stone_chewing")
		stage.step_ticks(3)
		await settle(4)
		check(int(st().recipes.meters.mineral.value) == 25, "mineral 25 after one stone (%d)" % int(st().recipes.meters.mineral.value))
		stage.queue_order({"verb": 15, "target": int(s0.id)})
		stage.step_ticks(6)
		await settle(4)
		await shot("32_mineral_meter_50")
		var speed0: float = float(st().entities[0].get("speed", 0.0))
		print("mineral ", st().recipes.meters.mineral.value, " stones left ", st().recipes.stones[0].units)
	print("moves evidence: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func open_journal(name: String) -> void:
	var ui = sui.ui
	ui.open_view("journal")
	await settle(10)
	ui.journal.set_tab(3)
	ui.journal.page = 0
	ui.journal._request_art()
	await settle(30)
	await shot(name)
	ui.close_view()
	await settle(6)
