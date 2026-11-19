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

const RHO := 1.225
const G := 9.81
const CL_MAX := 1.5
const CL_MIN := 0.2
const FOLD_AREA := 0.4
const POWER_PER_KG := 150.0
const BURST := 2.0
const V_MIN_T := 3.0
const BANK_MAX_T := 1.0               # tan(45 deg)
const BANK_RATE := 2.6                # 1/s
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

# global tuning (the F3 panel, flight/*): the owner's "fun" knobs, never per creature
var lift_mul := 1.0
var power_mul := 1.0
var cd0_mul := 1.0

var spec: Dictionary = {}
var mode := "ground"          # ground, glide, flap, dive, flare, skid
var pos := Vector3.ZERO       # centre of mass, world
var vel := Vector3.ZERO
var bank_t := 0.0             # tan(bank angle), + = banked to the left (left wing down)
var stamina := 1.0
var yaw_dir := Vector2(0.0, 1.0)   # horizontal unit vector the body faces (x, z)
var stalled := false
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
		"vs_1g": sqrt(2.0 * mass * G / (RHO * area * CL_MAX)), "beat_hz": 4.5 / pow(maxf(mass, 0.05), 1.0 / 6.0)}


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
	stalled = false
	climb_out = CLIMB_OUT_S
	return {"ok": true, "reason": "", "burst": not run_ok}


func press_flap() -> void:
	flap_timer = maxf(flap_timer, 1.0 / maxf(float(spec.get("beat_hz", 3.0)), 0.5))


# ---- stepping -----------------------------------------------------------------------------------------------------------------
## input: {flap: bool (held), dive: bool, pitch: -1..1 (+1 = S, slower and floatier), steer: Vector2 or null (desired horizontal direction x, z)}
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
	# bank follows the steering: lean into the turn the player asks for, wings level with no input
	var f2 := _horizontal_dir()
	var t_goal := 0.0
	var steer = input.get("steer", null)
	if steer is Vector2 and (steer as Vector2).length() > 0.01:
		var sd: Vector2 = (steer as Vector2).normalized()
		var leftness := sd.x * f2.y - sd.y * f2.x      # component of the wanted direction on the creature's left (+X when facing +Z)
		var ahead := sd.x * f2.x + sd.y * f2.y
		t_goal = clampf(leftness * 2.2, -BANK_MAX_T, BANK_MAX_T) if ahead > -0.2 else (BANK_MAX_T if leftness >= 0.0 else -BANK_MAX_T)
	bank_t = move_toward(bank_t, t_goal, BANK_RATE * dt)
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
	var cl := cl_best() + clampf(-0.03 * vel.y, -0.25, 0.25)     # flight-path damping: the glide settles instead of ringing (phugoid)
	var pitch := clampf(float(input.get("pitch", 0.0)), -1.0, 1.0)
	cl = lerpf(cl, CL_MAX, pitch) if pitch >= 0.0 else lerpf(cl, CL_MIN, -pitch)
	var flaring := false
	var wants_flap: bool = bool(input.get("flap", false)) or flap_timer > 0.0
	var climbing := (wants_flap and bool(spec.flaps) and not _exhausted) or climb_out > 0.0
	climb_out = maxf(0.0, climb_out - dt)
	var flare_alt := FLARE_BODY_LENGTHS * float(spec.length)
	if want_dive:
		s_eff = s_full * FOLD_AREA
		cl = CL_MIN
		mode = "dive"
	elif climbing and pitch <= 0.0:
		cl = maxf(cl, minf(CL_CLIMB, CL_MAX))     # climb-friendly lift near the ground; the flare stays off
		mode = "glide"
	elif alt < flare_alt and vel.y < 0.0:
		flaring = true
		mode = "flare"
		var vy_goal := -(0.3 + 1.2 * clampf(alt / flare_alt, 0.0, 1.0))
		var a_cmd := (vy_goal - vel.y) / 0.4
		var l_need := m * (G + a_cmd) / maxf(cos_phi, 0.3)
		cl = clampf(l_need / maxf(q * s_full * lift_mul, 1e-6), CL_MIN, CL_MAX)
	else:
		mode = "glide"
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
	var drag := q * s_eff * (cd0() + float(spec.k) * cl * cl)
	last_lift = lift
	last_cl = cl
	var thrust := 0.0
	if flapping:
		thrust = float(spec.e) * power_available(true) / maxf(speed, V_MIN_T)
	var acc := lift_dir * (lift / m) - d * (drag / m) + d * (thrust / m) + Vector3(0.0, -G, 0.0)
	stalled = (not flaring) and speed < stall_speed() * 0.95 and not flapping
	vel += acc * dt
	pos += vel * dt
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
		mode = "skid"


func _skid(dt: float, ground: Callable, ev: Dictionary) -> void:
	var h := Vector2(vel.x, vel.z)
	var l := h.length()
	if l > 0.05:
		yaw_dir = h / l
	var nl := maxf(0.0, l - SKID_DECEL * dt)
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
		nose_up += 0.3
	elif mode == "skid":
		nose_up = 0.0
	var roll := -atan(bank_t) if mode != "skid" else 0.0
	return Basis(Vector3.UP, atan2(yaw_dir.x, yaw_dir.y)) * Basis(Vector3.RIGHT, -nose_up) * Basis(Vector3.BACK, roll)
