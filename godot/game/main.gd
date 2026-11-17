extends Node
# Boot: settings -> terrain cache hit goes straight to the island; a miss shows the loading screen.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const LoadingScene := preload("res://game/loading/loading_screen.tscn")
const Scenario := preload("res://devtools/scenario.gd")

# `--scenario <name>` (or --scenario=<name>) after "--": a scenario under res://scenarios/, user://scenarios/, or a path.
func _scenario_arg() -> String:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--scenario" and i + 1 < args.size():
			return args[i + 1]
		if args[i].begins_with("--scenario="):
			return args[i].substr(11)
	return ""

# `--play` after "--" skips the menu (evidence and tests); otherwise the menu opens once the island data is ready.
func _next() -> void:
	if "--play" in OS.get_cmdline_user_args() or not Game.pending_scenario.is_empty():
		Game.goto_island()
	else:
		Game.goto_menu()

func _ready() -> void:
	var sc_name := _scenario_arg()
	if sc_name != "":
		var parsed := Scenario.read(sc_name)
		if not parsed.ok:
			Game.startup_error = parsed.error
			push_error(parsed.error)
			printerr("SCENARIO_ERROR " + parsed.error)
			get_tree().quit(1)
			return
		Game.pending_scenario = parsed
		var isl: Dictionary = parsed.dict.get("island", {})
		if isl.has("seed"):
			Game.settings.seed = int(isl.seed)
	var params := {"seed": int(Game.settings.seed)}
	var t0 := Time.get_ticks_msec()
	var entry := TerrainCache.load_entry(params)
	if not entry.is_empty():
		print("terrain cache: hit (%d ms)" % (Time.get_ticks_msec() - t0))
		Game.set_island(entry)
		_next.call_deferred()
		return
	print("terrain cache: miss")
	var screen := LoadingScene.instantiate()
	add_child(screen)
	screen.finished.connect(_on_generated.bind(t0))
	screen.start(params)

func _on_generated(entry: Dictionary, t0: int) -> void:
	if entry.get("error", -1) != 0:
		push_error("terrain generation failed: %s" % [entry.get("error")])
		get_tree().quit(1)
		return
	print("terrain cache: generated and stored (%d ms)" % (Time.get_ticks_msec() - t0))
	Game.set_island(entry)
	_next()
