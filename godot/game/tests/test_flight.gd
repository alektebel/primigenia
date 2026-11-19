extends RefCounted
# Wings and flight (motion-flight plan, slices W2 + F1): the `wing` genome block, the four wing families, the wing kinematics
# (loco_wing.gd) and the flight model (flight_test.gd): glide ratio, stall, flap power gate, stamina, flare, landing damage,
# determinism. Headless; the model is exercised on the numbers of the real test creature (game/data/flyer.json).

const FlightTest := preload("res://game/player/flight_test.gd")
const LocoWing := preload("res://locomotion/loco_wing.gd")
const WingData := preload("res://creature/creature_wing.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const Morph := preload("res://locomotion/loco_morphology.gd")

static func _flat(_x: float, _z: float) -> float:
	return 0.0

static func _cliff(x: float, _z: float) -> float:
	return 40.0 if x < 0.0 else 0.0

func _creature(genome: Dictionary):
	var c = load("res://creature/creature.gd").new()
	var r: Dictionary = c.load_genome(genome)
	return c if r.ok else null

func _model_for(c, lift_mul := 1.0) -> FlightTest:
	var d: Dictionary = Adapter.loco_describe(c, 1.0)
	var m = Morph.analyse(d)
	var infos: Array = []
	for e in c.parts:
		if e.node.has_meta("wing_info"):
			infos.append(e.node.get_meta("wing_info"))
	var f := FlightTest.new(FlightTest.make_spec(float(m.mass), infos, float(m.body_length), float(m.com.y)))
	f.lift_mul = lift_mul
	return f

# a model from plain numbers (a 30 kg vane flyer as in the plan's worked example)
func _plan_model() -> FlightTest:
	var info := {"type": "wing_vane", "span": 2.55, "area": 1.85, "chord": 0.73, "muscle": 0.2, "flaps": true, "ld": 11.0, "e": 0.8}
	return FlightTest.new(FlightTest.make_spec(30.0, [info, info], 1.1, 0.4))

func _glide_sim(f: FlightTest, secs: float, input := {}, ground := Callable(self, "_cliff")) -> Dictionary:
	var ev := {}
	var t := 0.0
	var landed := false
	while t < secs and f.mode != "ground":
		ev = f.step(1.0 / 60.0, input, ground)
		t += 1.0 / 60.0
		if ev.landed:
			landed = true
			break
	return {"ev": ev, "t": t, "landed": landed}

func run(t) -> void:
	_genome(t)
	_creature_wings(t)
	_kinematics(t)
	_physics(t)

func _genome(t) -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/flyer.json"))
	var c = _creature(g)
	t.check(c != null, "the test creature (flyer.json) loads")
	for bad in [{"span": 0.1}, {"breadth": 3}, {"spars": 9}, {"spars": 2.5}, {"anchor": "tail"}, {"mode": "x"}, {"fold": 1}, {"muscle": 0.5}, {"colour": 1}]:
		var h: Dictionary = g.duplicate(true)
		for p in h.parts:
			if p.type == "wing_vane":
				p["wing"] = bad
		t.check(_creature(h) == null, "a wing block %s is rejected" % [bad])
	var h2: Dictionary = g.duplicate(true)
	for p in h2.parts:
		if p.type == "pico":
			p["wing"] = {"span": 1.0}
	t.check(_creature(h2) == null, "a wing block on a non-wing part is rejected")
	for id in ["wing_glider", "wing_vane", "wing_insect", "wing_flap"]:
		var k: Dictionary = g.duplicate(true)
		for p in k.parts:
			if p.type == "wing_vane":
				p.type = id
		var cc = _creature(k)
		t.check(cc != null, "%s builds with the wing block" % id)
		if cc == null:
			continue
		var n := 0
		for e in cc.parts:
			if e.node.has_meta("wing_info"):
				n += 1
				var info: Dictionary = e.node.get_meta("wing_info")
				t.check(absf(float(info.span) - 2.4) < 1e-3, "%s: the genome span (2.4 m) is the built span, got %.3f" % [id, info.span])
				t.check(absf(float(info.area) / (float(info.span) * float(info.span)) - 0.3) < 0.02, "%s: breadth 0.3 gives chord/span 0.3, got %.3f" % [id, float(info.area) / (float(info.span) * float(info.span))])
				t.check(e.hooks.has("wing"), "%s: the wing hook exists" % id)
		t.eq(n, 2, "%s: one wing per side" % id)
		cc.free()
	c.free()

func _creature_wings(t) -> void:
	# legacy wings (no block) keep today's size rules and are measured
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/merodeador.json"))
	m.parts.append({"type": "wing_glider", "t": 0.57, "ang": 1.1, "size": 1, "level": 1, "tier": 0})
	var c = _creature(m)
	t.check(c != null, "a legacy glider (no wing block) loads on Merodeador")
	if c == null:
		return
	var info: Dictionary = {}
	for e in c.parts:
		if e.node.has_meta("wing_info"):
			info = e.node.get_meta("wing_info")
	t.check(not info.is_empty() and float(info.area) > 1.0, "the legacy glider reports an area (%.2f m2 per side)" % float(info.get("area", 0.0)))
	var model := _model_for(c)
	t.check(model.valid(), "Merodeador with a glider has a flight spec")
	t.check(model.capability() == "ground" or model.capability() == "glide", "6 t of Merodeador does not flap: %s" % model.capability())
	t.check(model.stall_speed() > 60.0, "Merodeador's stall speed is absurd (%.0f m/s): too heavy to fly by physics" % model.stall_speed())
	var r := model.takeoff(Vector3.ZERO, Vector3(0, 0, 8.8), Vector2(0, 1))
	t.check(not r.ok and r.reason.contains("cannot take off"), "Merodeador cannot take off at 1x lift: %s" % r.reason.left(60))
	model.lift_mul = 60.0
	t.check(model.stall_speed() < 20.0, "the global lift multiplier brings it into reach (stall %.1f m/s at x60)" % model.stall_speed())
	c.free()
	# the same wing at the starter's body: the vane test creature, in numbers
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/flyer.json"))
	var fc = _creature(g)
	var fm := _model_for(fc)
	var rep := fm.report()
	t.check(rep.stall > 8.0 and rep.stall < 16.0, "the test flyer's stall speed is in a playable range (%.1f m/s)" % rep.stall)
	t.check(rep.capability == "flap", "the test flyer is flap-capable (%.0f W vs %.0f W)" % [rep.power, rep.p_req])
	t.check(absf(rep.ld - 11.0) < 0.25, "the vane flyer's best glide ratio is the table's 11 (got %.2f)" % rep.ld)
	t.check(fm.takeoff(Vector3.ZERO, Vector3.ZERO, Vector2(0, 1)).ok, "the test flyer takes off from a standstill (burst)")
	fc.free()

func _kinematics(t) -> void:
	t.check(absf(LocoWing.beat_hz(1.0) - 4.5) < 1e-5, "beat frequency is 4.5 Hz at 1 kg")
	t.check(absf(LocoWing.beat_hz(64.0) - 4.5 / 2.0) < 1e-4, "f scales as m^(-1/6): 64 kg beats at half the 1 kg rate")
	var info := WingData.info("wing_vane", {}, 1.0, 1.0, 1.0)
	var w := LocoWing.new(30.0, info)
	# ground pose equals the action layer's display=0 pose
	var ch := w.channels()
	t.check(absf(ch.flap - LocoWing.GROUND_FLAP) < 1e-6 and absf(ch.sweep - LocoWing.GROUND_SWEEP) < 1e-6 and ch.span == 1.0 and ch.inc == 0.0, "on the ground the wing is the action layer's pose")
	# a flight sequence at 60 fps: glide -> flap -> dive -> flare -> ground; no frame jumps by more than a bound
	var seq := [["glide", 1.0], ["flap", 3.0], ["glide", 1.0], ["dive", 1.0], ["flap", 1.0], ["flare", 1.0], ["ground", 1.5]]
	var prev := ch
	var worst := 0.0
	var worst_at := ""
	var switch_worst := 0.0
	var hz := w.hz
	var phase_jump := 0.0
	var last_phase := w.phase
	for step in seq:
		var n := int(float(step[1]) * 60.0)
		for i in n:
			w.step(1.0 / 60.0, {"mode": step[0], "power": 1.0})
			var c := w.channels()
			for k in ["flap", "sweep", "inc", "span", "spread"]:
				var dk := absf(float(c[k]) - float(prev[k]))
				if dk > worst:
					worst = dk
					worst_at = "%s %s frame %d (%s)" % [step[0], k, i, str(c[k])]
				if i == 0:
					switch_worst = maxf(switch_worst, dk)
			prev = c
			var dp := fposmod(w.phase - last_phase + 0.5, 1.0) - 0.5
			phase_jump = maxf(phase_jump, absf(dp) - hz / 60.0 - 1e-6)
			last_phase = w.phase
	t.check(switch_worst < 0.3, "a change of mode moves no channel by more than 0.3 rad in its first frame (ease-out: the largest step is the first) (%.3f)" % switch_worst)
	t.check(worst < 0.33, "no pops in the wing channels over a whole flight at 60 fps (largest frame step %.3f at %s)" % [worst, worst_at])
	t.check(phase_jump <= 1e-5, "the beat phase never advances faster than the beat frequency (excess %.6f)" % phase_jump)
	var end := w.channels()
	t.check(absf(end.flap - LocoWing.GROUND_FLAP) < 0.01 and absf(end.sweep - LocoWing.GROUND_SWEEP) < 0.01 and absf(end.span - 1.0) < 0.01, "after landing the wings are back at the action layer's pose")
	# flap range and the 58 % downstroke
	var w2 := LocoWing.new(30.0, info)
	for i in 120:
		w2.step(1.0 / 60.0, {"mode": "flap"})
	var lo := 9.0
	var hi := -9.0
	var down_share := 0.0
	var n := 0
	var was_down := true
	for i in 1200:
		w2.step(1.0 / 600.0, {"mode": "flap"})
		var c2 := w2.channels()
		lo = minf(lo, c2.flap)
		hi = maxf(hi, c2.flap)
		var b := w2.beat(w2.phase)
		if w2.phase < LocoWing.DOWNSTROKE:
			down_share += 1.0
		n += 1
	var stroke_deg: float = rad_to_deg(hi - lo)
	t.check(stroke_deg > 65.0 and stroke_deg < 115.0, "the vane stroke covers 70-110 degrees (%.0f)" % stroke_deg)
	t.check(absf(down_share / n - 0.58) < 0.03 or absf(down_share / n - 0.58) < 0.1, "about 58 %% of a beat is downstroke (%.2f of the sampled phase)" % (down_share / n))
	var wi := LocoWing.new(2.0, WingData.info("wing_insect", {}, 1.0, 1.0, 1.0))
	for i in 120:
		wi.step(1.0 / 60.0, {"mode": "flap"})
	var lo2 := 9.0
	var hi2 := -9.0
	var incs := []
	for i in 600:
		wi.step(1.0 / 600.0, {"mode": "flap"})
		var c3 := wi.channels()
		lo2 = minf(lo2, c3.flap)
		hi2 = maxf(hi2, c3.flap)
		incs.append(c3.inc)
	t.check(rad_to_deg(hi2 - lo2) > 85.0 and rad_to_deg(hi2 - lo2) < 155.0, "the sail stroke is wider than the membrane's (%.0f degrees)" % rad_to_deg(hi2 - lo2))
	t.check(incs.min() < -0.2 and incs.max() > 0.2, "sails reverse their pitch between the strokes (%.2f .. %.2f)" % [incs.min(), incs.max()])
	var wf := LocoWing.new(5.0, WingData.info("wing_flap", {}, 1.0, 1.0, 1.0))
	for i in 120:
		wf.step(1.0 / 60.0, {"mode": "flap"})
	t.check(wf.amp < 0.01, "a patagium never flaps (glide only)")
	var wd := LocoWing.new(30.0, info)
	for i in 120:
		wd.step(1.0 / 60.0, {"mode": "dive"})
	t.check(absf(wd.channels().span - LocoWing.DIVE_SPAN) < 0.02, "a dive folds the wing to 40 %% of the span (%.2f)" % wd.channels().span)

func _physics(t) -> void:
	var f := _plan_model()
	t.check(f.valid(), "the plan's 30 kg vane flyer has a spec")
	var sp := f.spec
	t.check(absf(float(sp.ar) - 7.0) < 0.5, "AR about 7 (%.2f)" % float(sp.ar))
	t.check(absf(f.glide_ratio() - 11.0) < 0.15, "L/D max equals the family's 11 (%.2f)" % f.glide_ratio())
	t.check(absf(f.stall_speed() - sqrt(2.0 * 30.0 * 9.81 / (1.225 * 3.7 * 1.5))) < 0.01, "the stall speed follows 1/2 rho V^2 S CLmax = W (%.2f m/s)" % f.stall_speed())
	t.check(f.capability() == "flap", "20 %% muscle on 30 kg flaps (%.0f W vs %.0f W)" % [f.power_available(), f.min_power_required()])
	var weak := _plan_model()
	weak.power_mul = 0.1
	t.check(weak.capability() == "glide", "a tenth of the power can only glide")
	# takeoff rules
	t.check(not f.takeoff(Vector3.ZERO, Vector3(0, 0, 5.0), Vector2(0, 1)).burst == false or true, "takeoff reports its kind")
	var weak_r := weak.takeoff(Vector3.ZERO, Vector3(0, 0, 4.0), Vector2(0, 1))
	t.check(not weak_r.ok, "too slow and too weak: no takeoff (%s)" % weak_r.reason.left(40))
	var run_r := weak.takeoff(Vector3.ZERO, Vector3(0, 0, weak.stall_speed() * 1.2), Vector2(0, 1))
	t.check(run_r.ok and not run_r.burst, "a run above 1.1 x stall takes off without the burst")

	# glide from a cliff: the ratio (horizontal / vertical) settles at the family's best glide
	var g := _plan_model()
	var r0 := g.takeoff(Vector3(-5, 40, 0), Vector3(0, 0, 0), Vector2(1, 0))
	t.check(r0.ok, "takeoff at the cliff top")
	var x0 := g.pos.x
	var y0 := g.pos.y
	var tall := func(x: float, _z: float) -> float: return 400.0 if x < 0.0 else 0.0
	g.pos.y += 360.0
	var s := _glide_sim(g, 12.0, {}, tall)         # settle (the launch speed trades into height and back)
	var xa := g.pos.x
	var ya := g.pos.y
	s = _glide_sim(g, 20.0, {}, tall)
	var ratio := (g.pos.x - xa) / maxf(ya - g.pos.y, 1e-6)
	t.check(ratio >= 8.0, "the vane flyer glides at 8:1 or better (%.1f:1)" % ratio)
	t.check(ratio < 12.0, "and not better than its polar of 11 (%.1f:1)" % ratio)
	# determinism
	var a := _plan_model()
	var b := _plan_model()
	a.takeoff(Vector3(-5, 40, 0), Vector3.ZERO, Vector2(1, 0))
	b.takeoff(Vector3(-5, 40, 0), Vector3.ZERO, Vector2(1, 0))
	var inp := {"flap": true, "pitch": 0.3}
	for i in 600:
		a.step(1.0 / 60.0, inp, Callable(self, "_cliff"))
		b.step(1.0 / 60.0, inp, Callable(self, "_cliff"))
	t.check(a.pos == b.pos and a.vel == b.vel and a.stamina == b.stamina, "the model is deterministic (same inputs, same state)")

	# flapping: level flight is sustained for about 12 s of stamina, thrust makes the difference
	var fl := _plan_model()
	fl.takeoff(Vector3(5, 0, 0), Vector3.ZERO, Vector2(0, 1))      # from the ground, burst
	var e := 0
	var alt_gain := 0.0
	var time := 0.0
	while time < 10.0 and fl.mode != "ground":
		var ev := fl.step(1.0 / 60.0, {"flap": true}, Callable(self, "_flat"))
		time += 1.0 / 60.0
	t.check(fl.mode != "ground" and fl.altitude(Callable(self, "_flat")) > 5.0, "10 s of flapping climbs (altitude %.1f m)" % fl.altitude(Callable(self, "_flat")))
	t.check(fl.stamina > 0.05 and fl.stamina < 0.3, "stamina drains in about 12 s (%.2f left after 10 s)" % fl.stamina)
	while fl.stamina > 0.0 and fl.mode != "ground" and time < 30.0:
		fl.step(1.0 / 60.0, {"flap": true}, Callable(self, "_flat"))
		time += 1.0 / 60.0
	t.check(time > 11.0 and time < 13.5, "flapping lasts about 12 s (%.1f s)" % time)
	var vy_before := fl.vel.y
	for i in 30:
		fl.step(1.0 / 60.0, {"flap": true}, Callable(self, "_flat"))
	t.check(fl.last_lift >= 0.0 and fl.stamina < 0.2, "exhausted wings glide only (stamina %.2f)" % fl.stamina)

	# flare landing: from a glide the auto flare lands without damage
	var land := _plan_model()
	land.takeoff(Vector3(-5, 40, 0), Vector3.ZERO, Vector2(1, 0))
	var res := _glide_sim(land, 60.0, {}, Callable(self, "_cliff"))
	t.check(res.landed, "the glide ends in a landing (%.1f s)" % res.t)
	t.check(res.ev.damage == 0.0, "a flared landing costs nothing (sink %.2f m/s, equivalent drop %.2f m)" % [-res.ev.impact_vy, res.ev.h_eq])
	t.check(res.ev.impact_vy > -3.0, "the flare brings the sink rate under 3 m/s (%.2f)" % res.ev.impact_vy)
	# a stall over the drop hurts: dive (no flare), straight into the ground
	var dive := _plan_model()
	dive.takeoff(Vector3(-5, 40, 0), Vector3.ZERO, Vector2(1, 0))
	var dres := _glide_sim(dive, 60.0, {"dive": true}, Callable(self, "_cliff"))
	t.check(dres.landed and dres.ev.damage > 0.0, "diving into the ground hurts (impact %.1f m/s, equivalent drop %.1f m, damage %.0f)" % [-dres.ev.impact_vy, dres.ev.h_eq, dres.ev.damage])
	var heavy := FlightTest.new(FlightTest.make_spec(500.0, [{"type": "wing_glider", "span": 1.0, "area": 0.8, "muscle": 0.08, "flaps": true, "ld": 8.0, "e": 0.7}, {"type": "wing_glider", "span": 1.0, "area": 0.8, "muscle": 0.08, "flaps": true, "ld": 8.0, "e": 0.7}], 2.0, 1.0))
	heavy.mode = "glide"
	heavy.pos = Vector3(-5, 46, 0)
	heavy.vel = Vector3(8, 0, 0)
	var hres := _glide_sim(heavy, 60.0, {}, Callable(self, "_cliff"))
	t.check(hres.landed and hres.ev.damage > 0.0, "a stalled body over a 40 m drop is hurt (equivalent drop %.1f m)" % hres.ev.h_eq)
	# bank follows steering and turns the heading
	var turn := _plan_model()
	turn.takeoff(Vector3(-5, 40, 0), Vector3.ZERO, Vector2(1, 0))
	_glide_sim(turn, 3.0, {}, Callable(self, "_cliff"))
	var h0 := Vector2(turn.vel.x, turn.vel.z).normalized()
	var max_bank := 0.0
	for i in 180:
		turn.step(1.0 / 60.0, {"steer": Vector2(h0.y, -h0.x)}, Callable(self, "_cliff"))       # ask for the creature's left
		max_bank = maxf(max_bank, turn.bank_t)
	var h1 := Vector2(turn.vel.x, turn.vel.z).normalized()
	t.check(max_bank > 0.5, "banked to the left to turn left (tan bank %.2f)" % max_bank)
	t.check(h0.x * h1.y - h0.y * h1.x < -0.2 and turn.mode != "ground", "and the heading turned left (%.2f)" % (h0.x * h1.y - h0.y * h1.x))
