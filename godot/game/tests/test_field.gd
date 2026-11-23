extends RefCounted
# Step 5 (snapshot, debug ops, params, log v3 through the Godot bridge) and H4 (the island field in CporeWorld).

const StageWorld := preload("res://game/stage/stage_world.gd")
const WorldLog := preload("res://game/stage/world_log.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _rand_input(rng: RandomNumberGenerator) -> Dictionary:
	return {"verb": rng.randi_range(0, 3), "hx": rng.randi_range(-32767, 32767), "hz": rng.randi_range(-32767, 32767),
		"sprint": rng.randi() % 2, "x": rng.randf_range(-100, 100), "z": rng.randf_range(-100, 100)}

func _replay_in_cli(t, sw, name: String) -> Array:
	var dir := ProjectSettings.globalize_path("user://devtools-test")
	DirAccess.make_dir_recursive_absolute(dir)
	var log_path := dir.path_join(name + ".log")
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	f.store_string(sw.export_log(name + ".cpstate"))
	f.close()
	if sw.start_snapshot.size() > 0:
		var s := FileAccess.open(dir.path_join(name + ".cpstate"), FileAccess.WRITE)
		s.store_buffer(sw.start_snapshot)
		s.close()
	var r: Dictionary = t.exec(t.build_path("world_cli"), ["--replay", log_path])
	t.eq(r.rc, 0, "world_cli --replay accepts the %s log" % name)
	return str(r.out).strip_edges().split("\n")

func run(t) -> void:
	_snapshots(t)
	_bridge(t)
	_field(t)

func _snapshots(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var inputs := []
	for i in 900:
		inputs.append(_rand_input(rng))
	var a = CporeWorld.new()
	a.reset({"seed": 11})
	var ha := PackedStringArray()
	var blob := PackedByteArray()
	for i in 900:
		if i == 300:
			blob = a.snapshot()
		ha.append(a.step(inputs[i]))
	t.check(blob.size() > 22000 and blob.slice(0, 7).get_string_from_ascii() == "CPSTAGE", "snapshot header")
	var b = CporeWorld.new()
	t.eq(b.restore(blob), 0, "restore into another world")
	var diverged := 0
	for i in range(300, 900):
		if b.step(inputs[i]) != ha[i]:
			diverged += 1
	t.eq(diverged, 0, "restore then 600 ticks equals the uninterrupted run")
	t.eq(b.hash(), a.hash(), "final hashes equal")
	var bad := blob.duplicate()
	bad[0] = 0x58
	t.eq(b.restore(bad), -1, "wrong magic is rejected")
	t.check(CporeWorld.snapshot_error(-3).contains("engine"), "snapshot_error text")
	t.eq(b.hash(), a.hash(), "a failed restore keeps the state")
	t.check(b.layout().length() == 16, "layout fingerprint is 16 hex digits")
	var params: Array = CporeWorld.params()
	t.eq(params.size(), 28, "28 motion parameters")
	t.eq(params[0].name, "jog_k", "first parameter")
	t.check(absf(a.param(0) - params[0].default) < 1e-6, "param(0) is its default")
	t.eq(a.debug({"op": 7, "a": 0, "v": 2.0}), 0, "PARAM debug op accepted")
	t.check(absf(a.param(0) - 2.0) < 1e-6, "param(0) reads w->motion")
	t.eq(a.debug({"op": 99}), -1, "unknown op rejected")
	t.check(CporeWorld.debug_error(-2).contains("fight"), "debug_error text")

func _bridge(t) -> void:
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.nest = Vector2.ZERO
	setup.wild[0].x = 0.0
	setup.wild[0].z = 60.0
	setup.wild[0].home_x = 0.0
	setup.wild[0].home_z = 60.0
	t.eq(sw.reset(setup), 0, "bridge reset")
	var applied := []
	sw.debug_applied.connect(func(op, rc): applied.append(rc))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	sw.input_provider = func() -> Dictionary: return {"verb": 3, "hx": 20000 if sw.log_inputs.size() % 40 < 20 else -20000, "hz": 30000, "sprint": 0}
	for i in 120:
		if i == 11:
			t.check(Vector2(sw.cur.entities[0].x, sw.cur.entities[0].z).distance_to(Vector2(30, -20)) < 8.0, "the player was teleported")
		if i == 10:
			sw.queue_debug({"op": 1, "id": 0, "x": 30.0, "z": -20.0})
		if i == 20:
			sw.queue_debug({"op": 6, "a": 1})
		if i == 30:
			sw.queue_debug({"op": 7, "a": 0, "v": 1.8})
		if i == 40:
			sw.queue_debug({"op": 1, "id": 0, "x": 9999.0, "z": 0.0})   # rejected: not logged
		sw.step_once()
	t.eq(applied, [0, 0, 0, -4], "debug results emitted: three accepted, one rejected")
	t.eq(sw.log_debug.size(), 3, "only accepted ops are logged")
	t.eq(int(sw.log_debug[0].tick), 10, "the teleport applies at the start of tick 10")
	t.check(sw.snapshot_ring.size() == 1 and sw.snapshot_ring[0].tick == 100, "snapshot ring keeps ticks 100")
	var lines := _replay_in_cli(t, sw, "session-v3")
	t.eq(lines.size(), 120, "world_cli prints 120 hashes")
	var mism := 0
	for i in mini(lines.size(), 120):
		if lines[i].strip_edges() != sw.hashes[i]:
			mism += 1
	t.eq(mism, 0, "world_cli replay hashes equal the Godot session with tp + god + param")
	var parsed: Dictionary = WorldLog.parse(sw.export_log())
	t.check(parsed.ok and parsed.version == 3 and parsed.debug.size() == 3, "the exported v3 log parses back")
	t.eq(WorldLog.write(parsed.setup, parsed.inputs, {"debug": parsed.debug}), sw.export_log(), "write(parse(log)) is stable")
	# A session started from a snapshot exports the snapshot line and replays too.
	var blob: PackedByteArray = sw.snapshot_ring[0].bytes
	var sw2 = StageWorld.new()
	sw2.reset(setup)
	t.eq(sw2.restore_from(blob), 0, "restore_from")
	t.eq(sw2.log_start_tick, 100, "the log starts at the snapshot tick")
	sw2.input_provider = sw.input_provider
	for i in 50:
		if i == 5:
			sw2.queue_debug({"op": 1, "id": 0, "x": -10.0, "z": 10.0})
		sw2.step_once()
	var l2 := _replay_in_cli(t, sw2, "session-from-snapshot")
	var m2 := 0
	for i in mini(l2.size(), 50):
		if l2[i].strip_edges() != sw2.hashes[i]:
			m2 += 1
	t.check(l2.size() == 50 and m2 == 0, "a log started from a snapshot replays in world_cli (%d lines, %d mismatches)" % [l2.size(), m2])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://devtools-test"))

func _island() -> Dictionary:
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = 1
		entry = CporeTerrain.new().generate(p)
		TerrainData.prepare(entry)
	return entry

func _field(t) -> void:
	var entry := _island()
	var data = TerrainData.new()
	data.setup(entry, false)
	var w = CporeWorld.new()
	t.eq(w.reset({"terrain": 2}), -1, "terrain 2 without a field fails")
	t.eq(w.last_error(), "terrain 2 needs set_field() first", "last_error explains it")
	t.eq(w.set_field(entry), 0, "the seed-1 island attaches")
	t.check(w.has_field() and w.field_info().n == data.n and w.field_info().hash == entry.hash, "field_info")
	t.eq(w.reset({"terrain": 2, "nest": Vector2(0, 0), "wild": []}), 0, "terrain 2 resets with the field")
	t.check(absf(w.bound() - (data.half - 2.0 * data.cell)) < 0.01, "bound is half - 2 cells in FIELD mode")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var points := PackedVector2Array()
	for i in 5000:
		points.append(Vector2(rng.randf_range(-data.half, data.half), rng.randf_range(-data.half, data.half)))
	for i in 2000:
		var edge: float = float(rng.randi_range(-27, 27)) * 64.0 * data.cell
		points.append(Vector2(edge, rng.randf_range(-data.half, data.half)) if i % 2 == 0 else Vector2(rng.randf_range(-data.half, data.half), edge))
	var rock := 0
	while rock < 2000:
		var k := rng.randi_range(0, data.n * data.n - 1)
		if data.material[k] == 1:
			points.append(Vector2(data.cell_center(k % data.n) + rng.randf_range(-.5, .5) * data.cell, data.cell_center(k / data.n) + rng.randf_range(-.5, .5) * data.cell))
			rock += 1
	for i in 1000:
		var edge: float = data.half - rng.randf_range(0.0, 2.0) * data.cell
		var side := rng.randi() % 4
		var along: float = rng.randf_range(-data.half, data.half)
		var s := -1.0 if side % 2 == 0 else 1.0
		points.append(Vector2(s * edge, along) if side < 2 else Vector2(along, s * edge))
	var worst := 0.0
	for p in points:
		worst = maxf(worst, absf(w.ground(p.x, p.y) - data.ground(p.x, p.y)))
	t.eq(points.size(), 10000, "10 000 sample points")
	t.check(worst <= 0.001, "CporeWorld.ground equals TerrainData.ground at 10 000 points (max |d| = %s m)" % String.num(worst, 8))
	# Water: depth > 0 exactly on sea / pond cells (cell centres, nearest-cell rule).
	var wrong := 0
	var wet := 0
	for k in range(0, data.n * data.n, 5):
		var depth: float = w.water_depth(data.cell_center(k % data.n), data.cell_center(k / data.n))
		var expect: bool = data.is_sea(k) and data.height[k] < 0.0 or data.is_pond(k)
		if data.height[k] == 0.0 and data.is_sea(k):
			expect = false   # a zero-depth shore cell is sea but holds no water
		if (depth > 0.0) != expect:
			wrong += 1
		if depth > 0.0:
			wet += 1
	t.eq(wrong, 0, "water_depth > 0 exactly on sea and pond cells (%d wet cells sampled)" % wet)
	# A Godot session on the field replays in world_cli (n = 256 island, regenerated by the CLI from the log).
	var p256: Dictionary = CporeTerrain.defaults()
	p256.n = 256
	p256.seed = 1
	var e256: Dictionary = CporeTerrain.new().generate(p256)
	TerrainData.prepare(e256)
	var d256 = TerrainData.new()
	d256.setup(e256, false)
	var sw = StageWorld.new()
	t.eq(sw.world.set_field(e256), 0, "n=256 island attaches to a StageWorld")
	var setup: Dictionary = CporeWorld.default_setup(3)
	setup.terrain = 2
	setup.nest = Vector2(0, 0)
	setup.wild = []
	t.eq(sw.reset(setup), 0, "StageWorld resets on the field")
	sw.input_provider = func() -> Dictionary: return {"verb": 3, "hx": 12000 + sw.log_inputs.size() * 40, "hz": 32767, "sprint": 1 if sw.log_inputs.size() % 90 < 30 else 0}
	for i in 200:
		sw.step_once()
	var lines := _replay_in_cli(t, sw, "field-session")
	var mism := 0
	for i in mini(lines.size(), 200):
		if lines[i].strip_edges() != sw.hashes[i]:
			mism += 1
	t.check(lines.size() == 200 and mism == 0, "the field session replays in world_cli (%d lines, %d mismatches)" % [lines.size(), mism])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://devtools-test"))
	w.clear_field()
	t.check(not w.has_field(), "clear_field")
