extends SceneTree
## Headless UI smoke test of the cell stage: tool click, canvas click, keys, pause list. Run: make godot-cell-test

const CS := preload("res://cell/cell_strings.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	_run.call_deferred()

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e)

var canvas = null
var ccanvas = null

func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		canvas._gui_input(e)   # headless windows are 64 px: deliver straight to the canvas

func _cclick(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = button
	e.pressed = true
	ccanvas._gui_input(e)

# ---- drag helpers: a card press, motion and release through the card's own gui_input (as a real drag delivers them)
func _cev(card: Control, pos: Vector2, kind: String) -> void:
	var e: InputEvent
	if kind == "motion":
		var m := InputEventMouseMotion.new()
		m.position = pos - card.global_position
		m.global_position = pos
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		e = m
	else:
		var b := InputEventMouseButton.new()
		b.position = pos - card.global_position
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = kind == "down"
		e = b
	card.gui_input.emit(e)

func _cdrag_to(card: Control, p: Vector2) -> void:
	# press on the card, move a little (past the drag threshold), then to p
	var c0 := card.global_position + card.size / 2.0
	_cev(card, c0, "down")
	_cev(card, c0 + Vector2(-12, -4), "motion")
	_cev(card, p, "motion")

func _motion(cv: Control, pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	cv._gui_input(m)

func _btn(cv: Control, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	cv._gui_input(e)

func _run() -> void:
	await process_frame
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "en"
	var st = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(st)
	await process_frame
	await process_frame
	canvas = st.canvas
	ccanvas = st.ccanvas
	ok(st.sim != null and st.canvas != null, "stage builds a sim and a canvas")
	# phase keys
	_key(KEY_3)
	ok(st.sim.phase == 3, "key 3 selects phase 3")
	_key(KEY_1)
	ok(st.sim.phase == 1, "key 1 selects phase 1")
	_key(KEY_F)
	ok(st.speed == 3, "F toggles speed x3")
	_key(KEY_F)
	_key(KEY_L)
	ok(not st.canvas.labels, "L toggles the labels")
	_key(KEY_SPACE)
	ok(st.paused_by_key and st.canvas.paused, "Space pauses")
	_key(KEY_SPACE)
	ok(not st.paused_by_key, "Space resumes")
	# tool then cell
	st._tools_grid.get_child(0).emit_signal("pressed")   # transporter
	ok(st.canvas.tool == "tr", "clicking the first tool arms the transporter")
	var sp = st.sim.pol(st.sim.RO, 0.2)
	var sc: Vector2 = st.canvas.to_screen(sp)
	_click(sc)
	ok(st.sim.pieces.size() == 1 and st.canvas.tool == "", "clicking the membrane places the transporter and clears the tool")
	# right click removes
	_click(sc, MOUSE_BUTTON_RIGHT)
	ok(st.sim.pieces.size() == 0, "right click removes the piece")
	# a tool for a locked phase is not in the grid
	ok(not st._tool_btns.has("ldh"), "lactate DH tool is hidden in phase 1")
	_key(KEY_2)
	ok(st._tool_btns.has("ldh"), "lactate DH tool shows in phase 2")
	# esc opens the pause list
	_key(KEY_ESCAPE)
	ok(st.menu_open and st._menu_layer.visible, "Esc opens the pause list")
	_key(KEY_ESCAPE)
	ok(not st.menu_open, "Esc closes it")
	# sim keeps running in _process
	var t0: float = st.sim.T
	for i in 10:
		await process_frame
	ok(st.sim.T > t0, "the sim advances with frames")
	# phase 5: locked until the aggregation, then the threats card and the counter tools
	_key(KEY_1)
	st._refresh_hud(true)
	ok(st._phase_btns[4].disabled and st._phase_btns[5].disabled, "phases 5 and 6 are locked at the start")
	_key(KEY_5)
	ok(st.sim.phase == 1, "key 5 does nothing while threats are locked")
	st.sim.agg_done = true
	st._refresh_hud(true)
	ok(not st._phase_btns[4].disabled and st._phase_btns[5].disabled, "the aggregation opens phase 5 only")
	_key(KEY_5)
	ok(st.sim.phase == 5 and st._th_card.visible, "key 5 selects phase 5 and shows the threats card")
	ok(st._tool_btns.has("rib") and st._tool_btns.has("cas") and st._tool_btns.has("pump") and st._tool_btns.has("cat") and st._tool_btns.has("spn"), "the five new pieces are tools in phase 5")
	st.sim.reset()
	st._tool_btns["cas"].emit_signal("pressed")
	_click(st.canvas.to_screen(Vector2(340, 330)))
	ok(st.sim.pieces.is_empty(), "a Cas cannot be placed without a ribosome")
	ok(st.sim.fx.any(func(f): return f.k == "txt" and f.text == "need_rib"), "the cell says why (needs a ribosome)")
	st.canvas.tool = ""
	st.sim.demo()
	st._refresh_hud(true)
	ok(st._th_grid.get_child_count() >= 12, "the card lists the four threats with counter and state (%d cells)" % st._th_grid.get_child_count())
	st.sim.start_threats(1.0, 0)
	st.advance(3.0)
	await process_frame
	ok(st.sim.threat_info().stage == "warn", "the first threat gives a warning")
	# phase 6: locked until the four threats are survived, then the board, its tools and the carry-over card
	_key(KEY_6)
	ok(not st._phase6, "key 6 does nothing while the colony is locked")
	st.sim.threats.done = true
	st._refresh_hud(true)
	ok(not st._phase_btns[5].disabled, "surviving the threats opens phase 6")
	_key(KEY_6)
	await process_frame
	ok(st._phase6 and st.ccanvas.visible and not st.canvas.visible and st.colony != null, "key 6 shows the colony board")
	ok(st._ctool_btns.size() == 4 and st._ctool_btns["photo"].disabled and not st._ctool_btns["energy"].disabled, "four block tools, the photosynthetic one locked")
	ok(not st._th_card.visible and not st._lines_card.visible, "the cell cards give way to the colony")
	st._ctool_btns["energy"].emit_signal("pressed")
	ok(st.ccanvas.tool == "energy", "clicking a block arms it")
	_cclick(st.ccanvas.hex_center(Vector2i(1, 0)))
	ok(st.colony.cells.size() == 2 and st.ccanvas.tool == "", "clicking a free hex next to the founder places it")
	st._ctool_btns["defense"].emit_signal("pressed")
	_cclick(st.ccanvas.hex_center(Vector2i(2, 2)))
	ok(st.colony.cells.size() == 2, "a far hex is refused")
	st.ccanvas.tool = ""
	_cclick(st.ccanvas.hex_center(Vector2i(1, 0)), MOUSE_BUTTON_RIGHT)
	ok(st.colony.cells.size() == 1, "right click removes a block")
	# phase 6 drag: palette card onto a hex, between hexes, off the board, refusals, Esc
	var cg = st.ghost
	var ecard: Button = st._ctool_btns["energy"]
	st.colony.done = false
	var h10: Vector2 = st.ccanvas.hex_center(Vector2i(1, 0))
	_cdrag_to(ecard, h10 + Vector2(40, 30))
	ok(cg.active and cg.mode == "colony" and cg.gpos == h10 + Vector2(40, 30), "colony: the ghost block follows the pointer 1:1")
	ok(st.ccanvas.drag_kind == "energy" and cg.ok, "colony: the board lights the slots for the dragged block")
	_cev(ecard, h10, "motion")
	ok(cg.gpos == h10 and cg.ok and cg.text == "", "colony: a free hex touching the colony is a valid drop")
	_cev(ecard, h10, "up")
	ok(st.colony.cells.has(Vector2i(1, 0)) and st.colony.cells[Vector2i(1, 0)].kind == "energy", "colony: dropping on the hex places the block")
	ok(not cg.active and st.ccanvas.drag_kind == "" and st.ccanvas.tool == "", "colony: the ghost is gone and no tool stays armed")
	var atp0: float = st.colony.cells[Vector2i.ZERO].atp
	ok(atp0 < 10.0, "colony: the drop paid the same ATP as a tap")
	st._ctool_btns["energy"].emit_signal("pressed")
	ok(st.ccanvas.tool == "", "colony: the release of a drag is not read as a tap on the card")
	await process_frame
	# invalid: far hex, taken hex, no ATP
	var hfar: Vector2 = st.ccanvas.hex_center(Vector2i(-2, 0))
	_cdrag_to(ecard, hfar)
	ok(cg.active and not cg.ok and cg.text == CS.t("dr_far"), "colony: a far hex tints the ghost red and says why (%s)" % cg.text)
	_cev(ecard, hfar, "up")
	ok(st.colony.cells.size() == 2 and cg.returning(), "colony: dropping on a far hex places nothing and the ghost eases back")
	await create_timer(0.3).timeout
	ok(not cg.active, "colony: the ghost is gone after the ease-back")
	_cdrag_to(ecard, h10)
	ok(not cg.ok and cg.text == CS.t("dr_taken"), "colony: an occupied hex says Occupied (%s)" % cg.text)
	_cev(ecard, h10, "up")
	st.colony.cells[Vector2i.ZERO].atp = 0.0
	st.colony.cells[Vector2i(1, 0)].atp = 0.0
	var h0m: Vector2 = st.ccanvas.hex_center(Vector2i(-1, 0))
	_cdrag_to(ecard, h0m)
	ok(not cg.ok and cg.text == CS.t("dr_atp"), "colony: no ATP next door says so (%s)" % cg.text)
	_cev(ecard, h0m, "up")
	ok(st.colony.cells.size() == 2, "colony: a drop without ATP places nothing")
	await create_timer(0.3).timeout
	st.colony.cells[Vector2i.ZERO].atp = 10.0
	var lcard: Button = st._ctool_btns["photo"]
	_cev(lcard, lcard.global_position + lcard.size / 2.0, "down")
	_cev(lcard, lcard.global_position + Vector2(-30, -30), "motion")
	ok(not cg.active, "colony: a locked block card cannot be dragged")
	_cev(lcard, lcard.global_position + Vector2(-30, -30), "up")
	# drop outside the board: cancels
	_cdrag_to(ecard, Vector2(st.size.x - 100, 300))
	ok(cg.active and cg.text == CS.t("dr_cancel") and cg.ok, "colony: over the side column the ghost says release to cancel")
	_cev(ecard, Vector2(st.size.x - 100, 300), "up")
	await create_timer(0.3).timeout
	ok(st.colony.cells.size() == 2, "colony: releasing outside the board places nothing")
	# Esc mid drag
	_cdrag_to(ecard, h0m)
	_key(KEY_ESCAPE)
	ok(not st.menu_open and cg.returning() and st.ccanvas.drag_kind == "", "colony: Esc cancels the drag (and does not open the menu)")
	_cev(ecard, h0m, "motion")
	_cev(ecard, h0m, "up")
	await create_timer(0.3).timeout
	ok(st.colony.cells.size() == 2 and not cg.active, "colony: after Esc the release places nothing")
	# move a block between hexes
	st.colony.cells[Vector2i.ZERO].atp = 10.0
	var hb: Vector2 = st.ccanvas.hex_center(Vector2i(0, 1))
	_btn(st.ccanvas, h10, true)
	ok(st.ccanvas.drag_from == Vector2i(1, 0) and cg.active, "colony: pressing a placed block picks it up")
	_motion(st.ccanvas, hb)
	ok(cg.gpos == hb and cg.ok and st.ccanvas.mouse_default_cursor_shape == Control.CURSOR_DRAG, "colony: the picked-up block follows the pointer, grabbing cursor")
	_btn(st.ccanvas, hb, false)
	ok(st.colony.cells.has(Vector2i(0, 1)) and not st.colony.cells.has(Vector2i(1, 0)) and st.colony.cells[Vector2i(0, 1)].kind == "energy", "colony: dropping on another free hex moves the block")
	_btn(st.ccanvas, hb, true)
	_motion(st.ccanvas, hb + Vector2(0, 400))
	ok(st.ccanvas.drag_out and cg.text == CS.t("dr_remove"), "colony: dragged off the board it says release to remove")
	_btn(st.ccanvas, hb + Vector2(0, 400), false)
	ok(st.colony.cells.size() == 1 and not st.colony.cells.has(Vector2i(0, 1)), "colony: releasing off the board removes the block")
	st._ctool_btns["energy"].emit_signal("pressed")
	_cclick(st.ccanvas.hex_center(Vector2i(1, 0)))
	_btn(st.ccanvas, st.ccanvas.hex_center(Vector2i(1, 0)), true)
	_motion(st.ccanvas, hb)
	_key(KEY_ESCAPE)
	_btn(st.ccanvas, hb, false)
	ok(st.colony.cells.has(Vector2i(1, 0)) and not st.colony.cells.has(Vector2i(0, 1)), "colony: Esc leaves a picked-up block where it was")
	_btn(st.ccanvas, st.ccanvas.hex_center(Vector2i.ZERO), true)
	ok(st.ccanvas.drag_from == Vector2i(99, 99), "colony: the founder cannot be picked up")
	_btn(st.ccanvas, st.ccanvas.hex_center(Vector2i.ZERO), false)
	st.ccanvas.tool = ""
	_cclick(st.ccanvas.hex_center(Vector2i(1, 0)), MOUSE_BUTTON_RIGHT)
	ok(st.colony.cells.size() == 1, "colony: right click still removes")
	st.find_child("Demo", true, false).emit_signal("pressed")
	ok(st.colony.cells.size() == 7, "'Montar ejemplo' builds the colony of 7 (%d)" % st.colony.cells.size())
	st._refresh_hud(true)
	ok(st._stat_lbls["s_rate"][1].text == "7/7", "the stats card reads the colony (%s)" % st._stat_lbls["s_rate"][1].text)
	st.colony.done = true
	st.colony.done_t = 2.0
	for i in 3:
		await process_frame
	ok(st._leg_card.visible and st._leg_table.get_child_count() == 6, "the carry-over card shows diet, part and size")
	ok(st._leg_title.text == "La colonia se convierte en criatura" or st._leg_title.text == "The colony becomes a creature", "with its title (%s)" % st._leg_title.text)
	_key(KEY_5)
	await process_frame
	ok(not st._phase6 and st.canvas.visible and not st.ccanvas.visible, "key 5 goes back to the cell")
	# ---- drag a card onto the cell
	st.sim.reset()
	st._refresh_hud(true)
	_key(KEY_1)
	await process_frame
	var g = st.ghost
	var trc: Button = st._tool_btns["tr"]
	var hkc: Button = st._tool_btns["hk"]
	var mem_pt: Vector2 = st.canvas.to_screen(st.sim.pol(st.sim.RO, 0.2))
	var in_pt: Vector2 = st.canvas.to_screen(Vector2(st.sim.CX + 40, st.sim.CY - 20))
	_cdrag_to(trc, mem_pt + Vector2(30, 20))
	ok(g.active and g.visible and g.gpos == mem_pt + Vector2(30, 20), "drag: a ghost follows the pointer 1:1 (no lag)")
	ok(st.canvas.drag_kind == "tr" and st.canvas.tool == "", "drag: the cell knows a transporter is coming and the tap tool is off")
	ok(trc.mouse_default_cursor_shape == Control.CURSOR_DRAG and trc.modulate.a < 1.0, "drag: grabbing cursor, the card dims")
	_cev(trc, mem_pt, "motion")
	ok(g.gpos == mem_pt and g.ok and g.text == "", "drag: over the membrane the transporter is valid")
	ok(st.sim.can_place("tr", st.canvas.to_sim(mem_pt)) == "", "drag: the snap target is valid for the transporter")
	_cev(trc, mem_pt, "up")
	ok(st.sim.pieces.size() == 1 and st.sim.pieces[0].type == "tr" and st.canvas.drag_kind == "" and not g.active, "drag: dropping on the membrane places it, the ghost is gone")
	ok(absf(st.sim.pieces[0].a - atan2(st.canvas.to_sim(mem_pt).y - st.sim.CY, st.canvas.to_sim(mem_pt).x - st.sim.CX)) < 0.001, "drag: it snaps to the membrane under the pointer")
	st._tool_btns["tr"].emit_signal("pressed")
	ok(st.canvas.tool == "", "drag: the release is not read as a tap")
	await process_frame
	trc.emit_signal("pressed")
	ok(st.canvas.tool == "tr", "tap-then-tap still arms the tool")
	st.canvas.tool = ""
	st._refresh_tools()
	# invalid: an enzyme on the membrane
	st.sim.reset()
	_cdrag_to(hkc, mem_pt)
	ok(g.active and not g.ok and g.text == CS.t("dr_where_in"), "drag: an enzyme over the membrane tints red and says why (%s)" % g.text)
	_cev(hkc, mem_pt, "up")
	ok(st.sim.pieces.is_empty() and g.returning(), "drag: an invalid drop places nothing, the ghost eases back")
	await create_timer(0.1).timeout
	var card_c: Vector2 = hkc.global_position + hkc.size / 2.0
	ok(g.active and g.alpha < 1.0 and g.gpos.distance_to(card_c) < mem_pt.distance_to(card_c), "drag: mid ease-back it is between the drop and its card")
	await create_timer(0.25).timeout
	ok(not g.active and not g.visible, "drag: the ghost is gone after 200 ms")
	# invalid: a transporter inside
	_cdrag_to(trc, in_pt)
	ok(not g.ok and g.text == CS.t("dr_where_mem"), "drag: a transporter inside the cell says membrane only (%s)" % g.text)
	_cev(trc, in_pt, "up")
	ok(st.sim.pieces.is_empty(), "drag: and is not placed")
	await create_timer(0.3).timeout
	# valid enzyme
	_cdrag_to(hkc, in_pt)
	ok(g.ok and g.text == "", "drag: an enzyme inside the cytoplasm is valid")
	_cev(hkc, in_pt, "up")
	ok(st.sim.pieces.size() == 1 and st.sim.pieces[0].type == "hk", "drag: and is placed")
	# outside: cancel
	st.sim.reset()
	_cdrag_to(hkc, Vector2(st.size.x - 100, 300))
	ok(g.active and g.text == CS.t("dr_cancel"), "drag: over the side column it says release outside to cancel (%s)" % g.text)
	_cev(hkc, Vector2(st.size.x - 100, 300), "up")
	ok(st.sim.pieces.is_empty() and g.returning(), "drag: dropping outside the cell cancels")
	await create_timer(0.3).timeout
	# Esc
	_cdrag_to(hkc, in_pt)
	_key(KEY_ESCAPE)
	ok(not st.menu_open and g.returning() and st.canvas.drag_kind == "", "drag: Esc cancels and does not open the pause list")
	_cev(hkc, in_pt, "motion")
	_cev(hkc, in_pt, "up")
	ok(st.sim.pieces.is_empty(), "drag: after Esc the release places nothing")
	await create_timer(0.3).timeout
	# a press that does not move is a tap
	_cev(hkc, card_c, "down")
	_cev(hkc, card_c + Vector2(2, 1), "motion")
	ok(not g.active, "drag: under 6 px it is still a tap")
	_cev(hkc, card_c, "up")
	# move a placed piece
	st.sim.reset()
	var pc = st.sim.add_piece("tr", st.sim.pol(st.sim.RO, 0.2), true)
	var pe = st.sim.add_piece("hk", Vector2(st.sim.CX + 40, st.sim.CY), true)
	var a0: float = pc.a
	var ps: Vector2 = st.canvas.to_screen(st.sim.ppos(pc))
	_btn(st.canvas, ps, true)
	ok(st.canvas.drag == pc and st.canvas.mouse_default_cursor_shape == Control.CURSOR_DRAG, "move: pressing a placed piece picks it up (grabbing cursor)")
	var to: Vector2 = st.canvas.to_screen(st.sim.pol(st.sim.RO, 1.4))
	_motion(st.canvas, to)
	ok(absf(pc.a - 1.4) < 0.01 and not st.canvas.drag_out, "move: the transporter slides along the membrane with the pointer")
	_btn(st.canvas, to, false)
	ok(st.sim.pieces.size() == 2 and absf(pc.a - 1.4) < 0.01, "move: releasing leaves it there")
	var es: Vector2 = st.canvas.to_screen(st.sim.ppos(pe))
	_btn(st.canvas, es, true)
	var to2: Vector2 = st.canvas.to_screen(Vector2(st.sim.CX - 30, st.sim.CY + 50))
	_motion(st.canvas, to2)
	_key(KEY_ESCAPE)
	_btn(st.canvas, to2, false)
	ok(pe.pos.distance_to(Vector2(st.sim.CX + 40, st.sim.CY)) < 0.01, "move: Esc puts the piece back where it was picked up")
	# drag it out of the cell to remove it
	_btn(st.canvas, es, true)
	var far_pt: Vector2 = st.canvas.to_screen(st.sim.pol(st.sim.RO + 200.0, 3.0))
	_motion(st.canvas, far_pt)
	ok(st.canvas.drag_out, "remove: past the membrane the piece is marked for removal")
	_btn(st.canvas, far_pt, false)
	ok(st.sim.pieces.size() == 1 and not st.sim.pieces.has(pe), "remove: releasing outside the cell removes it (same as Quitar)")
	_btn(st.canvas, st.canvas.to_screen(st.sim.ppos(pc)), true)
	_motion(st.canvas, far_pt)
	_motion(st.canvas, st.canvas.to_screen(st.sim.pol(st.sim.RO, 2.0)))
	ok(not st.canvas.drag_out, "remove: coming back inside unmarks it")
	_btn(st.canvas, st.canvas.to_screen(st.sim.pol(st.sim.RO, 2.0)), false)
	ok(st.sim.pieces.size() == 1, "remove: dropped back on the membrane it stays")
	print("cell ui tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
