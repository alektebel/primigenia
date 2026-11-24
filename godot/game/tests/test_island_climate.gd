extends RefCounted
# Island descs and their climate maps through the extension and the cache (island-realism plan part II, M2):
# generate({island_blob}) returns climate, biome, veg byte-identical to build/terrain_cli (hash --desc --climate); island_info; the cache key and verify.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const DIR := "user://m2-tests"

func _abs(path: String) -> String:
	return ProjectSettings.globalize_path(path)

func _clean() -> void:
	var d := DirAccess.open("user://")
	if d != null and d.dir_exists("m2-tests"):
		var dir := DirAccess.open(DIR)
		for f in dir.get_files():
			dir.remove(f)
		d.remove("m2-tests")

func run(t) -> void:
	var blob_path: String = t.build_path("island/star_f0.isl")
	t.check(FileAccess.file_exists(blob_path), "the Star massif blob exists (make build/island/star_f0.isl)")
	var blob := FileAccess.get_file_as_bytes(blob_path)
	var info: Dictionary = CporeTerrain.island_info(blob)
	t.eq(info.get("error", -1), 0, "island_info parses the blob")
	t.eq(info.get("id", ""), "star-massif", "island id")
	t.eq(str(info.get("hash", "")).length(), 16, "island hash is 16 hex digits")
	t.eq(info.get("n", 0), 1536, "island n")
	t.check(CporeTerrain.island_info(blob.slice(0, 40)).get("error", 0) != 0, "a truncated blob is refused")
	t.eq(CporeTerrain.climate_version(), 1, "climate kernel version")

	var p: Dictionary = CporeTerrain.defaults()
	p.n = 256
	p.seed = 1
	var opts := p.duplicate()
	opts["island_blob"] = blob
	var r: Dictionary = CporeTerrain.new().generate(opts)
	t.eq(r.get("error", -1), 0, "generate with an island blob")
	t.eq(r.get("island", ""), "star-massif", "result names the island")
	t.eq(r.get("island_hash", ""), info.hash, "result carries the island hash")
	t.eq(r.get("climate_n", 0), 256, "climate grid 256")
	t.eq(r.get("climate", PackedByteArray()).size(), 256 * 256 * 4, "climate map size")
	t.eq(r.get("biome", PackedByteArray()).size(), 256 * 256, "biome map size")
	t.eq(r.get("veg", PackedByteArray()).size(), 256 * 256 * 4, "veg map size")
	t.eq(r.size_m, 8000.0, "the desc sets the size")
	var cli: String = t.build_path("terrain_cli")
	var ref: Dictionary = t.exec(cli, ["hash", "--desc", blob_path, "--seed", "1", "--n", "256", "--climate"])
	var words := str(ref.out).split("\n")[0].split(" ")
	var chash := str(ref.out).split("\n")[1].split(" ")[1] if str(ref.out).split("\n").size() > 1 else ""
	t.eq(words[0], r.get("hash", ""), "terrain hash equals terrain_cli --desc")
	t.eq(chash, r.get("climate_hash", "x"), "climate hash equals terrain_cli --desc --climate")
	t.eq(CporeTerrain.climate_hash(r), r.get("climate_hash", "x"), "CporeTerrain.climate_hash recomputes it")
	t.eq(CporeTerrain.hash(r), r.get("hash", "x"), "CporeTerrain.hash recomputes the terrain hash of a desc island (it mixes the desc hash)")
	var biome: PackedByteArray = r.biome
	var seen := {}
	for b in biome:
		seen[b] = true
	t.check(seen.has(0) and seen.has(3), "the biome map has sea and meadow")
	# a seed island has no climate keys, and a bad blob is an error
	var plain: Dictionary = CporeTerrain.new().generate(p)
	t.check(not plain.has("climate") and not plain.has("island"), "a seed island carries no climate")
	var bad := p.duplicate()
	bad["island_blob"] = blob.slice(0, 100)
	t.check(CporeTerrain.new().generate(bad).get("error", 0) != 0, "a bad blob is refused")

	# the cache: the blob becomes the key (island + island_hash + climate version), maps are verified on load
	_clean()
	var q := p.duplicate()
	q["island_blob"] = blob
	var first: Dictionary = TerrainCache.get_or_build(q, DIR)
	t.eq(first.hit, false, "island: first load is a miss")
	t.eq(first.entry.get("error", -1), 0, "island: first load generated")
	var key := TerrainCache.resolve(q)
	t.check(not key.has("island_blob") and key.island == "star-massif" and key.island_hash == info.hash, "resolve turns the blob into the key")
	var path := TerrainCache.cache_path(q, DIR)
	t.check(path.contains("-istar-massif-d%s-c%d-" % [info.hash, CporeTerrain.climate_version()]), "key carries id, desc hash and climate version: " + path)
	var second: Dictionary = TerrainCache.get_or_build(q, DIR)
	t.eq(second.hit, true, "island: second load is a hit")
	t.check(second.entry.climate == first.entry.climate and second.entry.biome == first.entry.biome and second.entry.veg == first.entry.veg
		and second.entry.climate_hash == first.entry.climate_hash, "island: the hit has equal climate maps")
	var tampered: Dictionary = TerrainCache.load_entry(q, DIR)
	var bio: PackedByteArray = tampered.biome
	bio[1000] = (bio[1000] + 1) % 13
	tampered.biome = bio
	TerrainCache.save_entry(TerrainCache.resolve(q), tampered, DIR)
	t.check(TerrainCache.load_entry(q, DIR).is_empty(), "island: a modified biome map fails the climate hash")
	t.eq(TerrainCache.get_or_build(q, DIR).hit, false, "island: the tampered file regenerates")
	var other := q.duplicate()
	other["island_blob"] = blob.slice(0, blob.size())
	var tail := blob.duplicate()
	tail[16 + 4 * 14] = (tail[16 + 4 * 14] + 1) % 256       # lake x: another desc
	t.check(CporeTerrain.island_info(tail).get("error", 0) != 0, "a patched blob without its CRC is refused")
	_clean()
	t.check(not DirAccess.dir_exists_absolute(_abs(DIR)), "island test directory removed")
