extends RefCounted
# Run and fall through the Godot layer: the run intent latched in C, the stamina in the state, and a slide off a cliff face with
# its fell event (type 27) reaching StageWorld.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const RockViews := preload("res://game/tests/rock_views.gd")
const WorldLog := preload("res://game/stage/world_log.gd")

func run(t) -> void:
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 256
	p.seed = 1
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var data = TerrainData.new()
	data.setup(entry, false)
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var genome: Dictionary = Profile.load_json("res://game/data/merodeador.json")
	var player: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	var setup: Dictionary = StageSetup.build(data, 7, player, garfio, false, sw.world)
	t.eq(sw.reset(setup), 0, "run/fall session resets")
	# walking, then running: the C speed is 1.8x and the stamina drains
	var heading := {"verb": 3, "hx": 32767, "hz": 0, "sprint": 0, "run": 0}
	sw.input_provider = func() -> Dictionary: return heading
	for i in 25:
		sw.step_once()
	var walk_speed: float = sw.cur.entities[0].speed
	t.check(not bool(sw.cur.player.running) and int(sw.cur.player.stamina) == 1000, "not running: full run stamina")
	heading["run"] = 1
	for i in 25:
		sw.step_once()
	var run_speed: float = sw.cur.entities[0].speed
	t.check(bool(sw.cur.player.running) and int(sw.cur.player.stamina) < 1000, "run intent: running, stamina drains (%d)" % int(sw.cur.player.stamina))
	t.check(walk_speed > 0.5 and absf(run_speed / walk_speed - sqrt(2.2 / 0.24)) < 0.15, "run speed is sqrt(Fr 2.2 / Fr 0.24) = 3.0x walk (A39, run Fr 2.2 since A54) (%.2f vs %.2f)" % [run_speed, walk_speed])
	heading["run"] = 0
	for i in 5:
		sw.step_once()
	t.check(not bool(sw.cur.player.running), "releasing Shift stops running")
	# a cliff face: the body falls instead of walking, and lands with a fell event
	var cliff: Dictionary = RockViews.find_cliff(data, true)
	if cliff.is_empty():
		cliff = RockViews.find_cliff(data, false)
	t.check(not cliff.is_empty(), "the seed-1 island has a cliff face")
	if cliff.is_empty():
		return
	t.eq(sw.debug_now({"op": 1, "id": 0, "x": cliff.x, "z": cliff.z}), 0, "teleport onto the cliff face")
	heading["run"] = 0
	var fell := false
	var saw_falling := false
	var damage := 0.0
	for i in 200:
		sw.step_once()
		saw_falling = saw_falling or bool(sw.cur.player.falling)
		for ev in sw.cur.get("social_events", []):
			if int(ev.type) == 27:
				fell = true
				damage = float(ev.value)
		if fell:
			break
	t.check(saw_falling, "direct movement on a 55-65 degree face starts a fall")
	t.check(fell and not bool(sw.cur.player.falling), "the fall ends with a fell event (type 27), damage %.1f" % damage)
	t.check(sw.sample(0).has("pos"), "sample() still interpolates after a fall")
	_log_v4(t, sw)

# Input log v4: the run column is written, parses back, and world_cli replays the session (run toggles included) to the same hashes.
func _log_v4(t, sw) -> void:
	var text: String = sw.export_log()
	t.check(text.begins_with("CPORE_WORLD_LOG 4"), "a session that ran exports a v4 log")
	var parsed: Dictionary = WorldLog.parse(text)
	t.check(parsed.ok and parsed.version == 4 and parsed.inputs.size() == sw.log_inputs.size(), "the v4 log parses back")
	var runs := 0
	for i in parsed.inputs:
		runs += int(i.get("run", 0))
	t.check(runs > 20, "the run column carries the toggles (%d ticks running)" % runs)
	t.eq(WorldLog.write(parsed.setup, parsed.inputs, {"debug": parsed.debug, "field": parsed.field}), text, "write(parse(v4 log)) is stable")
	var dir := ProjectSettings.globalize_path("user://devtools-test")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("run-v4.log")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	var r: Dictionary = t.exec(t.build_path("world_cli"), ["--replay", path])
	t.eq(r.rc, 0, "world_cli --replay accepts the v4 log")
	var lines: PackedStringArray = str(r.out).strip_edges().split("\n")
	var bad := 0
	for i in mini(lines.size(), sw.hashes.size()):
		if lines[i].strip_edges() != sw.hashes[i]:
			bad += 1
	t.check(lines.size() == sw.hashes.size() and bad == 0, "world_cli replays the run session to the Godot hashes (%d lines, %d mismatches)" % [lines.size(), bad])
	# the same inputs without any run: v3 text (no run column), still parses and replays
	var plain: Array = []
	for i in sw.log_inputs:
		var c: Dictionary = i.duplicate()
		c.erase("run")
		plain.append(c)
	var v3: String = WorldLog.write(parsed.setup, plain, {"debug": parsed.debug, "field": parsed.field})
	var p3: Dictionary = WorldLog.parse(v3)
	t.check(v3.begins_with("CPORE_WORLD_LOG 3") and p3.ok and p3.version == 3 and not p3.inputs[0].has("run"), "no run set: a v3 log, no run column")
	DirAccess.remove_absolute(path)
