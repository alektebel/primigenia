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
	t.eq(Registry.tokenize("tp  \"my site\" 3"), PackedStringArray(["tp", "my site", "3"]), "tokenize keeps quoted tokens")
	var sw = _world()
	var r = _registry(sw)
	t.check(r.execute("").ok, "empty line is fine")
	var bad: Dictionary = r.execute("frobnicate")
	t.check(not bad.ok and bad.error.contains("unknown command"), "unknown command: %s" % bad.error)
	t.check(r.execute("help").out.contains("spawn"), "help lists spawn")
	t.check(r.execute("help tp").out.contains("teleport"), "help <cmd>")
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
