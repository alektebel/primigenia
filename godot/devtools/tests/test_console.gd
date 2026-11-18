extends RefCounted
# Step 7: the console registry and the creature-stage commands on a StageWorld without the island.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Registry := preload("res://devtools/console/registry.gd")
const Commands := preload("res://devtools/console/commands_creature.gd")

func _world() -> Node:
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.flat_height = 2.0
	sw.reset(setup)
	return sw

func _registry(sw):
	var r = Registry.new()
	r.stage_provider = func(): return sw
	Commands.register_all(r)
	return r

func run(t) -> void:
	_loadout(t)
	_run_rest(t)

# A21: `loadout <slot> <move>` is an order to C: validated there, in the input log, replayed to the same hash.
func _loadout(t) -> void:
	var sw = _world()
	var r = _registry(sw)
	t.check(r.execute("help").out.contains("loadout"), "help lists loadout")
	var h0: String = sw.world.hash()
	for line in ["loadout", "loadout 1", "loadout 0 bite", "loadout 5 bite", "loadout 1 dance", "loadout 1 guard", "loadout x bite"]:
		var res: Dictionary = r.execute(line)
		t.check(not res.ok and res.error != "", "'%s' fails with a sentence (%s)" % [line, res.error])
	t.check(r.execute("loadout 1 dodge").error.contains("unknown_move"), "dodge is not slottable: unknown_move")
	t.eq(sw.world.hash(), h0, "failed loadout commands change nothing")
	t.eq(sw.cur.loadout.slots, [0, 1, 3, 4], "the default loadout is bite, charge, spit, tail_strike")
	t.check(sw.cur.loadout.can_edit, "the player starts at the nest: the loadout can be edited")
	t.check(r.execute("loadout 1 tail_strike").ok, "loadout 1 tail_strike")
	sw.step_ticks(1)
	t.eq(sw.cur.loadout.slots, [4, 1, 3, -1], "the move went to slot 1 and left slot 4")
	t.check(r.execute("loadout 2 none").ok and r.execute("loadout 4 0").ok, "none empties, a move index works")
	sw.step_ticks(2)         # one queued order per tick
	t.eq(sw.cur.loadout.slots, [4, -1, 3, 0], "none empties a slot and an index fills one")
	t.eq(int(sw.log_inputs[sw.log_inputs.size() - 1].verb), 10, "the loadout order is in the input log (verb 10)")
	var attack: Dictionary = r.execute("order attack #1 charge")
	t.check(not attack.ok and attack.error.contains("not_equipped"), "an unequipped move is not_equipped: %s" % attack.error)
	# the same session replays to the same hash from its exported log
	sw.step_ticks(20)
	var parsed: Dictionary = preload("res://game/stage/world_log.gd").parse(sw.export_log())
	t.check(parsed.ok, "the log with loadout orders parses")
	var sw2 = _world()
	t.eq(sw2.replay_recipe(parsed), 0, "replay_recipe runs")
	t.eq(sw2.world.hash(), sw.world.hash(), "the replay reaches the same C hash")
	t.eq(sw2.cur.loadout.slots, [4, -1, 3, 0], "and the same loadout")
	# away from the nest: not_at_nest, and the order is refused before it is queued
	t.check(r.execute("tp 60 0").ok, "tp away from the nest")
	sw.step_ticks(1)
	t.check(not sw.cur.loadout.can_edit, "far from the nest the loadout cannot be edited")
	var far: Dictionary = r.execute("loadout 1 bite")
	t.check(not far.ok and far.error.contains("not_at_nest"), "not_at_nest: %s" % far.error)
	t.check(r.execute("tp 0 0").ok, "tp back to the nest")
	sw.step_ticks(1)
	t.check(r.execute("loadout 1 bite").ok, "at the nest again it is accepted")

func _run_rest(t) -> void:
	t.eq(Registry.tokenize("tp  \"my site\" 3"), PackedStringArray(["tp", "my site", "3"]), "tokenize keeps quoted tokens")
	var sw = _world()
	var r = _registry(sw)
	t.check(r.execute("").ok, "empty line is fine")
	var bad: Dictionary = r.execute("frobnicate")
	t.check(not bad.ok and bad.error.contains("unknown command"), "unknown command: %s" % bad.error)
	t.check(r.execute("help").out.contains("spawn"), "help lists spawn")
	t.check(r.execute("help tp").out.contains("teleport"), "help <cmd>")
	# C1-nav: `overlay path` toggles a presentation node; it needs the island, and it is off by default
	t.check(r.execute("help").out.contains("overlay"), "help lists overlay")
	var no_island: Dictionary = r.execute("overlay path")
	t.check(not no_island.ok and no_island.error.contains("island"), "overlay path without the island says so: %s" % no_island.error)
	var overlay = preload("res://devtools/path_overlay.gd").new()
	t.check(not overlay.enabled, "the path overlay is off by default")
	r.services["path_overlay"] = overlay
	t.check(r.execute("overlay path on").ok and overlay.enabled, "overlay path on")
	t.check(r.execute("overlay path").ok and not overlay.enabled, "overlay path toggles")
	t.check(not r.execute("overlay nope").ok, "overlay <unknown> is refused")
	overlay.free()
	r.services.erase("path_overlay")
	t.check(sw.world.path().is_empty() and sw.world.nav_cell() == 0.0, "no path and no nav grid outside the island field")
	r.dev_enabled = false
	t.check(not r.execute("tp 1 1").ok and r.execute("help").ok, "dev commands are refused when dev tools are off")
	t.check(r.complete("t").has("help") == false and not r.complete("").has("tp"), "dev commands do not complete when off")
	r.dev_enabled = true
	# tp moves the C player after one tick and is in the v3 log
	t.check(r.execute("tp 30 40").ok, "tp 30 40")
	sw.step_ticks(1)
	var p: Dictionary = sw.cur.entities[0]
	t.check(Vector2(p.x, p.z).distance_to(Vector2(30, 40)) < 0.5, "the C player is at 30,40 (%s, %s)" % [p.x, p.z])
	t.eq(sw.log_debug.size(), 1, "the teleport is logged")
	t.check(sw.export_log().begins_with("CPORE_WORLD_LOG 3"), "and the exported log is v3")
	t.check(r.execute("tp #1 -20 10").ok, "tp #1 moves the wild creature")
	t.check(not r.execute("tp 500 0").ok, "tp outside the bound is refused with a sentence: %s" % r.execute("tp 500 0").error)
	# invalid commands change nothing
	var before: String = sw.world.hash()
	for line in ["tp abc", "tp #99 1 1", "kill #99", "kill", "spawn zanco", "spawn nothing", "spawn garfio 99", "time 25:00", "time 7",
			"give hp -5", "give dna 3", "heal #77", "order frobnicate", "order attack #99 bite", "step 0", "timescale 1000", "ai maybe", "trait add x", "stage island"]:
		var res: Dictionary = r.execute(line)
		t.check(not res.ok and res.error != "", "'%s' fails with a sentence (%s)" % [line, res.error])
	t.eq(sw.world.hash(), before, "failed commands leave the C hash unchanged")
	t.check(r.execute("spawn zanco").error.contains("no body"), "species without a body")
	# spawn on a ring ahead of the player
	var n0: int = sw.world.state().entities.size()
	var res: Dictionary = r.execute("spawn garfio 3")
	t.check(res.ok, "spawn garfio 3: %s %s" % [res.out, res.error])
	t.eq(sw.world.state().entities.size(), n0 + 3, "three creatures were added")
	var es: Array = sw.world.state().entities
	var pl: Dictionary = es[0]
	var a: Dictionary = es[n0]
	var b: Dictionary = es[n0 + 1]
	t.check(absf(Vector2(a.x - pl.x, a.z - pl.z).length() - 12.0) < 0.5 and Vector2(a.x - b.x, a.z - b.z).length() > 7.5, "spawned 12 m ahead and 8 m apart")
	# god + kill radius
	t.check(r.execute("god on").ok and int(sw.world.state().flags) == 1, "god on sets the flag")
	t.check(r.execute("ai off").ok and int(sw.world.state().flags) == 3, "ai off adds the flag")
	t.check(r.execute("god").out.contains("off") and int(sw.world.state().flags) == 2, "god toggles")
	t.check(r.execute("ai on").ok and int(sw.world.state().flags) == 0, "ai on clears it")
	var killed: Dictionary = r.execute("kill radius 1000")
	t.check(killed.ok and killed.out.begins_with("killed "), "kill radius: %s" % killed.out)
	var alive := 0
	for e in sw.world.state().entities.slice(1):
		if not e.dead:
			alive += 1
	t.eq(alive, 0, "every wild creature within 1000 m is dead")
	# time, heal, give
	t.check(r.execute("time 06:00").ok, "time 06:00")
	t.eq(int(sw.world.state().clock), 3000, "06:00 is tick 3000")
	sw.world.debug({"op": 4, "id": 0, "x": 5.0, "z": 5.0})
	t.check(r.execute("heal").ok and r.execute("give hp 50").ok, "heal and give hp")
	t.eq(sw.world.state().entities[0].hp, 50.0, "give hp 50")
	# order goes through the log
	sw.step_ticks(1)
	t.check(r.execute("order go 10 20").ok, "order go 10 20")
	sw.step_ticks(1)
	t.eq(int(sw.cur.order.verb), 2, "the order reached the C world")
	t.eq(int(sw.log_inputs[sw.log_inputs.size() - 1].get("verb", -1)), 2, "and is in the input log")
	# time control commands
	t.check(r.execute("timescale 2").ok and sw.timescale == 2.0, "timescale")
	t.check(r.execute("pause").ok and sw.paused, "pause toggles on")
	var tick0: int = int(sw.cur.tick)
	t.check(r.execute("step 5").ok and int(sw.cur.tick) == tick0 + 5, "step 5 while paused")
	t.check(r.execute("pause off").ok and not sw.paused, "pause off")
	t.check(r.execute("tick").out.to_int() == int(sw.cur.tick) and r.execute("hash").out.length() == 16 and r.execute("obs").out.begins_with("{"), "tick / hash / obs")
	t.check(r.execute("reveal").ok and r.flags.get("reveal", false), "reveal sets the presentation flag")
	# completion
	t.eq(r.complete("sp"), ["spawn"], "complete a command name")
	t.eq(r.complete("spawn g"), ["Garfio"], "complete a species")
	t.eq(r.complete("god o"), ["on", "off"], "complete on/off")
	t.check(r.complete("t").size() >= 5, "complete 't' lists several")
	t.eq(r.complete("nonexistent x"), [], "no completion for unknown commands")
	# history: dedupe consecutive, cap at 50, round trip
	r.history = PackedStringArray()
	r.execute("hash")
	r.execute("hash")
	r.execute("tick")
	t.eq(r.history.size(), 2, "history dedupes consecutive repeats")
	for i in 70:
		r.execute("step %d" % (i + 1))
	t.eq(r.history.size(), 50, "history is capped at 50")
	var path := "user://devtools-test-history.txt"
	r.save_history(path)
	var r2 = _registry(sw)
	r2.load_history(path)
	t.eq(r2.history, r.history, "history round trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
