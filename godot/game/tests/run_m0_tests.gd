extends SceneTree
# M0 test runner: godot --headless --path godot --script res://game/tests/run_m0_tests.gd
# Each test script exposes `func run(t)`, where t offers check()/eq()/exec().

const TESTS := [
	"res://game/tests/test_terrain.gd",
	"res://game/tests/test_world.gd",
	"res://game/tests/test_project.gd",
	"res://game/tests/test_ground.gd",
	"res://game/tests/test_look.gd",
	"res://game/tests/test_lod.gd",
	"res://game/tests/test_cache.gd",
]

var checks := 0
var failures := 0
var current := ""
var shared := {}  # data handed from one test to the next

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL [%s] %s" % [current, what])
	return ok

func eq(a, b, what: String) -> bool:
	var ok: bool = (a == b)
	return check(ok, "%s (got %s, expected %s)" % [what, str(a).left(80), str(b).left(80)])

func build_path(name: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("../build/" + name).simplify_path()

func exec(path: String, args: Array) -> Dictionary:
	var out: Array = []
	var rc := OS.execute(path, PackedStringArray(args), out, true)
	return {"rc": rc, "out": "" if out.is_empty() else str(out[0])}

func _initialize() -> void:
	for cls in ["CporeTerrain", "CporeWorld"]:
		if not ClassDB.class_exists(cls):
			printerr("FATAL: GDExtension class %s is missing. Run `make godot` first (it seeds .godot/extension_list.cfg)." % cls)
			quit(2)
			return
	for path in TESTS:
		current = path.get_file()
		var script = load(path)
		if script == null:
			check(false, "cannot load " + path)
			continue
		var started := Time.get_ticks_msec()
		script.new().run(self)
		print("  %s done in %d ms" % [current, Time.get_ticks_msec() - started])
	print("M0 tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
