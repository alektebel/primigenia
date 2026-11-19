extends SceneTree
# Read-only placement export for the C certification fixtures. Run headless with -- <output directory>.
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const Profile := preload("res://game/stage/profile.gd")
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
		route_places.append({"id": "river-gap", "x": 800, "z": 120})
		route_places.append({"id": "hidden-cave-entrance", "x": caves[0].x, "z": caves[0].z})
		var pairs := []
		for place in route_places.slice(1):
			pairs.append(["nest", place.id])
		var out := {"seed": seed, "n": p.n, "terrain_hash": entry.hash, "player": player, "places": places,
			"route_places": route_places, "required_pairs": pairs, "caves": caves, "volcano": [volcano.x, volcano.y, volcano.z, volcano.w]}
		var file := FileAccess.open(output.path_join("seed%d.json" % seed), FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "\t"))
	quit()
