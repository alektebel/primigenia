extends SceneTree
## Evidence renders for docs/evidence/godot/creature/ (software GL only):
##   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 \
##     --max-fps 15 --path godot --script res://creature/tools/render_evidence.gd
## (or `make godot-creature-evidence`). Writes:
##   merodeador_vs_threejs.png  three.js hero (golden-mid) | Godot, same seed
##   g48_tail_hammer_compare.png g48-after3 tail_hammer row (top) | Godot (bottom)
##   seeds.png                  Godot Merodeador, Zancuda, Babosa
##   growth.png                 v3 horns, Zancuda plates/tendrils/horns
##   parts_contact_sheet.png    all 46 parts on Merodeador (eyes and legs kept)

const OUT := "res://../docs/evidence/godot/creature/"
const REF_HERO := "res://../docs/evidence/hero/grid/golden-mid.png"
const REF_G48 := "res://../docs/evidence/g48-after3.png"

var stage: CreaturePreview
var label: Label


func _initialize() -> void:
	_run()


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p).simplify_path()


func _setup(size: Vector2i) -> Creature:
	if stage:
		stage.viewport.queue_free()
	stage = CreaturePreview.new(self, size)
	var layer := CanvasLayer.new()
	stage.viewport.add_child(layer)
	label = Label.new()
	label.position = Vector2(6, 4)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_font_size_override("font_size", 14)
	layer.add_child(label)
	var c := Creature.new()
	stage.world_root.add_child(c)
	return c


func _shot(c: Creature, yaw: float, pitch: float, dist: float, fov: float, text := "") -> Image:
	label.text = text
	stage.orbit(CreaturePreview.mid_target(c), yaw, pitch, dist, fov)
	var img: Image = await stage.capture(self, 3)
	img.convert(Image.FORMAT_RGB8)
	return img


static func _ref_crop(path: String, rect: Rect2i, size: Vector2i) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	var out := img.get_region(rect)
	out.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return out


static func _sheet(cells: Array, cols: int, cell: Vector2i, gap := 4) -> Image:
	var rows := int(ceil(cells.size() / float(cols)))
	var img := Image.create(cols * cell.x + (cols + 1) * gap, rows * cell.y + (rows + 1) * gap, false, Image.FORMAT_RGB8)
	img.fill(Color("#0f1c24"))
	for i in cells.size():
		var c: Image = cells[i]
		if c.get_size() != cell:
			c.resize(cell.x, cell.y, Image.INTERPOLATE_LANCZOS)
		img.blit_rect(c, Rect2i(Vector2i.ZERO, cell), Vector2i(gap + (i % cols) * (cell.x + gap), gap + (i / cols) * (cell.y + gap)))
	return img


func _strip(seed: Dictionary, keep: Array) -> Dictionary:
	var g := seed.duplicate(true)
	g["parts"] = g["parts"].filter(func(p): return p["type"] in keep)
	return g


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(_abs(OUT))
	var seeds := Creature.seeds()
	var only := OS.get_environment("CREATURE_EVIDENCE_ONLY")
	if only != "parts":
		await _comparisons(seeds)
	await _contact_sheet(seeds)
	print("evidence written to ", _abs(OUT))
	quit()


func _comparisons(seeds: Dictionary) -> void:

	# 1. Hero comparison: Merodeador, three.js stage (left) vs Godot (right).
	var size := Vector2i(560, 360)
	var c := _setup(size)
	c.load_genome(seeds["Merodeador"])
	var ref := _ref_crop(_abs(REF_HERO), Rect2i(360, 220, 560, 360), size)
	var g1: Image = await _shot(c, 2.35, .16, 6.2, 42, "Godot 4 (GL Compatibility, llvmpipe)")
	_sheet([ref, g1], 2, size).save_png(_abs(OUT + "merodeador_vs_threejs.png"))

	# 2. g48-after3 tail_hammer row (studio cameras) vs the same setup in Godot.
	size = Vector2i(420, 300)
	c = _setup(size)
	var cells := []
	var views := [[.5, 7.0], [1.57, 8.0], [2.6, 8.0]]
	for col in 6:
		cells.append(_ref_crop(_abs(REF_G48), Rect2i(180 + 420 * col, 60 + 360 * 5, 420, 300), size))
	for name in ["Merodeador", "Zancuda"]:
		var keep := ["ojo", "pata"] if name == "Merodeador" else ["ojo", "zanca"]
		var g := _strip(seeds[name], keep)
		c.build(g)
		g["parts"].append(c.default_part("tail_hammer"))
		c.load_genome(g)
		for v in views:
			cells.append(await _shot(c, v[0], .18, v[1], 50, "Godot %s yaw %.2f" % [name, v[0]]))
	_sheet(cells, 6, size).save_png(_abs(OUT + "g48_tail_hammer_compare.png"))

	# 3. The three seeds.
	var seed_cells := []
	for name in ["Merodeador", "Zancuda", "Babosa"]:
		c.load_genome(seeds[name])
		seed_cells.append(await _shot(c, .9, .2, 9.5 if name == "Zancuda" else 8.0, 50, name))
	_sheet(seed_cells, 3, size).save_png(_abs(OUT + "seeds.png"))
	c.load_genome(seeds["Zancuda"])
	var zref := _ref_crop(_abs(REF_G48), Rect2i(180 + 420 * 4, 60 + 360 * 5, 420, 300), size)
	var z1: Image = await _shot(c, 1.57, .18, 8.0, 50, "Godot Zancuda (full seed)")
	c.build(_strip(seeds["Zancuda"], ["ojo", "zanca"]))
	var z2: Image = await _shot(c, 1.57, .18, 8.0, 50, "Godot Zancuda (eyes + legs)")
	_sheet([zref, z2, z1], 3, size).save_png(_abs(OUT + "zancuda_vs_threejs.png"))

	# 5. Growth: v3 fixture (9 mirrored horns, torso) and Zancuda with plates (torso),
	# tendrils (neck) and horns (tail), same recipe as the placement test.
	var gcells := []
	c.load_genome(FileAccess.get_file_as_string(_abs("res://../tests/fixtures/studio/v3.json")))
	gcells.append(await _shot(c, .9, .2, 8.0, 50, "v3 fixture: 9 horns, mirrored, torso"))
	var gdoc: Dictionary = load("res://creature/tests/test_creature.gd").growth_doc(seeds["Zancuda"])
	c.load_genome(gdoc)
	gcells.append(await _shot(c, .9, .2, 9.5, 50, "Zancuda: plates torso, tendrils neck, horns tail"))
	gcells.append(await _shot(c, 2.4, .2, 9.5, 50, "same, other flank"))
	_sheet(gcells, 3, size).save_png(_abs(OUT + "growth.png"))



func _contact_sheet(seeds: Dictionary) -> void:
	# 4. Contact sheet: every part at its default placement on Merodeador.
	var size := Vector2i(300, 210)
	var c := _setup(size)
	var lib := CreatureParts.library()
	var part_cells := []
	var base := _strip(seeds["Merodeador"], ["ojo", "pata"])
	for entry in lib["table"]["parts"]:
		var id: String = entry["id"]
		var g := base.duplicate(true)
		c.build(g)
		if id in ["ojo", "pata"]:
			g = base.duplicate(true)
		g["parts"].append(c.default_part(id))
		var r := c.load_genome(g)
		if not r["ok"]:
			push_error("%s: %s" % [id, r["error"]])
		var yaw := 1.0
		if id.begins_with("tail_") or id in ["maza", "aguijon"]:
			yaw = 1.9
		# Frame between the body centre and the part's mount.
		var np: Dictionary = g["parts"][-1]
		var A := c.anchor(np["t"], np["ang"])
		var target := CreaturePreview.mid_target(c).lerp(A["p"] + Vector3(0, c.ground_offset, 0), .55)
		label.text = "%s (%s)" % [id, entry["source"]]
		stage.camera.fov = 50
		var cp := cos(.3)
		stage.camera.look_at_from_position(target + Vector3(sin(yaw) * cp, sin(.3), cos(yaw) * cp) * 5.2, target)
		var img: Image = await stage.capture(self, 3)
		img.convert(Image.FORMAT_RGB8)
		part_cells.append(img)
	_sheet(part_cells, 8, size).save_png(_abs(OUT + "parts_contact_sheet.png"))
