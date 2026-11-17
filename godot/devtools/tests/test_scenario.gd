extends RefCounted
# Step 8: scenarios and saves on a StageWorld (no island): round trip, recipes, every §1.4 error sentence.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Scenario := preload("res://devtools/scenario.gd")

const DIR := "user://devtools-test/scenarios"

func _world() -> Node:
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.flat_height = 2.0
	sw.reset(setup)
	sw.input_provider = func() -> Dictionary:
		var k: int = int(sw.cur.tick)
		return {"verb": 3, "hx": (k % 60) * 500 - 15000, "hz": 20000, "sprint": 1 if k % 80 < 25 else 0}
	return sw

func _patch_state(path: String, offset: int, value: int) -> void:
	var b := FileAccess.get_file_as_bytes(path)
	b[offset] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(b)
	f.close()

func _patch_json(path: String, key: String, value) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	d[key] = value
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func run(t) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var sw = _world()
	for i in 150:
		sw.step_once()
	sw.debug_now({"op": 1, "id": 0, "x": 20.0, "z": -10.0})
	sw.debug_now({"op": 2, "a": 3, "x": 30.0, "z": 30.0})
	for i in 50:
		sw.step_once()
	var path := DIR + "/round"
	t.eq(Scenario.save(sw, {"genome": {}}, path, "scenario", "round trip"), "", "save writes json, cpstate and recipe")
	t.check(FileAccess.file_exists(path + ".json") and FileAccess.file_exists(path + ".cpstate") and FileAccess.file_exists(path + ".log"), "three files")
	var parsed := Scenario.read(path)
	t.check(parsed.ok, "read: %s" % parsed.error)
	t.eq(parsed.dict.format, "primigenia.scenario/1", "format")
	t.eq(int(parsed.dict.tick), 200, "tick recorded")
	t.check(parsed.recipe.begins_with("CPORE_WORLD_LOG 3"), "the recipe is a v3 log")
	# save -> load -> 300 ticks == continuing the original
	var cont: Array = []
	for i in 300:
		sw.step_once()
		cont.append(sw.hashes[sw.hashes.size() - 1])
	var sw2 = _world()
	var res := Scenario.load_into(parsed, sw2)
	t.check(res.ok and not res.rebuilt, "load_into restores: %s" % res.get("error", ""))
	t.eq(sw2.world.state().hash, parsed.dict.hash, "restored hash equals the saved one")
	var same := true
	for i in 300:
		sw2.step_once()
		same = same and sw2.hashes[sw2.hashes.size() - 1] == cont[i]
	t.check(same, "300 ticks after load equal the uninterrupted run")
	# the recipe alone rebuilds the same state
	var rec: Dictionary = preload("res://game/stage/world_log.gd").parse(parsed.recipe)
	var sw3 = _world()
	t.eq(sw3.replay_recipe(rec), 0, "the recipe replays")
	t.eq(sw3.world.state().hash, parsed.dict.hash, "recipe replay equals the saved state")
	# errors: one sentence each, naming the file
	var e: Dictionary
	_patch_json_copy(path, DIR + "/newer", "format", "primigenia.scenario/2")
	e = Scenario.read(DIR + "/newer")
	t.check(not e.ok and e.error.contains("format primigenia.scenario/2 is newer than this build (reads /1)") and e.error.contains("newer.json"), "newer format: %s" % e.error)
	_patch_json_copy(path, DIR + "/nofmt", "format", "other/1")
	t.check(not Scenario.read(DIR + "/nofmt").ok, "foreign format")
	_patch_json_copy(path, DIR + "/nostate", "state", "gone.cpstate")
	t.check(Scenario.read(DIR + "/nostate").error.contains("gone.cpstate"), "missing state file names it")
	t.check(Scenario.read(DIR + "/does_not_exist").error.contains("no such file"), "missing scenario")
	# engine mismatch with a recipe: rebuilt + note; without: the snapshot sentence
	_copy_all(path, DIR + "/engine")
	_patch_state(DIR + "/engine.cpstate", 12, 99)
	var sw4 = _world()
	var r4 := Scenario.load_into(Scenario.read(DIR + "/engine"), sw4)
	t.check(r4.ok and r4.rebuilt and r4.note.contains("rebuilt from the recipe"), "engine mismatch rebuilds from the recipe: %s" % r4.get("note", r4.get("error", "")))
	t.eq(sw4.world.state().hash, parsed.dict.hash, "the rebuilt state equals the original")
	_copy_all(path, DIR + "/layout")
	_patch_state(DIR + "/layout.cpstate", 16, 0x7f)
	var r5 := Scenario.load_into(Scenario.read(DIR + "/layout"), _world())
	t.check(r5.ok and r5.rebuilt, "layout mismatch also rebuilds")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/layout.log"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR + "/engine.log"))
	var r6 := Scenario.load_into(Scenario.read(DIR + "/engine"), _world())
	t.check(not r6.ok and r6.error.contains("engine.json") and r6.error.contains("engine version"), "engine mismatch without a recipe: %s" % r6.error)
	_copy_all(path, DIR + "/corrupt")
	_patch_state(DIR + "/corrupt.cpstate", 48 + 8, 0xff)
	var r7 := Scenario.load_into(Scenario.read(DIR + "/corrupt"), _world())
	t.check(not r7.ok and r7.error.contains("corrupt"), "a corrupt payload: %s" % r7.error)
	_copy_all(path, DIR + "/disagree")
	_patch_json(DIR + "/disagree.json", "hash", "0123456789abcdef")
	var r8 := Scenario.load_into(Scenario.read(DIR + "/disagree"), _world())
	t.check(not r8.ok and r8.error.contains("disagree"), "json vs state: %s" % r8.error)
	# island rules
	_copy_all(path, DIR + "/island")
	_patch_json(DIR + "/island.json", "island", {"seed": 1, "terrain_version": 3, "terrain_hash": "deadbeefdeadbeef"})
	var r9 := Scenario.load_into(Scenario.read(DIR + "/island"), _world())
	t.check(not r9.ok and r9.error.contains("no island field attached"), "island without a field: %s" % r9.error)
	var fake := {"n": 4, "size_m": 40.0, "height": PackedFloat32Array([1,1,1,1, 1,1,1,1, 1,1,1,1, 1,1,1,1]), "hash": "0000000000000001", "seed": 1}
	var sw5 = _world()
	sw5.world.set_field(fake)
	var r10 := Scenario.load_into(Scenario.read(DIR + "/island"), sw5)
	t.check(not r10.ok and r10.error.contains("made on island version 3") and r10.error.contains("this build generates 0000000000000001"), "another terrain hash: %s" % r10.error)
	# a genome the creature module rejects names the reason
	_copy_all(path, DIR + "/genome")
	_patch_json(DIR + "/genome.json", "genome", {"schema": "cpore.creature/4", "nodes": "broken"})
	var r11 := Scenario.load_into(Scenario.read(DIR + "/genome"), _world())
	t.check(not r11.ok and r11.error.contains("genome was rejected"), "broken genome: %s" % r11.error)
	# list / resolve
	t.check(Scenario.resolve("user://x/y").ends_with("y.json") and Scenario.resolve("/abs/z.json") == "/abs/z.json", "resolve")
	# a game save is a scenario without a recipe
	var save_path := DIR + "/slot-test"
	t.eq(Scenario.save(sw, {}, save_path, "save", ""), "", "save game")
	t.check(not FileAccess.file_exists(save_path + ".log") and Scenario.read(save_path).dict.kind == "save", "saves keep no recipe")
	# from a snapshot start the recipe is omitted
	var sw6 = _world()
	sw6.restore_from(sw.world.snapshot())
	var b: Dictionary = Scenario.build(sw6, {}, "scenario", "x", "")
	t.check(b.recipe == "" and not b.json.has("recipe"), "a session that started from a snapshot has no recipe")
	var d := DirAccess.open(DIR)
	for f in d.get_files():
		d.remove(f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DIR))

func _copy_all(from_base: String, to_base: String) -> void:
	for ext in [".json", ".cpstate", ".log"]:
		if FileAccess.file_exists(from_base + ext):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(from_base + ext), ProjectSettings.globalize_path(to_base + ext))
	# the json names its state file after the scenario: point it at the copy
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(to_base + ".json"))
	d.state = to_base.get_file() + ".cpstate"
	if d.has("recipe"):
		d.recipe = to_base.get_file() + ".log"
	var f := FileAccess.open(to_base + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func _patch_json_copy(from_base: String, to_base: String, key: String, value) -> void:
	_copy_all(from_base, to_base)
	_patch_json(to_base + ".json", key, value)
