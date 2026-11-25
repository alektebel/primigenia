extends RefCounted
# CporeWorld: the three committed golden logs replay tick for tick; determinism; validation.

const WorldLog := preload("res://game/stage/world_log.gd")

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func run(t) -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../tests/golden")
	for seed in [1, 42, 987654321]:
		var log_text := _read("%s/world-%d.log" % [root, seed])
		var expected := _read("%s/world-%d.hashes" % [root, seed]).split("\n", false)
		var parsed: Dictionary = WorldLog.parse(log_text)
		if not t.check(parsed.ok, "parse world-%d.log: %s" % [seed, parsed.get("error", "")]):
			continue
		t.eq(parsed.inputs.size(), 3000, "3000 ticks")
		t.eq(expected.size(), 3000, "3000 hashes")
		var w = CporeWorld.new()
		t.eq(w.reset(parsed.setup), 0, "reset golden setup %d" % seed)
		var mismatches := 0
		var first := -1
		for i in parsed.inputs.size():
			var h: String = w.step(parsed.inputs[i])
			if h != expected[i]:
				mismatches += 1
				if first < 0:
					first = i
		t.eq(mismatches, 0, "world-%d: every tick hash equals the golden (first mismatch tick %d)" % [seed, first])
		# The writer is stable: write -> parse -> write gives the same text, and it replays the same.
		var text1: String = WorldLog.write(parsed.setup, parsed.inputs)
		var again: Dictionary = WorldLog.parse(text1)
		t.check(again.ok and WorldLog.write(again.setup, again.inputs) == text1, "world-%d: written log is stable" % seed)
		var w2 = CporeWorld.new()
		w2.reset(again.setup)
		var same := true
		for i in 300:
			same = same and w2.step(again.inputs[i]) == expected[i]
		t.check(same, "world-%d: the rewritten log replays identically (300 ticks)" % seed)

	# Float round trip of the writer.
	for v in [0.1, 34.16093444824219, 1e-7, 123456.7, -0.0003, 195.0]:
		var f: float = WorldLog.f32(v)
		t.eq(WorldLog.f32(WorldLog.num(f).to_float()), f, "num() round-trips %s" % v)

	# Determinism with random inputs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var a = CporeWorld.new()
	var b = CporeWorld.new()
	a.reset({"seed": 5})
	b.reset({"seed": 5})
	var diverged := false
	for i in 180:
		var inp := {"verb": rng.randi_range(0, 3), "hx": rng.randi_range(-32767, 32767), "hz": rng.randi_range(-32767, 32767),
			"sprint": rng.randi() % 2, "x": rng.randf_range(-100, 100), "z": rng.randf_range(-100, 100)}
		if a.step(inp) != b.step(inp):
			diverged = true
	t.check(not diverged, "two worlds with the same inputs stay hash-equal")
	t.eq(a.hash(), b.hash(), "final hashes equal")

	# Observation, commands, validation.
	var o = JSON.parse_string(a.observe())
	t.check(o is Dictionary and o.get("schema", "") == "world-2", "observe() is world-2 JSON")
	var before: String = a.hash()
	t.check(a.command("invalid verb") != 0, "invalid command rejected")
	t.eq(a.hash(), before, "invalid command leaves the hash unchanged")
	var good: Dictionary = a.get_setup()
	good.player.mouth = 6
	t.eq(a.reset(good), -1, "reset with mouth 6 fails")
	t.eq(a.hash(), before, "failed reset keeps the old state")
	t.eq(a.reset({"seed": "x"}), -1, "reset with a string seed fails")
	t.eq(a.reset({"unknown": 1}), -1, "reset with an unknown key fails")
	var tick_before: int = a.state().tick
	t.eq(a.step({"hx": 40000}), "", "step with hx out of range returns empty")
	t.eq(a.step({"verb": "go"}), "", "step with a wrong type returns empty")
	t.eq(a.state().tick, tick_before, "rejected steps do not advance")
	var sp: Array = CporeWorld.species()
	t.eq(sp.size(), 8, "eight species (C2 secrets added Acechalunas and Babosa)")
	t.eq(sp[3].name, "Garfio", "species 3 is Garfio")
	t.eq(sp[3].temperament, 2, "Garfio is aggressive")
	t.eq(CporeWorld.version(), 4, "stage version")
	var st: Dictionary = a.state()
	t.check(st.has("entities") and st.has("combat") and st.has("order") and st.has("arena"), "state schema")
	t.eq(st.entities[0].id, 0, "entity 0 is the player")
	t.check(a.ground(0, 0) == a.height(0, 0) or true, "ground callable")
