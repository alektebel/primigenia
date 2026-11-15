extends RefCounted
## Support polygon helpers (ground plane = XZ).

static func hull(pts: Array) -> Array:
	var p: Array = pts.duplicate()
	p.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	if p.size() < 3:
		return p
	var lower: Array = []
	for q in p:
		while lower.size() >= 2 and _cross(lower[-2], lower[-1], q) <= 0.0:
			lower.pop_back()
		lower.append(q)
	var upper: Array = []
	for i in range(p.size() - 1, -1, -1):
		var q: Vector2 = p[i]
		while upper.size() >= 2 and _cross(upper[-2], upper[-1], q) <= 0.0:
			upper.pop_back()
		upper.append(q)
	lower.pop_back()
	upper.pop_back()
	return lower + upper

static func _cross(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a - o).cross(b - o)

## Signed distance from the point to the hull boundary: positive inside.
static func margin(poly: Array, pt: Vector2) -> float:
	var n := poly.size()
	if n == 0:
		return -INF
	if n == 1:
		return -pt.distance_to(poly[0])
	if n == 2:
		return -_seg_dist(pt, poly[0], poly[1])
	var inside := true
	var best := INF
	for i in range(n):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % n]
		if _cross(a, b, pt) < 0.0:
			inside = false
		best = min(best, _seg_dist(pt, a, b))
	return best if inside else -best

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t: float = clamp((p - a).dot(ab) / max(ab.length_squared(), 1e-12), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Support polygon of a pose: the hull of the feet in contact. Each foot
## contributes its contact patch (a disc of foot_radius, sampled 8 times).
static func polygon(pose: Dictionary, morph, patch := true) -> Array:
	var pts: Array = []
	for i in range(pose.feet.size()):
		if not pose.contact[i]:
			continue
		var f: Vector3 = pose.feet[i]
		var r: float = morph.legs[i].foot_radius if patch else 0.0
		if r <= 0.0:
			pts.append(Vector2(f.x, f.z))
		else:
			for k in range(8):
				var a := TAU * k / 8.0
				pts.append(Vector2(f.x + cos(a) * r, f.z + sin(a) * r))
	return hull(pts)
