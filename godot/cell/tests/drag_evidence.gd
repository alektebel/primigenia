extends SceneTree
## Evidence frames of dragging pieces onto the cell and blocks onto the colony board (xvfb, software GL).
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --rendering-driver opengl3 --path godot --script res://cell/tests/drag_evidence.gd -- <out dir>

const CS := preload("res://cell/cell_strings.gd")
var out_dir := ""
var st

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/drag"
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))
	print("saved ", name, " ", img.get_size())

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

func _drag(card: Control, p: Vector2) -> void:
	var c0 := card.global_position + card.size / 2.0
	_cev(card, c0, "down")
	var q := c0
	for i in range(1, 13):
		q = c0.lerp(p, float(i) / 12.0)
		_cev(card, q, "motion")

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e)

func _run() -> void:
	await process_frame
	root.get_node("Game").persist_settings = false
	root.get_node("Game").settings["language"] = "es"
	st = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(st)
	await process_frame
	st.sim.seed_value = 3
	st._apply_phase(2)
	st.sim.demo()
	st.advance(15.0)
	st._refresh_hud(true)
	var c = st.canvas
	var s = st.sim
	var trc: Button = st._tool_btns["tr"]
	var hkc: Button = st._tool_btns["hk"]
	# 1 a transporter near the membrane: ring highlighted, snap ring under it
	var near: Vector2 = c.to_screen(s.pol(s.RO + 34.0, -1.6))
	_drag(trc, near)
	await _shot("1-drag-membrane-valid")
	_cev(trc, near, "up")
	await process_frame
	# 2 an enzyme over the membrane: red ghost and the reason
	var mp: Vector2 = c.to_screen(s.pol(s.RO, 2.5))
	_drag(hkc, mp)
	await _shot("2-drag-enzyme-on-membrane-invalid")
	_cev(hkc, mp, "up")
	await create_timer(0.1).timeout
	await _shot("3-ease-back-mid-flight")
	await create_timer(0.3).timeout
	# 3 an enzyme inside: cytoplasm lit, valid
	var inside: Vector2 = c.to_screen(Vector2(s.CX + 70, s.CY + 60))
	_drag(hkc, inside)
	await _shot("4-drag-enzyme-inside-valid")
	_cev(hkc, inside, "up")
	await process_frame
	# 4 a transporter inside: invalid
	_drag(trc, inside + Vector2(-80, -60))
	await _shot("5-drag-transporter-inside-invalid")
	_key(KEY_ESCAPE)
	_cev(trc, inside, "up")
	await create_timer(0.3).timeout
	# 5 a placed piece dragged out of the cell: marked for removal
	var pc = s.pieces[0]
	var ps: Vector2 = c.to_screen(s.ppos(pc))
	var pe := InputEventMouseButton.new()
	pe.position = ps
	pe.global_position = ps
	pe.button_index = MOUSE_BUTTON_LEFT
	pe.pressed = true
	c._gui_input(pe)
	var far: Vector2 = c.to_screen(s.pol(s.RO + 190.0, pc.a if s.is_mem(pc) else 2.0))
	for i in range(1, 9):
		var mm := InputEventMouseMotion.new()
		mm.position = ps.lerp(far, i / 8.0)
		mm.global_position = mm.position
		mm.button_mask = MOUSE_BUTTON_MASK_LEFT
		c._gui_input(mm)
	await _shot("6-drag-placed-out-to-remove")
	_key(KEY_ESCAPE)
	pe.pressed = false
	c._gui_input(pe)
	# 6 the colony board
	s.threats.done = true
	st._refresh_hud(true)
	_key(KEY_6)
	for i in 6:
		await process_frame
	var cc = st.ccanvas
	var ec: Button = st._ctool_btns["energy"]
	var h1: Vector2 = cc.hex_center(Vector2i(1, -1))
	_drag(ec, h1 + Vector2(26, 18))
	await _shot("7-colony-drag-valid")
	_cev(ec, h1, "up")
	await create_timer(0.3).timeout
	var far_hex: Vector2 = cc.hex_center(Vector2i(-2, 1))
	_drag(st._ctool_btns["defense"], far_hex)
	await _shot("8-colony-drag-invalid-far")
	_cev(st._ctool_btns["defense"], far_hex, "up")
	await create_timer(0.3).timeout
	st.colony.cells[Vector2i.ZERO].atp = 0.0
	for h in st.colony.cells:
		st.colony.cells[h].atp = 0.0
	_drag(ec, cc.hex_center(Vector2i(1, 0)))
	await _shot("9-colony-drag-no-atp")
	_cev(ec, cc.hex_center(Vector2i(1, 0)), "up")
	await create_timer(0.3).timeout
	quit(0)
