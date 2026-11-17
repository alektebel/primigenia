extends RefCounted
## Spring bank (docs/godot/PLAN-actions.md 1.6): damped springs per channel with the implicit integrator of
## loco_controller._spring. A channel keyed by an action (kin * weight >= 0.99) is slaved to the goal, so the
## action's timing is exact; when the action lets go the spring starts from the keyed pose WITH its velocity
## (overshoot and settle for free). Channels no action keys are fully spring driven.

var _s := {}     # name -> Vector2(x, v)

func clear() -> void:
	_s.clear()

func get_x(name: String) -> float:
	return (_s[name] as Vector2).x if _s.has(name) else 0.0

func get_v(name: String) -> float:
	return (_s[name] as Vector2).y if _s.has(name) else 0.0

func kick(name: String, dv: float) -> void:
	var s: Vector2 = _s.get(name, Vector2.ZERO)
	s.y += dv
	_s[name] = s

## goal: the action sum for this channel; kin_w: max(weight * kin) of the tracks keying it; extra: follow-through
## offset added to the spring target only. Returns the output value.
func step(name: String, goal: float, kin_w: float, omega: float, zeta: float, extra: float, dt: float) -> float:
	var s: Vector2 = _s.get(name, Vector2(goal, 0.0))
	if kin_w >= 0.99:
		s = Vector2(goal, (goal - s.x) / maxf(dt, 1e-4))
		_s[name] = s
		return goal
	# implicit damped spring toward goal + extra (sub-steps keep it stable at low frame rates)
	var target := goal + extra
	var n := maxi(1, int(ceil(dt * omega / 0.5)))
	var h := dt / float(n)
	for _i in n:
		var oo := omega * omega
		var den := 1.0 + 2.0 * h * zeta * omega + h * h * oo
		var nv := (s.y + h * oo * (target - s.x)) / den
		var nx := s.x + h * nv
		s = Vector2(nx, nv)
	_s[name] = s
	return lerpf(s.x, goal, clampf(kin_w, 0.0, 1.0))
