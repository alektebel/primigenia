extends RefCounted
## Wing kinematics (motion-flight plan 3c, slice W2): the procedural flap, glide, dive, flare and ground pose of a
## creature's wing hooks, driven by a flight state. Pure maths on a few eased channels, like the locomotion controller.
##
##   var wing = LocoWing.new(mass_kg, wing_info)         # wing_info: creature_wing.gd info() of one side
##   wing.step(dt, {"mode": "flap", "power": 1.0, "pitch": 0.0})
##   LocoWing.apply(creature, wing.channels())           # writes every part's wing hook (and vane hinges)
##
## Modes: ground (the legacy folded/spread pose of the action layer, so the hand-off back to it has no pop), glide, flap,
## dive (wings folded to 40 % of the span, swept back), flare (wings cupped up and forward for touchdown).
## The channels are eased, so a change of mode never pops; the beat phase is continuous and only advances while flapping.
## Hinge only: today's rigid sails flap as a unit; vanes also fan open and closed (W1 will bring the articulated chain).

const BEAT_HZ_1KG := 4.5            # f = 4.5 (m / 1 kg)^(-1/6) Hz (Pennycuick 1996, adopted in the plan)
const BEAT_C_LAB := 4.8             # lab law f = 4.8 m^(-1/3) Hz (geometric similarity, web/gaitlab/flight.html; unchecked, from memory)
## Wingbeat scaling, an F10 option (owner to decide, A56): "game" = 4.5 m^-1/6 (2.5 Hz at 36 kg), "lab" = 4.8 m^-1/3 (1.5 Hz at 36 kg).
static var scaling := "game"
const DOWNSTROKE := 0.58            # share of the beat spent on the downstroke
const TAU_DEPLOY := 0.16            # s, first-order time constants of the channels (UI motion rule: <= 250 ms to settle)
const TAU_AMP := 0.10
const TAU_FOLD := 0.10
const TAU_FLARE := 0.08
# The pose the action layer writes with display = 0 (action_rig.gd): ground values, so ground -> flight -> ground is continuous.
const GROUND_FLAP := 0.12
const GROUND_SWEEP := 0.32
const GLIDE_FLAP := 0.20            # dihedral
const GLIDE_SWEEP := 0.05
const GLIDE_INC := -0.12            # leading edge up a little
const BOB_SPAN := 0.02              # share of the span (lab: 0.03; the camera follows the body, so a little less)
const DIVE_SWEEP := 1.15
const DIVE_FLAP := -0.15
const DIVE_SPAN := 0.4              # the same 40 % of the area the flight model uses
const FLARE_FLAP := 0.45
const FLARE_INC := -0.7
const FLARE_SWEEP := -0.1

var info: Dictionary = {}
var mass := 1.0
var hz := 3.0
var mode := "ground"
var phase := 0.0            # beat phase 0..1, 0 = top of the stroke
var deploy := 0.0           # 0 ground pose .. 1 flight pose
var amp := 0.0              # 0 gliding .. 1 full stroke
var fold := 0.0             # dive tuck
var flare := 0.0
var power := 1.0            # stroke size 0..1 (70..110 deg for membranes, 90..150 for sails)
var bank := 0.0             # -1..1 share of the sharpest bank, + = banked left (left wing inner)
var pitch := 0.0            # +1 = nose up input (more incidence), -1 = nose down


static func beat_hz(mass_kg: float, law: String = "") -> float:
	var m := maxf(mass_kg, 0.05)
	if (law if law != "" else scaling) == "lab":
		return BEAT_C_LAB * pow(m, -1.0 / 3.0)
	return BEAT_HZ_1KG * pow(m, -1.0 / 6.0)


## Re-reads the scaling option (live change from F10): the beat rate of this wing follows the new law.
func set_mass(mass_kg: float) -> void:
	mass = mass_kg
	hz = beat_hz(mass_kg)

## Body bob in metres: the body rises as the wings go down (the reaction to the downstroke), falls on the upstroke. Visual only.
func bob() -> float:
	if amp < 0.01:
		return 0.0
	var x := 0.5 * phase / DOWNSTROKE if phase < DOWNSTROKE else 0.5 + 0.5 * (phase - DOWNSTROKE) / (1.0 - DOWNSTROKE)
	return -BOB_SPAN * 2.0 * float(info.get("span", 1.0)) * amp * cos(TAU * x)


func _init(mass_kg: float = 1.0, wing_info: Dictionary = {}) -> void:
	mass = mass_kg
	hz = beat_hz(mass_kg)
	info = wing_info


static func smooth(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _ease(cur: float, target: float, tau: float, dt: float) -> float:
	return target if dt <= 0.0 else lerpf(cur, target, 1.0 - exp(-dt / tau))


## cmd: {mode, power (0..1, default 1), pitch (-1..1)}
func step(dt: float, cmd: Dictionary) -> void:
	mode = str(cmd.get("mode", mode))
	power = clampf(float(cmd.get("power", power)), 0.0, 1.0)
	pitch = clampf(float(cmd.get("pitch", pitch)), -1.0, 1.0)
	bank = _ease(bank, clampf(float(cmd.get("bank", 0.0)), -1.0, 1.0), 0.12, dt)
	var flaps: bool = bool(info.get("flaps", true))
	deploy = _ease(deploy, 0.0 if mode == "ground" else 1.0, TAU_DEPLOY, dt)
	amp = _ease(amp, 1.0 if (mode == "flap" and flaps) else 0.0, TAU_AMP, dt)
	fold = _ease(fold, 1.0 if mode == "dive" else 0.0, TAU_FOLD, dt)
	flare = _ease(flare, 1.0 if mode == "flare" else 0.0, TAU_FLARE, dt)
	if amp > 0.02 or mode == "flap":
		phase = fposmod(phase + dt * hz, 1.0)


## Stroke angle (rad, relative to the glide dihedral) and the retraction / incidence / sweep waves at phase u.
func beat(u: float) -> Dictionary:
	var stroke: Array = info.get("stroke", [70.0, 110.0])
	var a := deg_to_rad(lerpf(float(stroke[0]), float(stroke[1]), power))
	var top := a * 0.55
	var bottom := -a * 0.45
	var x: float
	var wave: float
	var up := 0.0                       # 0 on the downstroke, bump 0..1 on the upstroke
	var down := 0.0                     # bump 0..1 on the downstroke
	if u < DOWNSTROKE:
		x = u / DOWNSTROKE
		wave = lerpf(top, bottom, smooth(x))
		down = 4.0 * x * (1.0 - x)
	else:
		x = (u - DOWNSTROKE) / (1.0 - DOWNSTROKE)
		wave = lerpf(bottom, top, smooth(x))
		up = 4.0 * x * (1.0 - x)
	return {"wave": wave, "up": up, "down": down}


## The pose to write: {flap, sweep, inc, span (x scale), spread (vane fan 0..1)}.
func channels() -> Dictionary:
	var b := beat(phase)
	var reverse: bool = bool(info.get("pitch_reverse", false))
	var retract: float = float(info.get("retract", 0.0))
	# flight pose: glide values, with the stroke blended in by `amp`
	var inc_glide := GLIDE_INC - 0.25 * pitch
	var flap_f: float = lerpf(GLIDE_FLAP, GLIDE_FLAP + b.wave, amp)
	var sweep_f: float = GLIDE_SWEEP + amp * 0.30 * b.up      # upstroke: the wrist flexes, the tip trails (recovery fold)
	var inc_dn := -0.5 if reverse else -0.2       # sails reverse their pitch between the strokes
	var inc_up := 0.5 if reverse else 0.12
	var inc_f: float = inc_glide + amp * (inc_dn * b.down + inc_up * b.up)
	var span_f: float = 1.0 + amp * 0.04 * b.down - amp * retract * b.up      # downstroke: full reach, the power stroke
	var spread_f: float = 1.0 - 0.45 * amp * b.up
	# dive: swept back and down, folded to 40 % of the span
	flap_f = lerpf(flap_f, DIVE_FLAP, fold)
	sweep_f = lerpf(sweep_f, DIVE_SWEEP, fold)
	inc_f = lerpf(inc_f, 0.0, fold)
	span_f = lerpf(span_f, DIVE_SPAN, fold)
	spread_f = lerpf(spread_f, 0.15, fold)
	# flare: cupped up and forward, fully open
	flap_f = lerpf(flap_f, FLARE_FLAP, flare)
	sweep_f = lerpf(sweep_f, FLARE_SWEEP, flare)
	inc_f = lerpf(inc_f, FLARE_INC, flare)
	span_f = lerpf(span_f, 1.0, flare)
	spread_f = lerpf(spread_f, 1.0, flare)
	return {
		"bank": bank * deploy * (1.0 - fold) * (1.0 - flare),
		"flap": lerpf(GROUND_FLAP, flap_f, deploy), "sweep": lerpf(GROUND_SWEEP, sweep_f, deploy),
		"inc": lerpf(0.0, inc_f, deploy), "span": lerpf(1.0, span_f, deploy), "spread": lerpf(1.0, spread_f, deploy),
	}


## Writes the channels into every wing hook of a Creature (parts[].hooks.wing; vane hinges in the group's "vanes" meta).
static func apply(creature, ch: Dictionary) -> void:
	for e in creature.parts:
		var h: Dictionary = e.hooks
		if not h.has("wing"):
			continue
		var w: Node3D = h.wing
		# a banked turn: the inner wing is flexed (shorter, swept back) and held higher, the outer one extended. Left is +X.
		var inner := 0.0
		var b: float = float(ch.get("bank", 0.0))
		if b != 0.0:
			var left: bool = (creature.to_local(w.global_position).x >= 0.0) if creature.is_inside_tree() else (w.position.x >= 0.0)
			inner = b if left else -b           # + = this wing is the inner one, - = the outer one
		var span_k := float(ch.span) * (1.0 - 0.22 * inner if inner > 0.0 else 1.0 - 0.10 * inner)
		var flap_k := float(ch.flap) + 0.18 * inner
		var sweep_k := float(ch.sweep) + 0.30 * maxf(inner, 0.0)
		w.basis = Basis.from_euler(Vector3(float(ch.inc), sweep_k, flap_k), EULER_ORDER_YXZ) * Basis.from_scale(Vector3(span_k, 1.0, 1.0))
		if w.has_meta("vanes"):
			for v in w.get_meta("vanes"):
				if v is Node3D:
					(v as Node3D).rotation.y = float(v.get_meta("rest_angle", 0.0)) * float(ch.spread)


## Back to the action layer's own hinge values (it rewrites rotation.z/y every frame; this clears the incidence and span).
static func release(creature) -> void:
	for e in creature.parts:
		var h: Dictionary = e.hooks
		if not h.has("wing"):
			continue
		var w: Node3D = h.wing
		w.basis = Basis.from_euler(Vector3(0.0, GROUND_SWEEP, GROUND_FLAP), EULER_ORDER_YXZ)
		if w.has_meta("vanes"):
			for v in w.get_meta("vanes"):
				if v is Node3D:
					(v as Node3D).rotation.y = float(v.get_meta("rest_angle", 0.0))
