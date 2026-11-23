extends SceneTree
# A65 play tests on the real island and the real C world (headless is fine, no rendering needed):
#   1. clicking a carcass with no verb armed walks the creature there and eats it (the order verb R sends)
#   2. a non-edible living creature clicked with no verb armed is only selected (today's behaviour)
#   3. the peck from range gallops at the target, closes the distance and hits; inside the run-up it is the standing bite
#      nice -n 10 timeout 900 godot --headless --path godot --script res://game/tests/click_peck_test.gd
const TerrainCache := preload("res://game/island/terrain_cache.gd")

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

func st() -> Dictionary:
	return stage.world.state()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func dist(a: int, b: int) -> float:
	var ea: Dictionary = st().entities[a]
	var eb: Dictionary = st().entities[b]
	return Vector2(float(ea.x) - float(eb.x), float(ea.z) - float(eb.z)).length()

func nearest_rondo(skip: Array) -> int:
	for i in range(1, st().entities.size()):
		var e: Dictionary = st().entities[i]
		var sp: Dictionary = sui.species[int(e.species)] if int(e.species) >= 0 and int(e.species) < sui.species.size() else {}
		if str(sp.get("name", "")) == "Rondo" and not bool(e.dead) and not skip.has(i):
			return i
	return -1

func place_near(id: int, d: float) -> bool:
	var w: Dictionary = st().entities[id]
	for ang in [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]:
		if stage.debug_now({"op": 1, "id": 0, "x": float(w.x) + cos(ang) * d, "z": float(w.z) + sin(ang) * d}) == 0:
			stage.step_ticks(2)
			return true
	return false

func _run() -> void:
	root.size = Vector2i(960, 540)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 500
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(20)
	island = current_scene
	stage = game.stage
	sui = island.stage_ui
	stage.paused = true
	stage.debug_now({"op": 6, "a": 3})            # god mode, wild AI off
	var prof: Dictionary = stage.world.get_setup().player
	print("loadout ", st().loadout.slots, " diet ", st().social.diet)
	check(7 in st().loadout.slots, "starter B has the peck in its loadout")

	print("-- 1. click a carcass: walk there and eat")
	var dead_id := nearest_rondo([])
	check(dead_id > 0, "a Rondo exists")
	stage.debug_now({"op": 3, "id": dead_id})
	stage.step_ticks(3)
	check(bool(st().entities[dead_id].dead) and int(st().entities[dead_id].meat) > 0, "the Rondo is a carcass with meat (%s)" % str(st().entities[dead_id].get("meat")))
	var d0 := 9.0
	place_near(dead_id, d0)
	var meat0: int = int(st().entities[dead_id].meat)
	var food0: float = float(st().social.food)
	check(not sui.verb_is_armed(), "no verb armed")
	check(sui._edible(dead_id), "the carcass is edible for this diet")
	sui._on_clicked(dead_id, Vector3.ZERO)
	stage.paused = false
	var closest := d0
	var ate := false
	for t in 500:
		await process_frame
		closest = minf(closest, dist(0, dead_id))
		if int(st().entities[dead_id].meat) < meat0 or float(st().social.food) > food0 + 0.01:
			ate = true
			break
	check(closest < d0 - 4.0, "the click made the creature walk to the carcass (closest %.1f m from %.1f)" % [closest, d0])
	check(ate, "and it ate (meat %d -> %d, food %.1f -> %.1f)" % [meat0, int(st().entities[dead_id].meat), food0, float(st().social.food)])
	stage.paused = true
	stage.debug_now({"op": 6, "a": 3})

	print("-- 2. a living, non-edible creature is only selected")
	var live := nearest_rondo([dead_id])
	check(live > 0 and not sui._edible(live), "a living Rondo is not edible")
	sui._pending_social = null
	var order_before := int(st().order.verb)
	sui.selected_id = -1
	sui._on_clicked(live, Vector3.ZERO)
	check(sui.selected_id == live or not sui.ui.selected.is_empty(), "it is selected")
	check(int(st().order.verb) == order_before and sui._pending_social == null, "no order was sent")

	print("-- 3. the galloping peck")
	place_near(live, 4.0)
	stage.debug_now({"op": 4, "id": live, "x": 1000.0, "z": -1.0})
	var hp0: float = float(st().entities[live].hp)
	var gap0 := dist(0, live)
	sui.selected_id = live
	sui._pending_attack = {"target": live, "move": 7, "chain": false, "tick": int(st().tick)}
	stage.paused = false
	var saw_peck := false
	var saw_close := 1e9
	var hit := false
	for t in 400:
		await process_frame
		var f: Array = st().combat.fighters
		if f.size() > 0 and int(f[0].move) == 7:
			saw_peck = true
		saw_close = minf(saw_close, dist(0, live))
		if float(st().entities[live].hp) < hp0:
			hit = true
			break
	check(saw_peck, "C ran the peck move on the player")
	check(hit, "the peck hit (wild hp %.1f -> %.1f)" % [hp0, float(st().entities[live].hp)])
	check(hp0 - float(st().entities[live].hp) >= 8.0, "a strong opener (%.1f damage)" % (hp0 - float(st().entities[live].hp)))
	check(saw_close < gap0 - 0.5, "the gallop closed the distance (%.1f m -> %.1f m)" % [gap0, saw_close])
	sui._pending_attack = null
	stage.paused = true

	print("-- 3b. inside the run-up it is the standing bite")
	await settle(10)
	var fresh := nearest_rondo([dead_id, live])      # a Rondo nobody has fought: a fresh fight, no peck cooldown or standing order
	check(fresh > 0, "a third Rondo exists")
	stage.paused = true
	place_near(fresh, 1.6)
	var used_bite := false
	var used_peck := false
	sui.selected_id = fresh
	sui._pending_attack = {"target": fresh, "move": 7, "chain": false, "tick": int(st().tick)}
	stage.paused = false
	for t in 200:
		await process_frame
		var f2: Array = st().combat.fighters
		if f2.size() > 0:
			if int(f2[0].move) == 0:
				used_bite = true
			if int(f2[0].move) == 7:
				used_peck = true
		if used_bite or used_peck:
			break
	check(used_bite and not used_peck, "a peck order at 1.6 m starts the bite (bite %s, peck %s)" % [used_bite, used_peck])
	print("click/peck tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
