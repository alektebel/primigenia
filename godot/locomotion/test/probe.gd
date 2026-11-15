extends SceneTree
const Sim = preload("sim.gd")
const Bodies = preload("bodies.gd")
func _init() -> void:
	for name in ["biped", "light_quadruped"]:
		var s2 = Sim.new(Bodies.get_body(name))
		var vmax: float = s2.morph.proposal.max_speed
		var last := 0.0
		for k in range(600):
			s2.run(1.0/60.0, func(t): return vmax * clamp(sin(t * 0.8), 0.0, 1.0), func(t): return 0.5 * sin(t * 0.37))
			var c = s2.ctl
			var st := 0.0
			var who := -1
			for i in range(s2.morph.legs.size()):
				var m = s2.morph.legs[i]
				var d: float = (c.pose.root * m.hip).distance_to(c.pose.feet[i]) - (m.upper + m.lower)
				if c.pose.contact[i] and d > st:
					st = d; who = i
			if st > 0.002:
				var l = c._legs[who]
				print("%s t=%.3f v=%.2f fr=%.2f gait=%s leg=%d over=%.4f duty=%.2f frac=%.2f stride=%.2f cad=%.2f crouch=%.3f drop=%.3f y=%.3f force=%s moving=%.2f" % [name, s2.t, c._speed_f, c.fr, c.gait, who, st, c.duty, l.theta - floor(l.theta), c.stride, c.cadence, c.crouch, c._drop, c._y.x, l.force, c._moving])
	quit()
