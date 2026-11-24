extends SceneTree
## Creator scorecard replay (docs/briefs/creator-score.md): a deterministic scripted session in the real editor, captured at the
## moments the reference video shows (docs/evidence/godot/creator-score/reference.json).
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 --path godot \
##     --script res://studio/tests/creator_replay.gd -- <out_dir>
## Fixed starter (Merodeador), fixed part (placa), fixed pointer path: no randomness anywhere. Time is frame count / 30 (fixed-fps).
## Per moment it writes <moment>.jpg (what the player sees), <moment>_mask.png (creature on a flat key colour, scenery and UI hidden)
## and <moment>_ui.png (UI only on the key colour). replay.json holds the moments, the event log and per-frame wall times.
## Events come from Studio.creator_event; an event the editor never emits is reported absent by tools/creator/score.py (it fails, no crash).
## Optional probe: Studio.creator_probe() -> {vertebra_spheres: int, part_ring: bool, popup: bool, head_target: Vector3}.

const Studio := preload("../ui/studio.gd")
const FPS := 30.0
const KEY := Color(1, 0, 1)
const PART := "placa"
const STARTER := "Merodeador"

var ui
var m
var out := "/tmp"
var frame := 0
var events: Array = []
var moments: Dictionary = {}
var actions: Dictionary = {}
var frame_ms: Array = []
var _last_us := 0
var _probe_log: Array = []

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	process_frame.connect(_on_frame)
	_run()

func _on_frame() -> void:
	frame += 1
	var now := Time.get_ticks_usec()
	if _last_us > 0:
		frame_ms.append(snappedf((now - _last_us) / 1000.0, 0.01))
	_last_us = now
	if ui != null:
		_probe_log.append([frame, _probe()])

func _t() -> float:
	return snappedf(frame / FPS, 0.001)

func _ev(name: String, data: Dictionary) -> void:
	events.append({"t": _t(), "frame": frame, "name": name, "data": data})

func _probe() -> Dictionary:
	if ui.has_method("creator_probe"):
		return ui.creator_probe()
	return {"vertebra_spheres": 0, "part_ring": false, "popup": false}

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _scr(v: Vector3) -> Vector2:
	return ui.camera.unproject_position(v)

func _mm(pos: Vector2, rel := Vector2.ZERO) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	return e

func _mb(pos: Vector2, pressed: bool, idx := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = pos
	e.global_position = pos
	e.button_index = idx
	e.pressed = pressed
	return e

func _move(pos: Vector2, rel := Vector2.ZERO) -> void:
	ui._stage_input(_mm(pos, rel))

func _press(pos: Vector2) -> void:
	ui._stage_input(_mb(pos, true))

func _release(pos: Vector2) -> void:
	ui._stage_input(_mb(pos, false))

func _wheel(pos: Vector2, up: bool) -> void:
	_move(pos)
	ui._stage_input(_mb(pos, true, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN))

# ------------------------------------------------------------------ capture passes
var _env_hidden: Array = []
var _env_saved: Environment

func _mask_on() -> void:
	ui.hud.visible = false
	ui.overlay.visible = false
	ui._ghost.visible = false
	var env: Node = ui.env_node
	for c in env.get_children():
		if c is Node3D and c != env.world_env and c != env.sun and c.visible:
			c.visible = false
			_env_hidden.append(c)
	_env_saved = env.world_env.environment
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = KEY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = .6
	env.world_env.environment = e

func _mask_off() -> void:
	for c in _env_hidden:
		c.visible = true
	_env_hidden.clear()
	ui.env_node.world_env.environment = _env_saved
	ui.hud.visible = true
	ui.overlay.visible = true

func _ui_on() -> void:
	ui.stage.visible = false
	RenderingServer.set_default_clear_color(KEY)

func _ui_off() -> void:
	ui.stage.visible = true
	RenderingServer.set_default_clear_color(Color(0.3, 0.3, 0.3))

func _save(img: Image, name: String, jpg: bool) -> void:
	var path := out.path_join(name + (".jpg" if jpg else ".png"))
	if jpg:
		img.save_jpg(path, 0.9)
	else:
		img.save_png(path)

func _shot(moment: String) -> void:
	await _frames(2)
	var vs := root.get_visible_rect().size
	_save(root.get_texture().get_image(), moment, true)
	var cam_f: Vector3 = -ui.camera.global_transform.basis.z
	var cre_f: Vector3 = ui.view.global_transform.basis * Vector3(0, 0, 1)   # the head is at +Z in view space
	var info := {"facing_deg": snappedf(rad_to_deg(cam_f.angle_to(cre_f)), 0.1), "t": _t(), "frame": frame, "pitch_deg": snappedf(rad_to_deg(ui._pitch), 0.1), "yaw_deg": snappedf(rad_to_deg(ui._yaw), 0.1),
		"dist": snappedf(ui._dist, 0.01), "probe": _probe(), "parts": m.doc["parts"].size(), "nodes": m.doc["nodes"].size(), "dna": ui.dna_value(),
		"viewport": [int(vs.x), int(vs.y)], "grass_visible": ui.env_node.grass != null and ui.env_node.grass.visible,
		"rocks_visible": ui.env_node.rocks != null and ui.env_node.rocks.visible}
	_mask_on()
	await _frames(3)
	_save(root.get_texture().get_image(), moment + "_mask", false)
	_mask_off()
	_ui_on()
	await _frames(3)
	_save(root.get_texture().get_image(), moment + "_ui", false)
	_ui_off()
	await _frames(2)
	moments[moment] = info
	print("shot ", moment, " ", info["pitch_deg"], " probe ", info["probe"])

# ------------------------------------------------------------------ the session
func _run() -> void:
	ui = Studio.new()
	root.add_child(ui)
	await _frames(8)
	m = ui.model
	ui.creator_event.connect(func(n, d): _ev(n, d))
	m.new_from_seed(STARTER)
	ui.frame_creature()
	m.select(-1)
	await _frames(12)
	_move(Vector2(20, 20))
	await _frames(4)
	actions["open"] = _t()
	await _shot("start")
	# spine hover: the pointer rests on the body, spine handles should appear
	var pts: PackedVector3Array = ui.view.spine_node_positions()
	var body := _scr(pts[4])
	actions["hover_start"] = _t()
	for i in range(1, 13):
		_move(Vector2(20, 20).lerp(body, float(i) / 12.0))
		await process_frame
	actions["hover_body"] = _t()
	await _frames(14)
	await _shot("spine_hover")
	# part picked: press the palette tile, drag it from the empty stage onto the body
	_move(Vector2(20, 20))
	await _frames(2)
	var tgt := _scr(pts[3] + Vector3(0, 0.6, 0))
	var start := Vector2(ui.stage.size.x * 0.82, 120.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	ui._palette_input(press, PART)
	ui._drag["start"] = Vector2(-1000, -1000)
	ui._drag["moved"] = true
	actions["pick"] = _t()
	var gp0: Vector2 = ui.stage.global_position
	for i in range(0, 11):
		var p := start.lerp(tgt, float(i) / 10.0)
		ui._update_new_drag(gp0 + p)
		ui._mouse = gp0 + p
		await process_frame
	actions["over_body"] = _t()
	await _frames(4)
	await _shot("part_picked")
	# part dropped
	actions["drop"] = _t()
	ui._finish_new_drag(gp0 + tgt)
	var placed: int = m.doc["parts"].size() - 1
	await _frames(3)
	await _shot("part_dropped")
	await _frames(40)    # the editor's own feedback (puff, +N popup, head turn) plays out; the probe log samples it
	# spine drag: grab a vertebra, move it, capture mid-drag
	pts = ui.view.spine_node_positions()
	var vn := _scr(pts[2])
	_move(vn)
	await _frames(8)
	actions["spine_press"] = _t()
	_press(vn)
	var up := Vector2(10, -70)
	for i in range(1, 9):
		_move(vn + up * (float(i) / 8.0), up / 8.0)
		await process_frame
		if i == 5:
			await _shot("spine_drag")
	_release(vn + up)
	actions["spine_release"] = _t()
	await _frames(10)
	# part rotate + scale: select the new part, drag the rotation bead, wheel up twice
	m.select(placed)
	await _frames(10)
	var hs: Dictionary = ui._handles()
	actions["rotate_start"] = _t()
	if hs.has("rot"):
		var a: Vector2 = hs["rot"]
		var c: Vector2 = hs["c"]
		_move(a)
		await _frames(3)
		_press(a)
		for i in range(1, 9):
			var ang := float(i) * 0.12
			_move(c + (a - c).rotated(ang))
			await process_frame
		_release(c + (a - c).rotated(0.96))
	await _frames(6)
	var pc: Vector2 = ui._handles().get("c", body)
	_wheel(pc, true)
	_wheel(pc, true)
	actions["scale"] = _t()
	await _frames(10)
	await _shot("part_rotate")
	# final: the paint step
	m.select(-1)
	ui.set_mode("paint")
	await _frames(20)
	actions["final"] = _t()
	await _shot("final")
	var fm := frame_ms.duplicate()
	fm.sort()
	var f := FileAccess.open(out.path_join("replay.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"fps": FPS, "starter": STARTER, "part": PART, "viewport": moments["start"]["viewport"], "moments": moments,
		"actions": actions, "events": events, "frame_ms_median": fm[fm.size() / 2], "frame_ms_p95": fm[int(fm.size() * 0.95)], "frames": fm.size(),
		"has_probe": ui.has_method("creator_probe"), "probe_log": _probe_log_changes()}, "  "))
	f.close()
	print("replay done: ", events.size(), " events, median frame ms ", fm[fm.size() / 2])
	quit()

## The probe log reduced to its changes ([frame, probe] only when the value differs from the previous frame).
func _probe_log_changes() -> Array:
	var res: Array = []
	var last = null
	for e in _probe_log:
		if last == null or e[1] != last:
			res.append([e[0], e[1]])
			last = e[1]
	return res
