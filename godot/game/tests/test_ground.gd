extends RefCounted
# TerrainData: ground() is the exact LOD0 surface; derived maps; chunk bounds; classification.

const TerrainData := preload("res://game/island/terrain_data.gd")

func run(t) -> void:
	var params: Dictionary = CporeTerrain.defaults()
	params.n = 128
	params.seed = 3
	var entry: Dictionary = CporeTerrain.new().generate(params)
	TerrainData.prepare(entry)
	var d = TerrainData.new()
	d.setup(entry)
	t.check(d.height_tex != null and d.level_tex != null and d.surface_tex != null, "textures built")
	t.eq(d.height_tex.get_width(), 128, "height texture width")
	var h: PackedFloat32Array = d.height
	var n: int = d.n
	t.eq(d.cell, 28.125, "cell size from size_m/n")

	var exact := 0
	var tested := 0
	for k in range(0, n * n, 7):
		var i := k % n
		var j := k / n
		tested += 1
		var g := PackedFloat32Array([d.ground(d.cell_center(i), d.cell_center(j))])[0]
		if g == h[k]:
			exact += 1
	t.eq(exact, tested, "ground() at cell centres equals height (float32), %d cells" % tested)

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bad := 0
	for s in 1000:
		var x := rng.randf_range(-1790.0, 1790.0)
		var z := rng.randf_range(-1790.0, 1790.0)
		var u: float = (x + d.half) / d.cell - 0.5
		var v: float = (z + d.half) / d.cell - 0.5
		var i := clampi(floori(u), 0, n - 2)
		var j := clampi(floori(v), 0, n - 2)
		var fu := clampf(u - i, 0.0, 1.0)
		var fv := clampf(v - j, 0.0, 1.0)
		var k := j * n + i
		var expect: float
		if fu >= fv:
			expect = (1.0 - fu) * h[k] + (fu - fv) * h[k + 1] + fv * h[k + n + 1]
		else:
			expect = (1.0 - fv) * h[k] + (fv - fu) * h[k + n] + fu * h[k + n + 1]
		var g: float = d.ground(x, z)
		var lo := minf(minf(h[k], h[k + 1]), minf(h[k + n], h[k + n + 1]))
		var hi := maxf(maxf(h[k], h[k + 1]), maxf(h[k + n], h[k + n + 1]))
		if absf(g - expect) > 1e-3 or g < lo - 1e-3 or g > hi + 1e-3:
			bad += 1
	t.eq(bad, 0, "ground() equals the barycentric triangle formula and stays in the corner range")
	t.eq(d.ground(-99999.0, 99999.0), d.ground(-d.half, d.half), "ground() clamps outside the square")

	# Surface map.
	var s: PackedByteArray = d.surface
	t.eq(s.size(), n * n * 4, "surface size")
	var mat_bad := 0
	var grass_bad := 0
	var same_mat := 0
	for k in n * n:
		var m: int = s[k * 4]
		if m > 5:
			mat_bad += 1
		if m == d.material[k]:
			same_mat += 1
		if s[k * 4 + 1] > 0 and (m != 0 or d.is_sea(k) or d.is_pond(k)):
			grass_bad += 1
	t.eq(mat_bad, 0, "material ids within 0..5")
	t.eq(same_mat, n * n, "R channel is the material id")
	t.eq(grass_bad, 0, "no grass on sea, ponds or non-meadow cells")
	var grass_cells := 0
	for k in n * n:
		if s[k * 4 + 1] > 128:
			grass_cells += 1
	t.check(grass_cells > 100, "some meadow carries grass (%d cells)" % grass_cells)

	# Chunk bounds contain the lattice heights.
	var cps: int = d.chunks_per_side
	t.eq(cps, 2, "chunks per side at n=128")
	var out := 0
	for cj in cps:
		for ci in cps:
			var mn: float = d.chunk_bounds[(cj * cps + ci) * 2]
			var mx: float = d.chunk_bounds[(cj * cps + ci) * 2 + 1]
			for b in 65:
				for a in 65:
					var v := h[mini(cj * 64 + b, n - 1) * n + mini(ci * 64 + a, n - 1)]
					if v < mn or v > mx:
						out += 1
	t.eq(out, 0, "chunk bounds contain every lattice height")

	# Classification matches the lab rule.
	var wrong := 0
	for s2 in 200:
		var k := rng.randi_range(0, n * n - 1)
		var pond: bool = d.water_level[k] - h[k] > 0.5 and h[k] > 0.0
		if d.is_pond(k) != pond or d.is_sea(k) != (h[k] <= 0.0):
			wrong += 1
	t.eq(wrong, 0, "pond/sea classification")

	if t.shared.has("big"):
		var big: Dictionary = t.shared.big
		var t0 := Time.get_ticks_msec()
		TerrainData.prepare(big)
		print("  derived maps at N=1024: %d ms" % (Time.get_ticks_msec() - t0))
		var data = TerrainData.new()
		var t1 := Time.get_ticks_msec()
		data.setup(big)
		print("  textures at N=1024: %d ms" % (Time.get_ticks_msec() - t1))
		t.eq(data.chunks_per_side, 16, "16 chunks per side at N=1024")
		t.eq(data.chunk_bounds.size(), 512, "512 bounds floats")
