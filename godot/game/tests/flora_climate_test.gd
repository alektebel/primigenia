extends SceneTree
# make godot-flora-climate-test: flora and grass follow the climate maps (island-realism plan part II, M4).
# Star massif (the frozen island, 8 km, n 1536) through the real cache and terrain data: counts per biome, no tree in desert or badlands
# cells, the Madre de agua at the spring, grass density from veg.B, and the fallback on the seed island (layout 0, no climate maps).
# godot --headless --path godot --script res://game/tests/flora_climate_test.gd -- [tier 0|1|2]

const Placement := preload("res://game/island/flora_placement.gd")
const Terrain := preload("res://game/island/terrain_data.gd")
const Cache := preload("res://game/island/terrain_cache.gd")
const Grass := preload("res://game/island/grass.gd")
const ISLAND := "res://game/data/islands/star_massif.isl"
const DENSITY := [0.34, 0.57, 0.87]
const DIR := "user://m4-tests"

var checks := 0
var failures := 0

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ", what)
	return ok

func _initialize() -> void:
	var tier := 1
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			tier = clampi(int(a), 0, 2)
	run(tier)
	print("flora climate test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func run(tier: int) -> void:
	var rows := Placement.recipes()
	var form := {}
	for r in rows:
		form[r.id] = r.form
	var blob := FileAccess.get_file_as_bytes(ISLAND)
	check(blob.size() > 0, "the frozen Star massif blob exists")
	var t0 := Time.get_ticks_msec()
	var info: Dictionary = CporeTerrain.island_info(blob)
	var got := Cache.get_or_build({"seed": 1, "n": int(info.n), "island_blob": blob}, DIR)
	var d := Terrain.new()
	d.setup(got.entry, false)
	print("  Star massif n %d, terrain %d ms (cache hit %s)" % [d.n, Time.get_ticks_msec() - t0, got.hit])
	check(d.has_climate(), "Star massif terrain carries biome and veg")
	check(d.climate_n == 256, "climate grid 256")
	var biome_cells := {}
	for k in d.n * d.n:
		biome_cells[d.biome[k]] = biome_cells.get(d.biome[k], 0) + 1
	var km2 := d.cell * d.cell / 1.0e6
	var setup := {"nest": Vector2.ZERO, "wild": [{"x": 64, "z": 0}]}
	var t1 := Time.get_ticks_msec()
	var recs := Placement.generate(d, setup, 1, DENSITY[tier], rows)
	var ms := Time.get_ticks_msec() - t1
	check(hash(recs) == hash(Placement.generate(d, setup, 1, DENSITY[tier], rows)), "the placement repeats")
	# counts per biome
	var per := {}
	var trees := {}
	var by_id := {}
	for obj in recs:
		var p: Vector3 = obj.p
		var k := d.cell_index(p.x, p.z)
		var b: int = d.biome[k]
		per[b] = per.get(b, 0) + 1
		if form.get(obj.id, "") == "tree":
			trees[b] = trees.get(b, 0) + 1
		if not by_id.has(b):
			by_id[b] = {}
		by_id[b][obj.id] = by_id[b].get(obj.id, 0) + 1
	print("  tier %d: %d records in %d ms" % [tier, recs.size(), ms])
	print("  %-10s %8s %8s %8s %8s  top species" % ["biome", "km2", "records", "trees", "trees/km2"])
	for b in Placement.BIOME_NAMES.size():
		var area: float = float(biome_cells.get(b, 0)) * km2
		var tr: int = trees.get(b, 0)
		var top := []
		var ids: Dictionary = by_id.get(b, {})
		var order := ids.keys()
		order.sort_custom(func(x, y): return ids[x] > ids[y])
		for id in order.slice(0, 4):
			top.append("%s %d" % [id, ids[id]])
		print("  %-10s %8.2f %8d %8d %8.0f  %s" % [Placement.BIOME_NAMES[b], area, per.get(b, 0), tr, float(tr) / maxf(area, 0.001), ", ".join(top)])
	var area_of := func(b: int) -> float: return maxf(float(biome_cells.get(b, 0)) * km2, 0.001)
	var tree_density := func(b: int) -> float: return float(trees.get(b, 0)) / area_of.call(b)
	var dens_j: float = tree_density.call(Placement.B_JUNGLE)
	var dens_df: float = tree_density.call(Placement.B_DRY_FOREST)
	var dens_sc: float = tree_density.call(Placement.B_SCRUB)
	check(biome_cells.get(Placement.B_JUNGLE, 0) > 0 and biome_cells.get(Placement.B_DESERT, 0) > 0, "Star massif has cloud forest and desert cells")
	check(dens_j > 800.0, "cloud forest is densely wooded (%.0f trees/km2)" % dens_j)
	check(dens_df > 400.0 and dens_df < dens_j, "dry forest is wooded, less than cloud forest (%.0f)" % dens_df)
	check(dens_sc < dens_df * 0.25, "scrub is sparse (%.0f trees/km2)" % dens_sc)
	# no tree in desert, badlands (and none above the treeline or on snow)
	var bad := 0
	for obj in recs:
		var p: Vector3 = obj.p
		var b: int = d.biome[d.cell_index(p.x, p.z)]
		if form.get(obj.id, "") == "tree" and obj.id != "madre_de_agua" and b in [Placement.B_DESERT, Placement.B_BADLANDS, Placement.B_ALPINE, Placement.B_TUNDRA, Placement.B_SNOW, Placement.B_CLIFF]:
			bad += 1
	check(bad == 0, "no tree in desert, badlands, alpine, tundra, snow or cliff cells (%d found)" % bad)
	# desert and badlands: bare, a few xerophytes (no tree, no shrub, no fern)
	var bare_n := 0
	var bare_area: float = area_of.call(Placement.B_DESERT) + area_of.call(Placement.B_BADLANDS)
	var woody := 0
	for b in [Placement.B_DESERT, Placement.B_BADLANDS]:
		for id in by_id.get(b, {}):
			bare_n += by_id[b][id]
			if form.get(id, "") in ["tree", "shrub", "fern", "vine"] and id != "salvisca":   # salvisca: the salt shrub of the spray zone on any coast
				woody += by_id[b][id]
	check(bare_n > 0, "desert and badlands keep a few xerophytes (%d)" % bare_n)
	check(woody == 0, "no woody plant in desert or badlands, but the coastal salt shrub (%d)" % woody)
	var forest_records: int = per.get(Placement.B_JUNGLE, 0)
	var forest_area: float = area_of.call(Placement.B_JUNGLE)
	check(float(bare_n) / bare_area < 0.2 * float(forest_records) / forest_area, "desert and badlands are far barer than the forest per km2")
	# meadow is grass; alpine and tundra get low cushion plants
	var meadow: Dictionary = by_id.get(Placement.B_MEADOW, {})
	check(meadow.get("paja_dulce", 0) > 0, "meadow carries paja_dulce (%d)" % meadow.get("paja_dulce", 0))
	var cushions := 0
	for b in [Placement.B_ALPINE, Placement.B_TUNDRA]:
		for id in by_id.get(b, {}):
			if form.get(id, "") in ["moss_lichen", "grass"]:
				cushions += by_id[b][id]
	check(cushions > 0, "alpine and tundra carry low cushion plants (%d)" % cushions)
	# the forest zones: understory under the canopy
	var jungle: Dictionary = by_id.get(Placement.B_JUNGLE, {})
	check(jungle.get("nieblon", 0) > 0 and jungle.get("pluma_de_sombra", 0) > 0, "cloud forest has nieblon and its ferns")
	check(by_id.get(Placement.B_DRY_FOREST, {}).get("nieblon", 0) + by_id.get(Placement.B_DRY_FOREST, {}).get("caramillo", 0) > 0, "dry forest has trees")
	# Madre de agua: exactly one, at the spring (the nearest eligible freshwater margin east of the nest), never in a dry biome
	var madre := []
	for obj in recs:
		if obj.id == "madre_de_agua":
			madre.append(obj)
	check(madre.size() == 1, "one Madre de agua (%d)" % madre.size())
	if madre.size() == 1:
		var spring_row: Dictionary = {}
		for r in rows:
			if r.id == "madre_de_agua":
				spring_row = r
		var blocked := Placement.river_mask(d)
		var site := Placement.spring_site(d, [setup.nest, Vector2(64, 0)], spring_row, blocked)
		var p: Vector3 = madre[0].p
		check(not site.is_empty() and Vector2(p.x, p.z).distance_to(site.p) < 0.01, "the Madre de agua stands on the spring site")
		var b: int = d.biome[d.cell_index(p.x, p.z)]
		check(b in [Placement.B_MEADOW, Placement.B_JUNGLE, Placement.B_DRY_FOREST, Placement.B_SCRUB], "the Madre de agua is not in a dry or bare biome (%s)" % Placement.BIOME_NAMES[b])
		check(Placement.bank(d, Vector2(p.x, p.z)), "the Madre de agua is on a water margin")
		print("  Madre de agua at (%.0f, %.0f), %s, h %.0f" % [p.x, p.z, Placement.BIOME_NAMES[b], p.y])
	# grass: veg.B reaches the shader
	d.setup(got.entry, true)
	check(d.veg_tex != null and d.biome_tex != null, "veg_tex and biome_tex exist")
	check(d.veg_tex.get_width() == d.n and d.biome_tex.get_width() == d.n, "veg_tex and biome_tex are n x n")
	var m := ShaderMaterial.new()
	d.bind_climate(m)
	check(is_equal_approx(m.get_shader_parameter("use_veg"), 1.0), "grass reads veg on the climate island")
	var grass_desert := 0.0
	var grass_meadow := 0.0
	var nd := 0
	var nm := 0
	for k in d.n * d.n:
		if d.biome[k] == Placement.B_DESERT:
			grass_desert += d.veg_at(k, Placement.V_GRASS)
			nd += 1
		elif d.biome[k] == Placement.B_MEADOW:
			grass_meadow += d.veg_at(k, Placement.V_GRASS)
			nm += 1
	check(nd > 0 and nm > 0 and grass_desert / nd < 0.05 and grass_meadow / nm > 0.5, "grass density: desert %.2f, meadow %.2f" % [grass_desert / maxf(nd, 1), grass_meadow / maxf(nm, 1)])
	# the seed island (layout 0) has no climate maps: the old rules and full grass
	var seed_entry: Dictionary = Cache.get_or_build({"seed": 1}, DIR).entry
	var s0 := Terrain.new()
	s0.setup(seed_entry, true)
	check(not s0.has_climate(), "layout 0 has no climate maps")
	var m0 := ShaderMaterial.new()
	s0.bind_climate(m0)
	check(is_equal_approx(m0.get_shader_parameter("use_veg"), 0.0), "grass ignores veg on layout 0")
	var old := Placement.generate(s0, setup, 1, 0.34, rows)
	var ids0 := {}
	for obj in old:
		ids0[obj.id] = true
	check(old.size() == 5154 and ids0.has("nieblon") and ids0.has("paja_dulce"), "layout 0 keeps the old placement (%d records, 5154 before M4)" % old.size())
