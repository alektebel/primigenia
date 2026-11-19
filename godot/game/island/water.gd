extends Node3D
# Sea (one big plane at y = 0) and lakes (CPU mesh over pond cells at their routing water level).

const WATER_SHADER := preload("res://game/shaders/water.gdshader")

var material: ShaderMaterial
var sea: MeshInstance3D
var lakes: MeshInstance3D

# Cell indices that get a lake quad: every pond cell plus a one-cell dilation, except river cells.
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
			# River cells are the ribbons' water (rivers.gd, at the channel's own level): a lake quad there would lie over
			# the channel as a flat slab with straight cell edges at the pond's level (a lighter chunk at a bend).
			if found and not data.is_river(j * n + i):
				out.append(j * n + i)
	return out

# Does the grid corner at the top-left of cell (i, j) touch a pond cell (the four cells around it)?
static func _touches_pond(data, i: int, j: int) -> bool:
	for dj in range(-1, 1):
		for di in range(-1, 1):
			var ii := i + di
			var jj := j + dj
			if ii >= 0 and jj >= 0 and ii < data.n and jj < data.n and data.is_pond(jj * data.n + ii) and not data.is_river(jj * data.n + ii):
				return true
	return false

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
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var half: float = data.cell * 0.5
	for k in cells:
		var level := lake_level(data, k)
		var cx: float = data.cell_center(k % data.n)
		var cz: float = data.cell_center(k / data.n)
		var base := verts.size()
		# COLOR.r = 1 on corners that touch a pond cell, 0 on the outer corners of the dilation ring: the shader fades the
		# water out across the ring instead of ending in the straight edge of the quad (INTEGRATION-QA bug 5).
		var ci: int = k % data.n
		var cj: int = k / data.n
		for corner in [[-1, -1], [0, -1], [0, 0], [-1, 0]]:
			cols.append(Color(1.0 if _touches_pond(data, ci + corner[0] + 1, cj + corner[1] + 1) else 0.0, 0.0, 0.0, 1.0))
		verts.append(Vector3(cx - half, level, cz - half))
		verts.append(Vector3(cx + half, level, cz - half))
		verts.append(Vector3(cx + half, level, cz + half))
		verts.append(Vector3(cx - half, level, cz + half))
		idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
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
