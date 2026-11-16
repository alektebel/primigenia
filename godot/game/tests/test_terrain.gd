extends RefCounted
# CporeTerrain: defaults, hashes against build/terrain_cli, validation, progress, concurrency.

func run(t) -> void:
	var d: Dictionary = CporeTerrain.defaults()
	t.eq(d.size(), 46, "46 parameters")
	t.eq(d.n, 1024, "default n")
	t.eq(d.seed, 1, "default seed")
	t.eq(d.size_m, 3600.0, "default size_m")
	for k in ["gentle_bases", "layout_variety", "volcano"]:
		t.eq(d[k], 0.0, "W20 default " + k)
	for k in ["cliff_bands", "sea_cliffs", "hard_rock", "caves"]:
		t.eq(d[k], 1.0, "W20 default " + k)
	t.eq(CporeTerrain.version(), 3, "terrain version")
	t.eq(CporeTerrain.validate(d), 0, "defaults validate")

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
