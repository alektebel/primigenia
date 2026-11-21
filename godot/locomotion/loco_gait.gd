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

## Per-plan ladders: [slower gait, faster gait, Fr of the change].
static func ladder(morph) -> Array:
	match morph.plan:
		&"upright_biped", &"horizontal_biped":
			return [[&"walk", &"run", FR_WALK_RUN]]
		&"quadruped":
			if morph.graviportal:
				# heavy bodies never leave the ground for long: a running amble, then a heavy trot with no flight (duty 0.5, elephant-like)
				return [[&"walk", &"amble", FR_WALK_RUN], [&"amble", &"trot", FR_HEAVY_RUN]]
			return [[&"walk", &"trot", FR_WALK_RUN], [&"trot", &"gallop", FR_TROT_GALLOP]]
		&"multi":
			return []
		_:
			return []

static func base_gait(morph) -> StringName:
	match morph.plan:
		&"legless": return &"slither"
		&"monopod": return &"hop"
		&"multi": return &"ripple" if morph.stations.size() >= 4 else &"tripod"
		_: return &"walk"

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
	while k < lad.size() and fr > lad[k][2] + HYSTERESIS:
		k += 1
	while k > 0 and fr < lad[k - 1][2] - HYSTERESIS:
		k -= 1
	return names[k]

## Fraction of the stride a foot spends on the ground.
static func duty(gait: StringName, fr: float, heavy := false) -> float:
	var f: float = max(fr, 1e-4)
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
	var rel := 2.3 * pow(f, 0.3)
	if gait == &"gallop":
		rel = 1.9 * pow(f, 0.4)
	return max(rel, 0.3) * hip_height

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
	if gait != &"run":
		return 0.0
	var k := 0.16 if plan == &"upright_biped" else 0.07
	return k * smoothstep(0.4, 3.0, fr)
