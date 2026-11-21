extends SceneTree
# Close-up evidence of the three things the e2e bot cannot frame well at speed: the fossil bed before digging, the dig and its hole,
# and the flamethrower on a target. Evidence runs only: it uses a debug teleport and spawn to stage the shots (the e2e bot uses none).
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 60 --resolution 1280x720 --path godot \
#     --script res://game/tests/first_quest_evidence.gd -- <out-dir>

var game
var island
var sui
var ui
var out := ""
var n := 0

func frames(k: int) -> void:
	for i in k:
		await process_frame

func tick() -> int:
	return int(game.stage.cur.tick)

func ticks(k: int) -> void:
	var t0 := tick()
	var g := 0
	while tick() - t0 < k and g < k * 40 + 400:
		await process_frame
		g += 1

func shot(name: String) -> void:
	await frames(12)
	n += 1
	DirAccess.make_dir_recursive_absolute(out)
	root.get_texture().get_image().save_png("%s/f%02d_%s.png" % [out, n, name])

func key(code: Key) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = p
		root.push_input(e)

func face(x: float, z: float) -> void:
	var me: Dictionary = game.stage.cur.entities[0]
	var d := Vector2(x - float(me.x), z - float(me.z)).normalized()
	game.stage.queue_order({"verb": 3, "hx": int(d.x * 32767), "hz": int(d.y * 32767)})
	game.stage.queue_order({"verb": 1})

func _initialize() -> void:
	out = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/fq"
	_run.call_deferred()

func _scene_is(s: String) -> bool:
	return current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with(s)

func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1280, 720)
	game.persist_settings = false
	game.settings.seed = 1
	game.settings.grass = 3000
	game.settings.wild = true
	game.settings.herds = true
	game.settings["onboarding"] = 0x1ff
	change_scene_to_file("res://game/main.tscn")
	while not _scene_is("main_menu.gd"):
		await process_frame
	current_scene.play_button.pressed.emit()
	while not _scene_is("island.gd"):
		await process_frame
	island = current_scene
	await frames(5)
	sui = island.stage_ui
	ui = sui.ui
	var st = game.stage
	var bed: Dictionary = st.cur.dig.beds[0]
	var bx: float = bed.x
	var bz: float = bed.z
	# 1. the bed from 7 m, facing it
	st.debug_now({"op": 1, "id": 0, "x": bx - 7.0, "z": bz})
	face(bx, bz)
	await ticks(4)
	st.timescale = 1.0
	await frames(90)
	await shot("bed_cues")
	# 2. closer: the key label and the chip; then dig
	st.debug_now({"op": 1, "id": 0, "x": bx - 2.0, "z": bz})
	face(bx, bz)
	await ticks(4)
	await frames(60)
	await shot("bed_close_with_key")
	key(KEY_X)
	await ticks(12)
	await shot("digging")
	await ticks(14)
	await frames(20)
	await shot("hole_and_find")
	# 3. the editor: the gland on the body
	sui.open_nest_editor()
	await frames(10)
	var editor = null
	for c in island.get_children():
		if c is CanvasLayer:
			for k in c.get_children():
				if "nest_world" in k and k.nest_world != null:
					editor = k
	editor.model.add_part("fire_gland")
	editor._nest_refresh()
	await frames(20)
	await shot("editor_gland")
	editor.nest_evolve_button.pressed.emit()
	await frames(40)
	# 4. the flame on a creature
	var me: Dictionary = st.cur.entities[0]
	st.debug_now({"op": 2, "a": 0, "x": float(me.x) + 3.5, "z": float(me.z)})
	await ticks(3)
	var id: int = st.cur.entities.size() - 1
	st.debug_now({"op": 1, "id": 0, "x": float(me.x), "z": float(me.z)})
	face(float(st.cur.entities[id].x), float(st.cur.entities[id].z))
	await ticks(3)
	sui.select_id(id)
	ui.set_mode(&"attack")
	var slot := int(st.cur.loadout.slots.find(6))
	ui._press(slot)
	var g := 0
	while g < 600 and not (st.cur.combat.fighters.size() > 0 and int(st.cur.combat.fighters[0].move) == 14 and int(st.cur.combat.fighters[0].phase) == 1):
		ui._press(slot)
		await frames(2)
		g += 1
	await frames(14)
	await shot("flame_windup")
	while g < 900 and not (int(st.cur.combat.fighters[0].phase) == 2):
		await frames(1)
		g += 1
	await frames(3)
	await shot("flame_cone")
	await frames(10)
	await shot("flame_cone_2")
	await ticks(12)
	await shot("burning")
	print("first quest evidence: %d frames in %s" % [n, out])
	quit(0)
