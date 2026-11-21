extends RefCounted
# C2 secrets through the Godot bridge: the island setup (species 4 and 5, shards, cave), state().shards / cave / day / species,
# the cave ground rule mirrored in GDScript, shard pickup, nocturnal hiding.

const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const CaveSite := preload("res://game/island/cave_site.gd")
const Profile := preload("res://game/stage/profile.gd")

func run(t) -> void:
	var p: Dictionary = CporeTerrain.defaults()
	p.seed = 1
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var data := TerrainData.new()
	data.setup(entry, false)
	var world := CporeWorld.new()
	t.eq(world.set_field(entry), 0, "field attached")
	world.reset({"terrain": 2})
	var manifest: Dictionary = Profile.load_json("res://game/data/parts.json")
	var player: Dictionary = Profile.from_studio(Profile.load_json("res://game/data/merodeador.json"), manifest).profile
	var setup: Dictionary = StageSetup.build(data, 1, player, StageSetup.garfio_profile(manifest), true, world, true)
	t.eq(int(setup.secrets), 3, "setup asks for shards and the cave")
	t.eq(int(setup.start_clock), StageSetup.CLOCK_START, "a new game starts in the morning")
	t.check(setup.has("cave") and abs(float(setup.cave.x) - float(data.caves[0].position.x)) < 0.001, "the cave record is the terrain's first entrance")
	var counts := {}
	for w in setup.wild:
		counts[int(w.species)] = int(counts.get(int(w.species), 0)) + 1
	t.check(int(counts.get(4, 0)) >= 2 and int(counts.get(5, 0)) >= 2, "Acechalunas (%s) and Babosa (%s) herds exist" % [counts.get(4, 0), counts.get(5, 0)])
	t.eq(int(counts.get(6, 0)), 4, "four real Brujula")
	t.eq(int(counts.get(7, 0)), 2, "two real Corona")
	t.check(setup.wild.size() <= 24, "within the 24 creature cap (%d)" % setup.wild.size())
	t.eq(world.reset(setup), 0, "the C world accepts the island setup")
	var st: Dictionary = world.state()
	t.eq(st.shards.items.size(), 5, "five shards in state().shards")
	t.eq(int(st.shards.found), 0, "none found yet")
	t.check(not st.shards.items[0].has("line"), "the story line stays hidden until found")
	t.check(bool(st.cave.enabled), "state().cave.enabled")
	t.eq(st.species.size(), 8, "state().species lists eight species")
	t.eq(String(st.species[4].name), "Acechalunas", "species 4")
	t.eq(String(st.species[5].name), "Babosa", "species 5")
	t.eq(String(st.day.phase), "day", "08:00 is day")
	t.eq(int(st.day.light), 1000, "full light in the morning")
	var sp: Array = CporeWorld.species()
	t.eq(sp.size(), 8, "species() has eight entries")
	t.check(bool(sp[4].nocturnal) and String(sp[5].activity_name) == "crepuscular", "activity flags")
	# nocturnal creatures sleep by day: hidden entities are flagged, they come out at night
	var hidden_day := 0
	for e in st.entities:
		if int(e.get("species", -1)) == 4 and int(e.id) > 0 and bool(e.hidden):
			hidden_day += 1
	t.eq(hidden_day, int(counts.get(4, 0)), "every Acechalunas is hidden by day")
	t.eq(world.debug({"op": 5, "a": 11500}), 0, "clock to 23:00")
	var night: Dictionary = world.state()
	var hidden_night := 0
	for e in night.entities:
		if int(e.get("species", -1)) == 4 and int(e.id) > 0 and bool(e.hidden):
			hidden_night += 1
	t.eq(hidden_night, 0, "none hidden at night")
	t.eq(String(night.day.phase), "night", "23:00 is night")
	world.debug({"op": 5, "a": 4500})
	# the cave rule in GDScript equals the C ground, point by point
	var site = CaveSite.from_state(st.cave)
	t.check(site.on, "CaveSite built from state().cave")
	var worst := 0.0
	var checked := 0
	var cv: Dictionary = st.cave
	for u in range(-9, 36, 3):
		for v in range(-7, 8, 2):
			var x: float = float(cv.x) - float(cv.fx) * u - float(cv.fz) * v
			var z: float = float(cv.z) - float(cv.fz) * u + float(cv.fx) * v
			var raw: float = data.ground(x, z)
			var mine: float = site.adjust(x, z, raw)
			worst = maxf(worst, absf(mine - float(world.ground(x, z))))
			checked += 1
	t.check(worst < 0.05, "GDScript cave ground equals the C ground at %d points (worst %.5f m; the wall ramp scales the 0.001 m rounding of the JSON numbers)" % [checked, worst])
	# zone parity with C and the walkable chamber
	t.eq(site.zone(float(cv.chamber_x), float(cv.chamber_z)), 2, "chamber centre is zone 2")
	t.eq(world.debug({"op": 1, "id": 0, "x": float(cv.chamber_x), "z": float(cv.chamber_z)}), 0, "teleport into the chamber")
	world.step({})
	t.eq(int(world.state().cave.inside), 2, "C says the player is in the chamber")
	t.check(bool(world.state().cave.chamber_entered), "chamber entry recorded")
	# collect a shard
	var item: Dictionary = st.shards.items[0]
	t.eq(world.debug({"op": 1, "id": 0, "x": float(item.x) - 1.0, "z": float(item.z)}), 0, "teleport beside shard 1")
	t.eq(world.order({"verb": 16, "target": int(item.id)}), 0, "inspect collects the shard")
	var after: Dictionary = world.state()
	t.eq(int(after.shards.found), 1, "one shard found")
	t.check(after.shards.items[0].has("line") and after.shards.items[0].has("line_es"), "the line (en and es) is revealed")
	t.check(int(after.social.dna_total) >= 5, "the shard paid DNA")
	var seen := false
	for ev in after.social_events:
		if int(ev.type) == 25:
			seen = true
	t.check(seen, "shard_found event (25) is in social_events")
	t.check(load("res://game/stage/shard_nodes.gd").can_instantiate() and load("res://game/island/day_night.gd").can_instantiate(), "shard and day/night scripts load")
