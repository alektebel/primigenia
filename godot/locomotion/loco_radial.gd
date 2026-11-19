extends RefCounted
## Gait generator for radial bodies (A24, docs/godot/CREATURE-RADIAL.md). Same shape as LocoController: feed it the
## world position, heading and velocity every frame with step(); read `pose`, hand it to
## LocoRigAdapter.radial_apply(). Pure maths, no nodes. There is no fixed front: C steers a yaw, the animal keeps a
## visual `body_yaw` and the lead arm is the one nearest the heading, so it never turns more than pi/fold; it
## only changes its lead arm.
##
## Modes
##   glide   tube feet, slow (v < 0.5 m/s): smooth translation, the lead arm lifts 4 cm and probes +-12 deg at 0.5 Hz
##   row     brittle-star rowing (Astley 2012, J Exp Biol 215:1923): the two arms next to the lead row in synchrony
##           (power stroke 40 % of the cycle, ~35 deg backwards, tip planted), the rear arms trail lifted
##   jet     bell pulse (jellyfish): 30 % contraction of the cycle, the arms follow on damped spring chains
##   cilia   glide with a metachronal ripple along the margin; slack-tide collapse while `hunker`
##
## Description (LocoRigAdapter.radial_describe, or a test fake): {radial: {fold, disc_r, root_r, reach, tip_h, act,
##   bell, bell_d, mass}}; metres, rest space, ground y = 0. Angles in the pose are tip-up (pitch) and bearing
##   increasing towards +X (yaw), per bone, relative to the parent bone.

signal footfall(arm: int, position: Vector3)

const NB := 6                                  ## bones per arm
const MAX_DT := 1.0 / 60.0
const YAW_W := [0.4, 0.3, 0.15, 0.1, 0.05, 0.0]   ## share of an arm's yaw at each bone
const GLIDE_MAX := 0.5
const DRIFT := 0.5                              ## rad/s: how fast the body re-aligns its lead arm with the heading
const ROW_DUTY := 0.4
const ROW_FRACTION := 0.6                       ## stroke length as a share of the arm reach: f = v / (0.6 L)
const JET_K := 30.0
const JET_C := 0.6

var fold := 5
var disc_r := 0.3
var root_r := 0.22
var reach := 0.9
var tip_h := 0.03
var act := &"tubefeet"
var bell := false
var bell_d := 0.6
var ground: Callable

var mode: StringName = &"glide"
var pose := {}
var hunker := false                             ## set by the caller (idle / guarding): cilia bodies collapse at slack tide
var time := 0.0
var body_yaw := 0.0
var lead := 0
var cycle := 0.0                                ## row / jet phase 0..1
var row_hz := 0.0
var footfalls := 0

var _ready_ok := false
var _speed := 0.0
var _pos := Vector3.ZERO
var _tilt := Quaternion.IDENTITY
var _y := 0.0
var _contact: Array = []
var _ap: Array = []                             ## per arm, NB pitch angles
var _ay: Array = []
var _jp: Array = []                             ## jet spring chains: position / velocity per arm and bone
var _jv: Array = []
var _squeeze := 0.0
var _collapse := 0.0
var _wave := 0.0
var _probe := 0.0
var _last_ph := 0.0
var _dist := 0.0


func _init(desc: Dictionary = {}, ground_fn: Callable = Callable()) -> void:
	ground = ground_fn
	if not desc.is_empty():
		setup(desc, ground_fn)


func setup(desc: Dictionary, ground_fn: Callable = Callable()) -> void:
	ground = ground_fn
	var r: Dictionary = desc["radial"]
	fold = int(r["fold"])
	disc_r = float(r["disc_r"])
	root_r = float(r.get("root_r", disc_r * .75))
	reach = maxf(float(r["reach"]), .05)
	tip_h = float(r.get("tip_h", .03))
	act = StringName(r.get("act", "tubefeet"))
	bell = bool(r.get("bell", false))
	bell_d = maxf(float(r.get("bell_d", disc_r * 2.0)), .1)
	_alloc()
	mode = _base_mode()
	_ready_ok = false


func _alloc() -> void:
	_contact = []
	_ap = []
	_ay = []
	_jp = []
	_jv = []
	for k in fold:
		_contact.append(true)
		var z := PackedFloat32Array()
		z.resize(NB)
		_ap.append(z.duplicate())
		_ay.append(z.duplicate())
		_jp.append(z.duplicate())
		_jv.append(z.duplicate())


func _base_mode() -> StringName:
	if bell:
		return &"jet"
	if act == &"cilia":
		return &"cilia"
	return &"glide"


func _gy(x: float, z: float) -> float:
	return float(ground.call(x, z)) if ground.is_valid() else 0.0


func reset(pos: Vector3, yaw: float) -> void:
	_pos = pos
	body_yaw = yaw
	_y = _gy(pos.x, pos.z)
	_tilt = Quaternion.IDENTITY
	_speed = 0.0
	time = 0.0
	cycle = 0.0
	_squeeze = 0.0
	_collapse = 0.0
	_dist = 0.0
	_ready_ok = true
	mode = _base_mode()
	lead = _lead_for(yaw)
	_publish(pos, yaw)


func set_intent(_yaw) -> void:
	pass        # the heading is the only intent a body without a front needs


static func wrap_pi(a: float) -> float:
	return a - TAU * floor((a + PI) / TAU)


func _lead_for(yaw: float) -> int:
	var best := 0
	var bd := 1e9
	for k in fold:
		var d := absf(wrap_pi(yaw - (body_yaw + TAU * k / fold)))
		if d < bd:
			bd = d
			best = k
	return best


## Signed arm index relative to the lead, in (-fold/2, fold/2].
func rel(k: int) -> int:
	var j := (k - lead) % fold
	if j < 0:
		j += fold
	if j > fold / 2:
		j -= fold
	return j


func step(dt: float, pos: Vector3, yaw: float, vel: Vector3) -> void:
	if not _ready_ok:
		reset(pos, yaw)
	dt = clampf(dt, 0.0, 0.1)
	var n := maxi(1, int(ceil(dt / MAX_DT)))
	var h := dt / n
	for i in n:
		_sub(h, pos, yaw, vel)
	_publish(pos, yaw)


func _sub(h: float, pos: Vector3, yaw: float, vel: Vector3) -> void:
	time += h
	var sp := Vector2(vel.x, vel.z).length()
	if not is_finite(sp):
		sp = 0.0
	_speed += (sp - _speed) * (1.0 - exp(-6.0 * h))
	_dist += sp * h
	# lead arm and the slow drift of the body towards it
	lead = _lead_for(yaw)
	var want := wrap_pi(yaw - TAU * lead / fold)
	body_yaw = wrap_pi(body_yaw + clampf(wrap_pi(want - body_yaw), -DRIFT * h, DRIFT * h))
	# mode
	var m := _base_mode()
	if m == &"glide" and _speed >= GLIDE_MAX:
		m = &"row"
	mode = m
	for k in fold:
		for b in NB:
			_ap[k][b] = 0.0
			_ay[k][b] = 0.0
		_contact[k] = true
	_squeeze = 0.0
	var collapse_to := 1.0 if (hunker and act == &"cilia" and _speed < .05) else 0.0
	_collapse += (collapse_to - _collapse) * (1.0 - exp(-h / 0.7))
	match mode:
		&"glide":
			_glide(h)
		&"row":
			_row(h)
		&"jet":
			_jet(h)
		&"cilia":
			_cilia(h)


func _put(k: int, pitch_total: float, yaw_total: float) -> void:
	for b in NB - 1:
		_ap[k][b] += pitch_total / float(NB - 1)
	for b in NB:
		_ay[k][b] += yaw_total * float(YAW_W[b])


func _lift(height: float) -> float:
	return asin(clampf(height / reach, 0.0, .6))


func _glide(h: float) -> void:
	_probe += h * TAU * 0.5
	_wave += h * (2.0 + 6.0 * _speed)
	for k in fold:
		if k == lead:
			_put(k, _lift(.04), sin(_probe) * deg_to_rad(12.0))
			_contact[k] = false


func _row(h: float) -> void:
	var f := clampf(_speed / (ROW_FRACTION * reach), 0.4, 2.0)
	row_hz = f
	_last_ph = cycle
	cycle = fposmod(cycle + f * h, 1.0)
	var sweep := 2.0 * asin(clampf(.5 * (_speed / f) / reach, 0.0, 0.7))
	if cycle < _last_ph:
		for k in fold:
			if absi(rel(k)) == 1 and (fold > 2):
				footfalls += 1
				footfall.emit(k, tip_world(k))
	for k in fold:
		var j := rel(k)
		if j == 0:
			_put(k, _lift(.05), sin(time * TAU * .5) * deg_to_rad(6.0))
			_contact[k] = false
		elif absi(j) == 1:
			var s: float = signf(float(j))
			var yw: float
			var lift := 0.0
			if cycle < ROW_DUTY:                          # power stroke: planted, sweeping backwards
				var u := cycle / ROW_DUTY
				yw = (-.5 + u) * sweep
				_contact[k] = true
			else:                                           # recovery: lifted, swinging forwards
				var u2 := (cycle - ROW_DUTY) / (1.0 - ROW_DUTY)
				yw = (.5 - u2) * sweep
				lift = sin(PI * u2) * .07
				_contact[k] = false
			_put(k, _lift(lift), s * yw)
		else:
			_put(k, _lift(.035), 0.0)                       # trailing arms stay lifted off the ground
			_contact[k] = false


func _jet(h: float) -> void:
	var f := .5 * sqrt(.8 / bell_d)
	row_hz = f
	cycle = fposmod(cycle + f * h, 1.0)
	var s := 0.0
	if cycle < .3:
		s = sin(PI * cycle / .3)
	else:
		s = -.15 * sin(PI * (cycle - .3) / .7)           # slow refill overshoots a little
	_squeeze = s
	for k in fold:
		var target0 := -.3 * s
		for b in NB - 1:
			var prev: float = target0 if b == 0 else _jp[k][b - 1]
			var a: float = _jp[k][b]
			var v: float = _jv[k][b]
			v += (JET_K * (prev - a) - JET_C * 2.0 * sqrt(JET_K) * v) * h
			a += v * h
			if not is_finite(a):
				a = 0.0
				v = 0.0
			_jp[k][b] = clampf(a, -1.2, 1.2)
			_jv[k][b] = clampf(v, -20.0, 20.0)
			_ap[k][b] += _jp[k][b]
			_ay[k][b] += sin(time * 1.3 + float(k) * 1.9 + float(b) * .5) * .035 * float(b) / float(NB)
		_contact[k] = false


func _cilia(h: float) -> void:
	_wave += h * (1.0 + 4.0 * _speed)
	for k in fold:
		var th := TAU * k / fold
		for b in NB - 1:
			_ap[k][b] += .045 * sin(3.0 * th - 2.0 * time - .6 * float(b))


# ---------------------------------------------------------------- pose

## Rest position of arm k's tip bone, body space (tip_h above the ground).
func tip_rest(k: int) -> Vector3:
	var a := TAU * k / fold
	return Vector3(sin(a), 0.0, cos(a)) * (root_r + reach) + Vector3(0, tip_h, 0)


## Tip of arm k in body space: the rest tip plus what the bone pitches and yaws move it by (straight segments).
func tip_local(k: int) -> Vector3:
	var a := TAU * k / fold
	var seg := reach / float(NB - 1)
	var p := Vector3(sin(a), 0.0, cos(a)) * root_r + Vector3(0, tip_h, 0)
	var cp := 0.0
	var cy := 0.0
	for b in NB - 1:
		cp += _ap[k][b]
		cy += _ay[k][b]
		var ha := a + cy
		p += Vector3(sin(ha) * cos(cp), sin(cp), cos(ha) * cos(cp)) * seg
	# the rest tip is the straight chain at pitch 0; return the displaced one
	return p


func tip_world(k: int) -> Vector3:
	var r: Transform3D = pose["root"] if pose.has("root") else Transform3D(Basis(), _pos)
	return r * tip_local(k)


func _plane(pos: Vector3, yaw_b: float) -> Dictionary:
	# least-squares plane through the ground under the centre and the arm tips (disc size: the body rests on it)
	var R := root_r + reach * .9
	var hs := PackedFloat32Array()
	var sx := 0.0
	var sz := 0.0
	var sxx := 0.0
	var szz := 0.0
	var sh := _gy(pos.x, pos.z)
	var hx := 0.0
	var hz := 0.0
	var pts := []
	for k in fold:
		var a := yaw_b + TAU * k / fold
		var dx := sin(a) * R
		var dz := cos(a) * R
		var g := _gy(pos.x + dx, pos.z + dz)
		pts.append([dx, dz, g])
		sh += g
		hx += g * dx
		hz += g * dz
		sxx += dx * dx
		szz += dz * dz
	var cnt := float(fold + 1)
	var bx := hx / maxf(sxx, 1e-6)
	var bz := hz / maxf(szz, 1e-6)
	return {"a": sh / cnt, "bx": bx, "bz": bz, "pts": pts}


func _publish(pos: Vector3, yaw: float) -> void:
	var pl := _plane(pos, body_yaw)
	var slope := Vector2(float(pl["bx"]), float(pl["bz"]))
	if slope.length() > 1.2:
		slope = slope.normalized() * 1.2
	var up := Vector3(-slope.x, 1.0, -slope.y).normalized()
	var qt := Quaternion(Vector3.UP, up) if up.dot(Vector3.UP) < .99999 else Quaternion.IDENTITY
	var kf := 1.0 - exp(-8.0 * MAX_DT * 2.0)
	_tilt = _tilt.slerp(qt, kf)
	_y += (float(pl["a"]) - _y) * kf
	if not is_finite(_y):
		_y = pos.y
	var surge := 0.0
	if mode == &"row":
		surge = sin(TAU * cycle) * .02 * reach
	var origin := Vector3(pos.x, _y, pos.z) + Vector3(sin(yaw), 0.0, cos(yaw)) * surge
	var root := Transform3D(Basis(_tilt) * Basis(Vector3.UP, body_yaw), origin)
	# ground residual: pitch each planted arm so the tip sits on ground(tip) (2 CCD iterations on the chain)
	var ap := []
	var ay := []
	for k in fold:
		ap.append((_ap[k] as PackedFloat32Array).duplicate())
		ay.append((_ay[k] as PackedFloat32Array).duplicate())
	pose = {"root": root, "body_yaw": body_yaw, "lead": lead, "mode": mode, "arm_pitch": ap, "arm_yaw": ay,
		"contact": _contact.duplicate(), "axis": {"squeeze": _squeeze, "collapse": _collapse}, "wave": _wave,
		"margin": -2.0 * time, "speed": _speed, "cycle": cycle, "tip": []}
	if mode == &"glide" or mode == &"cilia" or mode == &"row":
		for k in fold:
			if not _contact[k]:
				continue
			for it in 2:
				var tw := root * tip_local_of(ap[k], ay[k], k)
				var err := (_gy(tw.x, tw.z) + tip_h) - tw.y
				if absf(err) < .002:
					break
				var seg := reach / float(NB - 1)
				var q := clampf(err / (seg * 15.0), -.12, .12)
				for b in NB - 1:
					ap[k][b] += q
	for k in fold:
		pose["tip"].append(root * tip_local_of(ap[k], ay[k], k))


func tip_local_of(pitch: PackedFloat32Array, yaw: PackedFloat32Array, k: int) -> Vector3:
	var a := TAU * k / fold
	var seg := reach / float(NB - 1)
	var p := Vector3(sin(a), 0.0, cos(a)) * root_r + Vector3(0, tip_h, 0)
	var cp := 0.0
	var cy := 0.0
	for b in NB - 1:
		cp += pitch[b]
		cy += yaw[b]
		var ha := a + cy
		p += Vector3(sin(ha) * cos(cp), sin(cp), cos(ha) * cos(cp)) * seg
	return p


## Where tube-foot suckers touch down, for the footfall strip and the tests: contact flag per arm.
func planted() -> Array:
	return _contact.duplicate()
