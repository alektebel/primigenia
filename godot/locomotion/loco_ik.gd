extends RefCounted
## Analytic two-bone leg IK shared by the tests and by test rigs. The real
## creature rig has its own solver; this one defines what "where the foot
## really ends up" means for the foot-slide measurement.

## Returns {knee, foot, stretch}: foot is the ankle actually reached (the
## target, unless it is out of reach), stretch is the overshoot in metres.
static func two_bone(hip: Vector3, target: Vector3, a: float, b: float, pole: Vector3) -> Dictionary:
	var d := target - hip
	var dist := d.length()
	var lo: float = abs(a - b) + 1e-4
	var hi := a + b - 1e-4
	var reach: float = clamp(dist, lo, hi)
	var dir := d / dist if dist > 1e-6 else Vector3.DOWN
	var foot := hip + dir * reach
	var x := (a * a - b * b + reach * reach) / (2.0 * reach)
	var hgt := sqrt(max(a * a - x * x, 0.0))
	var side := pole - dir * pole.dot(dir)
	if side.length() < 1e-5:
		side = Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	side = side.normalized()
	return {"knee": hip + dir * x + side * hgt, "foot": foot, "stretch": abs(dist - reach)}
