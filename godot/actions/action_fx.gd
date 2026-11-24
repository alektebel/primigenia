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

## A74/A69: the blob of a context spit, by kind (0 jet, 1 glob, 2 lob, 3 charged lob): a low fast jet, a fat glob on a ballistic arc,
## the lob's high arc. The flight is the C flight time, so the blob lands on the tick the damage does.
const KIND_ARC := [0.06, 0.22, 0.45, 0.5]       # apex height as a share of the distance
const KIND_SIZE := [0.7, 1.5, 1.1, 1.7]
static func shot(parent: Node, from: Vector3, to: Vector3, flight: float, size: float, kind: int) -> Node3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = clampf(0.08 * size * KIND_SIZE[clampi(kind, 0, 3)], 0.04, 0.5)
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
	var arc: float = KIND_ARC[clampi(kind, 0, 3)] * from.distance_to(to)
	var tw := m.create_tween()
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			m.global_position = from.lerp(to, u) + Vector3.UP * (4.0 * arc * u * (1.0 - u)), 0.0, 1.0, maxf(flight, 0.03))
	tw.tween_callback(m.queue_free)
	return m

## Acid on a body: a green fizz of bubbles and a wisp of vapour rising from the hit point (cosmetic, frees itself).
static func acid_sizzle(parent: Node, at: Vector3, size: float, strong := false) -> Node3D:
	var p := CPUParticles3D.new()
	var quad := SphereMesh.new()
	quad.radius = clampf(0.02 * size, 0.01, 0.06)
	quad.height = quad.radius * 2.0
	quad.radial_segments = 6
	quad.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.72, 0.95, 0.25, 0.9)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.85, 0.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material = mat
	p.mesh = quad
	p.emitting = false
	p.one_shot = true
	p.amount = 26 if strong else 14
	p.lifetime = 0.9
	p.explosiveness = 0.5
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 1.1 + 0.8 * size
	p.gravity = Vector3(0, -1.5, 0)
	p.top_level = true
	parent.add_child(p)
	p.global_position = at
	p.emitting = true
	p.restart()
	var tw := p.create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(p.queue_free)
	return p

## The puddle a charged glob leaves: a flat green disc on the ground that shrinks and fades over `life` seconds (cosmetic).
static func acid_puddle(parent: Node, at: Vector3, radius: float, life := 4.0) -> Node3D:
	var m := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 1.0
	c.bottom_radius = 1.0
	c.height = 0.02
	c.radial_segments = 20
	m.mesh = c
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.9, 0.2, 0.6)
	m.material_override = mat
	m.top_level = true
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	m.global_position = at + Vector3.UP * 0.03
	m.scale = Vector3(0.01, 1.0, 0.01)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius, 1.0, radius), 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_method(func(u: float) -> void:
		if is_instance_valid(m):
			mat.albedo_color = Color(0.55, 0.9, 0.2, 0.6 * (1.0 - u))
			m.scale = Vector3(radius * (1.0 - 0.3 * u), 1.0, radius * (1.0 - 0.3 * u)), 0.0, 1.0, life)
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
