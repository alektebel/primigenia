extends RefCounted
# A59 ambient fliers: habitat planning is data (terrain + seed), the flight sim is deterministic, birds never clip the ground,
# take off, land on their perch, and flee a player who walks up.

const Flock := preload("res://game/island/fliers/flier_flock.gd")
const Species := preload("res://game/island/fliers/flier_species.gd")
const Terrain := preload("res://game/island/terrain_data.gd")
const Cache := preload("res://game/island/terrain_cache.gd")
const Setup := preload("res://game/stage/stage_setup.gd")

func _world(world_seed: int) -> Array:
	var d := Terrain.new()
	var entry: Dictionary = Cache.get_or_build({"seed": world_seed}).entry
	d.setup(entry, false)
	return [d, Setup.find_nest(d)]

func _make(d, world_seed: int, nest: Vector2):
	var f = Flock.new()
	f.setup(d, world_seed, nest, Callable(d, "visual_ground"), Callable(), Callable(), null, false)
	return f

func _hash(f) -> int:
	var h := 0
	for b in f.birds:
		h = hash([h, snappedf(b.pos.x, 0.001), snappedf(b.pos.y, 0.001), snappedf(b.pos.z, 0.001), b.state])
	return h

func run(t) -> void:
	for world_seed in [1, 7, 42]:
		var w := _world(world_seed)
		var d = w[0]
		var nest: Vector2 = w[1]
		var a: Dictionary = Flock.plan(d, world_seed, nest)
		t.eq(hash(a), hash(Flock.plan(d, world_seed, nest)), "same seed, same flier placement (seed %d)" % world_seed)
		var kinds := {}
		for fl in a.flocks:
			kinds[fl.species] = true
			for p: Vector2 in fl.spots:
				t.check(Flock._habitat(d, fl.species, p, 0.0) or fl.species == Species.ALARIZ, "perch in habitat (seed %d)" % world_seed)
				t.check(d.normal(p.x, p.y).y > 0.5, "perch is not on a cliff")
			t.check(fl.n >= 1 and fl.n <= fl.spots.size(), "enough perches for the flock")
		t.check(kinds.size() >= 3, "at least three species placed (seed %d: %d)" % [world_seed, kinds.size()])
		var f1 = _make(d, world_seed, nest)
		var f2 = _make(d, world_seed, nest)
		t.check(f1.birds.size() >= 8, "a few dozen at most, at least eight birds (seed %d: %d)" % [world_seed, f1.birds.size()])
		t.check(f1.birds.size() <= 60, "flier budget")
		var player := Vector3(nest.x, 0, nest.y)
		player.y = d.visual_ground(player.x, player.z)
		# 100 s of sim, the player far from the fliers' perches at the nest (they may still be near; that is the flee test below)
		for i in 6000:
			f1.step(1.0 / 60.0, Vector3.INF)
			f2.step(1.0 / 60.0, Vector3.INF)
		t.eq(_hash(f1), _hash(f2), "two runs of the same world fly the same (seed %d)" % world_seed)
		var nan := false
		for b in f1.birds:
			if not (is_finite(b.pos.x) and is_finite(b.pos.y) and is_finite(b.pos.z)):
				nan = true
		t.check(not nan, "no NaN positions")
		t.check(f1.stats.min_clear > 0.2, "never inside the ground while flying (min clearance %.2f m)" % f1.stats.min_clear)
		t.check(f1.stats.takeoffs >= 2 and f1.stats.landings >= 2, "birds take off and land (%d / %d, seed %d)" % [f1.stats.takeoffs, f1.stats.landings, world_seed])
		t.eq(f1.stats.aborts, 0, "no landing gave up (seed %d)" % world_seed)
		# every bird above the ground and at plausible speed
		for b in f1.birds:
			t.check(b.pos.y >= d.visual_ground(b.pos.x, b.pos.z) - 0.01, "bird above the ground")
			t.check(b.speed <= float(Species.get_data(b.species).vmax) + 0.5, "speed under vmax")
	# flee: stand a player next to a perched flock
	var w := _world(1)
	var d = w[0]
	var f = _make(d, 1, w[1])
	for i in 60:
		f.step(1.0 / 60.0, Vector3.INF)
	var victim = null
	for b in f.birds:
		if b.state == Flock.S.PERCH and b.species != Species.ALARIZ:
			victim = b
			break
	if victim == null:
		# everything started flying: let them land (the flock timers run out), then try
		for i in 60 * 120:
			f.step(1.0 / 60.0, Vector3.INF)
			for b in f.birds:
				if victim == null and b.state == Flock.S.PERCH and b.species != Species.ALARIZ:
					victim = b
			if victim != null:
				break
	t.check(victim != null, "found a perched bird to scare")
	if victim != null:
		var sd: Dictionary = Species.get_data(victim.species)
		var near: Vector3 = victim.pos + Vector3(float(sd.flee) * 0.5, 0, 0)
		var p0: Vector3 = victim.pos
		var left := -1.0
		for i in 60 * 6:
			f.step(1.0 / 60.0, near)
			if victim.state != Flock.S.PERCH and left < 0.0:
				left = float(i) / 60.0
		t.check(left >= 0.0 and left < 1.5, "a player inside the flee radius sends the bird off within 1.5 s (left after %.2f s)" % left)
		t.check(Vector2(victim.pos.x - p0.x, victim.pos.z - p0.z).length() > float(sd.flee) * 0.6, "and it is gone from the perch (moved %.1f m)" % Vector2(victim.pos.x - p0.x, victim.pos.z - p0.z).length())
		t.check(f.stats.flees >= 1, "flee counted")
	# determinism of the planner across seeds
	t.check(hash(Flock.plan(d, 1, w[1])) != hash(Flock.plan(d, 99, w[1])), "a different world seed changes the fliers")
