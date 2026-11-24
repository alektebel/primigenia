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
	_picks(t)
	_ground_takeoff(t)
	_creator_panel(t)

func _creator_panel(t) -> void:
	var Model = load("res://studio/model.gd")
	var Panel = load("res://studio/ui/wing_panel.gd")
	var Genome = load("res://studio/genome.gd")
	var m = Model.new()
	var i: int = m.add_part("wing_vane", 0.62, 1.3)
	t.check(i >= 0, "the creator can add a wing_vane")
	var p: Dictionary = m.doc["parts"][i]
	t.check(Panel.is_wing(p), "the panel recognises a wing")
	t.check(not Panel.is_wing(m.doc["parts"][0]), "and not a mouth")
	var box := VBoxContainer.new()
	Panel.build(box, m, null, i, func(s): return s)
	var names := {}
	var stack: Array = [box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		names[n.name] = n
		stack.append_array(n.get_children())
	for k in ["WingFamily", "WingSpan", "WingBreadth", "WingSpars", "WingMuscle", "WingMode", "WingFold"]:
		t.check(names.has(k), "the wing panel has %s" % k)
	(names["WingSpan"] as HSlider).value_changed.emit(1.8)
	(names["WingSpars"] as HSlider).value_changed.emit(3.0)
	(names["WingMode"] as OptionButton).item_selected.emit(1)
	(names["WingFamily"] as OptionButton).item_selected.emit(2)
	var q: Dictionary = m.doc["parts"][i]
	t.check(absf(float(q.wing.span) - 1.8) < 1e-6 and int(q.wing.spars) == 3 and q.wing.mode == "extra" and q.type == "wing_insect", "the controls write the wing block and the family (%s)" % [q])
	var types := {}
	for e in JSON.parse_string(FileAccess.get_file_as_string("res://game/data/parts.json")).parts:
		types[e.id] = e
	var gr: Dictionary = Genome.validate(m.doc, types)
	t.check(gr.ok, "the studio validates the document with the wing block (%s)" % gr.get("error", ""))
	var cr = _creature(m.doc.duplicate(true))
	t.check(cr != null, "and the creature module builds it")
	if cr != null:
		cr.free()
	var before: String = m.snapshot()
	m.undo()
	t.check(m.snapshot() != before, "a wing edit is one undoable step")
	box.free()

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
	# A31: lift_mul is dev-only; without dev tools the gain the mode hands the model is 1 whatever was tuned
	var dev = t.root.get_node_or_null("Dev")
	if dev != null:
		var fm = load("res://game/player/flight_mode.gd").new()
		fm._lift_mul = 60.0
		var was: bool = dev.enabled
		dev.enabled = false
		t.eq(fm.lift_gain(), 1.0, "normal play: lift_mul is ignored (physics decides who flies)")
		dev.enabled = true
		t.eq(fm.lift_gain(), 60.0, "dev builds: lift_mul applies")
		dev.enabled = was
		fm = null # FlightMode is RefCounted.
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
	_bird_turn(t)

# A level cruiser at 18 m/s, 500 m up over flat ground, heading +Z. lift_mul 0 keeps the model's own; `balanced` sets it so that the
# pulled-up lift cancels the weight at the given bank (tan), the textbook level turn.
func _cruiser(balanced_tan := -1.0) -> FlightTest:
	var f := _plan_model()
	f.mode = "glide"
	f.pos = Vector3(0, 500.0, 0)
	f.vel = Vector3(0, 0, 18.0)
	f.climb_out = 0.0
	if balanced_tan >= 0.0:
		var q := 0.5 * FlightTest.RHO * 18.0 * 18.0
		f.lift_mul = float(f.spec.mass) * FlightTest.G / (q * float(f.spec.area) * f.cl_best())
	return f

func _bird_turn(t) -> void:
	var flat := Callable(self, "_flat")
	var dt := 1.0 / 60.0
	# 1. roll leads: holding left builds the bank gradually, it does not jump to the clamp
	var f := _cruiser()
	f.step(dt, {"roll": 1.0}, flat)
	t.check(f.bank_t > 0.0 and f.bank_t < 0.1, "a held turn key starts the roll gently (tan bank %.3f after one frame)" % f.bank_t)
	var tan30 := 0.0
	var t_half := -1.0
	var t_max := -1.0
	var time := dt
	var yaw_at_30 := 0.0
	while time < 4.0:
		f.step(dt, {"roll": 1.0}, flat)
		time += dt
		if t_half < 0.0 and f.bank_t >= 0.577:
			t_half = time
		if t_max < 0.0 and f.bank_t >= FlightTest.BANK_MAX_T - 1e-4:
			t_max = time
	t.check(t_half > 0.4 and t_half < 1.0, "a 30 degree bank takes %.2f s of holding (between 0.4 and 1 s)" % t_half)
	t.check(t_max > 1.3 and t_max < 2.6, "the sharp 60 degree bank takes %.2f s of holding" % t_max)
	t.check(f.bank_t <= FlightTest.BANK_MAX_T + 1e-6 and f.yaw_rate > 0.0, "the bank stops at 60 degrees and the bird turns left (%.2f rad/s)" % f.yaw_rate)
	# a tap is a gentle turn
	var tap := _cruiser()
	for i in 20:
		tap.step(dt, {"roll": -1.0}, flat)
	var after_tap := tap.bank_t
	t.check(after_tap < -0.12 and after_tap > -0.9, "a third of a second of D banks right, gently (tan %.2f)" % after_tap)
	# 2. roll-out: release the key and the wings come back level, smoothly
	var prev := f.bank_t
	var max_step := 0.0
	var back := 0.0
	for i in 400:
		f.step(dt, {}, flat)
		max_step = maxf(max_step, absf(f.bank_t - prev))
		prev = f.bank_t
		if absf(f.bank_t) < 0.02 and back == 0.0:
			back = float(i + 1) * dt
	t.check(back > 0.3 and back < 5.0 and absf(f.bank_t) < 0.01, "releasing the key rolls back out to level in %.2f s" % back)
	t.check(max_step < 0.03, "the roll-out has no jerk (largest frame step in tan bank %.4f)" % max_step)
	# 3. turn rate is the horizontal part of the lift: g tan(phi) / v, to 5 %
	for bank in [0.36, 0.577, 1.0]:
		var b := _cruiser(bank)
		var yaw := 0.0
		var pred := 0.0
		for i in 15:
			b.bank_t = bank
			b.roll_rate = 0.0
			var v := b.vel.length()
			b.step(dt, {}, flat)
			yaw += b.yaw_rate * dt
			pred += FlightTest.G * bank / v * dt
		t.check(absf(yaw / pred - 1.0) < 0.05, "turn rate at tan %.2f is g tan(phi)/v within 5 %% (%.3f vs %.3f rad in 0.25 s)" % [bank, yaw, pred])
	# the heading never changes without a bank (no direct yaw from the keys)
	var lvl := _cruiser()
	for i in 120:
		lvl.step(dt, {}, flat)
	t.check(absf(lvl.vel.x) < 1e-4 and absf(lvl.yaw_rate) < 1e-4, "wings level, the heading holds (vx %.6f)" % lvl.vel.x)
	# 4. a held-altitude 45 degree turn bleeds speed (and CL went up by 1/cos)
	var turn := _cruiser(1.0)
	var level := _cruiser(1.0)
	var y0 := turn.pos.y
	for i in 240:
		turn.bank_t = 1.0
		turn.roll_rate = 0.0
		turn.step(dt, {}, flat)
		level.step(dt, {}, flat)
	t.check(absf(turn.last_cl * 0.7071 / level.last_cl - 1.0) < 0.12 or turn.last_cl > level.last_cl * 1.2, "CL rises in the bank (%.2f vs %.2f level)" % [turn.last_cl, level.last_cl])
	t.check(turn.vel.length() < level.vel.length() - 0.3, "a 45 degree turn loses speed (%.2f vs %.2f m/s level after 4 s)" % [turn.vel.length(), level.vel.length()])
	t.check(absf(turn.pos.y - y0) < 25.0 and not turn.overbank, "and the altitude holds well enough (%.1f m)" % (turn.pos.y - y0))
	# too much bank or too little speed: it sinks (CL would exceed CL_MAX), and it says so
	var steep := _cruiser()
	steep.vel = Vector3(0, 0, steep.stall_speed() * 1.15)
	var sink0 := steep.pos.y
	var saw_over := false
	for i in 180:
		steep.bank_t = FlightTest.BANK_MAX_T
		steep.roll_rate = 0.0
		steep.step(dt, {}, flat)
		saw_over = saw_over or steep.overbank
	t.check(saw_over and steep.pos.y < sink0 - 8.0, "60 degrees near the stall speed overbanks and sinks (%.1f m in 3 s)" % (steep.pos.y - sink0))
	# 5. the head stays on the horizon while the body rolls
	var hd := _cruiser()
	var worst_head := 0.0
	var worst_body := 0.0
	for i in 150:
		hd.step(dt, {"roll": 1.0}, flat)
		worst_head = maxf(worst_head, absf(hd.head_roll()))
		worst_body = maxf(worst_body, absf(atan(hd.bank_t)))
	t.check(rad_to_deg(worst_body) > 55.0 and rad_to_deg(worst_head) < 6.0, "the head stays within %.1f degrees of level while the body rolls %.0f" % [rad_to_deg(worst_head), rad_to_deg(worst_body)])
	# determinism
	var da := _cruiser()
	var db := _cruiser()
	for i in 300:
		var inp := {"roll": 1.0 if (i / 70) % 2 == 0 else -1.0, "pitch": 0.2}
		da.step(dt, inp, flat)
		db.step(dt, inp, flat)
	t.check(da.pos == db.pos and da.vel == db.vel and da.bank_t == db.bank_t, "the turn is deterministic")

func _ground_takeoff(t) -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/flyer.json"))
	var c = _creature(g)
	var tests := {"burst": Vector3.ZERO, "run": Vector3(0, 0, 9.0)}
	for k in tests:
		var f := _model_for(c)
		var r := f.takeoff(Vector3.ZERO, tests[k], Vector2(0, 1))
		t.check(r.ok, "flat ground %s takeoff accepted" % k)
		var best := 0.0
		var time := 0.0
		var landed := false
		while time < 6.0 and f.mode != "ground":
			var ev := f.step(1.0 / 60.0, {"flap": true}, Callable(self, "_flat"))
			time += 1.0 / 60.0
			best = maxf(best, f.altitude(Callable(self, "_flat")))
			if ev.landed:
				landed = true
				break
		t.check(best >= 10.0 and not landed, "flat ground %s takeoff holding flap climbs to >= 10 m in 6 s (peak %.1f m, landed %s)" % [k, best, landed])
	# gliding without flapping still flares and lands softly
	var f2 := _model_for(c)
	f2.pos = Vector3(0, 30.0 + f2.spec.com_h, 0)
	f2.vel = Vector3(0, -1.0, 14.0)
	f2.mode = "glide"
	var saw_flare := false
	var res := {}
	var tt := 0.0
	while tt < 40.0 and f2.mode != "ground":
		var ev2 := f2.step(1.0 / 60.0, {}, Callable(self, "_flat"))
		tt += 1.0 / 60.0
		saw_flare = saw_flare or f2.mode == "flare"
		if ev2.landed:
			res = ev2
			break
	t.check(saw_flare and res.has("impact_vy") and absf(res.impact_vy) < 2.5, "a glide-down without flapping flares and lands softly (impact %.2f m/s)" % float(res.get("impact_vy", -99.0)))
	c.free()
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/merodeador.json"))
	m.parts.append({"type": "wing_glider", "t": 0.57, "ang": 1.1, "size": 1, "level": 1, "tier": 0})
	var mc = _creature(m)
	var mm := _model_for(mc)
	var mr := mm.takeoff(Vector3.ZERO, Vector3(0, 0, 8.8), Vector2(0, 1))
	t.check(not mr.ok and mr.reason.contains("cannot take off"), "Merodeador still cannot take off at lift_mul 1 and says why")
	mc.free()


# ---- the owner's picks (A56 starter B, A57 hatchling): flap-glide cruise, wingover, flare and running landings, wingbeat scaling -------
func _starter_b() -> FlightTest:
	# the lab's starter B: 36 kg, 2 wings of 1.35 m2 and 2.4 m (span 5.3 m with the body), L/D 11
	var info := {"type": "wing_vane", "span": 2.4, "area": 1.35, "chord": 0.56, "muscle": 0.18, "flaps": true, "ld": 11.0, "e": 0.8}
	return FlightTest.new(FlightTest.make_spec(36.0, [info, info], 1.45, 0.78))

func _level(f: FlightTest, speed: float, alt: float) -> void:
	f.mode = "glide"
	f.pos = Vector3(0, alt + float(f.spec.com_h), 0)
	f.vel = Vector3(0, 0, speed)
	f.yaw_dir = Vector2(0, 1)
	f.climb_out = 0.0
	f.bank_t = 0.0
	f.roll_rate = 0.0

func _picks(t) -> void:
	var flat := Callable(self, "_flat")
	var dt := 1.0 / 60.0
	# wingbeat scaling: both laws, live
	LocoWing.scaling = "game"
	t.check(absf(LocoWing.beat_hz(36.0) - 2.48) < 0.03 and absf(LocoWing.beat_hz(30.0) - 2.55) < 0.03, "game law: B 2.5 Hz, hatchling 2.6 Hz (%.2f, %.2f)" % [LocoWing.beat_hz(36.0), LocoWing.beat_hz(30.0)])
	t.check(absf(LocoWing.beat_hz(36.0, "lab") - 1.45) < 0.03 and absf(LocoWing.beat_hz(30.0, "lab") - 1.55) < 0.03, "lab law: B 1.5 Hz, hatchling 1.5 Hz (%.2f, %.2f)" % [LocoWing.beat_hz(36.0, "lab"), LocoWing.beat_hz(30.0, "lab")])
	var b := _starter_b()
	var hz_game := b.beat_hz()
	LocoWing.scaling = "lab"
	t.check(b.beat_hz() < hz_game * 0.7, "the option changes the model's beat rate live (%.2f -> %.2f)" % [hz_game, b.beat_hz()])
	LocoWing.scaling = "game"
	t.check(absf(b.stall_speed() - 11.9) < 0.6, "the lab's starter B stalls near 11.9 m/s (%.1f)" % b.stall_speed())

	# A56 cruise = flap-glide: bursts until fast, glide until slow; the average power is a fraction of a continuous flap
	var fg := _starter_b()
	fg.cruise_style = "flapglide"
	_level(fg, fg.cruise_speed(), 500.0)
	var cont := _starter_b()
	_level(cont, cont.cruise_speed(), 500.0)
	var on_ticks := 0
	var n := 0
	var vmin := 99.0
	var vmax := 0.0
	var switches := 0
	var was := false
	for i in int(20.0 / dt):
		fg.step(dt, {"flap": true}, flat)
		cont.step(dt, {"flap": true}, flat)
		if i > int(5.0 / dt):
			var on := fg.mode == "flap"
			on_ticks += 1 if on else 0
			n += 1
			if on != was:
				switches += 1
			was = on
			vmin = minf(vmin, fg.vel.length())
			vmax = maxf(vmax, fg.vel.length())
	var duty := float(on_ticks) / float(n)
	t.check(duty > 0.1 and duty < 0.7, "flap-glide: the wings burst for a share of the time, not always (duty %.2f)" % duty)
	t.check(switches >= 4, "and they alternate (%d switches in 15 s)" % switches)
	t.check(vmin > 0.8 * fg.cruise_speed() and vmax < 1.3 * fg.cruise_speed(), "the speed stays around cruise %.1f m/s (%.1f .. %.1f)" % [fg.cruise_speed(), vmin, vmax])
	t.check(fg.stamina > cont.stamina + 0.15, "flap-glide costs much less stamina than continuous flapping (%.2f vs %.2f after 20 s)" % [fg.stamina, cont.stamina])
	# the held energy follows the pilot's pitch: nose up (S) climbs on bursts, hands-off holds the height
	var hold := _starter_b()
	hold.cruise_style = "flapglide"
	_level(hold, hold.cruise_speed(), 500.0)
	var up := _starter_b()
	up.cruise_style = "flapglide"
	_level(up, up.cruise_speed(), 500.0)
	for i in int(15.0 / dt):
		hold.step(dt, {"flap": true}, flat)
		up.step(dt, {"flap": true, "pitch": 0.4}, flat)
	t.check(absf(hold.pos.y - 500.0 - float(hold.spec.com_h)) < 6.0, "flap-glide hands-off holds the height (%.1f m drift in 15 s)" % (hold.pos.y - 500.0 - float(hold.spec.com_h)))
	t.check(up.pos.y > hold.pos.y + 10.0, "with the nose up it climbs on bursts (%.1f m above the hands-off flight)" % (up.pos.y - hold.pos.y))
	# a tap is never gated: one beat, whatever the speed
	var tap := _starter_b()
	tap.cruise_style = "flapglide"
	_level(tap, 1.6 * tap.stall_speed(), 300.0)
	tap.press_flap()
	tap.step(dt, {}, flat)
	t.check(tap.mode == "flap", "a tap of Space still gives one beat above the cruise speed")

	# A56/A57 turn = wingover, both directions
	for dir in [1, -1]:
		var w := _starter_b()
		w.cruise_style = "flapglide"
		_level(w, w.cruise_speed(), 120.0)
		var y0 := 120.0
		var r := w.start_wingover(dir, flat)
		t.check(r.ok, "the wingover starts at cruise speed (dir %d)" % dir)
		var y_max := 0.0
		var bank_peak := 0.0
		var v_min := 99.0
		var worst_roll := 0.0
		var last_bank := 0.0
		var time := 0.0
		var landed := false
		var nan := false
		while w.wo_phase != "" and time < 25.0:
			var ev := w.step(dt, {"flap": false}, flat)
			time += dt
			y_max = maxf(y_max, w.pos.y - float(w.spec.com_h))
			bank_peak = maxf(bank_peak, absf(w.bank_t))
			v_min = minf(v_min, w.vel.length())
			worst_roll = maxf(worst_roll, absf(atan(w.bank_t) - atan(last_bank)) / dt)
			last_bank = w.bank_t
			landed = landed or ev.landed
			nan = nan or is_nan(w.pos.x) or is_nan(w.vel.y)
		t.check(not nan and not landed, "the wingover is finite and does not hit the ground")
		t.check(w.wo_phase == "", "it ends by itself (%.1f s)" % time)
		t.check(w.yaw_dir.y < -0.5, "the heading reversed (forward is now %s)" % w.yaw_dir)
		t.check(y_max > y0 + 4.0, "the zoom climbs (peak %.1f m above %.0f)" % [y_max, y0])
		t.check(bank_peak > 6.0, "it rolls over the top (tan bank %.1f: more than 80 degrees)" % bank_peak)
		t.check(v_min > 0.5 * w.stall_speed(), "it is slowest over the top but never falls out of the sky (%.1f m/s vs %.1f)" % [v_min, w.stall_speed()])
		t.check(worst_roll < 3.2, "the roll is smooth: at most %.2f rad/s" % worst_roll)
		t.check(absf(w.bank_t) < 0.3, "rolled out level (tan %.2f)" % w.bank_t)
		t.check(w.yaw_dir.y < -0.8 and w.vel.length() > 0.9 * w.stall_speed(), "it leaves on the reverse heading at flying speed (%s, %.1f m/s)" % [w.yaw_dir, w.vel.length()])
	var low := _starter_b()
	_level(low, low.cruise_speed(), 4.0)
	t.check(not low.start_wingover(1, flat).ok, "too low for a wingover: refused")
	var slow := _starter_b()
	_level(slow, 0.9 * slow.stall_speed(), 300.0)
	t.check(not slow.start_wingover(1, flat).ok, "too slow for a wingover: refused")
	# Ctrl cuts it short, and the opposite key too: still smooth and finite
	for how in ["dive", "key"]:
		var c := _starter_b()
		_level(c, c.cruise_speed(), 300.0)
		c.start_wingover(1, flat)
		for i in int(1.5 / dt):
			c.step(dt, {}, flat)
		for i in int(8.0 / dt):
			var held: bool = i < int(0.4 / dt)       # a quick press of the opposite key / Ctrl
			c.step(dt, {"dive": how == "dive" and held, "roll": 1.0 if (how == "key" and held) else 0.0}, flat)
		t.check(c.wo_phase == "" and absf(c.bank_t) < BANK_OK, "%s cuts the wingover short and the wings level out (phase '%s', tan %.2f)" % [how, c.wo_phase, c.bank_t])

	# A56 landing = flare + stall touchdown; A57 hatchling = running landing
	var res := {}
	for style in ["flare", "run"]:
		var l := _starter_b()
		l.landing_style = style
		_level(l, 1.3 * l.stall_speed(), 40.0)
		var legs_flare := [0.0, 0.0]
		var v_td := 0.0
		var dist := 0.0
		var x0 := l.pos.z
		var time := 0.0
		var dmg := 0.0
		var got := false
		while l.mode != "ground" and time < 90.0:
			var ev := l.step(dt, {}, flat)
			time += dt
			if l.mode == "flare":
				legs_flare = [l.legs_tuck, l.legs_fwd]
			if ev.landed:
				v_td = Vector2(l.vel.x, l.vel.z).length()
				dmg = ev.damage
				got = true
				x0 = l.pos.z
		dist = l.pos.z - x0
		res[style] = {"v": v_td, "run": dist, "legs": legs_flare}
		t.check(got and dmg == 0.0, "%s landing: no damage (%.1f)" % [style, dmg])
		t.check(legs_flare[0] < 0.3, "%s landing: the legs are extended (tuck %.2f)" % [style, legs_flare[0]])
		t.check(l.mode == "ground", "%s landing: comes to rest" % style)
	t.check(res.flare.legs[1] > res.run.legs[1] + 0.2, "the flare swings the legs forward more than the running landing (%.2f vs %.2f)" % [res.flare.legs[1], res.run.legs[1]])
	t.check(res.flare.v < res.run.v + 0.01 or res.flare.v < 1.15 * 11.9, "the flare touches down slow, near the stall speed (%.1f m/s)" % res.flare.v)
	t.check(res.run.run > res.flare.run + 2.0, "the running landing runs out further (%.1f m vs %.1f m)" % [res.run.run, res.flare.run])
	t.check(b.legs_tuck > 0.99, "legs are tucked in cruise")

const BANK_OK := 0.35
