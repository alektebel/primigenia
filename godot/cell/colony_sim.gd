extends RefCounted
## Phase 6, the colony: a small hex board where specialised copies of the founder cell are placed around it.
## No nodes, no drawing; stepped with a fixed dt like cell_sim.gd. Every block reuses the founder's stats sheet
## (sheet = Sim.legacy_sheet(): ATP per minute and membrane drive its production and its toughness).
## Rules: a block is placed next to the colony and its ATP cost is taken from a neighbour; neighbours share ATP
## (levels equalise); motile cells burn ATP to swim toward the light, the speed is thrust / mass; once the light is
## reached (with GOAL_CELLS blocks) an amoeba wave comes from a shown direction, bites the front line and is held off
## by defensive cells. Survive it with the founder alive and GOAL_CELLS blocks: "La colonia se convierte en criatura".

const BOARD_R := 2
const GOAL_CELLS := 7
const TARGET_DIST := 380.0
const CAP := 10.0
const WAVE_DELAY := 5.0
const WARN_T := 10.0
const BITES := 4
const BITE_DMG := 55.0
const SETTLE_T := 3.0
const DIRS := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

## cost in ATP (taken from a neighbour), prod = ATP/s at sheet rate 1, use = ATP/s burned, hp factor.
const BLOCKS := {
	"energy": {"n": ["Célula de energía", "Energy cell"], "cost": 5, "prod": 2.2, "use": 0.1, "hp": 1.0, "col": Color("E2C240"),
		"role": ["Fabrica ATP de sobra y lo reparte entre sus vecinas.", "Makes spare ATP and shares it with its neighbours."]},
	"motile": {"n": ["Célula móvil", "Motile cell"], "cost": 5, "prod": 0.0, "use": 0.1, "hp": 1.0, "col": Color("D4B37C"),
		"role": ["Flagelo: gasta ATP para nadar hacia la luz. La velocidad es empuje entre tamaño de la colonia.", "Flagellum: burns ATP to swim toward the light. Speed is thrust over colony size."]},
	"defense": {"n": ["Célula defensiva", "Defensive cell"], "cost": 6, "prod": 0.0, "use": 0.25, "hp": 1.6, "col": Color("8C7D5A"),
		"role": ["Espinas y membrana gruesa: la ameba que muerde aquí se pincha. Colócala en el lado del aviso.", "Spines and a thick membrane: an amoeba biting here is pricked. Put it on the side of the warning."]},
	"photo": {"n": ["Célula fotosintética", "Photosynthetic cell"], "cost": 6, "locked": true, "col": Color("7FA65A"),
		"role": ["Próximamente: vivirá de la luz.", "Coming soon: it will live on light."]},
}
const ORDER := ["energy", "motile", "defense", "photo"]

var rng := RandomNumberGenerator.new()
var seed_value := 1
var sheet := {}
var T := 0.0
var cells := {}              # Vector2i -> {kind, atp, hp, hp0, born, fed, hit}
var rate := 1.0              # the founder's ATP rate relative to the 150/min of the aggregation
var dist := TARGET_DIST
var speed := 0.0
var light_a := 0.0           # direction of the light/food seen from the colony
var arrived := false
var wave := {}
var flows := {}              # "q,r>q,r" -> recent ATP flow (for drawing)
var fx: Array = []           # {k "txt"/"ring", p (hex units), t, text, color}
var events: Array = []
var attempts := 0
var done := false
var done_t := 0.0
var founder_dead := false

func _init(seed_: int = 1, sheet_: Dictionary = {}) -> void:
	seed_value = seed_
	sheet = sheet_ if not sheet_.is_empty() else default_sheet()
	reset()

static func default_sheet() -> Dictionary:
	return {"atp_min": 150, "glu_min": 40, "atp_per_glu": 3.8, "lip_min": 12, "up_min": 10, "mem": 97, "size": 1.75, "tier": 5,
		"pieces": {"hk": 3, "ald": 3, "pk": 3, "ldh": 3, "syn": 3, "fl": 12, "tr": 6, "ex": 3, "rib": 2}}

func R(a: float, b: float) -> float:
	return rng.randf_range(a, b)

func reset() -> void:
	rng.seed = seed_value
	T = 0.0
	rate = clampf(float(sheet.get("atp_min", 150)) / 150.0, 0.6, 2.0)
	cells = {}
	var h0 := base_hp()
	cells[Vector2i.ZERO] = _cell("founder", 10.0, h0)
	dist = TARGET_DIST
	speed = 0.0
	light_a = R(-PI, PI)
	arrived = false
	wave = {"stage": "wait", "t": 0.0, "a": R(-PI, PI), "bites": 0, "absorbed": 0, "acc": 0.0, "tries": 0, "result": "", "min_cells": 0,
		"am": null}
	flows = {}
	fx = []
	events = []
	attempts = 0
	done = false
	done_t = 0.0
	founder_dead = false

func base_hp() -> float:
	return clampf(40.0 + float(sheet.get("mem", 100)) * 0.6, 40.0, 100.0)

func _cell(kind: String, atp: float, hp: float) -> Dictionary:
	return {"kind": kind, "atp": atp, "hp": hp, "hp0": hp, "born": T, "fed": false, "hit": 0.0}

# ---------- hex helpers (pointy top, size 1)
static func to_px(h: Vector2i) -> Vector2:
	return Vector2(sqrt(3.0) * (h.x + h.y * 0.5), 1.5 * h.y)

static func from_px(p: Vector2) -> Vector2i:
	var qf := (sqrt(3.0) / 3.0 * p.x - p.y / 3.0)
	var rf := p.y * 2.0 / 3.0
	var sf := -qf - rf
	var q := roundf(qf)
	var r := roundf(rf)
	var s := roundf(sf)
	var dq := absf(q - qf)
	var dr := absf(r - rf)
	var ds := absf(s - sf)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))

static func hex_dist(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return maxi(maxi(absi(d.x), absi(d.y)), absi(d.x + d.y))

static func on_board(h: Vector2i) -> bool:
	return hex_dist(h, Vector2i.ZERO) <= BOARD_R

func neighbours(h: Vector2i) -> Array:
	var out := []
	for d in DIRS:
		if cells.has(h + d):
			out.append(h + d)
	return out

## Hexes where a block can go now (empty, on the board, next to a cell).
func slots() -> Array:
	var out := []
	for q in range(-BOARD_R, BOARD_R + 1):
		for r in range(-BOARD_R, BOARD_R + 1):
			var h := Vector2i(q, r)
			if on_board(h) and not cells.has(h) and not neighbours(h).is_empty():
				out.append(h)
	return out

func count(kind: String = "") -> int:
	if kind == "":
		return cells.size()
	var n := 0
	for h in cells:
		if cells[h].kind == kind:
			n += 1
	return n

func total_atp() -> float:
	var s := 0.0
	for h in cells:
		s += cells[h].atp
	return s

## Why a block cannot go at h (a free hex next to the colony), without placing it: "" or unknown, locked, done, taken, far, atp.
## `ignore` is a hex whose block is being moved (it does not count as a neighbour).
func can_place(kind: String, h: Vector2i, ignore := Vector2i(99, 99)) -> String:
	if not BLOCKS.has(kind):
		return "unknown"
	if BLOCKS[kind].get("locked", false):
		return "locked"
	if done:
		return "done"
	if cells.has(h):
		return "taken"
	if not on_board(h):
		return "far"
	var near := neighbours(h)
	near.erase(ignore)
	if near.is_empty():
		return "far"
	if ignore != Vector2i(99, 99):
		return ""
	var best := -1.0
	for n in near:
		best = maxf(best, cells[n].atp)
	if best < BLOCKS[kind].cost:
		return "atp"
	return ""

## "" or an error (see can_place).
func place(kind: String, h: Vector2i) -> String:
	var err := can_place(kind, h)
	if err != "":
		return err
	var cost: float = BLOCKS[kind].cost
	var donor = null
	var best := -1.0
	for n in neighbours(h):
		if cells[n].atp > best:
			best = cells[n].atp
			donor = n
	cells[donor].atp -= cost
	cells[h] = _cell(kind, 0.0, base_hp() * BLOCKS[kind].hp)
	fx.append({"k": "ring", "p": h, "t": 0.0, "color": BLOCKS[kind].col})
	fx.append({"k": "txt", "p": donor, "t": 0.0, "text": "−%d ATP" % int(cost), "color": Color("9E392C")})
	return ""

## Why the block at `from` cannot move to `to` (free, still touching the colony without it): "" or founder, taken, far.
func can_move(from: Vector2i, to: Vector2i) -> String:
	if from == Vector2i.ZERO or not cells.has(from):
		return "founder"
	if from == to:
		return ""
	if cells.has(to):
		return "taken"
	if not on_board(to):
		return "far"
	var near := neighbours(to)
	near.erase(from)
	return "" if not near.is_empty() else "far"

## Moves a block (with its ATP and life) to a free hex; free of charge. Returns "" or the can_move error.
func move_block(from: Vector2i, to: Vector2i) -> String:
	var err := can_move(from, to)
	if err != "" or from == to:
		return err
	cells[to] = cells[from]
	cells.erase(from)
	fx.append({"k": "ring", "p": to, "t": 0.0, "color": BLOCKS[cells[to].kind].col})
	return ""

func remove_at(h: Vector2i) -> bool:
	if h == Vector2i.ZERO or not cells.has(h):
		return false
	cells.erase(h)
	return true

# ---------- the step
func step(dt: float) -> void:
	T += dt
	if done:
		done_t += dt
	_atp(dt)
	_motion(dt)
	_wave(dt)
	for f in fx:
		f.t += dt
	fx = fx.filter(func(f): return f.t < 1.1)
	for k in flows:
		flows[k] = flows[k] * maxf(0.0, 1.0 - 3.0 * dt)
	for h in cells:
		cells[h].hit = maxf(0.0, cells[h].hit - dt * 2.0)

func _atp(dt: float) -> void:
	# production and upkeep
	for h in cells:
		var c: Dictionary = cells[h]
		var prod := 0.0
		var use := 0.05
		if c.kind == "founder":
			prod = 0.7
		elif BLOCKS.has(c.kind):
			prod = float(BLOCKS[c.kind].get("prod", 0.0))
			use += float(BLOCKS[c.kind].get("use", 0.0))
		c.atp = clampf(c.atp + (prod * rate - use) * dt, 0.0, CAP)
		# a fed cell slowly mends
		if c.atp > 2.0 and c.hp < c.hp0:
			c.hp = minf(c.hp0, c.hp + 2.0 * dt)
	# neighbours share: levels equalise along every edge
	var delta := {}
	for h in cells:
		delta[h] = 0.0
	for h in cells:
		for d in [DIRS[0], DIRS[1], DIRS[5]]:
			var o: Vector2i = h + d
			if cells.has(o):
				var f: float = (cells[h].atp - cells[o].atp) * 0.6 * dt
				delta[h] -= f
				delta[o] += f
				if absf(f) > 0.0001:
					flows["%d,%d>%d,%d" % [h.x, h.y, o.x, o.y]] = f / dt
	for h in cells:
		cells[h].atp = clampf(cells[h].atp + delta[h], 0.0, CAP)

func _motion(dt: float) -> void:
	var fed := 0
	for h in cells:
		var c: Dictionary = cells[h]
		c.fed = false
		if c.kind == "motile":
			var need := 0.9 * rate * dt
			if c.atp >= need and not arrived:
				c.atp -= need
				c.fed = true
				fed += 1
	speed = 40.0 * fed / maxf(1.0, float(cells.size()))
	if not arrived:
		dist = maxf(0.0, dist - speed * dt)
		if dist <= 0.0:
			arrived = true
			events.append("arrived")

func _wave(dt: float) -> void:
	var w := wave
	if done:
		return
	if w.stage == "wait":
		# the wave starts once the light is reached with a colony of GOAL_CELLS
		if arrived and cells.size() >= GOAL_CELLS:
			w.t += dt
			if w.t >= WAVE_DELAY:
				w.stage = "warn"
				w.t = 0.0
				w.min_cells = cells.size()
				events.append("warn")
		else:
			w.t = 0.0
	elif w.stage == "warn":
		w.t += dt
		if w.t >= WARN_T:
			w.stage = "hit"
			w.t = 0.0
			w.bites = 0
			w.absorbed = 0
			w.acc = 0.0
			events.append("hit")
	elif w.stage == "hit":
		w.t += dt
		w.acc += dt
		if w.bites < BITES and w.acc >= (1.0 if w.bites == 0 else 1.2):
			w.acc = 0.0
			w.bites += 1
			_bite()
		w.min_cells = mini(int(w.min_cells), cells.size())
		if w.absorbed >= 2 or (w.bites >= BITES and w.acc >= 1.0):
			w.stage = "settle"
			w.t = 0.0
	elif w.stage == "settle":
		w.t += dt
		if w.t >= SETTLE_T:
			var ok := not founder_dead and cells.has(Vector2i.ZERO) and cells.size() >= GOAL_CELLS
			if ok:
				w.result = "ok"
				done = true
				done_t = 0.0
				events.append("colony_done")
			else:
				w.result = "fail"
				w.tries += 1
				attempts += 1
				events.append("wave_fail")
				if founder_dead:
					founder_dead = false
					cells[Vector2i.ZERO] = _cell("founder", 6.0, base_hp())
				w.stage = "wait"
				w.t = 0.0
				w.a = R(-PI, PI)

## The cells on the front line of an attack from angle a: those within one hex of the furthest projection.
func front(a: float) -> Array:
	var d := Vector2(cos(a), sin(a))
	var best := -1e9
	var proj := {}
	for h in cells:
		var p := to_px(h).dot(d)
		proj[h] = p
		best = maxf(best, p)
	var out := []
	for h in cells:
		if proj[h] >= best - 1.0:
			out.append(h)
	out.sort_custom(func(x, y): return proj[x] > proj[y] or (proj[x] == proj[y] and (x.x < y.x or (x.x == y.x and x.y < y.y))))
	return out

func _bite() -> void:
	var cand := front(wave.a)
	var h: Vector2i = cand[int(R(0, cand.size())) % cand.size()]
	var c: Dictionary = cells[h]
	c.hit = 1.0
	if c.kind == "defense":
		wave.absorbed += 1
		fx.append({"k": "txt", "p": h, "t": 0.0, "text": "pinchos", "color": Color("3F6B2E")})
		return
	c.hp -= BITE_DMG
	fx.append({"k": "txt", "p": h, "t": 0.0, "text": "−%d" % int(BITE_DMG), "color": Color("9E392C")})
	if c.hp <= 0.0:
		if h == Vector2i.ZERO:
			founder_dead = true
			c.hp = 0.0
		else:
			cells.erase(h)
			fx.append({"k": "ring", "p": h, "t": 0.0, "color": Color("9E392C")})

# ---------- read side
func goal() -> Dictionary:
	var stage: String = wave.stage
	return {"cells": cells.size(), "goal_cells": GOAL_CELLS, "arrived": arrived, "dist": dist, "frac": 1.0 - dist / TARGET_DIST,
		"wave": stage, "wave_eta": maxf(0.0, WARN_T - wave.t) if stage == "warn" else 0.0, "wave_a": wave.a, "tries": wave.tries,
		"done": done, "founder_dead": founder_dead, "light_a": light_a}

## The hint as {"key", "args"}; the view turns it into text.
func hint() -> Dictionary:
	var g := goal()
	if done:
		return {"key": "ch_done", "args": []}
	if g.wave == "hit":
		return {"key": "ch_hit", "args": []}
	if g.wave == "warn":
		return {"key": "ch_warn", "args": [int(ceil(g.wave_eta))]}
	if wave.tries > 0 and cells.size() < GOAL_CELLS:
		return {"key": "ch_fail", "args": [GOAL_CELLS]}
	if count("energy") == 0:
		return {"key": "ch_energy", "args": []}
	if count("motile") == 0:
		return {"key": "ch_motile", "args": []}
	if cells.size() < GOAL_CELLS:
		return {"key": "ch_grow", "args": [cells.size(), GOAL_CELLS]}
	if not arrived:
		return {"key": "ch_swim", "args": [int(round(g.frac * 100.0))]}
	if count("defense") == 0:
		return {"key": "ch_defense", "args": []}
	return {"key": "ch_wait", "args": []}

func take_events() -> Array:
	var e := events
	events = []
	return e

## Composition for the carry-over sheet.
func composition() -> Dictionary:
	return {"cells": cells.size(), "energy": count("energy"), "motile": count("motile"), "defense": count("defense"), "photo": count("photo")}
