extends SceneTree
# Read-only placement export for the C certification fixtures. Run headless with -- <output directory>.
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const Profile := preload("res://game/stage/profile.gd")
# River-gap checkpoints: the lowest dry cell on the 809 m circle around the start (core/src/terrain.c gap_trail), where the
# graded trail passes. They depend on the terrain, so they are pinned beside its hash and re-pinned with it.
const GAP := {1: [796.2890625, 138.8671875], 7: [768.1640625, 258.3984375], 42: [796.2890625, 138.8671875]}
const MOUTH_STAND_M := 6.0
const TerrainCache := preload("res://game/island/terrain_cache.gd")
# B1: with "star" as the second argument the export is the frozen Star massif (tests/routes/star-seed*.json): no river gap and no start-valley or
# lake-shore points (the nest valley is half lake); the four exits of the island data (the second point of each trail, 300 to 650 m out so a 0.5 m body
# makes the trip inside the 20000-tick budget; the outer ends are covered by test_nav's far targets), snapped to dry gentle ground, take their place,
# and the chamber is certified from the cave mouth (the 7.8 m nav grid of the 8 km island refuses a GO from far away into the passage; see tests/test_secrets.c).
const EXITS := {"exit-1-river-valley": Vector2(450, 420), "exit-2-north-pass": Vector2(250, -330), "exit-3-south-pass": Vector2(-200, 260), "exit-4-west-saddle": Vector2(-300, 100)}

static func snap_dry(data, p: Vector2) -> Vector2:
	for r in range(0, 80, 4):
		for k in (1 if r == 0 else 16):
			var a := k * TAU / 16.0
			var q := p + Vector2(sin(a), cos(a)) * r
			if data.ground(q.x, q.y) > 2.0 and not data.is_pond_at(q.x, q.y) and data.normal(q.x, q.y).y > 0.9:
				return q
	return p

func _initialize() -> void:
	var output := OS.get_cmdline_user_args()[0]
	var star := OS.get_cmdline_user_args().size() > 1 and OS.get_cmdline_user_args()[1] == "star"
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var player: Dictionary = Profile.from_studio(Profile.load_json("res://game/data/merodeador.json"), manifest).profile
	for seed in [1, 7, 42]:
		var p: Dictionary = TerrainCache.resolve(TerrainCache.game_params(seed)) if star else CporeTerrain.defaults()
		p.seed = seed
		var opts: Dictionary = TerrainCache.game_params(seed) if star else p
		var entry: Dictionary = CporeTerrain.new().generate(opts)
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
			if int(spawn.species) >= 6 or int(spawn.species) in seen:
				continue
			seen.append(int(spawn.species))
			places.append({"id": ["Rondo", "Zanco", "Espinodo", "Garfio", "Acechalunas", "Babosa"][int(spawn.species)], "x": spawn.home_x, "z": spawn.home_z})
		var caves := []
		for cave in entry.caves:
			caves.append({"x": cave.position.x, "z": cave.position.z, "height": cave.position.y,
				"facing_x": cave.facing.x, "facing_z": cave.facing.z, "width": cave.size.x})
		var volcano: Vector4 = entry.volcano
		var route_places := places.duplicate(true)
		if star:
			for id in EXITS:
				var q := snap_dry(data, EXITS[id])
				route_places.append({"id": id, "x": q.x, "z": q.y})
		else:
			route_places.append({"id": "start-valley", "x": 30, "z": 20})
			route_places.append({"id": "lake-shore-water", "x": -75, "z": 70})
			route_places.append({"id": "river-gap", "x": GAP[seed][0], "z": GAP[seed][1]})
		route_places.append({"id": "hidden-cave-entrance", "x": caves[0].x + caves[0].facing_x * MOUTH_STAND_M, "z": caves[0].z + caves[0].facing_z * MOUTH_STAND_M})
		# C2 secrets: the five shards and the hidden cave chamber, as the C world derives them from this island
		var secrets_probe := CporeWorld.new()
		secrets_probe.set_field(entry)
		assert(secrets_probe.reset(setup) == 0)
		var secrets_state: Dictionary = secrets_probe.state()
		for item in secrets_state.shards.items:
			route_places.append({"id": "shard-%d" % (int(item.index) + 1), "x": item.x, "z": item.z})
		route_places.append({"id": "cave-chamber", "x": secrets_state.cave.chamber_x, "z": secrets_state.cave.chamber_z})
		var pairs := []
		for place in route_places.slice(1):
			if not (star and place.id == "cave-chamber"):
				pairs.append(["nest", place.id])
		if star:
			pairs.append(["hidden-cave-entrance", "cave-chamber"])
		var out := {"seed": seed, "n": p.n, "terrain_hash": entry.hash, "player": player, "places": places,
			"route_places": route_places, "required_pairs": pairs, "caves": caves, "volcano": [volcano.x, volcano.y, volcano.z, volcano.w]}
		if star:
			out["min_legs"] = {"exit-2-north-pass": 4, "exit-3-south-pass": 4, "exit-4-west-saddle": 4}   # the passes: no two-legged body (grade 0.8+)
		var file := FileAccess.open(output.path_join(("star-seed%d.json" if star else "seed%d.json") % seed), FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "\t"))
	quit()
