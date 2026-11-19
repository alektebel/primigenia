extends Node3D
# Visual-only radial fauna (S5a of the radial-bodies plan): the tide-pool star brujula, the shallow-water bell cuarteta and
# the cave disc corona. They are NOT C entities (no stats, no combat, no snapshot); they only live on the island so the
# world has radial animals. Placement is deterministic from the world seed and the terrain data, like flora_placement.gd.
# Each animal wanders a tiny seeded random walk around its home, driven by loco_radial.gd through the rig adapter.
#
#   brujula   an intertidal shelf: ground .15..1.8 m, within 30 m of the sea, gentle; 4 animals 3..6 m apart round a pool point
#   cuarteta  coastal shallows: sea cells 1..6 m deep, 15..60 m off the shelf; 5 bells, bell top at y = -0.4, a seeded loop
#   corona    a level tide-pool flat at the water edge nearest the lowest tidal cave mouth (caves are only slope notches);
#             falls back to that cave (not the secrets cave) 3..6 m inside the entrance

const Look := preload("res://game/island/look.gd")
const Radial := preload("res://locomotion/loco_radial.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")

const SPECIES := {"brujula": 0.6, "cuarteta": 0.8, "corona": 0.55}
const COUNT := {"brujula": 4, "cuarteta": 5, "corona": 2}
const CULL := 80.0
const BELL_TOP := 0.3     # plan: -0.4; the sea shader hides anything below the surface, so the bell dome floats up through it
const SEA_FLOOR := Vector2(-6.0, -1.0)

var placement: Dictionary = {}
var animals: Array = []
var _cam: Callable
var _ground: Callable


# ------------------------------------------------------------------ placement (pure: terrain data + seed)

static func _rng(world_seed: int, tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world_seed, "radial", tag])
	return r


static func _free_ground(d, p: Vector2) -> bool:
	if absf(p.x) >= d.half - 4.0 or absf(p.y) >= d.half - 4.0:
		return false
	var k: int = d.cell_index(p.x, p.y)
	return not (d.is_sea(k) or d.is_pond(k) or d.is_river(k))


static func is_shelf(d, p: Vector2) -> bool:
	if not _free_ground(d, p):
		return false
	var h: float = d.ground(p.x, p.y)
	if h < 0.15 or h > 1.8 or d.normal(p.x, p.y).y < 0.9:
		return false
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(0.71, 0.71), Vector2(-0.71, 0.71), Vector2(0.71, -0.71), Vector2(-0.71, -0.71)]:
		var r := float(d.cell)
		while r <= 30.0:
			var q: Vector2 = p + dir * r
			if absf(q.x) < d.half and absf(q.y) < d.half and d.ground(q.x, q.y) < -0.2:
				return true
			r += float(d.cell)
	return false


## The nearest shelf point over 72 bearings from the nest (every 5 degrees, marching outwards; seeded start so ties
## and scan order differ per world). The plan said "first such stretch"; the nearest is the same rule made stable.
static func find_shelf(d, world_seed: int, nest: Vector2) -> Variant:
	var start := _rng(world_seed, "shelf").randi() % 72
	var step := maxf(float(d.cell) * 0.5, 4.0)
	var best = null
	var best_r := 1e9
	for i in 72:
		var a := deg_to_rad(float((start + i) % 72) * 5.0)
		var dir := Vector2(sin(a), cos(a))
		var r := 20.0
		while r < minf(d.half - 6.0, best_r):
			var p: Vector2 = nest + dir * r
			if absf(p.x) >= d.half - 6.0 or absf(p.y) >= d.half - 6.0:
				break
			var h: float = d.ground(p.x, p.y)
			if h >= 0.15 and h <= 1.8 and is_shelf(d, p):
				if r < best_r:
					best_r = r
					best = p
				break
			r += step
	return best


static func _around(d, rng: RandomNumberGenerator, centre: Vector2, count: int, rmin: float, rmax: float, ok: Callable, spacing: float) -> Array:
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < 600:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var p := centre + Vector2(sin(a), cos(a)) * r
		if not ok.call(p):
			continue
		var clear := true
		for q: Vector2 in out:
			if q.distance_to(p) < spacing:
				clear = false
		if clear:
			out.append(p)
	return out


static func is_shallows(d, p: Vector2) -> bool:
	if absf(p.x) >= d.half - 4.0 or absf(p.y) >= d.half - 4.0:
		return false
	var g: float = d.ground(p.x, p.y)
	return d.is_sea(d.cell_index(p.x, p.y)) and g >= SEA_FLOOR.x and g <= SEA_FLOOR.y


## Everything the fauna needs, as data: {brujula:{pool, spots}, cuarteta:{centre, spots}, corona:{cave, spots, inward}, log}.
static func plan(d, world_seed: int, nest: Vector2) -> Dictionary:
	var out := {"brujula": {"pool": null, "spots": []}, "cuarteta": {"centre": null, "spots": []}, "corona": {"cave": -1, "spots": [], "inward": Vector2.ZERO}, "log": []}
	var pool = find_shelf(d, world_seed, nest)
	if pool == null:
		out.log.append("radial fauna: no intertidal shelf on this island, no brujula")
	else:
		out.brujula.pool = pool
		out.brujula.spots = _around(d, _rng(world_seed, "brujula"), pool, COUNT.brujula, 3.0, 6.0, func(p): return is_shelf(d, p) or (_free_ground(d, p) and d.ground(p.x, p.y) >= 0.1 and d.ground(p.x, p.y) <= 2.5), 3.0)
		if out.brujula.spots.size() < COUNT.brujula:
			out.log.append("radial fauna: only %d brujula spots around the pool" % out.brujula.spots.size())
	# cuarteta: bells 15..60 m off the shelf (or the nest when there is none)
	var centre: Vector2 = pool if pool != null else nest
	var bells := _around(d, _rng(world_seed, "cuarteta"), centre, COUNT.cuarteta, 15.0, 60.0, func(p): return is_shallows(d, p), 8.0)
	if bells.size() < COUNT.cuarteta:
		bells = _around(d, _rng(world_seed, "cuarteta2"), centre, COUNT.cuarteta, 15.0, 160.0, func(p): return is_shallows(d, p), 8.0)
	out.cuarteta.centre = centre
	out.cuarteta.spots = bells
	if bells.is_empty():
		out.log.append("radial fauna: no coastal shallows, no cuarteta")
	# corona: the lore habitat is a sunken tidal lava tube (lore/creatures/corona.json niche), but the cave meshes are only
	# notches in steep slopes, which made the disc cling to a hillside. Until real cave meshes exist it takes the lore's
	# damp, tidal alternative: a level tide-pool flat at the water's edge, as near as possible to the lowest tidal cave
	# mouth (the tube it would live in), away from the brujula pool. The cave rule below stays as the fallback.
	var anchor: Vector2 = nest
	var best := -1
	var best_floor := 1e9
	for i in range(1, d.caves.size()):
		var f: float = d.caves[i].position.y
		if f < best_floor:
			best_floor = f
			best = i
	if best >= 0:
		anchor = Vector2(d.caves[best].position.x, d.caves[best].position.z)
	var pool_at = find_tide_flat(d, world_seed, anchor, nest, pool)
	if pool_at != null:
		var rng2 := _rng(world_seed, "corona")
		var spots2 := _around(d, rng2, pool_at, COUNT.corona, 1.6, 3.5, func(p): return is_tide_flat(d, p, 14.0, true), 2.0)
		if spots2.size() == COUNT.corona:
			var toward := Vector2.RIGHT
			var bd := 1e9
			for k in 16:       # inward = the direction away from the nearest sea
				var dir := Vector2.from_angle(TAU * k / 16.0)
				for r in [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]:
					var q: Vector2 = pool_at + dir * r
					if d.is_sea(d.cell_index(q.x, q.y)) and r < bd:
						bd = r
						toward = dir
			out.corona = {"cave": -1, "site": "tide_pool", "pool": pool_at, "spots": spots2, "inward": -toward}
			out.log.append("radial fauna: corona on a tide-pool flat at (%.0f, %.0f), %.0f m from the lowest tidal cave mouth (caves are slope notches)" % [pool_at.x, pool_at.y, pool_at.distance_to(anchor)])
			return out
	out.log.append("radial fauna: no level tide-pool flat for corona, falling back to a cave mouth")
	best = -1
	best_floor = 1e9
	for i in range(1, d.caves.size()):
		var f: float = d.caves[i].position.y
		if f < best_floor:
			best_floor = f
			best = i
	if best >= 0 and best_floor >= 25.0:
		best = -1
		var near := 1e9
		for i in range(1, d.caves.size()):
			var cp: Vector3 = d.caves[i].position
			var dist := _coast_distance(d, Vector2(cp.x, cp.z))
			if dist < near:
				near = dist
				best = i
		out.log.append("radial fauna: no cave floor below 25 m, corona uses the cave nearest the coast")
	if best < 0:
		out.log.append("radial fauna: no cave besides the secrets cave, no corona")
	else:
		var cave: Dictionary = d.caves[best]
		var cp: Vector3 = cave.position
		var facing := Vector2(cave.facing.x, cave.facing.z)
		var inward := -facing
		var rng := _rng(world_seed, "corona")
		# 24 seeded candidates 3..6 m inside the entrance; the two gentlest, at least 2 m apart, are the animals
		var cands: Array = []
		for k in 24:
			var p := Vector2(cp.x, cp.z) + inward * rng.randf_range(3.0, 6.0) + Vector2(-inward.y, inward.x) * rng.randf_range(-2.0, 2.0)
			cands.append({"p": p, "n": d.normal(p.x, p.y).y, "i": k})
		cands.sort_custom(func(a, b): return a.n > b.n or (a.n == b.n and a.i < b.i))
		var spots: Array = []
		for c in cands:
			if spots.size() >= COUNT.corona:
				break
			var clear := true
			for q: Vector2 in spots:
				if q.distance_to(c.p) < 2.0:
					clear = false
			if clear:
				spots.append(c.p)
		out.corona = {"cave": best, "site": "cave", "spots": spots, "inward": inward}
	return out


## A level, damp tide-pool flat: low gentle ground that is dry land but has the sea within `reach` metres.
static func is_tide_flat(d, p: Vector2, reach := 10.0, loose := false) -> bool:
	if not _free_ground(d, p):
		return false
	var h: float = d.ground(p.x, p.y)
	if h < 0.1 or h > 1.6 or d.normal(p.x, p.y).y < (0.95 if loose else 0.97):
		return false
	for k in 8:     # level all round (a 3 m ring within 25 cm), so not a gully or a slope foot
		var q: Vector2 = p + Vector2.from_angle(TAU * k / 8.0) * 3.0
		if absf(d.ground(q.x, q.y) - h) > (0.45 if loose else 0.25) or d.normal(q.x, q.y).y < (0.92 if loose else 0.96):
			return false
	for k in 8:
		var dir := Vector2.from_angle(TAU * k / 8.0)
		var r := 1.5
		while r <= reach:
			var q: Vector2 = p + dir * r
			if absf(q.x) < d.half and absf(q.y) < d.half and d.is_sea(d.cell_index(q.x, q.y)):
				return true
			r += 1.5
	return false


## The tide-pool flat nearest `anchor`: a 6 m grid over the island, nearest wins, ties go to the first in scan order from a
## seeded row (so two equal flats differ per world); at least 20 m from the brujula pool and 15 m from the nest.
static func find_tide_flat(d, world_seed: int, anchor: Vector2, nest: Vector2, pool: Variant) -> Variant:
	var strict = _scan_flat(d, world_seed, anchor, nest, pool, false)
	return strict if strict != null else _scan_flat(d, world_seed, anchor, nest, pool, true)


static func _scan_flat(d, world_seed: int, anchor: Vector2, nest: Vector2, pool: Variant, loose: bool) -> Variant:
	var step := 6.0
	var count := int((d.half - 8.0) * 2.0 / step)
	var start := _rng(world_seed, "corona_flat").randi() % maxi(count, 1)
	var best = null
	var best_d := 1e18
	for ri in count:
		var z: float = -d.half + 8.0 + float((start + ri) % count) * step
		for ci in count:
			var p := Vector2(-d.half + 8.0 + float(ci) * step, z)
			var dd := p.distance_squared_to(anchor)
			if dd >= best_d or not is_tide_flat(d, p, 10.0, loose):
				continue
			if p.distance_to(nest) < 15.0 or (pool != null and p.distance_to(pool) < 20.0):
				continue
			best_d = dd
			best = p
	return best


static func _coast_distance(d, p: Vector2) -> float:
	var best := 1e9
	for k in range(0, d.n * d.n, 7):
		if d.height[k] <= 0.0:
			var x: float = (float(k % d.n) + 0.5) * d.cell - d.half
			var z: float = (float(k / d.n) + 0.5) * d.cell - d.half
			best = minf(best, p.distance_to(Vector2(x, z)))
	return best


# ------------------------------------------------------------------ nodes

func setup(d, world_seed: int, nest: Vector2, ground: Callable, camera_fn: Callable = Callable()) -> void:
	_ground = ground
	_cam = camera_fn
	placement = plan(d, world_seed, nest)
	for line in placement.log:
		print(line)
	for id in ["brujula", "cuarteta", "corona"]:
		var spots: Array = placement[id].spots
		for i in spots.size():
			_spawn(id, i, spots[i], world_seed)


static func _genome(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))


func _spawn(id: String, i: int, home: Vector2, world_seed: int) -> void:
	var c := Creature.new()
	var res: Dictionary = c.load_genome(_genome(id))
	if not res["ok"]:
		push_warning("radial fauna %s rejected: %s" % [id, res["error"]])
		c.free()
		return
	c.set_sun_direction(Look.sun_dir())
	c.name = "%s_%d" % [id, i]
	add_child(c)
	var scale: float = SPECIES[id]
	var desc: Dictionary = Adapter.radial_describe(c, scale)
	var floats := id == "cuarteta"
	var float_y := 0.0
	var ground: Callable = _ground
	if floats:
		# the creature origin is the underside of the bell: the bell top (ring NS-1 plus its cap) sits at y = BELL_TOP
		var top: float = float(c.rest[Creature.NS - 1].y) - float(c.radial.y_floor)
		float_y = BELL_TOP - top * scale
		ground = func(_x: float, _z: float) -> float: return float_y
	var loco = Radial.new(desc, ground)
	var rng := _rng(world_seed, "%s_walk_%d" % [id, i])
	var a := {"id": id, "creature": c, "loco": loco, "desc": desc, "home": home, "rng": rng, "scale": scale,
		"pos": Vector3(home.x, 0, home.y), "yaw": rng.randf() * TAU, "goal": home, "wait": rng.randf_range(0.0, 3.0),
		"speed": 0.0, "orbit": rng.randf() * TAU, "float_y": float_y, "loop_r": rng.randf_range(6.0, 12.0)}
	if floats:
		a.home = home
		a.pos = Vector3(home.x + sin(a.orbit) * a.loop_r, 0, home.y + cos(a.orbit) * a.loop_r)
	a.pos.y = ground.call(a.pos.x, a.pos.z)
	loco.reset(a.pos, a.yaw)
	animals.append(a)
	_pose(a, 1.0 / 60.0, Vector3.ZERO)


func _process(delta: float) -> void:
	var cam := Vector3.INF
	if _cam.is_valid():
		cam = _cam.call()
	for a in animals:
		var c: Creature = a.creature
		var d2 := Vector2(a.pos.x - cam.x, a.pos.z - cam.z).length() if cam != Vector3.INF else 0.0
		c.visible = d2 < CULL
		if d2 >= CULL:
			continue
		_wander(a, delta)


func _wander(a: Dictionary, dt: float) -> void:
	var id: String = a.id
	var rng: RandomNumberGenerator = a.rng
	dt = minf(dt, 0.1)
	var vel := Vector3.ZERO
	if id == "cuarteta":
		# a seeded loop in the shallows: constant drift, heading along the loop
		var v := 0.25
		a.orbit += v / a.loop_r * dt
		var np := Vector3(a.home.x + sin(a.orbit) * a.loop_r, 0, a.home.y + cos(a.orbit) * a.loop_r)
		var step: Vector3 = np - a.pos
		a.yaw = atan2(step.x, step.z) if step.length() > 1e-5 else a.yaw
		vel = Vector3(sin(a.yaw), 0, cos(a.yaw)) * v
		a.pos = np
	else:
		var radius := 2.5 if id == "brujula" else 1.8
		if a.wait > 0.0:
			a.wait -= dt
			a.speed = 0.0
			a.loco.hunker = id == "corona"
		else:
			a.loco.hunker = false
			var to: Vector2 = a.goal - Vector2(a.pos.x, a.pos.z)
			if to.length() < 0.2:
				a.wait = rng.randf_range(2.0, 9.0)
				var ang := rng.randf() * TAU
				a.goal = a.home + Vector2(sin(ang), cos(ang)) * rng.randf() * radius
				a.speed = 0.0
				# now and then a brujula bursts away (rowing) instead of gliding
				a.burst = id == "brujula" and rng.randf() < 0.2
			else:
				var want := atan2(to.x, to.y)
				a.yaw += clampf(Radial.wrap_pi(want - a.yaw), -0.8 * dt, 0.8 * dt)
				var vmax := 0.9 if a.get("burst", false) else (0.2 if id == "brujula" else 0.25)
				a.speed = move_toward(a.speed, vmax, 0.5 * dt)
				vel = Vector3(sin(a.yaw), 0, cos(a.yaw)) * a.speed
				a.pos += vel * dt
		a.pos.y = _ground.call(a.pos.x, a.pos.z)
	_pose(a, dt, vel)


func _pose(a: Dictionary, dt: float, vel: Vector3) -> void:
	var loco = a.loco
	loco.step(dt, a.pos, a.yaw, vel)
	Adapter.radial_apply(a.creature, loco.pose, a.desc)
