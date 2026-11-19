extends RefCounted
# S5a: the visual-only radial fauna. Placement is data (terrain + seed -> spots): deterministic, on land / in water where
# the habitat says, never a C entity. The lore chains' arm counts equal the genome folds.

const Fauna := preload("res://game/island/radial_fauna.gd")
const Terrain := preload("res://game/island/terrain_data.gd")
const Cache := preload("res://game/island/terrain_cache.gd")
const Setup := preload("res://game/stage/stage_setup.gd")

func run(t) -> void:
	for id in ["brujula", "cuarteta", "corona"]:
		var lore: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../lore/creatures/%s.json" % id))
		var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))
		t.eq(int(lore.body_plan.arms), int(g.plan.fold), "lore body_plan.arms == plan.fold for " + id)
		t.eq(lore.body_plan.symmetry, "radial", "lore symmetry for " + id)
		t.eq(g.plan.sym, "radial", id + " is a radial genome")
	var shelves := 0
	var corona_logged := 0
	for world_seed in [1, 7, 42]:
		var d := Terrain.new()
		d.setup(Cache.get_or_build({"seed": world_seed}).entry, false)
		var nest := Setup.find_nest(d)
		var a: Dictionary = Fauna.plan(d, world_seed, nest)
		var b: Dictionary = Fauna.plan(d, world_seed, nest)
		t.eq(hash(a), hash(b), "same seed gives the same radial placement (seed %d)" % world_seed)
		if world_seed == 1:
			t.check(hash(a) != hash(Fauna.plan(d, 99, nest)), "a different world seed changes the spots")
		if a.brujula.pool != null:
			shelves += 1
			t.eq(a.brujula.spots.size(), 4, "four brujula round the pool (seed %d)" % world_seed)
			for p: Vector2 in a.brujula.spots:
				var k: int = d.cell_index(p.x, p.y)
				t.check(not d.is_sea(k) and not d.is_pond(k) and d.ground(p.x, p.y) >= 0.1 and d.ground(p.x, p.y) <= 2.5, "brujula on the shelf (seed %d)" % world_seed)
		for p: Vector2 in a.cuarteta.spots:
			t.check(Fauna.is_shallows(d, p), "cuarteta in the shallows (seed %d)" % world_seed)
		t.check(a.cuarteta.spots.size() <= 5, "at most five bells")
		if a.corona.cave >= 0:
			t.check(a.corona.cave >= 1, "corona never in the secrets cave (seed %d)" % world_seed)
			t.eq(a.corona.spots.size(), 2, "two corona (seed %d)" % world_seed)
		for line: String in a.log:
			if line.contains("corona"):
				corona_logged += 1
		print("  radial fauna seed %d: pool %s, %d bells, corona cave %d, log %s" % [world_seed, a.brujula.pool, a.cuarteta.spots.size(), a.corona.cave, a.log])
	t.check(shelves >= 1, "at least one of three seeds has an intertidal shelf")
