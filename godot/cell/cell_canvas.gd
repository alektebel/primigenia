extends Control
## Draws the cell stage (a port of the prototype's canvas drawing) and turns the mouse into sim actions.
## Everything is drawn in the sim's 720 space through one transform (zoom follows the cell); text is drawn in screen space.

const Sim := preload("res://cell/cell_sim.gd")
const CS := preload("res://cell/cell_strings.gd")

signal placed(kind: String)
signal tool_cleared
signal removed(kind: String)

const INK := Color("3A352D")
const SUB := Color("6A6356")
const PHOS := Color("9179C9")
const ATPY := Color("E2C240")
const WARN := Color("9E392C")
const LIGHT := Color("E9E4D6")
const STC := {"trabaja": Color("5E9E4A"), "recibe": Color("6F93C4"), "sin entrada": Color("8E8A82"), "atasco": Color("D08A2E"), "inhibida": Color("D08A2E"), "falta ATP": Color("C0392B"), "bloqueada": Color("7A5BB8"), "secuestrada": Color("5FA36B"), "oxidada": Color("B4382F"), "listo": Color("8EA38A")}
const STT := {"trabaja": Color("3F6B2E"), "recibe": Color("2F5E99"), "sin entrada": Color("6A6356"), "atasco": Color("9A5A12"), "inhibida": Color("9A5A12"), "falta ATP": Color("9E392C"), "montando": Color("6A6356"), "bloqueada": Color("5B3F96"), "secuestrada": Color("3F7A4A"), "oxidada": Color("9E392C"), "listo": Color("5E7A5A")}
const HC := [Color("9DB56A"), Color("CFAE55"), Color("C4703C"), Color("9E392C")]

var sim
var tool := ""            # "", "del" or a piece kind
var labels := true
var paused := false
var still := false
var play_rect := Rect2(0, 0, 800, 720)   # where the cell is shown (the part of the screen not under the side column)
var hover_piece = null
var hover_pos := Vector2.ZERO
var mouse_in := false
var drag = null           # a placed piece being moved with the pointer
var drag_out := false     # ... and it is out of the cell: releasing removes it
var drag_kind := ""       # a tool card is being dragged over the cell (set by the stage)
var drag_pos := Vector2.ZERO   # ... where its pointer is, canvas coordinates
var _drag_from_a := 0.0
var _drag_from_pos := Vector2.ZERO
var t_draw := 0.0         # animation clock (keeps running while paused)
var _crowd: Array = []
var _font: Font
var _font_bold: Font
var _door_box := StyleBoxFlat.new()
var _S := 1.0
var _origin := Vector2.ZERO
var _base := Transform2D()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load("res://ui/fonts/AlegreyaSans-Medium.ttf")
	_font_bold = _font
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var cols := [Color("E6D3AC"), Color("CBD7E3"), Color("DCCFE6"), Color("E9DCC0"), Color("D9E2C4")]
	for i in 150:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.84
		_crowd.append({"u": Vector2(cos(a), sin(a)) * r, "rot": rng.randf() * 3.0, "rx": rng.randf_range(2, 5.5), "ry": rng.randf_range(1.6, 4.0), "c": cols[i % 5]})
	_door_box.set_corner_radius_all(5)
	_door_box.set_border_width_all(1)
	_door_box.border_color = INK
	_door_box.anti_aliasing = true

func _process(delta: float) -> void:
	t_draw += delta
	queue_redraw()

# ---------- transform helpers
func _update_base() -> void:
	var k := minf(play_rect.size.x, play_rect.size.y) / 720.0
	_S = k * sim.zoom
	_origin = play_rect.get_center()
	_base = Transform2D(Vector2(_S, 0), Vector2(0, _S), _origin - Sim.CENTER * _S)

func to_sim(p: Vector2) -> Vector2:
	return Sim.CENTER + (p - _origin) / _S

func to_screen(p: Vector2) -> Vector2:
	return _origin + (p - Sim.CENTER) * _S

func _local(pos: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform_matrix(_base * Transform2D(rot, pos).scaled_local(sc))

func _world() -> void:
	draw_set_transform_matrix(_base)

func _screen() -> void:
	draw_set_transform_matrix(Transform2D())

func _fk() -> float:
	return minf(play_rect.size.x, play_rect.size.y) / 720.0

# ---------- primitives (sim units)
func bead(p: Vector2, r: float, fill: Color, lw: float = 1.0) -> void:
	draw_circle(p, r + lw * 0.5, INK)
	draw_circle(p, maxf(r - lw * 0.5, 0.1), fill)

func ring(p: Vector2, r: float, col: Color, w: float) -> void:
	draw_arc(p, r, 0, TAU, 40, col, w, true)

func dashed_circle(p: Vector2, r: float, col: Color, w: float, dash: float, gap: float) -> void:
	var circ := TAU * r
	var n := maxi(int(circ / (dash + gap)), 4)
	for i in n:
		var a0 := float(i) / n * TAU
		draw_arc(p, r, a0, a0 + dash / r, 4, col, w, true)

func tag(sp: Vector2, text: String, col: Color, size: float = 11.0, bold: bool = false) -> void:
	_screen()
	var fs := int(clampf(size * _fk() * 1.3, 11.0, 30.0))
	var s := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var q := to_screen(sp) - Vector2(s.x / 2.0, 0)
	draw_string_outline(_font, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, Color(0.07, 0.15, 0.18, 0.55) if col.get_luminance() > 0.6 else Color(0.98, 0.95, 0.88, 0.7))
	draw_string(_font, q, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_world()

func radial(c: Vector2, r_out: float, c_out: Color, c_in: Color, shift: Vector2, steps: int = 10) -> void:
	for i in steps:
		var f := float(i) / (steps - 1)
		draw_circle(c + shift * f, r_out * (1.0 - f * 0.92), c_out.lerp(c_in, f))

func back(t: float) -> float:
	var c := 1.70158
	t = clampf(t, 0.0, 1.0) - 1.0
	return 1.0 + (c + 1.0) * t * t * t + c * t * t

# ---------- main draw
func _draw() -> void:
	if sim == null:
		return
	_update_base()
	var T: float = sim.T if not paused else sim.T
	var tt := t_draw
	var sz := size
	# water
	draw_rect(Rect2(Vector2.ZERO, sz), Color("0F2229"))
	var wc := play_rect.get_center()
	var wr := maxf(sz.x, sz.y) * 0.75
	for i in 14:
		var f := float(i) / 13.0
		draw_circle(wc, wr * (1.0 - f * 0.8), Color("0F2229").lerp(Color("2E5560"), f))
	var kk := _fk()
	for i in 40:
		var x := fposmod(i * 97.3 * sz.x / 720.0 - tt * (6 + i % 5) * kk, sz.x)
		var y := fposmod(i * 53.7 * sz.y / 720.0 + sin(tt * 0.4 + i) * 8.0, sz.y)
		draw_circle(Vector2(x, y), (1.6 + (i % 3) * 0.5) * maxf(kk, 0.8), Color(0.56, 0.72, 0.72, 0.4))
	_draw_weather(sz, tt)
	_world()
	var ag: Dictionary = sim.aggregation()
	if ag.active:
		_draw_neighbors(ag)
	var br := 0.0 if still else sin(tt * 0.8) * 1.5
	var m0: float = sim.mid()
	_cell_body(Sim.CENTER, sim.RO, sim.RI, br, 0.85)
	var fw: float = sim.flw()
	for f in sim.pieces:
		if f.type == "fl":
			draw_arc(Sim.CENTER, m0, f.a - fw, f.a + fw, 24, Color(0.37, 0.56, 0.24, 0.2 if f.built else 0.08), sim.RO - sim.RI + 26.0, false)
	for p in sim.pulses:
		var w := 32.0 / m0
		var c: Color = p.c
		c.a = (1.0 - p.t) * 0.7
		draw_arc(Sim.CENTER, m0, p.a - w, p.a + w, 16, c, sim.RO - sim.RI + 14.0 + p.t * 14.0, false)
	var da: Array = sim.pieces.filter(func(q): return sim.is_mem(q))
	_draw_lipids(da, br, tt)
	for d in da:
		if d.type == "spn":
			_draw_spines(d, T)
		else:
			_draw_door(d, T)
	if sim.phase >= 5:
		_draw_genome(tt)
		_draw_warn_marks(tt)
	# links of the glycolysis chain
	for i in 2:
		for a in sim.pieces.filter(func(q): return q.type == Sim.ORDER[i]):
			var b = sim.nearest(sim.pieces.filter(func(q): return q.type == Sim.ORDER[i + 1]), a.pos)
			if b != null:
				_dashed_line(a.pos, b.pos, Color(0.42, 0.39, 0.34, 0.45))
	if tool != "" and tool != "del" and mouse_in:
		_draw_ghost()
	if drag_kind != "":
		_draw_drop_hint()
	for p in sim.pieces:
		if not sim.is_mem(p):
			_draw_enz(p, T, tt)
	for m in sim.mols:
		_draw_mol(m, tt)
	for f in sim.phages:
		_draw_phage(f)
	if sim.amoeba != null:
		_draw_amoeba(sim.amoeba, tt)
	_draw_threat_banner()
	for f in sim.fx:
		if f.k == "ring":
			var p: float = f.t / 0.55
			var c2: Color = f.color
			c2.a = 1.0 - p
			ring(f.p, (16.0 if f.big else 10.0) + p * (34.0 if f.big else 22.0), c2, 3.0 * (1.0 - p) + 0.5)
		elif f.k == "txt":
			var p3: float = f.t / 1.1
			var c3: Color = f.color
			c3.a = 1.0 - p3 * p3
			tag(f.p + Vector2(0, -p3 * 26.0), CS.fx_text(f.text), c3, 13.0, true)
	_screen()
	for f in sim.fx:
		if f.k == "big":
			var p4: float = f.t / 2.6
			var txt := CS.t("grew", [f.tier])
			var fs := 22
			var w2 := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var a4 := minf(1.0, (1.0 - p4) * 3.0)
			var r := Rect2(Vector2(play_rect.get_center().x - w2 / 2.0 - 16.0, play_rect.position.y + 74.0), Vector2(w2 + 32.0, 40))
			draw_style_box(_box(Color(0.98, 0.97, 0.925, 0.94 * a4)), r)
			draw_string(_font, r.position + Vector2(16, 28), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.25, 0.42, 0.18, a4))
	if tool != "" and tool != "del":
		var msg := CS.t("tap_membrane") if Sim.PIECES[tool].has("mem") else CS.t("tap_inside")
		_center_text(msg, play_rect.end.y - 26.0, 16, Color(0.91, 0.89, 0.84, 0.95))
	elif tool == "del":
		_center_text(CS.t("remove"), play_rect.end.y - 26.0, 16, Color(0.91, 0.89, 0.84, 0.95))
	if paused:
		_center_text(CS.t("paused"), play_rect.position.y + 24.0, 18, Color(0.98, 0.9, 0.55, 0.95))
	_draw_hover_tip()
	_draw_remove_hint()

## A placed piece dragged out of the cell: it reddens and says what releasing does.
func _draw_remove_hint() -> void:
	if drag == null or not drag_out:
		return
	_screen()
	var sp: Vector2 = to_screen(sim.ppos(drag))
	draw_arc(sp, 26.0 * _S, 0, TAU, 40, Color("E06A5A"), 3.0, true)
	var tp := Vector2(clampf(hover_pos.x, play_rect.position.x + 90.0, play_rect.end.x - 90.0), clampf(hover_pos.y, play_rect.position.y + 20.0, play_rect.end.y - 50.0))
	tag(to_sim(tp + Vector2(0, 38.0)), CS.t("dr_remove"), Color("F2A59A"), 15.0, true)

func _box(c: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = c
	b.set_corner_radius_all(10)
	return b

func _center_text(txt: String, y: float, fs: int, col: Color) -> void:
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(_font, Vector2(play_rect.get_center().x - w / 2.0, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)

func _dashed_line(a: Vector2, b: Vector2, col: Color) -> void:
	draw_dashed_line(a, b, col, 1.0, 4.0)

func _cell_body(c: Vector2, ro: float, ri: float, br: float, halo: float) -> void:
	# soft halo
	for i in 6:
		var f := float(i) / 5.0
		draw_circle(c, ro + 6.0 + br + (1.0 - f) * 26.0, Color(0.85, 0.94, 0.86, halo * 0.05))
	radial(c, ro + 6.0 + br, Color("EAD9B2"), Color("FBF2DC"), Vector2(-30, -40), 12)
	var cr := ri - 8.0
	for cd in _crowd:
		_local(c + cd.u * cr, cd.rot, Vector2(cd.rx, cd.ry))
		draw_circle(Vector2.ZERO, 1.0, Color(cd.c, 0.6))
	_world()
	# wall shade
	for i in 6:
		var f2 := float(i) / 5.0
		var rr := ri - 46.0 * (1.0 - f2) + 4.0
		draw_arc(c, rr, 0, TAU, 96, Color(0.23, 0.21, 0.18, 0.035 + 0.035 * f2), 9.0, true)
	draw_arc(c, (ro + ri) / 2.0 + br, 0, TAU, 128, Color("E9DDB6"), ro - ri, true)

func _draw_lipids(da: Array, br: float, tt: float) -> void:
	var m0: float = sim.mid()
	var skips: Array = []
	for t in da:
		skips.append([t.a, ((23 if t.type == "fl" else 30) + 3) / m0])
	var heads := [[], [], [], []]
	var tails := PackedVector2Array()
	var C := Sim.CENTER
	for pr in [[sim.RO, -1], [sim.RI, 1]]:
		var Rb: float = pr[0]
		var dir: int = pr[1]
		var n := int(round(TAU * Rb / 7.4))
		for i in n:
			var a: float = float(i) / n * TAU + sim.phi
			var sk := false
			for s in skips:
				if sim.adiff(a, s[0]) < s[1]:
					sk = true
					break
			if sk:
				continue
			var v: float = sim.integ[sim.lidx(a)]
			if v <= 0.0:
				continue
			var w := 0.0 if still else sin(tt * 1.7 + i * 1.9) * 1.3
			var c := cos(a)
			var s2 := sin(a)
			var r := Rb + w + br
			heads[0 if v > 0.8 else (1 if v > 0.5 else (2 if v > 0.25 else 3))].append(C + Vector2(c, s2) * r)
			for o in [-1.9, 1.9]:
				tails.append(C + Vector2(c * (r + dir * 5) - s2 * o, s2 * (r + dir * 5) + c * o))
				tails.append(C + Vector2(c * (r + dir * 17) - s2 * o * 1.2, s2 * (r + dir * 17) + c * o * 1.2))
	if tails.size() > 0:
		draw_multiline(tails, Color("CDBB7C"), 2.0, true)
	for b in 4:
		for p in heads[b]:
			draw_circle(p, 4.4, INK)
		for p in heads[b]:
			draw_circle(p, 3.6, HC[b])

func _draw_door(p, T: float) -> void:
	var d: Dictionary = Sim.PIECES[p.type]
	var k := back((T - p.born) / 0.35) if p.built else 1.0
	var ln := 46.0 if p.type == "fl" else 60.0
	var open: float = p.open
	var col: Color = d.col
	if not p.built:
		col.a = 0.35
	_door_box.bg_color = col
	_door_box.border_color = Color(INK, col.a)
	for s in [-1, 1]:
		var xf := Transform2D(p.a, Sim.CENTER) * Transform2D(0.0, Vector2(sim.mid(), 0)) * Transform2D(0.0, Vector2(k, k)) \
			* Transform2D(s * open * 0.22, Vector2(0, s * 2))
		draw_set_transform_matrix(_base * xf)
		draw_style_box(_door_box, Rect2(-ln / 2.0, 0.0 if s > 0 else -11.0, ln, 11.0))
	_world()
	if not p.built:
		var q: Vector2 = sim.pol(sim.RO + 34.0, p.a)
		tag(q + Vector2(0, 4), "%d/%d ATP" % [p.got, d.c], LIGHT)

func _draw_enz(e, T: float, tt: float) -> void:
	var d: Dictionary = Sim.PIECES[e.type]
	var k := back((T - e.born) / 0.35) if e.built else 1.0
	var sx := 1.0
	var sy := 1.0
	if e.proc >= 0.0:
		var j := sin(e.proc * 40.0) * 0.07
		sx = 1.0 + j
		sy = 1.0 - j
	elif e.pulse > 0.0:
		var j2 := sin(e.pulse * PI) * 0.22
		sx = 1.0 + j2
		sy = 1.0 - j2
	_local(e.pos + e.off, 0.0 if still else sin(tt * 1.1 + e.ph) * 0.06, Vector2(k * sx, k * sy))
	var al := 1.0 if e.built else 0.35
	if e.built:
		for l in d.lobes:
			draw_circle(Vector2(l[0], l[1] + 4.0), l[2] + 2.0, Color(0.23, 0.21, 0.18, 0.18))
	for l in d.lobes:
		draw_circle(Vector2(l[0], l[1]), l[2] + 1.3, Color(INK, al))
	var col: Color = d.col
	if e.hij > 0.0:
		col = Color("8FC79A")
	elif e.abx > 0:
		col = Color("B9B2A6")
	elif e.ox > 0.0:
		col = col.lerp(Color("B4382F"), 0.45)
	col.a = al
	for l in d.lobes:
		draw_circle(Vector2(l[0], l[1]), l[2], col)
	_world()
	if not e.built:
		tag(e.pos + Vector2(0, -28), "%d/%d ATP" % [e.got, d.c], SUB)
		return
	bead(e.pos + Vector2(17, -15), 4.5, STC.get(e.st, Color("8E8A82")))
	if e.st == "inhibida" or e.st == "atasco" or e.st == "falta ATP" or e.st == "bloqueada" or e.st == "secuestrada" or e.st == "oxidada":
		var rc := Color(0.75, 0.22, 0.17, 0.45 + 0.4 * sin(tt * 6.0)) if (e.st == "falta ATP" or e.st == "secuestrada" or e.st == "oxidada") else Color(0.82, 0.54, 0.18, 0.75)
		if e.st == "bloqueada":
			rc = Color(0.48, 0.36, 0.72, 0.8)
		dashed_circle(e.pos, 27.0, rc, 2.0, 5.0, 4.0)
		tag(e.pos + Vector2(0, -32), CS.status(e.st), STT[e.st], 11.0, true)
	if labels:
		tag(e.pos + Vector2(0, 34), "%s · %d %%" % [CS.piece_name(Sim.PIECES, e.type), int(round(e.u * 100.0))], SUB, 11.0)

func _hexpts(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := PI / 6.0 + i * PI / 3.0
		pts.append(Vector2(s * cos(a), s * sin(a)))
	return pts

func _draw_mol(m, tt: float) -> void:
	var x: Vector2 = m.p
	var al: float = m.alpha
	if al <= 0.01:
		return
	match m.type:
		"glu", "g6p":
			_local(x, 0.0 if still else sin(tt * 1.3 + m.ph) * 0.25)
			var hp := _hexpts(7.5)
			draw_colored_polygon(hp, Color(1, 1, 1, al))
			var cl := PackedVector2Array(hp)
			cl.append(hp[0])
			draw_polyline(cl, Color(INK, al), 1.4, true)
			if m.type == "g6p":
				bead(Vector2(9, -5), 3.2, Color(PHOS, al))
				bead(Vector2(-9, 5), 3.2, Color(PHOS, al))
			_world()
		"tri":
			_local(x, m.ph + tt * 0.6)
			var tp := PackedVector2Array([Vector2(-7, 4), Vector2(-3.5, -4), Vector2(3.5, -4), Vector2(7, 4)])
			draw_colored_polygon(tp, Color("E8D2A6"))
			var tc := PackedVector2Array(tp)
			tc.append(tp[0])
			draw_polyline(tc, INK, 1.3, true)
			bead(Vector2(7, 5), 2.8, PHOS)
			_world()
		"pyr":
			var pp := PackedVector2Array([x + Vector2(0, -6), x + Vector2(6, 5), x + Vector2(-6, 5)])
			draw_colored_polygon(pp, Color("E3A777", al))
			draw_polyline(PackedVector2Array([pp[0], pp[1], pp[2], pp[0]]), Color(INK, al), 1.2, true)
		"lac":
			bead(x, 5.0, Color(Color("D9806F"), al))
		"lip":
			var a: float = m.ph + tt * 0.8
			var c := cos(a)
			var s := sin(a)
			for o in [-1.9, 1.9]:
				draw_line(x + Vector2(-s * o, c * o), x + Vector2(-c * 13 - s * o, -s * 13 + c * o), Color("CDBB7C"), 2.0, true)
			bead(x + Vector2(c * 3, s * 3), 4.0, Color("9DB56A"))
		"ros":
			var pts := PackedVector2Array()
			for i in 10:
				var aa := i * TAU / 10.0 + tt * 3.0
				var r: float = 3.4 if i % 2 == 1 else 7.5
				pts.append(x + Vector2(cos(aa), sin(aa)) * r)
			draw_colored_polygon(pts, Color("B4382F"))
			var pc := PackedVector2Array(pts)
			pc.append(pts[0])
			draw_polyline(pc, INK, 1.0, true)
		"dna", "frag":
			var sp2: float = maxf(m.v.length(), 0.0001)
			var u2: Vector2 = -m.v / sp2 if m.type == "dna" else -Vector2.from_angle(m.ph)
			var n2 := 5 if m.type == "dna" else 2
			var pts2 := PackedVector2Array()
			for i in n2:
				var w2 := sin(tt * 10.0 + i * 1.4) * 3.0
				pts2.append(x + u2 * i * 5.0 + Vector2(-u2.y, u2.x) * w2)
			if pts2.size() > 1:
				draw_polyline(pts2, Color(INK, al), 5.0, true)
				draw_polyline(pts2, Color(Color("5FA36B"), al), 2.8, true)
		"baby":
			_local(x)
			draw_colored_polygon(_hexpts(6.0), Color(Color("8FC79A"), al))
			var hp2 := _hexpts(6.0)
			hp2.append(hp2[0])
			draw_polyline(hp2, Color(INK, al), 1.2, true)
			_world()
		"abx":
			var dp := PackedVector2Array([x + Vector2(0, -9.0), x + Vector2(7.5, 0), x + Vector2(0, 9.0), x + Vector2(-7.5, 0)])
			draw_colored_polygon(dp, Color(Color("7A5BB8"), al))
			dp.append(dp[0])
			draw_polyline(dp, Color(INK, al), 1.1, true)
		_:
			var sp: float = maxf(m.v.length(), 0.0001)
			var u: Vector2 = -m.v / sp
			draw_circle(x, 11.0, Color(0.89, 0.76, 0.25, 0.22 * al))
			for i in range(3, 0, -1):
				var w := 0.0 if still else sin(tt * 9.0 + m.ph + i) * 1.6
				bead(x + u * (4.0 + i * 4.6) + Vector2(-u.y, u.x) * w, 2.3, Color(PHOS, al))
			bead(x, 5.0, Color(ATPY, al))

## While a card is dragged: where the piece can go. Membrane pieces light the ring and snap to the point of it nearest
## the pointer; enzymes light the cytoplasm. Nothing snaps when the spot is refused (the ghost under the pointer is red).
func _draw_drop_hint() -> void:
	var d: Dictionary = Sim.PIECES[drag_kind]
	var col: Color = d.col
	var pulse := 0.5 if still else 0.5 + 0.5 * sin(t_draw * 4.0)
	var good: bool = sim.can_place(drag_kind, to_sim(drag_pos)) == ""
	if d.has("mem"):
		var mid: float = sim.mid()
		var band: float = sim.RO - sim.RI + 56.0
		draw_arc(Sim.CENTER, mid, 0, TAU, 120, Color(col.r, col.g, col.b, 0.26 + 0.12 * pulse), band, true)
		dashed_circle(Sim.CENTER, mid, Color(1.0, 0.98, 0.9, 0.8 + 0.2 * pulse), 4.0, 16.0, 10.0)
	else:
		var rr: float = sim.RI - 8.0
		draw_circle(Sim.CENTER, rr, Color(col.r, col.g, col.b, 0.07 + 0.05 * pulse))
		dashed_circle(Sim.CENTER, rr, Color(0.97, 0.95, 0.88, 0.5 + 0.25 * pulse), 2.5, 10.0, 8.0)
	if good:
		_draw_ghost_at(drag_kind, to_sim(drag_pos), 0.85)

func _draw_ghost() -> void:
	_draw_ghost_at(tool, to_sim(hover_pos), 0.4)

func _draw_ghost_at(kind: String, sp: Vector2, alpha: float) -> void:
	var d: Dictionary = Sim.PIECES[kind]
	var col: Color = d.col
	col.a = alpha
	if d.has("mem"):
		var a := atan2(sp.y - Sim.CY, sp.x - Sim.CX)
		var r: float = sim.rad(sp)
		if r > sim.RI - 50.0 and r < sim.RO + 70.0:
			var q: Vector2 = sim.pol(sim.mid(), a)
			ring(q, 22.0, col, 4.0)
	else:
		if sim.rad(sp) < sim.RI - 8.0:
			var pp := sp
			var r2: float = sim.rad(pp)
			var mx: float = sim.RI - 40.0
			if r2 > mx:
				pp = Sim.CENTER + (pp - Sim.CENTER) * mx / r2
			for l in d.lobes:
				draw_circle(pp + Vector2(l[0], l[1]), l[2], col)

func _draw_neighbors(ag: Dictionary) -> void:
	var t: float = ag.t
	var e := minf(1.0, t / 4.0)
	var k := e * e * (3.0 - 2.0 * e)
	var D: float = (2.0 * sim.RO + 14.0) * (1.9 - 0.9 * k)
	var fade: float = ag.fade
	var al := (maxf(0.0, 1.0 - fade / 1.5) if fade >= 0.0 else 1.0) * minf(1.0, t)
	for j in 6:
		var a := j * TAU / 6.0 + TAU / 12.0
		var c := Sim.CENTER + Vector2(cos(a), sin(a)) * D
		_cell_body_alpha(c, sim.RO, sim.RI, al)
		var n := int(round(TAU * sim.RO / 12.0))
		for i in n:
			var b := float(i) / n * TAU
			bead(c + Vector2(cos(b), sin(b)) * sim.RO, 3.8, Color(Color("9DB56A"), al), 0.8)
		if t > 4.2:
			for q in range(-2, 3):
				var bb := a + q * 0.05
				var p1: Vector2 = sim.pol(sim.RO + 2.0, bb)
				var p2: Vector2 = c + Vector2(cos(bb + PI), sin(bb + PI)) * (sim.RO + 2.0)
				draw_line(p1, p2, Color(INK, al), 6.0, true)
				draw_line(p1, p2, Color(Color("E68FB5"), al), 3.4, true)

func _cell_body_alpha(c: Vector2, ro: float, ri: float, al: float) -> void:
	radial(c, ro + 6.0, Color(Color("EAD9B2"), al), Color(Color("FBF2DC"), al), Vector2(-30, -40), 10)
	draw_arc(c, (ro + ri) / 2.0, 0, TAU, 96, Color(Color("E9DDB6"), al), ro - ri, true)

func _draw_hover_tip() -> void:
	if hover_piece == null or not mouse_in or tool != "" or drag != null:
		return
	var p = hover_piece
	var title: String = CS.piece_name(Sim.PIECES, p.type)
	var role: String = CS.role(Sim.PIECES, p.type)
	var st := ""
	if not sim.is_mem(p):
		st = CS.status(p.st if p.built else "montando") + (" · %d %%" % int(round(p.u * 100.0)) if p.built else "")
	_screen()
	var fs := 15
	var w := 250.0
	var rh := _font.get_multiline_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y
	var h := 12.0 + 20.0 + rh + (20.0 if st != "" else 0.0) + 8.0
	var pos := hover_pos + Vector2(16, 14)
	if pos.x + w + 24.0 > size.x:
		pos.x = hover_pos.x - w - 30.0
	if pos.y + h > size.y:
		pos.y = size.y - h - 4.0
	draw_style_box(_tip_box(), Rect2(pos, Vector2(w + 24.0, h)))
	var y := pos.y + 24.0
	draw_string(_font, Vector2(pos.x + 12, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	y += 6.0
	draw_multiline_string(_font, Vector2(pos.x + 12, y + 14.0), role, HORIZONTAL_ALIGNMENT_LEFT, w, fs, -1, SUB)
	if st != "":
		draw_string(_font, Vector2(pos.x + 12, y + 14.0 + rh + 4.0), st, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, STT.get(p.st, SUB))
	_world()

var _tipbox: StyleBoxFlat
func _tip_box() -> StyleBoxFlat:
	if _tipbox == null:
		_tipbox = StyleBoxFlat.new()
		_tipbox.bg_color = Color(0.985, 0.968, 0.925, 0.97)
		_tipbox.border_color = Color("CFC3A6")
		_tipbox.set_border_width_all(1)
		_tipbox.set_corner_radius_all(8)
	return _tipbox

# ---------- input
## Is the pointer (canvas coordinates) out of the cell, for dropping a placed piece to remove it?
func is_outside(local: Vector2) -> bool:
	return not play_rect.has_point(local) or sim.rad(to_sim(local)) > sim.RO + 80.0

## What dropping a card here would do: {in_play, err, ok}. err is a CellSim.can_place code.
func drop_eval(kind: String, local: Vector2) -> Dictionary:
	var inp := play_rect.has_point(local)
	var err: String = sim.can_place(kind, to_sim(local)) if inp else "outside"
	return {"in_play": inp, "err": err, "ok": inp and err == ""}

## A card dropped on the cell. Same rules as a tap: returns "" when placed, else the can_place code.
func drop_place(kind: String, local: Vector2) -> String:
	var sp := to_sim(local)
	var err: String = sim.place(kind, sp)
	if err == "":
		placed.emit(kind)
	elif err == "need_rib":
		sim.float_text(sp + Vector2(0, -20), "need_rib", WARN)
	return err

func scale_px() -> float:
	_update_base()
	return _S

## Esc (or the card drag ending elsewhere): a placed piece goes back where it was picked up.
func cancel_drag() -> bool:
	if drag == null:
		return false
	if sim.is_mem(drag):
		drag.a = _drag_from_a
	else:
		drag.pos = _drag_from_pos
	drag = null
	drag_out = false
	_set_cursor()
	return true

func _set_cursor() -> void:
	if drag != null:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	elif tool != "":
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	elif hover_piece != null:
		mouse_default_cursor_shape = Control.CURSOR_CAN_DROP
	else:
		mouse_default_cursor_shape = Control.CURSOR_ARROW

func _gui_input(ev: InputEvent) -> void:
	if sim == null:
		return
	if ev is InputEventMouseMotion:
		hover_pos = ev.position
		mouse_in = true
		var sp := to_sim(ev.position)
		if drag != null:
			sim.move_piece(drag, sp)
			drag_out = is_outside(ev.position)
		else:
			hover_piece = sim.piece_at(sp)
		_set_cursor()
	elif ev is InputEventMouseButton:
		var sp2 := to_sim(ev.position)
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			var h = sim.piece_at(sp2)
			if tool == "del":
				if h != null:
					sim.remove_piece(h)
				_clear_tool()
			elif tool != "":
				var err: String = sim.place(tool, sp2)
				if err == "":
					placed.emit(tool)
					_clear_tool()
				elif err == "need_rib":
					sim.float_text(sp2 + Vector2(0, -20), "need_rib", WARN)
			elif h != null:
				drag = h
				drag_out = false
				_drag_from_a = h.a
				_drag_from_pos = h.pos
				_set_cursor()
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			if drag != null and drag_out:
				var k: String = drag.type
				sim.remove_piece(drag)
				removed.emit(k)
			drag = null
			drag_out = false
			hover_piece = null if hover_pos != ev.position else sim.piece_at(sp2)
			_set_cursor()
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			if tool != "":
				_clear_tool()
			else:
				sim.remove_at(sp2)

func _clear_tool() -> void:
	tool = ""
	tool_cleared.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		mouse_in = false
		drag = null
		drag_out = false

# ---------- phase 5: threat drawing (ported from art/reference/cell/malos-tiempos.html)
func _draw_weather(sz: Vector2, tt: float) -> void:
	if sim.tide > 0.01:
		# the antibiotic tide: purple water coming in from the right, specks carried with it
		var n := 12
		for i in n:
			var f := float(i) / n
			var x0: float = sz.x * (1.0 - 0.55 * sim.tide) + sz.x * 0.55 * sim.tide * f
			draw_rect(Rect2(x0, 0, sz.x - x0, sz.y), Color(0.48, 0.34, 0.72, 0.045 + 0.05 * sim.tide))
		for i in 30:
			var y := fposmod(i * 61.7 + sin(tt * 0.6 + i) * 10.0, sz.y)
			var x := fposmod(sz.x - fposmod(tt * (30.0 + i % 4 * 8.0) + i * 83.0, sz.x * 0.6), sz.x)
			draw_rect(Rect2(x, y, 7, 3), Color(0.55, 0.42, 0.85, 0.5 * sim.tide))
	if sim.flash > 0.01:
		var pulse := 0.5 + 0.5 * sin(tt * 7.0)
		draw_rect(Rect2(Vector2.ZERO, sz), Color(0.85, 0.25, 0.15, 0.10 * sim.flash * (0.4 + 0.6 * pulse)))

func _draw_genome(tt: float) -> void:
	var g: Vector2 = Sim.GENOME
	var pulse: float = sim._genome_p.hij
	draw_arc(g, 24.0, 0, TAU, 40, INK, 7.0, true)
	draw_arc(g, 24.0, 0, TAU, 40, Color("D99A3C"), 4.6, true)
	if sim.cas_primed:
		draw_arc(g, 24.0, -0.9, -0.5, 8, Color("5FA36B"), 4.6, true)
	if pulse > 0.0:
		dashed_circle(g, 32.0, Color(0.75, 0.22, 0.17, 0.45 + 0.4 * sin(tt * 6.0)), 2.0, 5.0, 4.0)
	tag(g + Vector2(0, 3), CS.t("genome"), INK, 11.0, true)

func _draw_spines(p, T: float) -> void:
	var k := back((T - p.born) / 0.35) if p.built else 1.0
	var al := 1.0 if p.built else 0.35
	var base: float = sim.RO + 2.0
	for i in 5:
		var a: float = p.a + (i - 2) * 0.115
		var c := Vector2(cos(a), sin(a))
		var n := Vector2(-c.y, c.x)
		var tip: Vector2 = Sim.CENTER + c * (base + 30.0 * k)
		var b0: Vector2 = Sim.CENTER + c * (base - 4.0) - n * 6.0
		var b1: Vector2 = Sim.CENTER + c * (base - 4.0) + n * 6.0
		var tri := PackedVector2Array([b0, tip, b1])
		draw_colored_polygon(tri, Color(0.55, 0.49, 0.35, al))
		draw_polyline(PackedVector2Array([b0, tip, b1]), Color(INK, al), 1.4, true)
	_world()
	if not p.built:
		var q: Vector2 = sim.pol(sim.RO + 44.0, p.a)
		tag(q, "%d/%d ATP" % [p.got, Sim.PIECES[p.type].c], LIGHT)

func _draw_phage(f) -> void:
	var a := atan2(Sim.CY - f.y, Sim.CX - f.x)
	var al: float = f.al
	_local(Vector2(f.x, f.y), a, Vector2(1.25, 1.25))
	var down: bool = f.state == "land" or f.state == "empty"
	var ink := Color(INK, al)
	for s in [-1, 0, 1]:
		draw_line(Vector2(14, 0), Vector2(26 if down else 20, s * (13 if down else 8)), ink, 1.8, true)
	draw_rect(Rect2(0, -3.5, 16, 7), Color(0.79, 0.76, 0.71, al))
	draw_rect(Rect2(0, -3.5, 16, 7), ink, false, 1.6)
	var hp := _hexpts(12.0)
	for i in hp.size():
		hp[i] += Vector2(-10, 0)
	var empty: bool = f.state == "empty" or f.state == "gone"
	draw_colored_polygon(hp, Color(Color("DCEBDD") if empty else Color("8FC79A"), al))
	var hc := PackedVector2Array(hp)
	hc.append(hp[0])
	draw_polyline(hc, ink, 1.9, true)
	if not empty:
		draw_polyline(PackedVector2Array([Vector2(-15, -3), Vector2(-10, 3), Vector2(-5, -3)]), Color(Color("3F7A4A"), al), 2.0, true)
	_world()

func _draw_amoeba(am, tt: float) -> void:
	var a := atan2(am.y - Sim.CY, am.x - Sim.CX)
	var k := 0.85
	_local(Vector2(am.x, am.y), 0.0, Vector2(k, k))
	var pts := PackedVector2Array()
	for i in 49:
		var t := float(i) / 48.0 * TAU
		var to := cos(t - (a + PI))
		var r := 150.0 * (1.0 + 0.1 * sin(t * 3.0 + tt * 1.3) + 0.06 * sin(t * 5.0 - tt * 1.9)) + (maxf(0.0, to) * 26.0 if am.contact else 0.0)
		pts.append(Vector2(r * cos(t), r * sin(t)))
	draw_colored_polygon(pts, Color(0.79, 0.60, 0.43, 0.86))
	draw_polyline(pts, INK, 2.0, true)
	var nuc := Vector2(30.0 + 8.0 * sin(tt * 0.7), 30.0)
	draw_circle(nuc, 35.0, INK)
	draw_circle(nuc, 33.0, Color("A9784F"))
	for v in [[-50, 40, 14], [60, -50, 11], [-30, -60, 9], [-80, -20, 8]]:
		var c := Vector2(v[0] + 3.0 * sin(tt + v[0]), v[1])
		draw_circle(c, v[2] + 1.0, INK)
		draw_circle(c, v[2], Color("E7C9A6"))
	_world()

func _draw_threat_banner() -> void:
	if sim.phase < 5:
		return
	var th: Dictionary = sim.threat_info()
	if not th.on or th.done:
		return
	var warn: bool = th.stage == "warn" or th.stage == "hit"
	var txt := ""
	var col := Color(0.98, 0.9, 0.55, 0.96)
	if warn:
		txt = CS.t("w_" + th.kind, [int(ceil(th.eta))]) if th.stage == "warn" else CS.t("hit_" + th.kind)
		col = Color(1.0, 0.72, 0.55, 0.98)
	elif th.stage == "settle":
		txt = CS.t("settle_t", [th.min])
	else:
		txt = CS.t("next_t", [CS.t("kind_" + th.kind), int(ceil(th.eta))])
		col = Color(0.91, 0.89, 0.84, 0.9)
	_screen()
	var fs := 18 if warn else 15
	var w := _font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := Rect2(Vector2(play_rect.get_center().x - w / 2.0 - 14.0, play_rect.position.y + 8.0), Vector2(w + 28.0, fs + 14.0))
	var bg := Color(0.30, 0.12, 0.08, 0.78) if warn else Color(0.06, 0.13, 0.16, 0.6)
	draw_style_box(_box(bg), r)
	draw_string(_font, r.position + Vector2(14, fs + 3), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	_world()

## What the warning points at: the door a phage is heading for, the arc a radical wave or an amoeba will hit.
func _draw_warn_marks(tt: float) -> void:
	var th: Dictionary = sim.threat_info()
	if not th.on or th.done or (th.stage != "warn" and th.stage != "hit"):
		return
	var pulse := 0.55 + 0.45 * sin(tt * 6.0)
	var col := Color(0.86, 0.32, 0.18, 0.35 + 0.45 * pulse)
	match th.kind:
		"phage":
			if th.stage == "warn":
				var mo: Vector2 = sim.pol(sim.RO + 26.0, th.a)
				dashed_circle(mo, 26.0 + 3.0 * pulse, col, 3.0, 6.0, 5.0)
				for f in sim.phages:
					draw_dashed_line(Vector2(f.x, f.y), mo, Color(col, 0.35), 1.5, 6.0)
		"ox":
			draw_arc(Sim.CENTER, sim.RO + 26.0, th.a - 1.7, th.a + 1.7, 40, col, 8.0, true)
			draw_arc(Sim.CENTER, sim.RO + 26.0, th.a - 1.7, th.a - 1.62, 3, Color(col, 0.9), 14.0, true)
			draw_arc(Sim.CENTER, sim.RO + 26.0, th.a + 1.62, th.a + 1.7, 3, Color(col, 0.9), 14.0, true)
		"amoeba":
			if th.stage == "warn":
				draw_arc(Sim.CENTER, sim.RO + 14.0, th.a - 0.5, th.a + 0.5, 24, col, 9.0, true)
