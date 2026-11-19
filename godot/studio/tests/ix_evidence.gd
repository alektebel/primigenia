extends SceneTree
## Evidence frames for the creator direct manipulation, through the real input path:
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --rendering-driver opengl3 --path godot --script res://studio/tests/ix_evidence.gd -- <out_dir>

const Studio := preload("../ui/studio.gd")
var ui
var m
var out := "/tmp"
var n := 0

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	ui = Studio.new()
	root.add_child(ui)
	await _frames(8)
	m = ui.model
	m.new_from_seed("Merodeador")
	m.select(-1)
	await _frames(10)
	# 1 wheel over an eye
	var eye := 1
	var p := _scr(ui.view.part_anchor(eye)["pos"])
	_move(p)
	await _frames(6)
	await _shot("wheel", "0-hover")
	for i in 5:
		_wheel(p, true)
		await _frames(2)
	await _shot("wheel", "1-grow")
	for i in 80:
		_wheel(p, true)
	await _frames(3)
	await _shot("wheel", "2-limit")
	m.undo()
	m.select(-1)
	# 2 joint drag on a leg
	m.new_from_seed("Merodeador")
	await _frames(10)
	var leg := 3
	var mid := _leg_mid(leg)
	_move(mid)
	await _frames(8)
	await _shot("joint", "0-hover-handles")
	var knee := _joint(leg, "k")
	_move(knee)
	_press(knee)
	await _frames(3)
	for i in 8:
		knee += Vector2(4, -3)
		_move(knee, Vector2(4, -3))
		await _frames(2)
		if i == 3:
			await _shot("joint", "1-dragging")
	_release(knee)
	await _frames(6)
	await _shot("joint", "2-dropped")
	# 3 spine arrows
	m.new_from_seed("Merodeador")
	m.select(-1)
	await _frames(10)
	var pts: PackedVector3Array = ui.view.spine_node_positions()
	var body := _scr(pts[4])
	_move(Vector2(30, 30))
	_move(body)
	await _frames(30)
	await _shot("spine", "0-hover-arrows")
	var arr: Dictionary = ui.spine_arrows()
	var head: Vector2 = arr["head"]["pos"]
	for i in range(1, 7):
		_move(body.lerp(head, float(i) / 6.0))
	await _frames(4)
	await _shot("spine", "1-head-arrow-hot")
	_press(head)
	var d: Vector2 = arr["head"]["dir"]
	var cur := head
	for i in 10:
		cur += d * 12.0
		_move(cur, d * 12.0)
		await _frames(2)
		if i == 5:
			await _shot("spine", "2-extending")
	_release(cur)
	await _frames(6)
	await _shot("spine", "3-extended")
	# tail
	_move(Vector2(30, 30))
	_move(body)
	await _frames(30)
	arr = ui.spine_arrows()
	var tail: Vector2 = arr["tail"]["pos"]
	for i in range(1, 7):
		_move(body.lerp(tail, float(i) / 6.0))
	_press(tail)
	cur = tail
	for i in 10:
		cur += arr["tail"]["dir"] * 12.0
		_move(cur, arr["tail"]["dir"] * 12.0)
		await _frames(2)
	_release(cur)
	await _frames(6)
	await _shot("spine", "4-tail-extended")
	# 4 actuator ring
	m.new_from_seed("Merodeador")
	m.select(-1)
	await _frames(10)
	mid = _leg_mid(leg)
	_move(mid)
	await _frames(4)
	_press(mid)
	_release(mid)
	await _frames(1)
	await _shot("ring", "0-opening")
	await create_timer(.3).timeout
	await _frames(3)
	await _shot("ring", "1-open")
	var ring = ui._ring
	var hy: Vector2 = ring.button_center(3)
	ring._gui_input(_mm(hy))
	await _frames(3)
	await _shot("ring", "2-hover-hydrostat")
	ring._gui_input(_mb(hy, true))
	ring._gui_input(_mb(hy, false))
	await _frames(8)
	await _shot("ring", "3-applied")
	# armoured body: all four available
	m.new_from_seed("Merodeador")
	m.add_part("placa", .3, 0.0)
	m.add_part("placa", .5, 0.0)
	m.select(-1)
	await _frames(10)
	mid = _leg_mid(leg)
	_move(mid)
	await _frames(4)
	_press(mid)
	_release(mid)
	await create_timer(.3).timeout
	await _frames(3)
	await _shot("ring", "4-armoured-all-four")
	quit()

func _scr(v: Vector3) -> Vector2:
	return ui.camera.unproject_position(v)

func _leg_mid(i: int) -> Vector2:
	for h in ui.view.leg_handles(i):
		if h.joint == "k" and h.side == 1:
			return _scr((h.hip + h.pos) * .5)
	return Vector2.ZERO

func _joint(i: int, j: String) -> Vector2:
	for h in ui._joint_handles():
		if h["joint"] == j and h["side"] == 1:
			return h["screen"]
	return Vector2.ZERO

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
	ui._stage_input(_mm(pos))
	ui._stage_input(_mb(pos, true, MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN))

func _frames(k: int) -> void:
	for i in k:
		await process_frame

func _shot(group: String, name: String) -> void:
	await _frames(2)
	var img := root.get_texture().get_image()
	var path := out.path_join("%s-%s.png" % [group, name])
	img.save_png(path)
	print("saved ", path, " ", img.get_size())
