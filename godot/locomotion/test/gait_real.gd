extends SceneTree
## Run-gait evidence on the REAL creature rig (software GL, needs a display):
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --path godot --rendering-driver opengl3 \
##     --script locomotion/test/gait_real.gd -- [morph=hero] [out=<dir>] [mode=sheet|measure]
## sheet: one contact sheet per morphology, one row per gait, 8 frames over one stride, side view.
## measure: prints per-gait cadence, stride, speed check, planted-foot slide and body-bob stats (no rendering needed).

const Morph := preload("res://locomotion/loco_morphology.gd")
const Ctl := preload("res://locomotion/loco_controller.gd")
const Gait := preload("res://locomotion/loco_gait.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const Genomes := preload("res://devtools/zoo/zoo_genomes.gd")

const CELL := Vector2i(360, 220)
const FRAMES := 8
const MORPHS := ["hero", "mite", "giant", "hexapod", "centipede", "trotter"]

var out_dir := ""
var only := ""
var mode := "sheet"

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/evidence/godot/run-gait")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("morph="): only = a.substr(6)
		elif a.begins_with("out="): out_dir = a.substr(4)
		elif a.begins_with("mode="): mode = a.substr(5)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()

static func genome_for(id: String) -> Dictionary:
	if id == "hero":
		return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/merodeador.json"))
	return Genomes.genome(id)

## Froude numbers worth showing: one per gait of the ladder, from the slowest gait up to the last gait's mid range.
static func shots(morph) -> Array:
	var out := _shots(morph)
	var cap: float = 3.0 if morph.graviportal else 1e9
	for o in out:
		o[1] = minf(float(o[1]), cap)
	return out

static func _shots(morph) -> Array:
	var lad: Array = Gait.ladder(morph)
	if lad.is_empty():
		return [["walk", 0.1], ["fast", 1.0], ["fastest", 3.0]]
	var out: Array = [[str(lad[0][0]), 0.15]]
	for k in lad.size():
		var lo: float = lad[k][2]
		var hi: float = lad[k + 1][2] if k + 1 < lad.size() else lad[k][2] * 3.0
		out.append([str(lad[k][1]), sqrt(lo * hi) if k + 1 < lad.size() else lo * 2.2])
		if k + 1 == lad.size():
			out.append([str(lad[k][1]) + " fast", lad[k][2] * 5.0])
	return out

class Scene extends Node3D:
	var c
	var desc: Dictionary
	var ctl
	var cam: Camera3D
	var pos := Vector3.ZERO
	var morph
	func build(g: Dictionary) -> bool:
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.72, 0.82, 0.9)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.75, 0.8, 0.9)
		e.ambient_light_energy = 0.7
		env.environment = e
		add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50.0, -140.0, 0.0)
		sun.light_energy = 1.1
		add_child(sun)
		c = Creature.new()
		add_child(c)
		if not c.load_genome(g).ok:
			return false
		desc = Adapter.loco_describe(c, 1.0)
		morph = Morph.analyse(desc)
		ctl = Ctl.new(morph, func(_x, _z): return -c.ground_offset)
		ctl.reset(Vector3(0, -c.ground_offset, 0), 0.0)
		# striped ground with 1 m markers, so the speed shows
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for iz in range(-30, 400):
			var col := Color(0.42, 0.55, 0.36) if iz % 2 == 0 else Color(0.5, 0.63, 0.42)
			var z0 := iz * 0.5
			for t in [[-6, z0], [6, z0], [6, z0 + 0.5], [-6, z0], [6, z0 + 0.5], [-6, z0 + 0.5]]:
				st.set_color(col)
				st.add_vertex(Vector3(t[0], -c.ground_offset, t[1]))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m
		add_child(mi)
		cam = Camera3D.new()
		add_child(cam)
		cam.current = true
		return true
	func advance(dt: float, speed: float) -> void:
		var vel := Vector3(0, 0, speed)
		pos += vel * dt
		var p := Vector3(pos.x, -c.ground_offset, pos.z)
		ctl.step(dt, p, 0.0, vel)
		Adapter.loco_apply(c, ctl.pose, desc)
		var d: float = max(morph.body_length * 1.5, morph.hip_height * 2.6)
		cam.position = Vector3(d, morph.hip_height * 0.55, pos.z)
		cam.look_at(Vector3(0, morph.hip_height * 0.6, pos.z), Vector3.UP)
		cam.fov = 40.0

func _run() -> void:
	root.size = CELL
	await process_frame
	for id in MORPHS:
		if only != "" and only != id:
			continue
		if mode == "measure":
			_measure(id)
		else:
			await _sheet(id)
	quit()

func _measure(id: String) -> void:
	var sc := Scene.new()
	root.add_child(sc)
	if not sc.build(genome_for(id)):
		print(id, ": genome failed")
		return
	for s in shots(sc.morph):
		var v: float = sqrt(float(s[1]) * 9.81 * sc.morph.hip_height)
		sc.ctl.reset(Vector3(0, -sc.c.ground_offset, 0), 0.0)
		sc.pos = Vector3.ZERO
		for k in 360:
			sc.advance(1.0 / 60.0, v)
		print("%-10s %-12s Fr %.2f v %.2f gait %-7s cadence %.2f stride %.2f  cad*stride %.2f duty %.2f" % [id, s[0], sc.ctl.fr, v, sc.ctl.gait, sc.ctl.cadence, sc.ctl.stride, sc.ctl.cadence * sc.ctl.stride, sc.ctl.duty])
	sc.queue_free()
	await process_frame

func _sheet(id: String) -> void:
	var sc := Scene.new()
	root.add_child(sc)
	if not sc.build(genome_for(id)):
		print(id, ": genome failed")
		return
	var list: Array = shots(sc.morph)
	var sheet := Image.create(CELL.x * FRAMES, CELL.y * list.size(), false, Image.FORMAT_RGBA8)
	for r in list.size():
		var v: float = sqrt(float(list[r][1]) * 9.81 * sc.morph.hip_height)
		sc.ctl.reset(Vector3(0, -sc.c.ground_offset, 0), 0.0)
		sc.pos = Vector3.ZERO
		for k in 420:
			sc.advance(1.0 / 60.0, v)
		var period: float = 1.0 / max(sc.ctl.cadence, 0.05)
		for f in FRAMES:
			for k in 6:
				sc.advance(period / FRAMES / 6.0, v)
			await process_frame
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * f, CELL.y * r))
		print("%s %s: Fr %.2f v %.2f m/s gait %s cadence %.2f Hz stride %.2f m duty %.2f" % [id, list[r][0], sc.ctl.fr, v, sc.ctl.gait, sc.ctl.cadence, sc.ctl.stride, sc.ctl.duty])
	sheet.save_png(out_dir.path_join("sheet_%s.png" % id))
	sc.queue_free()
	await process_frame
