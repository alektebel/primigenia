extends RefCounted
## Morphology analysis (G73): turns a body description into the numbers that
## drive locomotion: mass, centre of mass, moments of inertia, the leg set,
## the body-plan class and a speed/acceleration proposal.
##
## Body description (the "rest space" the creature rig must provide):
##   +Z forward, +Y up, +X left, ground at y = 0, metres.
##   {
##     "spine": [ {pos: Vector3, radius: float, region: "tail"|"trunk"|"neck"|"head"} ... ]
##              ordered tail tip -> head,
##     "legs":  [ {hip: Vector3, upper: float, lower: float, radius: float,
##                 foot: String, foot_size: float, (foot_rest: Vector3)} ... ],
##     "parts": [ {pos: Vector3, mass: float, (category: String)} ... ],
##     "density": float (kg/m3, default 1000)
##   }

const G := 9.81

# Foot types: ankle height as a fraction of foot_size, grip (friction-like
# coefficient used for the acceleration proposal), swing clearance factor and
# a top-speed factor. Names cover the web catalogue's feet (garra, dedos,
# pezuna, runner, sucker, spring, cloven, gecko) plus generic ones.
const FOOT := {
	"paw": {"ankle": 0.5, "grip": 0.9, "lift": 1.0, "speed": 1.0},
	"garra": {"ankle": 0.5, "grip": 1.0, "lift": 1.0, "speed": 1.0},
	"dedos": {"ankle": 0.35, "grip": 0.85, "lift": 1.25, "speed": 0.95},
	"toes": {"ankle": 0.35, "grip": 0.85, "lift": 1.25, "speed": 0.95},
	"pezuna": {"ankle": 0.6, "grip": 0.75, "lift": 0.9, "speed": 1.1},
	"hoof": {"ankle": 0.6, "grip": 0.75, "lift": 0.9, "speed": 1.1},
	"cloven": {"ankle": 0.6, "grip": 0.85, "lift": 0.9, "speed": 1.05},
	"runner": {"ankle": 0.45, "grip": 0.9, "lift": 1.0, "speed": 1.15},
	"pad": {"ankle": 0.5, "grip": 0.8, "lift": 0.7, "speed": 0.85},
	"sucker": {"ankle": 0.4, "grip": 1.3, "lift": 0.8, "speed": 0.7},
	"gecko": {"ankle": 0.4, "grip": 1.4, "lift": 0.8, "speed": 0.85},
	"spring": {"ankle": 0.5, "grip": 0.9, "lift": 1.3, "speed": 1.05},
	"point": {"ankle": 0.3, "grip": 0.7, "lift": 1.1, "speed": 0.9},
}

var mass := 0.0
var com := Vector3.ZERO
## Moments of inertia about the body axes through the centre of mass:
## x = pitch axis, y = yaw axis, z = roll axis (kg m2).
var inertia := Vector3.ONE
var legs: Array = []          # analysed legs, see _analyse_legs
var stations: Array = []      # fore-aft hip stations, rear first: {z, legs:[idx], share}
var plan := &"legless"        # upright_biped | horizontal_biped | quadruped | multi | legless | monopod
var graviportal := false
var hip_height := 0.3         # characteristic leg length for Froude (m)
var body_length := 1.0
var body_radius := 0.2
var track_width := 0.2
var trunk_incline := 0.0      # rad from horizontal
var robustness := 1.0         # mass / mass expected for this leg length
var neck := {"length": 0.0, "mass": 0.0, "base": Vector3.ZERO}
var tail := {"length": 0.0, "mass": 0.0, "base": Vector3.ZERO}
var spine_u: PackedFloat32Array = []  # arc-length coordinate 0..1 of each spine node
var spine_regions: Array = []
var proposal := {}

static func foot_info(kind: String) -> Dictionary:
	return FOOT.get(kind, FOOT["paw"])

static func analyse(desc: Dictionary):
	var m = new()
	if desc.has("radial"):
		m._run_radial(desc)
	else:
		m._run(desc)
	return m

## Radial plan (A24): disc plus arms. No legs, no ladder; `hip_height` is the disc thickness, `base_gait` the arm mode.
var base_gait := &""
func _run_radial(desc: Dictionary) -> void:
	var r: Dictionary = desc["radial"]
	plan = &"radial"
	mass = float(r.get("mass", 1.0))
	var rt := float(r["root_r"]) + float(r["reach"])
	hip_height = maxf(float(r.get("disc_h", .1)), .02)
	body_radius = float(r["disc_r"])
	body_length = 2.0 * rt
	track_width = 2.0 * rt
	com = Vector3(0, hip_height * .5, 0)
	var arms := float(r["fold"])
	var m_arm := mass * .5 / maxf(arms, 1.0)
	var i_y := mass * .5 * .5 * body_radius * body_radius      # disc about its axis
	i_y += arms * m_arm * (rt * rt / 3.0 + 0.0)                 # arms as rods from the axis
	inertia = Vector3(i_y * .5, i_y, i_y * .5)
	legs = []
	stations = []
	robustness = 1.0
	var a := String(r.get("act", "tubefeet"))
	base_gait = &"jet" if bool(r.get("bell", false)) else (&"cilia" if a == "cilia" else &"glide")
	proposal = {"plan": plan, "gait": base_gait}

func _add(acc: Array, mm: float, p: Vector3, own: Vector3 = Vector3.ZERO) -> void:
	acc.append([mm, p, own])

func _segment(acc: Array, p0: Vector3, p1: Vector3, r0: float, r1: float, density: float) -> float:
	var d := p1 - p0
	var l := d.length()
	if l < 1e-6:
		return 0.0
	var vol := PI * l / 3.0 * (r0 * r0 + r0 * r1 + r1 * r1)
	var mm := vol * density
	# centroid of a frustum along its axis
	var t := (r0 * r0 + 2.0 * r0 * r1 + 3.0 * r1 * r1) / (4.0 * (r0 * r0 + r0 * r1 + r1 * r1))
	var r := 0.5 * (r0 + r1)
	var i_par := 0.5 * mm * r * r
	var i_perp := mm * (3.0 * r * r + l * l) / 12.0
	var u := d / l
	var own := Vector3(
		i_par * u.x * u.x + i_perp * (1.0 - u.x * u.x),
		i_par * u.y * u.y + i_perp * (1.0 - u.y * u.y),
		i_par * u.z * u.z + i_perp * (1.0 - u.z * u.z))
	_add(acc, mm, p0 + d * t, own)
	return mm

func _run(desc: Dictionary) -> void:
	var density: float = desc.get("density", 1000.0)
	var spine: Array = desc.get("spine", [])
	var acc: Array = []
	# --- spine: truncated cones between nodes, plus end caps (half spheres)
	var trunk_acc: Array = []
	var total_len := 0.0
	var lens: Array = [0.0]
	var rmax := 0.01
	for i in range(spine.size() - 1):
		var a: Dictionary = spine[i]
		var b: Dictionary = spine[i + 1]
		var mm := _segment(acc, a.pos, b.pos, a.radius, b.radius, density)
		var seg_len: float = (b.pos - a.pos).length()
		total_len += seg_len
		lens.append(total_len)
		rmax = max(rmax, max(a.radius, b.radius))
		var reg: String = str(b.get("region", "trunk"))
		var rega: String = str(a.get("region", "trunk"))
		if reg == "trunk" and rega == "trunk":
			trunk_acc.append([mm, a.pos, b.pos])
		if rega == "tail":
			tail.mass += mm
			tail.length += seg_len
			tail.base = b.pos
		if reg == "neck" or reg == "head":
			neck.mass += mm
			neck.length += seg_len
			if neck.length == seg_len:
				neck.base = a.pos
	if spine.size() > 0:
		for e in [spine[0], spine[spine.size() - 1]]:
			var rr: float = e.radius
			_add(acc, density * 2.0 / 3.0 * PI * rr * rr * rr, e.pos, Vector3.ONE * 0.26 * density * 2.0 / 3.0 * PI * pow(rr, 5))
	body_length = max(total_len, 0.05)
	body_radius = rmax
	spine_u = PackedFloat32Array()
	spine_regions = []
	for i in range(spine.size()):
		spine_u.append(lens[i] / body_length if spine.size() > 1 else 0.0)
		spine_regions.append(str(spine[i].get("region", "trunk")))
	# --- trunk inclination from the mass-weighted trunk axis
	var axis := Vector3.ZERO
	for t in trunk_acc:
		axis += (t[2] - t[1]) * t[0]
	if axis.length() < 1e-9 and spine.size() > 1:
		axis = spine[spine.size() - 1].pos - spine[0].pos
	trunk_incline = atan2(abs(axis.y), Vector2(axis.x, axis.z).length()) if axis.length() > 1e-9 else 0.0
	# --- legs: upper and lower cylinders in the rest pose (straight hip -> ankle)
	var raw_legs: Array = desc.get("legs", [])
	for l in raw_legs:
		var fi := foot_info(str(l.get("foot", "paw")))
		var fs: float = l.get("foot_size", l.get("radius", 0.05) * 1.5)
		var ankle: float = fi.ankle * fs
		var hip: Vector3 = l.hip
		var rest: Vector3 = l.get("foot_rest", Vector3(hip.x, 0.0, hip.z))
		rest.y = ankle
		var knee := hip.lerp(rest, l.upper / max(l.upper + l.lower, 1e-6))
		var r: float = l.get("radius", 0.05)
		_segment(acc, hip, knee, r, r * 0.8, density)
		_segment(acc, knee, rest, r * 0.8, r * 0.55, density)
		_add(acc, density * 4.0 / 3.0 * PI * pow(fs * 0.5, 3) * 0.6, rest)
	# --- parts: point masses
	for p in desc.get("parts", []):
		_add(acc, float(p.get("mass", 0.0)), p.pos)
	# --- totals
	mass = 0.0
	var first := Vector3.ZERO
	for a in acc:
		mass += a[0]
		first += a[1] * a[0]
	mass = max(mass, 1e-4)
	com = first / mass
	inertia = Vector3.ZERO
	for a in acc:
		var d: Vector3 = a[1] - com
		inertia += a[2] + Vector3(d.y * d.y + d.z * d.z, d.x * d.x + d.z * d.z, d.x * d.x + d.y * d.y) * a[0]
	inertia = inertia.max(Vector3.ONE * 1e-6)
	_analyse_legs(raw_legs)
	_classify()
	_propose()

func _analyse_legs(raw: Array) -> void:
	legs = []
	stations = []
	if raw.is_empty():
		hip_height = body_radius
		track_width = body_radius * 2.0
		return
	var hsum := 0.0
	var xmax := 0.0
	for i in range(raw.size()):
		var l: Dictionary = raw[i]
		var kind := str(l.get("foot", "paw"))
		var fi := foot_info(kind)
		var fs: float = l.get("foot_size", l.get("radius", 0.05) * 1.5)
		var hip: Vector3 = l.hip
		var ankle: float = fi.ankle * fs
		var total: float = l.upper + l.lower
		var rest: Vector3 = l.get("foot_rest", Vector3(hip.x, 0.0, hip.z))
		rest.y = ankle
		var side := 0
		if hip.x > 1e-4:
			side = 1
		elif hip.x < -1e-4:
			side = -1
		legs.append({
			"index": i, "hip": hip, "upper": float(l.upper), "lower": float(l.lower),
			"length": total, "rest_len": (rest - hip).length(), "rest_h": hip.y - ankle,
			"side": side, "station": 0, "foot": kind, "foot_radius": fs * 0.5, "toe": 0.8 * fs * 0.5,
			"ankle": ankle, "home": rest, "share": 0.0, "lift": float(fi.lift),
			"grip": float(fi.grip), "radius": float(l.get("radius", 0.05)),
		})
		hsum += hip.y - ankle
		xmax = max(xmax, abs(rest.x))
	hip_height = max(hsum / raw.size(), 0.02)
	track_width = max(2.0 * xmax, 0.02)
	# stations: cluster hips by fore-aft position
	var order := range(legs.size())
	order.sort_custom(func(a, b): return legs[a].hip.z < legs[b].hip.z)
	var tol := 0.12 * hip_height + 1e-4
	for idx in order:
		var z: float = legs[idx].hip.z
		if stations.is_empty() or abs(z - stations[-1].z) > tol:
			stations.append({"z": z, "legs": [idx], "share": 0.0})
		else:
			var st: Dictionary = stations[-1]
			st.legs.append(idx)
			st.z = (st.z * (st.legs.size() - 1) + z) / st.legs.size()
		legs[idx].station = stations.size() - 1
	# static load share per station: minimal-norm distribution balancing the COM
	var n := stations.size()
	if n == 1:
		stations[0].share = 1.0
	else:
		var zbar := 0.0
		for s in stations:
			zbar += s.z / n
		var var_z := 0.0
		for s in stations:
			var_z += (s.z - zbar) * (s.z - zbar)
		var alpha: float = (com.z - zbar) / max(var_z, 1e-9)
		var tot := 0.0
		for s in stations:
			s.share = clamp(1.0 / n + alpha * (s.z - zbar), 0.08 / n, 1.0)
			tot += s.share
		for s in stations:
			s.share /= tot
	for s in stations:
		for idx in s.legs:
			legs[idx].share = s.share / s.legs.size()

func _classify() -> void:
	var n := legs.size()
	# expected mass for this leg length, from mammal allometry (leg ~ 0.15 M^0.35 m)
	var m_exp := pow(hip_height / 0.15, 1.0 / 0.35)
	robustness = mass / max(m_exp, 1e-6)
	if n == 0:
		plan = &"legless"
		robustness = 1.0
	elif n == 1:
		plan = &"monopod"
	elif n == 2:
		plan = &"upright_biped" if trunk_incline > deg_to_rad(45.0) else &"horizontal_biped"
		# bipeds carry the feet under the centre of mass
		for l in legs:
			var shift: float = clamp(com.z - l.hip.z, -0.45 * l.length, 0.45 * l.length)
			l.home.z = l.hip.z + shift
			l.rest_len = (l.home - l.hip).length()
	elif n <= 4 and stations.size() == 2:
		plan = &"quadruped"
	else:
		plan = &"multi"
	graviportal = plan == &"quadruped" and mass > 800.0 and robustness > 1.6

## Morphology-derived speed realism: a proposal for the C profile (core/ is
## not touched). See docs/godot/LOCOMOTION.md for the derivation.
func _propose() -> void:
	# Hirt et al. 2017 (Nature Ecol. Evol.): v_max = a M^b (1 - exp(-h M^i)), land animals, km/h.
	var hirt := 25.5 * pow(mass, 0.26) * (1.0 - exp(-22.0 * pow(mass, -0.6))) / 3.6
	var plan_k := {&"quadruped": 1.0, &"horizontal_biped": 0.95, &"upright_biped": 0.7,
		&"multi": 0.6, &"monopod": 0.5, &"legless": 0.22}
	var fr_cap := {&"quadruped": 25.0, &"horizontal_biped": 20.0, &"upright_biped": 10.0,
		&"multi": 8.0, &"monopod": 6.0, &"legless": 0.0}
	var limb: float = clamp(pow(1.0 / max(robustness, 1e-6), 0.35 * 0.5), 0.6, 1.3)
	var foot_k := 1.0
	var grip := 0.8
	if not legs.is_empty():
		foot_k = 0.0
		grip = 0.0
		for l in legs:
			foot_k += float(foot_info(l.foot).speed) / legs.size()
			grip += float(l.grip) / legs.size()
	var game_scale := 0.55
	var v := hirt * game_scale * float(plan_k[plan]) * limb * foot_k
	var cap := 1e9
	if plan != &"legless":
		var frc: float = 3.0 if graviportal else float(fr_cap[plan])
		cap = sqrt(frc * G * hip_height)
	var v_max: float = clamp(min(v, cap), 0.5, 12.0)
	# acceleration: traction-limited for small bodies, power-limited (M^-0.2) for large
	var a_max: float = clamp(0.6 * grip * G * min(1.0, pow(mass / 10.0, -0.2)), 0.8, 8.0)
	var lever: float = max(0.5 * track_width, 0.25 * body_length)
	var turn: float = clamp(0.45 * sqrt(mass * G * lever / inertia.y), 0.8, 3.8)
	proposal = {
		"max_speed": v_max,                      # sprint speed, m/s
		"roam_speed": v_max / 1.7,               # C profile speed (sprint = 1.7 x roam)
		"max_accel": a_max,                      # m/s2
		"accel_time": v_max / a_max,             # s, 0 -> max
		"ease_per_tick": 1.0 - exp(-0.1 * 2.0 * a_max / v_max),  # exponential ease at 10 Hz
		"max_turn_rate": turn,                   # rad/s
		"max_turn_per_tick": turn * 0.1,
		"froude_at_max": v_max * v_max / (G * hip_height),
		"hirt_unscaled": hirt,
	}
