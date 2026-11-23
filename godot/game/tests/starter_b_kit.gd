extends SceneTree
# Starter B kit (A62): the shipped starter, trimmed like a new game, has the starting loadout bite, pounce, spit, roar and C accepts
# an attack order for each of them (pounce and roar need legs / a throat part; spit needs the beak).
#   godot --headless --fixed-fps 60 --path godot --script res://game/tests/starter_b_kit.gd
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const MOVES := {"bite": 0, "spit": 3, "pounce": 8, "roar": 10}
const V_ATTACK := 5
var game
var stage
var checks := 0
var failures := 0
var _target := -1
var _move := -1
var _go := false

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)

func _initialize() -> void:
	_run.call_deferred()

func _provider() -> Dictionary:
	if _go:
		return {"verb": V_ATTACK, "target": _target, "move": _move, "dir": 0, "run": 0}
	return {"verb": 1}

func _run() -> void:
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 500
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null and not current_scene._building:
			break
	for i in 30:
		await process_frame
	stage = game.stage
	stage.step_ticks(2)
	var st: Dictionary = stage.world.state()
	check(st.loadout.slots.slice(0, 4) == [0, 8, 3, 10], "starter B loadout is bite, pounce, spit, roar (%s)" % str(st.loadout.slots))
	var rondo := -1
	for i in range(1, st.entities.size()):
		if not bool(st.entities[i].dead):
			rondo = i
			break
	check(rondo > 0, "a creature to order the attacks on")
	stage.paused = true
	stage.debug_now({"op": 6, "a": 3})
	stage.input_provider = Callable(self, "_provider")
	_target = rondo
	for name in ["pounce", "roar", "spit", "bite"]:
		_move = MOVES[name]
		var s: Dictionary = stage.world.state()
		var w: Dictionary = s.entities[rondo]
		var rc = stage.debug_now({"op": 1, "id": 0, "x": float(w.x) + 2.5, "z": float(w.z)})
		stage.step_ticks(3)
		_go = true
		var seen := false
		var err := 0
		for k in 90:
			stage.step_ticks(1)
			var cs: Dictionary = stage.world.state()
			err = int(cs.get("error", 0))
			if cs.combat.fighters.size() > 0 and int(cs.combat.fighters[0].get("move", -1)) == _move:
				seen = true
				break
		_go = false
		check(seen, "C accepted the %s order and the fighter is in the move (error %d, teleport rc %d)" % [name, err, rc])
		for k in 400:
			stage.step_ticks(1)
			if int(stage.world.state().active) < 0:
				break
		stage.debug_now({"op": 4, "id": rondo, "x": 100.0, "z": -1.0})
	print("starter B kit: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
