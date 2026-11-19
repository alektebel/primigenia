extends RefCounted
## The cell stage simulation: a faithful port of art/reference/cell/fase-celula-escala.html (no nodes, no drawing).
## Stepped with a fixed dt by the view (or by tests). Coordinates are the prototype's 720x720 space, centre (360,360).
## Public API: reset(phase) set_phase(n) place(kind,pos)->String("" ok / error code) remove_at(pos) demo() step(dt)
## stats() lines() goal() hint() aggregation() and the read-only state the view draws (pieces, mols, fx, pulses, integ).

const W := 720.0
const CX := 360.0
const CY := 360.0
const CENTER := Vector2(360.0, 360.0)
const TAU_ := TAU
const NL := 180
const R0 := 200.0
const RSTEP := 30.0
const TIERS := 5
const AGG_RATE := 150.0
const AGG_HOLD := 20.0
const GOAL_ATP := 40
const GOAL_LAC := 12
const GOAL_MEM_SECONDS := 60

## Mirrors the prototype's PIECES: c = cost in ATP, ph = phase unlocked, mem = lives on the membrane.
## n = [es, en] names, role = [es, en] one-liner for the tooltip. lobes = [x, y, r] blobs of the enzyme body.
const PIECES := {
	"tr": {"n": ["Transportador", "Transporter"], "c": 2, "ph": 1, "mem": true, "col": Color("6F93C4"),
		"role": ["Deja entrar glucosa desde fuera, sin gasto, hasta igualar el nivel.", "Lets glucose in from outside, free of charge, until the levels match."]},
	"hk": {"n": ["Hexoquinasa", "Hexokinase"], "c": 2, "ph": 1, "col": Color("7FA3CF"), "accept": "glu", "need": 2, "time": 0.6,
		"lobes": [[-6, 2, 12], [8, -4, 10]],
		"role": ["Marca la glucosa con fosfato (gasta 2 ATP) y la atrapa dentro. Se frena si se acumula su producto.", "Tags glucose with phosphate (costs 2 ATP) and traps it inside. Slows down when its product piles up."]},
	"ald": {"n": ["Aldolasa", "Aldolase"], "c": 3, "ph": 1, "col": Color("D4B37C"), "accept": "g6p", "need": 0, "time": 0.5,
		"lobes": [[-5, -3, 11], [7, 5, 11], [10, -8, 6]],
		"role": ["Parte la glucosa marcada en dos mitades.", "Splits the tagged glucose into two halves."]},
	"pk": {"n": ["Piruvato quinasa", "Pyruvate kinase"], "c": 3, "ph": 1, "col": Color("AE97CC"), "accept": "tri", "need": 0, "time": 0.45,
		"lobes": [[0, 0, 13], [-11, 7, 7], [11, 7, 7]],
		"role": ["Saca 2 ATP de cada mitad y deja piruvato.", "Pulls 2 ATP out of each half and leaves pyruvate."]},
	"ldh": {"n": ["Lactato DH", "Lactate DH"], "c": 3, "ph": 2, "col": Color("C98F86"), "accept": "pyr", "need": 0, "time": 0.4,
		"lobes": [[-7, 0, 11], [7, 0, 11]],
		"role": ["Convierte el piruvato en lactato para que la glucólisis no se atasque.", "Turns pyruvate into lactate so glycolysis does not jam."]},
	"ex": {"n": ["Exportador", "Exporter"], "c": 2, "ph": 2, "mem": true, "col": Color("D9806F"),
		"role": ["Saca el lactato de la célula.", "Pushes lactate out of the cell."]},
	"syn": {"n": ["Sintasa de lípidos", "Lipid synthase"], "c": 4, "ph": 3, "col": Color("A9BF73"), "accept": "tri", "need": 1, "time": 0.7,
		"lobes": [[-8, -2, 12], [8, 2, 12], [0, -10, 7]],
		"role": ["Usa una mitad y 1 ATP para fabricar un lípido. Se frena con poca energía.", "Uses one half and 1 ATP to make a lipid. Brakes when energy is low."]},
	"fl": {"n": ["Flipasa", "Flippase"], "c": 3, "ph": 3, "mem": true, "col": Color("7FA65A"),
		"role": ["Mete los lípidos nuevos en la membrana: repara su arco verde o, si no hay daño, hace crecer la célula.", "Inserts new lipids into the membrane: repairs its green arc or, with no damage, grows the cell."]},
	# phase 5: threats. Ribosomes build the counter proteins (and eat 1 ATP per 5 s while one is under construction).
	"rib": {"n": ["Ribosoma", "Ribosome"], "c": 4, "ph": 5, "col": Color("C97FA8"), "lobes": [[0, 5, 12], [2, -8, 9]],
		"role": ["Fabrica las proteínas de defensa: sin un ribosoma libre no se puede empezar ninguna. Gasta 1 ATP cada 5 s mientras trabaja. Los fagos lo secuestran y el antibiótico lo bloquea.", "Builds the defence proteins: none can be started without a free ribosome. Spends 1 ATP every 5 s while working. Phages hijack it and the antibiotic blocks it."]},
	"cas": {"n": ["Cas (CRISPR)", "Cas (CRISPR)"], "c": 4, "ph": 5, "col": Color("3F8F86"), "lobes": [[-5, 0, 10], [7, -5, 7], [7, 6, 7]],
		"role": ["Corta el ADN del fago en un ribosoma secuestrado (tarda unos segundos). Aprende: la segunda vez lo corta antes de que llegue.", "Cuts phage DNA inside a hijacked ribosome (takes a few seconds). It learns: the second time it cuts before the DNA arrives."]},
	"pump": {"n": ["Bomba de expulsión", "Efflux pump"], "c": 4, "ph": 5, "mem": true, "col": Color("B58BC9"),
		"role": ["Expulsa el antibiótico de uno en uno, gastando 1 ATP por molécula.", "Pumps the antibiotic out one molecule at a time, spending 1 ATP per molecule."]},
	"cat": {"n": ["Catalasa", "Catalase"], "c": 3, "ph": 5, "col": Color("D9A23C"), "lobes": [[-6, 2, 11], [7, -3, 9], [6, 8, 6]],
		"role": ["Neutraliza un radical libre cada 0,2 s antes de que toque la membrana. Más flipasas reparan lo que se escape.", "Neutralises one free radical every 0.2 s before it touches the membrane. More flippases repair what slips through."]},
	"spn": {"n": ["Espinas", "Spines"], "c": 2, "ph": 5, "mem": true, "col": Color("8C7D5A"),
		"role": ["Pinchos en la membrana. Con 3 o más, la ameba los nota y se suelta enseguida.", "Spikes on the membrane. With 3 or more, the amoeba feels them and lets go at once."]},
}
## The four threats in the order they arrive, and the timings (seconds) of one threat.
const THREAT_ORDER := ["phage", "abx", "ox", "amoeba"]
const WARN_T := 10.0
const SETTLE_T := 8.0
const MEM_MIN := 60                  # membrane % that must hold through a threat
const HIT_T := {"phage": 36.0, "abx": 18.0, "ox": 10.0, "amoeba": 14.0}
const HIJACK_T := 14.0
const CAS_CUT_T := 4.0
const THREAT_MOLS := ["dna", "abx", "baby", "frag"]
const ORDER := ["hk", "ald", "pk", "ldh", "syn"]
const LINE_ORDER := ["hk", "ald", "pk", "ldh", "syn", "rib", "cas", "cat"]
const PHASE_NAMES := [["", ""], ["Energía", "Energy"], ["Residuos", "Waste"], ["Membrana", "Membrane"], ["Crecer", "Grow"], ["Amenazas", "Threats"], ["Colonia", "Colony"]]
const SIM_PHASES := 5          # phase 6 (the colony) is colony_sim.gd
## Counter pieces: their proteins are built by a free ribosome, so they cannot be started without one.
const COUNTERS := ["cas", "pump", "cat", "spn"]

class Piece extends RefCounted:
	var type := ""
	var born := 0.0
	var built := false
	var got := 0
	var claim := 0
	var ph := 0.0
	var u := 0.0
	var st := "montando"
	# membrane pieces
	var a := 0.0
	var open := 0.0
	var cool := 0.0
	var busy := false
	# enzymes
	var pos := Vector2.ZERO
	var sub = null          # Mol
	var atps: Array = []
	var proc := -1.0        # -1 = idle (the prototype's null)
	var pulse := 0.0
	var wait := 0.0
	var block := ""
	var starved := false
	# phase 5
	var hij := 0.0          # >0: a phage hijacked this ribosome (seconds left before lysis)
	var abx := 0            # antibiotic molecules stuck on this piece
	var ox := 0.0           # >0: oxidised enzyme (seconds left)
	var off := Vector2.ZERO # Cas: how far it has gone to cut DNA (drawn offset)
	var cdelay := 0.0

class Mol extends RefCounted:
	var type := ""
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var state := ""
	var age := 0.0
	var target = null       # Piece
	var alpha := 1.0
	var ph := 0.0
	var dead := false
	var dir := 1
	var prog := 0.0
	var tr = null           # Piece
	var u := Vector2.ZERO   # exit direction
	var sp := 0.0
	var ta := 0.0

var rng := RandomNumberGenerator.new()
var seed_value := 1

var RO := R0
var RI := R0 - 36.0
var ROt := R0
var zoom := 270.0 / R0
var zoomT := 270.0 / R0
var T := 0.0
var phi := 0.0              # lateral slide of the lipids
var phase := 1
var pieces: Array = []
var mols: Array = []
var fx: Array = []          # {k:"ring"/"txt"/"big", p, t, color, big, text}
var pulses: Array = []      # {a, t, c}
var integ: Array = []
var logs := {"atp": [], "glu": [], "lip": [], "up": []}
var store := 0
var tier := 0
var growth := 0
var sustain := 0.0
var agg = null              # null or {t, stats, shown, fade}
var agg_done := false
var goal_state := {"atp": 0, "lac": 0, "mem": 0.0, "done": false}
var maint_t := 0.0
var trickle_t := 0.0
var ros_t := 0.0
var leak_t := 0.0
var up_t := 0.0
var threats := {}           # phase 5 schedule, see _reset_threats()
var phages: Array = []      # {x, y, state "in"/"land"/"empty"/"gone", al, a}
var amoeba = null           # null or {x, y, a, state "come"/"bite"/"flee", bite, engulf, contact}
var tide := 0.0             # antibiotic tide tint 0..1
var flash := 0.0            # oxidation warning flash 0..1
var ox_a := 0.0             # angle the oxidation wave comes from
var cas_primed := false
var wait_first := 30.0
var wait_gap := 20.0
var events: Array = []      # cheap one-shot notes for the view (sounds/toasts), cleared by take_events()

func _init(seed_: int = 1, phase_: int = 1) -> void:
	seed_value = seed_
	phase = phase_
	reset(phase_)

# ---------- helpers
func R(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func pol(r: float, a: float) -> Vector2:
	return CENTER + Vector2(cos(a), sin(a)) * r

func rad(p: Vector2) -> float:
	return p.distance_to(CENTER)

func ang(p: Vector2) -> float:
	return atan2(p.y - CY, p.x - CX)

func adiff(a: float, b: float) -> float:
	var d := fmod(absf(a - b), TAU)
	return TAU - d if d > PI else d

func mid() -> float:
	return (RO + RI) / 2.0

func flw() -> float:
	return 110.0 / mid()

## The membrane is fluid (as in the prototype): lipid i sits at lang(i), and the whole bilayer slides sideways at 0.035 rad/s
## while doors, enzymes and radicals stay put. Damage belongs to the lipid, not to the angle.
func lang(i: int) -> float:
	return float(i) / NL * TAU + phi

func lidx(a: float) -> int:
	return ((int(round((a - phi) / TAU * NL)) % NL) + NL) % NL

func is_mem(p: Piece) -> bool:
	return PIECES[p.type].has("mem")

func ppos(p: Piece) -> Vector2:
	return pol(mid(), p.a) if is_mem(p) else p.pos

func spos(p: Piece) -> Vector2:
	return pol(RI - 14.0, p.a) if is_mem(p) else p.pos

func need_g() -> int:
	return 20 + 6 * tier

func per(k: String, s: float) -> float:
	var n := 0
	for t in logs[k]:
		if T - t < s:
			n += 1
	return n * 60.0 / s

func mem_pct() -> int:
	var s := 0.0
	for v in integ:
		s += v
	return int(round(s / NL * 100.0))

func set_r(r: float) -> void:
	RO = r
	RI = r - 36.0

func count(t: String, s: String = "") -> int:
	var n := 0
	for m in mols:
		if m.type == t and (s == "" or m.state == s):
			n += 1
	return n

func built_of(t: String) -> Array:
	return pieces.filter(func(p): return p.type == t and p.built)

func nearest(list: Array, p: Vector2):
	var b = null
	var bd := 1e9
	for m in list:
		var q: Vector2 = m.p if m is Mol else (m.pos if m is Piece else m)
		var d := q.distance_to(p)
		if d < bd:
			bd = d
			b = m
	return b

func steer(m: Mol, t: Vector2, dt: float, acc: float, mx: float) -> float:
	var d := t - m.p
	var dl := maxf(d.length(), 0.0001)
	m.v += d / dl * acc * dt
	var s := m.v.length()
	if s > mx:
		m.v *= mx / s
	return dl

func piece_name(t: String, lang_es: bool = true) -> String:
	return PIECES[t].n[0 if lang_es else 1]

# ---------- creation and removal
func new_mol(type: String, p: Vector2, state: String) -> Mol:
	var m := Mol.new()
	m.type = type
	m.p = p
	m.v = Vector2(R(-20, 20), R(-20, 20))
	m.state = state
	m.ph = R(0, TAU)
	mols.append(m)
	return m

func spawn_out(edge: bool) -> Mol:
	var h := 360.0 / zoom + 20.0
	var x := 0.0
	var y := 0.0
	var k := 0
	while true:
		x = CX + h if edge else CX + R(-h, h)
		y = CY + R(-h + 10, h - 10)
		k += 1
		if not (Vector2(x - CX, y - CY).length() < RO + 40 and k < 40):
			break
	return new_mol("glu", Vector2(x, y), "out")

func burst(p: Vector2, color: Color, big: bool = false) -> void:
	fx.append({"k": "ring", "p": p, "t": 0.0, "color": color, "big": big})

func float_text(p: Vector2, text: String, color: Color) -> void:
	fx.append({"k": "txt", "p": p, "t": 0.0, "text": text, "color": color})

func emit_atp(p: Vector2, n: int) -> void:
	for i in n:
		logs.atp.append(T)
		if count("atp") >= 70:
			store += 1
			continue
		var a := new_mol("atp", p, "free")
		var an := R(0, TAU)
		a.v = Vector2(cos(an), sin(an)) * 90.0

func add_piece(type: String, p: Vector2, free: bool = false) -> Piece:
	var d: Dictionary = PIECES[type]
	var pc := Piece.new()
	pc.type = type
	pc.born = T
	pc.built = free
	pc.ph = R(0, TAU)
	if d.has("mem"):
		pc.a = atan2(p.y - CY, p.x - CX)
	else:
		var r := p.distance_to(CENTER)
		var m := RI - 40.0
		if r > m:
			p = CENTER + (p - CENTER) * m / r
		pc.pos = p
	pieces.append(pc)
	burst(ppos(pc), Color("1F5F9E"), true)
	return pc

func remove_piece(p: Piece) -> void:
	for m in mols:
		if m.target == p:
			m.target = null
			if m.state == "seek" or m.state == "dock" or m.state == "leak":
				m.state = "free"
	pieces = pieces.filter(func(q): return q != p)

func reset(phase_: int = -1) -> void:
	if phase_ > 0:
		phase = clampi(phase_, 1, SIM_PHASES)
	rng.seed = seed_value
	goal_state = {"atp": 0, "lac": 0, "mem": 0.0, "done": false}
	pieces = []
	mols = []
	fx = []
	pulses = []
	logs = {"atp": [], "glu": [], "lip": [], "up": []}
	store = 0
	T = 0.0
	phi = 0.0
	set_r(R0)
	ROt = R0
	zoom = 270.0 / R0
	zoomT = zoom
	tier = 0
	growth = 0
	sustain = 0.0
	agg = null
	agg_done = false
	maint_t = 0.0
	trickle_t = 0.0
	ros_t = 0.0
	leak_t = 0.0
	up_t = 0.0
	integ = []
	integ.resize(NL)
	integ.fill(1.0)
	for i in 30:
		spawn_out(false)
	for i in 12:
		var p := pol(R(0, RI - 40), R(0, TAU))
		new_mol("atp", p, "free")
	_reset_threats()
	if phase >= 5:
		threats.on = true

func set_phase(n: int) -> void:
	phase = clampi(n, 1, SIM_PHASES)
	goal_state = {"atp": 0, "lac": 0, "mem": 0.0, "done": false}
	if phase >= 5 and not threats.on:
		_reset_threats()
		threats.on = true
		threats.wait = wait_first

## Places a piece the player chose. Returns "" on success, else an error code:
## "unknown", "phase" (not unlocked yet), "where" (membrane pieces need the membrane, enzymes the inside), "colony".
func place(kind: String, p: Vector2) -> String:
	if not PIECES.has(kind):
		return "unknown"
	var d: Dictionary = PIECES[kind]
	if int(d.ph) > phase:
		return "phase"
	if agg != null:
		return "colony"
	if COUNTERS.has(kind) and built_of("rib").is_empty():
		return "need_rib"
	var r := rad(p)
	if d.has("mem"):
		if not (r > RI - 50.0 and r < RO + 70.0):
			return "where"
	elif not r < RI - 8.0:
		return "where"
	add_piece(kind, p)
	return ""

func piece_at(p: Vector2, maxd: float = 34.0) -> Piece:
	var b: Piece = null
	var bd := maxd
	for q in pieces:
		var d := ppos(q).distance_to(p)
		if d < bd:
			bd = d
			b = q
	return b

func remove_at(p: Vector2) -> bool:
	var h := piece_at(p)
	if h == null:
		return false
	remove_piece(h)
	return true

func move_piece(pc: Piece, p: Vector2) -> void:
	if is_mem(pc):
		pc.a = atan2(p.y - CY, p.x - CX)
	else:
		var r := p.distance_to(CENTER)
		var m := RI - 40.0
		if r > m:
			p = CENTER + (p - CENTER) * m / r
		pc.pos = p

func demo() -> void:
	reset()
	var P := func(t: String, a: float) -> void: add_piece(t, pol(RO, a), true)
	var E := func(t: String, x: float, y: float) -> void: add_piece(t, Vector2(CX + x, CY + y), true)
	P.call("tr", -0.35)
	P.call("tr", 0.35)
	E.call("hk", 95, -40)
	E.call("ald", 40, -70)
	E.call("pk", -30, -20)
	if phase >= 2:
		E.call("ldh", -100, 10)
		P.call("ex", PI)
	if phase >= 3:
		E.call("syn", 30, 70)
		for a in [0.3, 1.55, 2.8, -2.3, -1.0]:
			P.call("fl", a)
	if phase >= 5:
		# what a player brings from phase 4: three lines of every enzyme, many flippases, doors (the aggregation test factory)
		var g := RandomNumberGenerator.new()
		g.seed = 5
		for k in 3:
			for t in ["hk", "ald", "pk", "ldh", "syn"]:
				add_piece(t, CENTER + Vector2.from_angle(g.randf() * TAU) * g.randf_range(20, 120), true)
		for a in [0.0, 0.7, 1.4, 2.1, 2.8, 3.5, 4.2, 4.9, 5.6, 0.35, 1.05, 1.75]:
			P.call("fl", a)
		for a in [-0.8, 0.8, 1.2, 2.0, 2.5, -1.3]:
			P.call("tr", a)
		for a in [PI, 3.5, 2.6]:
			P.call("ex", a)
		E.call("rib", -140, 60)
		E.call("rib", 120, 80)

func grow(a: float) -> void:
	pulses.append({"a": a, "t": 0.0, "c": Color("A9D46A")})
	if tier >= TIERS:
		return
	growth += 1
	if growth >= need_g():
		growth = 0
		tier += 1
		ROt = R0 + tier * RSTEP
		fx.append({"k": "big", "t": 0.0, "tier": tier})
		events.append("grow")

func take_events() -> Array:
	var e := events
	events = []
	return e

func finish(e: Piece) -> void:
	var s: Mol = e.sub
	e.proc = -1.0
	e.sub = null
	e.pulse = 1.0
	e.wait = 0.0
	mols = mols.filter(func(m): return not e.atps.has(m))
	e.atps = []
	match e.type:
		"hk":
			s.type = "g6p"
			s.state = "free"
			s.target = null
			s.age = 0.0
			burst(e.pos, Color("9179C9"))
			float_text(e.pos + Vector2(0, -24), "−2 ATP", Color("9E392C"))
			logs.glu.append(T)
		"ald":
			mols = mols.filter(func(m): return m != s)
			for k in [-1, 1]:
				var t := new_mol("tri", e.pos + Vector2(k * 8, 0), "free")
				t.v = Vector2(k * 70, R(-30, 30))
			burst(e.pos, Color("B89B5E"))
		"pk":
			s.type = "pyr"
			s.target = null
			s.age = 0.0
			if phase >= 2:
				s.state = "free"
			else:
				s.state = "exit"
				var r := maxf(rad(s.p), 0.0001)
				s.u = (s.p - CENTER) / r
				s.sp = 45.0
			emit_atp(e.pos, 2)
			goal_state.atp += 2
			burst(e.pos, Color("E2C240"), true)
			float_text(e.pos + Vector2(0, -24), "+2 ATP", Color("7A6410"))
		"ldh":
			s.type = "lac"
			s.state = "free"
			s.target = null
			s.age = 0.0
			burst(e.pos, Color("D9806F"))
		"syn":
			s.type = "lip"
			s.state = "free"
			s.target = null
			s.age = 0.0
			logs.lip.append(T)
			burst(e.pos, Color("7FA65A"))

func worst_in(fl: Piece) -> int:
	var b := -1
	var bv := 0.8
	var w := flw()
	for i in NL:
		if integ[i] < bv and adiff(lang(i), fl.a) < w:
			bv = integ[i]
			b = i
	return b

func _door_nearest(list: Array, m: Mol):
	## nearest door by its inside point; returns the Piece
	var best = null
	var bd := 1e9
	for t in list:
		var d := pol(RI - 18.0, t.a).distance_to(m.p)
		if d < bd:
			bd = d
			best = t
	return best

func _lip_nearest(list: Array, m: Mol):
	var best = null
	var bd := 1e9
	for t in list:
		var d := spos(t).distance_to(m.p)
		if d < bd:
			bd = d
			best = t
	return best

# ---------- the step
func step(dt: float) -> void:
	T += dt
	phi = fposmod(phi + dt * 0.035, TAU)
	if absf(ROt - RO) > 0.05:
		set_r(RO + (ROt - RO) * minf(1.0, dt * 1.2))
	zoomT = 330.0 / (3.05 * RO) if agg != null else 270.0 / ROt
	zoom += (zoomT - zoom) * minf(1.0, dt * 1.5)
	var doors: Array = pieces.filter(func(p): return (p.type == "tr" or p.type == "ex") and p.built)
	var trs: Array = doors.filter(func(p): return p.type == "tr")
	var exs: Array = doors.filter(func(p): return p.type == "ex")
	var enz: Array = pieces.filter(func(p): return not is_mem(p) and p.built and PIECES[p.type].has("accept"))
	var has_hk := enz.any(func(e): return e.type == "hk")
	var fls := built_of("fl")
	if count("glu", "out") < int(round(40.0 * RO / R0)):
		spawn_out(true)
	if store > 0 and count("atp") < 40:
		new_mol("atp", pol(R(0, RI - 30), R(0, TAU)), "free")
		store -= 1
	# building with ATP (counter proteins need a free ribosome)
	var rib_ok := built_of("rib").any(func(r): return r.hij <= 0.0 and r.abx == 0)
	for p in pieces:
		if p.built:
			continue
		if COUNTERS.has(p.type) and not rib_ok:
			continue
		var c: int = PIECES[p.type].c
		while p.got + p.claim < c:
			var a = nearest(mols.filter(func(m): return m.type == "atp" and m.state == "free"), spos(p))
			if a == null:
				break
			a.state = "seek"
			a.target = p
			p.claim += 1
	# doors (passive transport: stops when inside glucose matches outside)
	var sc := RO / R0
	var in_glu := 0
	for m in mols:
		if m.type == "glu" and (m.state == "free" or m.state == "seek" or m.state == "pass"):
			in_glu += 1
	for tr in doors:
		tr.cool -= dt
		if not tr.busy and tr.cool <= 0.0:
			var mo := pol(RO + 16.0, tr.a)
			var mi := pol(RI - 18.0, tr.a)
			var g = null
			for m in mols:
				if m.state == "leak" and m.target == tr and m.p.distance_to(mi) < 16.0:
					g = m
					break
			if g != null:
				g.state = "pass"
				g.dir = -1
				g.prog = 0.0
				g.tr = tr
				tr.busy = true
			elif tr.type == "tr" and in_glu < 6.0 * sc:
				for m in mols:
					if m.state == "out" and m.type == "glu" and m.p.distance_to(mo) < 36.0:
						g = m
						break
				if g != null:
					g.state = "pass"
					g.dir = 1
					g.prog = 0.0
					g.tr = tr
					tr.busy = true
		if not tr.busy:
			tr.open *= maxf(0.0, 1.0 - 6.0 * dt)
	# enzymes
	var free_atp_n := 0
	for m in mols:
		if m.type == "atp" and m.state == "free":
			free_atp_n += 1
	var low_e := free_atp_n + store < 6
	var s := RO / R0
	var nG := count("g6p", "free")
	var nT := count("tri", "free")
	var nP := count("pyr", "free")
	var nLip := count("lip", "free")
	var nL := 0
	for m in mols:
		if m.type == "lac" and m.state != "trail" and m.state != "pass":
			nL += 1
	for e in enz:
		var d: Dictionary = PIECES[e.type]
		e.pulse = maxf(0.0, e.pulse - dt * 2.5)
		var blk := ""
		if e.type == "hk" and nG >= 6 * s:
			blk = "inhibida"
		elif e.type == "ald" and nT >= 10 * s:
			blk = "atasco"
		elif e.type == "pk" and phase >= 2 and nP >= 6 * s:
			blk = "atasco"
		elif e.type == "ldh" and nL >= 8 * s:
			blk = "atasco"
		elif e.type == "syn" and nLip >= 6 * s:
			blk = "atasco"
		elif e.type == "syn" and low_e:
			blk = "inhibida"
		if e.ox > 0.0:
			e.ox = maxf(0.0, e.ox - dt)
			blk = "oxidada"
		if e.abx > 0:
			blk = "bloqueada"
		e.block = blk
		if e.sub == null:
			if e.block == "":
				var cand = nearest(mols.filter(func(m): return m.type == d.accept and (m.state == "free" or m.state == "leak")), e.pos)
				if cand != null:
					var dm: float = e.pos.distance_to(cand.p)
					var beaten := false
					for o in enz:
						if o != e and o.sub == null and o.block == "" and PIECES[o.type].accept == d.accept and o.pos.distance_to(cand.p) < dm:
							beaten = true
							break
					if not beaten:
						cand.state = "seek"
						cand.target = e
						e.sub = cand
						e.wait = 0.0
		elif e.sub.state == "dock":
			if e.proc < 0.0:
				if e.block != "":
					e.wait += dt
				elif d.need > 0:
					e.atps = e.atps.filter(func(a): return mols.has(a) and a.target == e)
					e.starved = false
					while e.atps.size() < d.need:
						var a = nearest(mols.filter(func(m): return m.type == "atp" and m.state == "free"), e.pos)
						if a == null:
							e.starved = true
							break
						a.state = "seek"
						a.target = e
						e.atps.append(a)
					if e.atps.size() == d.need and e.atps.all(func(a): return a.state == "dock"):
						e.proc = 0.0
					else:
						e.wait += dt
				else:
					e.proc = 0.0
			else:
				e.proc += dt
				if e.proc >= d.time:
					finish(e)
		elif not mols.has(e.sub) or e.sub.target != e:
			e.sub = null
		var st := ""
		if e.proc >= 0.0:
			st = "trabaja"
		elif e.block != "":
			st = e.block
		elif e.sub != null and e.sub.state == "dock":
			st = "falta ATP" if (d.need > 0 and e.starved and e.wait > 0.4) else "recibe"
		elif e.sub != null:
			st = "recibe"
		else:
			st = "sin entrada"
		e.st = st
		e.u += ((1.0 if st == "trabaja" else 0.0) - e.u) * minf(1.0, dt / 6.0)
	# ATP upkeep, rescue trickle
	var free_atp: Array = mols.filter(func(m): return m.type == "atp" and m.state == "free")
	maint_t += dt
	if maint_t > 3.5:
		maint_t = 0.0
		if phase < 3 and free_atp.size() > 10:
			var a: Mol = free_atp[int(R(0, free_atp.size()))]
			a.state = "tomem"
			a.ta = ang(a.p) + R(-0.5, 0.5)
	trickle_t += dt
	if trickle_t > 3.0:
		trickle_t = 0.0
		if free_atp.size() < 3 and store <= 0:
			var an := R(0.8, 2.3)
			new_mol("atp", pol(RI - 20.0, an), "free")
			pulses.append({"a": an, "t": 0.0, "c": Color("79B8AB")})
	if phase >= 4:
		up_t += dt
		if up_t > 6.0 * R0 / RO:
			up_t = 0.0
			if store > 0:
				store -= 1
				logs.up.append(T)
			elif free_atp.size() > 0:
				var a2: Mol = free_atp[int(R(0, free_atp.size()))]
				a2.state = "tomem"
				a2.ta = ang(a2.p) + R(-0.5, 0.5)
				logs.up.append(T)
			else:
				var i := int(R(0, NL))
				if integ[i] > 0.45:
					integ[i] = 0.45
				float_text(pol(RO + 20.0, lang(i)), "sin ATP", Color("9E392C"))
	# membrane damage
	if phase >= 3:
		ros_t += dt
		if ros_t > 9.0 * R0 / RO:
			ros_t = 0.0
			var a3 := R(0, TAU)
			var m3 := new_mol("ros", pol(RO + 150.0, a3), "ros")
			m3.ta = a3
		var nx: Array = integ.duplicate()
		for i in NL:
			var v: float = integ[i]
			if v > 0.0 and v < 0.5:
				nx[i] = maxf(0.0, v - 0.03 * dt)
				for j in [(i + 1) % NL, (i + NL - 1) % NL]:
					if integ[j] >= 0.5:
						nx[j] = maxf(0.49, nx[j] - 0.012 * dt)
		integ = nx
		var gaps: Array = []
		for i in NL:
			if integ[i] <= 0.0:
				gaps.append(i)
		leak_t += dt * minf(gaps.size(), 8)
		if leak_t > 9.0 and gaps.size() > 0:
			leak_t = 0.0
			var gp := pol(RI - 10.0, lang(gaps[int(R(0, gaps.size()))]))
			var a4 = nearest(free_atp, gp)
			if a4 != null:
				a4.state = "exit"
				var dd := maxf(a4.p.distance_to(gp), 0.0001)
				a4.u = (gp - a4.p) / dd
				a4.sp = 120.0
				float_text(gp, "fuga", Color("9E392C"))
	else:
		integ.fill(1.0)
	# aggregation trigger
	var rate := per("atp", 20.0)
	if phase >= 4 and tier >= TIERS and not agg_done:
		if rate >= AGG_RATE:
			sustain += dt
		else:
			sustain = maxf(0.0, sustain - dt * 2.0)
		if sustain >= AGG_HOLD:
			agg_done = true
			agg = {"t": 0.0, "stats": sheet_stats(), "shown": false}
			events.append("aggregation")
	if agg != null:
		agg.t += dt
		if agg.t > 5.5 and not agg.shown:
			agg.shown = true
		if agg.has("fade"):
			agg.fade += dt
			if agg.fade > 1.5:
				agg = null
	if phase >= 5:
		_step_threats(dt)
	# molecules
	var h := 360.0 / zoom + 30.0
	for m in mols:
		_step_mol(m, dt, h, trs, exs, fls, has_hk)
	mols = mols.filter(func(m): return not m.dead)
	if phase == 3 and built_of("fl").size() > 0 and mem_pct() >= 95:
		goal_state.mem += dt
	else:
		goal_state.mem = 0.0
	for f in fx:
		f.t += dt
	fx = fx.filter(func(f): return f.t < (1.1 if f.k == "txt" else (2.6 if f.k == "big" else 0.55)))
	for p in pulses:
		p.t += dt
	pulses = pulses.filter(func(p): return p.t < 1.0)
	for k in logs:
		if logs[k].size() > 0 and T - logs[k][0] > 65.0:
			logs[k] = logs[k].filter(func(t): return T - t < 65.0)

func _step_mol(m: Mol, dt: float, h: float, trs: Array, exs: Array, fls: Array, has_hk: bool) -> void:
	m.age += dt
	if THREAT_MOLS.has(m.type):
		_step_threat_mol(m, dt)
		return
	if m.state == "pass":
		var tr: Piece = m.tr
		if not pieces.has(tr):
			m.state = "out" if m.dir > 0 else "free"
			m.tr = null
			return
		m.prog += dt / 0.7
		var o := pol(RO + 16.0, tr.a)
		var i := pol(RI - 18.0, tr.a)
		var a := o if m.dir > 0 else i
		var b := i if m.dir > 0 else o
		var p := minf(1.0, m.prog)
		var q := p * p * (3.0 - 2.0 * p)
		m.p = a + (b - a) * q
		tr.open = sin(p * PI)
		if m.prog >= 1.0:
			tr.busy = false
			tr.cool = 0.25
			m.tr = null
			m.age = 0.0
			m.target = null
			var cs := Vector2(cos(tr.a), sin(tr.a))
			if m.dir > 0:
				m.state = "free"
				m.v = -cs * 50.0
			else:
				if m.type == "lac":
					goal_state.lac += 1
				m.state = "trail" if m.type == "lac" else "out"
				m.v = cs * 50.0
		return
	if m.state == "dock":
		var e: Piece = m.target
		if e == null:
			m.state = "free"
			return
		var k := 0
		if m.type == "atp":
			k = 1 if e.atps.find(m) != 0 else -1
		m.p = Vector2(e.pos.x + k * 13.0, e.pos.y + (-15.0 if k != 0 else 0.0))
		return
	m.v += Vector2(R(-1, 1), R(-1, 1)) * 160.0 * dt
	m.v *= 1.0 - 1.4 * dt
	if m.state == "out" or m.state == "trail":
		m.v.x += (-24.0 - m.v.x) * 0.4 * dt
		var r := rad(m.p)
		if r < RO + 18.0:
			var u := (m.p - CENTER) / maxf(r, 0.0001)
			m.p = CENTER + u * (RO + 18.0)
			m.v += u * 30.0
		if m.state == "out":
			for tr in trs:
				var mo := pol(RO + 16.0, tr.a)
				if m.p.distance_to(mo) < 170.0:
					steer(m, mo, dt, 160.0, 85.0)
		m.p += m.v * dt
		if m.state == "trail":
			m.alpha = maxf(0.0, 1.0 - m.age / 16.0)
			if m.alpha <= 0.0 or m.p.x < CX - h:
				m.dead = true
			if m.p.y < CY - h or m.p.y > CY + h:
				m.v.y *= -1.0
			return
		if m.p.x < CX - h:
			m.p.x = CX + h - 10.0
			m.p.y = CY + R(-h + 10, h - 10)
		if m.p.x > CX + h + 10.0:
			m.p.x = CX + h
		if m.p.y < CY - h or m.p.y > CY + h:
			m.v.y *= -1.0
		return
	if m.state == "ros":
		var t := pol(RO + 6.0, m.ta)
		if steer(m, t, dt, 200.0, 70.0) < 10.0:
			m.dead = true
			if _catalase_take(m.p):
				return
			var ix := lidx(m.ta)
			var strong := m.prog > 0.5
			if strong:
				for o in range(-3, 4):
					var j := (ix + o + NL) % NL
					if integ[j] > 0.0:
						integ[j] = minf(integ[j], 0.05)
			elif integ[ix] > 0.0:
				integ[ix] = minf(integ[ix], 0.45)
			burst(t, Color("B4382F"))
			if strong and R(0, 1) < 0.12:
				_oxidise_enzyme(m.p)
		m.p += m.v * dt
		return
	if m.state == "exit":
		m.p += m.u * m.sp * dt
		var r2 := rad(m.p)
		m.alpha = maxf(0.0, 1.0 - maxf(0.0, r2 - RI + 10.0) / 90.0)
		if m.alpha <= 0.0:
			m.dead = true
		return
	if m.state == "tomem":
		var t2 := pol(RI - 8.0, m.ta)
		if steer(m, t2, dt, 260.0, 110.0) < 12.0:
			m.dead = true
			pulses.append({"a": m.ta, "t": 0.0, "c": Color("7FA65A")})
		m.p += m.v * dt
		return
	if m.state == "seek":
		var p2: Piece = m.target
		if p2 == null or not pieces.has(p2):
			m.state = "free"
			m.target = null
		elif steer(m, spos(p2), dt, 360.0, 160.0) < 13.0:
			if not p2.built:
				m.dead = true
				p2.got += 1
				p2.claim -= 1
				if p2.got >= int(PIECES[p2.type].c):
					p2.built = true
					p2.born = T
					burst(ppos(p2), PIECES[p2.type].col, true)
				return
			if p2.type == "fl":
				var wi := worst_in(p2)
				if wi >= 0:
					integ[wi] = 1.0
					m.dead = true
					pulses.append({"a": lang(wi), "t": 0.0, "c": Color("7FA65A")})
				elif phase >= 4:
					m.dead = true
					grow(p2.a)
				else:
					m.state = "free"
					m.target = null
				return
			m.state = "dock"
			m.v = Vector2.ZERO
			return
	if m.state == "free":
		if m.type == "glu" and not has_hk and m.age > 2.5 and trs.size() > 0:
			m.state = "leak"
			m.target = _door_nearest(trs, m)
		elif m.type == "lac" and exs.size() > 0:
			m.state = "leak"
			m.target = _door_nearest(exs, m)
		elif m.type == "lip" and fls.size() > 0:
			var c: Array = fls.filter(func(f): return worst_in(f) >= 0)
			if c.is_empty() and phase >= 4:
				c = fls
			if not c.is_empty():
				m.state = "seek"
				m.target = _lip_nearest(c, m)
	if m.state == "leak":
		var tr2: Piece = m.target
		if tr2 == null or not pieces.has(tr2):
			m.state = "free"
			m.target = null
		else:
			steer(m, pol(RI - 18.0, tr2.a), dt, 160.0, 70.0)
	m.p += m.v * dt
	var r3 := rad(m.p)
	var lim := RI - 14.0
	if r3 > lim:
		var u3 := (m.p - CENTER) / r3
		m.p = CENTER + u3 * lim
		var vn := m.v.dot(u3)
		if vn > 0.0:
			m.v -= u3 * 1.6 * vn

# ---------- phase 5: threats (port of the four scenes of art/reference/cell/malos-tiempos.html, as events against the factory)
## A threat goes wait -> warn (WARN_T seconds, with a visible sign) -> hit -> settle, then a verdict: it is survived when the
## membrane never fell under MEM_MIN % meanwhile. A failed threat comes back after wait_gap seconds. Order: THREAT_ORDER.
const GENOME := Vector2(292.0, 262.0)   # where the genome ring is drawn and where stray phage DNA goes
var _genome_p: Piece = null

func _reset_threats() -> void:
	threats = {"on": false, "idx": 0, "stage": "wait", "t": 0.0, "wait": wait_first, "min": 100, "results": ["", "", "", ""],
		"tries": 0, "blocked": "", "a": 0.0, "n": 0, "acc": 0.0, "pore": 0.0, "cas_t": 0.0, "done": false, "p2": false}
	phages = []
	amoeba = null
	tide = 0.0
	flash = 0.0
	cas_primed = false
	_genome_p = Piece.new()
	_genome_p.type = "gen"
	_genome_p.pos = GENOME
	_genome_p.built = true

## Starts (or restarts) the schedule; `first` is the wait before the first warning.
func start_threats(first: float = -1.0, idx: int = 0) -> void:
	_reset_threats()
	threats.on = true
	threats.idx = clampi(idx, 0, 3)
	threats.wait = wait_first if first < 0.0 else first

func threat_kind() -> String:
	return THREAT_ORDER[mini(int(threats.idx), 3)]

func threat_info() -> Dictionary:
	var th := threats
	var kind := threat_kind()
	var eta := 0.0
	match th.stage:
		"wait": eta = th.wait - th.t
		"warn": eta = WARN_T - th.t
		"hit": eta = float(HIT_T[kind]) - th.t
		"settle": eta = SETTLE_T - th.t
	var counter: String = {"phage": "cas", "abx": "pump", "ox": "cat", "amoeba": "spn"}[kind]
	return {"on": th.on, "kind": kind, "stage": th.stage, "eta": maxf(0.0, eta), "idx": th.idx, "results": th.results.duplicate(),
		"done": th.done, "blocked": th.blocked, "a": ox_a if kind == "ox" else th.a, "min": th.min, "tries": th.tries, "counter": counter,
		"has_counter": has_piece(counter) or (kind == "amoeba" and tier >= 3)}

func _hint5() -> Dictionary:
	var th := threats
	if not has_piece("rib"):
		return {"key": "h_rib", "args": []}
	if th.done:
		return {"key": "h_threats_done", "args": []}
	var kind := threat_kind()
	match th.stage:
		"warn", "hit":
			return {"key": "h_w_" + kind, "args": [piece_name(th.blocked) if th.blocked != "" else "-"]}
		"settle":
			return {"key": "h_settle", "args": []}
	var info := threat_info()
	if not info.has_counter:
		return {"key": "h_n_" + kind, "args": []}
	return {"key": "h_ready", "args": []}

func _cas_ready() -> bool:
	for c in built_of("cas"):
		if c.abx == 0:
			return true
	return false

func _catalase_take(at: Vector2) -> bool:
	for c in built_of("cat"):
		if c.cool <= 0.0:
			c.cool = 0.2
			c.pulse = 1.0
			burst(at, Color("D9A23C"))
			return true
	return false

func _oxidise_enzyme(at: Vector2) -> void:
	var cand: Array = pieces.filter(func(q): return not is_mem(q) and q.built and PIECES[q.type].has("accept") and q.ox <= 0.0)
	var e = nearest(cand, at)
	if e != null:
		e.ox = 8.0
		float_text(e.pos + Vector2(0, -26), "oxidada", Color("9E392C"))

func _lysis(a: float, w: float, lvl: float) -> void:
	for i in NL:
		if adiff(lang(i), a) < w:
			integ[i] = minf(integ[i], lvl)
	burst(pol(RO, a), Color("B4382F"), true)
	float_text(pol(RO + 24.0, a), "lisis", Color("9E392C"))
	pulses.append({"a": a, "t": 0.0, "c": Color("B4382F")})

func _step_threats(dt: float) -> void:
	var th := threats
	# piece bookkeeping that runs whatever the stage is
	_threat_pieces(dt)
	_move_phages(dt)
	_move_amoeba(dt)
	_pumps(dt)
	_hijacks(dt)
	_abx_pores(dt)
	if not th.on or th.done:
		return
	var kind := threat_kind()
	th.t += dt
	if th.stage != "wait":
		th.min = mini(int(th.min), mem_pct())
	match th.stage:
		"wait":
			if th.t >= th.wait:
				th.stage = "warn"
				th.t = 0.0
				th.min = mem_pct()
				_warn_begin(kind)
				events.append("warn")
		"warn":
			if kind == "abx":
				tide = th.t / WARN_T
			elif kind == "ox":
				flash = th.t / WARN_T
			if th.t >= WARN_T:
				th.stage = "hit"
				th.t = 0.0
				th.n = 0
				th.acc = 0.0
				_hit_begin(kind)
				events.append("hit")
		"hit":
			_hit_step(kind, dt)
			if kind == "ox":
				flash = 1.0 - th.t / float(HIT_T[kind])
			if th.t >= float(HIT_T[kind]):
				th.stage = "settle"
				th.t = 0.0
		"settle":
			if kind == "abx":
				tide = maxf(0.0, 1.0 - th.t / SETTLE_T)
			flash = 0.0
			if th.t >= SETTLE_T:
				_verdict(kind)

func _verdict(kind: String) -> void:
	var th := threats
	var ok: bool = int(th.min) >= MEM_MIN
	th.results[th.idx] = "ok" if ok else "fail"
	# clean what the threat left
	phages = []
	amoeba = null
	tide = 0.0
	flash = 0.0
	for m in mols:
		if m.type == "abx" or m.type == "dna" or m.type == "baby":
			m.dead = true
	for q in pieces:
		q.abx = 0
		q.hij = 0.0
	th.stage = "wait"
	th.t = 0.0
	th.wait = wait_gap
	if ok:
		th.idx += 1
		events.append("threat_ok")
		if th.idx >= 4:
			th.done = true
			th.idx = 3
			events.append("threats_done")
	else:
		th.tries += 1
		events.append("threat_fail")

func _warn_begin(kind: String) -> void:
	var th := threats
	match kind:
		"phage":
			var trs := built_of("tr")
			var a := (trs[0].a if not trs.is_empty() else R(0, TAU)) as float
			th.a = a
			th.p2 = false
			_spawn_phage(a, WARN_T)
		"abx":
			th.blocked = ""
			if not built_of("rib").is_empty():
				th.blocked = "rib"
			else:
				for k in ORDER:
					if not built_of(k).is_empty():
						th.blocked = k
						break
		"ox":
			ox_a = R(0, TAU)
		"amoeba":
			var a2 := R(0, TAU)
			th.a = a2
			var far := 360.0 / zoom + 170.0
			var p1 := pol(RO + 40.0, a2)
			var p0 := CENTER + Vector2(cos(a2 + 0.35), sin(a2 + 0.35)) * (RO + 40.0 + far)
			amoeba = {"x": p0.x, "y": p0.y, "p0": p0, "p1": p1, "a": a2, "state": "come", "t": 0.0, "bite": 0.0, "engulf": 0.0, "hold": 0.0, "contact": false, "fl": 0.0}

func _spawn_phage(a: float, dur: float) -> void:
	var p1 := pol(RO + 26.0, a)
	var p0 := pol(RO + 26.0 + 240.0, a + 0.45)
	phages.append({"x": p0.x, "y": p0.y, "p0": p0, "p1": p1, "state": "in", "al": 1.0, "t": 0.0, "dur": dur, "land": 0.0, "inj": false, "a": a})

func _hit_begin(kind: String) -> void:
	if kind == "amoeba" and amoeba != null:
		amoeba.state = "bite"
		amoeba.contact = true

func _hit_step(kind: String, dt: float) -> void:
	var th := threats
	match kind:
		"phage":
			if not th.p2 and th.t >= 6.0:
				th.p2 = true
				_spawn_phage(th.a, 8.0)
		"abx":
			th.acc += dt
			if th.n < 8 and th.acc >= 0.5:
				th.acc = 0.0
				th.n += 1
				var h := 360.0 / zoom + 14.0
				var m := new_mol("abx", Vector2(CX + h, CY + R(-120, 120)), "in")
				m.v = Vector2.ZERO
		"ox":
			th.acc += dt
			if th.n < 80 and th.acc >= 0.1:
				th.acc = 0.0
				th.n += 1
				var ta := ox_a + R(-1.7, 1.7)
				var m2 := new_mol("ros", pol(RO + 150.0, ta), "ros")
				m2.ta = ta
				m2.prog = 1.0

func _threat_pieces(dt: float) -> void:
	var counters_building := pieces.any(func(q): return not q.built and COUNTERS.has(q.type))
	for q in pieces:
		if not q.built or is_mem(q) and q.type != "pump" and q.type != "spn":
			continue
		match q.type:
			"rib":
				q.pulse = maxf(0.0, q.pulse - dt * 2.5)
				var st := "listo"
				if q.hij > 0.0:
					st = "secuestrada"
				elif q.abx > 0:
					st = "bloqueada"
				elif counters_building:
					st = "trabaja"
					q.wait += dt
					if q.wait >= 5.0:
						q.wait = 0.0
						var a = nearest(mols.filter(func(m): return m.type == "atp" and m.state == "free"), q.pos)
						if a != null:
							a.dead = true
							float_text(q.pos + Vector2(0, -24), "−1 ATP", Color("9E392C"))
				q.st = st
				q.u += ((1.0 if st == "trabaja" else 0.0) - q.u) * minf(1.0, dt / 6.0)
			"cas":
				q.pulse = maxf(0.0, q.pulse - dt * 2.5)
				q.st = "bloqueada" if q.abx > 0 else ("trabaja" if q.off.length() > 4.0 else "listo")
				q.u += ((1.0 if q.st == "trabaja" else 0.0) - q.u) * minf(1.0, dt / 6.0)
			"cat":
				q.pulse = maxf(0.0, q.pulse - dt * 2.5)
				q.cool = maxf(0.0, q.cool - dt)
				q.st = "trabaja" if q.cool > 0.0 else "listo"
				q.u += ((1.0 if q.st == "trabaja" else 0.0) - q.u) * minf(1.0, dt / 6.0)
			"pump":
				q.open *= maxf(0.0, 1.0 - 6.0 * dt)
				q.st = "trabaja" if q.cool > 0.0 else "listo"
			"spn":
				q.st = "listo"

func _move_phages(dt: float) -> void:
	for f in phages:
		match f.state:
			"in":
				f.t += dt
				var k := minf(1.0, f.t / f.dur)
				var q: Vector2 = f.p0.lerp(f.p1, k)
				f.x = q.x
				f.y = q.y
				if k >= 1.0:
					f.state = "land"
					f.land = 0.0
			"land":
				f.land += dt
				if f.land >= 1.0 and not f.inj and threats.stage != "warn":
					f.inj = true
					f.state = "empty"
					f.land = 0.0
					_inject(f.a)
			"empty":
				f.land += dt
				if f.land >= 3.0:
					f.state = "gone"
			"gone":
				f.x += 30.0 * dt
				f.y -= 50.0 * dt
				f.al = maxf(0.0, f.al - dt * 0.5)
	phages = phages.filter(func(f): return f.al > 0.0)

func _inject(a: float) -> void:
	for t in built_of("tr"):
		if adiff(t.a, a) < 0.05:
			t.open = 1.0
	var cand: Array = built_of("rib").filter(func(r): return r.hij <= 0.0 and not mols.any(func(m): return m.type == "dna" and m.target == r))
	var tgt = null
	if cand.is_empty():
		tgt = _genome_p
	else:
		tgt = cand[int(R(0, cand.size())) % cand.size()]
	var m := new_mol("dna", pol(RI - 16.0, a), "go")
	m.v = Vector2.ZERO
	m.target = tgt
	m.sp = 70.0
	m.prog = 0.0
	burst(pol(RO + 20.0, a), Color("5FA36B"), true)
	float_text(pol(RO + 44.0, a), "inyecta", Color("3F7A4A"))

func _hijacks(dt: float) -> void:
	var th := threats
	var list: Array = built_of("rib")
	list.append(_genome_p)
	var cutting = null
	for r in list:
		if r.hij <= 0.0:
			continue
		r.hij -= dt
		r.cool += dt
		if r.cool >= 3.0:
			r.cool = 0.0
			var a = nearest(mols.filter(func(m): return m.type == "atp" and m.state == "free"), r.pos)
			if a != null:
				a.dead = true
		if int(r.hij * 0.8) != int((r.hij + dt) * 0.8) and count("baby") < 4:
			var b := new_mol("baby", r.pos, "free")
			b.ta = 6.0
		if r.hij <= 0.0:
			_lysis(ang(r.pos), 0.9, 0.2)
			events.append("lysis")
			if r != _genome_p:
				remove_piece(r)
		elif cutting == null:
			cutting = r
	var cas_list: Array = built_of("cas").filter(func(c): return c.abx == 0)
	if cutting != null and not cas_list.is_empty():
		th.cas_t += dt
		var c: Piece = cas_list[0]
		var d: Vector2 = cutting.pos - c.pos
		c.off = d.limit_length(maxf(d.length() - 22.0, 0.0)) * minf(1.0, th.cas_t / 1.2)
		if th.cas_t >= (CAS_CUT_T if not cas_primed else 1.5):
			th.cas_t = 0.0
			cutting.hij = 0.0
			cas_primed = true
			c.pulse = 1.0
			burst(cutting.pos, Color("3F8F86"), true)
			float_text(cutting.pos + Vector2(0, -30), "cortado", Color("2F6E67"))
			events.append("cut")
			for m in mols:
				if m.type == "baby":
					m.state = "exit"
					m.u = Vector2.from_angle(R(0, TAU))
					m.sp = 20.0
					m.age = 0.0
					m.ta = 1.2
	else:
		th.cas_t = 0.0
		for c in built_of("cas"):
			c.off = c.off * maxf(0.0, 1.0 - 4.0 * dt)

func _abx_pores(dt: float) -> void:
	var n := 0
	for m in mols:
		if m.type == "abx" and (m.state == "stuck" or m.state == "free"):
			n += 1
	if n == 0:
		return
	threats.pore += dt * n
	if threats.pore >= 1.4:
		threats.pore -= 1.4
		var i := int(R(0, NL))
		integ[i] = minf(integ[i], 0.3)

func _pumps(dt: float) -> void:
	for pm in built_of("pump"):
		pm.cool = maxf(0.0, pm.cool - dt)
		if pm.cool > 0.0:
			continue
		var cands: Array = mols.filter(func(m): return m.type == "abx" and (m.state == "stuck" or m.state == "free"))
		if cands.is_empty():
			continue
		var at: Vector2 = pol(RI - 18.0, pm.a)
		var atp = nearest(mols.filter(func(m): return m.type == "atp" and m.state == "free"), at)
		if atp == null:
			continue
		atp.dead = true
		burst(atp.p, Color("E2C240"))
		pm.cool = 0.6
		var ab = nearest(cands, at)
		if ab.state == "stuck" and ab.target != null:
			ab.target.abx = maxi(0, ab.target.abx - 1)
		ab.state = "pump"
		ab.target = pm

func _move_amoeba(dt: float) -> void:
	var am = amoeba
	if am == null:
		return
	var th := threats
	var spiked := built_of("spn").size() >= 3
	var big := tier >= 3
	match am.state:
		"come":
			am.t += dt
			var k := minf(1.0, am.t / WARN_T)
			k = 1.0 - (1.0 - k) * (1.0 - k)
			var q: Vector2 = am.p0.lerp(am.p1, k)
			am.x = q.x
			am.y = q.y
		"bite":
			if spiked:
				am.hold += dt
				if am.hold >= 1.5:
					am.state = "flee"
					float_text(pol(RO + 30.0, am.a), "pinchos", Color("3F6B2E"))
			else:
				am.bite += dt
				am.hold += dt
				if big and am.hold >= 6.0:
					am.state = "flee"
					float_text(pol(RO + 30.0, am.a), "grande", Color("3F6B2E"))
				elif am.bite >= 0.5:
					am.bite = 0.0
					for i in NL:
						if adiff(lang(i), am.a) < 0.5 and integ[i] > 0.0:
							integ[i] = maxf(0.0, integ[i] - 0.2)
					pulses.append({"a": am.a, "t": 0.0, "c": Color("9E392C")})
					am.engulf += 0.5 / 9.0
					if am.engulf >= 1.0 and not big:
						_lysis(am.a, 1.5, 0.1)
						float_text(pol(RO + 44.0, am.a), "engullida", Color("9E392C"))
						am.state = "flee"
		"flee":
			am.fl += dt
			am.contact = false
			am.x += cos(am.a) * 70.0 * dt
			am.y += sin(am.a) * 70.0 * dt
			if am.fl > 7.0:
				amoeba = null
	if amoeba != null:
		amoeba.contact = amoeba.state == "bite"

func _step_threat_mol(m: Mol, dt: float) -> void:
	var h := 360.0 / zoom + 30.0
	match m.type:
		"dna":
			var tgt: Piece = m.target
			if tgt == null or (tgt != _genome_p and not pieces.has(tgt)):
				m.target = _genome_p
				tgt = _genome_p
			var d: Vector2 = tgt.pos - m.p
			var dl := maxf(d.length(), 0.0001)
			var stp := minf(dl, m.sp * dt)
			m.p += d / dl * stp + Vector2(-d.y, d.x) / dl * sin(m.age * 10.0) * 14.0 * dt
			m.prog += stp
			m.v = d / dl * 40.0
			if cas_primed and _cas_ready() and m.prog >= 36.0:
				m.dead = true
				burst(m.p, Color("3F8F86"), true)
				float_text(m.p + Vector2(0, -22), "cortado", Color("2F6E67"))
				for k in [-1, 1]:
					var fr := new_mol("frag", m.p, "exit")
					fr.u = Vector2(k * 0.8, R(-0.6, 0.6))
					fr.sp = 40.0
					fr.ta = 1.4
					fr.age = 0.0
				for c in built_of("cas"):
					c.pulse = 1.0
					c.off = (m.p - c.pos).limit_length(120.0)
				events.append("cut")
			elif dl < 6.0:
				m.dead = true
				tgt.hij = HIJACK_T
				tgt.cool = 0.0
				threats.cas_t = 0.0
				tgt.pulse = 1.0
				burst(tgt.pos, Color("5FA36B"), true)
				float_text(tgt.pos + Vector2(0, -30), "secuestrado", Color("9E392C"))
				events.append("hijack")
		"baby":
			if m.state == "exit":
				m.p += m.u * m.sp * dt
			else:
				m.v += Vector2(R(-1, 1), R(-1, 1)) * 140.0 * dt
				m.v *= 1.0 - 1.4 * dt
				m.p += m.v * dt
				var r := rad(m.p)
				if r > RI - 14.0:
					m.p = CENTER + (m.p - CENTER) / maxf(r, 0.0001) * (RI - 14.0)
			if m.ta > 0.0 and m.age >= m.ta:
				m.alpha = maxf(0.0, 1.0 - (m.age - m.ta) / 0.8)
				if m.alpha <= 0.0:
					m.dead = true
		"frag":
			m.p += m.u * m.sp * dt
			m.alpha = maxf(0.0, 1.0 - m.age / m.ta)
			if m.alpha <= 0.0:
				m.dead = true
		"abx":
			match m.state:
				"in":
					var d2 := CENTER - m.p
					m.p += d2 / maxf(d2.length(), 0.0001) * 60.0 * dt + Vector2(R(-1, 1), R(-1, 1)) * 25.0 * dt
					if rad(m.p) < RI - 14.0:
						_abx_bind(m)
				"stuck":
					var t: Piece = m.target
					if t == null or not pieces.has(t):
						m.target = null
						m.state = "free"
					else:
						m.p = t.pos + m.u
				"free":
					m.v += Vector2(R(-1, 1), R(-1, 1)) * 140.0 * dt
					m.v *= 1.0 - 1.4 * dt
					m.p += m.v * dt
					var r2 := rad(m.p)
					if r2 > RI - 14.0:
						m.p = CENTER + (m.p - CENTER) / maxf(r2, 0.0001) * (RI - 14.0)
				"pump":
					var pm: Piece = m.target
					if pm == null or not pieces.has(pm):
						m.state = "free"
						m.target = null
					else:
						var mi := pol(RI - 18.0, pm.a)
						var dd := mi - m.p
						var l2 := maxf(dd.length(), 0.0001)
						m.p += dd / l2 * minf(l2, 150.0 * dt)
						if l2 < 8.0:
							pm.open = 1.0
							m.state = "exit"
							m.u = Vector2(cos(pm.a), sin(pm.a))
							m.sp = 150.0
							m.age = 0.0
							m.ta = 1.3
				"exit":
					m.p += m.u * m.sp * dt
					m.alpha = maxf(0.0, 1.0 - m.age / m.ta)
					if m.alpha <= 0.0:
						m.dead = true
			if (m.state == "stuck" or m.state == "free") and m.age > 26.0:
				if m.state == "stuck" and m.target != null:
					m.target.abx = maxi(0, m.target.abx - 1)
				m.dead = true

func _abx_bind(m: Mol) -> void:
	var kind: String = threats.blocked
	var best = null
	for q in pieces:
		if q.type == kind and q.built and q.abx < 4 and (best == null or q.abx < best.abx):
			best = q
	if best == null:
		m.state = "free"
		m.v = Vector2(R(-20, 20), R(-20, 20))
		return
	m.state = "stuck"
	m.target = best
	m.u = Vector2(R(-14, 14), R(-14, 12))
	best.abx += 1
	best.pulse = 1.0
	burst(best.pos, Color("7A5BB8"))

# ---------- read side for the HUD, tests and the aggregation sheet
func majority(k: String) -> String:
	var L := built_of(k)
	if L.is_empty():
		return ""
	var c := {}
	for e in L:
		c[e.st] = int(c.get(e.st, 0)) + 1
	var best := ""
	var bn := -1
	for key in c:
		if c[key] > bn:
			bn = c[key]
			best = key
	return best

## Returns a diagnosis key ("" when nothing is wrong): d_blackout d_membrane d_hk d_ald d_pk d_ldh d_syn d_syn_low d_glu
func diagnose() -> String:
	var hk := majority("hk")
	if hk == "falta ATP":
		return "d_blackout"
	if phase >= 5 and threats.stage == "wait" and threats.tries > 0 and not threats.done and threats.results[threats.idx] == "fail":
		return "d_threat"
	if phase >= 3 and mem_pct() < 90:
		return "d_membrane"
	if hk == "inhibida":
		return "d_hk"
	if majority("ald") == "atasco":
		return "d_ald"
	if majority("pk") == "atasco":
		return "d_pk"
	if majority("ldh") == "atasco":
		return "d_ldh"
	if majority("syn") == "atasco":
		return "d_syn"
	if majority("syn") == "inhibida":
		return "d_syn_low"
	if hk == "sin entrada":
		return "d_glu"
	return ""

func has_piece(t: String) -> bool:
	for p in pieces:
		if p.type == t:
			return true
	return false

## The phase hint as {"key": id, "args": [...]}.
func hint() -> Dictionary:
	var k := ""
	var args: Array = []
	if phase >= 5:
		return _hint5()
	if not has_piece("tr"):
		k = "h_tr"
	elif not has_piece("hk"):
		k = "h_hk"
	elif not has_piece("ald"):
		k = "h_ald"
	elif not has_piece("pk"):
		k = "h_pk"
	elif phase == 1:
		k = "h_p1"
	elif not has_piece("ldh"):
		k = "h_ldh"
	elif not has_piece("ex"):
		k = "h_ex"
	elif phase == 2:
		k = "h_p2"
	elif not has_piece("syn"):
		k = "h_syn"
	elif not has_piece("fl"):
		k = "h_fl"
	elif phase == 3:
		k = "h_p3"
	elif tier == 0:
		k = "h_t0"
	elif tier < TIERS:
		k = "h_tn"
		args = [tier]
	else:
		k = "h_final"
		args = [int(AGG_RATE)]
	return {"key": k, "args": args}

## The goal line as {"id", "args", "v", "max", "unit", "done"}; id is a string key for the view.
func goal() -> Dictionary:
	var rate := int(round(per("atp", 20.0)))
	var gv := 0
	var gm := 1
	var id := ""
	var args: Array = []
	var unit := ""
	if phase == 1:
		id = "g_energy"
		gv = int(goal_state.atp)
		gm = GOAL_ATP
		unit = "ATP"
	elif phase == 2:
		id = "g_waste"
		gv = int(goal_state.lac)
		gm = GOAL_LAC
	elif phase == 3:
		id = "g_membrane"
		gv = int(floor(goal_state.mem))
		gm = GOAL_MEM_SECONDS
		unit = "s"
	elif phase >= 5:
		id = "g_threats"
		args = [MEM_MIN]
		gv = threats.results.count("ok")
		gm = 4
	elif tier < TIERS:
		id = "g_grow"
		args = [tier, TIERS]
		gv = growth
		gm = need_g()
	elif not agg_done:
		id = "g_agg"
		args = [int(AGG_RATE), int(AGG_HOLD), rate]
		gv = int(floor(sustain))
		gm = int(AGG_HOLD)
		unit = "s"
	else:
		id = "g_agg_done"
		gv = 1
		gm = 1
	if phase < 4 and gv >= gm:
		goal_state.done = true
	var done: bool = goal_state.done if phase < 4 else agg_done
	if phase >= 5:
		done = threats.done
	return {"id": id, "args": args, "v": mini(gv, gm), "max": gm, "unit": unit, "done": done, "next_phase": phase + 1 if phase < 6 and (phase < 4 or done) else 0}

func stats() -> Dictionary:
	return {"atp": count("atp") + store, "atp_min": int(round(per("atp", 20.0))), "glu_min": int(round(per("glu", 20.0))),
		"mem": mem_pct(), "tier": tier, "tiers": TIERS, "phase": phase, "t": T}

## Per-enzyme usage: [{"type", "n", "use" 0..100, "status"}], then the membrane row as {"type":"membrane","tr","ex","fl"}.
func lines() -> Array:
	var rows: Array = []
	for k in LINE_ORDER:
		var L := built_of(k)
		if L.is_empty():
			continue
		var tot := 0.0
		for e in L:
			tot += e.u
		rows.append({"type": k, "n": L.size(), "use": int(round(tot / L.size() * 100.0)), "status": majority(k)})
	rows.append({"type": "membrane", "tr": built_of("tr").size(), "ex": built_of("ex").size(), "fl": built_of("fl").size()})
	return rows

## The stats sheet carried to the colony stage: [[key, text]] ("." decimals, the view localises).
func sheet_stats() -> Array:
	var g := per("glu", 60.0)
	var a := per("atp", 60.0)
	var nb := 0
	for p in pieces:
		if p.built:
			nb += 1
	return [["s_atp", "%d" % int(round(a))], ["s_glu", "%d" % int(round(g))], ["s_atp_glu", ("%.1f" % (a / g)) if g > 0.0 else "—"],
		["s_lip", "%d" % int(round(per("lip", 60.0)))], ["s_up", "%d" % int(round(per("up", 60.0)))], ["s_mem", "%d" % mem_pct()],
		["s_size", "%.2f" % (RO / R0)], ["s_pieces", "%d" % nb]]

## {"active": bool (the colony animation runs), "shown": the card is up, "t", "fade", "stats"}.
func aggregation() -> Dictionary:
	if agg == null:
		return {"active": false, "shown": false, "t": 0.0, "fade": -1.0, "done": agg_done, "stats": []}
	return {"active": true, "shown": agg.shown and not agg.has("fade"), "t": agg.t, "fade": agg.get("fade", -1.0), "done": agg_done, "stats": agg.stats}

## The numeric sheet of the cell that the colony and the creature inherit (counts of built pieces, rates per minute).
func legacy_sheet() -> Dictionary:
	var counts := {}
	for p in pieces:
		if p.built:
			counts[p.type] = int(counts.get(p.type, 0)) + 1
	var g := per("glu", 60.0)
	var a := per("atp", 60.0)
	return {"atp_min": int(round(a)), "glu_min": int(round(g)), "atp_per_glu": snappedf(a / g, 0.1) if g > 0.0 else 0.0,
		"lip_min": int(round(per("lip", 60.0))), "up_min": int(round(per("up", 60.0))), "mem": mem_pct(),
		"size": snappedf(RO / R0, 0.01), "tier": tier, "pieces": counts}

## "Seguir con esta célula": the card closes and the neighbours fade.
func continue_colony() -> void:
	if agg != null:
		agg["fade"] = 0.0

## Phase 5 opens after the aggregation; phase 6 once the four threats are survived.
func set_tier(n: int) -> void:
	tier = clampi(n, 0, TIERS)
	ROt = R0 + tier * RSTEP
	set_r(ROt)
	zoom = 270.0 / ROt
	zoomT = zoom

func threats_unlocked() -> bool:
	return agg_done or phase >= 5

func colony_unlocked() -> bool:
	return bool(threats.get("done", false))
