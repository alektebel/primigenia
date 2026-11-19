extends SceneTree
# Read-only placement export for the C certification fixtures. Run headless with -- <output directory>.
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const Profile := preload("res://game/stage/profile.gd")
# River-gap checkpoints: the lowest dry cell on the 809 m circle around the start (core/src/terrain.c gap_trail), where the
# graded trail passes. They depend on the terrain, so they are pinned beside its hash and re-pinned with it.
const GAP := {1: [796.2890625, 138.8671875], 7: [768.1640625, 258.3984375], 42: [796.2890625, 138.8671875]}
const MOUTH_STAND_M := 6.0

func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var player: Dictionary = Profile.from_studio(Profile.load_json("res://game/data/merodeador.json"), manifest).profile
	for seed in [1, 7, 42]:
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = seed
		var entry: Dictionary = CporeTerrain.new().generate(p)
		TerrainData.prepare(entry)
		var data := TerrainData.new()
		data.setup(entry, false)
		var probe := CporeWorld.new()
		probe.set_field(entry)
		probe.reset({"terrain": 2})
		var setup: Dictionary = StageSetup.build(data, seed, player, StageSetup.garfio_profile(manifest), true, probe, true)
		var places := [{"id": "nest", "x": setup.nest.x, "z": setup.nest.y}]
		var seen := []
		for spawn in setup.wild:
			if int(spawn.species) in seen:
				continue
			seen.append(int(spawn.species))
			places.append({"id": ["Rondo", "Zanco", "Espinodo", "Garfio"][int(spawn.species)], "x": spawn.home_x, "z": spawn.home_z})
		var caves := []
		for cave in entry.caves:
			caves.append({"x": cave.position.x, "z": cave.position.z, "height": cave.position.y,
				"facing_x": cave.facing.x, "facing_z": cave.facing.z, "width": cave.size.x})
		var volcano: Vector4 = entry.volcano
		var route_places := places.duplicate(true)
		route_places.append({"id": "start-valley", "x": 30, "z": 20})
		route_places.append({"id": "lake-shore-water", "x": -75, "z": 70})
		route_places.append({"id": "river-gap", "x": GAP[seed][0], "z": GAP[seed][1]})
		route_places.append({"id": "hidden-cave-entrance", "x": caves[0].x + caves[0].facing_x * MOUTH_STAND_M, "z": caves[0].z + caves[0].facing_z * MOUTH_STAND_M})
		var pairs := []
		for place in route_places.slice(1):
			pairs.append(["nest", place.id])
		var out := {"seed": seed, "n": p.n, "terrain_hash": entry.hash, "player": player, "places": places,
			"route_places": route_places, "required_pairs": pairs, "caves": caves, "volcano": [volcano.x, volcano.y, volcano.z, volcano.w]}
		var file := FileAccess.open(output.path_join("seed%d.json" % seed), FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "\t"))
	quit()
