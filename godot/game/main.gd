extends Node
# Boot: the stage menu opens at once; the island terrain is loaded only when Criatura is chosen (main_menu.gd).
# `--play`, `--agent` or a scenario skip the menu: terrain cache hit goes straight to the island, a miss shows the loading screen.

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

func _skips_menu() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--menu" in args:
		return false
	return "--play" in args or "--agent" in args or not Game.pending_scenario.is_empty()

func _next() -> void:
	Game.goto_island()

func _ready() -> void:
	# `--cell` after "--": straight into the cell stage, no terrain (tests and evidence).
	if "--cell" in OS.get_cmdline_user_args():
		Game.goto_cell.call_deferred()
		return
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
	if not _skips_menu():
		Game.goto_menu.call_deferred()
		return
	Game.enter_island()       # the terrain cache or generation and the island build, under the one loading screen
