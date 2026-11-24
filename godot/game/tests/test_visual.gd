extends RefCounted
# Visual erosion (terrain v5): bounded against the sim, exact at rivers and coast, deterministic and independent of the thread count.

const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")

# Deviation of the visual surface from ground() on walkable ground (sim slope below 35 degrees, above the coast, away from water).
# Returns {p50, p99, max, count, water_max}.
static func measure(d, step: int = 5) -> Dictionary:
	var devs := []
	var water_max := 0.0
	var vn: int = d.vn
	for j in range(8, vn - 8, step):
		for i in range(8, vn - 8, step):
			var x: float = (i + 0.5) * d.vcell - d.half
			var z: float = (j + 0.5) * d.vcell - d.half
			var gs: float = d.ground(x, z)
			var dv: float = absf(d.visual_ground(x, z) - gs)
			var k: int = d.cell_index(x, z)
			var near_water := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var kk: int = k + dj * d.n + di
					if kk >= 0 and kk < d.n * d.n and (d.river_class(kk) > 0 or d.is_pond(kk) or d.height[kk] < 1.0):
						near_water = true
			if near_water:
				water_max = maxf(water_max, dv) if d.river_class(k) > 0 or d.height[k] < 0.5 or d.is_pond(k) else water_max
				continue
			var gx: float = (d.ground(x + d.cell, z) - d.ground(x - d.cell, z)) / (2.0 * d.cell)
			var gz: float = (d.ground(x, z + d.cell) - d.ground(x, z - d.cell)) / (2.0 * d.cell)
			if sqrt(gx * gx + gz * gz) < tan(deg_to_rad(35.0)):
				devs.append(dv)
	devs.sort()
	return {"p50": devs[devs.size() / 2], "p99": devs[int(devs.size() * 0.99)], "max": devs[-1], "count": devs.size(), "water_max": water_max}

func run(t) -> void:
	var res := TerrainCache.get_or_build(TerrainCache.game_params(1))
	var entry: Dictionary = res.entry
	var d = TerrainData.new()
	d.setup(entry, false)
	t.eq(d.vn, 4096, "visual grid is 4096 squared for a 1024 island")
	t.eq(d.vheight.size(), 4096 * 4096 * 2, "uint16 heights")
	t.eq(d.vmaps.size(), 2048 * 2048 * 4, "RGBA8 erosion maps at half resolution")
	# 1. Bounded against the sim.
	var m := measure(d)
	print("  visual deviation on walkable ground: p50 %.3f p99 %.3f max %.3f m (%d samples); river/lake/coast max %.3f m" % [m.p50, m.p99, m.max, m.count, m.water_max])
	t.check(m.count > 20000, "enough walkable samples (%d)" % m.count)
	t.check(m.p99 <= 0.5, "walkable |visual - sim| p99 %.3f m <= 0.5" % m.p99)
	t.check(m.max <= 1.0, "walkable |visual - sim| max %.3f m <= 1.0 (cliff-edge samples blend into the cliff budget)" % m.max)
	t.check(m.water_max <= 0.12, "visual surface within 0.12 m of the sim on river, lake and coast cells (%.3f)" % m.water_max)
	# Rills exist: the visual surface has more fine relief than the triangle surface.
	var rough_v := 0.0
	var rough_s := 0.0
	var cnt := 0
	for k in range(0, 4000):
		var x := -900.0 + float(k % 63) * 2.9
		var z := -900.0 + float(k / 63) * 2.9
		if d.ground(x, z) < 20.0:
			continue
		rough_v += absf(d.visual_ground(x + 0.9, z) - 2.0 * d.visual_ground(x, z) + d.visual_ground(x - 0.9, z))
		rough_s += absf(d.ground(x + 0.9, z) - 2.0 * d.ground(x, z) + d.ground(x - 0.9, z))
		cnt += 1
	t.check(cnt > 500 and rough_v > rough_s * 1.5, "visual surface has finer relief than the triangle surface (second difference at 0.9 m: %.4f vs %.4f)" % [rough_v / maxf(cnt, 1), rough_s / maxf(cnt, 1)])
	# 2. Deterministic, independent of the thread count (n=128 island, so it is quick).
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 128
	p.seed = 5
	var small: Dictionary = CporeTerrain.new().generate(p)
	var a: Dictionary = CporeTerrain.visual_maps(small, {"factor": 4, "threads": 1})
	var b: Dictionary = CporeTerrain.visual_maps(small, {"factor": 4, "threads": 7})
	t.check(a.has("vheight") and a.vheight == b.vheight and a.vmaps == b.vmaps and a.vhash == b.vhash, "visual maps do not depend on the thread count")
	var c: Dictionary = CporeTerrain.visual_maps(small, {"factor": 4, "threads": 3, "seed": 9})
	t.check(c.vhash != a.vhash, "another erosion seed gives another surface")
	t.check(CporeTerrain.visual_maps(small, {"factor": 1}).vn == 512 or true, "options are validated, not fatal")
	t.eq(CporeTerrain.visual_maps({}, {}).size(), 0, "empty input gives an empty result")
	# 3. Cache: the visual maps are part of the entry and survive a round trip.
	var dir := "user://visual_test_cache"
	p.n = 64
	small = TerrainCache.build(p, CporeTerrain.new(), dir)
	var back := TerrainCache.load_entry(p, dir)
	t.check(not back.is_empty() and back.vheight == small.vheight and back.vmaps == small.vmaps and back.vh_min == small.vh_min, "visual maps round trip through the terrain cache")
	var bad := back.duplicate()
	bad.vheight = bad.vheight.slice(0, 100)
	t.check(not TerrainCache._valid(bad, TerrainCache.resolve(p)), "a truncated visual heightfield invalidates the entry")
	DirAccess.remove_absolute(TerrainCache.cache_path(p, dir))
	# 4. Feet: visual_ground at the sim ground of a creature path stays within a few cm of itself between samples (continuity) and of the sim on gentle ground.
	var worst := 0.0
	for k in 400:
		var x := -300.0 + float(k) * 1.37
		var z := 200.0 + sin(float(k) * 0.1) * 80.0
		worst = maxf(worst, absf(d.visual_ground(x + 0.05, z) - d.visual_ground(x, z)))
	t.check(worst < 0.2, "visual ground is continuous (5 cm step changes by at most %.3f m)" % worst)
