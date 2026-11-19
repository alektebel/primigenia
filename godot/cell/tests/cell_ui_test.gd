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

func _click(pos: Vector2, button: int = MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = button
		e.pressed = pressed
		canvas._gui_input(e)   # headless windows are 64 px: deliver straight to the canvas

func _run() -> void:
	await process_frame
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "en"
	var st = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(st)
	await process_frame
	await process_frame
	canvas = st.canvas
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
	print("cell ui tests: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)
