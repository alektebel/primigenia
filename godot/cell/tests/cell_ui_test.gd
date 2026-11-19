extends SceneTree
## Headless UI smoke test of the cell stage: tool click, canvas click, keys, pause list. Run: make godot-cell-test

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
	ok(st._leg_cont != null and st._leg_cont.visible and (st._leg_cont.text == "Continuar como criatura" or st._leg_cont.text == "Continue as a creature"), "the end card has the primary 'Continuar como criatura' button (%s)" % st._leg_cont.text)
	ok(st._leg_go.text == "Volver al menú" or st._leg_go.text == "Back to the menu", "and keeps the way back to the menu")
	_key(KEY_5)
	await process_frame
	ok(not st._phase6 and st.canvas.visible and not st.ccanvas.visible, "key 5 goes back to the cell")
	print("cell ui tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
