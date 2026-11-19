extends SceneTree
# Re-saves one scenario in the current snapshot format by rebuilding it from its recipe (use after a snapshot bump for scenarios
# make_scenarios.gd does not build, e.g. flight_cliff):
#   godot --headless --path godot --script res://devtools/tools/regen_scenario.gd -- creature/flight_cliff

const StageWorld := preload("res://game/stage/stage_world.gd")
const Scenario := preload("res://devtools/scenario.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var name: String = OS.get_cmdline_user_args()[0]
	var parsed := Scenario.read(name)
	if not parsed.ok:
		printerr(parsed.error)
		quit(1)
		return
	var entry := TerrainCache.load_entry({"seed": 1})
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	var res := Scenario.load_into(parsed, sw)
	if not res.ok:
		printerr(res.error)
		quit(1)
		return
	var d: Dictionary = parsed.dict
	var ctx := {"genome": d.get("genome", {}), "island": d.get("island", {}), "camera": d.get("camera", {}), "plants": d.get("plants", []),
		"tuning": d.get("tuning", {}), "time": d.get("time", {})}
	var err := Scenario.save(sw, ctx, Scenario.resolve(name).trim_suffix(".json"), String(d.get("kind", "scenario")), String(d.get("note", "")))
	print("regenerated %s: %s (rebuilt %s)" % [name, "ok" if err == "" else err, res.rebuilt])
	quit(0 if err == "" else 1)
