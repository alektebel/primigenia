extends Node3D
## A73: "hatch from a new egg". After the nest editor applied a change (Evolve or a free repaint) the world reloads the new body; this
## short cinematic plays at the nest: the camera frames the spot, an egg sits there, wobbles, cracks (shell pieces, a few chips), the
## new creature stands up out of it (curled to standing, a small shake-off) and control returns. About 3.6 s; any key or click skips.
##
## Determinism: purely visual. The C state change (nest_edit / nest_apply) already happened exactly as before. The sim does not run
## while this plays: `stage.paused` stays true (the same pause the editor used), and the owner of this node releases it on `finished`.
## No random numbers from the sim: the shell pieces use a private RNG with a fixed seed.

signal finished

const DURATION := 3.6
const T_FRAME := 0.55          # camera arrives
const T_WOBBLE := 0.45         # egg starts to rock
const T_CRACK := 1.55          # cracks show and the egg shakes
const T_BURST := 2.15          # shell flies, the creature appears
const T_STAND := 0.75          # curled to standing
const T_SHAKE := 2.8           # shake-off starts
const T_BACK := 3.2            # camera eases back to the chase pose

var island: Node3D
var host: Node3D
var camera: Camera3D
var t := 0.0
var done := false
var skipped := false

var _egg: Node3D
var _egg_mesh: MeshInstance3D
var _egg_mat: StandardMaterial3D
var _cracks: Array = []
var _bowl: MeshInstance3D
var _pieces: Array = []          # {node, vel, spin, rest_y}
var _chips: CPUParticles3D
var _burst: CPUParticles3D
var _base: Vector3
var _egg_h := 0.8
var _cam_from: Transform3D
var _cam_fov := 48.0
var _focus: Vector3
var _dir := Vector3(0, 0, 1)
var _dist := 4.0
var _chase_was := true
var _burst_done := false
var _hint: Label
var _rng := RandomNumberGenerator.new()

## `force` plays it even headless (tests); otherwise a headless run skips straight to `finished`.
func start(isl: Node3D, force := false) -> void:
	island = isl
	host = isl.hosts.get(0)
	camera = isl.camera
	if host == null or camera == null or (DisplayServer.get_name() == "headless" and not force):
		_finish.call_deferred()
		return
	_rng.seed = 73
	_base = host.global_position
	_base.y = Game.visual_ground(_base.x, _base.z) if Game.data != null else _base.y
	_egg_h = clampf(host.height() * 0.8, 0.45, 1.7)
	_cam_from = camera.global_transform
	_cam_fov = camera.fov
	_focus = _base + Vector3.UP * _egg_h * 0.55
	var away := Vector3(_cam_from.origin.x - _focus.x, 0.0, _cam_from.origin.z - _focus.z)
	_dir = away.normalized() if away.length() > 0.01 else Vector3(0, 0, 1)
	_dist = clampf(maxf(_egg_h, host.height()) * 3.3, 2.8, 10.0)
	_chase_was = island.chase_enabled
	island.chase_enabled = false
	island.add_child(self)
	_build_egg()
	_build_hint()

func _build_egg() -> void:
	_egg = Node3D.new()
	_egg.name = "Egg"
	add_child(_egg)
	_egg.global_position = _base
	var r := _egg_h * 0.36
	_egg_mat = StandardMaterial3D.new()
	_egg_mat.albedo_color = Color(0.82, 0.76, 0.62)
	_egg_mat.roughness = 0.72
	_egg_mat.emission_enabled = true
	_egg_mat.emission = Color(1.0, 0.72, 0.3)
	_egg_mat.emission_energy_multiplier = 0.0
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = _egg_h
	sm.radial_segments = 24
	sm.rings = 14
	_egg_mesh = MeshInstance3D.new()
	_egg_mesh.mesh = sm
	_egg_mesh.material_override = _egg_mat
	_egg_mesh.position = Vector3(0, _egg_h * 0.5, 0)       # rests on the ground, rocks about its foot
	_egg.add_child(_egg_mesh)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.15, 0.08)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 3:                       # crack lines on the side facing the camera, shown one after another
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, _egg_h * (0.16 + 0.05 * i), 0.012)
		var m := MeshInstance3D.new()
		m.mesh = bm
		m.material_override = dark
		var side := (i - 1) * r * 0.42
		var up := _egg_h * (0.52 + 0.08 * i)
		var out := _dir * (r * (0.93 if i != 1 else 0.99))
		var tang := _dir.cross(Vector3.UP).normalized() * side
		m.position = Vector3(0, up, 0) + out + tang
		m.basis = Basis(_dir, (i - 1) * 0.55)
		m.visible = false
		_egg.add_child(m)
		_cracks.append(m)
	_chips = _particles(10, 0.55, 1.4, 0.03 * _egg_h + 0.012, Color(0.93, 0.89, 0.78))
	_chips.position = Vector3(0, _egg_h * 0.7, 0)
	_egg.add_child(_chips)
	_burst = _particles(34, 0.9, 3.2, 0.035 * _egg_h + 0.015, Color(0.82, 0.76, 0.62))
	_burst.position = Vector3(0, _egg_h * 0.4, 0)
	_egg.add_child(_burst)

func _particles(n: int, life: float, speed: float, size: float, col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.9
	m.material = mat
	p.mesh = m
	return p

func _build_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	_hint = Label.new()
	_hint.text = "Pulsa una tecla para saltar" if str(Game.settings.get("language", "es")) == "es" else "Press any key to skip"
	_hint.add_theme_font_size_override("font_size", 15)
	_hint.add_theme_color_override("font_color", Color(0.93, 0.89, 0.78, 0.7))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -26
	layer.add_child(_hint)

func _input(e: InputEvent) -> void:
	if done:
		return
	if (e is InputEventKey and e.pressed and not e.echo) or (e is InputEventMouseButton and e.pressed):
		skipped = true
		get_viewport().set_input_as_handled()
		_finish()

func _process(dt: float) -> void:
	if done:
		return
	t += dt
	_camera(t)
	_egg_step(t)
	if t >= T_BURST and not _burst_done:
		_do_burst()
	_pieces_step(dt)
	_creature_step(t)
	if _hint != null:
		_hint.modulate.a = clampf(1.0 - (t - 2.6) / 0.4, 0.0, 1.0) * clampf(t / 0.4, 0.0, 1.0)
	if t >= DURATION:
		_finish()

static func _out(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return 1.0 - pow(1.0 - x, 3.0)

func _camera(tt: float) -> void:
	var look := _focus
	var pos := _focus + _dir * _dist + Vector3.UP * _dist * 0.16
	var target := Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	var k := _out(tt / T_FRAME)
	var back := _out((tt - T_BACK) / (DURATION - T_BACK))
	var shake := Vector3.ZERO
	if tt > T_CRACK and tt < T_BURST + 0.35:        # a small knock at the burst: a decaying sine, no random numbers
		var a: float = 0.02 * _egg_h * (1.0 if tt < T_BURST else (1.0 - (tt - T_BURST) / 0.35))
		shake = Vector3(sin(tt * 61.0), cos(tt * 47.0), 0.0) * a
	var cur := _cam_from.interpolate_with(target, k)
	cur.origin += cur.basis * shake
	if back > 0.0:
		cur = cur.interpolate_with(_cam_from, back)
	camera.global_transform = cur

func _egg_step(tt: float) -> void:
	if _burst_done:
		return
	var w := 0.0
	if tt >= T_WOBBLE:
		var u := (tt - T_WOBBLE) / (T_CRACK - T_WOBBLE)
		var amp := 0.05 + 0.12 * clampf(u, 0.0, 1.0)
		# rock, rock, pause: two beats then a rest (period 0.62 s)
		var ph := fmod(tt - T_WOBBLE, 0.62) / 0.62
		w = amp * sin(ph * TAU * 2.0) * (1.0 - smoothstep(0.55, 0.85, ph))
	if tt >= T_CRACK:
		w = 0.16 * sin(tt * 52.0) * (0.6 + 0.4 * sin(tt * 9.0))
		_egg_mat.emission_energy_multiplier = clampf((tt - T_CRACK) / (T_BURST - T_CRACK), 0.0, 1.0) * 1.1
	_egg.basis = Basis(_dir, w)      # roll about the axis towards the camera: it rocks left and right on screen
	for i in _cracks.size():
		_cracks[i].visible = tt >= T_CRACK - 0.35 + i * 0.16
	if tt >= T_CRACK - 0.05 and not _chips.emitting and _chips.one_shot and not _chips.has_meta("fired"):
		_chips.set_meta("fired", true)
		_chips.restart()
		_chips.emitting = true

func _do_burst() -> void:
	_burst_done = true
	_egg_mesh.visible = false
	for c in _cracks:
		c.visible = false
	_egg.basis = Basis()
	# what stays: the lower part of the shell
	var bm := SphereMesh.new()
	bm.radius = _egg_h * 0.36
	bm.height = _egg_h * 0.72
	bm.is_hemisphere = true
	bm.radial_segments = 20
	bm.rings = 8
	_bowl = MeshInstance3D.new()
	_bowl.mesh = bm
	_bowl.material_override = _egg_mat
	_bowl.rotation = Vector3(PI, 0, 0)
	_bowl.scale = Vector3(1.0, 0.42, 1.0)
	_bowl.position = Vector3(0, _egg_h * 0.16, 0)
	_egg.add_child(_bowl)
	_egg_mat.emission_energy_multiplier = 0.0
	for i in 9:
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		var rr := _egg_h * _rng.randf_range(0.07, 0.16)
		s.radius = rr
		s.height = rr * 2.0
		s.is_hemisphere = true
		s.radial_segments = 8
		s.rings = 4
		m.mesh = s
		m.material_override = _egg_mat
		m.scale = Vector3(1.0, 0.45, 1.0)
		var a := TAU * (i + _rng.randf_range(-0.3, 0.3)) / 9.0
		m.position = _base + Vector3(cos(a), 0, sin(a)) * _egg_h * 0.14 + Vector3.UP * _egg_h * _rng.randf_range(0.5, 0.9)
		m.rotation = Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)
		add_child(m)
		var v := Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.8, 1.9) * (0.6 + _egg_h) + Vector3.UP * _rng.randf_range(2.0, 3.6)
		_pieces.append({"node": m, "vel": v, "spin": Vector3(_rng.randf_range(-9, 9), _rng.randf_range(-9, 9), _rng.randf_range(-9, 9)), "rest": rr * 0.25, "live": true})
	_burst.restart()
	_burst.emitting = true

func _pieces_step(dt: float) -> void:
	for p in _pieces:
		if not p.live:
			continue
		var n: Node3D = p.node
		p.vel.y -= 9.0 * dt
		n.position += p.vel * dt
		n.rotate_x(p.spin.x * dt)
		n.rotate_z(p.spin.z * dt)
		var gy: float = Game.visual_ground(n.position.x, n.position.z) if Game.data != null else _base.y
		if n.position.y <= gy + p.rest:
			n.position.y = gy + p.rest
			p.live = false

func _creature_step(tt: float) -> void:
	if host == null or not is_instance_valid(host):
		return
	if tt < T_BURST:
		host.visible = false          # the island's zoom budget sets it every frame; this node runs after it
		return
	host.visible = true
	var u := _out((tt - T_BURST) / T_STAND)
	# curled: shorter and a little wider, standing up with the ease-out; never from zero
	var sc := Vector3(lerpf(1.1, 1.0, u), lerpf(0.62, 1.0, u), lerpf(1.1, 1.0, u))
	host.scale = sc
	if tt >= T_SHAKE:
		var s := (tt - T_SHAKE) / (T_BACK - T_SHAKE + 0.3)
		var decay := clampf(1.0 - s, 0.0, 1.0)
		host.rotate_y(sin((tt - T_SHAKE) * 34.0) * 0.16 * decay * decay)
		host.rotate_object_local(Vector3(0, 0, 1), sin((tt - T_SHAKE) * 29.0) * 0.05 * decay)

func _finish() -> void:
	if done:
		return
	done = true
	if host != null and is_instance_valid(host):
		host.visible = true
		host.scale = Vector3.ONE
	if island != null and is_instance_valid(island):
		island.chase_enabled = _chase_was
	if camera != null and is_instance_valid(camera) and not _cam_from.origin.is_zero_approx():
		camera.global_transform = _cam_from
		camera.fov = _cam_fov
	finished.emit()
	queue_free()
