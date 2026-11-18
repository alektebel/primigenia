extends RefCounted
# Lake mesh: quads only on pond cells (plus one-cell dilation) at their routing level.

const Water := preload("res://game/island/water.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const Rivers := preload("res://game/island/rivers.gd")

func run(t) -> void:
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 256
	p.seed = 1
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var d = TerrainData.new()
	d.setup(entry, false)
	var cells: PackedInt32Array = Water.lake_cells(d)
	var n: int = d.n
	var ponds := 0
	for k in n * n:
		if d.is_pond(k):
			ponds += 1
	t.check(ponds > 0, "the seed-1 island has pond cells at n=256 (%d)" % ponds)
	var stray := 0
	var wrong_level := 0
	var covered := {}
	for k in cells:
		covered[k] = true
		var i: int = k % n
		var j: int = k / n
		var near := false
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ii := i + di
				var jj := j + dj
				if ii >= 0 and jj >= 0 and ii < n and jj < n and d.is_pond(jj * n + ii) and not d.is_river(jj * n + ii):
					near = true
		if not near:
			stray += 1
		var level: float = Water.lake_level(d, k)
		var ok := false
		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ii := i + di
				var jj := j + dj
				if ii >= 0 and jj >= 0 and ii < n and jj < n and d.is_pond(jj * n + ii) and not d.is_river(jj * n + ii) and d.water_level[jj * n + ii] == level:
					ok = true
		if not ok:
			wrong_level += 1
	t.eq(stray, 0, "no lake quad further than one cell from a pond cell")
	t.eq(wrong_level, 0, "lake level equals a neighbouring pond cell's level")
	var missing := 0
	for k in n * n:
		if d.is_pond(k) and not d.is_river(k) and not covered.has(k):
			missing += 1
	t.eq(missing, 0, "every lake (non-river) pond cell has a quad")

	# Rivers (v4): the C map gives channels, each chain follows the receivers downhill and ends at an outlet or a joined channel.
	t.eq(d.river.size(), n * n, "river map present")
	var river_cells := 0
	var deep_ok := 0
	for k in n * n:
		if d.is_river(k):
			river_cells += 1
		if d.river_class(k) == 3 and d.water_level[k] - d.height[k] > 0.7:
			deep_ok += 1
	t.check(river_cells > 100, "the seed-1 island has river cells at n=256 (%d)" % river_cells)
	var chains: Array = Rivers.chains(d)
	t.check(chains.size() > 3, "river chains found (%d)" % chains.size())
	var bad := 0
	for c in chains:
		for q in c.size() - 1:
			var nx := Rivers.next_cell(d, c[q])
			if nx != c[q + 1] or d.height[c[q + 1]] > d.height[c[q]] + 0.6:
				bad += 1
	t.eq(bad, 0, "every chain step is the C receiver and does not climb more than 0.6 m")
	var rv = Rivers.new()
	rv.build(d)
	t.check(rv.vertex_count > 200 and rv.mesh_instance != null, "river ribbons built (%d vertices)" % rv.vertex_count)
	rv.free()
