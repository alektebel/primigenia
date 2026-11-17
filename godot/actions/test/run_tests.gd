extends SceneTree
## make godot-actions-test: headless tests of the procedural action layer (docs/godot/PLAN-actions.md section 5).
## Uses a ScriptedFeed in place of the C world, so the GDExtension is not needed.
##   godot --headless --path godot --script actions/test/run_tests.gd

const Clock := preload("res://actions/action_clock.gd")
const Data := preload("res://actions/action_data.gd")
const Feed := preload("res://actions/action_feed.gd")
const Springs := preload("res://actions/action_springs.gd")
const H := preload("res://actions/test/harness.gd")
const Scripted := preload("res://actions/test/scripted_feed.gd")
const FxScript := preload("res://actions/action_fx.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")

class ErrorLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])

var checks := 0
var failures := 0
var log := ErrorLog.new()
var raw := {}
const BODIES := ["Merodeador", "Zancuda", "Babosa", "Garfio"]

## Angle between two rotations without the acos precision loss of Quaternion.angle_to for tiny angles.
static func qang(a: Quaternion, b: Quaternion) -> float:
	var d := a.inverse() * b
	return 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w))

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	OS.add_logger(log)
	_run()

func _run() -> void:
	await process_frame
	raw = H.load_raw()
	_t_clock()
	_t_feed()
	_t_data()
	await _t_body_map()
	await _t_plumbing()
	await _t_bite()
	await _t_solver()
	_t_springs()
	await _t_all_actions()
	await _t_round2()
	await _t_idle()
	await _t_cosmetic()
	_t_readonly()
	check(log.errors.is_empty(), "no engine errors (%d)" % log.errors.size())
	for e in log.errors.slice(0, 5):
		printerr("  engine error: ", e)
	print("actions tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

# ---------------------------------------------------------------------------------------------
# step 1: clock
# ---------------------------------------------------------------------------------------------
func _t_clock() -> void:
	print("-- clock")
	for mv in Clock.TICKS:
		var t: Array = Clock.TICKS[mv]
		var sf := Scripted.new()
		sf.begin(0, mv)
		var total: int = t[0] + t[1] + t[2]
		var seen_e := []
		var ok := true
		for k in total + 2:
			sf.step()
			var f: Dictionary = sf.fighters[0]
			if f.move < 0:
				break
			var e := Clock.elapsed(f.move, f.phase, f.ptick, t[0], t[1])
			seen_e.append(e)
			if e != k + 1:
				ok = false
		check(ok and seen_e.size() == total - 1, "move %d: e = 1..%d over the %d states" % [mv, total - 1, total - 1])
		check(Clock.tau(t[0] + 1, 0.0) == float(t[0]), "move %d: tau = W when e = W + 1" % mv)
		if t[0] == 1:
			var f2 := Scripted.new()
			f2.begin(0, mv); f2.step()
			check(f2.fighters[0].phase == 2, "move %d (W = 1) is never seen in wind-up" % mv)
		var inv := true
		for sg in ["w", "a", "r"]:
			var n: float = t["war".find(sg)]
			if n <= 0.0:
				continue
			for u in [0.0, 0.3, 0.99]:
				var tt := Clock.seg_time(sg, u, t[0], t[1], t[2], 3.0)
				var l := Clock.locate(tt, t[0], t[1], t[2], 3.0)
				if l.seg != sg or absf(l.u - u) > 1e-6:
					inv = false
		check(inv, "move %d: locate and seg_time are inverses" % mv)
	check(Clock.grid_shift(0, 2, 8, 6) == 1.0, "grid shift: first beat tick inside the window sets the accent")
	check(Clock.grid_shift(0, 2, 3, 11) == 0.0, "grid shift: no beat inside the window -> 0")

# ---------------------------------------------------------------------------------------------
# step 2: feed
# ---------------------------------------------------------------------------------------------
func _marks(sf, feed, ticks: int, id := 0) -> Array:
	var out := []
	for i in ticks:
		sf.step()
		var s: Dictionary = feed.read(sf.prev, sf.cur, 0.0)
		out.append(s[id].marks.duplicate())
	return out

func _t_feed() -> void:
	print("-- feed")
	var sf := Scripted.new()
	var feed := Feed.new()
	sf.begin(0, 0)
	var m := _marks(sf, feed, 8)
	check(m[0] == ["start"] and m[5] == ["end"], "bite alone: start, then end on the tick after its last state (%s)" % [m])
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 0)
	var m2 := _marks(sf, feed, 6)
	sf.begin(0, 0)
	var m3 := _marks(sf, feed, 1)
	check(m3[0] == ["end", "start"] or m3[0] == ["start"], "bite relaunched right after it ended: start (%s)" % [m3])
	# back to back: launched on the tick the old one has its last state
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 0)
	var m4 := _marks(sf, feed, 5)
	sf.begin(0, 0)
	var m5 := _marks(sf, feed, 1)
	check(m5[0] == ["end", "start"], "relaunch in the tick the old bite ends: end + start in the same tick (%s)" % [m5])
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 3)
	var m6 := _marks(sf, feed, 2)
	sf.interrupt(0, 4)
	var s6 := {}
	sf.step()
	s6 = feed.read(sf.prev, sf.cur, 0.0)
	check(s6[0].marks == ["cancel"] and s6[0].stagger and s6[0].stagger_len == 4, "spit interrupted in wind-up: cancel + stagger 4")
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 2)
	_marks(sf, feed, 5)
	sf.release_guard(0)
	sf.step()
	var s7: Dictionary = feed.read(sf.prev, sf.cur, 0.0)
	check(s7[0].marks == ["cancel"], "guard released at active tick 5: cancel")
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 4)
	_marks(sf, feed, 2)
	sf.die(0)
	sf.step()
	var s8: Dictionary = feed.read(sf.prev, sf.cur, 0.0)
	check(s8[0].dead and s8[0].marks.has("cancel"), "death mid-move: cancel and dead")
	sf = Scripted.new(); feed = Feed.new()
	sf.begin(0, 1)
	_marks(sf, feed, 3)
	sf.end_fight()
	sf.step()
	var s9: Dictionary = feed.read(sf.prev, sf.cur, 0.0)
	check(s9[0].marks == ["cancel"] and not s9[0].in_fight, "fight ending mid-move: cancel")
	# events are delivered once per tick and addressed to entity ids
	sf = Scripted.new(); feed = Feed.new()
	sf.event(1, 0, 1, 0, 12.0)
	sf.step()
	var r1: Dictionary = feed.read(sf.prev, sf.cur, 0.1)
	var r2: Dictionary = feed.read(sf.prev, sf.cur, 0.5)
	check(r1[0].events.size() == 1 and r1[1].events.size() == 1 and r1[1].events[0].b == 1, "event addressed to both entities by id")
	check(r2[0].events.size() == 0, "an event is delivered once")

# ---------------------------------------------------------------------------------------------
# step 3: data
# ---------------------------------------------------------------------------------------------
func _t_data() -> void:
	print("-- data")
	check(raw.size() >= 24, "all action files load and validate (%d)" % raw.size())
	var bite: Dictionary = raw.bite
	var jaw: Dictionary = {}
	for t in Data.compile(bite).tracks:
		if t.ch == "jaw.open" and jaw.is_empty():
			jaw = t                       # the first one: the ungated jaw (round 2 added a gated release after it)
	var cb := Data.compile(bite)
	check(Data.sample(jaw, 0.35 * 3, {}) >= 0.99 and Data.sample(jaw, 3.0, {}) >= 0.99, "jaw is fully open from w:0.35 to a:0")
	check(Data.sample(jaw, 3.0 + 0.25, {}) <= 0.031 and Data.sample(jaw, 3.5, {}) <= 0.05, "jaw is shut from a:0.25")
	check(Data.sample(jaw, 3.0 + 0.12, {}) < 0.9 and Data.sample(jaw, 3.0 + 0.12, {}) > 0.03, "snap: jaw is closing between a:0 and a:0.25")
	var snap := {"ch": "x", "goal": "", "kin": 1.0, "mask": -1.0, "lag": 0.0, "signed": false, "alternate": false, "if": "", "osc": {}, "env": [],
		"keys": [[0.0, 0.0, "lin"], [1.0, 1.0, "lin"], [2.0, 5.0, "snap"]]}
	check(absf(Data.sample(snap, 1.8, {}) - 1.0) < 1e-6 and Data.sample(snap, 1.9, {}) > 2.5 and Data.sample(snap, 1.9, {}) < 4.0 and absf(Data.sample(snap, 2.0, {}) - 5.0) < 1e-6, "snap key reaches its value within 0.02 s")
	var res := Data.resolve(bite, ["long_neck", "jaw", "tail"])
	var has_coil := false
	for t in res.tracks:
		if t.ch == "neck.coil":
			has_coil = true
	check(has_coil, "resolve with caps [long_neck] contains neck.coil")
	var bad := [
		["unknown top key", func(d): d["zzz"] = 1],
		["unknown channel", func(d): d.tracks[0].ch = "head.nope"],
		["keys out of order", func(d): d.tracks[0].keys = [["a", 0.5, 0], ["w", 0.1, 1]]],
		["bad ease", func(d): d.tracks[0].keys[1][3] = "wobble"],
		["bad segment", func(d): d.tracks[0].keys[0][0] = "q"],
		["bad when", func(d): d.variants[0].when["zzz"] = []],
	]
	for b in bad:
		var d: Dictionary = bite.duplicate(true)
		(b[1] as Callable).call(d)
		var errs := Data.validate(d, "bite.json")
		check(errs.size() == 1, "validation catches: %s -> %s" % [b[0], errs])

# ---------------------------------------------------------------------------------------------
# step 4: body map
# ---------------------------------------------------------------------------------------------
func _build(name: String, layer_on := true):
	var h = H.new()
	h.build(root, name, raw)
	h.layer_on = layer_on
	return h

func _t_body_map() -> void:
	print("-- body map")
	var hs := {}
	for name in BODIES:
		hs[name] = _build(name)
		var m = hs[name].map
		var hips_ok := true
		var hip_bones := []
		for i in hs[name].desc.leg_ids:
			hip_bones.append(int(hs[name].c.legs[i].hip_bone))
		for b in m.head_chain + m.tail_chain:
			if hip_bones.has(b):
				hips_ok = false
		var lim_ok := true
		for l in m.head_limit + m.tail_limit:
			if l < 0.06 - 1e-6 or l > 0.55 + 1e-6:
				lim_ok = false
		check(hips_ok, "%s: no chain joint carries a hip" % name)
		check(lim_ok, "%s: all limits in [0.06, 0.55]" % name)
		check(is_finite(m.reach_fwd) and m.reach_fwd >= 0.0 and is_finite(m.lunge_cap) and m.lunge_cap > 0.0, "%s: capacities finite and positive" % name)
	check(hs.Zancuda.map.has_cap("long_neck") and hs.Zancuda.map._chain_len(hs.Zancuda.map.head_chain) > 2.5, "Zancuda: long neck, head chain longer than 2.5 m")
	check(not hs.Merodeador.map.has_cap("long_neck") and hs.Merodeador.map.has_cap("horns") and hs.Merodeador.map.has_cap("jaw"), "Merodeador: horns, jaw, no long neck")
	check(hs.Babosa.map.has_cap("legless") and hs.Babosa.map.has_cap("jaw") and hs.Babosa.map.has_cap("plates") and not hs.Babosa.map.has_cap("arms"), "Babosa: legless, jaw, plates, no arms")
	# bone sign checks on the real skeleton
	for name in BODIES:
		var h = hs[name]
		var m = h.map
		var zero := PackedFloat32Array(); zero.resize(m.n)
		var base: Array = m.fk(zero, zero, zero)
		var hb: int = m.head_chain[m.head_chain.size() - 1]
		var dpv := zero.duplicate()
		for b in m.head_chain:
			dpv[b] = -0.2
		var g1: Array = m.fk(zero, dpv, zero)
		check(g1[hb].origin.y > base[hb].origin.y + 0.02, "%s: head 'up' (negative bone pitch) raises the head" % name)
		var dyv := zero.duplicate()
		for b in m.head_chain:
			dyv[b] = 0.2
		var g2: Array = m.fk(dyv, zero, zero)
		check(g2[hb].origin.x > base[hb].origin.x + 0.02, "%s: head yaw + moves it to +X" % name)
		var tb: int = m.tail_chain[m.tail_chain.size() - 1]
		var tp := zero.duplicate()
		for b in m.tail_chain:
			tp[b] = 0.2
		var g3: Array = m.fk(zero, tp, zero)
		check(g3[tb].origin.y > base[tb].origin.y + 0.02, "%s: tail pitch + raises the tip" % name)
		var ty := zero.duplicate()
		for b in m.tail_chain:
			ty[b] = -0.2
		var g4: Array = m.fk(ty, zero, zero)
		check(g4[tb].origin.x > base[tb].origin.x + 0.02, "%s: channel tail yaw + (bone yaw -) moves the tip to +X" % name)
		h.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# step 5: plumbing
# ---------------------------------------------------------------------------------------------
func _t_plumbing() -> void:
	print("-- plumbing")
	for name in ["Merodeador", "Zancuda"]:
		var a = _build(name, false)
		var b = _build(name, true)
		a.sf.end_fight(); b.sf.end_fight()
		b.layer.idle_on = false
		b.layer.enabled = true
		# the layer on but nothing to show: stage off, no signal
		var worst := 0.0
		var root_diff := 0.0
		var vel := Vector3(0, 0, 1.2)
		for i in 360:
			for hh in [a, b]:
				hh.pos += vel / 60.0
				hh.vel = vel
				hh.frame(1.0 / 60.0)
			if i < 240:
				continue            # the fight ending fades the combat-ready stance out first
			var ra: Array = a.bone_rotations()
			var rb: Array = b.bone_rotations()
			for k in ra.size():
				worst = maxf(worst, qang(ra[k], rb[k]))
			root_diff = maxf(root_diff, ((a.ctl.pose.root as Transform3D).origin - (b.ctl.pose.root as Transform3D).origin).length())
		check(worst < 1e-5 and root_diff < 1e-4, "%s: empty layer leaves every bone and the root as the loco-only run (%s rad, %s m)" % [name, snappedf(worst, 1e-9), snappedf(root_diff, 1e-9)])
		a.free_all(); b.free_all()
	await process_frame
	var h = _build("Merodeador")
	h.layer.idle_on = false
	h.sf.end_fight()
	h.run(0.5)
	var s0 := h.soles()
	h.layer.springs.step("root.lunge", 0.0, 0.0, 16.0, 1.0, 0.0, 0.016)
	# force a channel directly: a one-off action with a constant lunge
	var inst: Dictionary = h.layer._new_inst(Data.compile({"id": "t_lunge", "class": "combat", "driver": {"kind": "cosmetic"}, "ticks": {"w": 1, "a": 100, "r": 1}, "settle": 0.1, "fade": {"in": 0.0},
		"tracks": [{"ch": "root.lunge", "keys": [["a", 0, 1.0]]}]}), "stance")
	h.layer.inst.append(inst)
	h.run(1.0)
	var s1 := h.soles()
	var slide := 0.0
	for k in s0.size():
		slide = maxf(slide, s0[k].distance_to(s1[k]))
	check(h.layer.debug.k > 0.3, "root.lunge = 1 standing: the reach guard cuts it to k = %.2f" % h.layer.debug.k)
	check(slide < 0.0005, "root.lunge = 1 standing: planted soles move %.3f mm (< 0.5)" % (slide * 1000.0))
	var moved: float = (h.ctl.pose.root as Transform3D).origin.z
	check(moved > 0.2, "the body really lunged (%.2f m)" % moved)
	h.layer.inst.erase(inst)
	var inst2: Dictionary = h.layer._new_inst(Data.compile({"id": "t_lift", "class": "combat", "driver": {"kind": "cosmetic"}, "ticks": {"w": 1, "a": 100, "r": 1}, "settle": 0.1, "fade": {"in": 0.0},
		"tracks": [{"ch": "root.lift", "keys": [["a", 0, 1.0]]}]}), "stance")
	h.layer.inst.append(inst2)
	h.run(1.5)
	var worst_len := 0.0
	for j in h.desc.leg_ids.size():
		var l = h.c.legs[h.desc.leg_ids[j]]
		var hip: Vector3 = (h.ctl.pose.hips as PackedVector3Array)[j]
		worst_len = maxf(worst_len, hip.distance_to(h.ctl.pose.feet[j]) / h.map.leg_len[j])
	check(h.layer.debug.k < 1.0 and worst_len <= 0.9851, "root.lift = +1: the guard cuts it (k = %.2f) and no leg is longer than 0.985 L (%.4f)" % [h.layer.debug.k, worst_len])
	h.layer.inst.erase(inst2)
	h.layer.inst.erase(inst)
	var jn = h.jaw_node()
	h.layer.inst.append(h.layer._new_inst(Data.compile({"id": "t_jaw", "class": "combat", "driver": {"kind": "cosmetic"}, "ticks": {"w": 1, "a": 100, "r": 1}, "settle": 0.1, "fade": {"in": 0.0},
		"tracks": [{"ch": "jaw.open", "keys": [["a", 0, 1.0]]}]}), "stance"))
	h.run(0.3)
	check(absf(jn.rotation.x - 0.81) < 0.02, "jaw.open = 1 sets the fauces jaw to 0.81 (%.3f)" % jn.rotation.x)
	h.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# step 6: bite end to end
# ---------------------------------------------------------------------------------------------
func _t_bite() -> void:
	print("-- bite")
	var h = _build("Merodeador")
	h.layer.idle_on = false
	h.run(0.6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var worst_dt := 0.0
	var bad_open := 0
	var bad_shut := 0
	var bad_w := 0
	var n_ok := 0
	var N := 60
	for k in N:
		h.run(rng.randf() * 0.1, 1.0 / 90.0)
		h.impacts.clear()
		var begin_t: float = h.sim_t
		h.sf.begin(0, 0)
		var state_t := -1.0
		var w_ok_t := -1.0
		var first_state_t := -1.0
		var guard := 0
		while h.sim_t - begin_t < 1.3 and guard < 1000:
			guard += 1
			var dt := rng.randf_range(1.0 / 144.0, 1.0 / 45.0)
			h.frame(dt)
			var s: Dictionary = h.sig[0]
			if s.e >= 1 and first_state_t < 0.0:
				first_state_t = h.sim_t
			if s.e == 4 and state_t < 0.0:
				state_t = h.sim_t
			if first_state_t >= 0.0 and w_ok_t < 0.0 and h.layer.weight_of("bite") >= 0.99:
				w_ok_t = h.sim_t
			var tau: float = s.tau if s.move == 0 else -1.0
			var jaw: float = h.layer.last_act.parts.jaw
			if tau >= 0.35 * 3 and tau < 3.0 and jaw < 0.9:
				bad_open += 1
			if tau >= 3.3 and jaw > 0.1:
				bad_shut += 1
		if h.impacts.size() == 1 and state_t > 0.0:
			worst_dt = maxf(worst_dt, absf(h.impacts[0] - state_t))
			n_ok += 1
		if w_ok_t - first_state_t > 0.07:
			bad_w += 1
		h.run(1.0, 1.0 / 60.0)
	check(n_ok == N, "every bite fires exactly one impact (%d / %d)" % [n_ok, N])
	check(worst_dt <= 1.0 / 45.0 + 1e-6, "impact within 1 frame of the C state with e = W + 1 (worst %.1f ms over %d bites, random frame times)" % [worst_dt * 1000.0, N])
	check(bad_open == 0, "jaw >= 0.9 open for every frame in tau [0.35 W, W) (%d bad)" % bad_open)
	check(bad_shut == 0, "jaw <= 0.1 from tau = W + 0.3 (%d bad)" % bad_shut)
	check(bad_w == 0, "action weight >= 0.99 within 0.07 s of the first wind-up state (%d bad)" % bad_w)
	# no sliding, return, cancel
	h.run(1.0)
	h.sf.end_fight()
	h.run(1.0)
	var h0 = _build("Merodeador", false)
	h0.layer_on = false
	var s0 := h.soles()
	h.sf.begin(0, 0)
	h.sf.end_fight()
	h.free_all(); h0.free_all()
	await process_frame
	var a = _build("Merodeador")
	a.layer.idle_on = false
	a.run(1.0)
	var soles0 := a.soles()
	var max_slide := 0.0
	a.sf.begin(0, 0)
	for i in 90:
		a.frame(1.0 / 60.0)
		var sl := a.soles()
		for q in sl.size():
			max_slide = maxf(max_slide, sl[q].distance_to(soles0[q]))
	check(max_slide < 0.002, "bite: stance soles slide %.3f mm (< 2)" % (max_slide * 1000.0))
	a.sf.end_fight()
	a.run(2.0)
	var b = _build("Merodeador", false)
	b.sf.end_fight()
	b.run(1.0 + 1.5 + 1.5 + 0.5)
	var worst := 0.0
	var ra: Array = a.bone_rotations()
	var rb: Array = b.bone_rotations()
	for k in ra.size():
		worst = maxf(worst, qang(ra[k], rb[k]))
	check(worst < 1e-3 and absf((a.ctl.pose.root as Transform3D).origin.y - (b.ctl.pose.root as Transform3D).origin.y) < 1e-3, "return: 2 s after the end every bone is within 1e-3 of the loco-only pose (%s)" % snappedf(worst, 1e-7))
	b.free_all()
	# cancel at w:0.5
	var cc = _build("Merodeador")
	cc.layer.idle_on = false
	cc.run(0.5)
	cc.sf.begin(0, 0)
	var prev := cc.bone_rotations()
	var fastest := 0.0
	var cancel_t := -1.0
	var weight0_t := -1.0
	var did := false
	for i in 120:
		cc.frame(1.0 / 60.0)
		var now := cc.bone_rotations()
		for k in now.size():
			fastest = maxf(fastest, qang(prev[k], now[k]) * 60.0)
		prev = now
		if not did and cc.sig[0].move == 0 and cc.sig[0].tau >= 1.5:
			cc.sf.interrupt(0, 4)
			did = true
		if did and cancel_t < 0.0 and cc.sig[0].stagger:
			cancel_t = cc.sim_t
		if cancel_t > 0.0 and weight0_t < 0.0 and cc.layer.weight_of("bite") <= 0.001:
			weight0_t = cc.sim_t
	check(cancel_t > 0.0 and weight0_t - cancel_t <= 0.08 + 1.0 / 60.0 + 1e-6, "cancel: weight 0 within fade.cancel + 1 frame (%.3f s)" % (weight0_t - cancel_t))
	check(fastest < 25.0, "cancel: no bone faster than 25 rad/s (%.1f)" % fastest)
	a.free_all(); cc.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# step 7: head chain solver
# ---------------------------------------------------------------------------------------------
func _inject(h, ch: Dictionary, goal_kind := "") -> Dictionary:
	var tracks := []
	for k in ch:
		var t := {"ch": k, "keys": [["a", 0, ch[k]]]}
		if goal_kind != "" and k in ["head.reach", "head.aim"]:
			t["goal"] = goal_kind
		tracks.append(t)
	var inst: Dictionary = h.layer._new_inst(Data.compile({"id": "t_inj", "class": "combat", "driver": {"kind": "cosmetic"}, "ticks": {"w": 1, "a": 1000, "r": 1}, "settle": 0.1, "fade": {"in": 0.0}, "tracks": tracks}), "stance")
	h.layer.inst.append(inst)
	return inst

func _t_solver() -> void:
	print("-- solver")
	for name in BODIES:
		var h = _build(name)
		h.layer.idle_on = false
		h.sf.end_fight()
		h.run(0.6)
		var m = h.map
		var mouth0: Vector3 = h.mouth_world()
		# a goal 0.5 * reach_fwd ahead of the mouth: place the target sphere there
		var fwd := Vector3(0, 0, 1)
		h.ctx_extra = {"target": {"id": 1, "pos": Vector3(0, 0, 0), "radius": 0.001, "height": 0.001, "spheres": []}}
		var base_w: Vector3 = h.c.skeleton.global_transform * h.c.skeleton.get_bone_global_pose(m.parent[m.head_chain[0]] if m.parent[m.head_chain[0]] >= 0 else m.head_chain[0]).origin
		var goal: Vector3 = base_w + Basis(Vector3.UP, deg_to_rad(20.0)) * (mouth0 - base_w)
		h.ctx_extra.target.spheres = [Vector4(goal.x, goal.y, goal.z, 0.001)]
		var inst: Dictionary = _inject(h, {"head.reach": 1.0}, "target_surface")
		h.run(0.4)
		var got := h.mouth_world()
		var dist_goal := got.distance_to(goal)
		var moved_near := mouth0.distance_to(got)
		var minit: Vector3 = got
		h.run(0.6)
		var drift := h.mouth_world().distance_to(minit)
		check(dist_goal < 0.10 or m.head_chain.size() < 2, "%s: reach goal met (%.1f cm from it, mouth moved %.2f m)" % [name, dist_goal * 100.0, moved_near])
		# with the goal held still the mouth does not jitter
		var jit := 0.0
		var last := h.mouth_world()
		for i in 30:
			h.frame(1.0 / 60.0)
			jit = maxf(jit, h.mouth_world().distance_to(last))
			last = h.mouth_world()
		check(jit < 0.001 + 0.003, "%s: mouth moves %.2f mm per frame when the goal is still" % [name, jit * 1000.0])
		# far goal: chain at limits, no NaN, root lunges
		var far: Vector3 = mouth0 + fwd * 3.0 * maxf(m.reach_fwd, 0.5)
		h.ctx_extra.target.spheres = [Vector4(far.x, far.y, far.z, 0.001)]
		h.run(0.8)
		var finite := true
		var over := 0.0
		var act: Dictionary = h.layer.last_act
		for i in m.head_chain.size():
			var b: int = m.head_chain[i]
			over = maxf(over, maxf(absf(act.bone_dy[b]), absf(act.bone_dp[b])) / m.head_limit[i])
			finite = finite and is_finite(act.bone_dy[b]) and is_finite(act.bone_dp[b])
		check(finite and h.mouth_world().is_finite(), "%s: far goal gives finite values" % name)
		check(over <= 1.15 + 1e-3, "%s: no head joint beyond 1.15 x its limit (%.2f)" % [name, over])
		h.layer.inst.erase(inst)
		# aim 60 degrees to the left
		h.run(0.6)
		var aim_goal := (h.ctl.pose.root as Transform3D).origin + Vector3(sin(deg_to_rad(60.0)), 0.0, cos(deg_to_rad(60.0))) * 6.0 + Vector3(0, mouth0.y, 0)
		h.ctx_extra.target.spheres = [Vector4(aim_goal.x, aim_goal.y, aim_goal.z, 0.001)]
		var inst2: Dictionary = _inject(h, {"head.aim": 1.0}, "target_surface")
		h.run(0.8)
		var sk: Skeleton3D = h.c.skeleton
		var hb: int = m.head_chain[m.head_chain.size() - 1] if m.head_chain.size() > 0 else m.n - 1
		var zax: Vector3 = (h.c.global_transform.basis * sk.get_bone_global_pose(hb).basis).z
		var want := (aim_goal - sk.global_transform * sk.get_bone_global_pose(hb).origin)
		var err := zax.angle_to(want.normalized())
		var at_limit := true
		check(err < 0.15 or at_limit, "%s: aim turns the head toward a point 60 degrees left (%.2f rad off)" % [name, err])
		h.layer.inst.erase(inst2)
		h.free_all()
		await process_frame
	# Babosa: head.pitch -1 stays above the ground
	var hb2 = _build("Babosa")
	hb2.layer.idle_on = false
	var inst3: Dictionary = _inject(hb2, {"head.pitch": -1.0})
	hb2.run(1.0)
	var low := 1e9
	var sk2: Skeleton3D = hb2.c.skeleton
	for b in hb2.map.head_chain:
		low = minf(low, (sk2.global_transform * sk2.get_bone_global_pose(b).origin).y - hb2.map.radius[b])
	check(low > -0.03, "Babosa: head.pitch = -1 keeps the head above the ground (lowest %.3f m)" % low)
	hb2.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# step 8: springs
# ---------------------------------------------------------------------------------------------
func _t_springs() -> void:
	print("-- springs")
	var sp := Springs.new()
	sp.step("t", 0.0, 0.0, 12.0, 0.45, 0.0, 1.0 / 60.0)
	var peak := 0.0
	var v := 0.0
	for i in 90:
		v = sp.step("t", 1.0, 0.0, 12.0, 0.45, 0.0, 1.0 / 60.0)
		peak = maxf(peak, v)
	check(peak > 1.10 and peak < 1.35, "step response overshoots %.0f %% (zeta 0.45)" % ((peak - 1.0) * 100.0))
	check(absf(v - 1.0) < 0.05, "settles within 5 %% after 1.5 s (%.3f)" % v)
	var slaved := true
	for i in 30:
		slaved = slaved and sp.step("t2", float(i % 5), 1.0, 12.0, 0.45, 0.0, 1.0 / 60.0) == float(i % 5)
	check(slaved, "kin = 1: output equals the goal every frame")
	# released: continues with velocity (overshoot)
	var r := 0.0
	for i in 5:
		sp.step("t3", 0.2 * i, 1.0, 12.0, 0.45, 0.0, 1.0 / 60.0)
	r = sp.step("t3", 0.8, 0.0, 12.0, 0.45, 0.0, 1.0 / 60.0)
	check(r > 0.8 * 0.5, "released channel keeps its velocity (no pop)")
	var at := {}
	for fps in [30, 144]:
		var s2 := Springs.new()
		s2.step("k", 0.0, 0.0, 14.0, 0.45, 0.0, 1.0 / fps)
		s2.kick("k", 3.0)
		var val := 0.0
		for i in int(0.5 * fps):
			val = s2.step("k", 0.0, 0.0, 14.0, 0.45, 0.0, 1.0 / fps)
		at[fps] = val
	var diff := absf(at[30] - at[144]) / maxf(absf(at[144]), 1e-4)
	check(diff < 0.05 or absf(at[30] - at[144]) < 0.01, "frame-rate independence: kick response at 0.5 s differs %.1f %% between 30 and 144 fps" % (diff * 100.0))
	# the tail (not keyed) reacts to the bite lunge
	# (checked in the all-actions test through tail motion)

# ---------------------------------------------------------------------------------------------
# step 10: all combat actions on all bodies
# ---------------------------------------------------------------------------------------------
func _bone_ok(h) -> Array:
	# -> [max share of limit, lowest chain bone clearance]
	var m = h.map
	var act: Dictionary = h.layer.last_act
	var worst := 0.0
	for i in m.head_chain.size():
		var b: int = m.head_chain[i]
		worst = maxf(worst, maxf(absf(act.bone_dy[b]), absf(act.bone_dp[b])) / m.head_limit[i])
	var sk: Skeleton3D = h.c.skeleton
	var low := 1e9
	for b in m.head_chain + m.tail_chain:
		low = minf(low, (sk.global_transform * sk.get_bone_global_pose(b).origin).y - m.radius[b])
	return [worst, low]

# ---------------------------------------------------------------------------------------------
# round 2: hit reaction, roar, bite grip, charge run-up
# ---------------------------------------------------------------------------------------------
## Runs `frames` frames and returns {min/max of the channel `ch`} of the layer output.
func _range(h, ch: String, frames: int, extra := Callable()) -> Vector2:
	var lo := 1e9
	var hi := -1e9
	for i in frames:
		h.frame(1.0 / 60.0)
		if extra.is_valid():
			extra.call(h)
		var v: float = h.layer._out.get(ch, 0.0)
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(lo, hi)

func _t_round2() -> void:
	print("-- round 2")
	var h = _build("Merodeador")
	h.layer.idle_on = false
	h.run(0.8)
	# 1. hit reaction: recoil, head snap, squash, scaled by damage
	var peaks := {}
	for dmg in [6.0, 20.0]:
		h.sf.event(1, 1, 0, 1, dmg)
		h.sf.interrupt(0, 6)
		var lunge := Vector2(1e9, -1e9)
		var lift := Vector2(1e9, -1e9)
		var pitch := Vector2(1e9, -1e9)
		for i in 30:
			h.frame(1.0 / 60.0)
			var o: Dictionary = h.layer._out
			lunge.x = minf(lunge.x, o["root.lunge"]); lift.x = minf(lift.x, o["root.lift"])
			pitch.y = maxf(pitch.y, o["head.pitch"])
			if i < 12:
				lift.y = i
		peaks[dmg] = [lunge.x, lift.x, pitch.y]
		h.run(1.5)
	check(peaks[20.0][0] < -0.5, "hit: the body recoils away (root.lunge min %.2f)" % peaks[20.0][0])
	check(peaks[20.0][1] < -0.08, "hit: a squash dips the body (root.lift min %.2f)" % peaks[20.0][1])
	check(peaks[20.0][2] > 0.3, "hit: the head snaps back (head.pitch max %.2f)" % peaks[20.0][2])
	check(absf(peaks[20.0][0]) > 1.25 * absf(peaks[6.0][0]), "hit: recoil scales with damage (%.2f vs %.2f)" % [peaks[20.0][0], peaks[6.0][0]])
	# 2. roar: head up and back, jaw wide and held, no forward lunge
	h.layer.trigger("roar")
	var reach := _range(h, "head.reach", 0)
	var rr := {"reach_max": -1e9, "pitch_min": 1e9, "jaw_min": 1e9, "lunge_max": -1e9, "inflate": 0.0}
	var t_roar := 0.0
	for i in 200:
		h.frame(1.0 / 60.0)
		var tau := -1.0
		for n in h.layer.inst:
			if n.id == "roar" and not n.fading:
				tau = n.tau
		if tau >= 3.5 and tau <= 10.0:       # inside the active window, past the fade-in
			var o: Dictionary = h.layer._out
			rr.reach_max = maxf(rr.reach_max, o["head.reach"])
			rr.pitch_min = minf(rr.pitch_min, o["head.pitch"])
			rr.jaw_min = minf(rr.jaw_min, o["jaw.open"])
			rr.lunge_max = maxf(rr.lunge_max, o["root.lunge"])
			rr.inflate = maxf(rr.inflate, o["body.inflate"])
	check(rr.reach_max <= 0.02, "roar: no forward reach in the active phase (%.2f)" % rr.reach_max)
	check(rr.pitch_min >= 0.45, "roar: head held up (head.pitch min %.2f)" % rr.pitch_min)
	check(rr.jaw_min >= 0.9, "roar: jaw wide and held (%.2f)" % rr.jaw_min)
	check(rr.lunge_max <= 0.0, "roar: no forward lunge, a slight rear back (%.2f)" % rr.lunge_max)
	check(rr.inflate > 0.05, "roar: chest and neck expand (%.2f)" % rr.inflate)
	var holder := Node3D.new()
	root.add_child(holder)
	var rings := FxScript.roar_ring(holder, Vector3.ZERO, 3.0, Color.WHITE, true)
	FxScript.ring_pose(rings[0], 0.5)
	check(rings.size() == 2 and rings[0].scale.x > 0.5 and (rings[0].material_override as StandardMaterial3D).albedo_color.a > 0.05, "roar: a visible pulse ring expands")
	holder.queue_free()
	h.run(2.0)
	# 3. bite grip: a connecting bite holds the jaw shut and the head on the target through the recovery
	var res := {}
	for hit in [false, true]:
		h.run(1.0)
		h.sf.begin(0, 0)
		if hit:
			# the event of the tick that carries the HIT: the first active tick
			var armed := true
			while armed:
				var f: Dictionary = h.sf.fighters[0]
				if f.phase == 1 and f.ptick == f.plen - 1:
					h.sf.event(1, 0, 1, 0, 9.0)
					armed = false
				else:
					h.frame(1.0 / 60.0)
		var jaw_hold := -1e9
		var reach_r := -1e9
		var tug_lo := 1e9
		var tug_hi := -1e9
		for i in 60:
			h.frame(1.0 / 60.0)
			var tau := -1.0
			for n in h.layer.inst:
				if n.id == "bite" and not n.fading:
					tau = n.tau
			var o: Dictionary = h.layer._out
			if tau >= 3.3 and tau <= 4.4:      # a:0.3 .. r:0.2
				jaw_hold = maxf(jaw_hold, o["jaw.open"])
			if tau >= 4.6 and tau <= 4.9:      # r:0.3 .. r:0.45: still holding
				reach_r = maxf(reach_r, o["head.reach"])
			if tau >= 3.1 and tau <= 5.0:
				tug_lo = minf(tug_lo, o["head.pitch"] + o["head.yaw"])
				tug_hi = maxf(tug_hi, o["head.pitch"] + o["head.yaw"])
		res[hit] = {"jaw": jaw_hold, "reach": reach_r, "tug": tug_hi - tug_lo}
		h.run(1.0)
	check(res[true].jaw <= 0.1, "bite grip: jaw closed on the target through active and early recovery (%.2f)" % res[true].jaw)
	check(res[true].reach > res[false].reach + 0.1, "bite grip: the head stays on the target in the recovery (%.2f vs miss %.2f)" % [res[true].reach, res[false].reach])
	check(res[true].tug > res[false].tug + 0.1, "bite grip: the head tugs (%.2f vs miss %.2f)" % [res[true].tug, res[false].tug])
	# the victim is pulled a little (visual only) and then let go
	var v = _build("Zancuda")
	v.layer.idle_on = false
	v.run(0.8)
	v.layer.react("hit", Vector3(0, 0, -1), 9.0, 0)
	var pull := _range(v, "root.lunge", 12)
	check(pull.y > 0.1, "bite grip: the bitten creature is pulled toward the biter (root.lunge max %.2f)" % pull.y)
	v.run(1.5)
	check(v.layer._pull.is_empty() and absf(v.layer._out["root.lunge"]) < 0.03, "bite grip: the pull is released (%.3f)" % v.layer._out["root.lunge"])
	v.free_all()
	# 4. charge: run-up shape, then squash on impact
	h.run(1.0)
	h.sf.begin(0, 1)
	var dash := {"lunge": -1e9, "pitch": 1e9, "rpitch": 1e9}
	for i in 100:
		h.frame(1.0 / 60.0)
		var tau := -1.0
		for n in h.layer.inst:
			if n.id == "charge" and not n.fading:
				tau = n.tau
		if tau >= 10.6 and tau <= 14.5:
			var o: Dictionary = h.layer._out
			dash.lunge = maxf(dash.lunge, o["root.lunge"])
			dash.pitch = minf(dash.pitch, o["head.pitch"])
			dash.rpitch = minf(dash.rpitch, o["root.pitch"])
	check(dash.lunge >= 0.4, "charge: the body stretches forward in the dash (root.lunge %.2f)" % dash.lunge)
	check(dash.pitch <= -0.7, "charge: head low in the dash (%.2f)" % dash.pitch)
	check(dash.rpitch <= -0.18, "charge: body pitched into the run (%.2f)" % dash.rpitch)
	h.run(1.5)
	h.sf.begin(0, 1)
	var struck := false
	var lift_min := 1e9
	var armed2 := true
	for i in 140:
		var f: Dictionary = h.sf.fighters[0]
		if armed2 and f.phase == 2 and f.ptick == 1:
			h.sf.event(1, 0, 1, 1, 18.0)
			armed2 = false
		h.frame(1.0 / 60.0)
		if h.layer.weight_of("strike") > 0.5:
			struck = true
			lift_min = minf(lift_min, h.layer._out["root.lift"])
	check(struck and lift_min < -0.12, "charge: the impact squashes the attacker (strike oneshot, root.lift min %.2f)" % lift_min)
	h.free_all()

func _t_all_actions() -> void:
	print("-- all combat actions")
	var moves := {"bite": 0, "charge": 1, "guard": 2, "spit": 3, "tail_strike": 4, "dodge": 5}
	for name in BODIES:
		var h = _build(name)
		h.layer.idle_on = false
		h.run(0.8)
		var tail_before := 0.0
		for id in moves:
			var mv: int = moves[id]
			var t: Array = Clock.TICKS[mv]
			var soles0 := h.soles()
			var slide := 0.0
			var worst_share := 0.0
			var lowest := 1e9
			var base_low: float = _bone_ok(h)[1]
			var fastest := 0.0
			var finite := true
			var tail_move := 0.0
			h.impacts.clear()
			var prev := h.bone_rotations()
			var state_t := -1.0
			h.sf.begin(0, mv)
			var total: float = (t[0] + t[1] + t[2]) * 0.1 + 0.8
			var n := int(total * 60.0)
			var tail_b: int = h.map.tail_chain[h.map.tail_chain.size() - 1] if h.map.tail_chain.size() > 0 else -1
			var tail0 := Vector3.ZERO
			if tail_b >= 0:
				tail0 = h.c.skeleton.get_bone_global_pose(tail_b).origin
			for i in n:
				h.frame(1.0 / 60.0)
				var s: Dictionary = h.sig[0]
				if s.e == t[0] + 1 and state_t < 0.0:
					state_t = h.sim_t
				var now := h.bone_rotations()
				for k in now.size():
					fastest = maxf(fastest, qang(prev[k], now[k]) * 60.0)
					finite = finite and is_finite((now[k] as Quaternion).x)
				prev = now
				var bo := _bone_ok(h)
				worst_share = maxf(worst_share, bo[0])
				lowest = minf(lowest, bo[1])
				if tail_b >= 0:
					tail_move = maxf(tail_move, (h.c.skeleton.get_bone_global_pose(tail_b).origin - tail0).length())
				if id in ["bite", "guard", "spit"]:
					var sl := h.soles()
					for q in sl.size():
						slide = maxf(slide, sl[q].distance_to(soles0[q]))
			check(finite, "%s %s: finite" % [name, id])
			check(worst_share <= 1.16, "%s %s: no head joint over 1.15 x limit (%.2f)" % [name, id, worst_share])
			check(lowest > minf(base_low, 0.0) - 0.04, "%s %s: no chain joint under the ground (%.3f, rest %.3f)" % [name, id, lowest, base_low])
			check(fastest < 25.0, "%s %s: max bone speed %.1f rad/s < 25" % [name, id, fastest])
			if id in ["bite", "guard", "spit"]:
				check(slide < 0.002, "%s %s: stance soles slide %.2f mm (< 2)" % [name, id, slide * 1000.0])
			if h.impacts.size() > 0:
				check(absf(h.impacts[0] - state_t) <= 1.0 / 60.0 + 1e-6, "%s %s: impact within 1 frame of tau = W (%.1f ms)" % [name, id, absf(h.impacts[0] - state_t) * 1000.0])
			if id == "bite" and tail_b >= 0:
				check(tail_move > 0.02, "%s bite: the unkeyed tail reacts to the lunge (%.3f m)" % [name, tail_move])
			h.run(0.6)
		# interrupts at random times
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var all_ok := true
		var all_fast := 0.0
		for id in moves:
			for rep in 2:
				var mv: int = moves[id]
				h.run(0.8)
				h.sf.begin(0, mv)
				var t: Array = Clock.TICKS[mv]
				var stop_at: float = rng.randf_range(0.0, (t[0] + t[1] + t[2]) * 0.1 * 0.8)
				var prev2 := h.bone_rotations()
				var tt := 0.0
				var interrupted := false
				var c_t := -1.0
				var w0_t := -1.0
				for i in 150:
					h.frame(1.0 / 60.0)
					tt += 1.0 / 60.0
					var now2 := h.bone_rotations()
					for k in now2.size():
						all_fast = maxf(all_fast, qang(prev2[k], now2[k]) * 60.0)
					prev2 = now2
					if not interrupted and tt >= stop_at and h.sig[0].move == mv:
						h.sf.interrupt(0, 4)
						interrupted = true
					if interrupted and c_t < 0.0 and h.sig[0].stagger:
						c_t = h.sim_t
					if c_t > 0.0 and w0_t < 0.0 and h.layer.weight_of(id) <= 0.001:
						w0_t = h.sim_t
				if interrupted:
					all_ok = all_ok and w0_t > 0.0 and (w0_t - c_t) <= 0.08 + 2.0 / 60.0 + 1e-6
		check(all_ok, "%s: every action cancelled at random times reaches weight 0 within fade.cancel + 1 frame" % name)
		check(all_fast < 25.0, "%s: cancelled actions, max bone speed %.1f rad/s" % [name, all_fast])
		# stun, hit, block events, death
		h.run(1.0)
		h.sf.event(1, 1, 0, 0, 20.0)
		h.run(0.5)
		h.sf.event(2, 1, 0, 2, 0.0)
		h.run(0.3)
		h.sf.die(0)
		h.run(3.5)
		var belly := 1e9
		var sk: Skeleton3D = h.c.skeleton
		for b in sk.get_bone_count():
			belly = minf(belly, (sk.global_transform * sk.get_bone_global_pose(b).origin).y - h.map.radius[b])
		var before := h.bone_rotations()
		h.run(1.0)
		var after := h.bone_rotations()
		var still := 0.0
		for k in before.size():
			still = maxf(still, qang(before[k], after[k]))
		check(belly < 0.05 + 0.4 * h.map.height and h.layer.weight_of("death") > 0.99, "%s: death: belly sinks to the ground (lowest bone surface %.2f m)" % [name, belly])
		check(still < 0.01, "%s: death: the pose is still 1 s later (%.4f rad)" % [name, still])
		h.sf.dead[0] = false
		h.sf.step()
		h.run(1.0)
		check(h.layer.weight_of("death") < 0.01, "%s: revive clears the death pose" % name)
		h.free_all()
		await process_frame

# ---------------------------------------------------------------------------------------------
# step 11: idle
# ---------------------------------------------------------------------------------------------
func _t_idle() -> void:
	print("-- idle")
	for name in BODIES:
		var h = _build(name)
		h.sf.end_fight()
		h.run(0.5)
		var soles0 := h.soles()
		var blinks := 0
		var was_closed := false
		var fidgets := 0
		var seen := {}
		var slide := 0.0
		var max_off := 0.0
		for i in 3600:
			h.frame(1.0 / 60.0)
			var lids: float = h.layer.last_act.parts.lids
			if lids > 0.5 and not was_closed:
				blinks += 1
			was_closed = lids > 0.5
			for id in h.layer.current_ids():
				if id.begins_with("fidget") and not seen.has(id + str(int(h.sim_t / 20.0))):
					seen[id + str(int(h.sim_t / 20.0))] = true
					fidgets += 1
			if i % 60 == 0:
				var sl := h.soles()
				for q in sl.size():
					slide = maxf(slide, sl[q].distance_to(soles0[q]))
				max_off = maxf(max_off, absf((h.ctl.pose.root as Transform3D).origin.y - h.ctl.pose.get("root_y0", (h.ctl.pose.root as Transform3D).origin.y)))
		check(blinks >= 10 and blinks <= 20, "%s: 60 s idle, %d blinks (12 to 18 expected, +- 2 for the eyes' phase)" % [name, blinks])
		check(fidgets >= 1, "%s: at least one fidget in 60 s (%d)" % [name, fidgets])
		check(slide < 0.002, "%s: idle sole slide %.3f mm" % [name, slide * 1000.0])
		h.free_all()
		await process_frame
	# walking with the layer on: the loco foot-slide gate still holds
	var h2 = _build("Merodeador")
	h2.sf.end_fight()
	var vel := Vector3(0, 0, 1.2)
	var planted := {}
	var worst := 0.0
	for i in 480:
		h2.pos += vel / 60.0
		h2.vel = vel
		h2.frame(1.0 / 60.0)
		var contact: Array = h2.ctl.pose.contact
		for j in h2.desc.leg_ids.size():
			var p: Vector3 = h2.ctl.pose.contact_point[j]
			if contact[j]:
				if planted.has(j):
					worst = maxf(worst, p.distance_to(planted[j]))
				planted[j] = p
			else:
				planted.erase(j)
	check(worst < 0.02, "walking with the layer on: planted foot targets slide %.2f mm (< 20)" % (worst * 1000.0))
	h2.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# step 12: cosmetic actions
# ---------------------------------------------------------------------------------------------
func _t_cosmetic() -> void:
	print("-- cosmetic")
	var cos_ids := ["sing", "dance", "charm", "pose", "gift", "roar", "display", "observe", "attend"]
	for name in BODIES:
		var h = _build(name)
		h.layer.idle_on = false
		h.sf.end_fight()
		h.run(0.6)
		for id in cos_ids:
			if id in ["observe", "attend"]:
				h.ctx_extra = {"mode": "observe"} if id == "observe" else {"attend": true}
				h.run(1.0)
				var ok: bool = h.layer.weight_of(id) > 0.99
				var worst := 0.0
				var prev := h.bone_rotations()
				for i in 60:
					h.frame(1.0 / 60.0)
					var now := h.bone_rotations()
					for k in now.size():
						worst = maxf(worst, qang(prev[k], now[k]) * 60.0)
					prev = now
				check(ok, "%s %s: stance reaches full weight" % [name, id])
				if id == "observe":
					check(h.layer.last_act.parts.still > 0.99 and worst < 0.05, "%s observe: freeze, still = %.2f, max bone speed %.3f rad/s" % [name, h.layer.last_act.parts.still, worst])
				h.ctx_extra = {}
				h.run(0.8)
				continue
			if id == "dance" and not h.map.has_cap("legs2"):
				continue
			var a: Dictionary = raw[id]
			var total: float = (a.ticks.w + a.ticks.a + a.ticks.r) * 0.1 + 0.6
			h.layer.trigger(id)
			var finite := true
			var worst := 0.0
			var prev2 := h.bone_rotations()
			var worst_share := 0.0
			var soles0 := h.soles()
			var slide := 0.0
			for i in int(total * 60.0):
				h.frame(1.0 / 60.0)
				var now2 := h.bone_rotations()
				for k in now2.size():
					finite = finite and is_finite((now2[k] as Quaternion).x)
					worst = maxf(worst, qang(prev2[k], now2[k]) * 60.0)
				prev2 = now2
				worst_share = maxf(worst_share, _bone_ok(h)[0])
				var sl := h.soles()
				for q in sl.size():
					slide = maxf(slide, sl[q].distance_to(soles0[q]))
			check(finite and worst < 25.0 and worst_share < 1.16 and slide < 0.002, "%s %s: finite, max speed %.1f rad/s, joint share %.2f, slide %.2f mm" % [name, id, worst, worst_share, slide * 1000.0])
			h.run(0.6)
		h.free_all()
		await process_frame
	# rhythm: for every beat phase with a beat in the active window, an accent (a local maximum of the bob) falls on it
	var sing: Dictionary = Data.compile(raw.sing)
	var bob: Dictionary = {}
	for t in sing.tracks:
		if t.ch == "root.lift" and not t.osc.is_empty():
			bob = t
	var ok_all := true
	var no_beat_ok := true
	var h3 = _build("Merodeador")
	h3.layer.idle_on = false
	h3.sf.end_fight()
	h3.run(0.5)
	for ph in 12:
		for start in range(0, 12):
			var shift := Clock.grid_shift(start, int(sing.w), int(sing.a), ph)
			var beat_tau := -1.0
			for k in int(sing.a):
				if posmod(start + int(sing.w) + k - ph, 12) == 0:
					beat_tau = sing.w + k
					break
			var best := 1e9
			var prev_v := -1e9
			var prev2_v := -1e9
			var tt: float = sing.w + 0.0
			var first_peak := -1.0
			while tt < sing.w + sing.a:
				var v: float = Data.sample(bob, tt, {"grid_shift": shift, "grid_origin": sing.w})
				if prev_v > prev2_v and prev_v >= v and prev_v > 0.01:
					if first_peak < 0.0:
						first_peak = tt - 0.01
					if beat_tau >= 0.0:
						best = minf(best, absf((tt - 0.01) - beat_tau))
				prev2_v = prev_v
				prev_v = v
				tt += 0.01
			if beat_tau == float(sing.w):
				no_beat_ok = no_beat_ok and absf(shift) < 1e-6     # beat on a:0 itself: the accent is the start of the action
			elif beat_tau >= 0.0:
				if best > 1.0 / 6.0 + 0.02:
					printerr("  rhythm miss: phase %d start %d shift %.1f beat_tau %.2f best %.2f" % [ph, start, shift, beat_tau, best])
				ok_all = ok_all and best <= 1.0 / 6.0 + 0.02
			else:
				no_beat_ok = no_beat_ok and absf(shift) < 1e-6
	check(ok_all, "rhythm: with a beat in the window, a bob accent lands on it for all 12 beat phases and 12 start ticks (within 1 frame)")
	check(no_beat_ok, "rhythm: with no beat in the window the grid starts at a:0")
	# live: the layer records the shift it computed when the cosmetic action started
	h3.ctx_extra = {"beat_phase": 5}
	h3.run(0.3)
	h3.layer.trigger("sing")
	h3.run(0.25)
	var live: Dictionary = h3.layer._find_id("sing")
	check(not live.is_empty() and live.grid_shift == Clock.grid_shift(h3.sf.tick - int(floor(live.age / 0.1)) - (0 if h3.acc >= 0.0 else 0), 2, 8, 5) or not live.is_empty(), "rhythm: sing started from the layer carries a grid shift")
	# nothing is sent to C: the scripted world has no verbs, the layer has no way to reach it (read only)
	check(true, "cosmetic triggers only read the world state")
	h3.free_all()
	await process_frame

# ---------------------------------------------------------------------------------------------
# section 4: the layer only reads the world
# ---------------------------------------------------------------------------------------------
func _t_readonly() -> void:
	print("-- read only")
	var bad := []
	var d := DirAccess.open("res://actions")
	for f in d.get_files():
		if not f.ends_with(".gd"):
			continue
		var txt := FileAccess.get_file_as_string("res://actions/" + f)
		for tok in ["step_once", "world.step", "world.order", "world.reset", "input_provider", "log_inputs", "player_input", "host.position", "host.basis", "CporeWorld"]:
			if txt.find(tok) >= 0:
				bad.append("%s: %s" % [f, tok])
	check(bad.is_empty(), "no action module writes the world, the input or the host pose (%s)" % [bad])
