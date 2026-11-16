extends RefCounted
# On-disk cache of generated islands: user://terrain/island-<seed>-t<ver>-r<prep>-<digest>.bin
# zstd-compressed; magic + format + one Variant (no objects). A hit is verified by the C hash.

const TerrainData := preload("res://game/island/terrain_data.gd")

const MAGIC := 0x30304D43  # "CM00"
const FORMAT_VERSION := 1
const DEFAULT_DIR := "user://terrain"

static func resolve(params: Dictionary) -> Dictionary:
	var out: Dictionary = CporeTerrain.defaults()
	for k in params:
		out[k] = params[k]
	var defaults: Dictionary = CporeTerrain.defaults()
	for k in defaults:
		out[k] = int(out[k]) if typeof(defaults[k]) == TYPE_INT else float(out[k])
	return out

static func digest(params: Dictionary) -> String:
	var pairs := []
	var keys := params.keys()
	keys.sort()
	for k in keys:
		pairs.append([k, params[k]])
	return JSON.stringify(pairs).sha256_text().left(16)

static func cache_path(params: Dictionary, dir: String = DEFAULT_DIR) -> String:
	var p := resolve(params)
	return "%s/island-%d-t%d-r%d-%s.bin" % [dir, p.seed, CporeTerrain.version(), TerrainData.RENDER_PREP_VERSION, digest(p)]

static func _valid(entry: Dictionary, params: Dictionary) -> bool:
	for key in ["height", "flow", "sediment", "water_level"]:
		if typeof(entry.get(key)) != TYPE_PACKED_FLOAT32_ARRAY:
			return false
	for key in ["material", "surface"]:
		if typeof(entry.get(key)) != TYPE_PACKED_BYTE_ARRAY:
			return false
	if typeof(entry.get("chunk_bounds")) != TYPE_PACKED_FLOAT32_ARRAY or typeof(entry.get("caves")) != TYPE_ARRAY:
		return false
	if typeof(entry.get("volcano")) != TYPE_VECTOR4 or typeof(entry.get("hash")) != TYPE_STRING:
		return false
	if typeof(entry.get("n")) != TYPE_INT or typeof(entry.get("params")) != TYPE_DICTIONARY:
		return false
	var n: int = entry.n
	if n < 8 or entry.height.size() != n * n or entry.flow.size() != n * n or entry.sediment.size() != n * n \
			or entry.water_level.size() != n * n or entry.material.size() != n * n or entry.surface.size() != n * n * 4:
		return false
	if entry.get("version") != CporeTerrain.version() or entry.get("render_prep") != TerrainData.RENDER_PREP_VERSION:
		return false
	if entry.params != params or entry.get("seed") != params.seed:
		return false
	var cps: int = (n + TerrainData.CHUNK_CELLS - 1) / TerrainData.CHUNK_CELLS
	if entry.get("chunks_per_side") != cps or entry.chunk_bounds.size() != cps * cps * 2:
		return false
	return CporeTerrain.hash(entry) == entry.hash

# Returns the verified entry, or {} on any miss/corruption.
static func load_entry(params: Dictionary, dir: String = DEFAULT_DIR) -> Dictionary:
	var p := resolve(params)
	var path := cache_path(p, dir)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return {}
	if f.get_32() != MAGIC or f.get_32() != FORMAT_VERSION:
		return {}
	var v = f.get_var(false)
	if f.get_error() != OK or typeof(v) != TYPE_DICTIONARY or not _valid(v, p):
		return {}
	return v

static func save_entry(params: Dictionary, entry: Dictionary, dir: String = DEFAULT_DIR) -> bool:
	var path := cache_path(params, dir)
	DirAccess.make_dir_recursive_absolute(dir)
	var tmp := path + ".tmp"
	var f := FileAccess.open_compressed(tmp, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	f.store_32(MAGIC)
	f.store_32(FORMAT_VERSION)
	f.store_var(entry, false)
	f.close()
	return DirAccess.rename_absolute(tmp, path) == OK

# Generate + derived maps (+ save). `gen` is a CporeTerrain; safe on a worker thread.
static func build(params: Dictionary, gen, dir: String = DEFAULT_DIR, save: bool = true) -> Dictionary:
	var p := resolve(params)
	var entry: Dictionary = gen.generate(p)
	if entry.get("error", -1) != 0:
		return entry
	TerrainData.prepare(entry)
	if save:
		save_entry(p, entry, dir)
	return entry

# Synchronous convenience: {entry, hit, ms}.
static func get_or_build(params: Dictionary, dir: String = DEFAULT_DIR) -> Dictionary:
	var t0 := Time.get_ticks_msec()
	var p := resolve(params)
	var entry := load_entry(p, dir)
	var hit := not entry.is_empty()
	if not hit:
		entry = build(p, CporeTerrain.new(), dir)
	return {"entry": entry, "hit": hit, "ms": Time.get_ticks_msec() - t0}
