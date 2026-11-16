extends RefCounted
# Ground picking by ray marching (port of web/stage/pointer.js groundHit) and creature picking.

# origin/dir in world space; ground: Callable(x, z) -> float. Returns Vector3 or null.
static func march(origin: Vector3, dir: Vector3, ground: Callable) -> Variant:
	var prev_t := 0.0
	for step in range(1, 901):
		var t := float(step)
		var p := origin + dir * t
		if p.y <= ground.call(p.x, p.z):
			var lo := prev_t
			var hi := t
			for k in 14:
				var mid := (lo + hi) * 0.5
				var q := origin + dir * mid
				if q.y <= ground.call(q.x, q.z):
					hi = mid
				else:
					lo = mid
			var h := origin + dir * hi
			return Vector3(h.x, ground.call(h.x, h.z), h.z)
		prev_t = t
	return null

static func ground_hit(camera: Camera3D, screen_pos: Vector2, ground: Callable) -> Variant:
	return march(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos), ground)

# Nearest living entity whose body sphere the ray crosses before it reaches the ground.
# entities: Array of {id, x, z, dead, radius_cm}; returns {id, pos} or {} (id -1).
static func pick_entity(origin: Vector3, dir: Vector3, entities: Array, ground: Callable) -> Dictionary:
	var ground_hit_pos = march(origin, dir, ground)
	var ground_t := 1e9
	if ground_hit_pos != null:
		ground_t = origin.distance_to(ground_hit_pos)
	var best := {}
	var best_t := 1e9
	for e in entities:
		if e.id == 0 or e.dead:
			continue
		var r: float = maxf(0.6, e.get("radius_cm", 60) / 100.0)
		var centre := Vector3(e.x, ground.call(e.x, e.z) + r * 0.8, e.z)
		var oc := centre - origin
		var tca := oc.dot(dir)
		if tca < 0.0:
			continue
		var d2 := oc.dot(oc) - tca * tca
		if d2 > r * r:
			continue
		var t := tca - sqrt(maxf(r * r - d2, 0.0))
		if t < best_t and t < ground_t + r:
			best_t = t
			best = {"id": e.id, "pos": Vector3(e.x, ground.call(e.x, e.z), e.z)}
	return best
