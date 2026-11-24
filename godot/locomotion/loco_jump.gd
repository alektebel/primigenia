extends RefCounted
## Jump presentation (visual only; C owns the height, godot/game/stage/stage_world.gd hands it over as the player's y).
##
## It post-processes the locomotion pose of the controller (controller.pose) once per frame:
##   launch   the body starts a quick crouch (a fraction of the hip height) that springs out in about 0.1 s while C already lifts it,
##            so the input feels instant: there is no wind-up before the take-off, the crouch is the first frames of the rise;
##   air      the legs fold up under the hips (feet leave the ground once the body has risen past full leg extension, then tuck),
##            the nose pitches up on the way up and down on the way down, the tail counter-swings;
##   landing  the legs stretch out again before touchdown, then the body squashes (springs back with a small overshoot) over feet that
##            stay planted where the gait had them, so nothing slides.
## The ground gait of the controller keeps running underneath, so a running jump lands in the stride it left.

const CROUCH := 0.30            # launch crouch depth, in hip heights (starting value: the owner wants visible, slightly exaggerated motion)
const SQUASH := 0.34            # landing squash depth at the full impact, in hip heights
const SLACK := 0.04             # leg slack at a normal stance (hip heights): the body can rise this far before a planted foot must leave
const TUCK := 0.34              # extra foot lift at the full tuck (hip heights)
const PITCH_MAX := 0.22         # rad of body pitch at the launch and at the touchdown speed
const LAUNCH_W := 30.0          # rad/s of the launch crouch spring
const LAND_W := 19.0            # rad/s of the landing squash spring
const LAND_ZETA := 0.5

var sq := 0.0                   # body dip in hip heights (+ = lower), spring state
var sv := 0.0
var _w := LAUNCH_W
var _zeta := 0.8
var tuck := 0.0
var _was := false
var _air_prev := 0.0
var _vy := 0.0
var _apex := 0.0
var _pitch := 0.0
var active := false             # something is being shown (the controller pose is modified)
var landed := 0                 # counts landings (tests)
var peak_air := 0.0             # highest air of the last jump (tests)

func _spring(h: float) -> void:
	var v := (sv + h * _w * _w * (0.0 - sq)) / (1.0 + 2.0 * _zeta * _w * h + _w * _w * h * h)
	sq += v * h
	sv = v

## dt: frame time. jumping: C says this air phase is a jump. air: metres above the ground under the body.
## Returns true when the pose was modified.
func apply(dt: float, jumping: bool, air: float, pose: Dictionary, ref_h: float, hip_loc: Array) -> bool:
	if dt <= 0.0 or not pose.has("root"):
		return false
	var hh := maxf(ref_h, 0.05)
	var in_air := jumping and air > 0.001
	if jumping and not _was:
		sq = CROUCH * 0.9
		sv = 0.0
		_w = LAUNCH_W
		_zeta = 0.85
		_apex = 0.0
		_vy = 0.0
		tuck = 0.0
		_pitch = 0.0
	if jumping:
		_vy = lerpf(_vy, (air - _air_prev) / dt, 1.0 - exp(-dt / 0.04))
		_apex = maxf(_apex, air)
		peak_air = _apex
	if _was and not jumping:
		# touchdown: the squash is deeper for a harder landing (descent speed relative to the take-off speed of this body)
		var hard := clampf(-_vy / sqrt(2.0 * 9.81 * maxf(_apex, 0.1)), 0.3, 1.0)
		sq = SQUASH * hard
		sv = 0.0
		_w = LAND_W
		_zeta = LAND_ZETA
		landed += 1
	_was = jumping
	_air_prev = air
	_spring(minf(dt, 1.0 / 30.0))
	if absf(sq) < 0.002 and absf(sv) < 0.01:
		sq = 0.0
		sv = 0.0
	var squat := sq != 0.0
	if not jumping and not squat and tuck < 0.01:
		tuck = 0.0
		_pitch = lerpf(_pitch, 0.0, 0.3)
		active = false
		return false
	active = true
	# the folding of the legs follows the height: it opens before the touchdown (descending and within half the apex)
	var t_tuck := clampf((air - 0.12 * hh) / (0.25 * hh), 0.0, 1.0) if jumping else 0.0
	if jumping and _vy < 0.0:
		t_tuck *= clampf(air / maxf(0.5 * _apex, 0.01), 0.0, 1.0)
	tuck = lerpf(tuck, t_tuck, 1.0 - exp(-dt / 0.05))
	var off := (air if jumping else 0.0) - sq * hh                  # the body's height change against the ground gait
	var pitch_t := 0.0
	if jumping:
		pitch_t = -PITCH_MAX * clampf(_vy / 3.0, -1.0, 1.0)          # nose up rising, down falling (rotation about +X is nose down)
	_pitch = lerpf(_pitch, pitch_t, 1.0 - exp(-dt / 0.06))
	var old_root: Transform3D = pose.root
	var root := old_root
	root.origin.y += off
	var com: Vector3 = pose.get("com", root.origin)
	var pivot := Vector3(com.x, com.y + off, com.z)
	var rot := Transform3D(Basis(old_root.basis * Vector3.RIGHT, _pitch), Vector3.ZERO)
	root = Transform3D(rot.basis, pivot - rot.basis * pivot) * root
	var xf := root * old_root.affine_inverse()
	pose.root = root
	if pose.has("hips"):
		var hips: PackedVector3Array = pose.hips
		for i in hips.size():
			hips[i] = xf * hips[i]
		pose.hips = hips
	pose.com = xf * com
	if pose.has("feet"):
		var feet: PackedVector3Array = (pose.feet as PackedVector3Array).duplicate()
		var contact: Array = (pose.contact as Array).duplicate()
		var swing_u: PackedFloat32Array = (pose.swing_u as PackedFloat32Array).duplicate()
		for j in feet.size():
			var f0: Vector3 = feet[j]
			var lift := maxf(0.0, off - SLACK * hh) + tuck * TUCK * hh
			if lift <= 0.0:
				continue
			var hipw: Vector3 = root * (hip_loc[j] as Vector3) if j < hip_loc.size() else f0
			var fa := Vector3(lerpf(f0.x, hipw.x, 0.6 * tuck), f0.y + lift, lerpf(f0.z, hipw.z, 0.6 * tuck))
			var w := clampf(lift / (0.1 * hh), 0.0, 1.0)
			feet[j] = f0.lerp(fa, w)
			if lift > 0.02 * hh:
				contact[j] = false
				swing_u[j] = 0.5
		pose.feet = feet
		pose.contact = contact
		pose.swing_u = swing_u
	if pose.has("tail") and jumping:
		(pose.tail as Dictionary).pitch = float((pose.tail as Dictionary).pitch) - 0.25 * clampf(_vy / 3.0, -1.0, 1.0)
	return true
