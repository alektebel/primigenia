extends RefCounted
# Terrain arrays plus everything the renderers and gameplay derive from them.
# One ground() function serves creatures, camera collision, pointer, grass and stage setup;
# it is the exact surface of the LOD0 mesh (same triangle diagonal).

# Bump when the derived maps (surface RGBA8, chunk bounds) change; part of the cache key.
const RENDER_PREP_VERSION := 1
const CHUNK_CELLS := 64

var n: int = 0
var size_m: float = 0.0
var cell: float = 0.0
var half: float = 0.0
var height: PackedFloat32Array
var flow: PackedFloat32Array
var water_level: PackedFloat32Array
var material: PackedByteArray
var surface: PackedByteArray      # RGBA8: R material id, G grass mask, B cavity, A wetness
var chunk_bounds: PackedFloat32Array
var chunks_per_side: int = 0
var caves: Array = []
var volcano: Vector4 = Vector4.ZERO
var height_tex: ImageTexture
var level_tex: ImageTexture
var surface_tex: ImageTexture

# Adds the derived maps to a CporeTerrain.generate() result (worker-thread safe).
static func prepare(entry: Dictionary) -> void:
	var maps: Dictionary = CporeTerrain.surface_maps(entry)
	entry["surface"] = maps.get("surface", PackedByteArray())
	entry["chunk_bounds"] = maps.get("chunk_bounds", PackedFloat32Array())
	entry["chunks_per_side"] = maps.get("chunks_per_side", 0)
	entry["render_prep"] = RENDER_PREP_VERSION

func setup(entry: Dictionary, build_textures: bool = true) -> void:
	n = entry.n
	size_m = entry.size_m
	cell = size_m / float(n)
	half = size_m * 0.5
	height = entry.height
	flow = entry.flow
	water_level = entry.water_level
	material = entry.material
	surface = entry.surface
	chunk_bounds = entry.chunk_bounds
	chunks_per_side = entry.chunks_per_side
	caves = entry.caves
	volcano = entry.volcano
	if build_textures:
		height_tex = _tex(Image.FORMAT_RF, height.to_byte_array())
		level_tex = _tex(Image.FORMAT_RF, water_level.to_byte_array())
		surface_tex = _tex(Image.FORMAT_RGBA8, surface)

func _tex(format: Image.Format, bytes: PackedByteArray) -> ImageTexture:
	return ImageTexture.create_from_image(Image.create_from_data(n, n, false, format, bytes))

func cell_center(i: int) -> float:
	return (float(i) + 0.5) * cell - half

# Exact LOD0 surface: two triangles per quad, diagonal (i+1, j) - (i, j+1). Clamped outside.
func ground(x: float, z: float) -> float:
	var u := (x + half) / cell - 0.5
	var v := (z + half) / cell - 0.5
	var i := clampi(floori(u), 0, n - 2)
	var j := clampi(floori(v), 0, n - 2)
	var fu := clampf(u - float(i), 0.0, 1.0)
	var fv := clampf(v - float(j), 0.0, 1.0)
	var k := j * n + i
	var h00 := height[k]
	var h10 := height[k + 1]
	var h01 := height[k + n]
	var h11 := height[k + n + 1]
	if fu >= fv:
		return h00 + fu * (h10 - h00) + fv * (h11 - h10)
	return h00 + fv * (h01 - h00) + fu * (h11 - h01)

func normal(x: float, z: float) -> Vector3:
	var dx := ground(x + cell, z) - ground(x - cell, z)
	var dz := ground(x, z + cell) - ground(x, z - cell)
	return Vector3(-dx, 2.0 * cell, -dz).normalized()

func is_sea(k: int) -> bool:
	return height[k] <= 0.0

func is_pond(k: int) -> bool:
	return water_level[k] - height[k] > 0.5 and height[k] > 0.0

func cell_index(x: float, z: float) -> int:
	var i := clampi(floori((x + half) / cell), 0, n - 1)
	var j := clampi(floori((z + half) / cell), 0, n - 1)
	return j * n + i

func is_pond_at(x: float, z: float) -> bool:
	return is_pond(cell_index(x, z))
