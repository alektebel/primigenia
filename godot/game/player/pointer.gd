extends RefCounted
# Ground picking by ray marching (port of web/stage/pointer.js groundHit) and creature picking.

# origin/dir in world space; ground: Callable(x, z) -> float. Returns Vector3 or null.
# max_range > 900 (the strategic map) grows the step with the distance (1 % of it), so a 3 km ray stays cheap.
static func march(origin: Vector3, dir: Vector3, ground: Callable, max_range: float = 900.0) -> Variant:
	var prev_t := 0.0
	var t := 0.0
	while t < max_range:
		t += 1.0 if max_range <= 900.0 else maxf(1.0, t * 0.01)
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

static func ground_hit(camera: Camera3D, screen_pos: Vector2, ground: Callable, max_range: float = 900.0) -> Variant:
	return march(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos), ground, max_range)

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
		if e.id == 0 or bool(e.get("hidden", false)) or (e.dead and int(e.get("meat", 0)) <= 0):
			continue      # the dead are only pickable while their carcass has meat (Eat, Observe)
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

# Verb-first lock-on (docs/briefs/verb-target.md): the creature whose body is nearest the mouse in SCREEN space, with a generous
# radius so a moving creature is easy to lock. cands: Array of {id, feet: Vector3, height: float}; project: Callable(Vector3) ->
# Vector2 or null (behind the camera); returns the id or -1. The allowed distance is the body's own on-screen half height times
# PICK_BODY plus PICK_PAD pixels, never under `min_px`, so it scales with the distance (a far creature is small but still
# catchable) and the nearest by that measure wins. Starting values: owner test V-LOCK checks them.
const PICK_BODY := 1.5
const PICK_PAD := 28.0
static func pick_screen(mouse: Vector2, cands: Array, project: Callable, min_px: float = 44.0) -> int:
	var best := -1
	var best_score := 1.0
	for c in cands:
		var feet: Vector3 = c.feet
		var h: float = maxf(float(c.get("height", 1.0)), 0.3)
		var mid = project.call(feet + Vector3(0, h * 0.5, 0))
		if mid == null:
			continue
		var top = project.call(feet + Vector3(0, h, 0))
		var body_px: float = absf((mid as Vector2).y - (top as Vector2).y) if top != null else 0.0
		var allowed: float = maxf(min_px, body_px * PICK_BODY + PICK_PAD)
		var d: float = (mid as Vector2).distance_to(mouse)
		var score := d / allowed
		if score <= best_score:
			best_score = score
			best = int(c.id)
	return best
