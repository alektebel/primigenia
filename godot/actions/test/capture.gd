extends SceneTree
## Evidence for docs/godot/ACTIONS.md: frame strips of the actions on several bodies, with a scripted C feed.
##   make godot-actions-evidence ARGS="actions=bite,spit creatures=Merodeador,Zancuda"
## Command line (after --): out=<dir> actions=a,b creatures=A,B size=288x216 (software GL only, see godot-common.md)
## Writes strip_<action>.png (rows = bodies, columns = wind-up, active, recovery, settle) and measurements.json.

const H := preload("res://actions/test/harness.gd")
const Clock := preload("res://actions/action_clock.gd")

var out_dir := "res://../docs/evidence/godot/actions"
var action_ids := ["bite", "charge", "spit", "tail_strike", "guard", "dodge", "stagger", "death", "roar", "sing"]
var creatures := ["Merodeador", "Zancuda", "Babosa"]
var cell := Vector2i(288, 216)
const SAMPLES := [["w", 0.0], ["w", 0.5], ["w", 0.85], ["a", 0.0], ["a", 0.5], ["r", 0.0], ["r", 0.5], ["s", 1.0]]
const SEG_COLOR := {"w": Color("#e8a735"), "a": Color("#d8432f"), "r": Color("#8a8f98"), "s": Color("#4d8f5a")}
const MOVES := {"bite": 0, "charge": 1, "guard": 2, "spit": 3, "tail_strike": 4, "dodge": 5}

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out_dir = kv[1]
			"actions": action_ids = kv[1].split(",")
			"creatures": creatures = kv[1].split(",")
			"size":
				var wh := kv[1].split("x")
				cell = Vector2i(int(wh[0]), int(wh[1]))
	_run()

func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p).simplify_path() if p.begins_with("res://") else p

func _run() -> void:
	await process_frame
	var raw := H.load_raw()
	DirAccess.make_dir_recursive_absolute(_abs(out_dir))
	var Preview = load("res://creature/tools/creature_preview.gd")
	var measurements := {}
	# one stage per body, reused for every action
	var rigs := {}
	for name in creatures:
		var prev = Preview.new(self, cell)
		var layer := CanvasLayer.new()
		prev.viewport.add_child(layer)
		var label := Label.new()
		label.position = Vector2(6, 4)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_font_size_override("font_size", 13)
		layer.add_child(label)
		var h = H.new()
		h.target_h = 1.8
		h.build(prev.world_root, name, raw)
		h.layer.idle_on = false
		var rest_mouth: Vector3 = h.map.mouth_point(h.map.rest_global)
		h.dist = maxf(rest_mouth.z + 0.4 + 0.6, 1.5)
		h.sf.pos = [Vector2(0, 0), Vector2(0, h.dist)]
		var tgt := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.6
		cap.height = 1.8
		tgt.mesh = cap
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.55, 0.57, 0.62)
		tm.roughness = 0.9
		tgt.material_override = tm
		tgt.position = Vector3(0, 0.9, h.dist)
		prev.world_root.add_child(tgt)
		rigs[name] = {"prev": prev, "h": h, "label": label, "tgt": tgt}
	for id in action_ids:
		if not raw.has(id):
			printerr("unknown action ", id)
			continue
		var cells := []
		for name in creatures:
			var r: Dictionary = rigs[name]
			var res := await _strip_row(r, id, raw[id])
			cells.append_array(res.cells)
			measurements["%s/%s" % [id, name]] = res.meas
		var img := Image.create(cell.x * SAMPLES.size(), cell.y * creatures.size(), false, Image.FORMAT_RGB8)
		for i in cells.size():
			img.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % SAMPLES.size()) * cell.x, (i / SAMPLES.size()) * cell.y))
		var path := _abs(out_dir).path_join("strip_%s.png" % id)
		img.save_png(path)
		print("wrote ", path)
	var f := FileAccess.open(_abs(out_dir).path_join("measurements.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(measurements, "  "))
	f.close()
	quit()

func _frame_cam(r: Dictionary, id := "") -> void:
	var h = r.h
	var box: AABB = h.c.rest_aabb()
	var z0: float = box.position.z
	var z1: float = maxf(box.end.z, h.dist + 0.7)
	var ymax: float = maxf(box.end.y, 1.8) + 0.3
	var span_z := z1 - z0
	var d := maxf(span_z / 0.85, ymax / 0.6) * 1.08
	if id == "tail_strike":       # the whip swings in the horizontal plane: look down on it
		r.prev.orbit(Vector3(0, ymax * 0.35, (z0 + z1) * 0.5), 0.5, 1.15, d * 1.05, 40.0)
	else:
		r.prev.orbit(Vector3(0, ymax * 0.48, (z0 + z1) * 0.5), 1.2, 0.1, d, 40.0)

func _strip_row(r: Dictionary, id: String, raw_act: Dictionary) -> Dictionary:
	var h = r.h
	var tk: Dictionary = raw_act.ticks
	var w: float = tk.w; var a: float = tk.a; var rr: float = tk.r
	var settle: float = float(raw_act.get("settle", 0.2)) / 0.1
	_frame_cam(r, id)
	h.sf.dead[0] = false
	h.sf.in_fight = raw_act.driver.kind != "cosmetic"
	h.layer.clear()
	h.run(0.8)
	var times := []
	for s in SAMPLES:
		times.append(Clock.seg_time(s[0], s[1], w, a, rr, settle) if s[0] != "s" else w + a + rr + settle * 0.85)
	var cells := []
	var meas := {"max_bone_speed": 0.0, "max_slide_mm": 0.0, "min_k": 1.0, "max_joint_share": 0.0}
	var soles0: PackedVector3Array = h.soles()
	var prev_rot: Array = h.bone_rotations()
	var cosmetic: bool = raw_act.driver.kind == "cosmetic"
	if cosmetic:
		h.layer.trigger(id)
	elif MOVES.has(id):
		h.sf.begin(0, MOVES[id])
	elif id == "stagger":
		h.sf.interrupt(0, 6)
	elif id == "death":
		h.sf.die(0)
	var idx := 0
	var guard := 0
	var timeout := (w + a + rr + settle) * 0.1 + 1.5
	var t0: float = h.sim_t
	while idx < times.size() and h.sim_t - t0 < timeout:
		h.frame(1.0 / 60.0)
		var tau := -1.0
		for i in h.layer.inst:
			if i.id == id and not i.fading:
				tau = maxf(tau, i.tau)
		var now: Array = h.bone_rotations()
		for k in now.size():
			var d: Quaternion = (prev_rot[k] as Quaternion).inverse() * (now[k] as Quaternion)
			meas.max_bone_speed = maxf(meas.max_bone_speed, 2.0 * atan2(Vector3(d.x, d.y, d.z).length(), absf(d.w)) * 60.0)
		prev_rot = now
		meas.min_k = minf(meas.min_k, float(h.layer.debug.get("k", 1.0)))
		if raw_act["legs"] == "plant":
			var sl: PackedVector3Array = h.soles()
			for q in sl.size():
				meas.max_slide_mm = maxf(meas.max_slide_mm, sl[q].distance_to(soles0[q]) * 1000.0)
		while idx < times.size() and tau >= times[idx] - 1e-6:
			r.label.text = "%s  %s:%.2f  tau %.1f" % [id, SAMPLES[idx][0], SAMPLES[idx][1], tau]
			var s: Array = SAMPLES[idx]
			r.label.add_theme_color_override("font_color", SEG_COLOR[s[0]])
			var img: Image = await r.prev.capture(self, 2)
			img.convert(Image.FORMAT_RGB8)
			for x in range(img.get_width()):
				for y in range(img.get_height() - 5, img.get_height()):
					img.set_pixel(x, y, SEG_COLOR[s[0]])
			cells.append(img)
			idx += 1
	while cells.size() < SAMPLES.size():
		var blank := Image.create(cell.x, cell.y, false, Image.FORMAT_RGB8)
		blank.fill(Color.BLACK)
		cells.append(blank)
	h.sf.dead[0] = false
	h.sf.in_fight = false
	h.sf.step()
	h.run(0.5)
	return {"cells": cells, "meas": meas}
