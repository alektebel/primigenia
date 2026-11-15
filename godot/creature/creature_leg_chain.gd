class_name CreatureLegChain
extends RefCounted
## One leg: hip -> knee -> foot, solved with the two-bone IK of
## web/creature/rig.js update() (law of cosines plus a pole vector).
## No gait here: a locomotion module sets `foot_target` (the point on the
## ground under the sole, global space), optionally `foot_yaw` / `foot_pitch`,
## and calls solve(). Positions are in the Creature node's local space unless
## the method name says global.

const DOWN := Vector3(0, -1, 0)

var creature: Node3D          ## the Creature (world placement node)
var part: Dictionary          ## genome part that made this leg
var part_index := -1          ## index in genome.parts
var type := ""                ## part id (pata, zanca, leg_sprinter, ...)
var side := 1                 ## +1 or -1 (mirror across the spine)
var hip_marker: Node3D        ## follows the spine bone; its origin is the hip
var hip_bone := -1            ## skeleton bone that carries the hip
var upper: Node3D             ## thigh segment, local -Y points to the knee
var lower: Node3D             ## shin segment, local -Y points to the ankle
var foot: Node3D              ## foot, origin on the sole
var upper_length := 1.0       ## a
var lower_length := 1.0       ## b
var width := .2               ## w (segment girth; the sole sits w*.6 under the ankle)
var rest_knee := Vector3()    ## knee offset from hip at rest (rk, side applied)
var rest_foot := Vector3()    ## ankle offset from hip at rest (rf, side applied)
var pole := Vector3(0, 0, 1)  ## knee pole direction (creature space)
var home := Vector3()         ## rest sole point on the ground (creature space, y=0)
var hang := 0.0               ## sole height above ground at rest (0 for grounded legs)
var mirrored_mesh := false    ## fitted G48 legs mirror their meshes by side
var pair_index := 0           ## index of this leg's mount t among the sorted leg mounts
var front := false            ## mount in the front half of the leg mounts

## Inputs written by locomotion.
var foot_target := Vector3()  ## GLOBAL point under the sole
var foot_yaw := 0.0           ## GLOBAL yaw of the foot (rig.js uses the facing)
var foot_pitch := 0.0         ## toe pitch (rig.js lifts -.5*sin during swing)
var allow_stretch := false    ## stretch bones when the target is out of reach (terrain)

## Outputs of the last solve (creature space).
var hip := Vector3()
var knee := Vector3()
var ankle := Vector3()


func total_length() -> float:
	return upper_length + lower_length


## Hip position in Creature-local space (follows body_root and the spine pose).
func hip_local() -> Vector3:
	var t := Transform3D.IDENTITY
	var n: Node = hip_marker
	while n and n != creature:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t.origin


func hip_global() -> Vector3:
	return creature.global_transform * hip_local() if creature.is_inside_tree() else hip_local()


## Rest pose: knee and ankle at their authored offsets (rig.js non-test branch).
func pose_rest() -> void:
	hip = hip_local()
	knee = hip + rest_knee
	ankle = hip + rest_foot
	_apply(0.0, 0.0, 1.0)
	if creature.is_inside_tree():
		foot_target = creature.global_transform * (ankle - Vector3(0, width * .6, 0))
	else:
		foot_target = ankle - Vector3(0, width * .6, 0)
	foot_yaw = _creature_yaw()


func _creature_yaw() -> float:
	if creature.is_inside_tree():
		var f := creature.global_transform.basis.z
		return atan2(f.x, f.z)
	return creature.rotation.y


## Two-bone IK towards foot_target (global). Returns the clamped hip-ankle
## distance ratio (1 = fully extended).
func solve() -> float:
	var to_local := creature.global_transform.affine_inverse() if creature.is_inside_tree() else Transform3D.IDENTITY
	var target := to_local * foot_target
	var yaw := foot_yaw - _creature_yaw()
	return solve_local(target, yaw, foot_pitch)


## IK in creature space. `sole` is the ground point under the sole,
## `yaw_local` the foot yaw relative to the creature.
func solve_local(sole: Vector3, yaw_local := 0.0, pitch := 0.0) -> float:
	hip = hip_local()
	var a_pt := sole + Vector3(0, width * .6, 0)
	var dv := a_pt - hip
	var d := dv.length()
	dv = dv / d if d > 1e-6 else DOWN
	var extension := maxf(1.0, (d + .01) / total_length()) if allow_stretch else 1.0
	var la := upper_length * extension
	var lb := lower_length * extension
	d = clampf(d, .08, la + lb - .01)
	var x := (la * la - lb * lb + d * d) / (2 * d)
	var h := sqrt(maxf(la * la - x * x, 0.0))
	var pl := pole - dv * pole.dot(dv)
	if pl.length_squared() < 1e-4:
		pl = Vector3(0, 0, 1)
	pl = pl.normalized()
	knee = hip + dv * x + pl * h
	ankle = hip + dv * d
	_apply(yaw_local, pitch, extension)
	return d / (la + lb)


func _apply(yaw_local: float, pitch: float, extension: float) -> void:
	var sx := float(side) if mirrored_mesh else 1.0
	upper.position = hip
	upper.transform.basis = Basis(_arc(DOWN, (knee - hip).normalized())) * Basis.from_scale(Vector3(sx, extension, 1))
	lower.position = knee
	lower.transform.basis = Basis(_arc(DOWN, (ankle - knee).normalized())) * Basis.from_scale(Vector3(sx, extension, 1))
	foot.position = Vector3(ankle.x, ankle.y - width * .6, ankle.z)
	var y := yaw_local + side * .18
	foot.transform.basis = Basis(Vector3(0, 1, 0), y) * Basis(Vector3(1, 0, 0), pitch) * Basis.from_scale(Vector3(sx, 1, 1))


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	# THREE.Quaternion.setFromUnitVectors
	var r := from.dot(to) + 1.0
	var q: Quaternion
	if r < 1e-6:
		if abs(from.x) > abs(from.z):
			q = Quaternion(-from.y, from.x, 0, 0)
		else:
			q = Quaternion(0, -from.z, from.y, 0)
	else:
		var c := from.cross(to)
		q = Quaternion(c.x, c.y, c.z, r)
	return q.normalized()
