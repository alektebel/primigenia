extends RefCounted
## The flamethrower's look (first-quest, docs/godot/FIRST-QUEST.md). Pure presentation: C decides the cone, the hit and the burn
## (core/src/combat.c, CB_FLAME); this draws a short cone of fire from the creature's mouth, a heat shimmer over it, a warm flickering
## light, and the small flames a burning creature carries. Software GL friendly: CPU particles, one additive billboard material,
## one screen-reading shimmer shader. Nothing here touches the grass (it does not burn yet: digging and fire on the land are C5).

const REACH := 3.5           # metres, CB_FLAME reach in core/src/combat.c
const SHIMMER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.012;
uniform float fade = 1.0;
varying float v_t;
void vertex() { v_t = clamp(0.5 - VERTEX.y / %f, 0.0, 1.0); }
void fragment() {
	vec2 q = SCREEN_UV * vec2(40.0, 24.0) + vec2(0.0, -TIME * 3.0);
	vec2 off = vec2(sin(q.y * 3.0 + TIME * 7.0), cos(q.x * 2.0 + TIME * 5.0)) * strength * fade * (0.4 + v_t);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.5);
	ALBEDO = texture(screen_tex, SCREEN_UV + off).rgb * vec3(1.06, 1.0, 0.94);
	ALPHA = clamp(edge * fade * 0.9, 0.0, 1.0);
}
""" % REACH

static var _tex: Texture2D
static var _shimmer: Shader

static func _glow_texture() -> Texture2D:
	if _tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_tex = t
	return _tex

static func _fire_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _glow_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	return m

static func _ramp(hot: bool) -> Gradient:
	var g := Gradient.new()
	if hot:
		g.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 0.9), Color(1.0, 0.62, 0.15, 0.8), Color(0.75, 0.2, 0.05, 0.45), Color(0.15, 0.05, 0.03, 0.0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.8, 0.35, 0.8), Color(0.9, 0.35, 0.08, 0.5), Color(0.2, 0.06, 0.03, 0.0)])
	return g

static func _quad(size: float) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _fire_material()
	return q

## A burst of fire from `from` along the horizontal `dir`, for `duration` s (the move's active frames), freed by itself.
static func flame_cone(parent: Node, from: Vector3, dir: Vector3, duration: float = 0.6) -> Node3D:
	var root := Node3D.new()
	root.name = "FlameCone"
	parent.add_child(root)
	root.global_position = from
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 1e-4:
		d = Vector3(0, 0, 1)
	root.look_at(from + d.normalized(), Vector3.UP)      # -Z points along the flame after look_at: we aim +Z below
	root.rotate_object_local(Vector3.UP, PI)
	var p := CPUParticles3D.new()
	p.amount = 110
	p.lifetime = 0.55
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.07
	p.direction = Vector3(0, 0.08, 1)
	p.spread = 16.0
	p.initial_velocity_min = REACH * 1.5
	p.initial_velocity_max = REACH * 2.0
	p.gravity = Vector3(0, 0.9, 0)
	p.damping_min = 1.5
	p.damping_max = 2.5
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25))
	curve.add_point(Vector2(0.45, 1.0))
	curve.add_point(Vector2(1.0, 0.55))
	p.scale_amount_curve = curve
	p.color_ramp = _ramp(true)
	p.mesh = _quad(0.7)
	p.emitting = true
	root.add_child(p)
	var core := CPUParticles3D.new()      # the white-hot core, thinner and faster
	core.amount = 40
	core.lifetime = 0.3
	core.direction = Vector3(0, 0, 1)
	core.spread = 5.0
	core.initial_velocity_min = REACH * 2.0
	core.initial_velocity_max = REACH * 2.6
	core.scale_amount_min = 0.3
	core.scale_amount_max = 0.55
	core.color_ramp = _ramp(false)
	core.mesh = _quad(0.5)
	core.emitting = true
	root.add_child(core)
	var cone := MeshInstance3D.new()
	cone.name = "HeatShimmer"
	var cm := CylinderMesh.new()
	cm.top_radius = 0.12
	cm.bottom_radius = 1.2
	cm.height = REACH
	cm.radial_segments = 14
	cm.rings = 1
	cone.mesh = cm
	cone.position = Vector3(0, 0, REACH * 0.5)
	cone.rotation = Vector3(-PI * 0.5, 0, 0)    # the cylinder's axis becomes +Z; its narrow end (top) at the mouth
	if _shimmer == null:
		_shimmer = Shader.new()
		_shimmer.code = SHIMMER
	var sm := ShaderMaterial.new()
	sm.shader = _shimmer
	cone.material_override = sm
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cone)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.omni_range = 7.0
	light.light_energy = 2.4
	light.position = Vector3(0, 0.1, REACH * 0.45)
	light.shadow_enabled = false
	root.add_child(light)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(v: float) -> void:
		if is_instance_valid(sm):
			sm.set_shader_parameter("fade", v), 1.0, 0.0, duration + 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_property(light, "light_energy", 0.0, duration + 0.4).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		p.emitting = false
		core.emitting = false)
	tw.tween_interval(0.7)
	tw.tween_callback(root.queue_free)
	# a flicker, so the light is not a lamp
	var fl := root.create_tween().set_loops(int((duration + 0.4) / 0.06) + 1)
	fl.tween_callback(func() -> void:
		if is_instance_valid(light) and light.light_energy > 0.2:
			light.light_energy *= randf_range(0.82, 1.18))
	fl.tween_interval(0.06)
	return root

## Small flames on a burning creature (`host` is its ActorHost). Idempotent.
static func burn_on(host: Node3D, height: float) -> void:
	if host.has_node("BurnFx"):
		return
	var fx := Node3D.new()
	fx.name = "BurnFx"
	host.add_child(fx)
	fx.position = Vector3(0, height * 0.5, 0)
	var p := CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.7
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = maxf(height * 0.28, 0.25)
	p.direction = Vector3(0, 1, 0)
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 1.2, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	p.color_ramp = _ramp(true)
	p.mesh = _quad(0.5)
	p.emitting = true
	fx.add_child(p)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.18)
	light.omni_range = 4.0
	light.light_energy = 0.9
	light.position = Vector3(0, 0.2, 0)
	fx.add_child(light)

static func burn_off(host: Node3D) -> void:
	var fx := host.get_node_or_null("BurnFx")
	if fx != null:
		fx.name = "BurnFxEnding"
		for c in fx.get_children():
			if c is CPUParticles3D:
				c.emitting = false
		fx.get_tree().create_timer(0.9).timeout.connect(fx.queue_free)
