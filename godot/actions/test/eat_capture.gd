extends SceneTree
## Evidence of the meal: frame sheets of a body eating a carcass and a plant, with the scripted C eat ticks.
##   make godot-eat-evidence
## Command line (after --): out=<dir> creatures=Hatchling,Merodeador  (software GL only)
## One sheet per body: row 1 a carcass (4 bites, shrinks, gone), row 2 a plant tuft. Columns are act ticks (label).

const H := preload("res://actions/test/harness.gd")
const Fx := preload("res://actions/action_fx.gd")

var out_dir := "res://../docs/evidence/godot/eat-loading"
var creatures := ["hatchling", "Merodeador"]
var cell := Vector2i(300, 225)
# act ticks at which a frame is taken; the last one is 0.9 s after C ended the meal
const TIMES := [1.0, 4.0, 7.0, 9.8, 11.8, 14.8, 19.5, 33.0, 41.5]
const KINDS := ["carcass", "plant"]

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			match kv[0]:
				"out": out_dir = kv[1]
				"creatures": creatures = kv[1].split(",")
	_run()

func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p).simplify_path() if p.begins_with("res://") else p

func _food(kind: String) -> Node3D:
	var n := Node3D.new()
	if kind == "carcass":
		var m := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		m.mesh = s
		m.scale = Vector3(1.0, 0.55, 1.5)
		m.position.y = 0.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.5, 0.2, 0.17)
		mat.roughness = 0.85
		m.material_override = mat
		n.add_child(m)
		var rib := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.025
		cy.bottom_radius = 0.025
		cy.height = 0.7
		rib.mesh = cy
		rib.rotation = Vector3(0, 0, PI / 2.0)
		rib.position = Vector3(0, 0.46, 0.1)
		var bm := StandardMaterial3D.new()
		bm.albedo_color = Color(0.88, 0.84, 0.72)
		rib.material_override = bm
		n.add_child(rib)
	else:
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.3, 0.62, 0.2)
		gm.roughness = 0.9
		for k in 7:
			var m := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.06
			c.height = 0.5 + 0.1 * (k % 3)
			m.mesh = c
			var a := TAU * k / 7.0
			m.position = Vector3(cos(a) * 0.16, c.height * 0.5, sin(a) * 0.16)
			m.rotation = Vector3(sin(a) * 0.35, 0, -cos(a) * 0.35)
			m.material_override = gm
			n.add_child(m)
	return n

func _run() -> void:
	await process_frame
	var raw := H.load_raw()
	DirAccess.make_dir_recursive_absolute(_abs(out_dir))
	var Preview = load("res://creature/tools/creature_preview.gd")
	for name in creatures:
		var prev = Preview.new(self, cell)
		var layer := CanvasLayer.new()
		prev.viewport.add_child(layer)
		var label := Label.new()
		label.position = Vector2(6, 4)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 14)
		layer.add_child(label)
		var h = H.new()
		h.build(prev.world_root, name, raw)
		h.layer.idle_on = false
		h.sf.end_fight()
		var mouth0: Vector3 = h.map.mouth_point(h.map.rest_global)
		var fscale: float = clampf(h.map.height * 0.55, 0.3, 1.2)
		var cells := []
		var st := {"food": null, "kind": "carcass", "pulse": 0.0, "fs": 0.1, "crumbs": []}
		h.layer.action_event.connect(func(n: String, d: Dictionary) -> void:
			if n == "eat_bite" and is_instance_valid(st.food):
				st.pulse = 1.0
				st.crumbs.append(Fx.crumbs(prev.world_root, (st.food as Node3D).global_position + Vector3.UP * 0.3 * fscale, Color(0.52, 0.18, 0.15) if st.kind == "carcass" else Color(0.35, 0.66, 0.22), 0.5 * fscale, d.left <= 0)))
		for kind in KINDS:
			var food := _food(kind)
			prev.world_root.add_child(food)
			var base: float = fscale
			var fz: float = mouth0.z - 0.1 * fscale + (0.35 * fscale if kind == "carcass" else 0.0)
			food.position = Vector3(0, 0, fz)
			h.food_pos = Vector3(0, 0.3 * fscale, fz - (0.3 * fscale if kind == "carcass" else 0.0))
			var fs := 1.0
			var meat := 4
			st.food = food
			st.kind = kind
			st.crumbs = []
			var box: AABB = h.c.rest_aabb()
			prev.orbit(Vector3(0, maxf(box.end.y, 0.5) * 0.4, (box.position.z + fz) * 0.5), 1.35, 0.12, maxf((fz - box.position.z + fscale) / 0.8, 1.4), 40.0)
			h.layer.clear()
			h.run(0.6)
			h.eat_t0 = h.sf.tick
			h.acc = 0.0
			var idx := 0
			var ended := false
			var end_t := -1.0
			var guard := 0
			var last_bite_tick := 0
			while idx < TIMES.size() and guard < 4000:
				guard += 1
				h.frame(1.0 / 60.0)
				var t: float = float(h.sf.tick - h.eat_t0) + h.acc / 0.1 if h.eat_t0 >= 0 else 99.0
				# the scripted C: a bite on every 10th act tick; the last (4th) ends the action
				var bt: int = (h.sf.tick - h.eat_t0) / 10 if h.eat_t0 >= 0 else 0
				if h.eat_t0 >= 0 and bt > last_bite_tick:
					last_bite_tick = bt
					meat = 4 - bt
					h.layer.eat_bite(meat, kind)
					if meat <= 0:
						h.eat_t0 = -1
						end_t = h.sim_t
				var want: float = (0.3 + 0.7 * float(meat) / 4.0) if meat > 0 else 0.0
				fs = lerpf(fs, want, 1.0 - exp(-9.0 / 60.0)) if want < fs else want
				st.pulse = maxf(0.0, st.pulse - 5.0 / 60.0)
				food.scale = Vector3.ONE * base * maxf(fs * (1.0 - 0.07 * st.pulse), 0.001)
				food.visible = fs > 0.02
				var cap := false
				if idx < TIMES.size() - 1:
					cap = t >= TIMES[idx]
				else:
					cap = end_t >= 0.0 and h.sim_t - end_t >= 0.9
				if cap:
					label.text = "%s %s  act tick %.1f%s  bites left %d" % [name, kind, minf(t, 40.0), " (ended)" if end_t >= 0.0 else "", meat]
					var img: Image = await prev.capture(self, 2)
					img.convert(Image.FORMAT_RGB8)
					cells.append(img)
					idx += 1
			food.queue_free()
			for c in st.crumbs:
				if is_instance_valid(c):
					c.queue_free()
			h.eat_t0 = -1
			h.run(1.0)
		var ncol: int = TIMES.size()
		var img := Image.create(cell.x * ncol, cell.y * KINDS.size(), false, Image.FORMAT_RGB8)
		for i in cells.size():
			img.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % ncol) * cell.x, (i / ncol) * cell.y))
		var path := _abs(out_dir).path_join("eat_%s.png" % name.to_lower())
		img.save_png(path)
		print("wrote ", path)
	quit()
