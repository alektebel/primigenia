extends SceneTree
## Radial species evidence (S2/S3/S5a): per species top / side / close / under, a gait strip per locomotion mode, and a
## lineup with the bilateral species for scale. Software GL, studio light.
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot \
##     --script res://creature/tools/radial_evidence.gd -- <out dir> [shots|gaits|lineup ...]
const SPECIES := {"brujula": .6, "cuarteta": .8, "corona": .55}
const BILATERAL := {"rondo": .8, "zanco": .75, "espinodo": .65, "garfio": 1.0, "babosa": .85, "acechalunas": .8}
const SIZE := Vector2i(1000, 640)

var out := ""


func _initialize() -> void:
	_run.call_deferred()


func _genome(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://game/data/%s.json" % id))


func _make(stage: CreaturePreview, id: String, scale: float, at := Vector3.ZERO) -> Creature:
	var c := Creature.new()
	c.name = id
	stage.world_root.add_child(c)
	var r := c.load_genome(_genome(id))
	if not r["ok"]:
		push_error("%s: %s" % [id, r["error"]])
	c.scale = Vector3.ONE * scale
	c.position = at
	return c


func _save(img: Image, name: String) -> void:
	img.save_jpg(out.path_join(name), .9)
	print("saved ", name)


func _frame(stage: CreaturePreview, target: Vector3, yaw: float, pitch: float, dist: float, fov := 38.0) -> void:
	stage.camera.fov = fov
	var cp := cos(pitch)
	stage.camera.look_at_from_position(target + Vector3(sin(yaw) * cp, sin(pitch), cos(yaw) * cp) * dist, target)


func _shots(id: String, scale: float) -> void:
	var stage := CreaturePreview.new(self, SIZE)
	var c := _make(stage, id, 1.0)
	var box := c.rest_aabb()
	var ctr := box.get_center() + Vector3(0, c.ground_offset, 0) * 0.0
	var span := maxf(maxf(box.size.x, box.size.z), box.size.y * (.9 if c.radial.gel > 0.0 else .0))
	ctr.y += c.ground_offset * 0.0
	if c.radial.gel > 0.0:
		c.position.y += 1.3          # a jelly floats: lift it clear of the floor
		ctr.y += 1.3
	await process_frame
	_frame(stage, ctr, 0.0, 1.5, span * 1.55)
	_save(await stage.capture(self, 5), "%s_top.jpg" % id)
	_frame(stage, ctr, 0.6, 0.12, span * 1.9)
	_save(await stage.capture(self, 5), "%s_side.jpg" % id)
	_frame(stage, ctr, 0.5, 0.5, span * 1.35)
	_save(await stage.capture(self, 5), "%s_close.jpg" % id)
	# Underside: the floor mesh is hidden and the animal lifted so the camera can look up at it.
	for ch in stage.world_root.get_children():
		if ch is MeshInstance3D:
			ch.visible = false
	c.position.y += 1.0
	_frame(stage, ctr + Vector3(0, 1.0, 0), 0.4, -1.1, span * 1.5)
	_save(await stage.capture(self, 5), "%s_under.jpg" % id)
	stage.viewport.queue_free()


func _lineup() -> void:
	var stage := CreaturePreview.new(self, Vector2i(1500, 560))
	var x := 0.0
	var all := {}
	for id in BILATERAL:
		all[id] = BILATERAL[id]
	for id in SPECIES:
		all[id] = SPECIES[id]
	var order := ["babosa", "brujula", "corona", "cuarteta", "rondo", "espinodo", "zanco", "acechalunas", "garfio"]
	var cs := []
	for id in order:
		var c := _make(stage, id, float(all[id]), Vector3(x, 0, 0))
		var w := maxf(c.rest_aabb().size.x, c.rest_aabb().size.z) * float(all[id])
		x += w * .5 + .5
		c.position.x = x
		x += w * .5 + .5
		cs.append(c)
	await process_frame
	_frame(stage, Vector3(x * .5, .5, 0), 0.0, .22, x * 1.05, 40.0)
	_save(await stage.capture(self, 6), "lineup.jpg")
	stage.viewport.queue_free()


func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	DirAccess.make_dir_recursive_absolute(out)
	var which := a.slice(1)
	if which.is_empty() or "shots" in which:
		for id in SPECIES:
			if which.size() > 1 and not (id in which):
				continue
			await _shots(id, SPECIES[id])
	if which.is_empty() or "lineup" in which:
		await _lineup()
	if which.is_empty() or "gaits" in which:
		var G = load("res://creature/tools/radial_gaits.gd") if ResourceLoader.exists("res://creature/tools/radial_gaits.gd") else null
		if G != null:
			await G.new().run(self, out)
	quit()
