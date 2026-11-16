extends RefCounted
# CporeWorld setup for the island. M0 gap (documented): the C world has only analytic and flat
# height sources and a hard +-195 m bound, so it runs FLAT at the valley floor height; island
# heights are visual only (BACKLOG 6 wires the generated heightfield into C).

const Profile := preload("res://game/stage/profile.gd")

const FLAT_HEIGHT := 42.0          # valley_floor_m
const BOUND := 195.0
const GARFIO_DISTANCE := 60.0

# data: TerrainData. player_profile / garfio_profile: CporeWorld profile dictionaries.
static func build(data, seed: int, player_profile: Dictionary, garfio_profile: Dictionary, with_wild: bool = true) -> Dictionary:
	var setup: Dictionary = CporeWorld.default_setup(seed)
	setup.terrain = 1
	setup.flat_height = FLAT_HEIGHT
	var water := water_circle(data)
	var nest := find_nest(data, water)
	setup.nest = nest
	setup.water = water
	setup.player = player_profile
	setup.wild = []
	setup.obstacles = []
	if with_wild:
		var home = find_home(data, nest)
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

# The C world knows one water circle. Use the largest connected pond (4-neighbour) inside the
# playable square: its centroid and equivalent radius; radius 0 if there is none. (All ponds
# together would give a circle covering half the valley.)
static func water_circle(data) -> Vector3:
	var lo := maxi(0, floori((-BOUND + data.half) / data.cell))
	var hi := mini(data.n - 1, floori((BOUND + data.half) / data.cell))
	var span := hi - lo + 1
	var seen := PackedByteArray()
	seen.resize(span * span)
	var best_count := 0
	var best := Vector2.ZERO
	for j0 in range(lo, hi + 1):
		for i0 in range(lo, hi + 1):
			if seen[(j0 - lo) * span + (i0 - lo)] == 1 or not _pond_in(data, i0, j0):
				continue
			var stack := [Vector2i(i0, j0)]
			seen[(j0 - lo) * span + (i0 - lo)] = 1
			var count := 0
			var sum := Vector2.ZERO
			while not stack.is_empty():
				var c: Vector2i = stack.pop_back()
				count += 1
				sum += Vector2(data.cell_center(c.x), data.cell_center(c.y))
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var q: Vector2i = c + d
					if q.x < lo or q.y < lo or q.x > hi or q.y > hi:
						continue
					var si := (q.y - lo) * span + (q.x - lo)
					if seen[si] == 0 and _pond_in(data, q.x, q.y):
						seen[si] = 1
						stack.append(q)
			if count > best_count:
				best_count = count
				best = sum / count
	if best_count == 0:
		return Vector3.ZERO
	return Vector3(best.x, best.y, sqrt(best_count * data.cell * data.cell / PI))

static func _pond_in(data, i: int, j: int) -> bool:
	return absf(data.cell_center(i)) <= BOUND and absf(data.cell_center(j)) <= BOUND and data.is_pond(j * data.n + i)

# First of 64 directions at 60 m whose straight path from the nest is dry and gentle.
static func find_home(data, nest: Vector2):
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
		if ok:
			return target
	return null

static func garfio_profile(manifest: Dictionary) -> Dictionary:
	var genome := Profile.load_json("res://game/data/garfio.json")
	var base: Dictionary = Profile.from_studio(genome, manifest).profile
	var tiers := Profile.load_json("res://game/data/garfio-combat.json")
	for k in tiers:
		base[k] = tiers[k]
	return base
