extends SceneTree

var failures := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func _initialize() -> void:
	# Dynamic lookup makes the missing extension an explicit failing test.
	check(ClassDB.class_exists("Cpore"), "Cpore GDExtension must load")
	if failures:
		quit(1)
		return
	call_deferred("run")

func run() -> void:
	var native = ClassDB.instantiate("Cpore")
	var params: Dictionary = native.terrain_defaults()
	check(params.n == 1024 and params.volcano == 0.0 and params.cliff_bands == 1.0,
		"W20 defaults must be preserved")
	params.n = 64
	params.seed = 42
	var terrain: Dictionary = native.generate(params)
	check(terrain.get("error", -1) == 0, "terrain generation succeeds")
	check(terrain.height.size() == 4096 and terrain.material.size() == 4096,
		"all terrain maps retain their dimensions")
	check(terrain.flow.size() == 4096 and terrain.sediment.size() == 4096,
		"flow and sediment maps are exposed")
	check(native.progress().stage == 4, "generation reports completion")
	var output: Array = []
	var executable := ProjectSettings.globalize_path("res://../build/terrain_cli")
	check(OS.execute(executable, ["hash", "--seed", "42", "--n", "64"], output) == 0,
		"native terrain CLI runs")
	check(str(output[0]).split(" ")[0] == terrain.hash, "extension terrain hash equals C CLI")
	check(native.generate({"n": 1}).error != 0, "invalid grid is rejected before allocation")
	check(native.generate({"not_a_parameter": 1}).error != 0, "unknown parameter is rejected")
	var other = ClassDB.instantiate("Cpore")
	check(native.world_reset({"seed": 42}) == 0, "world reset succeeds")
	other.world_reset({"seed": 42})
	for tick in range(180):
		var input := {"verb": 3, "hx": 22000, "hz": 15000, "sprint": tick % 3 == 0}
		check(native.world_step(input).hash == other.world_step(input).hash,
			"two independent C worlds step deterministically")
	check(native.world_state().tick == 180, "world runs one C tick per call")
	check(native.world_state().player.x != 0.0, "heading input moves the C player")
	check(JSON.parse_string(native.world_observe()) is Dictionary, "C observation is valid JSON")
	var before: String = native.world_state().hash
	check(native.world_command("invalid verb") != 0, "invalid command is rejected")
	check(native.world_state().hash == before, "rejected command preserves state")
	var cache_script = load("res://scripts/terrain_cache.gd")
	var cache = cache_script.new()
	var path: String = cache.cache_path(params, "user://m0-tests")
	DirAccess.remove_absolute(path)
	var first: Dictionary = cache.load_or_generate(native, params, "user://m0-tests")
	var second: Dictionary = cache.load_or_generate(native, params, "user://m0-tests")
	check(not first.cache_hit and second.cache_hit, "second load hits the disk cache")
	check(first.hash == second.hash and first.height == second.height,
		"cache roundtrip preserves maps and hash")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("truncated cache")
	file.close()
	check(not cache.load_or_generate(native, params, "user://m0-tests").cache_hit,
		"corrupt cache regenerates")
	var changed: Dictionary = params.duplicate()
	changed.erosion = 0.2
	check(path != cache.cache_path(changed, "user://m0-tests"), "parameter changes invalidate cache")
	DirAccess.remove_absolute(path)
	print("Godot extension tests: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	quit(1 if failures else 0)
