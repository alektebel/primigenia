extends RefCounted

const FrameProfile := preload("res://devtools/frame_profile.gd")
# Chooses how a creature node follows the C world's pose. With a real creature (g-creature) and
# g-loco it drives the G73 controller through the rig adapter: the controller gets the interpolated
# world position, heading and velocity, and the adapter writes the Creature's transform, legs and
# spine. Without loco a real creature glides in rest pose with its feet planted on the ground; the
# M0 placeholder just walks.

const UNIT := 1.0           # metres per rig unit (web/stage drew the rig at scale 1)
const ACTION_PATHS := ["res://actions/action_layer.gd", "res://actions/action_body_map.gd", "res://actions/action_data.gd", "res://actions/action_rig.gd", "res://actions/action_fx.gd"]
const LOCO_PATHS := ["res://locomotion/loco_controller.gd", "res://locomotion/loco_morphology.gd", "res://locomotion/loco_rig_adapter.gd"]
const RADIAL_PATH := "res://locomotion/loco_radial.gd"


signal footfall(leg: int, position: Vector3)

var host: Node3D
var body: Node3D            # placeholder or real creature
var is_placeholder := true
var controller = null
var adapter = null
var desc: Dictionary = {}
var problems: Array = []    # contract problems reported by loco_describe
var _ground: Callable
var _started := false
## Procedural action animation (godot/actions). Off = the pure locomotion pose; the world is never affected either way.
var actions_enabled := true
var layer = null
var map = null
var _rig_script = null
var _fx_script = null
var _acting_before := false
static var _raw_actions: Dictionary = {}

func setup(host_node: Node3D, body_node: Node3D, placeholder: bool, ground: Callable) -> void:
	host = host_node
	body = body_node
	is_placeholder = placeholder
	_ground = ground
	if not placeholder:
		_try_loco()

func _try_loco() -> void:
	for p in LOCO_PATHS:
		if not ResourceLoader.exists(p):
			return
	if not (body.has_method("reset_spine_pose") and "rest" in body and "legs" in body):
		return          # not the real rig (a fake module in tests)
	if "plan_kind" in body and body.plan_kind == "radial":
		_try_radial()   # no fixed front: the arms are the locomotors (the action layer has no radial map yet)
		return
	var ctl_script = load(LOCO_PATHS[0])
	var morph_script = load(LOCO_PATHS[1])
	adapter = load(LOCO_PATHS[2])
	if ctl_script == null or morph_script == null or adapter == null:
		adapter = null
		return
	desc = adapter.loco_describe(body, UNIT)
	problems = desc.problems
	if not problems.is_empty():
		push_warning("loco rig contract: %s" % [problems])
	controller = ctl_script.new(morph_script.analyse(desc), _ground)
	controller.footfall.connect(func(leg: int, pos: Vector3) -> void: footfall.emit(leg, pos))
	controller.push_off.connect(_dust_kick)
	_try_actions()

## A54: a small dust kick where a hind foot pushes off in a run burst (strength 0..1). Visual only; a short one-shot puff in the world.
func _dust_kick(pos: Vector3, strength: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3(0, 1, 0)
	p.spread = 55.0
	p.initial_velocity_min = 0.4 + 0.6 * strength
	p.initial_velocity_max = 1.0 + 1.0 * strength
	p.gravity = Vector3(0, -2.5, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(0.62, 0.55, 0.42, 0.55), Color(0.62, 0.55, 0.42, 0.0)])
	p.color_ramp = g
	host.get_parent().add_child(p)
	p.global_position = pos + Vector3(0, 0.03, 0)
	p.emitting = true
	host.get_tree().create_timer(1.0).timeout.connect(p.queue_free)

func _try_radial() -> void:
	adapter = load(LOCO_PATHS[2])
	desc = adapter.radial_describe(body, UNIT)
	problems = desc.problems
	controller = load(RADIAL_PATH).new(desc, _ground)
	controller.footfall.connect(func(arm: int, pos: Vector3) -> void: footfall.emit(arm, pos))

func _try_actions() -> void:
	for p in ACTION_PATHS:
		if not ResourceLoader.exists(p):
			return
	var data = load(ACTION_PATHS[2])
	if _raw_actions.is_empty():
		_raw_actions = data.load_all("res://actions/data")
	if _raw_actions.is_empty():
		return
	map = load(ACTION_PATHS[1]).from_rig(body, desc, controller.morph)
	layer = load(ACTION_PATHS[0]).new()
	layer.setup(map, _raw_actions, body, host.entity_id if "entity_id" in host else 0)
	_rig_script = load(ACTION_PATHS[3])
	_fx_script = load(ACTION_PATHS[4])
	layer.action_event.connect(_on_action_event)

const _flame_script := preload("res://game/actors/flame_fx.gd")
const _impact_script := preload("res://actions/impact_fx.gd")

func _on_action_event(ev: String, data: Dictionary) -> void:
	if ev == "hit_fx" and host != null and host.is_inside_tree():
		# A64: the shared melee contact: dust and sparks here, the camera shake and the like on the island
		var parent := host.get_parent()
		_impact_script.contact(parent, data)
		if parent != null and parent.has_method("melee_impact"):
			parent.melee_impact(data)
		return
	if ev == "drive" and layer != null and host != null and host.is_inside_tree() and map != null:
		# the lunge pushes off: dust from the hind feet
		var back := -Vector3(sin(host.rotation.y), 0.0, cos(host.rotation.y))
		_dust_kick(host.global_position + back * 0.25 * map.height, 0.8)
		return
	if ev == "cry" and str(data.get("id", "")).begins_with("roar") and layer != null and host.is_inside_tree() and map != null:
		# A74: the C roar's fear radius is 4 m, the ring and the dust show it; the cosmetic roar keeps its body-size ring
		var c_roar := str(data.get("id", "")) != "roar"
		_fx_script.roar_ring(host.get_parent(), host.global_position, 4.0 if c_roar else 1.6 * map.height + 0.8)
		if c_roar:
			_dust_kick(host.global_position, 1.2)
		return
	if ev == "projectile" and host != null and host.is_inside_tree():
		var flight := maxf(0.05, float(data.get("ticks", 5)) * 0.1)
		_fx_script.shot(host.get_parent(), data.get("from", host.global_position), data.to, flight, float(data.get("size", 1.0)) * 0.5, int(data.get("kind", 0)))
		return
	if ev == "acid_hit" and host != null and host.is_inside_tree():
		var kind := int(data.get("kind", 0))
		_fx_script.acid_sizzle(host.get_parent(), data.pos, float(data.get("victim_size", 1.0)), kind == 1 or kind == 3)
		if kind == 1 or kind == 3:
			var p: Vector3 = data.pos
			p.y = host.global_position.y
			_fx_script.acid_puddle(host.get_parent(), p, 0.5 + 0.35 * float(data.get("victim_size", 1.0)))
		return
	if ev == "flame_start" and layer != null and host.is_inside_tree():
		var mouth: Vector3 = layer._mouth_world
		var fwd := Vector3(sin(host.rotation.y), 0.0, cos(host.rotation.y))
		var tgt: Dictionary = layer._ctx.get("target", {})
		if not tgt.is_empty() and tgt.has("pos"):
			var to: Vector3 = (tgt.pos as Vector3) - host.global_position
			to.y = 0.0
			if to.length() > 0.05:
				fwd = to.normalized()
		_flame_script.flame_cone(host.get_parent(), mouth, fwd, 0.6)
		return
	if ev == "spit_release" and layer != null and host.is_inside_tree():
		if int(layer._ctx.get("sig", {}).get("ctx", 0)) != 0:
			return          # A69: a context spit is a C projectile; its blob leaves with the C `projectile` event and lands with the damage
		var from: Vector3 = layer._mouth_world
		var tgt: Dictionary = layer._ctx.get("target", {})
		if tgt.is_empty():
			return
		var to: Variant = layer._goal_point("target_surface", controller.pose)
		if to == null:
			return
		var act: Dictionary = layer.actions.get("spit", {})
		var flight := maxf(0.05, (float(act.get("w", 6.0)) - float(data.get("tau", 0.0))) * 0.1)
		_fx_script.spit_blob(host.get_parent(), from, to, flight, map.height * 0.5 if map != null else 1.0)

## After a flight the controller starts from where the creature landed (its feet were never on the ground in between).
func rebase() -> void:
	_started = false

# Flying (flight test): the controller is not stepped (its feet would plant on the ground far below). The last ground pose is
# re-rooted on the flyer's attitude and the legs are tucked under the body; the wings are written by the flight mode.
func _update_flight(_dt: float, s: Dictionary) -> void:
	var f: Dictionary = s.flight
	var r: Basis = f.basis
	var tuck: float = float(f.get("legs_tuck", 1.0))
	var fwd: float = float(f.get("legs_fwd", 0.0))
	var com_local: Vector3 = controller.morph.com
	var pose: Dictionary = controller.pose.duplicate()
	if pose.is_empty():
		return
	var root := Transform3D(r, (f.com as Vector3) - r * com_local)
	pose["root"] = root
	var feet: Array = []
	var contact: Array = []
	var swing: Array = []
	var hips: PackedVector3Array = PackedVector3Array()
	for j in desc.legs.size():
		var leg: Dictionary = desc.legs[j]
		var reach: float = float(leg.upper) + float(leg.lower)
		var hip: Vector3 = root * (leg.hip as Vector3)
		hips.append(hip)
		# tucked in cruise: knees up, feet under the belly; extended for the landing and, in a flare, swung forward
		feet.append(hip + r * Vector3(0.0, lerpf(-0.95, -0.4, tuck) * reach, lerpf(0.0, -0.28, tuck) * reach + 0.45 * fwd * reach))
		contact.append(false)
		swing.append(0.5)
	pose["feet"] = feet
	pose["contact"] = contact
	pose["swing_u"] = swing
	pose["hips"] = hips
	adapter.loco_apply(body, pose, desc)
	_bank_pose(f)
	_acting_before = false

# Presentation of a banked turn on the spine: the neck rolls back against the body (gaze stabilisation: the head stays on the horizon),
# the tail twists into the turn and fans (wider). loco_apply rewrote every bone this frame, so these are deltas on top of it.
const TAIL_TWIST := 0.35        # share of the body roll the tail tip adds, into the turn
const TAIL_FAN := 0.35          # tail width gain at the sharpest bank
func _bank_pose(f: Dictionary) -> void:
	var sk = body.skeleton
	if sk == null:
		return
	var bank: float = float(f.bank)
	var roll := -atan(bank)                                   # the body's roll about its forward axis (+ = left wing up)
	var stab: float = 1.0 - float(f.get("head_roll", 0.0)) / roll if absf(roll) > 1e-4 else 0.0
	var nn: int = body.neck_bones.size()
	for a in nn:
		var b: int = body.neck_bones[a]
		sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * Quaternion(Vector3.BACK, -roll * stab / float(nn)))
	var tn: int = body.tail_bones.size()
	var amount := clampf(bank / 1.7320508, -1.0, 1.0)
	for a in tn:
		var b2: int = body.tail_bones[a]
		var k := 1.0 - float(a) / float(maxi(tn, 1))          # tip first
		sk.set_bone_pose_rotation(b2, sk.get_bone_pose_rotation(b2) * Quaternion(Vector3.BACK, roll * TAIL_TWIST * k / float(maxi(tn, 1)) * 2.0))
		sk.set_bone_pose_scale(b2, (sk.get_bone_rest(b2) as Transform3D).basis.get_scale() * Vector3(1.0 + TAIL_FAN * absf(amount) * k, 1.0, 1.0))

# The slide / tumble while C has the player airborne or sliding (player.falling): the body leans back, feet downhill, and
# rolls a little, eased in and out so the landing settles. Presentation only.
const FALL_LEAN := 0.5          # rad, backwards
const FALL_ROLL := 0.28         # rad, side to side
var _fall_k := 0.0
var _fall_t := 0.0
func _fall_pose(dt: float, falling: bool) -> Basis:
	_fall_k = move_toward(_fall_k, 1.0 if falling else 0.0, dt / (0.18 if falling else 0.35))
	if _fall_k <= 0.0:
		_fall_t = 0.0
		return Basis.IDENTITY
	_fall_t += dt
	var lean := -FALL_LEAN * _fall_k + sin(_fall_t * 7.0) * 0.07 * _fall_k
	var roll := sin(_fall_t * 3.3) * FALL_ROLL * _fall_k
	return Basis(Vector3.BACK, roll) * Basis(Vector3.RIGHT, lean)

var _eat_squash := 0.0
## Fallback of the meal for a body with no action layer: a quick dip-and-rebound of the body on each bite (decays in update).
func eat_pulse() -> void:
	_eat_squash = 1.0

func _eat_fallback(dt: float) -> void:
	if layer != null or body == null or not (body is Node3D):
		return
	var was := _eat_squash > 0.0
	_eat_squash = maxf(0.0, _eat_squash - dt * 4.0)
	if was or _eat_squash > 0.0:
		var k := _eat_squash * _eat_squash
		(body as Node3D).scale = Vector3(1.0 + 0.06 * k, 1.0 - 0.10 * k, 1.0 + 0.06 * k)

# s: StageWorld.sample() -> {pos, yaw, speed, vel}, optionally intent (the world yaw the player asks for)
# ctx (optional): what the action layer reads, see actions/action_layer.gd
func update(dt: float, s: Dictionary, ctx: Dictionary = {}) -> void:
	if not FrameProfile.enabled:
		_profile_update(dt, s, ctx)
		return
	FrameProfile.begin()
	_profile_update(dt, s, ctx)
	FrameProfile.end(&"actor driver/actions")

func _profile_update(dt: float, s: Dictionary, ctx: Dictionary = {}) -> void:
	host.position = s.pos
	host.basis = Basis(Vector3.UP, s.yaw) * _fall_pose(dt, bool(s.get("falling", false)))
	_eat_fallback(dt)
	if s.has("flight") and controller != null and adapter != null:
		_update_flight(dt, s)
		return
	if is_placeholder:
		if body.has_method("animate"):
			body.animate(dt, s.speed)
		return
	if controller != null and adapter != null:
		if not _started:
			controller.reset(s.pos, s.yaw)
			_started = true
		controller.set_intent(s.get("intent", null))
		controller.step(dt, s.pos, s.yaw, s.vel)
		var acting: bool = actions_enabled and layer != null and int(ctx.get("lod", 0)) < 2
		if acting:
			var c2: Dictionary = ctx.duplicate()
			c2["pos"] = s.pos
			c2["yaw"] = s.yaw
			c2["speed"] = s.speed
			c2["vel"] = s.vel
			layer.light = int(ctx.get("lod", 0)) >= 1
			layer.update(dt, c2)
			layer.apply(controller.pose, dt)
		adapter.loco_apply(body, controller.pose, desc)
		if acting:
			_rig_script.apply_parts(body, controller.pose.act)
			_impact_script.apply_flash(body, layer.flash)
		elif layer != null and _acting_before:
			_rig_script.reset(body)
			_impact_script.apply_flash(body, 0.0)
		_acting_before = acting
		return
	# Rest-pose glide: plant each foot under its rest sole and solve the legs.
	if body.has_method("pose_legs_rest"):
		body.pose_legs_rest()
	if "legs" in body and body.has_method("solve_legs"):
		for leg in body.legs:
			if "home" in leg:
				var g: Vector3 = host.to_global(leg.home)
				g.y = _ground.call(g.x, g.z)
				leg.foot_target = g
		body.solve_legs()
