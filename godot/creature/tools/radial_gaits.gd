extends RefCounted
## Gait evidence of the radial species (S3): a frame strip per gait and an arm-phase diagram (bar = arm planted;
## for the jet and cilia modes the bar marks the arm drawn in / the ripple crest). Called by radial_evidence.gd.
const Radial := preload("res://locomotion/loco_radial.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const Diagram := preload("res://locomotion/test/footfall_diagram.gd")

## [species, label, speed m/s, yaw, frames, frame step s, creature scale]
const GAITS := [
	["brujula", "glide", 0.3, 0.6, 6, 0.5, 1.0],
	["brujula", "row", 1.2, 0.6, 6, 0.12, 1.0],
	["cuarteta", "jet", 0.25, 0.6, 6, 0.4, 1.0],
	["corona", "cilia", 0.3, 0.6, 6, 0.4, 1.0],
]
const CELL := Vector2i(360, 280)


func _genome(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))


func _ground(slope: bool) -> Callable:
	return func(x: float, z: float) -> float: return 0.0


func run(tree: SceneTree, out: String) -> void:
	for g in GAITS:
		await _strip(tree, out, g)
		_diagram(tree, out, g)
	await _collapse(tree, out)


func _build(stage: CreaturePreview, id: String) -> Creature:
	var c := Creature.new()
	stage.world_root.add_child(c)
	c.load_genome(_genome(id))
	return c


func _strip(tree: SceneTree, out: String, g: Array) -> void:
	var id: String = g[0]
	var stage := CreaturePreview.new(tree, CELL)
	var c := _build(stage, id)
	var desc := Adapter.radial_describe(c, 1.0)
	var loco = Radial.new(desc, _ground(false))
	var pos := Vector3.ZERO
	var yaw: float = g[3]
	var v: float = g[2]
	loco.reset(pos, yaw)
	var vel := Vector3(sin(yaw), 0, cos(yaw)) * v
	var sheet := Image.create(CELL.x * int(g[4]), CELL.y, false, Image.FORMAT_RGBA8)
	var lift := 1.3 if c.radial.gel > 0.0 else 0.0
	var span: float = c.rest_aabb().size.x * 1.0
	for i in 90:
		pos += vel / 60.0
		loco.step(1.0 / 60.0, pos, yaw, vel)
	Adapter.radial_apply(c, loco.pose, desc)
	for f in int(g[4]):
		var n := int(round(float(g[5]) * 60.0))
		for i in n:
			pos += vel / 60.0
			loco.step(1.0 / 60.0, pos, yaw, vel)
		Adapter.radial_apply(c, loco.pose, desc)
		c.global_position.y += lift
		var jelly := c.radial.gel > 0.0
		var tgt := c.global_position + Vector3(0, -0.25 if jelly else 0.1, 0)
		stage.camera.fov = 40
		stage.camera.look_at_from_position(tgt + Vector3(sin(yaw + 2.2) * 1.0, 0.35 if jelly else 0.8, cos(yaw + 2.2) * 1.0) * span * (2.4 if jelly else 1.15), tgt)
		var img: Image = await stage.capture(tree, 4)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, 0))
	sheet.save_jpg(out.path_join("%s_move_%s.jpg" % [id, g[1]]), 0.88)
	print("saved ", "%s_move_%s.jpg" % [id, g[1]])
	stage.viewport.queue_free()


func _diagram(tree: SceneTree, out: String, g: Array) -> void:
	var id: String = g[0]
	var stage := CreaturePreview.new(tree, Vector2i(64, 64))
	var c := _build(stage, id)
	var desc := Adapter.radial_describe(c, 1.0)
	var loco = Radial.new(desc, _ground(false))
	var yaw: float = g[3]
	var v: float = g[2]
	var vel := Vector3(sin(yaw), 0, cos(yaw)) * v
	var pos := Vector3.ZERO
	loco.reset(pos, yaw)
	for i in 240:
		pos += vel / 60.0
		loco.step(1.0 / 60.0, pos, yaw, vel)
	var period := 1.0 / maxf(loco.row_hz, 0.5) if (loco.mode == &"row" or loco.mode == &"jet") else 2.0
	var fold: int = loco.fold
	var segs := []
	var start := []
	for k in fold:
		segs.append([])
		start.append(-1.0)
	var steps := int(2.0 * period * 60.0)
	for i in steps:
		pos += vel / 60.0
		loco.step(1.0 / 60.0, pos, yaw, vel)
		var x := float(i) / 60.0 / period
		for k in fold:
			var on := false
			match loco.mode:
				&"jet":
					on = loco.pose.arm_pitch[k][0] < -0.04
				&"cilia":
					var tot := 0.0
					for b in 5:
						tot += loco.pose.arm_pitch[k][b]
					on = tot > 0.0
				_:
					on = loco.pose.contact[k]
			if on and start[k] < 0.0:
				start[k] = x
			elif not on and start[k] >= 0.0:
				segs[k].append([start[k], x])
				start[k] = -1.0
	for k in fold:
		if start[k] >= 0.0:
			segs[k].append([start[k], 2.0])
	var labels := []
	for k in fold:
		var j: int = loco.rel(k)
		labels.append("A%d%s" % [k, "*" if j == 0 else ""])
	var d := Diagram.new()
	d.panels.append({"title": "%s %s (%.2f m/s)" % [id, g[1], v], "labels": labels, "rows": segs,
		"note": "arm planted (glide, row) / drawn in (jet) / ripple crest (cilia); * = lead arm"})
	d.title = "%s: arm phase over two cycles" % id
	var vp := SubViewport.new()
	vp.size = d.size()
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	tree.root.add_child(vp)
	vp.add_child(d)
	d.queue_redraw()
	await tree.process_frame
	await tree.process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out.path_join("%s_gait_%s.png" % [id, g[1]]))
	print("saved ", "%s_gait_%s.png" % [id, g[1]])
	vp.queue_free()
	stage.viewport.queue_free()


## Slack-tide collapse of the corona (axis bones flatten over ~2 s while hunkered).
func _collapse(tree: SceneTree, out: String) -> void:
	var stage := CreaturePreview.new(tree, CELL)
	var c := _build(stage, "corona")
	var desc := Adapter.radial_describe(c, 1.0)
	var loco = Radial.new(desc, _ground(false))
	loco.reset(Vector3.ZERO, 0.0)
	loco.hunker = true
	var sheet := Image.create(CELL.x * 4, CELL.y, false, Image.FORMAT_RGBA8)
	for f in 4:
		for i in [0, 30, 40, 80][f]:
			loco.step(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.ZERO)
		if f == 0:
			loco.step(1.0 / 60.0, Vector3.ZERO, 0.0, Vector3.ZERO)
		Adapter.radial_apply(c, loco.pose, desc)
		var tgt := c.global_position + Vector3(0, 0.1, 0)
		stage.camera.look_at_from_position(tgt + Vector3(.7, .25, .9), tgt)
		var img: Image = await stage.capture(tree, 4)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i(f * CELL.x, 0))
	sheet.save_jpg(out.path_join("corona_move_collapse.jpg"), 0.88)
	print("saved corona_move_collapse.jpg")
	stage.viewport.queue_free()
