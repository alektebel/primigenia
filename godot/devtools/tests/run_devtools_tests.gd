extends SceneTree
# DT0 test runner: godot --headless --fixed-fps 60 --path godot --script res://devtools/tests/run_devtools_tests.gd
# Each test script exposes `func run(t)`; t offers check()/eq()/exec() (same shape as game/tests/run_m0_tests.gd).
# Tests that need the autoloads (Game, Dev) get them from the tree root: the runner is a SceneTree script, so
# autoloads are present as nodes under root.

const TESTS := [
	"res://devtools/tests/test_inputmap.gd",
	"res://devtools/tests/test_legend.gd",
	"res://devtools/tests/test_time.gd",
	"res://devtools/tests/test_console.gd",
	"res://devtools/tests/test_scenario.gd",
	"res://devtools/tests/test_sites.gd",
	"res://devtools/tests/test_tuning.gd",
	"res://devtools/tests/test_feedback.gd",
	"res://devtools/tests/test_curated.gd",
	"res://devtools/tests/test_zoo.gd",
]

var checks := 0
var failures := 0
var current := ""
var shared := {}

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL [%s] %s" % [current, what])
	return ok

func eq(a, b, what: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [what, str(a).left(120), str(b).left(120)])

func build_path(name: String) -> String:
	return ProjectSettings.globalize_path("res://").path_join("../build/" + name).simplify_path()

func exec(path: String, args: Array) -> Dictionary:
	var out: Array = []
	var rc := OS.execute(path, PackedStringArray(args), out, true)
	return {"rc": rc, "out": "" if out.is_empty() else str(out[0])}

func _initialize() -> void:
	for cls in ["CporeTerrain", "CporeWorld"]:
		if not ClassDB.class_exists(cls):
			printerr("FATAL: GDExtension class %s is missing. Run `make godot` first." % cls)
			quit(2)
			return
	_run_all.call_deferred()

func _run_all() -> void:
	for path in TESTS:
		current = path.get_file()
		var script = load(path)
		if script == null or not script.can_instantiate():
			check(false, "cannot load " + path)
			continue
		var started := Time.get_ticks_msec()
		var r = script.new().run(self)
		if r is Object and r.get_class() == "GDScriptFunctionState":
			await r
		print("  %s done in %d ms" % [current, Time.get_ticks_msec() - started])
	print("devtools tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
