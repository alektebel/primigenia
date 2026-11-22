extends MultiMeshInstance3D

const FrameProfile := preload("res://devtools/frame_profile.gd")
# World-anchored grass: one MultiMesh of identity-transform blades; the vertex shader places each
# blade from its stored offset (INSTANCE_CUSTOM) wrapped around `center`. Visual only.

const WorldLight := preload("res://game/island/world_light.gd")
const GRASS_SHADER := preload("res://game/shaders/grass.gdshader")
const SEED := 8808
const NEAR_R := 44.0
const FAR_R := 140.0

var material: ShaderMaterial
var tier := 2                    # terrain tier (WorldLight): 1 = unshaded, 2/3 = receives the sun shadow map
var near_count := 0
var far_count := 0

# The toroidal wrap of the shader, for tests: nearest copy of offset `o` to `center`.
static func wrap_base(o: Vector2, center: Vector2, radius: float) -> Vector2:
	return o + (((center - o) / (2.0 * radius) + Vector2(0.5, 0.5)).floor()) * 2.0 * radius

static func blade_mesh() -> ArrayMesh:
	var verts := PackedVector3Array([Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(-0.23, 0.55, 0), Vector3(0.23, 0.55, 0), Vector3(0, 1, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 2, 1, 3, 2, 3, 4])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# Reproducible blade table: 20 floats per instance = identity transform (12), colour (4), custom (4).
static func make_buffer(near: int, far: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var buf := PackedFloat32Array()
	buf.resize((near + far) * 20)
	var cx := 0.0
	var cz := 0.0
	var ch := 0.0
	for i in near + far:
		var lod := i >= near
		var clump := 4 if lod else 8
		var local := i - near if lod else i
		if local % clump == 0:
			var a := rng.randf() * TAU
			var u := rng.randf()
			var r := sqrt(34.0 * 34.0 + u * (140.0 * 140.0 - 34.0 * 34.0)) if lod else 44.0 * pow(u, 0.72)
			cx = cos(a) * r
			cz = sin(a) * r
			ch = rng.randf()
		var a2 := rng.randf() * TAU
		var r2 := sqrt(rng.randf()) * (0.52 if lod else 0.25)
		var k := i * 20
		buf[k] = 1.0
		buf[k + 5] = 1.0
		buf[k + 10] = 1.0
		buf[k + 12] = ch
		buf[k + 13] = 0.0
		buf[k + 14] = 0.0
		buf[k + 15] = 1.0
		buf[k + 16] = cx + cos(a2) * r2
		buf[k + 17] = cz + sin(a2) * r2
		buf[k + 18] = rng.randf()
		buf[k + 19] = 1.0 if lod else 0.0
	return buf

func build(data, total: int) -> void:
	far_count = int(round(total * 52000.0 / 252000.0))
	near_count = total - far_count
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = blade_mesh()
	mm.instance_count = near_count + far_count
	mm.buffer = make_buffer(near_count, far_count)
	multimesh = mm
	material = ShaderMaterial.new()
	material.shader = WorldLight.shader_for(GRASS_SHADER, tier)
	material.set_shader_parameter("height_tex", data.height_tex)
	material.set_shader_parameter("level_tex", data.level_tex)
	material.set_shader_parameter("surface_tex", data.surface_tex)
	material.set_shader_parameter("relief_tex", data.relief_tex)
	data.bind_visual(material)
	material.set_shader_parameter("MAP_N", data.n)
	material.set_shader_parameter("MAP_CELL", data.cell)
	material.set_shader_parameter("MAP_HALF", data.half)
	var empty := []
	for i in 12:
		empty.append(Vector4(0, -999, 0, 0))
	material.set_shader_parameter("occ", empty)
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-2000, -100, -2000), Vector3(4000, 900, 4000))

# Baked sun shadows (PLAN-rock step 9, off by default): grass in shadowed slopes goes dark like the terrain under it.
func set_sun_shadows(on: bool) -> void:
	material.set_shader_parameter("rock_shadows", 1.0 if on else 0.0)

func set_center(p: Vector3) -> void:
	material.set_shader_parameter("center", p)

func apply_occluders(center: Vector3, occ: Array) -> void:
	if not FrameProfile.enabled:
		_profile_apply_occluders(center, occ)
		return
	FrameProfile.begin()
	_profile_apply_occluders(center, occ)
	FrameProfile.end(&"grass uniforms")

func _profile_apply_occluders(center: Vector3, occ: Array) -> void:
	material.set_shader_parameter("occ", occ)
	material.set_shader_parameter("occ_center", center)
