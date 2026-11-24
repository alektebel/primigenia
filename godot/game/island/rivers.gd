extends Node3D
# River ribbons (docs/godot/HYDROLOGY.md): one triangle strip per channel, built from the C river map (class in bits 0..1,
# receiver direction + 1 in bits 2..5 of data.river). The ribbon follows the water level the C world reads
# (bed + 0.35 / 0.6 / 1.2 m), so what you see is what the sim treats as water. UV.x = metres along the flow / 4, UV.y = -1..1
# across; COLOR.r = class / 3, COLOR.g = bed drop per metre (rapids, waterfalls), COLOR.b = drainage (0..1, log).

const WorldLight := preload("res://game/island/world_light.gd")
const RIVER_SHADER := preload("res://game/shaders/river.gdshader")
const DX := [1, 1, 0, -1, -1, -1, 0, 1]
const DY := [0, 1, 1, 1, 0, -1, -1, -1]
const LIFT := 0.12

var mesh_instance: MeshInstance3D
var tier := 2                    # terrain tier (WorldLight)
var chain_count := 0
var vertex_count := 0

# Downstream cell of river cell k, or -1 at an outlet.
static func next_cell(data, k: int) -> int:
	var d: int = (data.river[k] >> 2) - 1
	if d < 0 or d > 7:
		return -1
	var x: int = k % data.n + DX[d]
	var y: int = k / data.n + DY[d]
	if x < 0 or y < 0 or x >= data.n or y >= data.n:
		return -1
	return y * data.n + x

# Channels as arrays of cell indices, source first. A channel stops after the first cell an earlier channel already uses,
# so a trunk is drawn once and tributaries end on it. Sources are visited in descending drainage so the trunk goes first.
static func chains(data) -> Array:
	var n: int = data.n
	var has_up := PackedByteArray()
	has_up.resize(n * n)
	var sources: Array = []
	for k in n * n:
		if data.river[k] & 3 != 0:
			var nx := next_cell(data, k)
			if nx >= 0 and data.river[nx] & 3 != 0:
				has_up[nx] = 1
	for k in n * n:
		if data.river[k] & 3 != 0 and has_up[k] == 0:
			sources.append(k)
	sources.sort_custom(func(a, b): return data.flow[a] > data.flow[b] or (data.flow[a] == data.flow[b] and a < b))
	var seen := PackedByteArray()
	seen.resize(n * n)
	var out: Array = []
	for s in sources:
		var chain := PackedInt32Array()
		var k: int = s
		while k >= 0 and data.river[k] & 3 != 0:
			chain.append(k)
			if seen[k] == 1:
				break
			seen[k] = 1
			k = next_cell(data, k)
		if chain.size() >= 3:
			out.append(chain)
	return out

static func width_for(area_m2: float) -> float:
	return maxf(2.6, 1.0 + 0.012 * sqrt(area_m2))

## `chains_in`: the channels when already computed (worker thread, see island.gd).
func build(data, chains_in = null) -> void:
	if data.river.size() != data.n * data.n:
		return
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var cell2: float = data.cell * data.cell
	var nn: float = data.n * data.n
	for chain in (chains(data) if chains_in == null else chains_in):
		var m: int = chain.size()
		var px := PackedFloat32Array()
		var pz := PackedFloat32Array()
		var py := PackedFloat32Array()
		for q in m:
			var k: int = chain[q]
			px.append(data.cell_center(k % data.n))
			pz.append(data.cell_center(k / data.n))
			py.append(data.water_level[k])
		# Two smoothing passes (1-2-1) keep the 8-neighbour zigzag out of the banks; the ends stay put.
		for pass_i in 2:
			var sx := px.duplicate()
			var sz := pz.duplicate()
			var sy := py.duplicate()
			for q in range(1, m - 1):
				sx[q] = 0.25 * px[q - 1] + 0.5 * px[q] + 0.25 * px[q + 1]
				sz[q] = 0.25 * pz[q - 1] + 0.5 * pz[q] + 0.25 * pz[q + 1]
				sy[q] = 0.25 * py[q - 1] + 0.5 * py[q] + 0.25 * py[q + 1]
			px = sx
			pz = sz
			py = sy
		var base := verts.size()
		var along := 0.0
		for q in m:
			var k: int = chain[q]
			var q0 := maxi(q - 1, 0)
			var q1 := mini(q + 1, m - 1)
			var tx: float = px[q1] - px[q0]
			var tz: float = pz[q1] - pz[q0]
			var tl := maxf(sqrt(tx * tx + tz * tz), 1e-4)
			tx /= tl
			tz /= tl
			var area: float = data.flow[k] * nn * cell2
			var half: float = width_for(area) * 0.5
			var drop: float = (py[q0] - py[q1]) / maxf(tl, 1e-3)
			if q > 0:
				along += Vector2(px[q] - px[q - 1], pz[q] - pz[q - 1]).length()
			var cls: float = float(data.river[k] & 3) / 3.0
			var lg := clampf((log(maxf(area, 1.0)) / log(10.0) - 4.4) / 2.4, 0.0, 1.0)
			var c := Color(cls, clampf(drop, 0.0, 1.0), lg, 1.0)
			verts.append(Vector3(px[q] - tz * half, py[q] + LIFT, pz[q] + tx * half))
			verts.append(Vector3(px[q] + tz * half, py[q] + LIFT, pz[q] - tx * half))
			uvs.append(Vector2(along / 4.0, -1.0))
			uvs.append(Vector2(along / 4.0, 1.0))
			cols.append(c)
			cols.append(c)
		for q in m - 1:
			var a := base + q * 2
			idx.append_array([a, a + 1, a + 3, a, a + 3, a + 2])
		chain_count += 1
	if verts.is_empty():
		return
	vertex_count = verts.size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = WorldLight.shader_for(RIVER_SHADER, tier)
	mat.set_shader_parameter("height_tex", data.height_tex)
	mat.set_shader_parameter("MAP_N", data.n)
	mat.set_shader_parameter("MAP_CELL", data.cell)
	mat.set_shader_parameter("MAP_HALF", data.half)
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "Rivers"
	mesh_instance.mesh = mesh
	mesh_instance.material_override = mat
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.custom_aabb = AABB(Vector3(-4000, -100, -4000), Vector3(8000, 1000, 8000))   # the 8 km Star massif field
	add_child(mesh_instance)
