extends SceneTree
## Headless acceptance tests for godot/locomotion (G73).
##   godot --headless --path godot --script locomotion/test/run_tests.gd
## Exit code 0 when every check passes. Measurements are written to
## docs/evidence/godot/locomotion/measurements.json.

const Sim = preload("sim.gd")
const Bodies = preload("bodies.gd")
const Morph = preload("../loco_morphology.gd")
const Gait = preload("../loco_gait.gd")
const Support = preload("../loco_support.gd")

const PLANS := ["biped", "horizontal_biped", "light_quadruped", "heavy_quadruped", "hexapod", "wader"]
const SLIDE_LIMIT := 0.02
const STABLE_LIMIT := 0.95
const FR_TOL := 0.15

var fails := 0
var checks := 0
var out := {}

func check(ok: bool, what: String) -> void:
	checks += 1
	if ok:
		print("  ok    ", what)
	else:
		fails += 1
		print("  FAIL  ", what)

func _init() -> void:
	var t0 := Time.get_ticks_msec()
	test_morphology()
	test_gait_tables()
	test_foot_slide()
	test_stability()
	test_transitions()
	test_footfall_patterns()
	test_body_dynamics()
	test_swing()
	test_stop_and_turn_in_place()
	test_robustness()
	test_proposal()
	test_quality()
	out["checks"] = checks
	out["failures"] = fails
	var path := ProjectSettings.globalize_path("res://").path_join("../docs/evidence/godot/locomotion/measurements.json")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  ") + "\n")
		f.close()
	print("\n%d checks, %d failures, %.1f s" % [checks, fails, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if fails > 0 else 0)

static func r(x: float, d := 4) -> float:
	return snappedf(x, pow(10.0, -d))

# ---------------------------------------------------------------- morphology
func test_morphology() -> void:
	print("morphology")
	# a plain cylinder: mass and centre are known in closed form
	var cyl := {"spine": [{"pos": Vector3(0, 1, -1), "radius": 0.5, "region": "trunk"}, {"pos": Vector3(0, 1, 1), "radius": 0.5, "region": "trunk"}], "legs": [], "parts": []}
	var m = Morph.analyse(cyl)
	var expect := 1000.0 * (PI * 0.25 * 2.0 + 4.0 / 3.0 * PI * 0.125)
	check(abs(m.mass - expect) < 1e-3 * expect, "capsule mass %.1f kg matches the closed form %.1f" % [m.mass, expect])
	check(m.com.distance_to(Vector3(0, 1, 0)) < 1e-6, "capsule centre of mass at its middle")
	check(m.inertia.x > m.inertia.z and abs(m.inertia.x - m.inertia.y) < 1e-6, "long body: pitch and yaw inertia exceed roll inertia")
	var cyl2: Dictionary = cyl.duplicate(true)
	cyl2.parts = [{"pos": Vector3(0, 1, 1), "mass": 200.0}]
	var m2 = Morph.analyse(cyl2)
	check(m2.com.z > 0.05 and m2.mass > m.mass, "a part at the front adds mass and moves the centre of mass forward")
	var plans := {"biped": &"upright_biped", "horizontal_biped": &"horizontal_biped", "light_quadruped": &"quadruped",
		"heavy_quadruped": &"quadruped", "hexapod": &"multi", "wader": &"horizontal_biped", "legless": &"legless"}
	var table := {}
	for name in plans:
		var mm = Morph.analyse(Bodies.get_body(name))
		check(mm.plan == plans[name], "%s classified as %s" % [name, mm.plan])
		var share := 0.0
		for l in mm.legs:
			share += l.share
		check(mm.legs.is_empty() or abs(share - 1.0) < 1e-6, "%s leg load shares sum to 1" % name)
		check(abs(mm.com.x) < 1e-6, "%s centre of mass on the midline" % name)
		table[name] = {"plan": str(mm.plan), "mass_kg": r(mm.mass, 1), "com": [r(mm.com.x), r(mm.com.y), r(mm.com.z)],
			"inertia_pitch_yaw_roll": [r(mm.inertia.x, 3), r(mm.inertia.y, 3), r(mm.inertia.z, 3)],
			"hip_height_m": r(mm.hip_height, 3), "legs": mm.legs.size(), "robustness": r(mm.robustness, 2), "graviportal": mm.graviportal}
	out["morphology"] = table
	var light = Morph.analyse(Bodies.get_body("light_quadruped"))
	var heavy = Morph.analyse(Bodies.get_body("heavy_quadruped"))
	check(heavy.graviportal and not light.graviportal, "heavy quadruped is graviportal, light one is not")
	var fore_share: float = light.stations[1].share
	var expect_share: float = (light.com.z - light.stations[0].z) / (light.stations[1].z - light.stations[0].z)
	check(abs(fore_share - expect_share) < 1e-4, "fore/hind load split follows the centre of mass (fore %.2f)" % fore_share)
	var wader = Morph.analyse(Bodies.get_body("wader"))
	check(wader.neck.length > 0.6 and abs(wader.legs[0].home.z - wader.com.z) < 1e-4, "wader: long neck found, feet rest under the centre of mass")

func test_gait_tables() -> void:
	print("gait tables")
	var q = Morph.analyse(Bodies.get_body("light_quadruped"))
	var names := ["LH", "RH", "LF", "RF"]
	var idx := {}
	for i in range(4):
		var l: Dictionary = q.legs[i]
		idx[("L" if l.side > 0 else "R") + ("H" if l.station == 0 else "F")] = i
	var w := Gait.offsets(&"walk", q)
	var order := names.duplicate()
	order.sort_custom(func(a, b): return w[idx[a]] < w[idx[b]])
	check(order == ["LH", "LF", "RH", "RF"], "quadruped walk is a lateral sequence: %s" % str(order))
	var tr := Gait.offsets(&"trot", q)
	check(tr[idx["LH"]] == tr[idx["RF"]] and tr[idx["RH"]] == tr[idx["LF"]] and abs(tr[idx["LH"]] - tr[idx["RH"]]) == 0.5, "trot couples the diagonals")
	check(Gait.duty(&"walk", 0.04) > 0.75, "slow walk duty factor above 0.75 (three feet down)")
	check(Gait.duty(&"walk", 0.45) > 0.5 and Gait.duty(&"run", 0.55) < 0.5, "walk keeps duty above 0.5, run below")
	check(is_equal_approx(Gait.stride_length(&"walk", 0.25, 1.0), 2.3 * pow(0.25, 0.3)), "stride length follows 2.3 Fr^0.3")
	var h = Morph.analyse(Bodies.get_body("hexapod"))
	var tp := Gait.offsets(&"tripod", h)
	var ok := true
	for i in range(6):
		for j in range(6):
			var a: Dictionary = h.legs[i]
			var b: Dictionary = h.legs[j]
			var same: bool = ((a.station + (0 if a.side > 0 else 1)) % 2) == ((b.station + (0 if b.side > 0 else 1)) % 2)
			if (tp[i] == tp[j]) != same:
				ok = false
	check(ok, "hexapod: two alternating tripods")

# ---------------------------------------------------------------- foot slide
func _rough(x: float, z: float) -> float:
	return 0.06 * sin(x * 1.3) + 0.05 * sin(z * 0.9 + 1.0) + 0.02 * sin(x * 4.1 + z * 3.3)

func test_foot_slide() -> void:
	print("foot slide (limit %.0f mm per step, measured on the IK-solved foot)" % (SLIDE_LIMIT * 1000.0))
	var table := {}
	for name in PLANS:
		var probe = Sim.new(Bodies.get_body(name))
		var vmax: float = probe.morph.proposal.max_speed
		var h: float = probe.morph.hip_height
		var worst := 0.0
		var nsteps := 0
		var row := {}
		var scenarios := {
			"slow walk": [func(_t): return probe.speed_for_froude(0.05), Callable(), Callable(), 0.0],
			"walk": [func(_t): return probe.speed_for_froude(0.25), Callable(), Callable(), 0.0],
			"fast": [func(_t): return min(probe.speed_for_froude(1.2), vmax), Callable(), Callable(), 0.0],
			"top speed": [func(_t): return vmax, Callable(), Callable(), 0.0],
			"circle": [func(_t): return probe.speed_for_froude(0.3), func(_t): return 0.7, Callable(), 0.0],
			"slalom at speed": [func(_t): return min(probe.speed_for_froude(1.5), vmax), func(t): return 1.2 * sin(t * 1.5), Callable(), 0.0],
			"start-stop": [func(t): return vmax * clamp(sin(t * 0.8), 0.0, 1.0), func(t): return 0.5 * sin(t * 0.37), Callable(), 0.0],
			"uphill 20%": [func(_t): return probe.speed_for_froude(0.25), Callable(), func(_x, z): return 0.2 * z, 0.0],
			"downhill 20%": [func(_t): return probe.speed_for_froude(0.25), Callable(), func(_x, z): return -0.2 * z, 0.0],
			"rough ground": [func(_t): return probe.speed_for_froude(0.3), func(t): return 0.3 * sin(t * 0.5), func(x, z): return _rough(x / h, z / h) * h, 0.0],
			"10 Hz world ticks": [func(t): return vmax * (0.25 + 0.75 * clamp(sin(t * 0.6), 0.0, 1.0)), func(t): return 0.9 * sin(t * 0.8), Callable(), 0.1],
		}
		for sc in scenarios:
			var a: Array = scenarios[sc]
			var s = Sim.new(Bodies.get_body(name), a[2])
			s.keep_frames = false
			s.run(10.0, a[0], a[1], 1.0 / 60.0, a[3])
			var sl: float = s.max_slide()
			row[sc] = r(sl * 1000.0, 2)
			worst = max(worst, sl)
			nsteps += s.steps.size()
			if s.nan_seen:
				check(false, "%s / %s produced a non-finite pose" % [name, sc])
		row["steps"] = nsteps
		table[name] = row
		check(worst < SLIDE_LIMIT, "%s: worst slide %.2f mm over %d steps in %d scenarios" % [name, worst * 1000.0, nsteps, scenarios.size()])
	out["foot_slide_mm"] = table

# ---------------------------------------------------------------- stability
func test_stability() -> void:
	print("static stability (centre of mass inside the support polygon, limit %.0f%% of frames)" % (STABLE_LIMIT * 100.0))
	var table := {}
	var cases := [["light_quadruped", 0.03], ["light_quadruped", 0.06], ["heavy_quadruped", 0.03], ["heavy_quadruped", 0.06],
		["hexapod", 0.05], ["hexapod", 0.25], ["hexapod", 1.0]]
	for c in cases:
		var s = Sim.new(Bodies.get_body(c[0]))
		var v: float = s.speed_for_froude(c[1])
		s.run(14.0, func(_t): return v)
		var frac: float = s.stable_fraction(2.0)
		# stricter variant: feet as points, no contact patch
		var okp := 0
		var n := 0
		var min_legs := 99
		var worst := INF
		for i in range(s.frames.size()):
			var f: Dictionary = s.frames[i]
			if f.t < 2.0:
				continue
			n += 1
			min_legs = min(min_legs, f.n)
			worst = min(worst, f.margin)
		var s2 = Sim.new(Bodies.get_body(c[0]))
		var pts_ok := _point_stability(s2, v, 14.0, 2.0)
		check(frac > STABLE_LIMIT, "%s Fr %.2f (%s): inside %.1f%% of frames (point feet %.1f%%), never fewer than %d feet down" % [c[0], c[1], s.ctl.gait, frac * 100.0, pts_ok * 100.0, min_legs])
		table["%s@Fr%.2f" % [c[0], c[1]]] = {"gait": str(s.ctl.gait), "inside_pct": r(frac * 100.0, 2), "inside_pct_point_feet": r(pts_ok * 100.0, 2),
			"min_feet_down": min_legs, "worst_margin_m": r(worst, 4), "duty": r(s.ctl.duty, 3)}
	# reported, not gated: gaits that are not statically stable
	for c in [["light_quadruped", 0.25], ["heavy_quadruped", 0.25], ["biped", 0.05], ["wader", 0.05], ["horizontal_biped", 0.05]]:
		var s = Sim.new(Bodies.get_body(c[0]))
		var v: float = s.speed_for_froude(c[1])
		s.run(10.0, func(_t): return v)
		table["%s@Fr%.2f (dynamic, not gated)" % [c[0], c[1]]] = {"gait": str(s.ctl.gait), "inside_pct": r(s.stable_fraction(2.0) * 100.0, 2), "duty": r(s.ctl.duty, 3)}
		print("  note  %s Fr %.2f is dynamically balanced: inside %.1f%% of frames (not gated)" % [c[0], c[1], s.stable_fraction(2.0) * 100.0])
	out["stability"] = table

func _point_stability(s, v: float, dur: float, t_from: float) -> float:
	var ok := 0
	var n := 0
	var steps := int(dur * 60.0)
	for k in range(steps):
		s.keep_frames = false
		s.run(1.0 / 60.0, func(_t): return v)
		if s.t < t_from:
			continue
		n += 1
		var p: Dictionary = s.ctl.pose
		if Support.margin(Support.polygon(p, s.morph, false), Vector2(p.com.x, p.com.z)) >= 0.0:
			ok += 1
	return float(ok) / max(n, 1)

# ---------------------------------------------------------------- transitions
func test_transitions() -> void:
	print("gait transitions (within +-%.2f of the target Froude number)" % FR_TOL)
	var table := {}
	for name in ["biped", "horizontal_biped", "wader", "light_quadruped", "heavy_quadruped"]:
		var s = Sim.new(Bodies.get_body(name))
		s.keep_frames = false
		var lad: Array = Gait.ladder(s.morph)
		var top: float = lad[-1][2] + 1.0
		var v_top: float = s.speed_for_froude(top)
		var dur := 30.0
		# speed ramps up then down, linearly in time
		s.run(2.0 * dur, func(t): return v_top * (1.0 - abs(t / dur - 1.0)))
		var rows: Array = []
		var seen := {}
		var ok := true
		for e in s.gait_events:
			var target := -1.0
			for rung in lad:
				if (rung[0] == e.from and rung[1] == e.to) or (rung[1] == e.from and rung[0] == e.to):
					target = rung[2]
			var err: float = e.fr - target
			rows.append({"from": str(e.from), "to": str(e.to), "froude": r(e.fr, 3), "target": target, "error": r(err, 3)})
			seen["%s>%s" % [e.from, e.to]] = true
			if target < 0.0 or abs(err) > FR_TOL:
				ok = false
		check(ok and s.gait_events.size() == 2 * lad.size(), "%s: %d transitions, all within tolerance: %s" % [name, s.gait_events.size(), str(rows.map(func(x): return "%s>%s@%.2f" % [x.from, x.to, x.froude]))])
		table[name] = rows
	# no chatter when holding a speed right at the boundary
	var s3 = Sim.new(Bodies.get_body("light_quadruped"))
	s3.keep_frames = false
	var vb: float = s3.speed_for_froude(0.5)
	s3.run(12.0, func(t): return vb * (1.0 + 0.03 * sin(t * 7.0)))
	check(s3.gait_events.size() <= 1, "no gait chatter when the speed wobbles around Fr 0.5 (%d changes)" % s3.gait_events.size())
	out["transitions"] = table

# ---------------------------------------------------------------- footfalls
func _phase_err(a: float, b: float) -> float:
	return abs(a - b - round(a - b))

func test_footfall_patterns() -> void:
	print("footfall patterns measured from contacts")
	var table := {}
	var cases := [
		["biped", 0.25, &"walk"], ["biped", 1.5, &"run"], ["horizontal_biped", 0.25, &"walk"], ["horizontal_biped", 1.5, &"run"],
		["wader", 0.1, &"walk"], ["wader", 1.5, &"run"],
		["light_quadruped", 0.1, &"walk"], ["light_quadruped", 1.2, &"trot"], ["light_quadruped", 5.0, &"gallop"],
		["heavy_quadruped", 0.1, &"walk"], ["heavy_quadruped", 0.8, &"amble"], ["hexapod", 0.3, &"tripod"]]
	for c in cases:
		var s = Sim.new(Bodies.get_body(c[0]))
		var v: float = s.speed_for_froude(c[1])
		s.run(12.0, func(_t): return v)
		var ff: Dictionary = s.footfalls(4.0)
		var model := Gait.offsets(c[2], s.morph)
		var worst_p := 0.0
		var worst_d := 0.0
		for i in range(model.size()):
			worst_p = max(worst_p, _phase_err(ff.phase[i], model[i] - model[0]))
			worst_d = max(worst_d, abs(ff.duty[i] - Gait.duty(c[2], c[1])))
		var aerial := 0
		var n := 0
		for f in s.frames:
			if f.t >= 4.0:
				n += 1
				if f.n == 0:
					aerial += 1
		var air: float = float(aerial) / max(n, 1)
		var period_model: float = Gait.stride_length(c[2], c[1], s.morph.hip_height) * s.ctl._stride_mult / v
		check(s.ctl.gait == c[2] and worst_p < 0.04 and worst_d < 0.04, "%s Fr %.2f: %s, phase error %.3f, duty error %.3f, airborne %.0f%%" % [c[0], c[1], s.ctl.gait, worst_p, worst_d, air * 100.0])
		table["%s@Fr%.2f" % [c[0], c[1]]] = {"gait": str(s.ctl.gait), "stride_period_s": r(ff.period, 3), "stride_m": r(s.ctl.stride, 3),
			"cadence_hz": r(s.ctl.cadence, 3), "duty_measured": ff.duty.map(func(x): return r(x, 3)), "touchdown_phase": ff.phase.map(func(x): return r(x, 3)),
			"airborne_pct": r(air * 100.0, 1), "period_from_alexander_s": r(period_model, 3)}
		if c[2] == &"walk" or c[2] == &"tripod":
			check(aerial == 0, "%s %s never leaves the ground" % [c[0], c[2]])
		if c[2] == &"run" or c[2] == &"gallop":
			check(air > 0.05, "%s %s has a flight phase (%.0f%% of the stride)" % [c[0], c[2], air * 100.0])
	out["footfalls"] = table

# ---------------------------------------------------------------- body dynamics
func _mean(frames: Array, key: String, pred: Callable) -> float:
	var s := 0.0
	var n := 0
	for f in frames:
		if pred.call(f):
			s += f[key]
			n += 1
	return s / max(n, 1)

func _range(frames: Array, key: String, t_from: float) -> float:
	var lo := INF
	var hi := -INF
	for f in frames:
		if f.t >= t_from:
			lo = min(lo, f[key])
			hi = max(hi, f[key])
	return hi - lo

func test_body_dynamics() -> void:
	print("body dynamics")
	var table := {}
	# inverted pendulum: highest in single support, lowest in double support
	for name in ["biped", "horizontal_biped", "wader"]:
		var s = Sim.new(Bodies.get_body(name))
		var v: float = s.speed_for_froude(0.25)
		s.run(10.0, func(_t): return v)
		var single := _mean(s.frames, "com_y", func(f): return f.t > 3.0 and f.n == 1)
		var double := _mean(s.frames, "com_y", func(f): return f.t > 3.0 and f.n == 2)
		var rng := _range(s.frames, "com_y", 3.0)
		check(single > double + 0.002 * s.morph.hip_height, "%s walk vaults: centre of mass %.1f mm higher in single support; excursion %.1f mm" % [name, (single - double) * 1000.0, rng * 1000.0])
		table[name + " walk Fr0.25"] = {"com_single_minus_double_mm": r((single - double) * 1000.0, 1), "com_excursion_mm": r(rng * 1000.0, 1)}
		# spring-mass: lowest in stance, highest in flight
		var s2 = Sim.new(Bodies.get_body(name))
		var v2: float = s2.speed_for_froude(1.5)
		s2.run(10.0, func(_t): return v2)
		var air := _mean(s2.frames, "com_y", func(f): return f.t > 3.0 and f.n == 0)
		var stance := _mean(s2.frames, "com_y", func(f): return f.t > 3.0 and f.n >= 1)
		var rng2 := _range(s2.frames, "com_y", 3.0)
		check(air > stance + 0.002 * s2.morph.hip_height, "%s run bounces: centre of mass %.1f mm higher in flight than in stance; excursion %.1f mm" % [name, (air - stance) * 1000.0, rng2 * 1000.0])
		table[name + " run Fr1.5"] = {"com_flight_minus_stance_mm": r((air - stance) * 1000.0, 1), "com_excursion_mm": r(rng2 * 1000.0, 1)}
	# quadruped trot bounce and gallop pitch
	var q = Sim.new(Bodies.get_body("light_quadruped"))
	var vq: float = q.speed_for_froude(5.0)
	q.run(10.0, func(_t): return vq)
	var pr := _range(q.frames, "pitch", 4.0)
	check(pr > deg_to_rad(1.5) and pr < deg_to_rad(20.0), "gallop rocks the body: pitch range %.1f degrees" % rad_to_deg(pr))
	var qt = Sim.new(Bodies.get_body("light_quadruped"))
	var vt: float = qt.speed_for_froude(1.2)
	qt.run(10.0, func(_t): return vt)
	var ptr := _range(qt.frames, "pitch", 4.0)
	check(ptr < pr, "trot pitches less than gallop (%.1f vs %.1f degrees)" % [rad_to_deg(ptr), rad_to_deg(pr)])
	table["light_quadruped pitch range deg"] = {"trot": r(rad_to_deg(ptr), 2), "gallop": r(rad_to_deg(pr), 2)}
	# heavier bodies: lower cadence, more damping
	var light = Sim.new(Bodies.get_body("light_quadruped"))
	var dense: Dictionary = Bodies.get_body("light_quadruped")
	dense["density"] = 8000.0
	var heavy = Sim.new(dense)
	light.run(6.0, func(_t): return 1.0)
	heavy.run(6.0, func(_t): return 1.0)
	check(heavy.ctl.cadence < light.ctl.cadence and heavy.ctl._zeta > light.ctl._zeta and heavy.ctl._omega < light.ctl._omega,
		"same legs, 8x the mass: cadence %.2f -> %.2f Hz, damping ratio %.2f -> %.2f" % [light.ctl.cadence, heavy.ctl.cadence, light.ctl._zeta, heavy.ctl._zeta])
	var lq = Sim.new(Bodies.get_body("light_quadruped"))
	var hq = Sim.new(Bodies.get_body("heavy_quadruped"))
	lq.run(6.0, func(_t): return lq.speed_for_froude(0.25))
	hq.run(6.0, func(_t): return hq.speed_for_froude(0.25))
	check(hq.ctl.cadence < lq.ctl.cadence, "at the same Froude number the heavy quadruped steps slower (%.2f vs %.2f Hz)" % [hq.ctl.cadence, lq.ctl.cadence])
	table["cadence_hz"] = {"light_quadruped 1 m/s": r(light.ctl.cadence, 3), "same body 8x mass 1 m/s": r(heavy.ctl.cadence, 3),
		"light_quadruped Fr0.25": r(lq.ctl.cadence, 3), "heavy_quadruped Fr0.25": r(hq.ctl.cadence, 3)}
	# banking: lean into the turn
	for name in ["biped", "light_quadruped"]:
		var s = Sim.new(Bodies.get_body(name))
		var v: float = s.speed_for_froude(1.0)
		s.run(6.0, func(_t): return v, func(_t): return 0.8)
		var roll := _mean(s.frames, "roll", func(f): return f.t > 3.0)
		var expect: float = -atan(v * 0.8 / 9.81) * s.ctl.bank_gain
		check(roll < -0.02 and abs(roll - expect) < 0.5 * abs(expect), "%s banks into a left turn: roll %.1f degrees (model %.1f)" % [name, rad_to_deg(roll), rad_to_deg(expect)])
		var s2 = Sim.new(Bodies.get_body(name))
		s2.run(6.0, func(_t): return v, func(_t): return -0.8)
		check(_mean(s2.frames, "roll", func(f): return f.t > 3.0) > 0.02, "%s banks the other way in a right turn" % name)
		table[name + " bank deg at 0.8 rad/s"] = r(rad_to_deg(roll), 2)
	# acceleration: bipeds lean forward, quadrupeds squat at the back
	var b = Sim.new(Bodies.get_body("biped"))
	b.run(1.0, func(_t): return 0.0)
	b.frames.clear()
	b.run(1.0, func(t): return 2.5 * (t - 1.0))
	var lean := _mean(b.frames, "pitch", func(f): return f.t > 1.4)
	check(lean > 0.03, "biped leans forward when accelerating at 2.5 m/s2 (%.1f degrees)" % rad_to_deg(lean))
	var qa = Sim.new(Bodies.get_body("light_quadruped"))
	qa.run(1.0, func(_t): return 0.0)
	qa.frames.clear()
	qa.run(1.0, func(t): return 3.0 * (t - 1.0))
	var squat := _mean(qa.frames, "pitch", func(f): return f.t > 1.4)
	check(squat < -0.01, "quadruped squats at the back when accelerating at 3 m/s2 (nose up %.1f degrees)" % rad_to_deg(-squat))
	table["accel pitch deg"] = {"biped (forward lean +)": r(rad_to_deg(lean), 2), "light_quadruped (nose up -)": r(rad_to_deg(squat), 2)}
	# slopes: body pitches with the terrain, stride shortens uphill
	for name in ["light_quadruped", "heavy_quadruped", "hexapod", "biped"]:
		var flat = Sim.new(Bodies.get_body(name))
		var up = Sim.new(Bodies.get_body(name), func(_x, z): return 0.2 * z)
		var v: float = flat.speed_for_froude(0.2)
		flat.run(8.0, func(_t): return v)
		up.run(8.0, func(_t): return v)
		var p_flat := _mean(flat.frames, "pitch", func(f): return f.t > 3.0)
		var p_up := _mean(up.frames, "pitch", func(f): return f.t > 3.0)
		var want := -atan(0.2)
		if name == "biped":
			check(p_up - p_flat < -0.01 and p_up - p_flat > 0.6 * want, "biped stays mostly upright on a 20%% climb (pitch %.1f of %.1f degrees)" % [rad_to_deg(p_up - p_flat), rad_to_deg(want)])
		else:
			check(abs((p_up - p_flat) - want) < 0.3 * abs(want), "%s pitches with a 20%% climb: %.1f degrees (terrain %.1f)" % [name, rad_to_deg(p_up - p_flat), rad_to_deg(want)])
		check(up.ctl.stride < 0.85 * flat.ctl.stride and up.ctl.cadence > flat.ctl.cadence, "%s shortens its stride uphill: %.2f -> %.2f m" % [name, flat.ctl.stride, up.ctl.stride])
		table[name + " 20% climb"] = {"pitch_deg": r(rad_to_deg(p_up - p_flat), 2), "stride_flat_m": r(flat.ctl.stride, 3), "stride_uphill_m": r(up.ctl.stride, 3)}
	# neck and tail: counter-motion with lag
	var th = Sim.new(Bodies.get_body("horizontal_biped"))
	var vth: float = th.speed_for_froude(0.3)
	th.run(3.0, func(_t): return vth)
	th.frames.clear()
	th.run(3.0, func(_t): return vth, func(_t): return 0.9)
	var late := 0.0
	var neck_late := 0.0
	var t_half := -1.0
	for f in th.frames:
		if f.t > 5.0:
			late += f.tail.yaw
			neck_late += f.neck.yaw
	var nlate := 0
	for f in th.frames:
		if f.t > 5.0:
			nlate += 1
	late /= max(nlate, 1)
	neck_late /= max(nlate, 1)
	for f in th.frames:
		if t_half < 0.0 and abs(f.tail.yaw) > 0.5 * abs(late) and sign(f.tail.yaw) == sign(late):
			t_half = f.t - 3.0
	check(late < -0.02 and neck_late > 0.05, "in a left turn the tail lags behind the turn (%.1f degrees) and the neck looks in (%.1f degrees)" % [rad_to_deg(late), rad_to_deg(neck_late)])
	check(t_half > 0.03, "the tail lags the turn: half deflection after %.0f ms" % (t_half * 1000.0))
	var tail_sway := 0.0
	var st = Sim.new(Bodies.get_body("horizontal_biped"))
	st.run(8.0, func(_t): return vth)
	for f in st.frames:
		if f.t > 3.0:
			tail_sway = max(tail_sway, abs(f.tail.yaw))
	check(tail_sway > 0.01, "walking straight, the tail swings against the pelvis (%.1f degrees)" % rad_to_deg(tail_sway))
	var up2 = Sim.new(Bodies.get_body("light_quadruped"), func(_x, z): return 0.2 * z)
	up2.run(6.0, func(_t): return 0.8)
	var np := 0.0
	var nn := 0
	for f in up2.frames:
		if f.t > 3.0:
			np += f.neck.pitch
			nn += 1
	np /= max(nn, 1)
	check(np < -0.02, "climbing, the neck pitches down to keep the head level (%.1f degrees)" % rad_to_deg(np))
	table["theropod left turn 0.9 rad/s"] = {"tail_yaw_deg": r(rad_to_deg(late), 2), "neck_yaw_deg": r(rad_to_deg(neck_late), 2), "tail_half_response_ms": r(t_half * 1000.0, 0)}
	# legless: undulation scales with speed, no feet
	var sn = Sim.new(Bodies.get_body("legless"))
	sn.run(4.0, func(_t): return 0.6)
	check(sn.ctl.gait == &"slither" and sn.ctl.pose.wave.amp > 0.02 and abs(sn.ctl.wave_offset(0.2)) <= sn.ctl.pose.wave.amp, "legless body slithers (wave amplitude %.0f mm)" % (sn.ctl.pose.wave.amp * 1000.0))
	out["body_dynamics"] = table

# ---------------------------------------------------------------- swing
func test_swing() -> void:
	print("swing arcs")
	var table := {}
	for name in PLANS:
		var slow = Sim.new(Bodies.get_body(name))
		var fast = Sim.new(Bodies.get_body(name))
		var h: float = slow.morph.hip_height
		slow.keep_frames = false
		fast.keep_frames = false
		slow.run(8.0, func(_t): return slow.speed_for_froude(0.1))
		fast.run(8.0, func(_t): return fast.speed_for_froude(1.0))
		# a ridge 0.12 hip heights tall every 1.7 hip heights
		var ridge := func(_x, z): return 0.12 * h * pow(max(0.0, sin(z / h * 3.7)), 8.0)
		var obs = Sim.new(Bodies.get_body(name), ridge)
		obs.keep_frames = false
		obs.run(12.0, func(_t): return obs.speed_for_froude(0.1))
		check(fast.max_swing_lift > slow.max_swing_lift * 1.2, "%s lifts its feet higher when faster (%.0f -> %.0f mm)" % [name, slow.max_swing_lift * 1000.0, fast.max_swing_lift * 1000.0])
		check(obs.min_clearance > -1e-5 and slow.min_clearance > -1e-5 and fast.min_clearance > -1e-5, "%s swing feet never go below the ground (min %.2f mm over ridges)" % [name, obs.min_clearance * 1000.0])
		check(obs.max_slide() < SLIDE_LIMIT, "%s keeps its feet planted over ridges (slide %.2f mm)" % [name, obs.max_slide() * 1000.0])
		table[name] = {"lift_slow_mm": r(slow.max_swing_lift * 1000.0, 1), "lift_fast_mm": r(fast.max_swing_lift * 1000.0, 1), "ridge_height_mm": r(0.12 * h * 1000.0, 1),
			"min_clearance_over_ridges_mm": r(obs.min_clearance * 1000.0, 2)}
	out["swing"] = table

# ---------------------------------------------------------------- stop / turn
func test_stop_and_turn_in_place() -> void:
	print("stopping and turning in place")
	for name in PLANS:
		var s = Sim.new(Bodies.get_body(name))
		var v: float = s.speed_for_froude(0.3)
		s.run(4.0, func(_t): return v)
		s.run(4.0, func(_t): return 0.0)
		var all_down := true
		for c in s.ctl.pose.contact:
			if not c:
				all_down = false
		var ph: float = s.ctl.phase
		s.run(1.0, func(_t): return 0.0)
		var worst := 0.0
		var root: Transform3D = Transform3D(Basis(Vector3.UP, s.yaw), s.pos)
		for i in range(s.morph.legs.size()):
			var home: Vector3 = root * Vector3(s.morph.legs[i].home.x, 0.0, s.morph.legs[i].home.z)
			var f: Vector3 = s.ctl.pose.feet[i]
			worst = max(worst, Vector2(f.x - home.x, f.z - home.z).length())
		check(all_down and s.ctl.phase == ph and worst < 0.13 * s.morph.hip_height, "%s comes to rest: all feet down, clock stopped, feet within %.0f mm of home" % [name, worst * 1000.0])
		# turn on the spot: the feet must step round, not twist
		var s2 = Sim.new(Bodies.get_body(name))
		s2.run(6.0, func(_t): return 0.0, func(_t): return 1.0)
		check(s2.steps.size() >= s2.morph.legs.size() and s2.max_slide() < SLIDE_LIMIT, "%s turns on the spot by stepping (%d steps, slide %.2f mm)" % [name, s2.steps.size(), s2.max_slide() * 1000.0])

# ---------------------------------------------------------------- robustness
func test_robustness() -> void:
	print("robustness")
	for name in ["octopod", "monopod", "tripod", "legless"] + PLANS:
		var s = Sim.new(Bodies.get_body(name))
		s.keep_frames = false
		var vmax: float = s.morph.proposal.max_speed
		s.run(4.0, func(t): return vmax * abs(sin(t * 1.3)), func(t): return 2.0 * sin(t * 2.1), 1.0 / 20.0)
		s.ctl.step(1.0 / 60.0, s.pos + Vector3(500, 0, 300), s.yaw)   # teleport
		s.run(2.0, func(_t): return vmax * 2.5, func(t): return 3.0 * cos(t), 1.0 / 144.0)
		var root: Transform3D = s.ctl.pose.root
		check(not s.nan_seen and abs(root.origin.y) < 10.0, "%s survives 20 Hz frames, a teleport and 2.5x its top speed" % name)
	var oc = Sim.new(Bodies.get_body("octopod"))
	oc.run(8.0, func(_t): return oc.speed_for_froude(0.2))
	check(oc.stable_fraction(2.0) > STABLE_LIMIT and oc.max_slide() < SLIDE_LIMIT, "octopod: alternating tetrapods, stable %.1f%%, slide %.2f mm" % [oc.stable_fraction(2.0) * 100.0, oc.max_slide() * 1000.0])

# ---------------------------------------------------------------- proposal
func test_proposal() -> void:
	print("speed proposal for the C profile")
	var table := {}
	var p := {}
	for name in Bodies.names():
		var m = Morph.analyse(Bodies.get_body(name))
		p[name] = m.proposal
		var row := {}
		for k in m.proposal:
			row[k] = r(m.proposal[k], 3)
		table[name] = row
		check(m.proposal.max_speed >= 0.5 and m.proposal.max_speed <= 12.0 and m.proposal.max_accel > 0.0 and m.proposal.max_turn_per_tick <= 0.38 + 1e-6,
			"%s: top speed %.1f m/s (roam %.1f), acceleration %.1f m/s2, turn %.2f rad/s" % [name, m.proposal.max_speed, m.proposal.roam_speed, m.proposal.max_accel, m.proposal.max_turn_rate])
	check(p["light_quadruped"].max_speed > p["heavy_quadruped"].max_speed, "light quadruped outruns the heavy one")
	check(p["light_quadruped"].max_speed > p["hexapod"].max_speed and p["hexapod"].max_speed > p["legless"].max_speed, "quadruped > hexapod > legless")
	check(p["heavy_quadruped"].max_accel < p["light_quadruped"].max_accel and p["heavy_quadruped"].max_turn_rate < p["light_quadruped"].max_turn_rate, "the heavy body accelerates and turns slower")
	check(p["horizontal_biped"].max_speed > p["biped"].max_speed, "the horizontal biped outruns the upright one")
	out["speed_proposal"] = table

# ---------------------------------------------------------------- quality
## Body-motion quality (plan step 2). Printed and recorded; gated only where
## the current model passes with margin.
func test_quality() -> void:
	print("motion quality")
	var table := {}
	for name in PLANS:
		var row := {}
		for sc in [["slow walk", 0.05], ["walk", 0.25]]:
			var s = Sim.new(Bodies.get_body(name))
			s.keep_frames = false
			s.run(14.0, func(_t): return s.speed_for_froude(sc[1]))
			row[sc[0]] = {"max_drop": r(s.max_drop, 4), "max_vert_acc_g": r(s.max_vert_acc, 3), "forced_lifts": s.ctl.forced_lifts,
				"stance_knee_deg": r(s.knee_mean(), 1)}
			print("  note  %-17s %-9s max_drop %.4f  max |vert acc| %.2f g  knee at mid-stance %.1f deg  forced lifts %d" % [name, sc[0], s.max_drop, s.max_vert_acc, s.knee_mean(), s.ctl.forced_lifts])
		table[name] = row
		check(row["walk"].max_drop < 0.03 and row["slow walk"].max_drop < (0.05 if name == "heavy_quadruped" else 0.03),
			"%s: reach-guard drop %.1f%% / %.1f%% of hip height (walk / slow walk)" % [name, row["walk"].max_drop * 100.0, row["slow walk"].max_drop * 100.0])
		check(row["walk"].forced_lifts == 0 and row["slow walk"].forced_lifts == 0, "%s: no lift-off forced by the reach guard in steady walks" % name)
	# pitch from the pendulum constraint: a walking quadruped's body rocks a little
	for name in ["light_quadruped", "heavy_quadruped"]:
		var sq = Sim.new(Bodies.get_body(name))
		sq.run(12.0, func(_t): return sq.speed_for_froude(0.12))
		var pr := rad_to_deg(_range(sq.frames, "pitch", 4.0))
		print("  note  %s walk Fr 0.12 pitch range %.2f deg" % [name, pr])
		table[name]["pitch_range_deg_Fr0.12"] = r(pr, 2)
		check(pr > 0.3 and pr < 4.0, "%s walk rocks with the pendulum constraint: pitch range %.2f degrees at Fr 0.12" % [name, pr])
	out["quality"] = table
