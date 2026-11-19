extends MeshInstance3D
# One ground ring of the diegetic UI: a 17 x 17 vertex patch that lies on the terrain (heights from Game.ground, so the
# visual ground the player sees), drawn by game/shaders/ground_mark.gdshader. The renderer is gl_compatibility, which has
# no Decal node, hence a mesh. The patch covers [-extent, extent]^2 around `pos`; every radius is in metres.
# Line widths are given in screen pixels (design units) and converted with the camera distance, so a ring keeps one
# hairline weight from chase to strategic distance.

const Style := preload("res://ui/style.gd")
const SHADER := preload("res://game/shaders/ground_mark.gdshader")
const N := 17
const RESAMPLE := 0.05

var extent := 1.0              # half-size of the patch (m)
var radius_m := 1.0            # ring radius at scale 1 (m)
var width_px := 2.6            # line width on screen (u)
var thick_px := 0.0            # extra width (the rhythm window), u
var scale_mul := 1.0           # animated multiplier of the radius (contraction / expansion)
var alpha := 0.0               # current opacity
var alpha_target := 0.0
var fade_secs := Style.IN
var breathe := false           # the move marker's slow breathing
var free_when_gone := false
var mat: ShaderMaterial
var base_alpha := 1.0          # opacity when fully shown (before breathing)
var _pos := Vector3.ZERO
var _sampled := Vector3(INF, 0, INF)
var _sampled_extent := -1.0
var _scale_from := 1.0
var _scale_to := 1.0
var _scale_t := 1.0
var _scale_secs := 0.0
var _scale_ease := &"out"
var _shake_t := 1.0
var _clock := 0.0
var _arrays: Array = []
var _uv := PackedVector2Array()

func _init() -> void:
	mat = ShaderMaterial.new()
	mat.shader = SHADER
	mat.render_priority = 2
	material_override = mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 4.0
	mesh = ArrayMesh.new()
	var idx := PackedInt32Array()
	for j in N - 1:
		for i in N - 1:
			var a := j * N + i
			idx.append_array([a, a + 1, a + N, a + 1, a + N + 1, a + N])
	for j in N:
		for i in N:
			_uv.append(Vector2(float(i) / (N - 1), float(j) / (N - 1)))
	_arrays.resize(Mesh.ARRAY_MAX)
	_arrays[Mesh.ARRAY_TEX_UV] = _uv
	_arrays[Mesh.ARRAY_INDEX] = idx
	visible = false

# --- placing -----------------------------------------------------------------------------------------------------

## Put the patch around `pos` (x, z used); re-samples the 289 heights only when it moved or its extent changed.
func place(pos: Vector3, ext: float = -1.0) -> void:
	if ext > 0.0:
		extent = ext
	_pos = pos
	position = Vector3(pos.x, 0.0, pos.z)
	if Vector2(pos.x - _sampled.x, pos.z - _sampled.z).length() > RESAMPLE or not is_equal_approx(extent, _sampled_extent):
		_resample()

## The ground the player sees: the terrain, or the water surface over rivers, ponds and the sea (the river ribbons lie
## 0.12 m above the water level, so a ring on the river bed would be hidden under them). Game.visual_ground does not
## exist on this branch; when it does, this is the place to call it.
static func visual_ground(x: float, z: float) -> float:
	if Game.has_method("visual_ground"):
		return Game.visual_ground(x, z)
	var g: float = Game.ground(x, z)
	var d = Game.data
	if d == null:
		return g
	var k: int = d.cell_index(x, z)
	if d.river_class(k) > 0 or d.is_pond(k):
		return maxf(g, float(d.water_level[k]) + 0.16)
	if d.is_sea(k):
		return maxf(g, 0.12)
	return g

func ground_at(x: float, z: float) -> float:
	return visual_ground(x, z)

func _resample() -> void:
	_sampled = Vector3(_pos.x, 0, _pos.z)
	_sampled_extent = extent
	var v := PackedVector3Array()
	v.resize(N * N)
	for j in N:
		for i in N:
			var lx := (float(i) / (N - 1) * 2.0 - 1.0) * extent
			var lz := (float(j) / (N - 1) * 2.0 - 1.0) * extent
			v[j * N + i] = Vector3(lx, ground_at(_pos.x + lx, _pos.z + lz), lz)
	_arrays[Mesh.ARRAY_VERTEX] = v
	var m: ArrayMesh = mesh
	m.clear_surfaces()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _arrays)

## The sampled height at patch vertex (i, j), for tests.
func vertex_height(i: int, j: int) -> float:
	return (_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[j * N + i].y

func vertex_world(i: int, j: int) -> Vector3:
	var p: Vector3 = (_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)[j * N + i]
	return p + Vector3(_pos.x, 0, _pos.z)

# --- appearance --------------------------------------------------------------------------------------------------

func set_param(name: String, v: Variant) -> void:
	mat.set_shader_parameter(name, v)

func param(name: String) -> Variant:
	return mat.get_shader_parameter(name)

func set_style(style: int, color: Color, count: int = 0) -> void:
	set_param("style", style)
	set_param("color", color)
	if count > 0:
		set_param("count", float(count))

func fade_to(target: float, secs: float = Style.IN) -> void:
	alpha_target = target
	fade_secs = secs
	if target > 0.0:
		visible = true

func fade_in(secs: float = Style.IN) -> void:
	fade_to(base_alpha, secs)

func fade_out(secs: float = Style.OUT, free := false) -> void:
	fade_to(0.0, secs)
	free_when_gone = free

func scale_to(mul: float, secs: float, from: float = -1.0, ease: StringName = &"out") -> void:
	_scale_from = scale_mul if from < 0.0 else from
	_scale_to = mul
	_scale_t = 0.0
	_scale_secs = secs
	_scale_ease = ease
	if secs <= 0.0:
		scale_mul = mul
		_scale_t = 1.0

func shake(metres: float = 0.12) -> void:
	_shake_t = 0.0
	set_meta("shake_m", metres)

func is_shown() -> bool:
	return alpha_target > 0.0

func _process(dt: float) -> void:
	_clock += dt
	alpha = Style.approach(alpha, alpha_target, dt, fade_secs)
	if _scale_t < 1.0:
		_scale_t = minf(_scale_t + dt / maxf(Style.dur(_scale_secs), 0.001), 1.0)
		var k := Style.ease_in(_scale_t) if _scale_ease == &"in" else Style.ease_out(_scale_t)
		scale_mul = lerpf(_scale_from, _scale_to, k)
	var a := alpha
	var thick := thick_px
	if breathe and alpha_target > 0.0:
		if Style.reduced_motion():
			thick += 0.8
		else:
			a *= 1.0 + 0.05 * sin(TAU * _clock / Style.BREATH)
	if _shake_t < 1.0:
		_shake_t = minf(_shake_t + dt / 0.2, 1.0)
		var off := sin(_shake_t * TAU * 2.0) * float(get_meta("shake_m", 0.1)) * (1.0 - _shake_t)
		position = Vector3(_pos.x + off, 0.0, _pos.z)
	if alpha <= 0.002 and alpha_target <= 0.0:
		visible = false
		if free_when_gone:
			queue_free()
		return
	visible = true
	_push(a, thick)

func _px_to_m() -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		return 0.02
	var h := get_viewport().get_visible_rect().size.y
	var d := cam.global_position.distance_to(Vector3(_pos.x, _pos.y, _pos.z))
	return d * 2.0 * tan(deg_to_rad(cam.fov) * 0.5) / maxf(h, 1.0)

func _push(a: float, thick: float) -> void:
	var m_px := _px_to_m()
	var s := Style.u(1.0)
	set_param("radius", radius_m * scale_mul / extent)
	set_param("width", width_px * s * m_px / extent)
	set_param("thick", thick * s * m_px / extent)
	set_param("alpha", a)
	set_param("halo", 0.9 if Style.strong_outlines() else 0.7)
