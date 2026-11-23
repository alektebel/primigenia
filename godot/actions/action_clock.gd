extends RefCounted
## Pure time functions of the action layer (docs/godot/PLAN-actions.md section 0.2). One tick = 0.1 s.
## `e` is the elapsed count of a move as the C state reports it (first state seen after the launch tick has
## e = 1), `tau = (e - 1) + alpha` is the continuous action time in ticks.

const DT := 0.1
## Wind-up, active, recovery ticks of the C moves (core/src/combat.c); the observed phase_length wins.
const TICKS := {0: [3, 1, 2], 1: [10, 5, 2], 2: [1, 14, 2], 3: [6, 1, 4], 4: [3, 2, 4], 5: [1, 3, 2], 6: [6, 6, 5], 7: [3, 3, 3], 8: [8, 4, 4], 10: [6, 1, 6]}
## The C moves that have an action file (pounce and the C roar are new with A74; the roar file is `roar_move`, the cosmetic `roar` keeps its own).
const MOVE_NAMES := {0: "bite", 1: "charge", 2: "guard", 3: "spit", 4: "tail_strike", 5: "dodge", 6: "flame", 7: "peck", 8: "pounce", 10: "roar_move"}
## A75: the attack set of the context attacks. "a" = the A74 picks (default), "b" = the second options the owner also liked (F10 option `attack set`).
static var attack_set := "a"

## C contexts (CB_CTX_*) of a pressed attack: 1 stand, 2 walk, 3 gallop, 4 far.
const CTX_SUFFIX := {1: "", 2: "_walk", 3: "_gallop", 4: "_far"}

## Wind-up, active, recovery ticks for a move in a context: the pounce gathers 6 ticks walking and 3 at the gallop and after the run-in (combat.c begin_move).
static func ticks_for(move: int, ctx: int) -> Array:
	var t: Array = TICKS.get(move, [3, 1, 2])
	if move == 8 and ctx == 2:
		return [6, t[1], t[2]]
	if move == 8 and (ctx == 3 or ctx == 4):
		return [3, t[1], t[2]]
	return t

## The action id the layer plays for a C move in a context, given the loaded ids and the attack set ("a" = the A74 picks, "b" = A75 set B).
## Falls back toward the plain move name so a body or a test with only the old files still works.
static func variant_id(move: int, ctx: int, hold: bool, have: Dictionary, set_b := false) -> String:
	var base: String = MOVE_NAMES.get(move, "")
	if base == "":
		return ""
	var sfx: String = CTX_SUFFIX.get(ctx, "")
	var tries: Array = []
	if move == 3 and hold:
		tries.append("spit_far_charged" if ctx == 4 else ("spit_glob_walk" if ctx == 2 or ctx == 3 else "spit_glob"))
	if set_b:
		tries.append(base + sfx + "_b")
	tries.append(base + sfx)
	tries.append(base)
	for t in tries:
		if have.has(t):
			return t
	return base
const SEGS := ["w", "a", "r", "s"]

## phase: 1 wind-up, 2 active, 3 recovery; ptick as in the C state.
static func elapsed(_move: int, phase: int, ptick: int, w: int, a: int) -> int:
	match phase:
		1: return ptick
		2: return w + ptick
		3: return w + a + ptick
	return 0

static func tau(e: int, alpha: float) -> float:
	return float(e - 1) + alpha

## -> {seg: "w"|"a"|"r"|"s", u: 0..1, done: bool}. Zero-length segments are skipped.
static func locate(t: float, w: float, a: float, r: float, settle_ticks: float) -> Dictionary:
	if t < w:
		return {"seg": "w", "u": t / w, "done": false}
	if t < w + a:
		return {"seg": "a", "u": (t - w) / a, "done": false}
	if t < w + a + r:
		return {"seg": "r", "u": (t - w - a) / r, "done": false}
	var u := (t - w - a - r) / maxf(settle_ticks, 1e-6)
	return {"seg": "s", "u": minf(u, 1.0), "done": u >= 1.0}

## Inverse of locate: action time (ticks) of segment `seg` at fraction `u`.
static func seg_time(seg: String, u: float, w: float, a: float, r: float, settle_ticks: float) -> float:
	match seg:
		"w": return u * w
		"a": return w + u * a
		"r": return w + a + u * r
	return w + a + r + u * settle_ticks

static func beat_u(tick: int, alpha: float, phase: int, period := 12) -> float:
	return fposmod(float(tick) + alpha - float(phase), float(period)) / float(period)

## Offset in ticks from `a:0` to the first accent so that one accent falls on a beat tick inside the
## active window [w, w + a) of an action that starts at `start_tick`; 0 when no beat lies inside.
static func grid_shift(start_tick: int, w: int, a: int, beat_phase: int, period := 12, step := 3) -> float:
	for k in range(a):
		var t := start_tick + w + k
		if posmod(t - beat_phase, period) == 0:
			return float(posmod(k, step))
	return 0.0
