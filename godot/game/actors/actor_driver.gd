extends RefCounted
# Chooses how a creature node follows the C world's pose. With a real creature (g-creature) and
# g-loco it drives the G73 controller through the rig adapter: the controller gets the interpolated
# world position, heading and velocity, and the adapter writes the Creature's transform, legs and
# spine. Without loco a real creature glides in rest pose with its feet planted on the ground; the
# M0 placeholder just walks.

const UNIT := 1.0           # metres per rig unit (web/stage drew the rig at scale 1)
const LOCO_PATHS := ["res://locomotion/loco_controller.gd", "res://locomotion/loco_morphology.gd", "res://locomotion/loco_rig_adapter.gd"]


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

# s: StageWorld.sample() -> {pos, yaw, speed, vel}, optionally intent (the world yaw the player asks for)
func update(dt: float, s: Dictionary) -> void:
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
		adapter.loco_apply(body, controller.pose, desc)
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
