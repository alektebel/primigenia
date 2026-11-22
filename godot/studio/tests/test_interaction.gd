extends SceneTree
## Creator direct manipulation, driven through the real input path with the real creature view:
##   godot --headless --path godot --script res://studio/tests/test_interaction.gd
## Wheel over a part scales it, joints drag without a mode, spine arrows extend neck and tail, a click on a limb
## opens the actuator ring (and nothing else changes actuation).

const Studio := preload("../ui/studio.gd")

var fails := 0
var checks := 0
var ui
var m

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)

func _frames(n := 3) -> void:
	for i in n:
		await process_frame

func motion(pos: Vector2, rel := Vector2.ZERO) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	ui._stage_input(e)

func button(pos: Vector2, idx: int, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = idx
	e.pressed = pressed
	ui._stage_input(e)

func wheel(pos: Vector2, up: bool) -> void:
	motion(pos)
	button(pos, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN, true)

func click(pos: Vector2) -> void:
	motion(pos)
	button(pos, MOUSE_BUTTON_LEFT, true)
	button(pos, MOUSE_BUTTON_LEFT, false)

func drag(a: Vector2, b: Vector2, steps := 6) -> void:
	motion(a)
	button(a, MOUSE_BUTTON_LEFT, true)
	for i in range(1, steps + 1):
		var p := a.lerp(b, float(i) / steps)
		motion(p, (b - a) / steps)
	button(b, MOUSE_BUTTON_LEFT, false)

func fresh(seed_name: String) -> void:
	m.new_from_seed(seed_name)
	ui.frame_creature()          # the studio starts on the 1 m hatchling: reframe for the seed under test
	m.select(-1)
	ui._close_ring()
	ui._close_wheel_tx()
	await _frames(3)

func screen(p: Vector3) -> Vector2:
	return ui.camera.unproject_position(p)

func part_pos(i: int) -> Vector2:
	var a: Dictionary = ui.view.part_anchor(i)
	return screen(a["pos"])

func leg_mid(i: int) -> Vector2:
	var hs: Array = ui.view.leg_handles(i)
	for h in hs:
		if h.joint == "k" and h.side == 1:
			return screen((h.hip + h.pos) * .5)
	return Vector2.ZERO

func leg_index() -> int:
	for i in m.doc["parts"].size():
		if ui.parts_db.is_leg(m.doc["parts"][i]["type"]):
			return i
	return -1

func _init() -> void:
	ui = Studio.new()
	root.add_child(ui)
	await _frames(6)
	m = ui.model
	ok("creature" in ui.view, "real creature view is used")
	await t_wheel()
	await t_joints()
	await t_arrows()
	await t_framing()
	await t_chain()
	await t_ring()
	await t_no_other_actuation_path()
	await t_topbar()
	await t_nest_drawer()
	print("studio interaction tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails > 0 else 0)

# ------------------------------------------------------------------ 1 wheel
func t_wheel() -> void:
	await fresh("Merodeador")
	var eye := 1
	ok(m.doc["parts"][eye]["type"] == "ojo", "part 1 is an eye")
	var p := part_pos(eye)
	var d0: float = ui._dist_goal
	var s0: float = m.doc["parts"][eye]["size"]
	motion(p)
	ok(ui.view._hover_part == eye or ui.view.hit_part(ui.camera.project_ray_origin(p), ui.camera.project_ray_normal(p)) >= 0, "eye is hoverable")
	wheel(p, true)
	ok(m.doc["parts"][eye]["size"] > s0, "wheel up over the eye enlarges it")
	ok(is_equal_approx(ui._dist_goal, d0), "wheel over a part does not zoom the camera")
	ok(not ui._scale_fx.is_empty() and str(ui._scale_fx["text"]).contains("."), "scale readout shown while scrolling")
	var s1: float = m.doc["parts"][eye]["size"]
	wheel(p, false)
	wheel(p, false)
	ok(m.doc["parts"][eye]["size"] < s1, "wheel down reduces it")
	for i in 60:
		wheel(p, true)
	ok(is_equal_approx(m.doc["parts"][eye]["size"], 2.2), "size clamps at the genome maximum 2.2")
	ok(ui._scale_fx["limit"], "readout flags the limit")
	for i in 120:
		wheel(p, false)
	ok(is_equal_approx(m.doc["parts"][eye]["size"], .5), "size clamps at the minimum 0.5")
	ok(m.validate()["ok"], "genome stays valid after scaling")
	ui._close_wheel_tx()
	ok(m.can_undo(), "scaling is one undoable edit")
	m.undo()
	ok(is_equal_approx(m.doc["parts"][eye]["size"], s0), "undo restores the original size in one step")
	# a leg: reach and thickness scale together
	var li := leg_index()
	var lp := leg_mid(li)
	var w0: float = m.doc["parts"][li]["w"]
	var f0: Array = m.doc["parts"][li]["f"].duplicate()
	wheel(lp, true)
	ok(m.doc["parts"][li]["f"][1] < f0[1], "wheel up over a leg lengthens it")
	ok(m.doc["parts"][li]["w"] >= w0, "and thickens it")
	for i in 80:
		wheel(lp, true)
	var f: Array = m.doc["parts"][li]["f"]
	ok(Vector3(f[0], f[1], f[2]).length() <= 6.001 and m.doc["parts"][li]["w"] <= .45 + 1e-6, "leg limits respected")
	ok(m.validate()["ok"], "genome valid after scaling a leg")
	ui._close_wheel_tx()
	# empty space still zooms
	var empty := Vector2(40, 60)
	var d1: float = ui._dist_goal
	wheel(empty, true)
	ok(ui._dist_goal < d1, "wheel over empty space zooms the camera in")
	wheel(empty, false)
	ok(ui._dist_goal > d1 * .99 and ui._dist_goal < d1 * 1.01, "and out")

# ------------------------------------------------------------------ 2 joints
func t_joints() -> void:
	await fresh("Merodeador")
	var li := leg_index()
	ok(li >= 0 and m.selected == -1, "a leg exists and nothing is selected")
	var lp := leg_mid(li)
	motion(lp)
	await _frames(2)
	ok(ui._hover_leg == li, "hovering a leg shows its handles (hover leg %d)" % ui._hover_leg)
	ok(ui.view.handle_leg() == li, "the view builds joint handles for the hovered leg")
	var js: Array = ui._joint_handles()
	ok(js.size() == 4, "knee and foot handles of both sides (%d)" % js.size())
	var knee: Dictionary = {}
	var foot: Dictionary = {}
	for j in js:
		if j["side"] == 1 and j["joint"] == "k": knee = j
		if j["side"] == 1 and j["joint"] == "f": foot = j
	var k0: Array = m.doc["parts"][li]["k"].duplicate()
	var f0: Array = m.doc["parts"][li]["f"].duplicate()
	drag(knee["screen"], knee["screen"] + Vector2(26, -22))
	await _frames(2)
	var k1: Array = m.doc["parts"][li]["k"]
	ok(abs(k1[0] - k0[0]) + abs(k1[1] - k0[1]) + abs(k1[2] - k0[2]) > .01, "dragging the knee moves it with no mode switch")
	ok(m.doc["parts"][li]["f"] == f0, "the foot stays put while the knee moves")
	ok(m.mode == "build", "still build mode")
	ok(m.validate()["ok"], "valid after a knee drag")
	m.undo()
	ok(m.doc["parts"][li]["k"] == k0, "undo restores the knee in one step")
	# foot: slides on the ground plane
	await _frames(2)
	motion(leg_mid(li))
	js = ui._joint_handles()
	for j in js:
		if j["side"] == 1 and j["joint"] == "f": foot = j
	drag(foot["screen"], foot["screen"] + Vector2(30, 6))
	var f1: Array = m.doc["parts"][li]["f"]
	ok(f1[0] != f0[0] or f1[2] != f0[2], "dragging the foot slides it")
	ok(is_equal_approx(f1[1], f0[1]), "the foot keeps its height (ground plane)")
	var fl := Vector2(f1[0], f1[2]).length()
	ok(fl < 6.0, "foot reach limit respected")
	ok(m.validate()["ok"], "valid after a foot drag")
	# a spine joint (vertebra) is draggable at any time too
	var n0: Dictionary = m.doc["nodes"][3].duplicate()
	var pts: PackedVector3Array = ui.view.spine_node_positions()
	motion(Vector2(30, 30))
	ui._spine_hover = true
	ui.view.set_spine_visible(true)
	await _frames(20)
	drag(screen(pts[3]), screen(pts[3]) + Vector2(0, -40))
	ok(abs(m.doc["nodes"][3]["y"] - n0["y"]) > .05, "a spine joint drags with the left button, no mode")

# ------------------------------------------------------------------ 3 spine arrows
func t_arrows() -> void:
	await fresh("Merodeador")
	var pts: PackedVector3Array = ui.view.spine_node_positions()
	var body := screen(pts[4])
	motion(Vector2(30, 30))
	motion(body)
	await _frames(25)
	ok(ui._spine_hover, "hovering the spine shows it")
	var arr: Dictionary = ui.spine_arrows()
	ok(arr.has("head") and arr.has("tail"), "two arrow handles, neck/head end and tail end")
	ok(ui.view.spine_alpha() > .5, "spine overlay faded in")
	# travelling from the body to the head arrow keeps the arrows alive
	var head: Vector2 = arr["head"]["pos"]
	for i in range(1, 7):
		motion(body.lerp(head, float(i) / 6.0))
	ok(ui._arrow_hot == "head", "pointer on the head arrow marks it hot")
	var n0: int = m.doc["nodes"].size()
	var last0: Dictionary = m.doc["nodes"][n0 - 1].duplicate()
	var prev0: Dictionary = m.doc["nodes"][n0 - 2].duplicate()
	var dir: Vector2 = arr["head"]["dir"]
	drag(head, head + dir * 150.0, 12)
	var n1: int = m.doc["nodes"].size()
	ok(n1 > n0, "dragging the head arrow outward adds neck segments (%d -> %d)" % [n0, n1])
	ok(n1 <= m.MAX_NODES_EDIT, "within the vertebra limit")
	var moved := Vector2(m.doc["nodes"][n1 - 1]["y"] - last0["y"], m.doc["nodes"][n1 - 1]["z"] - last0["z"])
	ok(moved.length() > .5, "the head end followed the drag")
	ok(m.validate()["ok"], "valid after extending the neck")
	m.undo()
	ok(m.doc["nodes"].size() == n0, "undo restores the neck in one step")
	# shorten: drag inward
	await _frames(25)
	motion(Vector2(30, 30))
	motion(body)
	await _frames(25)
	arr = ui.spine_arrows()
	head = arr["head"]["pos"]
	for i in range(1, 7):
		motion(body.lerp(head, float(i) / 6.0))
	drag(head, head - arr["head"]["dir"] * 120.0, 12)
	ok(m.doc["nodes"].size() <= n0, "dragging the head arrow inward does not add vertebrae")
	var gap := Vector2(m.doc["nodes"][m.doc["nodes"].size() - 1]["y"] - m.doc["nodes"][m.doc["nodes"].size() - 2]["y"], m.doc["nodes"][m.doc["nodes"].size() - 1]["z"] - m.doc["nodes"][m.doc["nodes"].size() - 2]["z"]).length()
	ok(gap >= .29, "segment spacing kept after shortening (%.2f)" % gap)
	ok(m.validate()["ok"], "valid after shortening the neck")
	m.undo()
	# bend: the vertebrae behind the end lean with it
	var before: Dictionary = m.doc["nodes"][n0 - 2].duplicate()
	m.bend_end(n0 - 1, last0["y"] + 1.0, last0["z"])
	ok(m.doc["nodes"][n0 - 2]["y"] > before["y"] + .1, "bending the end leans the neighbour with it")
	m.undo()
	# tail
	await _frames(25)
	var t0: Dictionary = m.doc["nodes"][0].duplicate()
	var nt: int = m.doc["nodes"].size()
	motion(Vector2(30, 30))
	motion(body)
	await _frames(25)
	arr = ui.spine_arrows()
	var tail: Vector2 = arr["tail"]["pos"]
	for i in range(1, 49):
		motion(body.lerp(tail, float(i) / 48.0))
	ok(ui._arrow_hot == "tail", "pointer on the tail arrow marks it hot")
	drag(tail, tail + arr["tail"]["dir"] * 150.0, 12)
	ok(m.doc["nodes"].size() > nt, "dragging the tail arrow outward adds tail segments (%d -> %d)" % [nt, m.doc["nodes"].size()])
	ok(Vector2(m.doc["nodes"][0]["y"] - t0["y"], m.doc["nodes"][0]["z"] - t0["z"]).length() > .5, "the tail end followed")
	ok(m.validate()["ok"], "valid after extending the tail")
	m.undo()
	ok(m.doc["nodes"].size() == nt, "undo restores the tail")
	# the arrows never get grabbed when the spine is not shown
	await _frames(1)
	ui._hover_node = -1
	ui._set_hover(-1)
	await _frames(40)
	ok(ui.view.spine_alpha() < .05, "spine fades out when the pointer leaves")

# ------------------------------------------------------------------ 7 framing, 8 growing spine end, 9 soft chain (A31)
func seg_lengths(N: Array) -> Array:
	var out := []
	for k in N.size() - 1:
		out.append(Vector2(N[k + 1]["y"] - N[k]["y"], N[k + 1]["z"] - N[k]["z"]).length())
	return out

func t_framing() -> void:
	for seed_name in ["Merodeador", "Hatchling"]:
		await fresh(seed_name)
		var free: Rect2 = ui.free_viewport()
		var arr: Dictionary = ui.spine_arrows()
		ok(arr.has("head") and arr.has("tail"), "%s: both spine arrows exist at the default framing" % seed_name)
		var inside := true
		for k in arr:
			inside = inside and free.has_point(arr[k]["pos"])
		ok(inside, "%s: both arrows sit in the free viewport between the panels (%s in %s)" % [seed_name, [arr["head"]["pos"], arr["tail"]["pos"]], free])

func t_chain() -> void:
	await fresh("Merodeador")
	var N0: Array = m.doc["nodes"].duplicate(true)
	var n0: int = N0.size()
	var sp: float = m.natural_spacing(N0)
	var e0 := Vector2(N0[n0 - 1]["y"], N0[n0 - 1]["z"])
	var axis := (e0 - Vector2(N0[n0 - 2]["y"], N0[n0 - 2]["z"])).normalized()
	var len0 := seg_lengths(N0)
	# 8: one drag (one transaction): out by about 2.4 spacings, then further, then back
	var hist0: int = m._hist.size()
	m.begin()
	m.bend_end(n0 - 1, e0.x + axis.x * sp * 2.4, e0.y + axis.y * sp * 2.4)
	var Na: Array = m.doc["nodes"]
	ok(Na.size() == n0 + 2, "dragging out 2.4 spacings generates two vertebrae (%d -> %d)" % [n0, Na.size()])
	var same := true
	for k in n0 - 1:
		same = same and is_equal_approx(Na[k]["y"], N0[k]["y"]) and is_equal_approx(Na[k]["z"], N0[k]["z"])
	ok(same, "the existing vertebrae did not move (no spreading)")
	var ls := seg_lengths(Na)
	var natural := true
	for k in range(n0 - 1, ls.size()):
		natural = natural and ls[k] > .45 * sp and ls[k] < 1.55 * sp
	ok(natural, "the new segments keep the natural spacing %.2f (%s)" % [sp, ls.slice(n0 - 1)])
	m.bend_end(Na.size() - 1, e0.x + axis.x * sp * 3.6, e0.y + axis.y * sp * 3.6)
	ok(m.doc["nodes"].size() == n0 + 3, "further out: one more vertebra, one by one (%d)" % m.doc["nodes"].size())
	m.bend_end(m.doc["nodes"].size() - 1, e0.x, e0.y)
	ok(m.doc["nodes"].size() == n0, "dragging back removes the generated vertebrae (%d)" % m.doc["nodes"].size())
	m.end()
	ok(m._hist.size() == hist0 + (1 if m.snapshot() != m._hist.back() else 0), "the whole drag is one undo step")
	m.undo()
	# the cap: far beyond 14 vertebrae
	m.begin()
	m.bend_end(n0 - 1, e0.x + axis.x * 40.0, e0.y)
	ok(m.doc["nodes"].size() == m.MAX_NODES_EDIT and m.end_capped, "the cap is %d vertebrae and says so (%d)" % [m.MAX_NODES_EDIT, m.doc["nodes"].size()])
	var lc := seg_lengths(m.doc["nodes"])
	var worst := 0.0
	for k in range(n0 - 1, lc.size()):
		worst = maxf(worst, lc[k])
	ok(worst <= 1.55 * sp + .001, "at the cap the segments still do not stretch (%.2f)" % worst)
	m.end()
	m.undo()
	# the tail grows the same way
	m.begin()
	var t0 := Vector2(N0[0]["y"], N0[0]["z"])
	var taxis := (t0 - Vector2(N0[1]["y"], N0[1]["z"])).normalized()
	m.bend_end(0, t0.x + taxis.x * sp * 2.2, t0.y + taxis.y * sp * 2.2)
	ok(m.doc["nodes"].size() == n0 + 2 and is_equal_approx(m.doc["nodes"][m.doc["nodes"].size() - 1]["y"], N0[n0 - 1]["y"]), "the tail generates vertebrae at the natural spacing, the head end stays")
	m.end()
	m.undo()
	# 9: a single vertebra drags its neighbours with a soft falloff
	await fresh("Merodeador")
	var A: Array = m.doc["nodes"].duplicate(true)
	var mid: int = A.size() / 2
	var parts_t := []
	for p in m.doc["parts"]:
		parts_t.append(p.get("t", 0.0))
	var hist1: int = m._hist.size()
	m.begin()
	for step in 6:
		m.move_node(mid, A[mid]["y"] + .12 * (step + 1), A[mid]["z"] + .1 * (step + 1))
	m.end()
	var B: Array = m.doc["nodes"]
	var mv := []
	for k in A.size():
		mv.append(Vector2(B[k]["y"] - A[k]["y"], B[k]["z"] - A[k]["z"]).length())
	ok(mv[mid] > .3, "the dragged vertebra moved (%.2f)" % mv[mid])
	ok(mv[mid + 1] > .05 and mv[mid - 1] > .05 and mv[mid + 1] < mv[mid] and mv[mid - 1] < mv[mid], "its neighbours follow, less (%.2f, %.2f, %.2f)" % [mv[mid - 1], mv[mid], mv[mid + 1]])
	ok(mv[mid + 2] < mv[mid + 1] + .001 and mv[mid - 2] < mv[mid - 1] + .001, "the pull decays along the chain (%.2f, %.2f)" % [mv[mid + 2], mv[mid - 2]])
	var lb := seg_lengths(B)
	var la := seg_lengths(A)
	var kinks := 0
	for k in lb.size():
		if lb[k] < .3 or lb[k] > 1.95:
			kinks += 1
	ok(kinks == 0, "no segment collapses or overstretches")
	var rigid := true
	for k in range(mid - 2, mid + 2):
		rigid = rigid and absf(lb[k] - la[k]) < .02
	ok(rigid, "segment lengths inside the dragged chain stay as they were")
	var same_t := true
	for k in parts_t.size():
		same_t = same_t and is_equal_approx(m.doc["parts"][k].get("t", 0.0), parts_t[k])
	ok(same_t, "limbs and mirrored pairs hang on their vertebra (positions t unchanged)")
	ok(m._hist.size() == hist1 + 1, "the whole drag is one undo step")
	m.undo()
	ok(Vector2(m.doc["nodes"][mid]["y"] - A[mid]["y"], m.doc["nodes"][mid]["z"] - A[mid]["z"]).length() < .001, "undo puts the spine back")
	ok(m.validate()["ok"], "valid after the soft drag")

# ------------------------------------------------------------------ 4 actuator ring
func t_ring() -> void:
	await fresh("Merodeador")
	var li := leg_index()
	var lp := leg_mid(li)
	# a click opens the ring
	motion(lp)
	button(lp, MOUSE_BUTTON_LEFT, true)
	button(lp, MOUSE_BUTTON_LEFT, false)
	await _frames(2)
	ok(ui.ring_open(), "a click on a limb opens the actuator ring")
	var ring: Control = ui._ring
	ok(ring.options.size() == 4, "four actuator types")
	var ids := []
	for o in ring.options:
		ids.append(o["id"])
	ok(ids == ["muscle", "hydraulic", "exo", "hydrostat"], "muscle, hydraulic, exoskeleton, hydrostatic")
	var cur := []
	for o in ring.options:
		if o["current"]: cur.append(o["id"])
	ok(cur == ["muscle"], "current actuator marked (%s)" % [cur])
	ok(ring.pivot_offset.distance_to(ring.center) < .1 and ring.center.distance_to(Vector2(ui.size.x / 2.0, ui.size.y / 2.0)) > 20.0, "ring is anchored on the limb, not on the screen centre")
	ok(ring.scale.x < 1.0 and ring.scale.x >= .96 and ring.modulate.a < 1.0, "ring starts at scale .96 and faded")
	ok(ring._tween != null and ring._tween.is_valid(), "ring animates in")
	await create_timer(.3).timeout
	ok(is_equal_approx(ring.scale.x, 1.0) and ring.modulate.a > .99, "ring settles at scale 1 and opacity 1 after 160 ms")
	# the disallowed ones do nothing
	var by := {}
	for i in ring.options.size():
		by[ring.options[i]["id"]] = i
	ok(not ring.options[by["hydraulic"]]["allowed"] and not ring.options[by["exo"]]["allowed"], "this endoskeleton body cannot carry hydraulic or exo")
	var hp: Vector2 = ring.button_center(by["hydraulic"])
	ring._gui_input(_mb(hp, true)); ring._gui_input(_mb(hp, false))
	ok(not m.doc["parts"][li].has("act") or m.doc["parts"][li]["act"] == "muscle", "a disallowed choice changes nothing")
	# A31: hovering a dimmed choice says why (bottom hint line and the bubble), Spanish and English
	var ev_m := InputEventMouseMotion.new()
	ev_m.position = hp
	ring._gui_input(ev_m)
	ok(ring._hover == by["hydraulic"] and ui.hint_label.text == "Necesita exoesqueleto: añade placas", "hovering a dimmed ring choice shows why in Spanish (%s)" % ui.hint_label.text)
	ok(ring.options[by["exo"]]["why"] == "Necesita exoesqueleto: añade placas", "the exoskeleton choice gives the same reason")
	var ev_m2 := InputEventMouseMotion.new()
	ev_m2.position = ring.button_center(by["muscle"])
	ring._gui_input(ev_m2)
	ok(not ui.hint_label.text.begins_with("Necesita"), "an allowed choice has no reason")
	ui.set_lang("en")
	ui._close_ring()
	ui._open_ring(li, false)
	ring = ui._ring
	ring.settle()
	ev_m.position = ring.button_center(by["hydraulic"])
	ring._gui_input(ev_m)
	ok(ui.hint_label.text == "Needs an exoskeleton: add plates", "and in English (%s)" % ui.hint_label.text)
	ui.set_lang("es")
	await _frames(1)
	# Esc closes
	if not ui.ring_open():
		click(lp)
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	ui._ring._input(ev)
	await _frames(2)
	ok(not ui.ring_open(), "Esc closes the ring")
	# a click outside closes it
	click(lp)
	ok(ui.ring_open(), "ring reopens")
	var outside := Vector2(60, 400)
	ui._ring._gui_input(_mb(outside, true)); ui._ring._gui_input(_mb(outside, false))
	await _frames(2)
	ok(not ui.ring_open(), "a click outside closes the ring")
	# a drag does not open it, nor does a long press
	var hl: Dictionary = {}
	drag(lp, lp + Vector2(30, 0))
	ok(not ui.ring_open(), "a drag on a limb does not open the ring")
	m.undo()
	motion(lp)
	button(lp, MOUSE_BUTTON_LEFT, true)
	ui._drag["t0"] -= 400
	button(lp, MOUSE_BUTTON_LEFT, false)
	ok(not ui.ring_open(), "a press longer than 200 ms is not a click")
	motion(lp)
	button(lp, MOUSE_BUTTON_LEFT, true)
	motion(lp + Vector2(3, 0), Vector2(3, 0))
	button(lp + Vector2(3, 0), MOUSE_BUTTON_LEFT, false)
	ok(ui.ring_open(), "a 3 px jitter is still a click")
	ui._close_ring()
	# choose hydrostat (allowed on an endo body): applies, one undo step
	ui._open_ring(li, false)
	ring = ui._ring
	ring.settle()
	by.clear()
	for i in ring.options.size():
		by[ring.options[i]["id"]] = i
	var hs: Vector2 = ring.button_center(by["hydrostat"])
	ring._gui_input(_mb(hs, true)); ring._gui_input(_mb(hs, false))
	await _frames(2)
	ok(m.doc["parts"][li].get("act", "") == "hydrostat", "choosing hydrostatic stores act on the limb")
	ok(not ui.ring_open(), "choosing closes the ring")
	ok(ui._limb_bio()["limbs"][li]["act"] == "hydrostat", "the realism layer derives the new actuator")
	ok(m.validate()["ok"], "genome valid after an actuator change")
	m.undo()
	ok(not m.doc["parts"][li].has("act"), "undo restores the automatic actuator")
	# an armoured body takes hydraulic and exoskeleton, switching its skeleton
	await fresh("Merodeador")
	m.add_part("placa", .3, 0.0)
	m.add_part("placa", .5, 0.0)
	m.select(-1)
	await _frames(3)
	var bio: Dictionary = ui._limb_bio()
	ok(bio["skeleton"] == "exo", "two plates give an exoskeleton body")
	ui._open_ring(li, false)
	ring = ui._ring
	by.clear()
	for i in ring.options.size():
		by[ring.options[i]["id"]] = i
	ok(ring.options[by["hydraulic"]]["allowed"] and ring.options[by["exo"]]["allowed"], "hydraulic and exoskeleton are available on an armoured body")
	var cur2 := []
	for o in ring.options:
		if o["current"]: cur2.append(o["id"])
	ok(cur2 == ["exo"], "muscle in an exoskeleton is the marked current one (%s)" % [cur2])
	var hy: Vector2 = ring.button_center(by["hydraulic"])
	ring._gui_input(_mb(hy, true)); ring._gui_input(_mb(hy, false))
	await _frames(2)
	ok(m.doc["parts"][li].get("act", "") == "hydraulic", "hydraulic applied")
	ok(m.validate()["ok"], "valid with hydraulic")
	m.undo()
	ui._open_ring(li, false)
	ring = ui._ring
	var mu: Vector2 = ring.button_center(0)
	ring._gui_input(_mb(mu, true)); ring._gui_input(_mb(mu, false))
	await _frames(2)
	ok(m.doc["parts"][li].get("act", "") == "muscle" and m.doc["skin"].get("sk", "auto") == "endo", "plain muscle switches the body to endoskeleton")
	ok(m.validate()["ok"], "valid with muscle on bone")
	m.undo()
	ok(m.doc["skin"].get("sk", "auto") == "auto", "undo restores the skeleton too")
	ui._open_ring(li, false)
	await _frames(1)
	ui.set_mode("test")
	ok(not ui.ring_open(), "switching mode closes the ring")
	ui.set_mode("build")

func _mb(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	return e

# ------------------------------------------------------------------ 5 no other path
func t_no_other_actuation_path() -> void:
	await fresh("Merodeador")
	ui._rebuild_panel()
	await _frames(2)
	var found := []
	_walk(ui, found)
	ok(found.is_empty(), "no actuation choosers left in the side panel (%s)" % [found])
	# every writer of the `act` key
	var src := FileAccess.get_file_as_string("res://studio/ui/studio.gd")
	ok(not src.contains("set_part_keys(ids, \"act\""), "no panel code writes limb actuation")
	var readout := false
	for n in ui.panel_box.get_children():
		if str(n.name).begins_with("Limb_"):
			readout = true
	ok(readout, "the read-only actuation readout is still shown")

func _walk(n: Node, out: Array) -> void:
	for c in n.get_children():
		if str(c.name).begins_with("LimbChoice") or str(c.name).begins_with("SkeletonChoice"):
			out.append(c.name)
		_walk(c, out)

# ------------------------------------------------------------------ 6 compact HUD and stage
## Same public controls remain reachable at the owner's three window sizes, in both languages.
func t_topbar() -> void:
	for sz in [Vector2i(1024, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		var sv := SubViewport.new()
		sv.size = sz
		root.add_child(sv)
		var st = Studio.new()
		sv.add_child(st)
		await _frames(5)
		for lg in ["es", "en"]:
			st.set_lang(lg)
			await _frames(5)
			var tag := "%dx%d %s" % [sz.x, sz.y, lg]
			var screen := Rect2(Vector2.ZERO, Vector2(sz))
			var modes: Rect2 = st.hud.get_node("TopModes").get_global_rect()
			var dna: Rect2 = st.hud.get_node("DnaCard").get_global_rect()
			ok(screen.encloses(modes) and screen.encloses(dna), "mode icons and budget fit (%s)" % tag)
			ok(not modes.intersects(dna), "mode icons and budget never overlap (%s)" % tag)
			ok(not st.right_card.visible and not st.palette_body.visible, "drawers start closed (%s)" % tag)
			var area: float = modes.get_area() + dna.get_area() + st.palette_card.get_global_rect().get_area()
			ok(area / screen.get_area() <= .15, "closed HUD covers at most 15 percent (%s: %.3f)" % [tag, area / screen.get_area()])
			for mode in ["build", "paint", "test"]:
				var b: Button = st.mode_buttons[mode]
				ok(b.text == "" and b.icon != null and b.tooltip_text != "", "mode has an icon and localised accessible tooltip (%s %s)" % [tag, mode])
			ok(st.play_creature_btn != null and modes.encloses(st.play_creature_btn.get_global_rect()), "play remains reachable (%s)" % tag)
			st.set_details_open(true)
			await _frames(3)
			ok(st.right_card.visible and screen.encloses(st.right_card.get_global_rect()), "Details opens inside the viewport (%s)" % tag)
			ok(st.name_edit.size.x >= 100 and st.name_edit.is_visible_in_tree(), "name remains editable in Details (%s)" % tag)
			st.set_details_open(false)
			st.set_palette_open(true)
			await _frames(3)
			ok(st.palette_body.visible and st.palette_card.size.x > 250, "parts expand on demand (%s)" % tag)
			st.set_palette_open(false)
			await _frames(3)
			ok(st.palette_card.size.x <= 64, "parts collapse back to an icon strip (%s)" % tag)
			st.frame_creature()
			var box: AABB = st.creature_bounds()
			var lo := INF
			var hi := -INF
			for i in 8:
				var y: float = st.camera.unproject_position(box.get_endpoint(i)).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			var fraction: float = (hi - lo) / st.stage.size.y
			# the loose rest AABB spans ~80% of the stage; the creature silhouette inside it is ~58% (the scorecard measures that)
			ok(fraction >= .72 and fraction <= .82, "starter rest bounds fill 72–82 percent (silhouette ~58) (%s %.3f)" % [tag, fraction])
			ok(st.env_node.grass == null and st.env_node.pedestal != null, "plinth has no foreground grass (%s)" % tag)
		sv.queue_free()
		await _frames(2)

func t_nest_drawer() -> void:
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	ok(w.reset(setup) == 0, "nest drawer fixture resets")
	var doc_model = preload("../model.gd").new(preload("../parts_db.gd").new())
	doc_model.new_from_seed("Hatchling")
	var sv := SubViewport.new()
	sv.size = Vector2i(1024, 600)
	root.add_child(sv)
	var st = Studio.new()
	st.nest_world = w
	st.nest_genome = doc_model.doc
	sv.add_child(st)
	await _frames(5)
	ok(not st.nest_panel.is_visible_in_tree(), "nest editing also starts with a quiet HUD")
	st.set_details_open(true)
	await _frames(3)
	ok(st.nest_panel.is_visible_in_tree(), "Details reveals the existing nest controls")
	ok(st.right_card.is_ancestor_of(st.nest_apply_button) and st.right_card.is_ancestor_of(st.nest_evolve_button), "Apply and Evolve remain in the scrollable drawer")
	var scroll: ScrollContainer = st.drawer_content.get_parent()
	scroll.ensure_control_visible(st.nest_evolve_button)
	await _frames(3)
	ok(st.nest_evolve_button.get_global_rect().intersects(st.right_card.get_global_rect()), "Evolve can be scrolled into view at 1024x600")
	st.set_details_open(false)
	await _frames(3)
	ok(not st.nest_panel.is_visible_in_tree(), "closing Details hides all nest controls")
	st.set_lang("en")
	await _frames(3)
	ok(not st.right_card.visible and st.nest_actions.size() == 3, "language rebuild preserves closed nest drawer and its actions")
	sv.queue_free()
	await _frames(2)
