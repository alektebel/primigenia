extends RefCounted
## Cosmetic nodes of the actions (docs/godot/PLAN-actions.md 1.7 events): the spit blob. Nothing here is game state.

## Flies a small glowing blob from `from` to `to` in `flight` seconds (linear with a 0.15 * distance arc) and frees it.
static func spit_blob(parent: Node, from: Vector3, to: Vector3, flight: float, size: float) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = clampf(0.08 * size, 0.04, 0.4)
	s.height = s.radius * 2.0
	s.radial_segments = 12
	s.rings = 6
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.95, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.9, 0.15)
	mat.emission_energy_multiplier = 1.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	m.top_level = true
	parent.add_child(m)
	m.global_position = from
	var arc := 0.15 * from.distance_to(to)
	var tw := m.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			m.global_position = from.lerp(to, u) + Vector3.UP * (4.0 * arc * u * (1.0 - u)), 0.0, 1.0, maxf(flight, 0.03))
	tw.tween_callback(m.queue_free)
	return m

## A roar's visible pulse: an expanding, fading ring on the ground around `center` (and a second, smaller one a beat later).
## `radius` is the final radius in metres (a few body heights); cosmetic only. Frees itself unless `manual` (tests and
## evidence step it with ring_pose).
static func roar_ring(parent: Node, center: Vector3, radius: float, tint := Color(1.0, 0.86, 0.6), manual := false) -> Array:
	var rings := []
	for k in 2:
		var m := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.9
		t.outer_radius = 1.0
		t.rings = 32
		t.ring_segments = 4
		m.mesh = t
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(tint, 0.0)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.material_override = mat
		m.top_level = true
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.set_meta("ring_radius", radius * (1.0 - 0.3 * k))
		m.set_meta("ring_tint", tint)
		parent.add_child(m)
		m.global_position = center + Vector3.UP * 0.05
		ring_pose(m, 0.0, k)
		rings.append(m)
		if not manual:
			var tw := m.create_tween()
			tw.tween_interval(0.12 * k)
			tw.tween_method(func(u: float) -> void:
				if is_instance_valid(m):
					ring_pose(m, u, k), 0.0, 1.0, RING_LIFE)
			tw.tween_callback(m.queue_free)
	return rings

const RING_LIFE := 0.55

## u in 0..1 along the ring's life: expands with an ease-out and fades.
static func ring_pose(m: MeshInstance3D, u: float, _k := 0) -> void:
	var r: float = m.get_meta("ring_radius", 1.0)
	var tint: Color = m.get_meta("ring_tint", Color.WHITE)
	var e := 1.0 - (1.0 - u) * (1.0 - u)
	var s := maxf(0.01, r * e)
	m.scale = Vector3(s, maxf(0.02, s * 0.3), s)
	(m.material_override as StandardMaterial3D).albedo_color = Color(tint, 0.7 * (1.0 - u) * smoothstep(0.0, 0.08, u))

## Crumbs and torn chunks of a bite: one-shot CPU particles (cosmetic, frees itself). `size` ~ the food's size in metres.
static func crumbs(parent: Node, at: Vector3, tint: Color, size: float, last := false) -> Node3D:
	var p := CPUParticles3D.new()
	var quad := BoxMesh.new()
	quad.size = Vector3.ONE * clampf(0.035 * size + 0.012, 0.015, 0.09)
	p.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	quad.material = mat
	p.emitting = false
	p.one_shot = true
	p.amount = 18 if last else 10
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6 + 0.8 * size
	p.initial_velocity_max = 1.6 + 1.6 * size
	p.gravity = Vector3(0, -9.8, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.top_level = true
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.restart()
	var tw := p.create_tween()
	tw.tween_interval(1.2)
	tw.tween_callback(p.queue_free)
	return p
