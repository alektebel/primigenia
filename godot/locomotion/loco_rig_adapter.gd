extends RefCounted
## Adapter between the creature rig (branch g-creature, `Creature` and
## `CreatureLegChain`) and the locomotion controller. Pure static functions;
## the rig is passed as a Variant, so this file does not depend on
## `class_name Creature` and tests can feed it a fake object with the same
## fields. Integration with the real rig is a later task and has NOT been run.
##
##   var desc := Adapter.loco_describe(creature, unit)   # unit: metres per rig unit
##   assert(desc.problems.is_empty())
##   var loco := Ctl.new(Morph.analyse(desc), ground_fn)
##   ...each frame:
##   loco.step(delta, pos, yaw, vel)
##   Adapter.loco_apply(creature, loco.pose, desc)
##
## Fields read from the rig (see docs/godot/CREATURE.md on g-creature):
## Creature: rest, rad, ground_offset, tail_bones, neck_bones, skeleton,
## parts[{type, category, side, t, ang, size}], anchor(t, ang), legs,
## maker.meta(type).foot, bone_rest_global(bone), reset_spine_pose(), solve_legs().
## CreatureLegChain: hip_local(), upper_length, lower_length, width, side,
## type, home, hang, hip_bone, foot_target, foot_yaw, foot_pitch.

const Morph = preload("loco_morphology.gd")

## Provisional part masses: mass = density * k * size^3 (size in metres).
## Not measured; replace when the part catalogue has masses.
const K_CATEGORY := {"horns": 0.02, "horn": 0.02, "shell": 0.08, "shells": 0.08, "plates": 0.08, "wings": 0.01, "fins": 0.01,
	"sensory": 0.005, "senses": 0.005, "mouths": 0.03, "weapons": 0.04, "digging_claws": 0.04, "arms": 0.03, "tails": 0.03}
const K_TYPE := {"cuerno": 0.02, "horn_crown": 0.02, "placa": 0.08, "shell_plate": 0.08, "aleta": 0.01, "wing_glider": 0.01, "wing_insect": 0.01}
const K_DEFAULT := 0.02
const SOLE := 0.6                   # the rig's sole sits width * SOLE under the ankle
const HANG_LIMIT := 0.001           # rig units; above it a leg hangs and is left out
const SOLE_TOLERANCE := 0.002       # m
const REACH_MARGIN := 0.04          # m taken off every described leg: the rig's hips ride the bones and can sit up to
									# 3 cm from the controller's (girdle model), and the rig's IK stops 1 cm short of straight
const BELLY_GAP := 0.03             # m between the lowest body vertex and the ground for a legless body

## Legless bodies: the rig's `ground_offset` is derived from the ring radii (rig.js `off`), but the built tube
## is an ellipse that is smaller than the circle at the belly, so the real lowest vertex floats a few cm above
## the ground (Babosa: 7.5 cm). Returns how far to lower the creature so the lowest body vertex is BELLY_GAP up.
static func belly_drop(creature) -> float:
	if creature.legs.size() > 0 or creature.get("body_mesh") == null or creature.body_mesh.mesh == null:
		return 0.0
	var mesh: Mesh = creature.body_mesh.mesh
	if mesh.get_surface_count() == 0:
		return 0.0
	var lowest := 1e9
	for v in (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		lowest = min(lowest, v.y)
	return maxf(0.0, lowest + float(creature.ground_offset) - BELLY_GAP)

static func _kind(creature, leg) -> String:
	if creature.get("maker") != null:
		var meta: Dictionary = creature.maker.meta(leg.type)
		return str(meta.get("foot", "garra"))
	return "garra"

static func region_for(t: float, last: bool) -> String:
	if last:
		return "head"
	if t < 0.35:
		return "tail"
	if t >= 0.68:
		return "neck"
	return "trunk"

## Body description for LocoMorphology, in metres, rest space (+Z forward, +X
## left, ground y = 0). `unit` = metres per rig unit. Returns the dictionary
## plus `unit`, `leg_ids` (rig leg index of each described leg) and `problems`
## (empty when the six contract points hold).
static func loco_describe(creature, unit: float, density := 1000.0) -> Dictionary:
	var problems: Array = []
	if creature.has_method("reset_spine_pose"):
		creature.reset_spine_pose()
	var spine: Array = []
	var n: int = creature.rest.size()
	var go: float = creature.ground_offset
	var i := 0
	while i < n:
		var last: bool = i + 4 >= n
		var idx := n - 1 if last else i
		var t := float(idx) / float(max(n - 1, 1))
		var p: Vector3 = (creature.rest[idx] + Vector3(0.0, go, 0.0)) * unit
		spine.append({"pos": p, "radius": float(creature.rad[idx]) * unit, "region": region_for(t, idx == n - 1)})
		if last:
			break
		i += 4
	var legs: Array = []
	var leg_ids: Array = []
	var kinds_ok := true
	for k in range(creature.legs.size()):
		var l = creature.legs[k]
		if l.hang > HANG_LIMIT:
			continue                                # 4. hanging legs are not walking legs
		var kind := _kind(creature, l)
		var fi: Dictionary = Morph.FOOT.get(kind, {})
		if fi.is_empty():
			problems.append("6. foot kind '%s' is not in the FOOT table" % kind)
			kinds_ok = false
			fi = Morph.FOOT["paw"]
		var hip: Vector3 = l.hip_local() * unit
		var w: float = l.width * unit
		var reach_k := clampf(1.0 - REACH_MARGIN / maxf((l.upper_length + l.lower_length) * unit, 1e-3), 0.85, 1.0)
		# 3. the controller's ankle is ankle_fraction * foot_size above the ground;
		# the rig's sole is SOLE * width under the ankle: make them the same height
		var foot_size: float = SOLE * w / fi.ankle
		legs.append({"hip": hip, "upper": l.upper_length * unit * reach_k, "lower": l.lower_length * unit * reach_k, "radius": w * 0.5,
			"foot": kind, "foot_size": foot_size, "foot_rest": l.home * unit, "side": l.side})
		leg_ids.append(k)
		# 2. axes: side +1 is +X (left); a mirrored mesh would show up here
		if abs(hip.x) > 1e-4 and sign(hip.x) != float(l.side):
			problems.append("2. leg %d has side %d but hip x %.3f: the rig is mirrored" % [k, l.side, hip.x])
		# 3. at rest the sole must be on the ground
		if abs(float(l.hang)) * unit > SOLE_TOLERANCE:
			problems.append("3. leg %d rest sole is %.1f mm off the ground" % [k, l.hang * unit * 1000.0])
	var parts: Array = []
	for e in creature.parts:
		var cat: String = str(e.get("category", ""))
		if cat == "legs":
			continue
		var kc: float = K_TYPE.get(str(e.get("type", "")), K_CATEGORY.get(cat, K_DEFAULT))
		var size: float = float(e.get("size", 1.0)) * unit
		var anchor: Dictionary = creature.anchor(float(e.get("t", 0.5)), float(e.get("side", 1)) * float(e.get("ang", 0.0)))
		parts.append({"pos": (anchor.p + Vector3(0.0, go, 0.0)) * unit, "mass": density * kc * size * size * size, "category": cat})
	var desc := {"spine": spine, "legs": legs, "parts": parts, "density": density, "unit": unit, "leg_ids": leg_ids,
		"belly_drop": belly_drop(creature) * unit}
	# 2. forward is +Z: the head end of the spine is ahead of the tail end
	if spine.size() >= 2 and spine[-1].pos.z <= spine[0].pos.z:
		problems.append("2. the head is not in front of the tail along +Z")
	# 1. units
	var m = Morph.analyse(desc)
	if not (m.hip_height > 0.02 and m.hip_height < 5.0) and not legs.is_empty():
		problems.append("1. hip height %.3f m is outside 0.02..5 m: wrong `unit` (%.4f m per rig unit)?" % [m.hip_height, unit])
	if unit <= 0.0:
		problems.append("1. unit must be positive")
	if not kinds_ok:
		pass
	desc["problems"] = problems
	return desc

static func _yaw_of(v: Vector3) -> float:
	return atan2(v.x, v.z)

## Writes a LocoController pose into the rig and solves the legs.
## Returns {max_sole_error} (metres) for the planted legs when `ground` is given.
static func loco_apply(creature, pose: Dictionary, desc: Dictionary, ground: Callable = Callable()) -> Dictionary:
	if desc.has("radial"):
		return radial_apply(creature, pose, desc)
	var unit: float = desc.unit
	var root: Transform3D = pose.root
	creature.global_transform = Transform3D(root.basis * Basis.from_scale(Vector3.ONE * unit), root.origin - Vector3.UP * float(desc.get("belly_drop", 0.0)))
	var heading := _yaw_of(root.basis.z)
	var ids: Array = desc.leg_ids
	for j in range(ids.size()):
		var l = creature.legs[ids[j]]
		var contact: bool = pose.contact[j]
		var up: float = SOLE * l.width * unit
		l.foot_target = (pose.feet[j] as Vector3) - Vector3.UP * up
		if contact:
			l.foot_pitch = pose.foot_pitch[j]             # heel raised = toe down = +X rotation
			l.foot_yaw = _yaw_of(pose.foot_dir[j])
		else:
			l.foot_pitch = -0.5 * sin(PI * pose.swing_u[j])  # rig.js: toe up during swing
			l.foot_yaw = heading
	_bend_spine(creature, pose, desc)
	creature.solve_legs()
	var err := 0.0
	if ground.is_valid():
		for j in range(ids.size()):
			if pose.contact[j]:
				var l = creature.legs[ids[j]]
				var p: Vector3 = l.foot_target
				err = max(err, abs(p.y - float(ground.call(p.x, p.z))))
	return {"max_sole_error": err}

## Spine bones: absolute yaw / pitch per bone (girdle bend, tail, neck,
## undulation), converted to local rotations about each bone's Y (lateral) and
## X (pitch) axes relative to its parent. Signs follow capsule_rig.gd
## (tail tip up = +X rotation, nose up = -X rotation); they are UNVERIFIED on
## the real skeleton.
static func _bend_spine(creature, pose: Dictionary, desc: Dictionary) -> void:
	var sk = creature.skeleton
	if sk == null:
		return
	var unit: float = desc.unit
	var nb: int = sk.get_bone_count()
	var yaw_abs := PackedFloat32Array()
	var pit_abs := PackedFloat32Array()
	yaw_abs.resize(nb)
	pit_abs.resize(nb)
	var tail_k := {}
	for a in range(creature.tail_bones.size()):
		tail_k[creature.tail_bones[a]] = 1.0 - float(a) / max(creature.tail_bones.size(), 1)      # tip first
	var neck_k := {}
	for a in range(creature.neck_bones.size()):
		neck_k[creature.neck_bones[a]] = float(a + 1) / max(creature.neck_bones.size(), 1)
	var spine_at: Callable = pose.spine_at
	var wave: Dictionary = pose.get("wave", {})
	var wl: float = max(float(desc.get("spine", [{}])[-1].get("pos", Vector3.ZERO).z - desc.get("spine", [{}])[0].get("pos", Vector3.ZERO).z), 1e-3)
	for b in range(nb):
		var z: float = (creature.bone_rest_global(b) as Transform3D).origin.z * unit
		var yw: float = spine_at.call(z).yaw
		if not wave.is_empty() and wave.get("amp", 0.0) > 0.0:
			var u := clampf((z - desc.spine[0].pos.z) / wl, 0.0, 1.0)
			var du := 0.01
			var f1 := _wave(wave, clampf(u + du, 0.0, 1.0))
			var f0 := _wave(wave, clampf(u - du, 0.0, 1.0))
			yw += atan((f1 - f0) / (2.0 * du * wl))
		var pt := 0.0
		if pose.has("spine_pitch"):
			pt += float((pose.spine_pitch as Callable).call(z))
		if tail_k.has(b):
			yw += pose.tail.yaw * tail_k[b]
			pt += pose.tail.pitch * tail_k[b]
		if neck_k.has(b):
			yw += pose.neck.yaw * neck_k[b]
			pt -= pose.neck.pitch * neck_k[b]
		yaw_abs[b] = yw
		pit_abs[b] = pt
	if not (desc.leg_ids as Array).is_empty():        # legless bodies keep their natural head carriage (a slug's head rests on the ground)
		_stabilise_head(creature, pose, sk, yaw_abs, pit_abs, neck_k)
	var act: Dictionary = pose.get("act", {})        # action layer (godot/actions): local bone deltas added on top
	# Bones from the first neck bone to the head take their yaw and pitch about the CREATURE's up and lateral axes
	# (a steep neck's own axes are tilted, so a local yaw would roll it sideways: the longneck periscope flip).
	var root_b = creature.get("root_bone")
	var from_creature: int = nb
	if root_b != null and sk.has_method("get_bone_global_rest") and creature.neck_bones.size() > 0 and creature.neck_bones[0] > int(root_b):
		from_creature = int(creature.neck_bones[0])
	var gpose := {}
	for b in range(nb):
		var par: int = sk.get_bone_parent(b)
		var rest_q: Quaternion = (sk.get_bone_rest(b) as Transform3D).basis.get_rotation_quaternion()
		var q: Quaternion
		if b >= from_creature:
			# rotation relative to the parent about the creature's axes, applied in the parent's actual frame (so the action
			# layer's rotations on the parent still carry the child along)
			var rc := Quaternion(Vector3.UP, yaw_abs[b]) * Quaternion(Vector3.RIGHT, pit_abs[b])
			var rc_par := Quaternion(Vector3.UP, yaw_abs[par]) * Quaternion(Vector3.RIGHT, pit_abs[par])
			var rel: Quaternion = rc * rc_par.inverse()
			var gp: Quaternion = gpose[par]
			q = gp.inverse() * rel * gp * rest_q
			if not act.is_empty():
				q = q * Quaternion(Vector3.UP, act.bone_dy[b]) * Quaternion(Vector3.RIGHT, act.bone_dp[b]) * Quaternion(Vector3.BACK, act.bone_dr[b])
		else:
			var dy: float = yaw_abs[b] - (yaw_abs[par] if par >= 0 else 0.0)
			var dp: float = pit_abs[b] - (pit_abs[par] if par >= 0 else 0.0)
			if not act.is_empty():
				dy += act.bone_dy[b]
				dp += act.bone_dp[b]
				q = rest_q * Quaternion(Vector3.UP, dy) * Quaternion(Vector3.RIGHT, dp) * Quaternion(Vector3.BACK, act.bone_dr[b])
			else:
				q = rest_q * Quaternion(Vector3.UP, dy) * Quaternion(Vector3.RIGHT, dp)
		sk.set_bone_pose_rotation(b, q)
		if root_b != null and b >= int(root_b):
			gpose[b] = (gpose[par] as Quaternion) * q if gpose.has(par) else q

## Head level (L1, docs/briefs/l1-posture.md). The generated rest mesh itself points the head up (the spine
## centreline rises ~19 deg over the last bones on every body, 37 deg on the longneck), so the head is counter-rotated
## about the neck: the head bone and the bones beyond it take one absolute pitch, the neck bones ramp towards it.
## HEAD_STAB is the share of the body's pitch (and the flex) the head ignores; the rest is the natural nod.
## Long steep necks (longneck) are also leaned forward so the head is carried ahead of the shoulders, not above them.
const HEAD_STAB := 0.9
const NECK_NOD := 0.2               # share of the controller's neck pitch the head keeps (a nod; the rest is stabilised away)
const HEAD_RATE := 0.06             # rad per applied frame
const HEAD_BIAS := 0.05             # rad: slightly nose up of level (the stabilised mean sits ~3 deg low)
const NECK_RISE_MAX := 0.6          # rad (~34 deg): a neck rising more than this at rest is leaned forward by the excess
const NECK_LEAN_MAX := 0.7          # rad

static func _stabilise_head(creature, pose: Dictionary, sk, yaw_abs: PackedFloat32Array, pit_abs: PackedFloat32Array, neck_k: Dictionary) -> void:
	var hb: int = int(creature.get("head_bone") if creature.get("head_bone") != null else -1)
	var nb: int = sk.get_bone_count()
	if hb < 0 or hb >= nb - 1 or creature.neck_bones.is_empty():
		return
	var tip: int = nb - 1
	var spine_b = creature.get("spine_bones")
	if spine_b != null and spine_b.size() > 0:
		tip = int(spine_b[spine_b.size() - 1])
	var h0: Vector3 = (sk.get_bone_global_rest(hb) as Transform3D).origin
	var h1: Vector3 = (sk.get_bone_global_rest(tip) as Transform3D).origin
	var rest_up := atan2(h1.y - h0.y, Vector2(h1.x - h0.x, h1.z - h0.z).length())
	# neck rise at rest: first neck bone to the head
	var n0: Vector3 = (sk.get_bone_global_rest(creature.neck_bones[0]) as Transform3D).origin
	var rise := atan2(h0.y - n0.y, maxf(Vector2(h0.x - n0.x, h0.z - n0.z).length(), 1e-4))
	var lean := clampf(rise - NECK_RISE_MAX, 0.0, NECK_LEAN_MAX)
	var nn: int = creature.neck_bones.size()
	for a in range(nn):
		var bn: int = creature.neck_bones[a]
		pit_abs[bn] += lean * minf(1.0, float(a + 1) / maxf(1.0, 0.5 * nn))
	var neck_pitch: float = float((pose.neck as Dictionary).pitch)
	for b in range(hb, nb):
		pit_abs[b] += lean - neck_pitch * 1.0
	var x: float = float(pose.get("pitch", 0.0)) + pit_abs[hb] + NECK_NOD * neck_pitch      # the neck's own pitch command is only partly cancelled
	var c: float = rest_up - HEAD_STAB * x - HEAD_BIAS
	# rate limit per call: a lunge (the action layer pitches the body in a few frames) must not whip the head back at twice the speed
	if creature is Object and creature.has_method("get_meta"):
		var prev = creature.get_meta("l1_head_c") if creature.has_meta("l1_head_c") else null
		if prev != null:
			c = float(prev) + clampf(c - float(prev), -HEAD_RATE, HEAD_RATE)
		creature.set_meta("l1_head_c", c)
	for bn in neck_k:
		pit_abs[bn] += c * float(neck_k[bn])
	for b in range(hb, nb):
		pit_abs[b] += c

static func _wave(w: Dictionary, u: float) -> float:
	return w.amp * (0.4 + 0.6 * (1.0 - u)) * sin(TAU * (w.waves * u + w.phase))


# ---------------------------------------------------------------- radial bodies (loco_radial.gd)

## Body description of a radial creature (Creature.plan_kind == "radial"), metres, rest space, ground y = 0.
static func radial_describe(creature, unit: float, density := 1000.0) -> Dictionary:
	var r = creature.radial
	var base: Vector3 = r._arm_point(0, 0.0)
	var tip: Vector3 = r._arm_point(0, 1.0)
	var root_r := Vector2(base.x, base.z).length()
	var reach := Vector2(tip.x - base.x, tip.z - base.z).length()
	var disc_h := 2.0 * float(r.disc_half)
	var vol: float = creature.body_volume() * pow(unit, 3.0)
	var desc := {"radial": {"fold": r.fold, "disc_r": float(r.max_r) * unit, "root_r": root_r * unit, "reach": reach * unit,
		"tip_h": (tip.y + float(creature.ground_offset)) * unit, "act": String(creature.bio["arm"]["act"]),
		"bell": float(r.gel) > 0.0 or float(r.arm["droop"]) >= .5, "bell_d": 2.0 * float(r.max_r) * unit,
		"disc_h": disc_h * unit, "mass": vol * density * (.2 if float(r.gel) > 0.0 else .9)},
		"unit": unit, "belly_drop": 0.0, "problems": []}
	if reach <= 0.01:
		desc["problems"].append("7. a radial body without arms has nothing to move")
	return desc


## Writes a LocoRadial pose into the rig: body placement (visual yaw and tilt), arm bone pitches and yaws, axis squeeze.
static func radial_apply(creature, pose: Dictionary, desc: Dictionary, ground: Callable = Callable()) -> Dictionary:
	var unit: float = desc.unit
	var root: Transform3D = pose.root
	creature.global_transform = Transform3D(root.basis * Basis.from_scale(Vector3.ONE * unit), root.origin)
	var sk = creature.skeleton
	var r = creature.radial
	var ap: Array = pose.arm_pitch
	var ay: Array = pose.arm_yaw
	for k in range(r.arm_bones.size()):
		for b in range(r.arm_bones[k].size()):
			var bone: int = r.arm_bones[k][b]
			var rest_q: Quaternion = (sk.get_bone_rest(bone) as Transform3D).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(bone, rest_q * Quaternion(Vector3.UP, ay[k][b]) * Quaternion(Vector3.RIGHT, -ap[k][b]))
	var sq: float = pose.axis.squeeze
	var col: float = pose.axis.collapse
	var y0: float = (sk.get_bone_rest(r.axis_bones[0]) as Transform3D).origin.y
	for i in range(r.axis_bones.size()):
		var bone: int = r.axis_bones[i]
		sk.set_bone_pose_scale(bone, Vector3(1.0 - .18 * sq, 1.0 + .1 * sq, 1.0 - .18 * sq))
		var rp: Vector3 = (sk.get_bone_rest(bone) as Transform3D).origin
		sk.set_bone_pose_position(bone, Vector3(rp.x, y0 + (rp.y - y0) * (1.0 - .45 * col), rp.z))
	return {"max_sole_error": 0.0}
