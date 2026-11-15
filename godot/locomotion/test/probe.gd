extends SceneTree
const Sim = preload("sim.gd")
const Bodies = preload("bodies.gd")
func _init() -> void:
	var s2 = Sim.new(Bodies.get_body("hexapod"))
	var v: float = s2.speed_for_froude(4.0)
	for k in range(40):
		s2.run(0.1, func(_t): return v)
		var c = s2.ctl
		print("t=%.1f fr=%.2f duty=%.2f stride=%.3f cad=%.2f crouch=%.3f rooty=%.3f a=%s y=%s drop=%.3f stretch=%.3f b=%s sx=%s sz=%s" % [s2.t, c.fr, c.duty, c.stride, c.cadence, c.crouch, c.pose.root.origin.y, c._a, c._y, c._drop, s2.max_stretch, c._b, c._sx, c._sz])
	quit()
