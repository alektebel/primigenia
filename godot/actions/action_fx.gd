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
