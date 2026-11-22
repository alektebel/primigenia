extends RefCounted
# CporeWorld setup for the island (PLAN-heights H5): terrain 2 = the generated heightfield, read by the C
# world through CporeWorld.set_field(); ponds and the sea come from the field, the bound is half - 2 cells.

const RadialFauna := preload("res://game/island/radial_fauna.gd")

const Profile := preload("res://game/stage/profile.gd")

const BOUND := 195.0               # the valley the nest and the encounter are searched in
const GARFIO_DISTANCE := 60.0
const CLOCK_START := 4000          # world clock at tick 0: 08:00 (500 ticks an hour, 0 = midnight), so a new game starts in the morning

# data: TerrainData. player_profile / garfio_profile: CporeWorld profile dictionaries.
# probe: a CporeWorld with the field attached and reset into terrain 2, so Garfio's path is also checked with the C walk rule.
static func build(data, seed: int, player_profile: Dictionary, garfio_profile: Dictionary, with_wild: bool = true, probe = null, herds: bool = false, secrets: bool = true, radial_plan_out: Dictionary = {}) -> Dictionary:
	var setup: Dictionary = CporeWorld.default_setup(seed)
	setup.terrain = 2
	var nest := find_nest(data)
	setup.nest = nest
	setup.water = Vector3.ZERO
	setup.player = player_profile
	setup.wild = []
	setup.obstacles = []
	setup.start_clock = CLOCK_START
	if secrets:
		# C2 secrets (docs/SECRETS-REPORT.md): the C world places the five meteor shards from the island field and opens the
		# hidden cave chamber behind the first (gameplay) cave entrance of the terrain.
		setup.secrets = 3
		if data.caves.size() > 0:
			var cave = data.caves[0]
			setup.cave = {"x": cave.position.x, "z": cave.position.z, "fx": cave.facing.x, "fz": cave.facing.z}
	if with_wild:
		var home = find_home(data, nest, probe)
		if home != null:
			var h: Vector2 = home
			setup.wild = [{"x": h.x, "z": h.y, "home_x": h.x, "home_z": h.y, "species": 3, "bot": -1, "profile": garfio_profile}]
		if herds:
			add_herds(setup, data, nest, probe)
			add_night_and_slug(setup, data, nest, probe)
			radial_plan_out.merge(add_radial(setup, data, seed, nest), true)
	return setup

# C2 (docs/P4.md 2.2): the valley holds more than Garfio so the Q43 loop has something to resolve. Rondo, Zanco and Espinodo
# each get a small group at a dry, gentle, reachable spot at HERD_DISTANCE from the nest, in directions that differ per species.
# Appended after Garfio, so entity 1 stays Garfio.
const HERD_DISTANCE := [85.0, 110.0, 140.0]
const HERD_COUNT := [4, 4, 3]
const HERD_ARC := [0.16, 0.41, 0.66]       # first direction to try, as a fraction of the circle

static func add_herds(setup: Dictionary, data, nest: Vector2, probe = null) -> void:
	var species: Array = CporeWorld.species()
	var taken: Array = []
	for w in setup.wild:
		taken.append(Vector2(w.home_x, w.home_z))
	for s in 3:
		var base = find_spot(data, nest, HERD_DISTANCE[s], HERD_ARC[s], probe, taken)
		if base == null:
			continue
		var b: Vector2 = base
		taken.append(b)
		var placed := 0
		for k in 12:
			if placed >= HERD_COUNT[s]:
				break
			var a := k * TAU / 12.0
			var p := b + Vector2(sin(a), cos(a)) * (3.0 + 2.0 * (k % 3)) if k > 0 else b
			if not dry(data, p.x, p.y) or absf(p.x) > BOUND - 1.0 or absf(p.y) > BOUND - 1.0:
				continue
			setup.wild.append({"x": p.x, "z": p.y, "home_x": b.x, "home_z": b.y, "species": s, "bot": -1, "profile": species[s].profile})
			placed += 1

static func find_spot(data, nest: Vector2, distance: float, arc: float, probe, taken: Array):
	for j in 64:
		var a := (arc + j / 64.0) * TAU
		var target := nest + Vector2(sin(a), cos(a)) * distance
		if absf(target.x) > BOUND - 12.0 or absf(target.y) > BOUND - 12.0:
			continue
		var near := false
		for t in taken:
			if (t as Vector2).distance_to(target) < 45.0:
				near = true
		if near:
			continue
		var ok := true
		for s in 21:
			var p := nest.lerp(target, s / 20.0)
			if not dry(data, p.x, p.y) or data.normal(p.x, p.y).y <= 0.8:
				ok = false
				break
		if ok and (probe == null or probe.can_walk(nest.x, nest.y, target.x, target.y, 0.6)):
			return target
	return null

static func dry(data, x: float, z: float) -> bool:
	return data.ground(x, z) > 1.0 and not data.is_pond_at(x, z)

static func clear_of_water(x: float, z: float, water: Vector3) -> bool:
	return water.z <= 0.0 or Vector2(x, z).distance_to(Vector2(water.x, water.y)) > water.z + 4.0

# The valley centre, or the nearest dry meadow cell on an expanding ring.
static func find_nest(data, water: Vector3 = Vector3.ZERO) -> Vector2:
	if dry(data, 0.0, 0.0) and clear_of_water(0.0, 0.0, water):
		return Vector2.ZERO
	for radius in range(5, 190, 5):
		for k in 32:
			var a := k * TAU / 32.0
			var x := sin(a) * radius
			var z := cos(a) * radius
			if dry(data, x, z) and clear_of_water(x, z, water):
				return Vector2(x, z)
	return Vector2.ZERO

# First of 64 directions at 60 m whose straight path from the nest is dry and gentle.
static func find_home(data, nest: Vector2, probe = null):
	for k in 64:
		var a := k * TAU / 64.0
		var target := nest + Vector2(sin(a), cos(a)) * GARFIO_DISTANCE
		if absf(target.x) > BOUND - 1.0 or absf(target.y) > BOUND - 1.0:
			continue
		var ok := true
		for s in 21:
			var p := nest.lerp(target, s / 20.0)
			if not dry(data, p.x, p.y) or data.normal(p.x, p.y).y <= 0.8:
				ok = false
				break
		if ok and (probe == null or probe.can_walk(nest.x, nest.y, target.x, target.y, 0.6)):
			return target
	return null

static func garfio_profile(manifest: Dictionary) -> Dictionary:
	var genome := Profile.load_json("res://game/data/garfio.json")
	var base: Dictionary = Profile.from_studio(genome, manifest).profile
	var tiers := Profile.load_json("res://game/data/garfio-combat.json")
	for k in tiers:
		base[k] = tiers[k]
	return base

# C2 secrets: the nocturnal Acechalunas (species 4) sleep by day near the hidden cave: their home is on the cave's graded apron,
# 14 m in front of the entrance. The sixth species, Babosa (species 5), grazes the damp slope of the valley.
const NIGHT_COUNT := 3
const SLUG_COUNT := 3 # Three still resolve an ally species; leaves room for six radial animals (24 total).
# Integration fix: evolving spawns a cousin, which needs a free wild slot (CP_STAGE_MAX_WILD 24), so the radial animals stop at 23. Owner: how many free slots for cousins?
const RADIAL_WILD_CAP := 23
const SLUG_DISTANCE := 125.0
const SLUG_ARC := 0.86

static func add_night_and_slug(setup: Dictionary, data, nest: Vector2, probe = null) -> void:
	var species: Array = CporeWorld.species()
	if setup.has("cave"):
		var c: Dictionary = setup.cave
		var mouth := Vector2(c.x, c.z)
		var f := Vector2(c.fx, c.fz)
		var perp := Vector2(-f.y, f.x)
		var placed: Array = []
		for d in [10.0, 14.0, 18.0, 22.0, 26.0, 30.0, 36.0]:
			for lat in [0.0, -4.0, 4.0, -8.0, 8.0]:
				if placed.size() >= NIGHT_COUNT:
					break
				var p: Vector2 = mouth + f * d + perp * lat
				if not dry(data, p.x, p.y) or data.normal(p.x, p.y).y <= 0.8 or absf(p.x) > 1700.0 or absf(p.y) > 1700.0:
					continue
				var near := false
				for q in placed:
					if (q as Vector2).distance_to(p) < 4.0:
						near = true
				if not near:
					placed.append(p)
		for k in placed.size():
			var base: Vector2 = placed[0]
			setup.wild.append({"x": placed[k].x, "z": placed[k].y, "home_x": base.x, "home_z": base.y, "species": 4, "bot": -1, "profile": species[4].profile})
	var taken: Array = []
	for w in setup.wild:
		taken.append(Vector2(w.home_x, w.home_z))
	var spot = find_spot(data, nest, SLUG_DISTANCE, SLUG_ARC, probe, taken)
	if spot == null:
		return
	var b: Vector2 = spot
	var n := 0
	for k in 12:
		if n >= SLUG_COUNT:
			break
		var a := k * TAU / 12.0
		var p := b + Vector2(sin(a), cos(a)) * (3.0 + 2.0 * (k % 3)) if k > 0 else b
		if not dry(data, p.x, p.y) or absf(p.x) > BOUND - 1.0 or absf(p.y) > BOUND - 1.0:
			continue
		setup.wild.append({"x": p.x, "z": p.y, "home_x": b.x, "home_z": b.y, "species": 5, "bot": -1, "profile": species[5].profile})
		n += 1

# The same habitat planner used by ambient fauna; only cuarteta remains ambient.
static func add_radial(setup: Dictionary, data, seed: int, nest: Vector2) -> Dictionary:
	var placement := RadialFauna.plan(data, seed, nest)
	var species: Array = CporeWorld.species()
	for id in ["corona", "brujula"]:   # corona first: the cap trims a Brujula (4 -> 3), both Corona stay
		var sp := 6 if id == "brujula" else 7
		var spots: Array = placement[id].spots
		for p: Vector2 in spots:
			if setup.wild.size() >= RADIAL_WILD_CAP:
				break
			# Each animal keeps its coastal microhabitat as its home.
			setup.wild.append({"x": p.x, "z": p.y, "home_x": p.x, "home_z": p.y,
				"species": sp, "bot": -1, "legs": 5 if sp == 6 else 6, "profile": species[sp].profile})

	return placement
