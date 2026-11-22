extends RefCounted
## Gait selection and timing from the Froude number (Alexander 1984) with
## Hildebrand footfall patterns.
##
## Fr = v^2 / (g h), h = hip height. Animals of very different size change
## gait at about the same Fr: walk -> run/trot near 0.5, trot -> gallop near 2.5.

const G := 9.81
const FR_WALK_RUN := 0.5
const FR_TROT_GALLOP := 2.5
const FR_HEAVY_RUN := 1.8
const HYSTERESIS := 0.05
## F10 option `gait` (devtools/tuning/option_defs.gd): true = the Froude rules of the gait lab (docs/evidence/loco/gaitlab.md,
## rules 1-9, tracker M1), false = the pre-port rules (kept for A/B). Default froude.
static var froude_mode := true
const FR_STRIDE_CAP := 6.0      # rule 3: the Fr fed to the stride law stops growing here; cadence takes the rest
const HYST_LAB := 0.04          # rule 1
const FR_HEXAPOD_WAVE := 0.15   # rule 1: wave below, tripod above

## Per-plan ladders: [slower gait, faster gait, Fr of the change].
static func ladder(morph) -> Array:
	match morph.plan:
		&"upright_biped", &"horizontal_biped":
			return [[&"walk", &"run", FR_WALK_RUN]]
		&"quadruped":
			if heavy(morph):
				# heavy bodies never leave the ground for long: a running amble, then a heavy trot with no flight (duty 0.5, elephant-like)
				return [[&"walk", &"amble", FR_WALK_RUN], [&"amble", &"trot", FR_HEAVY_RUN]]
			return [[&"walk", &"trot", FR_WALK_RUN], [&"trot", &"gallop", FR_TROT_GALLOP]]
		&"multi":
			# rule 1: a hexapod waves (one leg at a time) below Fr 0.15 and runs a tripod above; 8 legs are metachronal always
			if froude_mode and morph.stations.size() == 3:
				return [[&"ripple", &"tripod", FR_HEXAPOD_WAVE]]
			return []
		_:
			return []

static func base_gait(morph) -> StringName:
	match morph.plan:
		&"legless": return &"slither"
		&"monopod": return &"hop"
		&"multi": return &"ripple" if morph.stations.size() >= 4 else &"tripod"
		_: return &"walk"

## Graviportal (very heavy) bodies keep the amble-and-heavy-trot ladder only in the pre-port rules: the owner's A39 has every body
## run with a flight phase at Fr 1.5, the hero included.
static func heavy(morph) -> bool:
	return morph.graviportal and not froude_mode

static func froude(speed: float, hip_height: float) -> float:
	return speed * speed / (G * max(hip_height, 1e-3))

## Gait for this Froude number, with hysteresis around each change.
static func select(morph, prev: StringName, fr: float) -> StringName:
	var lad := ladder(morph)
	if lad.is_empty():
		return base_gait(morph)
	var names: Array = [lad[0][0]]
	for r in lad:
		names.append(r[1])
	var k: int = max(names.find(prev), 0)
	var hy: float = HYST_LAB if froude_mode else HYSTERESIS
	while k < lad.size() and fr > lad[k][2] + hy:
		k += 1
	while k > 0 and fr < lad[k - 1][2] - hy:
		k -= 1
	return names[k]

## Fraction of the stride a foot spends on the ground.
static func duty(gait: StringName, fr: float, heavy := false, eight_leg := false) -> float:
	var f: float = max(fr, 1e-4)
	if froude_mode:
		# rule 2 (starting values, tracker M1)
		match gait:
			&"walk":
				return clamp(0.78 - 0.46 * minf(f, 0.5), 0.55, 0.78)
			&"trot":
				return clamp(0.48 * pow(f / 0.5, -0.25), 0.5 if heavy else 0.28, 0.48)
			&"run", &"hop":
				if heavy:
					return 0.5
				return clamp(0.48 * pow(f / 0.5, -0.3), 0.22, 0.48)
			&"gallop": return clamp(0.32 * pow(f / 2.5, -0.3), 0.2, 0.32)
			&"tripod": return clamp(0.62 - 0.05 * f, 0.52, 0.62)
			&"ripple":
				# the hexapod wave is slow and heavy on the ground (duty 0.78); 8 legs: metachronal log curve
				return 0.78 if f < FR_HEXAPOD_WAVE and not eight_leg else clamp(0.7 - 0.08 * log(maxf(f / 0.05, 1e-3)) / log(10.0), 0.55, 0.75)
			&"amble": return clamp(0.55 * pow(f, -0.1), 0.53, 0.65)
			&"slither": return 1.0
	match gait:
		&"walk": return clamp(0.47 * pow(f, -0.18), 0.53, 0.88)
		&"tripod": return clamp(0.47 * pow(f, -0.18), 0.5, 0.85)
		&"ripple": return clamp(0.5 * pow(f, -0.15), 0.5, 0.85)
		# M1 starting value: an amble keeps overlapping support like a walk;
		# a sub-half duty made the hero hop between lateral couplets.
		&"amble": return clamp(0.55 * pow(f, -0.1), 0.53, 0.65)
		&"run", &"trot", &"hop":
			return clamp(0.40 * pow(f, -0.2), 0.5 if heavy else 0.2, 0.5 if heavy else 0.48)
		&"gallop": return clamp(0.36 * pow(f, -0.25), 0.15, 0.32)
	return 1.0

## How much of the body motion is a bounce (spring-mass) rather than a vault
## (inverted pendulum): 0 = pendulum, 1 = spring.
static func bounce(gait: StringName) -> float:
	match gait:
		&"walk": return 0.0
		&"tripod": return 0.25
		&"ripple": return 0.2
		&"amble": return 0.6
		&"slither": return 0.0
	return 1.0

## Relative stride length (Alexander & Jayes 1983): stride / h = 2.3 Fr^0.3
## for walks and trots, 1.9 Fr^0.4 for gallops.
static func stride_length(gait: StringName, fr: float, hip_height: float) -> float:
	var f: float = max(fr, 1e-4)
	if froude_mode:
		# rule 3: Fr capped at 6 in the law, walk stride uses Fr up to 0.5 only; cadence = v / stride is the caller's job
		f = minf(f, FR_STRIDE_CAP)
		if gait == &"walk" or gait == &"tripod" or gait == &"ripple":
			f = minf(f, 0.5) if gait == &"walk" else f
	var rel := 2.3 * pow(f, 0.3)
	if gait == &"gallop":
		rel = 1.9 * pow(f, 0.4)
	return max(rel, 0.3) * hip_height

## Metachronal wave lag between neighbouring stations (rule 4).
static func lag_metachronal(fr: float) -> float:
	return clampf(0.22 * pow(maxf(fr, 0.05) / 0.05, -0.23), 0.08, 0.22)

## Fr the metachronal lag is computed for (set by the controller before it asks for offsets).
static var fr_hint := 0.3

## Touchdown phase of each leg as a fraction of the stride (Hildebrand).
static func offsets(gait: StringName, morph) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var legs: Array = morph.legs
	out.resize(legs.size())
	var n := legs.size()
	if n == 0:
		return out
	if morph.plan == &"quadruped":
		for i in range(n):
			var l: Dictionary = legs[i]
			var hind: bool = l.station == 0
			var left: bool = l.side >= 0
			var p := 0.0
			if froude_mode:
				# rule 4: walk RH 0, RF .25, LH .5, LF .75; trot LH = RF = 0, RH = LF = .5; gallop LH 0, RH .1, LF .5, RF .6
				match gait:
					&"walk": p = (0.0 if hind else 0.25) + (0.5 if left else 0.0)
					&"amble": p = (0.0 if hind else 0.2) + (0.5 if left else 0.0)
					&"trot": p = 0.0 if (hind == left) else 0.5
					&"gallop": p = (0.0 if hind else 0.5) + (0.0 if left else 0.1)
				out[i] = fposmod(p, 1.0)
				continue
			match gait:
				&"walk":   # lateral sequence: LH, LF, RH, RF
					p = (0.0 if hind else 0.25) + (0.0 if left else 0.5)
				&"amble":  # lateral sequence drifting toward lateral couplets
					p = (0.0 if hind else 0.2) + (0.0 if left else 0.5)
				&"trot":   # diagonal couplets
					p = 0.0 if (hind == left) else 0.5
				&"gallop": # transverse gallop, left lead: RH, LH, RF, LF then suspension
					p = (0.0 if hind else 0.30) + (0.10 if left else 0.0) + (0.02 if (left and not hind) else 0.0)
			out[i] = fposmod(p, 1.0)
		return out
	if froude_mode and morph.plan == &"multi" and gait == &"ripple":
		# rule 4: metachronal i x lag + 0.5 x side, the lag 0.22 at Fr 0.05 falling as (Fr/0.05)^-0.23 to about 0.08 (the caller
		# passes the wave lag through `lag`); a hexapod wave has a lag of 1/6
		var ns2: int = morph.stations.size()
		var lag: float = 1.0 / 6.0 if ns2 == 3 else lag_metachronal(fr_hint)
		for i in range(n):
			var l: Dictionary = legs[i]
			out[i] = fposmod(float(l.station) * lag + (0.0 if l.side >= 0 else 0.5), 1.0)
		return out
	if morph.plan == &"multi" and gait == &"ripple":
		# metachronal wave: each station lands a little after the one behind it, the two sides in antiphase
		var ns: int = morph.stations.size()
		for i in range(n):
			var l: Dictionary = legs[i]
			out[i] = fposmod(float(l.station) * (0.75 / ns) + (0.0 if l.side >= 0 else 0.5), 1.0)
		return out
	if morph.plan == &"multi":
		# alternating tripod (tetrapod for 8 legs...): neighbours along the body
		# and across it are in antiphase.
		for i in range(n):
			var l: Dictionary = legs[i]
			var s := 0 if l.side >= 0 else 1
			out[i] = 0.5 * float((l.station + s) % 2)
		if morph.stations.size() < 2:
			for i in range(n):
				out[i] = float(i) / n
		return out
	# bipeds and monopods: alternate
	var k := 0
	for i in range(n):
		out[i] = fposmod(0.5 * k, 1.0)
		k += 1
	return out

## Spine flexion in a gallop (rad of arch: + brings head and tail down, - lifts them) over the stride phase.
## Gathered after the hind push (flexion) and stretched in the flight (extension), as in a bounding mammal.
static func spine_flex(gait: StringName, phase: float, fr: float) -> float:
	if gait != &"gallop":
		return 0.0
	var amp: float = clamp(0.045 * pow(max(fr, 0.1) / 2.5, 0.3), 0.0, 0.11)
	return amp * sin(TAU * (phase - 0.15))

## Forward lean of the body in a run (rad, nose down), from the Froude number.
static func run_lean(plan: StringName, gait: StringName, fr: float) -> float:
	if froude_mode:
		return lean_lab(gait, fr)
	if gait != &"run":
		return 0.0
	var k := 0.16 if plan == &"upright_biped" else 0.07
	return k * smoothstep(0.4, 3.0, fr)


## Rule 6: hip height = h (a0 + a1 W), W = max over grounded legs of sin(pi * stance progress). Returns [a0, a1].
## Walk is high at mid-stance (inverted pendulum), run and trot are lowest at mid-stance (spring-mass), many-legged is flat.
static func bob_coeffs(gait: StringName) -> Vector2:
	match gait:
		&"walk", &"amble": return Vector2(0.965, 0.045)
		&"run", &"trot", &"hop": return Vector2(1.03, -0.09)
		&"gallop": return Vector2(1.03, -0.10)
	return Vector2(1.0, 0.0)

## Rule 5: swing lift as a share of hip height: 0.12 in a walk, 0.2-0.25 in a run.
static func lift_share(gait: StringName, fr: float) -> float:
	match gait:
		&"run", &"trot", &"hop", &"gallop":
			return lerpf(0.20, 0.25, clampf((fr - 1.0) / 2.0, 0.0, 1.0))
	return 0.12 + 0.09 * minf(1.0, fr / 0.5)   # starting value: a walk lifts a little higher as it speeds up

## Rule 9: forward lean in a run, 0.12 smoothstep(0.4, 3, Fr) (rad).
static func lean_lab(gait: StringName, fr: float) -> float:
	if gait == &"run" or gait == &"trot" or gait == &"gallop":
		return 0.12 * smoothstep(0.4, 3.0, fr)
	return 0.0
