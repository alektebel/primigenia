extends SceneTree
# Regenerates the curated scenarios in godot/scenarios/creature/ (run after an engine or terrain change):
#   godot --headless --path godot --script res://devtools/tools/make_scenarios.gd
# Each is built by a session from reset (setup + debug ops) on the seed-1 island, so it keeps its recipe.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Profile := preload("res://game/stage/profile.gd")
const Scenario := preload("res://devtools/scenario.gd")

const OUT := "res://scenarios/creature"

func _initialize() -> void:
	_run.call_deferred()

func _slope_deg(data, x: float, z: float) -> float:
	var n: Vector3 = data.normal(x, z)
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

func _session(entry: Dictionary, data, with_wild: bool) -> Dictionary:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome := Profile.load_json("res://game/data/merodeador.json")
	var player: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	sw.world.reset({"terrain": 2})
	var setup: Dictionary = StageSetup.build(data, 1, player, garfio, with_wild, sw.world)
	sw.reset(setup)
	sw.input_provider = func() -> Dictionary: return {}
	var ctx := {"genome": genome, "island": {"seed": 1, "terrain_version": CporeTerrain.version(), "terrain_hash": entry.hash}, "camera": {}}
	return {"sw": sw, "ctx": ctx}

func _save(s: Dictionary, name: String, note: String) -> void:
	var err := Scenario.save(s.sw, s.ctx, "%s/%s" % [OUT, name], "scenario", note)
	print("%s: %s (tick %d)" % [name, "ok" if err == "" else err, int(s.sw.cur.tick)])
	if err != "":
		quit(1)

func _run() -> void:
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = 1
		entry = CporeTerrain.new().generate(p)
		TerrainData.prepare(entry)
	var data = TerrainData.new()
	data.setup(entry, false)
	# 1. the start of a game
	var a := _session(entry, data, true)
	_save(a, "nest_start", "The start of a game: at the nest, Garfio at its home 60 m away.")
	# 2. 8 m from Garfio, not fighting
	var b := _session(entry, data, true)
	var w: Dictionary = b.sw.cur.entities[1]
	var toward := (Vector2(0, 0) - Vector2(w.x, w.z)).normalized()
	var spot := Vector2(w.x, w.z) + toward * 8.0
	var rc: int = b.sw.debug_now({"op": 1, "id": 0, "x": spot.x, "z": spot.y})
	if rc != 0:
		printerr("teleport rejected: ", CporeWorld.debug_error(rc))
		quit(1)
		return
	_save(b, "garfio_close", "The player is 8 m from Garfio, not fighting yet. Good for the first exchange and for combat tuning.")
	# 3. a slope far from the valley
	var c := _session(entry, data, false)
	var found = null
	for r in range(500, 1200, 20):
		for k in 24:
			var ang := k * TAU / 24.0
			var x := sin(ang) * r
			var z := cos(ang) * r
			if StageSetup.dry(data, x, z) and _slope_deg(data, x, z) > 18.0 and _slope_deg(data, x, z) < 32.0 and StageSetup.dry(data, x + 6, z) and _slope_deg(data, x + 6, z) < 38.0:
				found = Vector2(x, z)
				break
		if found != null:
			break
	if found == null:
		printerr("no far slope found")
		quit(1)
		return
	var rc3: int = c.sw.debug_now({"op": 1, "id": 0, "x": found.x, "z": found.y})
	print("far spot ", found, " rc ", rc3)
	_save(c, "far_meadow", "A slope about %d m from the nest, no creatures near: to look at the island heights and the camera on slopes." % int(found.length()))
	quit(0)
