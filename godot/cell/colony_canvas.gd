extends Control
## Draws the colony board (phase 6) and turns the mouse into colony_sim actions. Screen space, hex size from the play area.

const CSim := preload("res://cell/colony_sim.gd")
const CS := preload("res://cell/cell_strings.gd")

signal placed(kind: String)
signal tool_cleared
signal removed(kind: String)
signal moved(kind: String)

const INK := Color("3A352D")
const SUB := Color("6A6356")
const WARN := Color("9E392C")
const ATPY := Color("E2C240")
const PHOS := Color("9179C9")

var sim
var tool := ""            # "", "del" or a block kind
var labels := true
var paused := false
var still := false
var play_rect := Rect2(0, 0, 800, 720)
const NONE := Vector2i(99, 99)
var drag_kind := ""        # a palette card is being dragged over the board (set by the stage)
var drag_pos := Vector2.ZERO   # ... pointer, canvas coordinates
var drag_from := NONE      # a placed block being moved between hexes
var drag_out := false      # ... and it is off the board: releasing removes it
var ghost = null           # the stage's DragGhost, for the blocks picked up from the board
var hover_hex := Vector2i(99, 99)
var hover_pos := Vector2.ZERO
var mouse_in := false
var t_draw := 0.0
var _font: Font
var _drift := Vector2.ZERO
var _tipbox: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://ui/fonts/AlegreyaSans-Medium.ttf")

func _process(delta: float) -> void:
	t_draw += delta
	if sim != null and not paused and not still:
		var a: float = sim.light_a
		_drift -= Vector2(cos(a), sin(a)) * sim.speed * delta * 3.0
	queue_redraw()

func hsize() -> float:
	return minf(play_rect.size.x / 9.8, play_rect.size.y / 9.6)

func center() -> Vector2:
	return play_rect.get_center()

func hex_center(h: Vector2i) -> Vector2:
	return center() + CSim.to_px(h) * hsize()

func hex_at(p: Vector2) -> Vector2i:
	return CSim.from_px((p - center()) / hsize())

func _screen_text(p: Vector2, text: String, col: Color, size: int = 13, outline := true) -> void:
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var q := p - Vector2(s.x / 2.0, 0)
	if outline:
		draw_string_outline(_font, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, Color(0.98, 0.95, 0.88, 0.7) if col.get_luminance() < 0.6 else Color(0.07, 0.15, 0.18, 0.55))
	draw_string(_font, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)

func _dashed_circle(p: Vector2, r: float, col: Color, w: float) -> void:
	var n := 14
	for i in n:
		var a0 := float(i) / n * TAU
		draw_arc(p, r, a0, a0 + TAU / n * 0.55, 5, col, w, true)

func _radial(c: Vector2, r_out: float, c_out: Color, c_in: Color, shift: Vector2, steps: int = 9) -> void:
	for i in steps:
		var f := float(i) / (steps - 1)
		draw_circle(c + shift * f, r_out * (1.0 - f * 0.92), c_out.lerp(c_in, f))

# ---------- main draw
func _draw() -> void:
	if sim == null:
		return
	var S := hsize()
	var c := center()
	var tt := t_draw
	var sz := size
	draw_rect(Rect2(Vector2.ZERO, sz), Color("0F2229"))
	var wr := maxf(sz.x, sz.y) * 0.75
	for i in 14:
		var f := float(i) / 13.0
		draw_circle(c, wr * (1.0 - f * 0.8), Color("0F2229").lerp(Color("2E5560"), f))
	var g: Dictionary = sim.goal()
	# the light (or food): a warm glow in its direction, closer as the colony gets there
	var ld := Vector2(cos(g.light_a), sin(g.light_a))
	var lp: Vector2 = c + ld * (S * 5.2 + g.dist * 1.15 * S / 40.0 * 4.0)
	for i in 8:
		var f2 := float(i) / 7.0
		draw_circle(lp, S * (4.8 - f2 * 4.4), Color(1.0, 0.9, 0.55, 0.05 + 0.07 * f2))
	draw_circle(lp, S * 0.5, Color(1.0, 0.97, 0.78, 0.9))
	# specks drift past as the colony swims
	var k := minf(sz.x, sz.y) / 720.0
	for i in 44:
		var x := fposmod(i * 97.3 * sz.x / 720.0 + _drift.x * k - tt * 3.0, sz.x)
		var y := fposmod(i * 53.7 * sz.y / 720.0 + _drift.y * k + sin(tt * 0.4 + i) * 6.0, sz.y)
		draw_circle(Vector2(x, y), (1.6 + (i % 3) * 0.5) * maxf(k, 0.8), Color(0.56, 0.72, 0.72, 0.4))
	# arrow to the light
	if not g.arrived:
		var ap := c + ld * S * 4.75
		var pulse := 0.6 + 0.4 * sin(tt * 3.0)
		var n := Vector2(-ld.y, ld.x)
		draw_colored_polygon(PackedVector2Array([ap + ld * 14.0, ap - ld * 6.0 + n * 11.0, ap - ld * 6.0 - n * 11.0]), Color(1.0, 0.9, 0.55, 0.55 + 0.35 * pulse))
		_screen_text(ap + ld * 34.0 + Vector2(0, 5), CS.t("light"), Color(1.0, 0.93, 0.7, 0.9), 14)
	# free slots while a block is armed
	var armed := tool if (tool != "" and tool != "del") else (drag_kind if drag_kind != "" else (str(sim.cells[drag_from].kind) if drag_from != NONE and sim.cells.has(drag_from) else ""))
	if armed != "":
		var tgt := hex_at(drag_pos) if drag_kind != "" else hover_hex
		var pulse := 0.5 if still else 0.5 + 0.5 * sin(tt * 4.0)
		var dragging := drag_kind != "" or drag_from != NONE
		var slots: Array = sim.slots()
		if drag_from != NONE:
			slots = slots.filter(func(q): return sim.can_move(drag_from, q) == "")
			slots.append(drag_from)
		for h in slots:
			var pc := hex_center(h)
			var hov: bool = h == tgt
			var base_a := 0.4 + (0.2 * pulse if dragging else 0.0)
			_dashed_circle(pc, S * 0.82, Color(0.91, 0.89, 0.84, 0.95 if hov else base_a), 2.5 if (hov or dragging) else 2.0)
			if hov and not (drag_from != NONE and h == drag_from):
				var col: Color = CSim.BLOCKS[armed].col
				col.a = 0.45 if not dragging else 0.7
				draw_circle(pc, S * 0.78, col)
		if drag_from != NONE and sim.cells.has(drag_from):
			draw_arc(hex_center(drag_from), S * 0.9, 0, TAU, 40, Color(0.97, 0.95, 0.88, 0.8), 2.0, true)
	# links, then cells
	for h in sim.cells:
		for d in [CSim.DIRS[0], CSim.DIRS[1], CSim.DIRS[5]]:
			var o: Vector2i = h + d
			if sim.cells.has(o):
				_draw_link(h, o, S, tt)
	for h in sim.cells:
		_draw_cell(h, sim.cells[h], S, tt, ld)
	if g.wave == "warn" or g.wave == "hit":
		_draw_amoeba(g, c, S, tt)
	_draw_threat_warning(g, c, S, tt)
	for f in sim.fx:
		var p := hex_center(f.p)
		var pr: float = f.t / 1.1
		if f.k == "ring":
			var cc: Color = f.color
			cc.a = 1.0 - pr
			draw_arc(p, S * (0.7 + pr * 0.7), 0, TAU, 32, cc, 3.0 * (1.0 - pr) + 0.5, true)
		else:
			var tc: Color = f.color
			tc.a = 1.0 - pr * pr
			_screen_text(p + Vector2(0, -S * 0.7 - pr * 24.0), CS.fx_text(f.text), tc, 14)
	_draw_banner(g)
	if tool != "" and tool != "del":
		_center_text(CS.t("tap_slot"), play_rect.end.y - 26.0, 16, Color(0.91, 0.89, 0.84, 0.95))
	elif tool == "del":
		_center_text(CS.t("remove"), play_rect.end.y - 26.0, 16, Color(0.91, 0.89, 0.84, 0.95))
	if paused:
		_center_text(CS.t("paused"), play_rect.end.y - 52.0, 18, Color(0.98, 0.9, 0.55, 0.95))
	_draw_tip(S)

func _center_text(txt: String, y: float, fs: int, col: Color) -> void:
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(play_rect.get_center().x - w / 2.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _box(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(10)
	return b

func _draw_link(a: Vector2i, b: Vector2i, S: float, tt: float) -> void:
	var pa := hex_center(a)
	var pb := hex_center(b)
	var m := (pa + pb) / 2.0
	var u := (pb - pa).normalized()
	draw_line(m - u * S * 0.5, m + u * S * 0.5, INK, S * 0.2, true)
	draw_line(m - u * S * 0.5, m + u * S * 0.5, Color("E68FB5"), S * 0.12, true)
	var fl: float = sim.flows.get("%d,%d>%d,%d" % [a.x, a.y, b.x, b.y], 0.0)
	if absf(fl) > 0.02:
		var ph := fposmod(tt * 1.6, 1.0)
		var s := 1.0 if fl > 0.0 else -1.0
		var q := m + u * s * (ph - 0.5) * S * 0.9
		draw_circle(q, S * 0.11, INK)
		draw_circle(q, S * 0.08, ATPY)

func _draw_cell(h: Vector2i, c: Dictionary, S: float, tt: float, ld: Vector2) -> void:
	var p := hex_center(h)
	var kind: String = c.kind
	var R := S * 0.78
	var born := clampf((sim.T - c.born) / 0.3, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - born, 3.0)
	R *= (0.7 + 0.3 * e) if c.born > 0.0 else 1.0
	var br := 0.0 if still else sin(tt * 0.8 + h.x * 1.3 + h.y * 0.7) * 1.2
	# flagellum first (behind the body): trails opposite to the light
	if kind == "motile":
		var back := -ld
		var nrm := Vector2(-back.y, back.x)
		var pts := PackedVector2Array()
		var amp := (0.22 if c.fed else 0.08) * S
		var sp := 12.0 if c.fed else 3.0
		for i in 25:
			var u := float(i) / 24.0
			var w := sin(u * 9.0 - (0.0 if still else tt * sp)) * amp * u
			pts.append(p + back * (R + u * S * 1.5) + nrm * w)
		draw_polyline(pts, INK, S * 0.2, true)
		draw_polyline(pts, Color("D4B37C"), S * 0.11, true)
	# spines of the defensive cell, all around
	if kind == "defense":
		for i in 14:
			var a := float(i) / 14.0 * TAU + 0.2
			var cu := Vector2(cos(a), sin(a))
			var nu := Vector2(-cu.y, cu.x)
			var tri := PackedVector2Array([p + cu * R * 0.95 - nu * S * 0.11, p + cu * (R + S * 0.38), p + cu * R * 0.95 + nu * S * 0.11])
			draw_colored_polygon(tri, Color("8C7D5A"))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2]]), INK, 1.3, true)
	for i in 4:
		draw_circle(p + Vector2(0, S * 0.08), R + S * 0.28 - i * S * 0.07, Color(0.85, 0.94, 0.86, 0.035))
	_radial(p, R + S * 0.12 + br, Color("EAD9B2"), Color("FBF2DC"), Vector2(-S * 0.25, -S * 0.3), 9)
	# membrane: a ring of lipid heads, thicker for the defensive cell, redder as the cell is hurt
	var hurt := 1.0 - clampf(c.hp / maxf(c.hp0, 1.0), 0.0, 1.0)
	var head := Color("9DB56A").lerp(Color("9E392C"), hurt)
	var nh := 22
	var rr := R + br
	for i in nh:
		var a2 := float(i) / nh * TAU + (0.0 if still else tt * 0.05)
		draw_circle(p + Vector2(cos(a2), sin(a2)) * rr, S * (0.115 if kind != "defense" else 0.16), INK)
		draw_circle(p + Vector2(cos(a2), sin(a2)) * rr, S * (0.095 if kind != "defense" else 0.135), head)
	if kind == "defense":
		draw_arc(p, rr - S * 0.2, 0, TAU, 40, Color(0.55, 0.49, 0.35, 0.55), S * 0.16, true)
	if c.hit > 0.0:
		draw_arc(p, rr + S * 0.15, 0, TAU, 32, Color(1, 1, 1, c.hit), 3.0, true)
	# inside
	if kind == "founder":
		draw_arc(p + Vector2(S * 0.1, -S * 0.12), S * 0.3, 0, TAU, 28, INK, S * 0.17, true)
		draw_arc(p + Vector2(S * 0.1, -S * 0.12), S * 0.3, 0, TAU, 28, Color("D99A3C"), S * 0.1, true)
	var nb := int(round(clampf(c.atp, 0.0, CSim.CAP) / 2.0))
	for i in nb:
		var a3 := 0.6 + float(i) * 1.15
		var q := p + Vector2(cos(a3), sin(a3)) * S * (0.36 if kind != "founder" else 0.5)
		draw_circle(q + Vector2(0, 0), S * 0.115, INK)
		draw_circle(q, S * 0.09, ATPY)
	if kind == "energy":
		_screen_text(p + Vector2(0, S * 0.09), "E", Color("7A6410"), int(S * 0.5), false)
	elif kind == "motile":
		_screen_text(p + Vector2(0, S * 0.09), "M", Color("8A6A30"), int(S * 0.5), false)
	elif kind == "defense":
		_screen_text(p + Vector2(0, S * 0.09), "D", Color("5E5238"), int(S * 0.5), false)
	if hurt > 0.01:
		draw_circle(p, R, Color(0.75, 0.2, 0.15, hurt * 0.35))
	# ATP bar under the cell
	var bw := S * 1.1
	var by := p.y + R + S * 0.28
	draw_rect(Rect2(p.x - bw / 2.0, by, bw, 4.0), Color(0.2, 0.18, 0.15, 0.55))
	draw_rect(Rect2(p.x - bw / 2.0, by, bw * clampf(c.atp / CSim.CAP, 0.0, 1.0), 4.0), Color("E2C240"))
	if labels:
		var nm: String = CS.t("founder") if kind == "founder" else CS.block_name(kind)
		_screen_text(Vector2(p.x, by + 17.0), nm, Color("D9E4DF"), 12)

func _draw_threat_warning(g: Dictionary, c: Vector2, S: float, tt: float) -> void:
	if g.wave != "warn" and g.wave != "hit":
		return
	var a: float = g.wave_a
	var pulse := 0.55 + 0.45 * sin(tt * 6.0)
	var col := Color(0.86, 0.32, 0.18, 0.35 + 0.45 * pulse)
	draw_arc(c, S * 3.7, a - 0.5, a + 0.5, 24, col, 9.0, true)
	# the front line of the attack: a ring on every cell that can be bitten
	for h in sim.front(a):
		_dashed_circle(hex_center(h), S * 0.98, col, 2.5)

func _draw_amoeba(g: Dictionary, c: Vector2, S: float, tt: float) -> void:
	var a: float = g.wave_a
	var d := Vector2(cos(a), sin(a))
	var k := 1.0
	if g.wave == "warn":
		k = clampf(1.0 - g.wave_eta / CSim.WARN_T, 0.0, 1.0)
		k = 1.0 - (1.0 - k) * (1.0 - k)
	var p := c + d * S * (7.4 - 2.0 * k)
	var r0 := S * 2.4
	var pts := PackedVector2Array()
	var contact: bool = g.wave == "hit"
	for i in 49:
		var t := float(i) / 48.0 * TAU
		var to := cos(t - (a + PI))
		var r := r0 * (1.0 + 0.1 * sin(t * 3.0 + tt * 1.3) + 0.06 * sin(t * 5.0 - tt * 1.9)) + (maxf(0.0, to) * S * 0.45 if contact else 0.0)
		pts.append(p + Vector2(r * cos(t), r * sin(t)))
	draw_colored_polygon(pts, Color(0.79, 0.60, 0.43, 0.86))
	draw_polyline(pts, INK, 2.0, true)
	var nuc := p + Vector2(S * 0.5 + S * 0.14 * sin(tt * 0.7), S * 0.5)
	draw_circle(nuc, S * 0.62, INK)
	draw_circle(nuc, S * 0.58, Color("A9784F"))

func _draw_banner(g: Dictionary) -> void:
	var txt := ""
	var warn := false
	if g.done:
		return
	if g.wave == "warn":
		txt = CS.t("cw_warn", [int(ceil(g.wave_eta))])
		warn = true
	elif g.wave == "hit":
		txt = CS.t("cw_hit")
		warn = true
	elif g.arrived:
		txt = CS.t("cw_arrived", [g.cells, g.goal_cells]) if g.cells < g.goal_cells else CS.t("cw_soon")
	else:
		return
	var fs := 18 if warn else 15
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(play_rect.get_center().x - w / 2.0 - 14.0, play_rect.position.y + 8.0), Vector2(w + 28.0, fs + 14.0))
	draw_style_box(_box(Color(0.30, 0.12, 0.08, 0.78) if warn else Color(0.06, 0.13, 0.16, 0.6)), r)
	draw_string(_font, r.position + Vector2(14, fs + 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.72, 0.55, 0.98) if warn else Color(0.91, 0.89, 0.84, 0.9))

func _draw_tip(S: float) -> void:
	if not mouse_in or tool != "" or not sim.cells.has(hover_hex):
		return
	var c: Dictionary = sim.cells[hover_hex]
	var kind: String = c.kind
	var title: String = CS.t("founder") if kind == "founder" else CS.block_name(kind)
	var role: String = CS.t("founder_role") if kind == "founder" else CS.block_role(kind)
	var inherit: String = CS.t("inherits", [int(sim.sheet.get("atp_min", 0)), int(sim.sheet.get("mem", 0))])
	var st: String = CS.t("cell_state", [snappedf(c.atp, 0.1), int(c.hp)])
	var fs := 15
	var w := 260.0
	var rh := _font.get_multiline_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	var ih := _font.get_multiline_string_size(inherit, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	var h := 12.0 + 22.0 + rh + ih + 24.0 + 12.0
	var pos := hover_pos + Vector2(16, 14)
	if pos.x + w + 24.0 > size.x:
		pos.x = hover_pos.x - w - 30.0
	if pos.y + h > size.y:
		pos.y = size.y - h - 4.0
	if _tipbox == null:
		_tipbox = StyleBoxFlat.new()
		_tipbox.bg_color = Color(0.985, 0.968, 0.925, 0.97)
		_tipbox.border_color = Color("CFC3A6")
		_tipbox.set_border_width_all(1)
		_tipbox.set_corner_radius_all(8)
	draw_style_box(_tipbox, Rect2(pos, Vector2(w + 24.0, h)))
	var y := pos.y + 26.0
	draw_string(_font, Vector2(pos.x + 12, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	y += 20.0
	draw_multiline_string(_font, Vector2(pos.x + 12, y), role, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, SUB)
	y += rh + 4.0
	draw_multiline_string(_font, Vector2(pos.x + 12, y), inherit, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, Color("2F5E99"))
	y += ih + 4.0
	draw_string(_font, Vector2(pos.x + 12, y), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("3F6B2E"))

# ---------- input
## Is the pointer off the board, for dropping a placed block to remove it?
func is_outside(local: Vector2) -> bool:
	return not play_rect.has_point(local) or not CSim.on_board(hex_at(local))

## What dropping a palette card here would do: {in_play, err, ok, hex}.
func drop_eval(kind: String, local: Vector2) -> Dictionary:
	var inp := play_rect.has_point(local)
	var h := hex_at(local)
	var err: String = "outside"
	if inp:
		err = sim.can_place(kind, h) if CSim.on_board(h) else "far"
	return {"in_play": inp, "err": err, "ok": inp and err == "", "hex": h}

## A palette card dropped on the board. Same rules as a tap: "" when placed, else the can_place code.
func drop_place(kind: String, local: Vector2) -> String:
	var h := hex_at(local)
	var err: String = sim.place(kind, h)
	if err == "":
		placed.emit(kind)
	elif err in ["atp", "locked", "far", "taken"]:
		sim.fx.append({"k": "txt", "p": h if CSim.on_board(h) else Vector2i.ZERO, "t": 0.0, "text": "no_" + err, "color": WARN})
	return err

## Esc: a block picked up from the board stays where it was.
func cancel_drag() -> bool:
	if drag_from == NONE:
		return false
	var home := hex_center(drag_from)
	_end_piece_drag()
	if ghost != null:
		ghost.send_back(home + global_position)
	return true

func _end_piece_drag() -> void:
	drag_from = NONE
	drag_out = false
	_set_cursor()

func _set_cursor() -> void:
	if drag_from != NONE:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif tool != "":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif sim != null and hover_hex != Vector2i.ZERO and sim.cells.has(hover_hex):
		mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _gui_input(ev: InputEvent) -> void:
	if sim == null:
		return
	if ev is InputEventMouseMotion:
		hover_pos = ev.position
		mouse_in = true
		hover_hex = hex_at(ev.position)
		if drag_from != NONE and ghost != null:
			drag_out = is_outside(ev.position)
			var err: String = sim.can_move(drag_from, hover_hex) if not drag_out else ""
			var txt := CS.t("dr_remove") if drag_out else (CS.drop_why(err) if err != "" else "")
			ghost.track(ev.position + global_position, err == "", txt)
		_set_cursor()
	elif ev is InputEventMouseButton:
		var h := hex_at(ev.position)
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			if tool == "del":
				sim.remove_at(h)
				_clear_tool()
			elif tool != "":
				var err: String = sim.place(tool, h)
				if err == "":
					placed.emit(tool)
					_clear_tool()
				elif err in ["atp", "locked", "far", "taken"]:
					sim.fx.append({"k": "txt", "p": h if CSim.on_board(h) else Vector2i.ZERO, "t": 0.0, "text": "no_" + err, "color": WARN})
			elif h != Vector2i.ZERO and sim.cells.has(h):
				drag_from = h
				drag_out = false
				if ghost != null:
					ghost.begin(str(sim.cells[h].kind), "colony", hex_center(h) + global_position, 1.0, hsize())
				_set_cursor()
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			if drag_from != NONE:
				_drop_piece(h, ev.position)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			if drag_from != NONE:
				cancel_drag()
			elif tool != "":
				_clear_tool()
			else:
				sim.remove_at(h)

func _drop_piece(h: Vector2i, local: Vector2) -> void:
	var from := drag_from
	var kind := str(sim.cells[from].kind) if sim.cells.has(from) else ""
	var home := hex_center(from)
	var out := is_outside(local)
	_end_piece_drag()
	if kind == "":
		if ghost != null:
			ghost.land()
		return
	if out:
		sim.remove_at(from)
		removed.emit(kind)
		if ghost != null:
			ghost.land()
	elif h != from and sim.move_block(from, h) == "":
		moved.emit(kind)
		if ghost != null:
			ghost.land()
	elif ghost != null:
		if h == from:
			ghost.land()
		else:
			ghost.send_back(home + global_position)

func _clear_tool() -> void:
	tool = ""
	tool_cleared.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse_in = false
		if drag_from != NONE:
			cancel_drag()
