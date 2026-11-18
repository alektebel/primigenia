extends RefCounted
# CporeTerrain: defaults, hashes against build/terrain_cli, validation, progress, concurrency.

func run(t) -> void:
	var d: Dictionary = CporeTerrain.defaults()
	t.eq(d.size(), 47, "47 parameters (v4 adds rivers)")
	t.eq(d.n, 1024, "default n")
	t.eq(d.seed, 1, "default seed")
	t.eq(d.size_m, 3600.0, "default size_m")
	for k in ["gentle_bases", "layout_variety", "volcano"]:
		t.eq(d[k], 0.0, "W20 default " + k)
	for k in ["cliff_bands", "sea_cliffs", "hard_rock", "caves"]:
		t.eq(d[k], 1.0, "W20 default " + k)
	t.eq(CporeTerrain.version(), 4, "terrain version")
	t.eq(CporeTerrain.validate(d), 0, "defaults validate")
	run_relief(t)
	run_sun(t)

	var cli: String = t.build_path("terrain_cli")
	var cases := [[42, 64], [7, 128], [1234, 128], [1, 1024]]
	var gen = CporeTerrain.new()
	for c in cases:
		var p := d.duplicate()
		p.seed = c[0]
		p.n = c[1]
		var r: Dictionary = gen.generate(p)
		t.eq(r.get("error", -1), 0, "generate %s" % [c])
		var ref: Dictionary = t.exec(cli, ["hash", "--seed", str(c[0]), "--n", str(c[1])])
		t.eq(str(ref.out).split(" ")[0], r.get("hash", ""), "hash equals terrain_cli for %s" % [c])
		var level: PackedFloat32Array = r.water_level
		var h: PackedFloat32Array = r.height
		t.eq(level.size(), c[1] * c[1], "water_level size")
		var below := 0
		for k in h.size():
			if level[k] < h[k]:
				below += 1
		t.eq(below, 0, "water_level >= height everywhere %s" % [c])
		if c[1] == 1024:
			t.shared["big"] = r
		if c[0] == 42:
			t.eq(CporeTerrain.hash(r), r.hash, "hash() recomputes the generated hash")
			var bytes: PackedFloat32Array = r.height.duplicate()
			bytes[100] += 0.5
			var r2 := r.duplicate()
			r2.height = bytes
			t.check(CporeTerrain.hash(r2) != r.hash, "one changed height changes the hash")
			var bad := r.duplicate()
			bad.height = PackedFloat32Array([1.0])
			t.eq(CporeTerrain.hash(bad), "", "malformed data hashes to empty")
			t.check(r.volcano is Vector4 and r.caves is Array, "caves and volcano present")

	# Validation.
	for bad in [{"n": 64.5}, {"seed": -1}, {"seed": 4294967296}, {"not_a_param": 1}, {"n": "64"}, {"erosion": NAN}, {"erosion": INF}, {"n": 1}]:
		t.check(CporeTerrain.validate(bad) != 0, "validate rejects %s" % [bad])
		t.check(gen.generate(bad).error != 0, "generate rejects %s" % [bad])
	t.eq(CporeTerrain.validate({"n": 64.0, "seed": 5}), 0, "integral float accepted for an int field")
	t.eq(CporeTerrain.validate({"n": 64, "erosion": 1}), 0, "int accepted for a float field")

	# Threaded generation with polling.
	var worker = CporeTerrain.new()
	var p := d.duplicate()
	p.n = 256
	p.seed = 9
	var box := {"r": {}}
	var th := Thread.new()
	th.start(func(): box.r = worker.generate(p))
	var last := -1
	var monotonic := true
	var seen := {}
	while th.is_alive():
		var pr: Dictionary = worker.progress()
		if pr.stage < last:
			monotonic = false
		last = pr.stage
		seen[pr.stage] = true
		if seen.size() == 1 and pr.running:
			# While running, a second concurrent call on the same instance is refused.
			var second: Dictionary = worker.generate({"n": 32})
			t.eq(second.get("error", 0), -8, "concurrent generate returns CP_TERR_ERR_BUFFER")
			seen["second"] = true
		OS.delay_msec(2)
	th.wait_to_finish()
	t.check(seen.has("second"), "the concurrency probe ran while generating")
	var pr: Dictionary = worker.progress()
	t.check(monotonic, "progress stage is monotonic")
	t.eq(pr.stage, 4, "progress ends at stage 4")
	t.eq(pr.running, false, "not running at the end")
	t.eq(box.r.get("error", -1), 0, "threaded generate ok")

# PLAN-rock step 6: the presentation "relief" map from surface_maps().
func _relief_input(n: int, size_m: float, hfn: Callable, sed_fn: Callable) -> Dictionary:
	var h := PackedFloat32Array()
	var sd := PackedFloat32Array()
	h.resize(n * n)
	sd.resize(n * n)
	var cell := size_m / n
	for j in n:
		for i in n:
			var x := (i + 0.5) * cell - size_m * 0.5
			var z := (j + 0.5) * cell - size_m * 0.5
			h[j * n + i] = hfn.call(x, z)
			sd[j * n + i] = sed_fn.call(x, z)
	var mat := PackedByteArray()
	mat.resize(n * n)
	mat.fill(1)
	var zeros := PackedFloat32Array()
	zeros.resize(n * n)
	return {"n": n, "size_m": size_m, "height": h, "flow": zeros, "water_level": h.duplicate(), "sediment": sd, "material": mat}

func run_relief(t) -> void:
	var n := 128
	var size := 128.0 * 3.5
	var flat: Dictionary = CporeTerrain.surface_maps(_relief_input(n, size, func(_x, _z): return 50.0, func(_x, _z): return 0.0))
	t.check(flat.has("relief"), "surface_maps returns relief")
	var rf: PackedByteArray = flat.get("relief", PackedByteArray())
	t.eq(rf.size(), n * n * 4, "relief has n*n*4 bytes")
	var worst := 0
	for k in n * n:
		worst = maxi(worst, absi(rf[k * 4] - 128))
		worst = maxi(worst, absi(rf[k * 4 + 1] - 128))
	t.check(worst <= 1, "R and G read 128 +- 1 on a flat map (worst %d)" % worst)
	t.eq(rf[3], 255, "A (sun visibility) is 255 until step 9")
	t.eq(rf[2], 0, "B (sediment) is 0 with no sediment")
	# A V gully along z (floor at x = 0) next to a ridge along z (crest at x = 120).
	var vh := func(x, _z): return 0.5 * absf(x) + 15.0 * maxf(0.0, 1.0 - absf(x - 120.0) / 15.0)
	var m: Dictionary = CporeTerrain.surface_maps(_relief_input(n, size, vh, func(_x, _z): return 0.0))
	var r: PackedByteArray = m.relief
	var cell := size / n
	var at := func(x: float, ch: int) -> int:
		var i := clampi(floori((x + size * 0.5) / cell), 0, n - 1)
		return r[(n / 2 * n + i) * 4 + ch]
	t.check(at.call(0.0, 0) > 128 + 8, "the gully floor reads concave (R %d > 128)" % at.call(0.0, 0))
	t.check(at.call(0.0, 1) > 128, "the gully floor reads concave at broad scale (G %d)" % at.call(0.0, 1))
	t.check(at.call(120.0, 0) < 128 - 8, "the ridge crest reads convex (R %d < 128)" % at.call(120.0, 0))
	# Sediment: B is monotone.
	var sm: Dictionary = CporeTerrain.surface_maps(_relief_input(n, size, func(_x, _z): return 50.0, func(x, _z): return maxf(0.0, (x + size * 0.5) * 0.5)))
	var sr: PackedByteArray = sm.relief
	var mono := true
	var prev := -1
	for i in n:
		var b: int = sr[(n / 2 * n + i) * 4 + 2]
		if b < prev:
			mono = false
		prev = b
	t.check(mono and prev > 150, "B is monotone in sediment and reaches %d" % prev)
	var bad: Dictionary = CporeTerrain.surface_maps({"n": n, "size_m": size, "height": PackedFloat32Array()})
	t.check(bad.is_empty(), "surface_maps refuses input without sediment")

# PLAN-rock step 9: baked sun visibility (off by default in the game).
func run_sun(t) -> void:
	var n := 128
	var size := 128.0 * 3.5
	var sun := Vector3(-0.62, 0.28, -0.72).normalized()
	var flat: PackedByteArray = CporeTerrain.sun_visibility(_relief_input(n, size, func(_x, _z): return 50.0, func(_x, _z): return 0.0), sun)
	t.eq(flat.size(), n * n, "sun_visibility has n*n bytes")
	var mn := 255
	for b in flat:
		mn = mini(mn, b)
	t.check(mn >= 250, "flat ground is fully lit (min %d)" % mn)
	# A 60 m wall across x at x = 0 (z-independent): the sun comes from -x, so cells just east of it are shadowed, west lit.
	var s2 := Vector3(-0.9, 0.3, 0.0).normalized()
	var wall: PackedByteArray = CporeTerrain.sun_visibility(_relief_input(n, size, func(x, _z): return 60.0 if x > -4.0 and x < 4.0 else 0.0, func(_x, _z): return 0.0), s2)
	var cell := size / n
	var at := func(x: float) -> int: return wall[(n / 2) * n + clampi(floori((x + size * 0.5) / cell), 0, n - 1)]
	t.check(at.call(-60.0) > 240, "west of the wall (sun side) is lit (%d)" % at.call(-60.0))
	t.check(at.call(40.0) < 40, "40 m behind the wall is in shadow (%d)" % at.call(40.0))
	t.check(at.call(200.0) > 200, "far behind the wall the shadow has ended (%d)" % at.call(200.0))
	t.check(CporeTerrain.sun_visibility({"n": n}, sun).is_empty(), "invalid input gives an empty array")
