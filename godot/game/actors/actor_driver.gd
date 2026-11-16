extends RefCounted
# Chooses how a creature node follows the C world's pose. With g-loco present it drives the G73
# controller (UNTESTED on this branch: the module lives elsewhere); with a real g-creature but no
# loco it glides in rest pose and plants feet on the ground; with the placeholder it just walks.

var host: Node3D
var body: Node3D            # placeholder or real creature
var is_placeholder := true
var controller = null
var adapter = null
var _ground: Callable

func setup(host_node: Node3D, body_node: Node3D, placeholder: bool, ground: Callable) -> void:
	host = host_node
	body = body_node
	is_placeholder = placeholder
	_ground = ground
	if not placeholder:
		_try_loco()

func _try_loco() -> void:
	var paths := ["res://locomotion/loco_controller.gd", "res://locomotion/loco_morphology.gd", "res://locomotion/loco_rig_adapter.gd"]
	for p in paths:
		if not ResourceLoader.exists(p):
			return
	var ctl_script = load(paths[0])
	var morph_script = load(paths[1])
	var adapter_script = load(paths[2])
	if ctl_script == null or morph_script == null or adapter_script == null:
		return
	adapter = adapter_script
	if adapter.has_method("loco_describe") and morph_script.has_method("analyse"):
		controller = ctl_script.new(morph_script.analyse(adapter.loco_describe(body)), _ground)

# s: StageWorld.sample() -> {pos, yaw, speed, vel}
func update(dt: float, s: Dictionary) -> void:
	host.position = s.pos
	host.basis = Basis(Vector3.UP, s.yaw)
	if is_placeholder:
		if body.has_method("animate"):
			body.animate(dt, s.speed)
		return
	if controller != null and adapter != null:
		controller.step(dt, s.pos, s.yaw, s.vel)
		adapter.loco_apply(body, controller.pose)
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
