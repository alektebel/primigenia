class_name CreaturePreview
extends RefCounted
## Evidence-only preview stage: studio-like golden-hour light (rig.js SUN,
## warm sun, sky ambient, ACES, exposure matched to three.js) and a grass floor, rendered in
## a SubViewport. Not part of the runtime API (the stage owns real lighting).

const SUN := Vector3(-.62, .3, -.72)

var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var sun: DirectionalLight3D


func _init(tree: SceneTree, size: Vector2i) -> void:
	viewport = SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	tree.root.add_child(viewport)
	world_root = Node3D.new()
	viewport.add_child(world_root)

	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#7f9fd6")
	sky_mat.sky_horizon_color = Color(.93, .74, .56)
	sky_mat.ground_horizon_color = Color(.85, .7, .55)
	sky_mat.ground_bottom_color = Color("#5a4630")
	sky_mat.sun_angle_max = 20
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = .75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	# three.js r128 ACESFilmic divides the exposure by 0.6; Godot's ACES does not.
	# 1.4 was matched by eye against the hero reference (studio uses 1.05).
	env.tonemap_exposure = float(OS.get_environment("CREATURE_EXPOSURE")) if OS.get_environment("CREATURE_EXPOSURE") != "" else 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	world_root.add_child(we)

	sun = DirectionalLight3D.new()
	sun.light_color = Color("#ffcf9a")
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 25
	sun.shadow_bias = .03
	sun.shadow_normal_bias = .6
	world_root.add_child(sun)
	sun.look_at_from_position(SUN.normalized() * 50, Vector3.ZERO)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#3b5526")
	gm.roughness = 1
	ground.material_override = gm
	world_root.add_child(ground)

	camera = Camera3D.new()
	camera.fov = 42
	camera.near = .1
	camera.far = 500
	world_root.add_child(camera)
	camera.current = true


## studio.js frameCam(): orbit around `target` at yaw/pitch/distance.
func orbit(target: Vector3, yaw: float, pitch: float, dist: float, fov := 42.0) -> void:
	camera.fov = fov
	var aspect := float(viewport.size.x) / viewport.size.y
	var d := dist * maxf(1.0, .9 / aspect)
	var cp := cos(pitch)
	var pos := Vector3(target.x + sin(yaw) * cp * d, maxf(.3, target.y + sin(pitch) * d), target.z + cos(yaw) * cp * d)
	camera.look_at_from_position(pos, target)


## Studio framing target: the middle spine ring in world space.
static func mid_target(c: Creature) -> Vector3:
	return c.rest[Creature.NS >> 1] + Vector3(0, c.ground_offset, 0)


func capture(tree: SceneTree, frames := 3) -> Image:
	for i in frames:
		await tree.process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()
