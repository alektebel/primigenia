extends Node3D
# GPU-displaced geomipmapped terrain: 5 shared flat grid meshes (LOD 0..4, step 1/2/4/8/16 cells)
# instanced in a cps x cps grid of 64-cell chunks. The vertex shader reads the height texture.

const TerrainData := preload("res://game/island/terrain_data.gd")
# Rock quality tiers (docs/godot/PLAN-rock.md section 6): compile-time variants, only the one in use is compiled.
const TIER_SHADERS := [
	preload("res://game/shaders/terrain_low.gdshader"),
	preload("res://game/shaders/terrain_medium.gdshader"),
	preload("res://game/shaders/terrain_high.gdshader"),
]
const PHOTO_ALBEDO := preload("res://game/textures/photo/rock_albedo.jpg")   # Texture2DArray, 8 CC0 materials (textures/CREDITS.md)
const PHOTO_PACK := preload("res://game/textures/photo/rock_pack.jpg")

# Chunks are 64 sim cells (224 m) wide = CHUNK visual cells. LOD steps are in visual cells (0.88 m): 0.9, 1.8, 3.5, 7, 14, 28, 56 m.
const CHUNK := TerrainData.CHUNK_CELLS * TerrainData.VISUAL_FACTOR
const STEPS := [1, 2, 4, 8, 16, 32, 64]
const THRESHOLDS := [130.0, 280.0, 600.0, 1200.0, 2400.0, 3800.0]   # metres; LOD i is used below THRESHOLDS[i]
const HYSTERESIS := 0.10
const UPDATE_PERIOD := 0.25
const UPDATE_MOVE := 20.0

var data
var lod_meshes: Array = []        # ArrayMesh per LOD (surface 0: grid, surface 1: skirts)
var materials: Array = []         # [lod] -> [grid material, skirt material]
var chunks: Array = []            # {node, lod, center: Vector3(aabb centre), aabb: AABB}
var lod_debug := false
var tier := 2                    # 1 low, 2 medium, 3 high (rock detail), resolved from Game.settings.quality
var _last_update_pos := Vector3(1e9, 1e9, 1e9)
var _timer := 0.0
var _skirt_shader: Shader

# Tier (1 low, 2 medium, 3 high) for a quality setting ("low", "medium", "high" or "auto") and a video adapter name. "auto" picks
# medium on integrated and software GPUs (Radeon 7xxM/8xxM and "Radeon Graphics", Intel, llvmpipe, SwiftShader) and high otherwise.
static func resolve_tier(quality: String, adapter: String) -> int:
	match quality:
		"low":
			return 1
		"medium":
			return 2
		"high":
			return 3
	var a := adapter.to_lower()
	var re := RegEx.new()
	re.compile("radeon(\\(tm\\))? ?(graphics|[78]\\d\\dm)")
	if re.search(a) != null or a.contains("intel") or a.contains("llvmpipe") or a.contains("swiftshader") or a.contains("software"):
		return 2
	return 3

func _quality() -> String:
	var game = get_tree().root.get_node_or_null("Game") if is_inside_tree() else null
	return String(game.settings.get("quality", "auto")) if game != null else "auto"

# Pure function for tests: LOD for a distance given the current LOD (hysteresis of 10 %).
static func lod_for(distance: float, current: int) -> int:
	var lod := current
	while lod < THRESHOLDS.size() and distance > THRESHOLDS[lod] * (1.0 + HYSTERESIS):
		lod += 1
	while lod > 0 and distance < THRESHOLDS[lod - 1] * (1.0 - HYSTERESIS):
		lod -= 1
	return lod

# One flat grid LOD: returns {mesh, grid_vertices, skirt_vertices}. Local x/z in metres.
static func build_lod_mesh(step: int, cell: float) -> ArrayMesh:
	var per_side := CHUNK / step + 1
	var verts := PackedVector3Array()
	var uv2 := PackedVector2Array()
	var idx := PackedInt32Array()
	var norms := PackedVector3Array()
	for b in per_side:
		for a in per_side:
			verts.append(Vector3(a * step * cell, 0.0, b * step * cell))
			uv2.append(Vector2.ZERO)
			norms.append(Vector3.UP)
	for b in per_side - 1:
		for a in per_side - 1:
			var p00 := b * per_side + a
			var p10 := p00 + 1
			var p01 := p00 + per_side
			var p11 := p01 + 1
			idx.append_array([p00, p10, p11, p00, p11, p01])
	var mesh := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Skirts: a ring of vertical quads under the 4 edges; the bottom copy has UV2 = (1, depth).
	var sv := PackedVector3Array()
	var su := PackedVector2Array()
	var sn := PackedVector3Array()
	var si := PackedInt32Array()
	var depth := maxf(2.0, 1.15 * float(step) * cell)
	var ring := []
	for a in per_side:
		ring.append(Vector2i(a, 0))
	for b in range(1, per_side):
		ring.append(Vector2i(per_side - 1, b))
	for a in range(per_side - 2, -1, -1):
		ring.append(Vector2i(a, per_side - 1))
	for b in range(per_side - 2, 0, -1):
		ring.append(Vector2i(0, b))
	for r in ring.size():
		var q: Vector2i = ring[r]
		var base := Vector3(q.x * step * cell, 0.0, q.y * step * cell)
		sv.append(base)
		su.append(Vector2.ZERO)
		sv.append(base)
		su.append(Vector2(1.0, depth))
		sn.append(Vector3.UP)
		sn.append(Vector3.UP)
	for r in ring.size():
		var n := (r + 1) % ring.size()
		var t0 := r * 2
		var b0 := r * 2 + 1
		var t1 := n * 2
		var b1 := n * 2 + 1
		si.append_array([t0, t1, b1, t0, b1, b0])
	arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = sv
	arrays[Mesh.ARRAY_NORMAL] = sn
	arrays[Mesh.ARRAY_TEX_UV2] = su
	arrays[Mesh.ARRAY_INDEX] = si
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func build(terrain_data) -> void:
	data = terrain_data
	var cps: int = data.chunks_per_side
	tier = resolve_tier(_quality(), RenderingServer.get_video_adapter_name())
	var shader: Shader = TIER_SHADERS[tier - 1]
	if tier >= 2 and is_inside_tree():
		get_viewport().anisotropic_filtering_level = Viewport.ANISOTROPY_4X if tier == 2 else Viewport.ANISOTROPY_8X   # the photographic materials are seen at grazing angles
	_skirt_shader = Shader.new()
	_skirt_shader.code = shader.code.replace("cull_back", "cull_disabled")
	for lod in STEPS.size():
		var mesh := build_lod_mesh(STEPS[lod], data.vcell)
		var grid_mat := ShaderMaterial.new()
		grid_mat.shader = shader
		var skirt_mat := ShaderMaterial.new()
		skirt_mat.shader = _skirt_shader
		for m in [grid_mat, skirt_mat]:
			m.set_shader_parameter("height_tex", data.height_tex)
			m.set_shader_parameter("level_tex", data.level_tex)
			m.set_shader_parameter("surface_tex", data.surface_tex)
			m.set_shader_parameter("relief_tex", data.relief_tex)
			m.set_shader_parameter("ph_alb", PHOTO_ALBEDO)
			m.set_shader_parameter("ph_pk", PHOTO_PACK)
			data.bind_visual(m)
			m.set_shader_parameter("MAP_N", data.n)
			m.set_shader_parameter("MAP_CELL", data.cell)
			m.set_shader_parameter("MAP_HALF", data.half)
			m.set_shader_parameter("lod_color", _lod_color(lod))
			m.set_shader_parameter("lod_step", STEPS[lod])
			m.set_shader_parameter("morph_range", THRESHOLDS[lod] if lod < THRESHOLDS.size() else 0.0)
			m.set_shader_parameter("lod_debug", 0.0)
		var empty := []
		for i in 12:
			empty.append(Vector4(0, -999, 0, 0))
		grid_mat.set_shader_parameter("occ", empty)
		skirt_mat.set_shader_parameter("occ", empty)
		mesh.surface_set_material(0, grid_mat)
		mesh.surface_set_material(1, skirt_mat)
		lod_meshes.append(mesh)
		materials.append([grid_mat, skirt_mat])
	for cj in cps:
		for ci in cps:
			var mi := MeshInstance3D.new()
			mi.name = "Chunk_%d_%d" % [ci, cj]
			mi.mesh = lod_meshes[0]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = Vector3((ci * CHUNK + 0.5) * data.vcell - data.half, 0.0, (cj * CHUNK + 0.5) * data.vcell - data.half)
			var mn: float = data.chunk_bounds[(cj * cps + ci) * 2]
			var mx: float = data.chunk_bounds[(cj * cps + ci) * 2 + 1]
			var aabb := AABB(Vector3(0.0, mn - 64.0, 0.0), Vector3(CHUNK * data.vcell, mx - mn + 80.0, CHUNK * data.vcell))
			mi.custom_aabb = aabb
			add_child(mi)
			chunks.append({"node": mi, "lod": 0, "aabb": AABB(aabb.position + mi.position, aabb.size)})
	update_lods(Vector3.ZERO, true)

static func _lod_color(lod: int) -> Vector3:
	return [Vector3(0.9, 0.2, 0.2), Vector3(0.95, 0.65, 0.15), Vector3(0.9, 0.9, 0.2), Vector3(0.2, 0.75, 0.3), Vector3(0.25, 0.45, 0.95), Vector3(0.6, 0.3, 0.9), Vector3(0.9, 0.9, 0.9)][lod]

# Sets one shader uniform on every terrain material (tests, tuning).
func set_uniform(name: String, value) -> void:
	for lod in materials.size():
		for m in materials[lod]:
			m.set_shader_parameter(name, value)

func set_rock_debug(mode: int) -> void:
	for lod in materials.size():
		for m in materials[lod]:
			m.set_shader_parameter("rock_debug", mode)

func set_lod_debug(on: bool) -> void:
	lod_debug = on
	for lod in materials.size():
		for m in materials[lod]:
			m.set_shader_parameter("lod_debug", 1.0 if on else 0.0)

# Distance from a point to an AABB (0 inside).
static func aabb_distance(box: AABB, p: Vector3) -> float:
	var c := p.clamp(box.position, box.end)
	return p.distance_to(c)

func update_lods(cam_pos: Vector3, force: bool = false) -> void:
	if not force and cam_pos.distance_to(_last_update_pos) < UPDATE_MOVE:
		return
	_last_update_pos = cam_pos
	for c in chunks:
		var lod := lod_for(aabb_distance(c.aabb, cam_pos), c.lod)
		if lod != c.lod:
			c.lod = lod
			c.node.mesh = lod_meshes[lod]

func _process(delta: float) -> void:
	_timer += delta
	if _timer < UPDATE_PERIOD:
		return
	_timer = 0.0
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		update_lods(cam.global_position)

func apply_occluders(center: Vector3, occ: Array) -> void:
	for lod in materials.size():
		for m in materials[lod]:
			m.set_shader_parameter("occ", occ)
			m.set_shader_parameter("occ_center", center)

func triangle_count() -> int:
	var total := 0
	for c in chunks:
		var mesh: ArrayMesh = lod_meshes[c.lod]
		total += (mesh.surface_get_array_index_len(0) + mesh.surface_get_array_index_len(1)) / 3
	return total
