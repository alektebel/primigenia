extends RefCounted

const RECIPES := "res://game/data/flora.json"
const SPACING := 20.0
const MAX_GRADE := 1.26

static func recipes() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string(RECIPES))

# Query the very triangle holding the root. A smoothed shading normal can hide a cliff edge.
static func facet(d, p: Vector2) -> Vector3:
	var cell: float = d.vcell if d.vn > 0 else d.cell
	var grid: Vector2 = (p + Vector2.ONE * d.half) / cell - Vector2.ONE * 0.5
	var corner: Vector2 = (grid.floor() + Vector2.ONE * 0.5) * cell - Vector2.ONE * d.half
	var a: float = d.visual_ground(corner.x, corner.y)
	var b: float = d.visual_ground(corner.x + cell, corner.y + cell)
	if grid.x - floorf(grid.x) >= grid.y - floorf(grid.y):
		var m: float = d.visual_ground(corner.x + cell, corner.y)
		return Vector3(a - m, cell, m - b).normalized()
	var m: float = d.visual_ground(corner.x, corner.y + cell)
	return Vector3(m - b, cell, a - m).normalized()

static func bank(d, p: Vector2) -> bool:
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(0.71, 0.71), Vector2(-0.71, 0.71), Vector2(0.71, -0.71), Vector2(-0.71, -0.71)]:
		for radius in [d.cell, maxf(8, d.cell * 2), maxf(20, d.cell * 4), maxf(32, d.cell * 6)]:
			var q: Vector2 = p + dir * radius
			var k: int = d.cell_index(q.x, q.y)
			if d.is_river(k) or d.is_pond(k):
				return true
	return false

static func clear(p: Vector2, reserved: Array) -> bool:
	for center: Vector2 in reserved:
		if p.distance_squared_to(center) < 100:
			return false
	return true

# The water ribbon can extend beyond the classified cell. Cover its photographic
# banks conservatively, including the two smoothing passes in rivers.gd.
static func river_mask(d) -> PackedByteArray:
	var blocked := PackedByteArray()
	blocked.resize(d.n * d.n)
	for k in d.river.size():
		if (d.river[k] & 3) == 0:
			continue
		var area: float = d.flow[k] * d.size_m * d.size_m
		var radius: float = preload("res://game/island/rivers.gd").width_for(area) * 0.5 / d.cell + 2.0
		var span := ceili(radius)
		var x: int = k % d.n
		var z: int = k / d.n
		for j in range(maxi(0, z - span), mini(d.n, z + span + 1)):
			var dx := floori(sqrt(maxf(0.0, radius * radius - (j - z) * (j - z))))
			for i in range(maxi(0, x - dx), mini(d.n, x + dx + 1)):
				blocked[j * d.n + i] = 1
	return blocked

static func site(d, p: Vector2, reserved: Array, blocked: PackedByteArray) -> Dictionary:
	if absf(p.x) >= d.half or absf(p.y) >= d.half:
		return {}
	var k: int = d.cell_index(p.x, p.y)
	if blocked[k] or d.is_pond(k) or not clear(p, reserved):
		return {}
	var h: float = d.visual_ground(p.x, p.y)
	if h < -0.65 or (d.is_sea(k) and d.height[k] < -0.65):
		return {}
	var up := facet(d, p)
	var min_y := 1.0 / sqrt(1.0 + MAX_GRADE * MAX_GRADE)
	if up.y < min_y or d.normal(p.x, p.y).y < min_y:
		return {}
	return {"p":p,"h":h,"up":up,"k":k,"sea":d.is_sea(k) or h <= 0}

# No impact site is exported by terrain v5. Use a seeded dry lowland basin
# and one bent deposit trace, separate from the summit's volcanic caldera.
static func impact_basin(d, world_seed: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed,"impact"])
	var best := -INF
	var center := Vector2.INF
	for i in 256:
		var p := Vector2(rng.randf_range(-0.7, 0.7), rng.randf_range(-0.7, 0.7)) * float(d.half)
		var k: int = d.cell_index(p.x, p.y)
		if p.length() < 400 or d.height[k] < 15 or d.is_pond(k) or d.height[k] > 280:
			continue
		var rim := 0.0
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			var q: Vector2 = p + dir * 250
			rim += d.ground(q.x, q.y)
		var score: float = rim * 0.25 - d.height[k]
		if score > best:
			best = score
			center = p
	return center

static func habitats(d, s: Dictionary, noise: FastNoiseLite, impact: Vector2, reserved := []) -> Array:
	var p: Vector2 = s.p
	var h: float = s.h
	var mat: int = d.material[s.k]
	if s.sea:
		return ["tidal"]
	var wet: float = d.surface[s.k * 4 + 3] / 255.0
	var pocket := noise.get_noise_2dv(p)
	var near_bank := bank(d, p)
	var zones := []
	if mat == 4 and h < 12:
		zones.append("spray")
	if near_bank:
		zones.append("bank")
	if mat == 5 and s.up.y > 0.78 and d.relief[s.k * 4 + 1] >= 126:
		zones.append("snowline")
	if mat == 3:
		if wet > 0.45 and pocket > 0.42:
			zones.append("mineral_seep")
		elif wet > 0.32 and pocket > 0:
			zones.append("lava_seep")
		elif pocket > -0.12:
			zones.append("lava_crack")
		else:
			zones.append("bare_lava")
	if mat == 1 and wet > 0.22:
		zones.append("bare_lava")
	var ray := p - impact
	var ejecta := ray.x > 0 and ray.x < 570 and absf(ray.y - 0.22 * minf(ray.x, 280) + 0.35 * maxf(0, ray.x - 280)) < 24
	if (ray.length_squared() < 210 * 210 or ejecta) and pocket > 0.12:
		zones.append("crater")
	for cave in d.caves:
		var cp: Vector3 = cave.position
		if p.distance_squared_to(Vector2(cp.x, cp.z)) < 28 * 28:
			zones.append_array(["cave","shade","litter"])
			break
	if p.x < -110 and mat in [0, 1, 3] and (mat != 3 or (wet > 0.45 and pocket > 0.2)) and pocket > -0.28 and h >= 80 and h <= 950:
		zones.append_array(["forest","litter","shade"])
	elif mat == 0 and h < 300:
		zones.append("meadow")
	# Start-valley habitats (east of the western fog forest, on soil, away from the sea).
	if mat == 0 and p.x >= -110 and not s.sea:
		if h >= 15 and h <= 400 and s.up.y > 0.94 and pocket > 0.0:
			zones.append("hollow")
		if near_bank and h >= 15 and h <= 350:
			zones.append("wet_fringe")
		if h >= 30 and h <= 550 and s.up.y > 0.8 and s.up.y < 0.96 and pocket > 0.18 and p.length() > 60:
			zones.append("valley_edge")
		for i in reserved.size():
			var dist: float = p.distance_to(reserved[i])
			if dist > 10 and dist < 80 and h >= 15 and h <= 450 and pocket > -0.2:
				zones.append("disturbed")
				break
	if near_bank:
		zones.append("shade")
	return zones

static func record(r: Dictionary, s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var h := rng.randf_range(r.height[0], r.height[1])
	var p: Vector2 = s.p
	return {"id":r.id,"p":Vector3(p.x, s.h, p.y),"height":h,"yaw":rng.randf() * TAU,"variant":rng.randi() % 2,"up":s.up}

# In the absence of a named dyke, choose the nearest eligible freshwater margin east of the start.
static func spring_site(d, reserved: Array, r: Dictionary, blocked: PackedByteArray) -> Dictionary:
	for radius in range(30, 1500, 6):
		for j in 33:
			var p: Vector2 = reserved[0] + Vector2.RIGHT.rotated((j - 16) * PI / 36) * radius
			if absf(p.x) >= d.half or absf(p.y) >= d.half:
				continue
			var s := site(d, p, reserved, blocked)
			if not s.is_empty() and s.h >= r.altitude[0] and s.h <= r.altitude[1] and bank(d, p):
				return s
	return {}

static func generate(d, setup: Dictionary, world_seed: int, density: float, rows: Array) -> Array:
	var reserved := [setup.nest]
	for wild in setup.wild:
		reserved.append(Vector2(wild.x, wild.z))
	var camps := reserved.duplicate()
	var by_zone := {}
	for r in rows:
		if not by_zone.has(r.habitat):
			by_zone[r.habitat] = []
		by_zone[r.habitat].append(r)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.frequency = 0.006
	var out := []
	var blocked := river_mask(d)
	var impact := impact_basin(d, world_seed)
	for r in by_zone.get("spring", []):
		var s := spring_site(d, reserved, r, blocked)
		if not s.is_empty():
			append_plant(out, r, s, rng, by_zone)
			reserved.append(s.p)
	var side := ceili(d.size_m / SPACING)
	for z in side:
		for x in side:
			rng.seed = hash(Vector3i(world_seed, x, z))
			if rng.randf() >= density:
				continue
			var p: Vector2 = (Vector2(x + rng.randf(), z + rng.randf()) * SPACING) - Vector2.ONE * d.half
			if p.x >= d.half or p.y >= d.half:
				continue
			var s := site(d, p, reserved, blocked)
			if s.is_empty():
				continue
			var zones := habitats(d, s, noise, impact, camps)
			var mat: int = d.material[s.k]
			if not s.sea and mat in [1, 2, 3] and rng.randf() < 0.32:
				var kind := "scree" if mat == 2 else ("outcrop" if s.up.y < 0.81 else "boulder")
				var sizes := [0.18, 0.72] if kind == "scree" else ([1.7, 5.6] if kind == "outcrop" else [0.55, 2.5])
				out.append(record({"id":kind,"height":sizes}, s, rng))
			if zones.is_empty():
				continue
			var zone: String = zones[rng.randi() % zones.size()]
			var choices: Array = by_zone.get(zone, [])
			if choices.is_empty():
				continue
			var r: Dictionary = choices[rng.randi() % choices.size()]
			# The render terrain compresses the alpine belt; its snow material tracks that belt.
			if zone != "snowline" and (s.h < r.altitude[0] or s.h > r.altitude[1]):
				continue
			if rng.randf() > float(r.chance):
				continue
			append_plant(out, r, s, rng, by_zone)
			for member in range(1, int(r.get("patch_count", 1))):
				var q := p + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.25, 1.0) * float(r.patch_radius)
				var other := site(d, q, reserved, blocked)
				if other.is_empty() or other.h < r.altitude[0] or other.h > r.altitude[1]:
					continue
				if zone in habitats(d, other, noise, impact, camps):
					append_plant(out, r, other, rng, by_zone)
	return out

static func append_plant(out: Array, r: Dictionary, s: Dictionary, rng: RandomNumberGenerator, by_zone: Dictionary) -> void:
	var plant := record(r, s, rng)
	if r.has("sheltered_colour"):
		plant.variant = 1 if s.up.x < -0.1 else 0
	out.append(plant)
	if r.form == "tree":
		for vine in by_zone.get("host", []):
			if rng.randf() < float(vine.chance):
				var v := record(vine, s, rng)
				v.height = clampf(plant.height * 0.72, vine.height[0], vine.height[1])
				out.append(v)
