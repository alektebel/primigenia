extends RefCounted
# Terrain arrays plus everything the renderers and gameplay derive from them.
# One ground() function serves creatures, camera collision, pointer, grass and stage setup;
# it is the exact surface of the LOD0 mesh (same triangle diagonal). Only the shading normal is smoothed (smooth_normal).

# Bump when the derived maps (surface and relief RGBA8, chunk bounds) change; part of the cache key.
const RENDER_PREP_VERSION := 5
const CHUNK_CELLS := 64
# Visual heightfield (terrain v5): VISUAL_FACTOR times finer than the sim grid, rendered by the terrain and used for feet, grass and the camera.
const VISUAL_FACTOR := 4

# Factor for a sim grid of n cells: 4, or 2 when n is 2048 (the visual grid stays at most 4096 squared).
static func visual_factor(n: int) -> int:
	return clampi(4096 / maxi(n, 1), 2, VISUAL_FACTOR)

var n: int = 0
var size_m: float = 0.0
var cell: float = 0.0
var half: float = 0.0
var height: PackedFloat32Array
var flow: PackedFloat32Array
var water_level: PackedFloat32Array
var material: PackedByteArray
var river: PackedByteArray        # CP_TERR_RIVER_*: 0 none, 1 stream, 2 shallow river, 3 deep river (terrain v4)
var surface: PackedByteArray      # RGBA8: R material id, G grass mask, B cavity, A wetness
var relief: PackedByteArray       # RGBA8: R fine curvature, G broad curvature (> 128 concave), B sediment, A sun visibility
var chunk_bounds: PackedFloat32Array
var chunks_per_side: int = 0
var caves: Array = []
var volcano: Vector4 = Vector4.ZERO
var vn: int = 0                   # visual grid side (n * VISUAL_FACTOR)
var vcell: float = 0.0
var vheight: PackedByteArray      # uint16 LE, vn*vn: height = vh_min + vh_range * v / 65535
var vh_min: float = 0.0
var vh_range: float = 1.0
var vmaps: PackedByteArray        # RGBA8, (vn/2)^2: R flow/wetness, G droplet deposition, B talus apron, A exposure (> 128 convex)
var vheight_tex: ImageTexture
var vmaps_tex: ImageTexture
var height_tex: ImageTexture
var level_tex: ImageTexture
var surface_tex: ImageTexture
var relief_tex: ImageTexture

# Adds the derived maps to a CporeTerrain.generate() result (worker-thread safe).
static func prepare(entry: Dictionary) -> void:
	var maps: Dictionary = CporeTerrain.surface_maps(entry)
	entry["surface"] = maps.get("surface", PackedByteArray())
	entry["relief"] = maps.get("relief", PackedByteArray())
	entry["chunk_bounds"] = maps.get("chunk_bounds", PackedFloat32Array())
	entry["chunks_per_side"] = maps.get("chunks_per_side", 0)
	var vis: Dictionary = CporeTerrain.visual_maps(entry, {"factor": visual_factor(int(entry.n))})
	for key in ["vn", "vheight", "vh_min", "vh_range", "vmaps", "vhash", "vstats"]:
		entry[key] = vis.get(key)
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
	river = entry.get("river", PackedByteArray())
	surface = entry.surface
	relief = entry.relief
	chunk_bounds = entry.chunk_bounds
	chunks_per_side = entry.chunks_per_side
	caves = entry.caves
	volcano = entry.volcano
	vn = entry.get("vn", 0)
	if vn > 0:
		vcell = size_m / float(vn)
		vheight = entry.vheight
		vh_min = entry.vh_min
		vh_range = entry.vh_range
		vmaps = entry.vmaps
	if build_textures:
		if vn > 0:
			vheight_tex = ImageTexture.create_from_image(Image.create_from_data(vn, vn, false, Image.FORMAT_R16, vheight))
			vmaps_tex = ImageTexture.create_from_image(Image.create_from_data(vn / 2, vn / 2, false, Image.FORMAT_RGBA8, vmaps))
		height_tex = _tex(Image.FORMAT_RF, height.to_byte_array())
		level_tex = _tex(Image.FORMAT_RF, water_level.to_byte_array())
		surface_tex = _tex(Image.FORMAT_RGBA8, surface)
		relief_tex = _tex(Image.FORMAT_RGBA8, relief)

# PLAN-rock step 9 (optional, off by default): bakes the sun visibility into relief.A and refreshes the texture in place (materials keep
# their reference). Not cached: ~0.3 s at 1024. Returns the bake time in ms, or -1 when the input is invalid.
func apply_sun_shadows(sun: Vector3) -> int:
	var t0 := Time.get_ticks_msec()
	var vis: PackedByteArray = CporeTerrain.sun_visibility({"n": n, "size_m": size_m, "height": height}, sun)
	if vis.size() != n * n:
		return -1
	for k in n * n:
		relief[k * 4 + 3] = vis[k]
	if relief_tex != null:
		relief_tex.update(Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, relief))
	return Time.get_ticks_msec() - t0

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

# Sets the visual heightfield and erosion map uniforms (terrain_maps.gdshaderinc) on a ShaderMaterial.
func bind_visual(m: ShaderMaterial) -> void:
	m.set_shader_parameter("vheight_tex", vheight_tex)
	m.set_shader_parameter("vmaps_tex", vmaps_tex)
	m.set_shader_parameter("VIS_N", vn)
	m.set_shader_parameter("VIS_CELL", vcell)
	m.set_shader_parameter("VH_MIN", vh_min)
	m.set_shader_parameter("VH_RANGE", vh_range)

func _vh(i: int, j: int) -> float:
	return vh_min + vh_range * (1.0 / 65535.0) * float(vheight.decode_u16((clampi(j, 0, vn - 1) * vn + clampi(i, 0, vn - 1)) * 2))

# Surface of the visual heightfield (the LOD0 mesh: same triangle diagonal on the vn grid). Feet, grass and the camera stand on this; the
# C sim keeps ground(). Within about 0.4 m of ground() on walkable ground (test_visual.gd), exactly equal near rivers, lakes and the coast.
func visual_ground(x: float, z: float) -> float:
	if vn == 0:
		return ground(x, z)
	var u := (x + half) / vcell - 0.5
	var v := (z + half) / vcell - 0.5
	var i := clampi(floori(u), 0, vn - 2)
	var j := clampi(floori(v), 0, vn - 2)
	var fu := clampf(u - float(i), 0.0, 1.0)
	var fv := clampf(v - float(j), 0.0, 1.0)
	var h00 := _vh(i, j)
	var h10 := _vh(i + 1, j)
	var h01 := _vh(i, j + 1)
	var h11 := _vh(i + 1, j + 1)
	if fu >= fv:
		return h00 + fu * (h10 - h00) + fv * (h11 - h10)
	return h00 + fv * (h01 - h00) + fu * (h11 - h01)

func normal(x: float, z: float) -> Vector3:
	var dx := ground(x + cell, z) - ground(x - cell, z)
	var dz := ground(x, z + cell) - ground(x, z - cell)
	return Vector3(-dx, 2.0 * cell, -dz).normalized()

# Shading normal of the terrain shaders (terrain_maps.gdshaderinc ground_normal): Catmull-Rom bicubic gradient of the height
# texels. Smooth (C1) across cells; the geometry itself remains the triangle surface of ground().
func smooth_normal(x: float, z: float) -> Vector3:
	var u := (x + half) / cell - 0.5
	var v := (z + half) / cell - 0.5
	var i := floori(u)
	var j := floori(v)
	var fx := u - float(i)
	var fy := v - float(j)
	var wx := _cr(fx)
	var wy := _cr(fy)
	var dx := _cr_d(fx)
	var dy := _cr_d(fy)
	var gx := 0.0
	var gz := 0.0
	for b in 4:
		var row := 0.0
		var rowd := 0.0
		for a in 4:
			var hh := _hc(i + a - 1, j + b - 1)
			row += wx[a] * hh
			rowd += dx[a] * hh
		gx += rowd * wy[b]
		gz += row * dy[b]
	return Vector3(-gx / cell, 1.0, -gz / cell).normalized()

func _hc(i: int, j: int) -> float:
	return height[clampi(j, 0, n - 1) * n + clampi(i, 0, n - 1)]

static func _cr(f: float) -> Array:
	var f2 := f * f
	var f3 := f2 * f
	return [(-f3 + 2.0 * f2 - f) * 0.5, (3.0 * f3 - 5.0 * f2 + 2.0) * 0.5, (-3.0 * f3 + 4.0 * f2 + f) * 0.5, (f3 - f2) * 0.5]

static func _cr_d(f: float) -> Array:
	var f2 := f * f
	return [(-3.0 * f2 + 4.0 * f - 1.0) * 0.5, (9.0 * f2 - 10.0 * f) * 0.5, (-9.0 * f2 + 8.0 * f + 1.0) * 0.5, (3.0 * f2 - 2.0 * f) * 0.5]

func is_sea(k: int) -> bool:
	return height[k] <= 0.0

func is_pond(k: int) -> bool:
	return water_level[k] - height[k] > 0.5 and height[k] > 0.0

func cell_index(x: float, z: float) -> int:
	var i := clampi(floori((x + half) / cell), 0, n - 1)
	var j := clampi(floori((z + half) / cell), 0, n - 1)
	return j * n + i

# River class of cell k (0 none, 1 stream, 2 shallow, 3 deep); 0 when the entry has no river map.
func river_class(k: int) -> int:
	return river[k] & 3 if river.size() == n * n else 0

func is_river(k: int) -> bool:
	return river_class(k) > 0

# Water the C world blocks on: deep river, lake or sea (depth > 0.7 m; shallow river is 0.6 m and walkable).
func is_pond_at(x: float, z: float) -> bool:
	return is_pond(cell_index(x, z))
