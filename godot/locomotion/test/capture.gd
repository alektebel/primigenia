extends SceneTree
## Evidence renderer (needs a display: run under xvfb-run with software GL).
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --path godot --rendering-driver opengl3 \
##       --script locomotion/test/capture.gd
## Writes frame strips and footfall diagrams to docs/evidence/godot/locomotion/.

const Stage = preload("stage.gd")
const Sim = preload("sim.gd")
const Bodies = preload("bodies.gd")
const Diagram = preload("footfall_diagram.gd")

const CELL := Vector2i(300, 250)
const FRAMES := 8
# plan -> [[label, Froude], ...]
const SHOTS := {
	"biped": [["walk", 0.25], ["run", 1.5]],
	"horizontal_biped": [["walk", 0.25], ["run", 1.8]],
	"light_quadruped": [["walk", 0.12], ["trot", 1.2], ["gallop", 5.0]],
	"heavy_quadruped": [["walk", 0.12], ["amble", 0.8]],
	"hexapod": [["tripod slow", 0.1], ["tripod fast", 1.0]],
	"wader": [["walk", 0.12], ["run", 1.5]],
}

var out_dir := ""

func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../docs/evidence/godot/locomotion")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()

func _run() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("plan="):
			only = a.substr(5)
	root.size = CELL
	await process_frame
	for plan in SHOTS:
		if only != "" and only != plan:
			continue
		await _strips(plan)
		await _diagram(plan)
	if only == "" or only == "legless":
		await _legless()
	if only == "":
		await _slope()
	quit()

func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func _strips(plan: String) -> void:
	var shots: Array = SHOTS[plan]
	var sheet := Image.create(CELL.x * FRAMES, CELL.y * shots.size(), false, Image.FORMAT_RGBA8)
	root.size = CELL
	for r in range(shots.size()):
		var stage = Stage.new()
		root.add_child(stage)
		stage.setup(plan)
		var v: float = sqrt(shots[r][1] * 9.81 * stage.rig.morph.hip_height)
		for k in range(360):
			stage.advance(1.0 / 60.0, v)
		var period: float = 1.0 / max(stage.ctl.cadence, 0.05)
		for f in range(FRAMES):
			var sub := 6
			for k in range(sub):
				stage.advance(period / FRAMES / sub, v)
			await process_frame
			var img: Image = await _grab()
			img.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * f, CELL.y * r))
		print("%s %s: Fr %.2f v %.2f m/s gait %s cadence %.2f Hz stride %.2f m duty %.2f" % [plan, shots[r][0], shots[r][1], v, stage.ctl.gait, stage.ctl.cadence, stage.ctl.stride, stage.ctl.duty])
		stage.queue_free()
		await process_frame
	sheet.save_png(out_dir.path_join("strip_%s.png" % plan))

func _legless() -> void:
	var sheet := Image.create(CELL.x * FRAMES, CELL.y, false, Image.FORMAT_RGBA8)
	var stage = Stage.new()
	root.add_child(stage)
	stage.setup("legless", Callable(), "quarter")
	for k in range(240):
		stage.advance(1.0 / 60.0, 0.7)
	for f in range(FRAMES):
		for k in range(6):
			stage.advance(1.0 / 60.0, 0.7)
		await process_frame
		var img: Image = await _grab()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * f, 0))
	stage.queue_free()
	await process_frame
	sheet.save_png(out_dir.path_join("strip_legless.png"))

func _slope() -> void:
	# uphill, ridges and a banked turn: one strip of situations
	var cases := [["light_quadruped", "uphill"], ["heavy_quadruped", "uphill"], ["biped", "uphill"], ["wader", "ridges"],
		["hexapod", "ridges"], ["light_quadruped", "turn"], ["horizontal_biped", "turn"], ["horizontal_biped", "accel"]]
	var sheet := Image.create(CELL.x * cases.size(), CELL.y, false, Image.FORMAT_RGBA8)
	for i in range(cases.size()):
		var plan: String = cases[i][0]
		var kind: String = cases[i][1]
		var stage = Stage.new()
		root.add_child(stage)
		var h: float = Sim.new(Bodies.get_body(plan)).morph.hip_height
		var gf: Callable = Callable()
		if kind == "uphill":
			gf = func(_x, z): return 0.25 * max(z, 0.0)
		elif kind == "ridges":
			gf = func(_x, z): return 0.12 * h * pow(max(0.0, sin(z / h * 3.7)), 8.0)
		stage.setup(plan, gf, "quarter" if kind == "turn" else "side")
		var v: float = sqrt((1.0 if kind == "turn" else 0.2) * 9.81 * h)
		var steps := 300
		for k in range(steps):
			if kind == "accel":
				stage.advance(1.0 / 60.0, 0.0 if k < 255 else (k - 255) / 60.0 * 4.0)
			else:
				stage.advance(1.0 / 60.0, v, 0.9 if (kind == "turn" and k > 200) else 0.0)
		await process_frame
		var img: Image = await _grab()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(CELL.x * i, 0))
		stage.queue_free()
		await process_frame
	sheet.save_png(out_dir.path_join("strip_situations.png"))

static func leg_labels(morph) -> Array:
	var out: Array = []
	var ns: int = morph.stations.size()
	for l in morph.legs:
		var side := "L" if l.side >= 0 else "R"
		if morph.plan == &"quadruped":
			out.append(side + ("H" if l.station == 0 else "F"))
		elif ns > 1:
			out.append("%s%d" % [side, ns - l.station])
		else:
			out.append(side)
	return out

func _diagram(plan: String) -> void:
	var d = Diagram.new()
	var shots: Array = SHOTS[plan]
	for sh in shots:
		var s = Sim.new(Bodies.get_body(plan))
		var v: float = s.speed_for_froude(sh[1])
		s.run(8.0, func(_t): return v)
		var period: float = 1.0 / s.ctl.cadence
		s.frames.clear()
		var t0: float = s.t
		s.run(2.0 * period, func(_t): return v, Callable(), period / 200.0)
		var labels := leg_labels(s.morph)
		# Hildebrand's row order: left hind, left fore, right fore, right hind
		var order: Array = range(labels.size())
		if s.morph.plan == &"quadruped":
			order = ["LH", "LF", "RF", "RH"].map(func(n): return labels.find(n))
		else:
			order.sort_custom(func(a, b): return labels[a] < labels[b])
		var rows: Array = []
		var names: Array = []
		for i in order:
			var segs: Array = []
			var start := -1.0
			for f in s.frames:
				var x: float = (f.t - t0) / period
				if f.contact[i] and start < 0.0:
					start = x
				elif not f.contact[i] and start >= 0.0:
					segs.append([start, x])
					start = -1.0
			if start >= 0.0:
				segs.append([start, 2.0])
			rows.append(segs)
			names.append(labels[i])
		d.panels.append({"title": "%s  (Fr %.2f, %.2f m/s)" % [s.ctl.gait, sh[1], v], "labels": names, "rows": rows,
			"note": "duty %.2f   stride %.2f m   %.2f strides/s" % [s.ctl.duty, s.ctl.stride, s.ctl.cadence]})
	d.title = "%s: footfalls measured from contact flags (bar = foot on the ground)" % plan
	root.size = d.size()
	root.add_child(d)
	d.queue_redraw()
	await process_frame
	await process_frame
	var img: Image = await _grab()
	img.save_png(out_dir.path_join("footfalls_%s.png" % plan))
	d.queue_free()
	await process_frame
	root.size = CELL
	await process_frame
