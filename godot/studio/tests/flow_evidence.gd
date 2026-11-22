extends SceneTree
## Same four moments before/after C1/C2. Headless writes geometry/timing only;
## software GL also writes JPGs. Reference-containing comparisons stay outside git.
const Studio := preload("../ui/studio.gd")
var ui
var out := "/tmp/creator-flow"
var rows := []

func _init() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func bounds() -> AABB:
	return ui.view.creature.transform * ui.view.creature.rest_aabb()

func shot(moment: String) -> void:
	await frames(12)
	for i in 120:
		if absf(ui._dist - ui._dist_goal) < .001 and ui._target.distance_to(ui._target_goal) < .001: break
		await process_frame
	var b := bounds()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var p: Vector2 = ui.camera.unproject_position(b.get_endpoint(i))
		lo = lo.min(p)
		hi = hi.max(p)
	var covered := 0.0
	for c in ui.hud.get_children():
		if c is PanelContainer and c.is_visible_in_tree():
			var r: Rect2 = c.get_global_rect().intersection(Rect2(Vector2.ZERO, ui.size))
			covered += r.get_area()
	rows.append({"moment": moment, "bounds_height_ratio": (hi.y - lo.y) / ui.stage.size.y,
		"ui_area_ratio": covered / (ui.size.x * ui.size.y)})
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out.path_join(moment + ".jpg"), .92)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	ui = Studio.new()
	root.add_child(ui)
	await frames(12)
	ui.frame_creature()
	await shot("01-start")
	ui.model.add_part("cuerno", .65, 1.1)
	var a: Dictionary = ui.view.part_anchor(ui.model.selected)
	ui._dropped(ui.model.selected, a.get("pos", Vector3.ZERO))
	await shot("02-add-part")
	ui.model.begin()
	var n: Dictionary = ui.model.doc.nodes.back()
	ui.model.bend_end(ui.model.doc.nodes.size() - 1, n.y + .3, n.z + .6)
	ui.model.end()
	ui._spine_hover = true
	ui.view.set_spine_visible(true)
	await shot("03-stretch-spine")
	ui._set_hover(-1)
	ui.model.select(-1)
	ui.model.apply_palette(2)
	await shot("04-final")
	await frames(360)  # let Performance's once-per-second monitor settle after mesh/thumbnail builds
	var samples := []
	var start := Time.get_ticks_usec()
	for i in 360:
		await process_frame
		samples.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000)
	var ms := (Time.get_ticks_usec() - start) / 360000.0
	samples.sort()
	var mean := 0.0
	for sample in samples: mean += sample / samples.size()
	var result := {"process_mean_ms": mean, "process_p95_ms": samples[int(samples.size() * .95)], "display": DisplayServer.get_name(), "size": "1280x720", "moments": rows,
		"wall_ms_per_frame": ms, "timing_note": "Headless wall time is not rendered GPU frame time; compare identical commands."}
	FileAccess.open(out.path_join("metrics.json"), FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	ui.queue_free()
	await frames(2)
	quit()
