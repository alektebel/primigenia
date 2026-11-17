extends RefCounted
# The curated scenarios in godot/scenarios/: each has its recipe, loads on the seed-1 island, and its recipe rebuilds the same state.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Scenario := preload("res://devtools/scenario.gd")
const WorldLog := preload("res://game/stage/world_log.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func run(t) -> void:
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = 1
		entry = CporeTerrain.new().generate(p)
	var names := Scenario.list_names()
	var curated := PackedStringArray()
	for n in names:
		if FileAccess.file_exists("res://scenarios/%s.json" % n):
			curated.append(n)
	t.check(curated.size() >= 3, "at least three curated scenarios (%s)" % [curated])
	for n in curated:
		var parsed := Scenario.read(n)
		t.check(parsed.ok, "%s reads: %s" % [n, parsed.get("error", "")])
		if not parsed.ok:
			continue
		t.check(parsed.recipe != "", "%s keeps its recipe" % n)
		var sw = StageWorld.new()
		t.eq(sw.world.set_field(entry), 0, "%s: island attaches" % n)
		var res := Scenario.load_into(parsed, sw)
		t.check(res.ok and not res.rebuilt, "%s loads (%s)" % [n, res.get("error", "")])
		var rec: Dictionary = WorldLog.parse(parsed.recipe)
		var sw2 = StageWorld.new()
		sw2.world.set_field(entry)
		t.eq(sw2.replay_recipe(rec), 0, "%s: the recipe replays" % n)
		t.eq(sw2.world.state().hash, parsed.dict.hash, "%s: the recipe rebuilds the saved state" % n)
