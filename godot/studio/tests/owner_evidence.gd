extends SceneTree
## Evidence frames for the owner tweaks (A31): default framing with both spine arrows, the dimmed ring choice with its reason,
## the spine end generating vertebrae at the natural spacing, and a vertebra drag with a soft chain.
##   xvfb-run -a env LIBGL_ALWAYS_SOFTWARE=1 godot --rendering-driver opengl3 --path godot --script res://studio/tests/owner_evidence.gd -- <out_dir>

const Studio := preload("../ui/studio.gd")
var ui
var m
var out := "/tmp"

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	ui = Studio.new()
	root.add_child(ui)
	await _frames(8)
	m = ui.model
	# 7 framing: the default view, both arrows inside the free area
	m.new_from_seed("Merodeador")
	ui.frame_creature()
	m.select(-1)
	await _frames(10)
	var pts: PackedVector3Array = ui.view.spine_node_positions()
	var body := _scr(pts[4])
	_move(Vector2(30, 30))
	_move(body)
	await _frames(30)
	await _shot("framing", "0-both-arrows-free")
	# 8 growing end
	var arr: Dictionary = ui.spine_arrows()
	var head: Vector2 = arr["head"]["pos"]
	for i in range(1, 25):
		_move(body.lerp(head, float(i) / 24.0))
	await _frames(4)
	_press(head)
	var d: Vector2 = arr["head"]["dir"]
	var cur := head
	var n0: int = m.doc["nodes"].size()
	for i in 14:
		cur += d * 10.0
		_move(cur, d * 10.0)
		await _frames(2)
		if i == 2 or i == 7 or i == 13:
			await _shot("grow", "%d-%d-vertebrae" % [i, m.doc["nodes"].size()])
	_release(cur)
	await _frames(4)
	await _shot("grow", "9-released-%d-from-%d" % [m.doc["nodes"].size(), n0])
	# 9 soft chain
	m.new_from_seed("Merodeador")
	ui.frame_creature()
	m.select(-1)
	await _frames(10)
	pts = ui.view.spine_node_positions()
	var mid_i: int = pts.size() / 2
	var at := _scr(pts[mid_i])
	_move(at)
	await _frames(25)
	await _shot("chain", "0-before")
	_press(at)
	cur = at
	for i in 10:
		cur += Vector2(6, -9)
		_move(cur, Vector2(6, -9))
		await _frames(2)
		if i == 4 or i == 9:
			await _shot("chain", "%d-dragging" % (i + 1))
	_release(cur)
	await _frames(4)
	await _shot("chain", "9-released")
	# 6 ring: hover a dimmed choice
	m.new_from_seed("Merodeador")
	ui.frame_creature()
	m.select(-1)
	await _frames(10)
	var leg := 3
	var lmid := _leg_mid(leg)
	_move(lmid)
	await _frames(4)
	_press(lmid)
	_release(lmid)
	await create_timer(.3).timeout
	await _frames(3)
	var ring = ui._ring
	ring._gui_input(_mm(ring.button_center(1)))
	await _frames(3)
	await _shot("ring", "0-why-es")
	ui._close_ring()
	ui.set_lang("en")
	await _frames(4)
	_move(lmid)
	_press(lmid)
	_release(lmid)
	await create_timer(.3).timeout
	await _frames(3)
	ring = ui._ring
	ring._gui_input(_mm(ring.button_center(2)))
	await _frames(3)
	await _shot("ring", "1-why-en")
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
