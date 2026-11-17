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
const Fx := preload("res://actions/action_fx.gd")
## Round 2: six frames at chosen action times (ticks) for the actions whose motion lives in a few ticks. [tau...]
const SETS := {
	"bite": [2.0, 3.0, 3.5, 4.3, 5.2, 7.5],
	"roar": [0.6, 1.9, 3.4, 5.0, 8.5, 12.5],
	"stagger": [0.12, 0.45, 1.1, 2.2, 4.5, 7.5],
	"charge": [6.0, 10.5, 12.0, 13.6, 15.4, 19.5],
}
const DASH_SPEED := 10.0       # C: charge reach 5 m over 5 active ticks
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
		rigs[name] = {"prev": prev, "h": h, "label": label, "tgt": tgt, "dist0": h.dist}
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
		var ncol: int = SETS[id].size() if SETS.has(id) else SAMPLES.size()
		var img := Image.create(cell.x * ncol, cell.y * creatures.size(), false, Image.FORMAT_RGB8)
		for i in cells.size():
			img.blit_rect(cells[i], Rect2i(Vector2i.ZERO, cell), Vector2i((i % ncol) * cell.x, (i / ncol) * cell.y))
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
	h.dist = 6.4 if id == "charge" else float(r.dist0)      # a run-up long enough to show the dash
	h.sf.pos[1] = Vector2(0, h.dist)
	r.tgt.position.z = h.dist
	var tk: Dictionary = raw_act.ticks
	var w: float = tk.w; var a: float = tk.a; var rr: float = tk.r
	var settle: float = float(raw_act.get("settle", 0.2)) / 0.1
	_frame_cam(r, id)
	h.sf.dead[0] = false
	h.sf.in_fight = raw_act.driver.kind != "cosmetic"
	h.events.clear()
	h.layer.clear()
	h.run(0.8)
	var times := []
	var samples: Array = []
	if SETS.has(id):
		for tt in SETS[id]:
			times.append(tt)
			var loc := Clock.locate(tt, w, a, rr, settle)
			samples.append([loc.seg, loc.u])
	else:
		samples = SAMPLES
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
		h.sf.event(1, 1, 0, 1, 18.0)       # the wild creature hits (a charge)
		h.sf.interrupt(0, 6)
	elif id == "death":
		h.sf.die(0)
	var idx := 0
	var guard := 0
	var hit_sent := false
	var hit_t := -1.0
	var stopped := false
	var tgt: MeshInstance3D = r.tgt
	var tgt_rest: Vector3 = tgt.position
	var mouth_z: float = h.map.mouth_point(h.map.rest_global).z
	var fx_nodes: Array = []
	var fx_t0 := -1.0
	var rings_seen := 0
	var timeout := (w + a + rr + settle) * 0.1 + 1.5
	var t0: float = h.sim_t
	while idx < times.size() and h.sim_t - t0 < timeout:
		var fgt: Dictionary = h.sf.fighters[0]
		if id == "bite" and not hit_sent and fgt.phase == 1 and fgt.ptick == fgt.plen - 1:
			h.sf.event(1, 0, 1, 0, 9.0)
			hit_sent = true
			hit_t = h.sim_t + 0.05
		if id == "charge" and fgt.phase == 2 and fgt.move == 1 and not stopped:
			h.pos.z += DASH_SPEED / 60.0
			h.sf.pos[0] = Vector2(0, h.pos.z)
			h.vel = Vector3(0, 0, DASH_SPEED)
			if h.pos.z + mouth_z >= h.dist - 0.6 - 0.1:
				stopped = true
				h.vel = Vector3.ZERO
				h.sf.event(1, 0, 1, 1, 18.0)
				hit_t = h.sim_t + 0.05
		elif id == "charge" and (stopped or fgt.phase != 2):
			h.vel = h.vel.lerp(Vector3.ZERO, 0.2) if not stopped else Vector3.ZERO
		h.frame(1.0 / 60.0)
		_target_fx(tgt, tgt_rest, id, h.sim_t - hit_t if hit_t >= 0.0 else -1.0)
		if id == "roar":
			for ev in h.events:
				if ev[1] == "cry" and rings_seen == 0:
					rings_seen = 1
					fx_t0 = ev[0]
					fx_nodes = Fx.roar_ring(r.prev.world_root, h.pos, 1.6 * h.map.height + 0.8, Color(1.0, 0.86, 0.6), true)
		if fx_t0 >= 0.0:
			for k in fx_nodes.size():
				Fx.ring_pose(fx_nodes[k], clampf((h.sim_t - fx_t0 - 0.12 * k) / 0.55, 0.0, 1.0), k)
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
			r.label.text = "%s  %s:%.2f  tau %.1f" % [id, samples[idx][0], samples[idx][1], tau]
			var s: Array = samples[idx]
			r.label.add_theme_color_override("font_color", SEG_COLOR[s[0]])
			var img: Image = await r.prev.capture(self, 2)
			img.convert(Image.FORMAT_RGB8)
			for x in range(img.get_width()):
				for y in range(img.get_height() - 5, img.get_height()):
					img.set_pixel(x, y, SEG_COLOR[s[0]])
			cells.append(img)
			idx += 1
	while cells.size() < samples.size():
		var blank := Image.create(cell.x, cell.y, false, Image.FORMAT_RGB8)
		blank.fill(Color.BLACK)
		cells.append(blank)
	h.sf.dead[0] = false
	h.sf.in_fight = false
	for n in fx_nodes:
		n.queue_free()
	h.pos = Vector3.ZERO
	h.vel = Vector3.ZERO
	h.sf.pos[0] = Vector2.ZERO
	tgt.position = tgt_rest
	tgt.rotation = Vector3.ZERO
	tgt.scale = Vector3.ONE
	h.sf.step()
	h.run(0.5)
	return {"cells": cells, "meas": meas}

## Stand-in for the target's own action layer in the strips: the capsule recoils, is pulled and shaken, squashes.
func _target_fx(tgt: MeshInstance3D, rest: Vector3, id: String, t: float) -> void:
	if t < 0.0:
		return
	if id == "charge":
		var d := 0.55 * (1.0 - exp(-9.0 * t)) * (1.0 - 0.3 * smoothstep(0.4, 1.2, t))
		tgt.position = rest + Vector3(0, 0, d)
		tgt.rotation = Vector3(0.5 * exp(-2.5 * t) * cos(5.0 * t), 0, 0.12 * exp(-2.0 * t) * sin(9.0 * t))
		var sq := 1.0 - 0.18 * exp(-8.0 * t)
		tgt.scale = Vector3(1.0 / sqrt(sq), sq, 1.0 / sqrt(sq))
	elif id == "bite":
		var env := smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(0.18, 0.3, t))
		tgt.position = rest + Vector3(0.05 * sin(TAU * 11.0 * t) * env, 0, -0.3 * env)
		tgt.rotation = Vector3(-0.1 * env, 0, 0.06 * sin(TAU * 11.0 * t + 1.0) * env)
