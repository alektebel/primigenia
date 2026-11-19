extends RefCounted
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
	_try_actions()

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

func _on_action_event(ev: String, data: Dictionary) -> void:
	if ev == "cry" and data.get("id", "") == "roar" and layer != null and host.is_inside_tree() and map != null:
		_fx_script.roar_ring(host.get_parent(), host.global_position, 1.6 * map.height + 0.8)
		return
	if ev == "spit_release" and layer != null and host.is_inside_tree():
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

# s: StageWorld.sample() -> {pos, yaw, speed, vel}, optionally intent (the world yaw the player asks for)
# ctx (optional): what the action layer reads, see actions/action_layer.gd
func update(dt: float, s: Dictionary, ctx: Dictionary = {}) -> void:
	host.position = s.pos
	host.basis = Basis(Vector3.UP, s.yaw)
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
		elif layer != null and _acting_before:
			_rig_script.reset(body)
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
