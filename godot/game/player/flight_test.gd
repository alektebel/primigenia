extends RefCounted
## Flight model for the Godot-side flight test mode (motion-flight plan 3c, slice F1). A point mass with lift and drag polars,
## written with + - * / and sqrt only (no trig, no pow) so it ports to the C world unchanged (F2). Pure: no nodes, no globals.
##
##   spec := FlightTest.make_spec(mass_kg, [wing_info of each wing part], body_length_m, com_height_m)
##   var f := FlightTest.new(spec)
##   f.takeoff(origin_pos, velocity, ground_fn) -> {ok, reason}
##   f.step(dt, input, ground_fn) -> {landed, impact_vy, h_eq, damage, ...}   (input: see step())
##
## Lift  L = 1/2 rho V^2 S CL lift_mul, perpendicular to the velocity and banked (bank t = tan(phi) in [-1, 1]).
## Drag  D = 1/2 rho V^2 S (CD0 + k CL^2),   k = 1/(pi e AR),   CD0 = 1/(4 (L/D)max^2 k)  so the family's best glide ratio is exact.
## Dive folds the area to 40 % with CL 0.2; flare commands the lift that brings the sink rate to a gentle value (stall = no lift = a hard landing).
## Flap thrust T = eta P / max(V, V_MIN_T) along the velocity; P = muscle * m * 150 W (x2 burst while stamina lasts).

const LocoWing := preload("res://locomotion/loco_wing.gd")

const RHO := 1.225
const G := 9.81
const CL_MAX := 1.5
const CL_MIN := 0.2
const FOLD_AREA := 0.4
const POWER_PER_KG := 150.0
const BURST := 2.0
const V_MIN_T := 3.0
const BANK_MAX_T := 1.7320508         # tan(60 deg): the sharpest turn
const ROLL_RATE_T := 1.1              # d tan(bank)/dt while a turn key is held: 45 deg in about 1 s, 60 deg in 1.7 s, a tap is a gentle bank
const ROLL_TAU := 0.2                 # s, the roll rate follows the command through this lag (roll inertia, no jerk)
const ROLLOUT_GAIN := 2.5             # 1/s, with no input the bank decays towards level at this proportional rate...
const ROLLOUT_MAX := 1.3              # ...but never faster than this d tan/dt
const HEAD_STAB := 0.92               # gaze stabilisation: the head cancels this share of the body roll
const STAMINA_DRAIN := 1.0 / 12.0     # per second of flapping (full power drains in about 12 s)
const STAMINA_REGEN := 1.0 / 6.0      # per second on the ground
const STAMINA_RESUME := 0.15
const FLARE_BODY_LENGTHS := 1.5       # auto flare starts under this many body lengths of altitude
const SAFE_DROP := 2.0                # m of equivalent drop that costs nothing (placeholder until run-fall lands its curve)
const DAMAGE_PER_M := 6.0             # hp per metre of equivalent drop above SAFE_DROP (placeholder, same reason)
const SKID_DECEL := 14.0              # m/s2 after touchdown
const CLIMB_OUT_S := 1.2              # s after a takeoff with no auto flare
const CL_CLIMB := 1.2                 # CL while climbing out or flapping near the ground
const SUBSTEP := 1.0 / 120.0
# Starter B / hatchling picks (A56, A57; lab web/gaitlab/flight.html). Lab starting values, not measured animal data.
const FG_CRUISE := 1.3                # flap-glide cruise speed, in stall speeds (B: lab vc 16 m/s against vs 11.9 = 1.34)
const FG_HIGH := 1.07                 # the speed ceiling (x1.1 here: flap bursts never push past it; the lab ended bursts at vT * 1.07)...
const FG_LOW := 0.93                  # ...and the floor (x0.95 here: the lab restarted bursts below vT * 0.93)
const FG_BAND := 0.1                  # half the energy band, in cruise-speed heads (vc^2 / 2g): bursts on below ref - band, off above ref + band
const FG_CLIMB := 2.5                 # m/s the held energy rises with full pitch-up
const FG_DAMP := 0.12                 # flight-path damping gain (CL per m/s of climb rate) while the flap-glide gates the wings
const WO_MIN_SPEED := 1.2             # stall speeds: slower than this a wingover cannot start (build speed first, a dive)
const WO_BUILD_SPEED := 1.85          # stall speeds the dive-in builds up to (lab: 1.3 x cruise)
const WO_BUILD_MAX_S := 2.2
const WO_BUILD_SIN := -0.2955         # sin of the dive-in angle (-17 degrees)
const WO_ZOOM_END_SPEED := 1.45       # stall speeds: the zoom ends here (the roll bleeds more speed over the top)...
const WO_ZOOM_END_SIN := 0.8134       # ...or at this climb angle (54 degrees, as sin)
const WO_TAN_BANK := 11.43            # tan(85 deg): rolled almost on its side over the top
const WO_ROLL_W := 2.2                # rad/s, the fastest roll into and out of the manoeuvre (d tan = w (1 + tan^2) dt: no trig)
const WO_ROLL_TAU := 0.15             # s, lag of the wingover roll rate
const WO_ROLL_K := 4.0                # 1/s, the roll slows as the angle to go shrinks
const WO_CL := 0.92                   # share of CL_MAX held while pulling and rolling
const WO_TURN_DONE := 2.6             # rad (150 deg) of heading change ends the roll: rolling out still turns the last 30 degrees
const WO_ROLL_MAX_S := 4.5
const WO_RECOVER_MAX_S := 5.0
const WO_MIN_ALT_K := 0.085           # m of altitude per (m/s)^2 of stall speed: 12 m for starter B (vs 11.9)
const CD_FLARE := 0.3                 # extra drag coefficient of the cupped wings in a flare landing (the brake of the stall touchdown)
const RUN_DECEL := 6.0                # m/s2 after a running landing (legs absorb the speed over a few metres; the lab brakes at 0.5 g)
const FLARE_STYLE_K := 1.45             # the flare + stall touchdown starts higher (2.2 body lengths, lab: 2.2 L) than the running landing
const LEG_TAU := 0.14                 # s, legs tuck and extend (lab: 0.14)

# global tuning (the F3 panel, flight/*): the owner's "fun" knobs, never per creature
var lift_mul := 1.0
var power_mul := 1.0
var cd0_mul := 1.0

var spec: Dictionary = {}
var mode := "ground"          # ground, glide, flap, dive, flare, skid
var pos := Vector3.ZERO       # centre of mass, world
var vel := Vector3.ZERO
var bank_t := 0.0             # tan(bank angle), + = banked to the left (left wing down)
var roll_rate := 0.0          # d bank_t / dt
var yaw_rate := 0.0           # rad/s of the heading, + = turning left; it comes only from the horizontal part of the tilted lift
var overbank := false         # the pull-up that holds altitude in this bank needs more than CL_MAX: the bird sinks
var stamina := 1.0
var yaw_dir := Vector2(0.0, 1.0)   # horizontal unit vector the body faces (x, z)
var stalled := false
var cruise_style := "continuous"   # "flapglide" (A56: flap bursts until fast, glide until slow; flight_mode sets it) or "continuous" (hold = flap)
var landing_style := "flare"      # "flare" (flare + stall touchdown, A56) or "run" (running landing, A57)
var _fg_gated := false
var fg_e_ref := 0.0           # energy height (m) the flap-glide holds
var _wo_w := 0.0              # wingover roll rate (rad/s)
var fg_on := true             # the flap-glide burst state (hysteresis)
var wo_phase := ""            # wingover: "" (off), "build", "zoom", "roll", "recover"
var wo_dir := 1               # +1 = to the right (D), -1 = to the left
var wo_t := 0.0
var wo_turned := 0.0          # rad of heading change since the roll began
var wingovers := 0
var legs_tuck := 1.0          # 1 tucked under the belly (cruise), 0 extended (flare, landing)
var legs_fwd := 0.0           # 0..1 swung forward (flare)
var run_out := false          # the skid is a running landing's run-out
var climb_out := 0.0          # s left of the post-takeoff climb-out (no auto flare, climb-friendly CL)
var flap_timer := 0.0         # s of flapping owed to a tap (one beat)
var last_lift := 0.0
var last_cl := 0.0
var _exhausted := false


## spec: {mass, area (m2, all wings), span (m, tip to tip), ar, e, ld, k, cd0, muscle, power (W sustained), length, com_h, vs_1g (stall speed at lift_mul 1),
##        beat_hz, flaps}
static func make_spec(mass: float, infos: Array, body_length: float, com_h: float) -> Dictionary:
	var area := 0.0
	var span := 0.0
	var ew := 0.0
	var ldw := 0.0
	var mus := 0.0
	var flapw := 0.0
	for i in infos:
		var a: float = float(i.area)
		area += a
		span = maxf(span, 2.0 * float(i.span))
		ew += a * float(i.e)
		ldw += a * float(i.ld)
		mus += float(i.muscle) * a
		flapw += a * (1.0 if bool(i.get("flaps", true)) else 0.0)
	if area <= 0.0:
		return {}
	var e := ew / area
	var ld := ldw / area
	var muscle := mus / area
	var ar := span * span / area
	var k := 1.0 / (3.14159265 * e * ar)
	var cd0 := 1.0 / (4.0 * ld * ld * k)
	var flaps := flapw / area > 0.5
	return {"mass": mass, "area": area, "span": span, "ar": ar, "e": e, "ld": ld, "k": k, "cd0": cd0, "muscle": muscle,
		"power": muscle * mass * POWER_PER_KG, "length": body_length, "com_h": com_h, "flaps": flaps,
		"vs_1g": sqrt(2.0 * mass * G / (RHO * area * CL_MAX)), "beat_hz": LocoWing.beat_hz(mass)}


func _init(s: Dictionary = {}) -> void:
	spec = s


func valid() -> bool:
	return not spec.is_empty()


# ---- derived numbers (the creator shows these; the tests check them) ----------------------------------------------------------
func wing_loading() -> float:
	return float(spec.mass) * G / float(spec.area)

func stall_speed() -> float:
	return float(spec.vs_1g) / sqrt(maxf(lift_mul, 1e-3))

func cd0() -> float:
	return float(spec.cd0) * cd0_mul

## CL of best glide (minimum drag-to-lift): sqrt(CD0 / k).
func cl_best() -> float:
	return clampf(sqrt(cd0() / float(spec.k)), CL_MIN, CL_MAX)

## Best glide ratio with the current tuning (lift_mul does not touch the induced drag, the fun knob is a pure lift gain).
func glide_ratio() -> float:
	var cl := cl_best()
	return cl * lift_mul / (cd0() + float(spec.k) * cl * cl)

## Power (W) the wing needs for level flight at V (CL from the weight, capped at CL_MAX).
func power_required(v: float) -> float:
	var q := 0.5 * RHO * v * v
	var cl := float(spec.mass) * G / maxf(q * float(spec.area) * lift_mul, 1e-6)
	if cl > CL_MAX:
		return INF
	return q * float(spec.area) * (cd0() + float(spec.k) * cl * cl) * v

func min_power_required() -> float:
	var best := INF
	var v := stall_speed() * 1.0
	for i in 60:
		best = minf(best, power_required(v))
		v += 0.5
	return best

func power_available(burst := false) -> float:
	return float(spec.power) * power_mul * (BURST if burst else 1.0)

## "ground" (cannot leave it), "glide" (only unpowered), "flap" (sustained powered flight).
func capability() -> String:
	if not valid():
		return "ground"
	if not bool(spec.flaps):
		return "glide"
	return "flap" if power_available() > min_power_required() else "glide"

func report() -> Dictionary:
	return {"wing_loading": wing_loading(), "stall": stall_speed(), "ld": glide_ratio(), "power": power_available(), "p_req": min_power_required(),
		"capability": capability(), "beat_hz": float(spec.beat_hz), "area": float(spec.area), "ar": float(spec.ar), "span": float(spec.span)}


func airborne() -> bool:
	return mode in ["glide", "flap", "dive", "flare"]

func active() -> bool:
	return mode != "ground"


# ---- takeoff ------------------------------------------------------------------------------------------------------------------
## origin: the creature's feet-level position; ground_vel: its horizontal velocity. Returns {ok, reason, burst}.
func takeoff(origin: Vector3, ground_vel: Vector3, heading: Vector2) -> Dictionary:
	if not valid():
		return {"ok": false, "reason": "no wings", "burst": false}
	var vs := stall_speed()
	var speed := Vector2(ground_vel.x, ground_vel.z).length()
	var run_ok := speed >= 1.1 * vs
	var p_req := power_required(vs * 1.15)
	var burst_ok := power_available(true) > 1.5 * p_req and bool(spec.flaps)
	if not run_ok and not burst_ok:
		return {"ok": false, "burst": false, "reason": "cannot take off: wing loading %.0f N/m2, stall %.1f m/s (run %.1f), burst power %.0f W vs %.0f W needed" %
			[wing_loading(), vs, speed, power_available(true), 1.5 * p_req if p_req < INF else -1.0]}
	var h := heading.normalized() if heading.length() > 0.01 else Vector2(0.0, 1.0)
	yaw_dir = h
	var v_fwd := maxf(speed, 1.15 * vs)
	pos = origin + Vector3(0.0, float(spec.com_h) + 0.05, 0.0)
	vel = Vector3(h.x * v_fwd, 1.5 if run_ok else 3.0, h.y * v_fwd)
	mode = "glide"
	bank_t = 0.0
	roll_rate = 0.0
	stalled = false
	climb_out = CLIMB_OUT_S
	return {"ok": true, "reason": "", "burst": not run_ok}


## Wingbeat rate now (Hz): the scaling option (LocoWing.scaling) is read live.
func beat_hz() -> float:
	return LocoWing.beat_hz(float(spec.get("mass", 30.0)))

func press_flap() -> void:
	flap_timer = maxf(flap_timer, 1.0 / maxf(beat_hz(), 0.5))


## Cruise speed of the flap-glide pattern.
func cruise_speed() -> float:
	return FG_CRUISE * stall_speed()

## Altitude a wingover needs: the dive-in, the zoom and the pull-out (m).
func wingover_min_alt() -> float:
	var vs := stall_speed()
	return WO_MIN_ALT_K * vs * vs + 2.0 * float(spec.length)

## Starts the wingover (A56, A57): dive in for speed, zoom climb, roll over the top, dive away on the reverse heading.
## dir: +1 = over the right wing (D), -1 = left (A). Returns {ok, reason}.
func start_wingover(dir: int, ground: Callable) -> Dictionary:
	if not valid() or not airborne() or mode == "dive":
		return {"ok": false, "reason": "not flying"}
	if wo_phase != "":
		return {"ok": false, "reason": "already in a wingover"}
	var vs := stall_speed()
	var alt := altitude(ground)
	if vel.length() < WO_MIN_SPEED * vs:
		return {"ok": false, "reason": "too slow for a wingover (%.1f m/s, needs %.1f)" % [vel.length(), WO_MIN_SPEED * vs]}
	if alt < wingover_min_alt():
		return {"ok": false, "reason": "too low for a wingover (%.0f m, needs %.0f)" % [alt, wingover_min_alt()]}
	wo_phase = "build"
	wo_dir = 1 if dir >= 0 else -1
	wo_t = 0.0
	wo_turned = 0.0
	wingovers += 1
	return {"ok": true, "reason": ""}

func abort_wingover() -> void:
	wo_phase = ""


# ---- stepping -----------------------------------------------------------------------------------------------------------------
## input: {flap: bool (held), dive: bool, pitch: -1..1 (+1 = S, slower and floatier), roll: -1..1 (+1 = roll left, -1 = right; it commands a
## roll RATE, the bank builds while it is held and rolls out to level when it is released)}
## ground: Callable(x, z) -> float. Returns the events of the step: {landed, impact_vy, h_eq, damage, speed}.
func step(dt: float, input: Dictionary, ground: Callable) -> Dictionary:
	var ev := {"landed": false, "impact_vy": 0.0, "h_eq": 0.0, "damage": 0.0, "ended": false, "speed": 0.0}
	var left := dt
	while left > 1e-6 and mode != "ground":
		var h := minf(left, SUBSTEP)
		left -= h
		if mode == "skid":
			_skid(h, ground, ev)
		else:
			_fly(h, input, ground, ev)
	if mode == "ground":
		stamina = minf(1.0, stamina + STAMINA_REGEN * dt)
		if stamina > STAMINA_RESUME:
			_exhausted = false
	return ev


func _horizontal_dir() -> Vector2:
	var h := Vector2(vel.x, vel.z)
	var l := h.length()
	if l > 1.0:
		yaw_dir = h / l
	return yaw_dir


func altitude(ground: Callable) -> float:
	return pos.y - float(spec.com_h) - float(ground.call(pos.x, pos.z))


func _fly(dt: float, input: Dictionary, ground: Callable, ev: Dictionary) -> void:
	var m := float(spec.mass)
	var s_full := float(spec.area)
	var v2 := vel.length_squared()
	var speed := sqrt(v2)
	var d := vel / speed if speed > 0.5 else Vector3(yaw_dir.x, 0.0, yaw_dir.y)
	var q := 0.5 * RHO * v2
	var alt := altitude(ground)
	var want_dive: bool = bool(input.get("dive", false))
	# roll leads, yaw follows: the keys command a roll rate; the heading changes only through the horizontal part of the banked lift
	_horizontal_dir()
	var roll_cmd := clampf(float(input.get("roll", 0.0)), -1.0, 1.0)
	var wo := _wingover_control(dt, speed, alt, roll_cmd, want_dive, FLARE_BODY_LENGTHS * float(spec.length))
	var rate_goal := roll_cmd * ROLL_RATE_T if absf(roll_cmd) > 0.01 else clampf(-bank_t * ROLLOUT_GAIN, -ROLLOUT_MAX, ROLLOUT_MAX)
	if wo.on:
		# the manoeuvre rolls at a constant ANGULAR rate (d tan(phi) = w (1 + tan^2) dt), through the same roll lag as the keys
		var tgt: float = wo.tan
		var den := 1.0 + tgt * bank_t                 # tan(a - b) = (ta - tb) / (1 + ta tb): the angle still to roll, no trig
		var err := (tgt - bank_t) / den if den > 0.25 else (1.5 if tgt > bank_t else -1.5)
		_wo_w += (clampf(WO_ROLL_K * err, -WO_ROLL_W, WO_ROLL_W) - _wo_w) * minf(1.0, dt / WO_ROLL_TAU)     # the lag acts on the ANGULAR rate: no overshoot
		rate_goal = _wo_w * (1.0 + bank_t * bank_t)
		roll_rate = rate_goal
	else:
		_wo_w = 0.0
		roll_rate += (rate_goal - roll_rate) * minf(1.0, dt / ROLL_TAU)
	bank_t += roll_rate * dt
	if wo_phase != "":
		bank_t = clampf(bank_t, -WO_TAN_BANK * 1.3, WO_TAN_BANK * 1.3)
	if absf(bank_t) > BANK_MAX_T and wo_phase == "":
		bank_t = BANK_MAX_T if bank_t > 0.0 else -BANK_MAX_T
		roll_rate = 0.0
	if wo_phase == "" and absf(roll_cmd) <= 0.01 and absf(bank_t) < 0.004 and absf(roll_rate) < 0.02:
		bank_t = 0.0
		roll_rate = 0.0
	var h0 := Vector2(vel.x, vel.z)
	var cos_phi := 1.0 / sqrt(1.0 + bank_t * bank_t)
	var sin_phi := bank_t * cos_phi
	# the lift direction: perpendicular to the velocity, in the plane of the bank
	var up := Vector3.UP
	var lv := up - d * d.dot(up)
	var ll := lv.length()
	lv = lv / ll if ll > 1e-4 else Vector3(-yaw_dir.x, 0.0, -yaw_dir.y)
	var lf := up.cross(d)
	var lfl := lf.length()
	lf = lf / lfl if lfl > 1e-4 else Vector3(yaw_dir.y, 0.0, -yaw_dir.x)
	var lift_dir := lv * cos_phi + lf * sin_phi
	# what the wings do: dive folds, flare commands the lift for a soft touchdown, otherwise the pilot's pitch moves CL
	var s_eff := s_full
	# flight-path damping: the glide settles instead of ringing (phugoid). In the flap-glide cruise it is stiffer: the burst thrust
	# becomes speed (which ends the burst), not a climb, so the body holds its height hands-off between bursts.
	var cl := cl_best() + (clampf(-FG_DAMP * vel.y, -0.5, 0.5) if _fg_gated else clampf(-0.03 * vel.y, -0.25, 0.25))
	var pitch := clampf(float(input.get("pitch", 0.0)), -1.0, 1.0)
	cl = lerpf(cl, CL_MAX, pitch) if pitch >= 0.0 else lerpf(cl, CL_MIN, -pitch)
	var flaring := false
	var flap_in: bool = bool(input.get("flap", false))
	var flare_alt := FLARE_BODY_LENGTHS * float(spec.length)
	# A56 cruise = flap-glide: while the flap key is held the wings burst until the body is fast and rest until it is slow. A tap
	# (one beat), the climb-out after takeoff and the last body lengths above the ground are never gated.
	var fg_gated := false
	if flap_in and cruise_style == "flapglide" and flap_timer <= 0.0 and climb_out <= 0.0 and alt >= flare_alt and not wo.on:
		fg_gated = true
		var vc := cruise_speed()
		# Bursts hold the total energy (height + speed^2 / 2g) around the level the pattern started at, so the body flaps until
		# it is fast (and has regained its height) and glides until it has bled that energy again, slow or lower. A speed floor
		# and ceiling keep it near the cruise speed; the pilot's pitch moves the reference (S = more energy: a climb).
		var e_now := pos.y + v2 / (2.0 * G)
		if not _fg_gated:
			fg_e_ref = e_now
			fg_on = speed < vc
		fg_e_ref += FG_CLIMB * clampf(float(input.get("pitch", 0.0)), -1.0, 1.0) * dt
		var band := FG_BAND * vc * vc / (2.0 * G)
		if speed > vc * FG_HIGH * 1.1 or e_now > fg_e_ref + band:
			fg_on = false
		elif speed < vc * FG_LOW * 0.95 or e_now < fg_e_ref - band:
			fg_on = true
		flap_in = fg_on
	else:
		fg_on = true
	_fg_gated = fg_gated
	var wants_flap: bool = flap_in or flap_timer > 0.0
	if wo.on:
		wants_flap = bool(wo.flap)
	var climbing: bool = ((wants_flap and bool(spec.flaps) and not _exhausted and not fg_gated) or climb_out > 0.0) and not wo.on     # a gated burst adds speed, not a climb
	climb_out = maxf(0.0, climb_out - dt)
	if wo.on and not want_dive and not (wo_phase == "recover" and alt < flare_alt and vel.y < 0.0):
		cl = float(wo.cl)
		mode = "glide"
	elif want_dive:
		s_eff = s_full * FOLD_AREA
		cl = CL_MIN
		mode = "dive"
	elif climbing and pitch <= 0.0:
		cl = maxf(cl, minf(CL_CLIMB, CL_MAX))     # climb-friendly lift near the ground; the flare stays off
		mode = "glide"
	elif alt < flare_alt * (FLARE_STYLE_K if landing_style == "flare" else 1.0) and vel.y < 0.0:
		flaring = true
		mode = "flare"
		var vy_goal := -(0.3 + 1.2 * clampf(alt / (flare_alt * (FLARE_STYLE_K if landing_style == "flare" else 1.0)), 0.0, 1.0))
		var a_cmd := (vy_goal - vel.y) / 0.4
		var l_need := m * (G + a_cmd) / maxf(cos_phi, 0.3)
		cl = clampf(l_need / maxf(q * s_full * lift_mul, 1e-6), CL_MIN, CL_MAX)
	else:
		mode = "glide"
	# in a bank the bird pulls up (CL x 1/cos) to hold its altitude; past CL_MAX it cannot, and it sinks
	overbank = false
	if not want_dive and not flaring and not wo.on:
		var cl_turn := cl / cos_phi
		overbank = cl_turn > CL_MAX + 1e-4 and absf(bank_t) > 0.05
		cl = minf(cl_turn, CL_MAX)
	# flapping
	var flapping := false
	flap_timer = maxf(0.0, flap_timer - dt)
	if wants_flap and bool(spec.flaps) and not want_dive and not _exhausted:
		flapping = true
		if not flaring:
			mode = "flap"
		stamina = maxf(0.0, stamina - STAMINA_DRAIN * dt)
		if stamina <= 0.0:
			_exhausted = true
			flapping = false
	elif stamina < 1.0 and not wants_flap:
		stamina = minf(1.0, stamina + 0.02 * dt)     # a trickle while gliding
	if _exhausted and stamina > STAMINA_RESUME:
		_exhausted = false
	# forces
	var lift := q * s_eff * cl * lift_mul
	var cd_extra := CD_FLARE if (flaring and landing_style == "flare") else 0.0     # cupped wings brake the flare
	var drag := q * s_eff * (cd0() + cd_extra + float(spec.k) * cl * cl)
	last_lift = lift
	last_cl = cl
	var thrust := 0.0
	if flapping:
		thrust = float(spec.e) * power_available(true) / maxf(speed, V_MIN_T)
	var acc := lift_dir * (lift / m) - d * (drag / m) + d * (thrust / m) + Vector3(0.0, -G, 0.0)
	stalled = (not flaring) and speed < stall_speed() * 0.95 and not flapping
	vel += acc * dt
	pos += vel * dt
	var h1 := Vector2(vel.x, vel.z)
	var hl0 := h0.length()
	var hl1 := h1.length()
	yaw_rate = -h0.cross(h1) / (hl0 * hl1 * dt) if hl0 > 0.5 and hl1 > 0.5 else 0.0
	if wo_phase == "roll":
		wo_turned += absf(yaw_rate) * dt
	# legs: tucked in cruise, extended and (flare) forward for the touchdown
	var tuck_goal := 0.0 if flaring else 1.0
	var fwd_goal := 0.0
	if flaring:
		fwd_goal = 1.0 if landing_style == "flare" else 0.4
	var kl := minf(1.0, dt / LEG_TAU)
	legs_tuck += (tuck_goal - legs_tuck) * kl
	legs_fwd += (fwd_goal - legs_fwd) * kl
	ev.speed = speed
	# touchdown
	var gy: float = ground.call(pos.x, pos.z)
	if pos.y - float(spec.com_h) <= gy and vel.y > 0.0:
		pos.y = gy + float(spec.com_h)       # still climbing: skim the rising ground instead of landing on it
		vel.y = minf(vel.y, 0.5 * speed)
	elif pos.y - float(spec.com_h) <= gy:
		var vy := vel.y
		ev.landed = true
		ev.impact_vy = vy
		var h_eq := (vy * vy) / (2.0 * G) if vy < 0.0 else 0.0
		ev.h_eq = h_eq
		ev.damage = maxf(0.0, h_eq - SAFE_DROP) * DAMAGE_PER_M
		pos.y = gy + float(spec.com_h)
		vel.y = 0.0
		bank_t = 0.0
		roll_rate = 0.0
		wo_phase = ""
		run_out = landing_style == "run"
		mode = "skid"


## The wingover state machine (A56, A57): returns {on, tan (target tan of the bank), cl, flap}. Called once per substep.
func _wingover_control(dt: float, speed: float, alt: float, roll_cmd: float, want_dive: bool, flare_alt: float) -> Dictionary:
	var out := {"on": false, "tan": 0.0, "cl": cl_best(), "flap": false}
	if wo_phase == "":
		return out
	var vs := stall_speed()
	var gam_s := vel.y / maxf(speed, 0.5)
	wo_t += dt
	# the player can always cut it short: Ctrl dives out, the opposite turn key rolls out
	if wo_phase != "recover":
		if want_dive or (absf(roll_cmd) > 0.5 and (roll_cmd > 0.0) == (wo_dir > 0)):
			wo_phase = "recover"
			wo_t = 0.0
		elif alt < flare_alt * 1.5 and vel.y < 0.0:
			wo_phase = "recover"
			wo_t = 0.0
	if wo_phase == "build":
		if speed >= WO_BUILD_SPEED * vs or wo_t > WO_BUILD_MAX_S:
			wo_phase = "zoom"
			wo_t = 0.0
	if wo_phase == "zoom":
		if speed <= WO_ZOOM_END_SPEED * vs or gam_s >= WO_ZOOM_END_SIN or wo_t > 4.0:
			wo_phase = "roll"
			wo_t = 0.0
			wo_turned = 0.0
	if wo_phase == "roll" and (wo_turned >= WO_TURN_DONE or wo_t > WO_ROLL_MAX_S):
		wo_phase = "recover"
		wo_t = 0.0
	if wo_phase == "recover":
		var levelled: bool = absf(bank_t) < 0.25 and (gam_s > -0.1 or want_dive)
		if levelled or wo_t > WO_RECOVER_MAX_S:
			wo_phase = ""
			fg_on = true
			return out
	out.on = true
	var q := 0.5 * RHO * speed * speed
	var s_q := maxf(q * float(spec.area) * lift_mul, 1e-6)
	match wo_phase:
		"build":
			# dive in at a steady -17 degrees (a proportional path controller on the weight component), flapping for speed
			var hold := float(spec.mass) * G * sqrt(maxf(1.0 - gam_s * gam_s, 0.0)) / s_q
			out.cl = clampf(hold + 4.0 * (WO_BUILD_SIN - gam_s), CL_MIN, CL_MAX)
			out.flap = true
		"zoom":
			out.cl = WO_CL * CL_MAX
		"roll":
			out.tan = -float(wo_dir) * WO_TAN_BANK
			out.cl = WO_CL * CL_MAX
		"recover":
			out.flap = speed < FG_CRUISE * vs and not want_dive
			if vel.y < 0.0 and absf(bank_t) < 0.5 and (speed >= FG_CRUISE * vs or alt < 2.0 * speed * absf(gam_s) + flare_alt):
				out.cl = WO_CL * CL_MAX              # back at cruise speed (or close to the ground): pull out of the dive
	return out


func _skid(dt: float, ground: Callable, ev: Dictionary) -> void:
	var h := Vector2(vel.x, vel.z)
	var l := h.length()
	if l > 0.05:
		yaw_dir = h / l
	var nl := maxf(0.0, l - (RUN_DECEL if run_out else SKID_DECEL) * dt)
	var hv := yaw_dir * nl
	vel = Vector3(hv.x, 0.0, hv.y)
	pos += vel * dt
	pos.y = float(ground.call(pos.x, pos.z)) + float(spec.com_h)
	if nl < 0.4:
		mode = "ground"
		ev.ended = true


## The flyer's attitude: yaw from the heading, pitch along the flight path (nose up in a flare), roll into the bank.
## Forward is +Z, the creature's left is +X; a positive rotation about +X is nose down, about +Z left wing up.
func orientation() -> Basis:
	var hl := Vector2(vel.x, vel.z).length()
	var gamma := atan2(vel.y, maxf(hl, 0.1))
	var nose_up := clampf(gamma * 0.85, -0.9, 0.7)
	if mode == "flare":
		nose_up += 0.3 if landing_style == "flare" else 0.08     # the running landing comes in flat
	elif mode == "skid":
		nose_up = 0.0
	var roll := -atan(bank_t) if mode != "skid" else 0.0
	return Basis(Vector3.UP, atan2(yaw_dir.x, yaw_dir.y)) * Basis(Vector3.RIGHT, -nose_up) * Basis(Vector3.BACK, roll)


## Roll (rad, + = left wing up) the head keeps against the horizon after the gaze stabilisation: a few degrees even in a 60 degree bank.
func head_roll() -> float:
	var roll := -atan(bank_t) if mode != "skid" else 0.0
	return roll * (1.0 - HEAD_STAB)
