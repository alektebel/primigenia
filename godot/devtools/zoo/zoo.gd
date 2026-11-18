extends Node3D
## Locomotion zoo (docs/godot/DEVTOOLS.md "Locomotion zoo"): several creatures with different morphologies run the same
## scripted course side by side on a synthetic test field (ramps of 10..50 degrees, steps, slalom, U-turn lane, figure-8).
## Every creature has its own C world (CporeWorld) on the same field and the same orders, so what you see is the real
## steering and slope rules (core/src/steer.c), not an animation. The orders come from zoo_course.gd steps, fed like the
## console's `order`, so a run is deterministic.
##
## Console: zoo [morph,morph,...|all] [figure8|zigzag|steps|uturn|ramps|all] / zoo exit. Keys: Space pause, +/- speed,
## 1-9 follow a creature, 0 or F all, Esc exit, drag / wheel to orbit and zoom.

const StageWorld := preload("res://game/stage/stage_world.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")
const Profile := preload("res://game/stage/profile.gd")
const EnvFactory := preload("res://game/island/environment.gd")
const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")
const Course := preload("res://devtools/zoo/zoo_course.gd")

var morph_ids: Array = []
var course_name := "all"
var repeat := true
var auto_build := true           # tests build by hand
var with_visuals := true         # tests turn the meshes and the rigs off
var runners: Array = []
var camera: Camera3D
var hud: Label
var follow := -1                 # runner index the camera follows, -1 = the pack
var paused := false
var timescale := 1.0
var cam_yaw := 0.0
var cam_pitch := 0.55
var cam_dist := 95.0
var _target := Vector3.ZERO
var _drag := false
var _clock := 0.0

func _ready() -> void:
	if not auto_build:
		return
	var args: Dictionary = Game.zoo_args if "zoo_args" in Game else {}
	if args.is_empty():
		args = parse_args(OS.get_cmdline_user_args())
	morph_ids = args.get("morphs", Genomes.DEFAULT_SET)
	course_name = args.get("course", "all")
	repeat = bool(args.get("repeat", true))
	build()

# "--zoo=mite,giant --course=uturn" after "--".
static func parse_args(user_args: PackedStringArray) -> Dictionary:
	var out := {}
	for a in user_args:
		if a.begins_with("--zoo="):
			out.morphs = Array(a.substr(6).split(",", false))
		elif a.begins_with("--course="):
			out.course = a.substr(9)
	return out

func build() -> void:
	morph_ids = morph_ids.filter(func(m): return Genomes.has(str(m))).slice(0, 8)
	if morph_ids.is_empty():
		morph_ids = Genomes.DEFAULT_SET.duplicate()
	var count := morph_ids.size()
	var manifest := Profile.load_json("res://game/data/parts.json")
	var entry := Course.field_entry(count)
	if with_visuals:
		_build_scene(count, entry)
	for i in count:
		var id: String = morph_ids[i]
		var genome := Genomes.genome(id)
		var prof := Genomes.profile(id, manifest)
		var x0 := Course.lane_x(i, count)
		var sw := StageWorld.new()
		sw.name = "World_%s" % id
		sw.process_priority = -10
		if sw.world.set_field(entry) != 0:
			push_error("zoo: the field was rejected: %s" % sw.world.last_error())
			return
		var setup: Dictionary = CporeWorld.default_setup(1 + i)
		setup.terrain = 2
		setup.nest = Vector2(x0, Course.START_Z)
		setup.water = Vector3.ZERO
		setup.player = prof
		setup.player_legs = Genomes.leg_count(genome)
		setup.wild = []
		setup.obstacles = []
		var world = sw.world
		var ground := func(x: float, z: float) -> float: return world.ground(x, z)
		sw.ground_fn = ground
		sw.input_provider = func() -> Dictionary: return {}
		add_child(sw)
		var rc := sw.reset(setup)
		if rc != 0:
			push_error("zoo: the C world rejected the setup of %s (%d)" % [id, rc])
			return
		var r := {"id": id, "sw": sw, "genome": genome, "x0": x0, "legs": int(setup.player_legs), "radius_cm": int(prof.get("radius_cm", 0)),
			"steps": Course.course(course_name, x0), "si": -1, "t": 0, "laps": 0, "host": null, "label": null, "ground": ground}
		sw.after_tick = func(state: Dictionary) -> void: _on_tick(r, state)
		if with_visuals:
			var host := ActorHost.new()
			host.name = "Host_%s" % id
			add_child(host)
			host.setup(genome, 0, prof, ground)
			r.host = host
			var lab := Label3D.new()
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.no_depth_test = true
			lab.fixed_size = false
			lab.pixel_size = 0.012
			lab.font_size = 40
			lab.outline_size = 12
			lab.text = str(Genomes.INFO[id].label)
			add_child(lab)
			r.label = lab
		runners.append(r)
		_advance(r)

func _build_scene(count: int, entry: Dictionary) -> void:
	var env := WorldEnvironment.new()
	env.environment = EnvFactory.make_environment()
	add_child(env)
	var sun := EnvFactory.make_sun()
	sun.directional_shadow_max_distance = 220.0
	add_child(sun)
	var mi := MeshInstance3D.new()
	mi.mesh = _terrain_mesh(entry)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mi.material_override = mat
	add_child(mi)
	for i in count:
		for k in Course.RAMP_DEG.size():
			var lab := Label3D.new()
			lab.text = "%d deg" % int(Course.RAMP_DEG[k])
			lab.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lab.pixel_size = 0.02
			lab.font_size = 36
			lab.outline_size = 10
			lab.position = Vector3(Course.lane_x(i, count) + Course.ramp_x(k), Course.BASE_H + Course.RAMP_RISE + 1.6, Course.RAMP_Z0 + Course.ramp_len(k))
			add_child(lab)
		var gates := Course.zigzag(Course.lane_x(i, count))
		for g in gates.slice(1):
			var post := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.12
			cm.bottom_radius = 0.12
			cm.height = 1.8
			post.mesh = cm
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.95, 0.55, 0.1)
			post.material_override = pm
			post.position = Vector3(g.x, Course.height(g.x, g.z, count) + 0.9, g.z)
			add_child(post)
	camera = Camera3D.new()
	camera.fov = 48.0
	camera.near = 0.3
	camera.far = 1500.0
	add_child(camera)
	camera.current = true
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(10, 8)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	hud.add_theme_font_override("font", font)
	hud.add_theme_font_size_override("font_size", 13)
	hud.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hud.add_theme_constant_override("outline_size", 5)
	layer.add_child(hud)

# Vertex grid at the field cells, coloured by steepness: green flat, yellow, orange, red, magenta (cliff).
func _terrain_mesh(entry: Dictionary) -> ArrayMesh:
	var n: int = entry.n
	var h: PackedFloat32Array = entry.height
	var cell: float = float(entry.size_m) / float(n)
	var half: float = float(entry.size_m) * 0.5
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	var stops := [[0.0, Color(0.42, 0.55, 0.34)], [0.18, Color(0.55, 0.62, 0.32)], [0.36, Color(0.85, 0.78, 0.3)], [0.6, Color(0.9, 0.5, 0.2)],
		[0.85, Color(0.82, 0.25, 0.2)], [1.2, Color(0.7, 0.2, 0.6)]]
	for j in n:
		for i in n:
			var k := j * n + i
			var x := (float(i) + 0.5) * cell - half
			var z := (float(j) + 0.5) * cell - half
			verts[k] = Vector3(x, h[k], z)
			var hx := h[j * n + mini(i + 1, n - 1)] - h[j * n + maxi(i - 1, 0)]
			var hz := h[mini(j + 1, n - 1) * n + i] - h[maxi(j - 1, 0) * n + i]
			var g := Vector2(hx, hz).length() / (2.0 * cell)
			norms[k] = Vector3(-hx / (2.0 * cell), 1.0, -hz / (2.0 * cell)).normalized()
			var c: Color = stops[stops.size() - 1][1]
			for s in stops.size() - 1:
				if g <= stops[s + 1][0]:
					c = (stops[s][1] as Color).lerp(stops[s + 1][1], clampf((g - float(stops[s][0])) / (float(stops[s + 1][0]) - float(stops[s][0])), 0.0, 1.0))
					break
			var lane_edge := absf(fposmod(x + Course.LANE_W * 0.5, Course.LANE_W) - Course.LANE_W * 0.5)
			if lane_edge > Course.LANE_W * 0.5 - 0.25 and g < 0.18:
				c = c.darkened(0.35)
			cols[k] = c
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ---- the scripted course -------------------------------------------------------------------------
func _on_tick(r: Dictionary, state: Dictionary) -> void:
	r.t += 1
	var st: Dictionary = r.steps[r.si]
	var e: Dictionary = state.entities[0]
	var done := false
	match st.k:
		"go":
			done = Vector2(e.x - st.x, e.z - st.z).length() < float(st.r) or int(state.order.verb) != 2 or r.t > int(st.max)
		"head", "wait":
			done = r.t >= int(st.ticks)
		_:
			done = true
	if done:
		_advance(r)

func _advance(r: Dictionary) -> void:
	r.si += 1
	if r.si >= r.steps.size():
		if not repeat:
			r.si = r.steps.size() - 1
			r.steps[r.si] = Course.wait(1000000)
		else:
			r.si = 0
			r.laps += 1
	r.t = 0
	var st: Dictionary = r.steps[r.si]
	var sw = r.sw
	match st.k:
		"go":
			sw.queue_order({"verb": 2, "x": st.x, "z": st.z})
		"head":
			sw.queue_order({"verb": 3, "hx": st.hx, "hz": st.hz})
		"wait":
			sw.queue_order({"verb": 1})
		"tp":
			sw.debug_now({"op": 1, "id": 0, "x": st.x, "z": st.z})
			sw.queue_order({"verb": 1})

# Advances every world n ticks now (tests and evidence; the zoo also runs on its own in _process).
func step_ticks(n: int) -> void:
	for r in runners:
		r.sw.step_ticks(n)

# What the overlay shows for runner i, from the C state of the latest tick.
func stats(i: int) -> Dictionary:
	var r: Dictionary = runners[i]
	var e: Dictionary = r.sw.cur.entities[0]
	var v := float(e.speed)
	var w := float(e.omega)
	var turn_r := INF if absf(w) < 0.05 else v / absf(w)
	var g := float(e.grade)
	var state := "idle"
	if bool(e.sliding):
		state = "slide"
	elif int(e.pivot) != 0:
		state = "pivot"
	elif g > 0.15 and v < 0.35 and int(r.sw.cur.order.verb) != 1:
		state = "stalled (too steep)"
	elif g > 0.15 and v > 0.35:
		state = "climb"
	elif g < -0.15 and v > 0.35:
		state = "descend"
	elif absf(w) > 0.4 and v > 0.35:
		state = "turn"
	elif v > 0.35:
		state = "run"
	return {"id": r.id, "label": Genomes.INFO[r.id].label, "legs": r.legs, "radius_m": float(r.radius_cm if r.radius_cm > 0 else 60) / 100.0,
		"speed": v, "omega": w, "turn_radius": turn_r, "grade": g, "state": state, "x": float(e.x), "z": float(e.z)}

func hud_text() -> String:
	var lines := PackedStringArray()
	lines.append("LOCOMOTION ZOO  course %s  t %.0f s  x%.2f%s   [Space pause, +/- speed, 1-%d follow, 0 all, Esc exit]" % [course_name, _clock, timescale, " PAUSED" if paused else "", runners.size()])
	lines.append("%-2s %-28s %4s %5s %6s %6s %8s %7s  %s" % ["#", "creature", "legs", "r m", "v m/s", "w r/s", "turn R m", "grade", "state"])
	for i in runners.size():
		var s := stats(i)
		lines.append("%-2d %-28s %4d %5.1f %6.2f %6.2f %8s %6.0f%%  %s" % [i + 1, s.label, s.legs, s.radius_m, s.speed, s.omega,
			"-" if is_inf(s.turn_radius) else "%.1f" % s.turn_radius, s.grade * 100.0, s.state])
	return "\n".join(lines)

func _process(delta: float) -> void:
	_clock += 0.0 if paused else delta * timescale
	for r in runners:
		var sw = r.sw
		sw.paused = paused
		sw.timescale = timescale
		if r.host != null:
			var s: Dictionary = sw.sample(0)
			r.host.update(delta, s, {})
			(r.label as Label3D).position = s.pos + Vector3(0, r.host.height() + 1.4, 0)
	if camera != null:
		_update_camera(delta)
	if hud != null:
		hud.text = hud_text()

func _update_camera(delta: float) -> void:
	var want := Vector3.ZERO
	if follow >= 0 and follow < runners.size():
		want = runners[follow].sw.sample(0).pos
	else:
		for r in runners:
			want += r.sw.sample(0).pos
		want /= maxf(1.0, float(runners.size()))
	_target = want if _target == Vector3.ZERO else _target.lerp(want, 1.0 - exp(-delta * 3.0))
	var dist := cam_dist if follow < 0 else minf(cam_dist, 25.0)
	var dir := Vector3(sin(cam_yaw) * cos(cam_pitch), sin(cam_pitch), cos(cam_yaw) * cos(cam_pitch))
	var pos := _target + dir * dist
	var g: float = runners[0].ground.call(pos.x, pos.z) if not runners.is_empty() else 0.0
	pos.y = maxf(pos.y, g + 1.0)
	camera.position = pos
	camera.look_at(_target)

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = maxf(8.0, cam_dist * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = minf(400.0, cam_dist * 1.1)
		elif mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			_drag = mb.pressed
	elif ev is InputEventMouseMotion and _drag:
		var mm := ev as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.006
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.004, 0.05, 1.45)
	elif ev is InputEventKey and (ev as InputEventKey).pressed and not (ev as InputEventKey).echo:
		var k := (ev as InputEventKey).keycode
		if k == KEY_SPACE:
			paused = not paused
		elif k == KEY_EQUAL or k == KEY_KP_ADD:
			timescale = minf(8.0, timescale * 2.0)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			timescale = maxf(0.125, timescale * 0.5)
		elif k == KEY_0 or k == KEY_F:
			follow = -1
		elif k >= KEY_1 and k <= KEY_9 and k - KEY_1 < runners.size():
			follow = k - KEY_1
		elif k == KEY_ESCAPE:
			exit()

# Back to the island (or the menu when there is none).
func exit() -> void:
	if Game.data != null:
		Game.goto_island()
	else:
		Game.goto_menu()
