extends RefCounted
# TerrainCache: miss then hit; corruption paths regenerate; the key encodes the versions.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const DIR := "user://m0-tests"

func _params(extra: Dictionary = {}) -> Dictionary:
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 128
	p.seed = 21
	for k in extra:
		p[k] = extra[k]
	return p

func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _clean() -> void:
	var d := DirAccess.open("user://")
	if d != null and d.dir_exists("m0-tests"):
		var dir := DirAccess.open(DIR)
		for f in dir.get_files():
			dir.remove(f)
		d.remove("m0-tests")

func run(t) -> void:
	_clean()
	var p := _params()
	var first: Dictionary = TerrainCache.get_or_build(p, DIR)
	t.eq(first.hit, false, "first load is a miss")
	t.eq(first.entry.get("error", -1), 0, "first load generated")
	var second: Dictionary = TerrainCache.get_or_build(p, DIR)
	t.eq(second.hit, true, "second load is a hit")
	t.eq(second.entry.hash, first.entry.hash, "hit has the same hash")
	t.check(second.entry.height == first.entry.height and second.entry.surface == first.entry.surface
		and second.entry.chunk_bounds == first.entry.chunk_bounds and second.entry.water_level == first.entry.water_level,
		"hit has equal maps")
	print("  cache miss %d ms, hit %d ms (n=128)" % [first.ms, second.ms])

	var path := TerrainCache.cache_path(p, DIR)
	t.check(path.contains("-t%d-" % CporeTerrain.version()) and path.contains("-r1-") and path.contains("island-21-"),
		"key contains seed, generator version and render prep version: " + path)
	t.check(TerrainCache.cache_path(_params({"erosion": 0.2}), DIR) != path, "changed erosion gives a different path")
	t.eq(TerrainCache.cache_path({"n": 128, "seed": 21}, DIR), path, "partial params resolve to the same key")

	# Truncated file.
	var size := FileAccess.get_file_as_bytes(path).size()
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.resize(size / 2)
	f.close()
	t.check(TerrainCache.load_entry(p, DIR).is_empty(), "truncated file is a miss")
	t.eq(TerrainCache.get_or_build(p, DIR).hit, false, "truncated file regenerates")
	t.eq(TerrainCache.get_or_build(p, DIR).hit, true, "and then hits again")

	# Wrong magic and wrong format version.
	var entry: Dictionary = first.entry
	for case in [[0x12345678, TerrainCache.FORMAT_VERSION, "wrong magic"], [TerrainCache.MAGIC, 99, "wrong format version"]]:
		var w := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
		w.store_32(case[0])
		w.store_32(case[1])
		w.store_var(entry, false)
		w.close()
		t.check(TerrainCache.load_entry(p, DIR).is_empty(), case[2] + " is a miss")
	t.eq(TerrainCache.get_or_build(p, DIR).hit, false, "regenerates after bad header")

	# Modified height: structurally valid but the hash no longer matches.
	var tampered: Dictionary = TerrainCache.load_entry(p, DIR)
	t.check(not tampered.is_empty(), "valid entry loads before tampering")
	var hh: PackedFloat32Array = tampered.height
	hh[10] = hh[10] + 1.0
	tampered.height = hh
	TerrainCache.save_entry(p, tampered, DIR)
	t.check(TerrainCache.load_entry(p, DIR).is_empty(), "modified height fails the hash check")
	t.eq(TerrainCache.get_or_build(p, DIR).hit, false, "tampered file regenerates")

	# Garbage file.
	var g := FileAccess.open(path, FileAccess.WRITE)
	g.store_string("not a cache file")
	g.close()
	t.check(TerrainCache.load_entry(p, DIR).is_empty(), "garbage file is a miss")
	_clean()
	t.check(not DirAccess.dir_exists_absolute(_abs(DIR)), "test directory removed")

	# Loading-screen progress is monotonic over a stage sequence.
	var Loading := preload("res://game/loading/loading_screen.gd")
	var last := -1.0
	var mono := true
	for stage in 5:
		for step in 11:
			var frac: float = Loading.overall_fraction(stage, step, 10)
			if frac < last - 1e-9:
				mono = false
			last = frac
	t.check(mono and last <= 1.0 and last > 0.9, "overall progress fraction is monotonic and ends near 1")
	t.check(absf(Loading.STAGE_WEIGHT.reduce(func(a, b): return a + b) - 1.0) < 0.002, "stage weights sum to 1")
