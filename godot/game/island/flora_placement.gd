extends RefCounted

const RECIPES := "res://game/data/flora.json"
const SPACING := 20.0
const MAX_GRADE := 1.26

# Island climate (island-realism plan part II, M4). Biome ids are core/include/cpore/climate.h CP_BIOME_*; veg channels are the RGBA8 of
# CpTerrain.veg. Only terrain with climate maps (d.has_climate(), an authored island) takes this path: layout 0 keeps the rules above.
const B_SEA := 0
const B_REEF := 1
const B_BEACH := 2
const B_MEADOW := 3
const B_JUNGLE := 4          # cloud forest (A99 (5))
const B_DRY_FOREST := 5
const B_SCRUB := 6
const B_DESERT := 7
const B_BADLANDS := 8
const B_ALPINE := 9
const B_TUNDRA := 10
const B_SNOW := 11
const B_CLIFF := 12
const BIOME_NAMES := ["sea", "reef", "beach", "meadow", "jungle", "dry_forest", "scrub", "desert", "badlands", "alpine", "tundra", "snow", "cliff"]
const V_CANOPY := 0
const V_UNDER := 1
const V_GRASS := 2

# Lattice of candidate sites per biome ("sp" metres, replacing the global 20 m SPACING) and the share of them that is used ("accept",
# times the tier density). Starting values, checked by counts per biome in tests/flora_climate_test.gd and by the OG3 view.
const PROFILE := {
	B_SEA: {"sp": 20.0, "accept": 1.0},
	B_REEF: {"sp": 20.0, "accept": 1.0},
	B_BEACH: {"sp": 20.0, "accept": 1.0},
	B_MEADOW: {"sp": 20.0, "accept": 1.0},
	B_JUNGLE: {"sp": 8.0, "accept": 1.0},
	B_DRY_FOREST: {"sp": 8.0, "accept": 0.7},
	B_SCRUB: {"sp": 20.0, "accept": 0.5},
	B_DESERT: {"sp": 40.0, "accept": 0.45},
	B_BADLANDS: {"sp": 40.0, "accept": 0.6},
	B_ALPINE: {"sp": 14.0, "accept": 0.8},
	B_TUNDRA: {"sp": 14.0, "accept": 0.6},
	B_SNOW: {"sp": 40.0, "accept": 0.5},
	B_CLIFF: {"sp": 20.0, "accept": 1.0},
}
const CLIMATE_SPACINGS := [8.0, 14.0, 20.0, 40.0]

# Island-realism M3: on an island with climate maps the big trees come from the C trunk records (core/src/flora_place.c, d.trunks: x, z, radius,
# height, species id): the same trees the sim treats as circle obstacles, so there is no second placement. GDScript keeps everything small.
const TRUNK_STRIDE := 5
const TRUNK_IDS := {1: "nieblon", 2: "madre_de_agua"}

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
	if d.has_climate():
		climate_zones(d, s, pocket, near_bank, reserved, zones)
		return zones
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

# Zones of a land site from its biome and vegetation (climate maps). Weighted by repetition: the generator picks one zone per site.
static func climate_zones(d, s: Dictionary, pocket: float, near_bank: bool, reserved: Array, zones: Array) -> void:
	var b: int = d.biome[s.k]
	var p: Vector2 = s.p
	var h: float = s.h
	var canopy: float = d.veg_at(s.k, V_CANOPY)
	var bare_biome := b == B_DESERT or b == B_BADLANDS
	if bare_biome and near_bank:
		# rivers cross the desert; the dry banks carry no riparian planting (a few xerophytes only)
		zones.erase("bank")
	match b:
		B_JUNGLE:
			zones.append_array(["forest", "forest", "forest", "litter", "shade"])
		B_DRY_FOREST:
			zones.append_array(["forest", "forest", "valley_edge", "litter"])
		B_MEADOW:
			zones.append("meadow")
		B_SCRUB:
			zones.append_array(["meadow", "disturbed", "valley_edge"])
		B_DESERT, B_BADLANDS:
			zones.append_array(["lava_crack", "bare_lava"])
		B_ALPINE:
			zones.append_array(["lava_crack", "lava_crack", "bare_lava", "bare_lava", "snowline"])
		B_TUNDRA:
			zones.append_array(["bare_lava", "bare_lava", "lava_crack", "snowline"])
		B_SNOW:
			zones.append("snowline")
	# Start-valley habitats: on soil, in the biomes that can carry them (the old rules were "east of the western fog forest").
	if d.material[s.k] == 0 and (b == B_MEADOW or b == B_SCRUB or b == B_DRY_FOREST):
		if h >= 15 and h <= 400 and s.up.y > 0.94 and pocket > 0.0:
			zones.append("hollow")
		if near_bank and h >= 15 and h <= 350:
			zones.append("wet_fringe")
		if b == B_MEADOW and h >= 30 and h <= 550 and s.up.y > 0.8 and s.up.y < 0.96 and pocket > 0.18 and p.length() > 60:
			zones.append("valley_edge")
		for i in reserved.size():
			var dist: float = p.distance_to(reserved[i])
			if dist > 10 and dist < 80 and h >= 15 and h <= 450 and pocket > -0.2:
				zones.append("disturbed")
				break
	if near_bank and not bare_biome:
		zones.append("shade")

# Does the climate allow recipe r at site s? The recipe's "climate" block (p_mm, t_c, canopy ranges, an optional altitude that replaces
# the lore altitude on this island) is checked against the maps; without a block the lore altitude is the only limit.
static func climate_ok(d, r: Dictionary, s: Dictionary, zone: String) -> bool:
	var c: Dictionary = r.get("climate", {})
	var alt: Array = c.get("altitude", r.altitude)
	if zone != "snowline" and (s.h < alt[0] or s.h > alt[1]):
		return false
	if c.has("p_mm") or c.has("t_c"):
		var cl: Vector4 = d.climate_at(s.p.x, s.p.y)
		if c.has("p_mm") and (cl.x < c.p_mm[0] or cl.x > c.p_mm[1]):
			return false
		if c.has("t_c") and (cl.y < c.t_c[0] or cl.y > c.t_c[1]):
			return false
	if c.has("canopy"):
		var cv: float = d.veg_at(s.k, V_CANOPY)
		if cv < c.canopy[0] or cv > c.canopy[1]:
			return false
	return true

# Chance multiplier of a zone from the vegetation maps: trees follow the canopy, understory the undergrowth, meadow the grass.
static func veg_weight(d, k: int, zone: String) -> float:
	match zone:
		"forest":
			return clampf(d.veg_at(k, V_CANOPY) * 1.25, 0.0, 1.0)
		"litter", "shade":
			return clampf(0.25 + d.veg_at(k, V_UNDER), 0.0, 1.0)
		"meadow":
			return clampf(0.2 + d.veg_at(k, V_GRASS), 0.0, 1.0)
	return 1.0

static func record(r: Dictionary, s: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var h := rng.randf_range(r.height[0], r.height[1])
	var p: Vector2 = s.p
	return {"id":r.id,"p":Vector3(p.x, s.h, p.y),"height":h,"yaw":rng.randf() * TAU,"variant":rng.randi() % 2,"up":s.up}

# The spring giant needs reliable water: never desert, badlands, snow or cliff cells (always true without climate maps).
static func spring_biome_ok(d, s: Dictionary) -> bool:
	if not d.has_climate():
		return true
	return d.biome[s.k] in [B_MEADOW, B_JUNGLE, B_DRY_FOREST, B_SCRUB]

# In the absence of a named dyke, choose the nearest eligible freshwater margin east of the start.
static func spring_site(d, reserved: Array, r: Dictionary, blocked: PackedByteArray) -> Dictionary:
	for radius in range(30, 1500, 6):
		for j in 33:
			var p: Vector2 = reserved[0] + Vector2.RIGHT.rotated((j - 16) * PI / 36) * radius
			if absf(p.x) >= d.half or absf(p.y) >= d.half:
				continue
			var s := site(d, p, reserved, blocked)
			if not s.is_empty() and s.h >= r.altitude[0] and s.h <= r.altitude[1] and bank(d, p) and spring_biome_ok(d, s):
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
	if d.has_climate():
		# the spring tree is a C trunk (species 2): keep the small flora off it, as it was off the GDScript spring site
		for i: int in d.trunks.size() / TRUNK_STRIDE:
			if int(d.trunks[i * TRUNK_STRIDE + 4]) == 2:
				reserved.append(Vector2(d.trunks[i * TRUNK_STRIDE], d.trunks[i * TRUNK_STRIDE + 1]))
	else:
		for r in by_zone.get("spring", []):
			var s := spring_site(d, reserved, r, blocked)
			if not s.is_empty():
				append_plant(out, r, s, rng, by_zone)
				reserved.append(s.p)
	var ctx := {"world_seed": world_seed, "density": density, "reserved": reserved, "camps": camps, "by_zone": by_zone, "noise": noise,
		"impact": impact, "blocked": blocked}
	if d.has_climate():
		# One lattice pass per spacing; a site is visited by the pass of its own biome only (PROFILE).
		for pass_i in CLIMATE_SPACINGS.size():
			var sp: float = CLIMATE_SPACINGS[pass_i]
			var side := ceili(d.size_m / sp)
			for z in side:
				for x in side:
					var c := Vector2((x + 0.5) * sp - d.half, (z + 0.5) * sp - d.half)
					var prof: Dictionary = PROFILE[d.biome[d.cell_index(c.x, c.y)]]
					if prof.sp != sp:
						continue
					rng.seed = hash(Vector3i(world_seed + pass_i * 7919, x, z))
					place_cell(d, ctx, rng, out, sp, x, z)
		append_trunks(d, out, by_zone, world_seed)
		return out
	var side := ceili(d.size_m / SPACING)
	for z in side:
		for x in side:
			rng.seed = hash(Vector3i(world_seed, x, z))
			place_cell(d, ctx, rng, out, SPACING, x, z)
	return out

# One lattice cell. With climate maps (d.has_climate()) the biome sets the acceptance, the vegetation maps weight the zone and the
# recipe's climate block gates it; without them this is the original rule set draw for draw.
static func place_cell(d, ctx: Dictionary, rng: RandomNumberGenerator, out: Array, sp: float, x: int, z: int) -> void:
	var climate: bool = d.has_climate()
	var reserved: Array = ctx.reserved
	var blocked: PackedByteArray = ctx.blocked
	var by_zone: Dictionary = ctx.by_zone
	var density: float = ctx.density
	var cell_density := density
	if rng.randf() >= density:
		return
	var p: Vector2 = (Vector2(x + rng.randf(), z + rng.randf()) * sp) - Vector2.ONE * d.half
	if p.x >= d.half or p.y >= d.half:
		return
	var s := site(d, p, reserved, blocked)
	if s.is_empty():
		return
	var rock_chance := 0.32
	if climate:
		var prof: Dictionary = PROFILE[d.biome[s.k]]
		if prof.sp != sp or rng.randf() >= float(prof.accept):
			return
		rock_chance = minf(0.85, 0.32 * sp * sp / (SPACING * SPACING))
	var zones := habitats(d, s, ctx.noise, ctx.impact, ctx.camps)
	var mat: int = d.material[s.k]
	if not s.sea and mat in [1, 2, 3] and rng.randf() < rock_chance:
		var kind := "scree" if mat == 2 else ("outcrop" if s.up.y < 0.81 else "boulder")
		var sizes := [0.18, 0.72] if kind == "scree" else ([1.7, 5.6] if kind == "outcrop" else [0.55, 2.5])
		out.append(record({"id":kind,"height":sizes}, s, rng))
	if zones.is_empty():
		return
	var zone: String = zones[rng.randi() % zones.size()]
	var choices: Array = by_zone.get(zone, [])
	if choices.is_empty():
		return
	var r: Dictionary = choices[rng.randi() % choices.size()]
	if climate:
		if r.id == "nieblon" or r.id == "madre_de_agua":
			return   # a C trunk (append_trunks)
		if not climate_ok(d, r, s, zone):
			return
	# The render terrain compresses the alpine belt; its snow material tracks that belt.
	elif zone != "snowline" and (s.h < r.altitude[0] or s.h > r.altitude[1]):
		return
	if rng.randf() > float(r.chance) * (veg_weight(d, s.k, zone) if climate else 1.0):
		return
	var members := int(r.get("patch_count", 1))
	var host_scale := 1.0
	if climate and sp < 14.0:
		# the 8 m forest lattice is already dense: no extra clumps of trunks, small patches of understory, half the vines
		members = 1 if r.form == "tree" else mini(members, 2)
		host_scale = 0.5
	append_plant(out, r, s, rng, by_zone, host_scale)
	for member in range(1, members):
		var q := p + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(0.25, 1.0) * float(r.patch_radius)
		var other := site(d, q, reserved, blocked)
		if other.is_empty():
			continue
		if climate:
			if not climate_ok(d, r, other, zone):
				continue
		elif other.h < r.altitude[0] or other.h > r.altitude[1]:
			continue
		if zone in habitats(d, other, ctx.noise, ctx.impact, ctx.camps):
			append_plant(out, r, other, rng, by_zone)

# The trees of the C trunk records as plant records, each with its own seeded draws (yaw, variant, host vines), appended after the small flora.
static func append_trunks(d, out: Array, by_zone: Dictionary, world_seed: int) -> void:
	var rows := {}
	for id in TRUNK_IDS.values():
		for zone in by_zone:
			for r in by_zone[zone]:
				if r.id == id:
					rows[id] = r
	var rng := RandomNumberGenerator.new()
	for i: int in d.trunks.size() / TRUNK_STRIDE:
		var base: int = i * TRUNK_STRIDE
		var id: String = TRUNK_IDS.get(int(d.trunks[base + 4]), "")
		if id == "" or not rows.has(id):
			continue
		var p := Vector2(d.trunks[base], d.trunks[base + 1])
		var k: int = d.cell_index(p.x, p.y)
		var s := {"p": p, "h": d.visual_ground(p.x, p.y), "up": facet(d, p), "k": k, "sea": false}
		rng.seed = hash(Vector3i(world_seed + 104729, i, int(d.trunks[base + 4])))
		var plant := record(rows[id], s, rng)
		plant.height = d.trunks[base + 3]
		out.append(plant)
		for vine in by_zone.get("host", []):
			if rng.randf() < float(vine.chance) * 0.5:
				var v := record(vine, s, rng)
				v.height = clampf(plant.height * 0.72, vine.height[0], vine.height[1])
				out.append(v)

static func append_plant(out: Array, r: Dictionary, s: Dictionary, rng: RandomNumberGenerator, by_zone: Dictionary, host_scale: float = 1.0) -> void:
	var plant := record(r, s, rng)
	if r.has("sheltered_colour"):
		plant.variant = 1 if s.up.x < -0.1 else 0
	out.append(plant)
	if r.form == "tree":
		for vine in by_zone.get("host", []):
			if rng.randf() < float(vine.chance) * host_scale:
				var v := record(vine, s, rng)
				v.height = clampf(plant.height * 0.72, vine.height[0], vine.height[1])
				out.append(v)
