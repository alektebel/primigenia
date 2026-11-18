extends Node3D
# Sea (one big plane at y = 0) and lakes (CPU mesh over pond cells at their routing water level).

const WATER_SHADER := preload("res://game/shaders/water.gdshader")

var material: ShaderMaterial
var sea: MeshInstance3D
var lakes: MeshInstance3D

# Cell indices that get a lake quad: every pond cell plus a one-cell dilation.
static func lake_cells(data) -> PackedInt32Array:
	var n: int = data.n
	var pond := PackedByteArray()
	pond.resize(n * n)
	for k in n * n:
		if data.is_pond(k) and not data.is_river(k):
			pond[k] = 1
	var out := PackedInt32Array()
	for j in n:
		for i in n:
			var found := false
			for dj in range(-1, 2):
				for di in range(-1, 2):
					var ii := i + di
					var jj := j + dj
					if ii >= 0 and jj >= 0 and ii < n and jj < n and pond[jj * n + ii] == 1:
						found = true
			if found:
				out.append(j * n + i)
	return out

# Surface level of a lake quad: the highest routing level among the pond cells around it.
static func lake_level(data, k: int) -> float:
	var n: int = data.n
	var i := k % n
	var j := k / n
	var level := -1e30
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ii := i + di
			var jj := j + dj
			if ii >= 0 and jj >= 0 and ii < n and jj < n and data.is_pond(jj * n + ii) and not data.is_river(jj * n + ii):
				level = maxf(level, data.water_level[jj * n + ii])
	return level

func build(data) -> void:
	material = ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("height_tex", data.height_tex)
	material.set_shader_parameter("level_tex", data.level_tex)
	material.set_shader_parameter("surface_tex", data.surface_tex)
	material.set_shader_parameter("MAP_N", data.n)
	material.set_shader_parameter("MAP_CELL", data.cell)
	material.set_shader_parameter("MAP_HALF", data.half)
	var plane := PlaneMesh.new()
	plane.size = Vector2(40000.0, 40000.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	sea = MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = plane
	sea.material_override = material
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.custom_aabb = AABB(Vector3(-20000, -100, -20000), Vector3(40000, 200, 40000))
	add_child(sea)
	var cells := lake_cells(data)
	if cells.is_empty():
		return
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var half: float = data.cell * 0.5
	for k in cells:
		var level := lake_level(data, k)
		var cx: float = data.cell_center(k % data.n)
		var cz: float = data.cell_center(k / data.n)
		var base := verts.size()
		verts.append(Vector3(cx - half, level, cz - half))
		verts.append(Vector3(cx + half, level, cz - half))
		verts.append(Vector3(cx + half, level, cz + half))
		verts.append(Vector3(cx - half, level, cz + half))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	lakes = MeshInstance3D.new()
	lakes.name = "Lakes"
	lakes.mesh = mesh
	lakes.material_override = material
	lakes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lakes.custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 2000, 4000))
	add_child(lakes)
