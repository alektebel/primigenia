extends RefCounted
# CporeWorld setup for the island (PLAN-heights H5): terrain 2 = the generated heightfield, read by the C
# world through CporeWorld.set_field(); ponds and the sea come from the field, the bound is half - 2 cells.

const Profile := preload("res://game/stage/profile.gd")

const BOUND := 195.0               # the valley the nest and the encounter are searched in
const GARFIO_DISTANCE := 60.0

# data: TerrainData. player_profile / garfio_profile: CporeWorld profile dictionaries.
# probe: a CporeWorld with the field attached and reset into terrain 2, so Garfio's path is also checked with the C walk rule.
static func build(data, seed: int, player_profile: Dictionary, garfio_profile: Dictionary, with_wild: bool = true, probe = null) -> Dictionary:
	var setup: Dictionary = CporeWorld.default_setup(seed)
	setup.terrain = 2
	var nest := find_nest(data)
	setup.nest = nest
	setup.water = Vector3.ZERO
	setup.player = player_profile
	setup.wild = []
	setup.obstacles = []
	if with_wild:
		var home = find_home(data, nest, probe)
		if home != null:
			var h: Vector2 = home
			setup.wild = [{"x": h.x, "z": h.y, "home_x": h.x, "home_z": h.y, "species": 3, "bot": -1, "profile": garfio_profile}]
	return setup

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
