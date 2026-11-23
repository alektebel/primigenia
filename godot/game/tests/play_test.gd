extends SceneTree
# make godot-play-test: the whole game, headless.
#   main -> menu -> Play -> stage: real creatures, loco, HUD, audio, selection, radial, an encounter;
#   rig contract (six adapter points) on the real rig; studio: real view, add a part, save; back to Play uses it.
# godot --headless --fixed-fps 60 --path godot --script res://game/tests/play_test.gd
# (the studio saves into user://play-test, never into the real user://studio)

const Morph := preload("res://locomotion/loco_morphology.gd")
const Ctl := preload("res://locomotion/loco_controller.gd")
const Adapter := preload("res://locomotion/loco_rig_adapter.gd")
const Profile := preload("res://game/stage/profile.gd")
const WorldLog := preload("res://game/stage/world_log.gd")

class ErrorLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])

var checks := 0
var failures := 0
var log := ErrorLog.new()
var game
var events_seen := 0
var windup_seen := false
var damage_seen := 0
var flash_seen := false
var footfalls := 0
var min_player_hp := 1e9
var min_enemy_hp := 1e9

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func frames(n: int) -> void:
	for i in n:
		await process_frame

# Wait for `ticks` C-world ticks (0.1 s each), drawing nothing special; bounded by a frame budget.
func sim_ticks(ticks: int, budget := 6000) -> void:
	var t0: int = game.stage.cur.tick
	var n := 0
	while game.stage.cur.tick - t0 < ticks and n < budget:
		await process_frame
		n += 1

func until(cond: Callable, budget := 1800) -> bool:
	var n := 0
	while not cond.call() and n < budget:
		await process_frame
		n += 1
	return cond.call()

## Like until, with a wall-clock budget: the island builds under a loading screen on worker threads (seconds, however many frames spin).
func until_ms(cond: Callable, budget_ms := 90000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < budget_ms:
		await process_frame
	return cond.call()

func _initialize() -> void:
	OS.add_logger(log)
	_run.call_deferred()

func _finish() -> void:
	check(log.errors.is_empty(), "no errors during the whole run (%d: %s)" % [log.errors.size(), str(log.errors.slice(0, 3))])
	OS.remove_logger(log)
	print("play test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _run() -> void:
	game = root.get_node("Game")
	var studio_dir := "user://play-test"
	_clean(studio_dir)
	game.studio_dir = studio_dir
	root.size = Vector2i(1280, 720)
	game.persist_settings = false
	game.legacy_path = "user://cell_legacy_play_test_none.json"     # the owner's real legacy would be applied by the menu's new game
	game.settings.grass = 3000
	for a in OS.get_cmdline_user_args():
		game.settings.quality = a      # make godot-play-test QUALITY=low|medium|high|auto forces the rock tier
	game.settings.wild = true
	await _rig_contract()
	await _stage()
	await _studio_and_back()
	_clean(studio_dir)
	_finish()

func _clean(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			d.remove(f)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))

# ------------------------------------------------------------------------------------------------
# 1. The adapter's six contract points on the real Creature rig
# ------------------------------------------------------------------------------------------------
func _rig_contract() -> void:
	print("== rig contract (real godot/creature rig)")
	var seeds: Dictionary = Creature.seeds()
	var genomes := {"Merodeador": seeds.Merodeador, "Zancuda": seeds.Zancuda, "Babosa": seeds.Babosa,
		"Garfio": Profile.load_json("res://game/data/garfio.json")}
	for leg_type in ["pata", "zanca", "pezuna", "leg_sprinter", "leg_sucker", "foot_spring", "foot_hoof", "foot_gecko"]:
		var g: Dictionary = (seeds.Merodeador as Dictionary).duplicate(true)
		var parts: Array = g.parts.filter(func(p): return p.type != "pata")
		var proto := Creature.new()
		var base_leg: Dictionary = proto.default_part(leg_type)
		proto.free()
		base_leg["t"] = 0.5
		base_leg["ang"] = 2.1
		parts.append(base_leg)
		g.parts = parts
		genomes["Merodeador+" + leg_type] = g
	var tails := 0
	for name in genomes:
		var c := Creature.new()
		root.add_child(c)
		var res: Dictionary = c.load_genome(genomes[name])
		if not check(res.ok, "%s builds" % name):
			c.queue_free()
			continue
		var desc: Dictionary = Adapter.loco_describe(c, 1.0)
		check(desc.problems.is_empty(), "%s: points 1-6 hold (%s)" % [name, str(desc.problems)])
		var legged := c.legs.size() > 0
		# 4. hanging legs are not driven
		var walking := 0
		for l in c.legs:
			if l.hang <= Adapter.HANG_LIMIT:
				walking += 1
		check(desc.leg_ids.size() == walking, "%s: point 4, %d of %d legs are driven" % [name, desc.leg_ids.size(), c.legs.size()])
		# 5. masses: every non-leg part contributes a positive mass
		var mass_ok := true
		for p in desc.parts:
			mass_ok = mass_ok and p.mass > 0.0
		check(mass_ok, "%s: point 5, %d part masses positive" % [name, desc.parts.size()])
		var m = Morph.analyse(desc)
		if legged:
			check(m.hip_height > 0.02 and m.hip_height < 5.0, "%s: point 1, hip height %.2f m" % [name, m.hip_height])
		# 2. head ahead of the tail along +Z, sides agree with hip x
		check(desc.spine[-1].pos.z > desc.spine[0].pos.z, "%s: point 2, head in front of the tail along +Z" % name)
		await _walk_check(name, c, desc, m)
		if name == "Merodeador":
			await _bone_signs(c, desc, m)
		tails += 1
		c.queue_free()
	await frames(1)

# 3. soles: the IK reaches every planted target, flat-footed soles sit on the ground, nothing goes under it
func _walk_check(name: String, c, desc: Dictionary, m) -> void:
	var ctl = Ctl.new(m, func(_x, _z): return 0.0)
	ctl.reset(Vector3.ZERO, 0.0)
	var speed := 1.2 if m.legs.is_empty() else clampf(m.proposal.roam_speed, 0.5, 4.0)
	var worst_reach := 0.0
	var worst_flat := 0.0
	var lowest := 1e9
	var swing_feet := 0
	for i in 360:
		var dt := 1.0 / 60.0
		var p := Vector3(0, 0, speed * i * dt)
		ctl.step(dt, p, 0.0, Vector3(0, 0, speed))
		Adapter.loco_apply(c, ctl.pose, desc)
		if i < 90:
			continue
		for j in desc.leg_ids.size():
			var l = c.legs[desc.leg_ids[j]]
			var sole: Vector3 = l.foot.global_position
			lowest = minf(lowest, sole.y)
			if ctl.pose.contact[j]:
				worst_reach = maxf(worst_reach, (sole - l.foot_target).length())
				if ctl.pose.foot_pitch[j] < 0.01:
					worst_flat = maxf(worst_flat, absf(sole.y))
			else:
				swing_feet += 1
	if not desc.leg_ids.is_empty():
		check(worst_reach < 0.002, "%s: point 3, the IK reaches the planted soles (%.2f mm)" % [name, worst_reach * 1000.0])
		check(worst_flat < Adapter.SOLE_TOLERANCE + 0.001, "%s: point 3, flat-footed soles on the ground (%.2f mm)" % [name, worst_flat * 1000.0])
		check(lowest > -0.01, "%s: no foot below the ground (%.1f mm)" % [name, lowest * 1000.0])
		check(swing_feet > 0, "%s: feet really swing" % name)
	else:
		var box: AABB = c.rest_aabb()
		check(box.position.y > -0.02 and box.position.y < 0.12, "%s: legless body rests on the ground (lowest %.3f m)" % [name, box.position.y])
		var low := 1e9
		for v in ((c.body_mesh.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			low = minf(low, (c.body_mesh.global_transform * v).y)
		check(absf(low - Adapter.BELLY_GAP) < 0.02, "%s: belly %.3f m above the ground after the drop (want %.2f)" % [name, low, Adapter.BELLY_GAP])

# Sign conventions of the bone bends on the real skeleton (the adapter's unverified part).
func _bone_signs(c, desc: Dictionary, m) -> void:
	var ctl = Ctl.new(m, func(_x, _z): return 0.0)
	ctl.reset(Vector3.ZERO, 0.0)
	ctl.step(0.02, Vector3.ZERO, 0.0, Vector3.ZERO)
	var base: Dictionary = ctl.pose.duplicate(true)
	var sk: Skeleton3D = c.skeleton
	var res := {}
	for label in ["base", "neck_pitch", "neck_yaw", "tail_pitch", "tail_yaw"]:
		var p: Dictionary = base.duplicate(true)
		p.neck = {"pitch": 0.0, "yaw": 0.0, "roll": 0.0}
		p.tail = {"pitch": 0.0, "yaw": 0.0}
		match label:
			"neck_pitch": p.neck.pitch = 0.4
			"neck_yaw": p.neck.yaw = 0.4
			"tail_pitch": p.tail.pitch = 0.4
			"tail_yaw": p.tail.yaw = 0.4
		Adapter.loco_apply(c, p, desc)
		res[label] = {"head": sk.get_bone_global_pose(c.head_bone).origin, "tail": sk.get_bone_global_pose(c.tail_bones[0]).origin}
	check(res.neck_pitch.head.y > res.base.head.y + 0.1, "bones: neck pitch + lifts the head")
	check(res.neck_yaw.head.x > res.base.head.x + 0.1, "bones: neck yaw + turns the head toward +X (left)")
	check(res.tail_pitch.tail.y > res.base.tail.y + 0.1, "bones: tail pitch + lifts the tail tip")
	check(res.tail_yaw.tail.x < res.base.tail.x - 0.1, "bones: tail yaw + swings the tail tip toward -X")

# ------------------------------------------------------------------------------------------------
# 2. main -> menu -> Play -> stage
# ------------------------------------------------------------------------------------------------
func _scene_is(script_name: String) -> bool:
	# the island is entered through the loading screen and builds across frames: it counts once it is built
	if script_name == "island.gd" and current_scene != null and "_building" in current_scene and current_scene._building:
		return false
	return current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with(script_name)

func _press(button: Button) -> void:
	button.pressed.emit()

func _stage() -> void:
	print("== boot main -> menu")
	change_scene_to_file("res://game/main.tscn")
	check(await until(func(): return _scene_is("main_menu.gd"), 3000), "main boots to the menu")
	var menu = current_scene
	check(menu.play_button != null and menu.creator_button != null, "menu has Play and Creator")
	_press(menu.play_button)
	check(await until_ms(func(): return _scene_is("island.gd")), "Play opens the stage")
	var island = current_scene
	await frames(5)
	var ui = island.stage_ui.ui
	check(ui != null and ui.signs != null and ui.ring != null, "the diegetic UI is mounted")
	check(root.has_node("Audio"), "the Audio autoload exists")
	check(AudioServer.get_bus_index("SFX") >= 0 and AudioServer.get_bus_index("Ambience") >= 0, "the bus layout (Master, Music, SFX, Ambience) is present")
	var player = island.hosts[0]
	var wild = island.hosts[1]
	check(player.uses_module and wild.uses_module, "player and Garfio are real creatures (not placeholders)")
	check(player.driver.controller != null and wild.driver.controller != null, "both are driven by locomotion")
	check(player.driver.problems.is_empty() and wild.driver.problems.is_empty(), "the adapter reports no contract problem for them")
	check(player.body.genome.get("name", "") == game.player_genome().get("name", "?"), "the player is the genome Play resolves (%s)" % player.body.genome.get("name", ""))
	for h in island.hosts.values():
		h.footfall.connect(func(_id, _p, _s): footfalls += 1)
	game.combat_events.connect(func(ev: Array):
		events_seen += ev.size()
		if OS.get_environment("PLAY_TEST_VERBOSE") != "":
			print("  events@", game.stage.cur.tick, " ", ev, " player hp ", game.stage.cur.entities[0].hp, " st ", game.stage.cur.entities[0].stamina))
	game.settings["numbers"] = true         # damage numbers exist only with Numbers: On
	var watch := _watch_tick.bind(ui, island)
	game.world_ticked.connect(watch)
	if OS.get_environment("PLAY_TEST_VERBOSE") != "":
		game.world_ticked.connect(func(st: Dictionary):
			if st.order.verb > 1 and st.active >= 0:
				print("  tick ", st.tick, " order ", st.order, " accepted ", st.accepted, " err ", st.error, " p.st ", st.entities[0].stamina, " fighters ", st.combat.fighters.map(func(f): return [f.move, f.phase, snappedf(f.x, 0.01), snappedf(f.z, 0.01), snappedf(f.fx, 0.01), snappedf(f.fz, 0.01)])))
	var hp_before: float = game.stage.cur.entities[0].hp
	var hp_max0: float = game.stage.cur.entities[0].hp_max
	check(absf(ui.signs.hp_frac - hp_before / hp_max0) < 0.01, "the health line shows the player's HP (%.3f for %.1f / %.1f)" % [ui.signs.hp_frac, hp_before, hp_max0])
	check(ui.player_name == player.body.genome.get("name", ""), "the UI knows the creature's name (it is the journal's, not a HUD label)")

	print("== loadout (A21): the hotbar follows the C loadout; keys 1-4 fire slots; the panel at the nest")
	var sui = island.stage_ui
	ui.set_mode(&"attack")            # no default mode: the loadout slots show once Attack is chosen
	var lo0: Dictionary = game.stage.cur.loadout
	# A25: a new run starts with the starter parts (pico, pata, ojo): it knows bite, spit and peck (parts decide what a creature can slot)
	check(lo0.slots == [0, 3, 7, 10] and lo0.can_edit and int(lo0.known) == 3209, "the player starts at the nest with its default loadout (%s, known %d)" % [lo0.slots, lo0.known])
	check(ui.abilities.size() == 4 and ui.abilities[0].move == 0 and ui.abilities[1].move == 3 and ui.abilities[2].move == 7, "the hotbar carries the C move ids of the slots")
	check(ui.petals.id_at(0) == "bite" and ui.petals.glyph_at(0) == "bite" and ui.petals.id_at(1) == "spit" and ui.petals.id_at(3) != "" and ui.petals.state_at(3) != &"empty", "the petals show the glyph of each loadout move, the fourth slot carries the starter's own move (%s / %s)" % [ui.petals.id_at(0), ui.petals.id_at(1)])
	sui.assign_loadout(0, 3)                  # spit into slot 1: bite is displaced out of the loadout
	await sim_ticks(2)
	check(game.stage.cur.loadout.slots == [3, -1, 7, 10], "a loadout order reached C and moved the move (%s)" % [game.stage.cur.loadout.slots])
	check(ui.petals.id_at(0) == "spit" and ui.petals.state_at(1) == &"empty", "the petals rebuilt: slot 1 is the spit, slot 2 empty")
	sui.assign_loadout(2, 4)                  # tail_strike: this creature has no tail, C says not_known
	await sim_ticks(1)                        # (the next tick's walking input would overwrite the error)
	check(game.stage.cur.loadout.slots == [3, -1, 7, 10] and game.stage.world.order_error(int(game.stage.cur.error)) == "not_known", "a move the body cannot do is refused by C (%s)" % game.stage.world.order_error(int(game.stage.cur.error)))
	sui.selected_id = 1
	var orders0: int = sui.attack_orders.size()
	_key(KEY_1)
	check(sui.attack_orders.size() > orders0 and str(sui.attack_orders.back().order) == "attack #1 spit", "key 1 fires the move in slot 1 (%s)" % [sui.attack_orders.back()])
	sui._pending_attack = null
	orders0 = sui.attack_orders.size()
	_key(KEY_2)
	check(sui.attack_orders.size() == orders0, "key 2 on an empty slot fires nothing")
	sui.toggle_loadout_panel()
	check(ui.loadout_panel.visible_open and game.modal_open == false, "the panel opens at the nest (key L)")
	await frames(2)
	check(game.modal_open, "an open panel blocks movement input (modal_open)")
	ui.loadout_panel.choose(0, 0)
	ui.loadout_panel.choose(1, 3)
	await sim_ticks(3)
	check(game.stage.cur.loadout.slots == [0, 3, 7, 10], "the panel restored the default through C orders (%s)" % [game.stage.cur.loadout.slots])
	ui.loadout_panel.close_panel()
	await frames(2)
	sui.selected_id = -1
	ui.set_mode(&"")

	print("== walk 6 s with scripted input")
	var start: Vector3 = island.player_pos
	var played0: int = int(root.get_node("Audio").played.get("step-0", 0)) + int(root.get_node("Audio").played.get("step-1", 0)) + int(root.get_node("Audio").played.get("step-2", 0))
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	var t0: int = game.stage.cur.tick
	# 6 s, not 10: on the current island the player faces the den of the hunting Garfio 60 m away, which charges at the
	# player; at 10 s the fight has already started and the select-and-ring steps below see an active encounter.
	await sim_ticks(60)
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	var moved := Vector2(island.player_pos.x - start.x, island.player_pos.z - start.z).length()
	check(game.stage.cur.tick - t0 >= 60, "6 s of game time passed (%d ticks)" % (game.stage.cur.tick - t0))
	check(moved > 3.0, "the player walked %.1f m (A39: a body walks at Fr 0.24, the starter about 1 m/s)" % moved)
	check(footfalls >= 6, "locomotion produced %d foot contacts" % footfalls)
	var played1: int = int(root.get_node("Audio").played.get("step-0", 0)) + int(root.get_node("Audio").played.get("step-1", 0)) + int(root.get_node("Audio").played.get("step-2", 0))
	check(played1 > played0, "footstep sounds played (%d)" % (played1 - played0))
	var lowest := 1e9
	for l in player.body.legs:
		lowest = minf(lowest, l.foot.global_position.y - game.visual_ground(l.foot.global_position.x, l.foot.global_position.z))
	check(lowest > -0.03, "feet are on the visible ground, Game.visual_ground (lowest %.1f mm relative)" % (lowest * 1000.0))
	check(absf(player.position.y - game.ground(player.position.x, player.position.z)) < 0.25, "the actor stands on Game.ground (within the owner style sprawl crouch, A42)")

	print("== pause menu: save game / load game")
	var Scenario = load("res://devtools/scenario.gd")
	Scenario.save_dir = "user://play-test/saves"
	_clean(Scenario.save_dir)
	var gui = island.stage_ui.ui
	gui.set_paused(true)
	check(not gui.menu.item_enabled("load") and gui.menu.open, "Load is unavailable while the slot is empty")
	var hash_saved: String = game.stage.world.hash()
	var tick_saved: int = game.stage.cur.tick
	gui.menu.activate("save")
	check(FileAccess.file_exists(Scenario.save_dir + "/slot1.json") and FileAccess.file_exists(Scenario.save_dir + "/slot1.cpstate"), "Save game writes the slot")
	check(not gui.paused, "saving returns to the game")
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": true}
	await sim_ticks(40)
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	check(game.stage.world.hash() != hash_saved, "the world moved on after saving")
	gui.set_paused(true)
	check(gui.menu.item_enabled("load"), "Load is available once the slot exists")
	gui.menu.activate("load")
	check(game.stage.world.hash() == hash_saved and game.stage.cur.tick == tick_saved, "Load game restores the saved state (tick %d)" % game.stage.cur.tick)
	check(not gui.paused, "loading returns to the game")
	await frames(2)
	check(absf(island.player_pos.x - game.stage.cur.entities[0].x) < 3.0, "the actor follows the restored creature")
	_clean(Scenario.save_dir)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://play-test/saves"))
	Scenario.save_dir = "user://saves"

	print("== camera: the left button never moves the camera (brief creature-fixes 1)")
	var yaw_before: float = island.chase.yaw
	var pitch_before: float = island.chase.orbit_pitch
	var zt_before: float = island.chase.z_target
	island.player_input.clear_destination()
	await _drag(Vector2(640, 500), Vector2(720, 420))
	await frames(2)
	check(island.chase.yaw == yaw_before and island.chase.orbit_pitch == pitch_before, "a left drag does not orbit the camera (yaw %.3f -> %.3f)" % [yaw_before, island.chase.yaw])
	check(island.player_input.destination == null, "a left drag does not set a destination")
	var dbl := InputEventMouseButton.new()
	dbl.position = Vector2(640, 500)
	dbl.button_index = MOUSE_BUTTON_LEFT
	dbl.pressed = true
	dbl.double_click = true
	root.push_input(dbl)
	dbl.pressed = false
	root.push_input(dbl)
	await frames(2)
	check(island.chase.z_target == zt_before, "a left double click does not zoom")
	_click(Vector2(640, 520))
	await frames(2)
	check(island.chase.mouse_walk == (island.player_input.destination != null), "walking to a left click does not turn the camera")
	var walked := 0
	var turned := 0
	for i in 90:
		var y0: float = island.chase.yaw
		var walking: bool = island.chase.mouse_walk
		await frames(1)
		if walking and island.chase.mouse_walk:
			walked += 1
			if island.chase.yaw != y0:
				turned += 1
	check(turned == 0, "no camera yaw change in %d frames of walking to a click" % walked)
	island.player_input.clear_destination()
	island.chase.reset_behind()
	var z_before: float = island.chase.z_target
	var zin := InputEventMouseButton.new()
	zin.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zin.pressed = true
	root.push_input(zin)
	check(island.chase.z_target > z_before, "the wheel zooms out (z target %.2f -> %.2f)" % [z_before, island.chase.z_target])
	island.chase.set_zoom(island.chase.Z_CHASE)

	var act_state: Dictionary = _actions_begin(island)
	print("== select Garfio, radial, Attack")
	if game.stage.cur.active >= 0:
		print("  (Garfio already started a fight on its own)")
	var target_pos: Vector3 = wild.global_position + Vector3(0, wild.height() * 0.5, 0)
	var screen: Vector2 = island.camera.unproject_position(target_pos)
	var vp := root.get_visible_rect().size
	check(screen.x > 0 and screen.y > 0 and screen.x < vp.x and screen.y < vp.y and not island.camera.is_position_behind(target_pos), "Garfio is on screen at %s" % screen)
	_click(screen)
	await frames(3)
	print("  clicked ", screen, " viewport ", vp, " player ", island.player_pos, " garfio ", wild.global_position)
	check(ui.selected.get("id", -1) == 1, "clicking Garfio selects it (id %s)" % ui.selected.get("id", null))
	var gmk = island.ground_marks
	check(gmk.is_selected() and gmk.sel_id == 1, "the selection ring is on Garfio")
	check(ui.note.visible, "the field note is shown")
	check(ui.ring.visible and ui.mode == &"", "the mode ring opened with no mode chosen")
	check(not game.modal_open and game.radial_open, "the ring is not modal: movement keys keep working")
	await _frame_png("radial")
	# choose Attack: the east side of the ring
	var c: Vector2 = ui.ring.centre
	_click(c + Vector2(ui.ring.radius(), 0))
	await frames(2)
	check(not ui.ring.visible and ui.mode == &"attack", "clicking the east side of the ring chooses Attack and closes it")
	check(ui.petals.count() == 4 and ui.defence.shown, "Attack shows the four petals and the guard and dodge marks")
	check(ui.abilities.size() == 4 and ui.abilities[0].id == "bite", "keys 1-4 carry the attack moves")
	# species-v8 (A31): Garfio takes no initiative during its grace minute and until the first evolution, so the player starts the fight
	ui._press(0)
	check(await until(func(): return game.stage.cur.active >= 0, 7200), "an encounter starts (active = %d)" % game.stage.cur.active)
	await sim_ticks(2)
	ui.clear_selection()
	sui._fight_prev = false           # as if the fight had just started with nothing selected
	await sim_ticks(2)
	check(ui.selected.get("id", -1) == game.stage.cur.active + 1 and ui.mode == &"attack" and not ui.ring.visible and ui.defence.shown, "a fight starting with nothing selected selects the attacker in attack mode with no ring")
	_key(KEY_2)
	await sim_ticks(25)
	_key(KEY_SPACE)
	await sim_ticks(10)
	_key(KEY_Q)
	await sim_ticks(20)
	_key(KEY_1)
	await sim_ticks(40)
	var p_now: Dictionary = game.stage.cur.entities[0]
	check(p_now.has("grip_deg") and p_now.has("sliding"), "A59 exposes grip and slipping to animation")
	var gp: Dictionary = CporeWorld.grip_profile(JSON.stringify({"nodes": [{"y": 0, "z": 0, "r": 1}], "parts": [{"type": "leg_sucker"}]}))
	check(int(gp.get("grip_deg", 0)) == 75, "A59 sucker preview clings at 75 degrees")
	var e_now: Dictionary = game.stage.cur.entities[1]
	check(events_seen > 0, "combat events reached the stage (%d)" % events_seen)
	check(windup_seen, "the wind-up tell was shown for an enemy wind-up")
	check(damage_seen > 0 or flash_seen, "damage numbers or flashes appeared (%d numbers, flash %s)" % [damage_seen, flash_seen])
	check(absf(ui.signs.hp_frac - clampf(p_now.hp / p_now.hp_max, 0.0, 1.0)) < 0.011, "the health line follows the world (%.3f vs %.1f / %.1f)" % [ui.signs.hp_frac, p_now.hp, p_now.hp_max])
	check(min_player_hp < hp_before or min_enemy_hp < e_now.hp_max, "the fight changed HP (player min %.1f of %.1f, Garfio min %.1f of %.1f)" % [min_player_hp, hp_before, min_enemy_hp, e_now.hp_max])
	check(root.get_node("Audio").played.get("hit", 0) + root.get_node("Audio").played.get("block", 0) + root.get_node("Audio").played.get("dodge", 0) + root.get_node("Audio").played.get("hurt", 0) > 0, "combat sounds played")
	await _frame_png("fight")
	game.world_ticked.disconnect(watch)
	await _actions_end(island, act_state)

	print("== move marker: the white circle where you click")
	var walk_to := Vector2(640, 560)
	_click(walk_to)
	await frames(3)
	check(island.player_input.destination != null and gmk.move_visible() and not gmk.follow_visible(), "a click on the ground sets a destination and shows the white circle")
	check(Vector2(gmk.destination().x, gmk.destination().z).distance_to(island.player_input.destination) < 0.01, "the circle is at the destination")
	await frames(10)
	check(gmk.move_mark.alpha > 0.5, "the circle is opaque after it appears (%.2f)" % gmk.move_mark.alpha)
	island.player_input.clear_destination()
	await frames(50)
	check(not gmk.move_mark.visible, "the circle fades once the destination is gone")
	island.player_input.clear_destination()
	var sea := Vector3.INF
	for k in game.data.n * game.data.n:
		if game.data.height[k] <= 0.0:
			sea = Vector3(game.data.cell_center(k % game.data.n), 0.0, game.data.cell_center(k / game.data.n))
			break
	check(sea != Vector3.INF and island.walk_blocked(sea) and not island.walk_blocked(island.player_pos), "the sea is a blocked destination, the ground under the player is not")
	gmk.move_blocked(sea)
	await frames(3)
	check(gmk._blocked_mark.is_shown() and not gmk.move_visible(), "a blocked click shows the cut ring, not the circle")


# ------------------------------------------------------------------------------------------------
# G77: the procedural action layer on the real stage and the real C world
# ------------------------------------------------------------------------------------------------
func _actions_begin(island) -> Dictionary:
	print("== actions (G77): recording")
	var p = island.hosts[0]
	var w = island.hosts[1]
	check(p.driver.layer != null and w.driver.layer != null, "both creatures have an action layer (%s, %s)" % [p.driver.layer != null, w.driver.layer != null])
	check(island.stage.process_priority < 0, "the world ticks before the actors read it (process_priority %d)" % island.stage.process_priority)
	var st := {"impacts": {0: [], 1: []}, "hits": {0: [], 1: []}, "wind": {"n": 0, "bad": 0, "seen": 0}, "ids": {}}
	p.driver.layer.action_event.connect(func(n: String, _d: Dictionary) -> void:
		if n == "impact": st.impacts[0].append(Engine.get_process_frames()))
	w.driver.layer.action_event.connect(func(n: String, _d: Dictionary) -> void:
		if n == "impact": st.impacts[1].append(Engine.get_process_frames()))
	game.combat_events.connect(func(evs: Array) -> void:
		for e in evs:
			if int(e.type) == 1:
				st.hits[int(e.a)].append(Engine.get_process_frames()))
	var names := ["bite", "charge", "guard", "spit", "tail_strike", "dodge"]
	st["cb"] = func() -> void:
		for id in p.driver.layer.current_ids():
			st.ids[id] = true
		for id in w.driver.layer.current_ids():
			st.ids[id] = true
		var f1: Variant = null
		for f in game.stage.cur.combat.fighters:
			if int(f.world_id) != 0:
				f1 = f
		if f1 == null or int(f1.phase) != 1 or int(f1.move) < 0:
			st.wind.n = 0
			return
		st.wind.n += 1
		st.wind.seen += 1
		if st.wind.n > 4 and w.driver.layer.weight_of(names[int(f1.move)]) < 0.99:
			st.wind.bad += 1
	process_frame.connect(st.cb)
	return st

func _actions_end(island, st: Dictionary) -> void:
	process_frame.disconnect(st.cb)
	print("== actions (G77): checks")
	var n_player: int = st.hits[0].size()
	var n_enemy: int = st.hits[1].size()
	check(n_player >= 2, "the player's attacks landed %d times, the enemy's %d" % [n_player, n_enemy])
	var worst := 0
	var matched := 0
	var last_frame := 0
	for kind in [0, 1]:
		for hf in st.hits[kind]:
			last_frame = maxi(last_frame, int(hf))
	var skipped := 0
	for kind in [0, 1]:
		for hf in st.hits[kind]:
			var trade: bool = st.hits[0].has(last_frame) and st.hits[1].has(last_frame)
			var attacker_dead: bool = "death" in island.hosts[kind].driver.layer.current_ids()
			if int(hf) == last_frame and (not trade or attacker_dead):
				# the lethal last hit ends the fight: its layer never plays an impact. When both creatures hit in that
				# same tick (a trade), only the one that died is excused: its death replaces the attack instance, while
				# the survivor's impact must still fire.
				skipped += 1
				matched += 1
				continue
			var best := 1000000
			for i in st.impacts[kind]:
				best = mini(best, absi(int(i) - int(hf)))
			if best <= 1:
				matched += 1
			worst = maxi(worst, best)
	check(matched == n_player + n_enemy, "every C HIT is matched by a layer impact within 1 frame (%d of %d, worst %d frames)" % [matched, n_player + n_enemy, worst])
	check(st.wind.seen > 0 and st.wind.bad == 0, "during an enemy wind-up the action weight is >= 0.99 after the first 4 frames (%d frames seen, %d bad)" % [st.wind.seen, st.wind.bad])
	var played: Array = st.ids.keys()
	check(played.has("bite") or played.has("charge"), "the player's attacks played their actions (%s)" % [played])
	# the layer reads the world and never writes it: replay the whole session's inputs in a fresh C world
	var parsed: Dictionary = WorldLog.parse(game.stage.export_log())
	var replay_ok := true
	if parsed.ok:
		var w2 = CporeWorld.new()
		if not parsed.field.is_empty():
			w2.set_field(game.terrain)
		w2.reset(parsed.setup)
		if game.stage.start_snapshot.size() > 0:     # the session began from a loaded save
			w2.restore(game.stage.start_snapshot)
		var hs: PackedStringArray = game.stage.hashes
		var dbg: Array = parsed.get("debug", [])
		var di := 0
		for i in mini(parsed.inputs.size(), hs.size()):
			while di < dbg.size() and int(dbg[di].tick) == int(w2.state().tick):
				w2.debug(dbg[di].op)
				di += 1
			if w2.step(parsed.inputs[i]) != hs[i]:
				replay_ok = false
				break
	else:
		replay_ok = false
	check(replay_ok, "determinism: replaying the session log in a fresh C world gives the same hashes with the action layer on")
	# a cosmetic action from the abilities goes nowhere near C
	var n_log: int = game.stage.log_inputs.size()
	island.hosts[0].layer().trigger("roar")
	await frames(40)
	var new_verbs := {}
	for i in game.stage.log_inputs.slice(n_log):
		new_verbs[int(i.get("verb", 0))] = true
	check(new_verbs.size() <= 2 and not new_verbs.has(10) and not new_verbs.has(11), "a cosmetic roar sends no new verb to C (%s)" % [new_verbs.keys()])

func _watch_tick(state: Dictionary, ui, island) -> void:
	min_player_hp = minf(min_player_hp, state.entities[0].hp)
	if state.entities.size() > 1:
		min_enemy_hp = minf(min_enemy_hp, state.entities[1].hp)
	for f in state.combat.fighters:
		if f.world_id != 0 and f.phase == 1 and float(island.ground_marks.sel_mark.param("disc")) > 0.0:
			windup_seen = true
	damage_seen = maxi(damage_seen, ui.words._floats.size())
	if ui.veil.hit > 0.01 or ui.defence._ripple > 0.0:
		flash_seen = true

func _click(pos: Vector2) -> void:
	for pressed in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = pos
		e.global_position = pos
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(e)

func _drag(a: Vector2, b: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.position = a
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e)
	for i in 5:
		var m := InputEventMouseMotion.new()
		m.position = a.lerp(b, (i + 1) / 5.0)
		m.relative = (b - a) / 5.0
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(m)
	var u := InputEventMouseButton.new()
	u.position = b
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	root.push_input(u)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)

func _frame_png(_name: String) -> void:
	await frames(1)   # hook for evidence runs; the headless test draws nothing

# ------------------------------------------------------------------------------------------------
# 3. studio with the real view, save, back to Play
# ------------------------------------------------------------------------------------------------
func _studio_and_back() -> void:
	print("== studio")
	game.goto_menu()
	check(await until(func(): return _scene_is("main_menu.gd"), 600), "back to the menu")
	_press(current_scene.creator_button)
	check(await until(func(): return current_scene != null and "model" in current_scene and current_scene.model != null, 600), "Creator opens the studio")
	var studio = current_scene
	await frames(5)
	check(str(studio.model.doc.get("name", "")) == "Starter B", "the creator opens on the starter B (%s)" % studio.model.doc.get("name", ""))
	studio.model.new_from_seed("Merodeador")           # the interface checks below need the horn and the big body
	await frames(5)
	var view = studio.view
	check(view.get_script().resource_path.ends_with("creature_view_real.gd") and view.creature != null, "the studio uses the real creature view")
	var before_parts: int = view.genome.parts.size()
	check(before_parts > 0 and view.creature.parts.size() + view.creature.legs.size() >= 1, "the view built the Merodeador seed (%d parts)" % before_parts)
	# interface checks against the real rig
	var pts: PackedVector3Array = view.spine_node_positions()
	check(pts.size() == view.genome.nodes.size() and absf(pts[0].x) < 1e-6, "spine_node_positions: one per node, x = 0")
	var mid: Vector3 = view.creature.rest[36] + Vector3(0, view.creature.ground_offset, 0)
	var rest_mid: Vector3 = view.creature.rest[36]
	var ray_o: Vector3 = rest_mid + Vector3(0, 0, 0) + Vector3(0, 0, 0)
	var origin := rest_mid + Vector3(0.0, 6.0, 0.0)
	var hit: Dictionary = view.hit_body(origin, Vector3.DOWN)
	check(not hit.is_empty() and absf(hit.t - 0.5) < 0.12, "hit_body from above the middle: t = %.2f" % hit.get("t", -1.0))
	check(not hit.is_empty() and absf(wrapf(hit.ang, -PI, PI)) < 0.35, "hit_body from above: ang = %.2f (0 = up)" % hit.get("ang", 9.0))
	var side: Dictionary = view.hit_body(rest_mid + Vector3(6.0, 0, 0), Vector3.LEFT)
	check(not side.is_empty() and side.ang > 1.1 and side.ang < 2.0, "hit_body from +X: ang = %.2f (about +pi/2)" % side.get("ang", 9.0))
	if not side.is_empty():
		var back: Dictionary = view.creature.anchor(side.t, side.ang)
		check(back.p.distance_to(side.point) < 0.35, "the hit (t, ang) round-trips through anchor() (%.2f m)" % back.p.distance_to(side.point))
	check(view.hit_body(Vector3(0, 40, 40), Vector3.UP).is_empty(), "hit_body misses empty space")
	var node_hit: int = view.hit_node(Vector3(0, pts[3].y, pts[3].z) + Vector3(6, 0, 0), Vector3.LEFT)
	check(node_hit == 3, "hit_node finds spine node 3 (%d)" % node_hit)
	var part_idx := -1
	for i in view.genome.parts.size():
		if view.creature.maker.is_leg(view.genome.parts[i].type):
			part_idx = i
			break
	var anchor: Dictionary = view.part_anchor(part_idx)
	check(not anchor.is_empty() and anchor.normal.length() > 0.9, "part_anchor gives pos, normal, up")
	# a ray at the first non-leg part's mirrored pair: both sides hit the same index
	var horn := -1
	for i in view.genome.parts.size():
		if view.genome.parts[i].type == "cuerno":
			horn = i
	var ha: Dictionary = view.part_anchor(horn)
	var ph_a: int = view.hit_part(ha.pos + ha.normal * 3.0, -ha.normal)
	var mirrored := Vector3(-ha.pos.x, ha.pos.y, ha.pos.z)
	var ph_b: int = view.hit_part(mirrored + Vector3(-ha.normal.x, ha.normal.y, ha.normal.z) * 3.0, -Vector3(-ha.normal.x, ha.normal.y, ha.normal.z))
	check(ph_a == horn and ph_b == horn, "hit_part finds the horn on both mirrored sides (%d, %d, want %d)" % [ph_a, ph_b, horn])
	var horn_nodes := 0
	for e in view.creature.parts:
		if e.index == horn:
			horn_nodes += 1
	check(horn_nodes == 2, "an off-midline part is built mirrored (%d copies)" % horn_nodes)

	# edit, save
	var idx: int = studio.model.add_part("cuerno", 0.72, 0.8)
	await frames(3)
	check(idx == before_parts and view.genome.parts.size() == before_parts + 1, "adding a part reaches the view (%d parts)" % view.genome.parts.size())
	studio.model.set_name_("Wire Test")
	var path: String = studio.save_current()
	check(path != "" and FileAccess.file_exists(path) and path.begins_with(game.studio_dir), "saved to the studio folder (%s)" % path)
	studio.set_mode("test")
	studio.toggle_play()
	await frames(30)
	check(view._playing and view._ctl != null, "Test mode runs locomotion on the real creature")
	var moved_to: Vector3 = view.creature.global_position
	check(moved_to.length() > 0.5, "the creature walks in Test mode (at %s)" % moved_to)
	studio.toggle_play()
	await frames(3)
	check(not view._playing, "Stop returns the creature to its rest pose")
	studio.set_mode("build")
	# back to Play
	studio._on_exit()
	check(await until(func(): return _scene_is("main_menu.gd"), 600), "the studio returns to the menu")
	var g: Dictionary = game.player_genome()
	check(g.get("name", "") == "Wire Test" and g.parts.size() == before_parts + 1, "Play will use the saved genome (%s, %d parts)" % [g.get("name", ""), g.parts.size()])
	var dev_node = game.get_node_or_null("/root/Dev")
	var dev_was: bool = dev_node != null and dev_node.enabled
	if dev_node != null:
		dev_node.enabled = false       # normal build: the A25 rule
	_press(current_scene.play_button)
	check(await until_ms(func(): return _scene_is("island.gd")), "Play opens the stage again")
	await frames(5)
	var host = current_scene.hosts[0]
	# A25: a new run starts from the saved creature's body but with the starter parts only (pico, pata, ojo)
	var starter_only: bool = host.body.genome.parts.all(func(p): return p.type in ["pico", "pata", "ojo"])
	check(host.body.genome.get("name", "") == "Wire Test" and starter_only, "the stage creature is the saved genome with starter parts (%d parts)" % host.body.genome.parts.size())
	check(host.driver.controller != null and host.driver.problems.is_empty(), "the edited creature is still driven by locomotion")
	await sim_ticks(20)
	# brief creature-fixes 5: the built island pieces are kept between scene changes; "Jugar con esta criatura" saves and enters with them
	check(current_scene.kit_reused and game.kit_hits >= 1, "the island pieces were taken from the kit on re-entry (hits %d)" % game.kit_hits)
	var terrain_node = current_scene.terrain_chunks
	game.goto_studio()
	check(await until(func(): return current_scene != null and "model" in current_scene and current_scene.model != null, 600), "the studio opens again from the island")
	var studio2 = current_scene
	check(studio2.play_creature_btn != null and studio2.play_creature_btn.visible, "the studio has the Jugar con esta criatura button")
	if dev_node != null:
		dev_node.enabled = dev_was
	studio2.model.add_part("cuerno", 0.72, 0.8)       # a part that is not a starter part
	var saved_types := {}
	for sp in studio2.model.doc.parts:
		saved_types[str(sp.type)] = true
	studio2.model.set_name_("Play Button Test")
	studio2.play_with_creature()
	check(await until_ms(func(): return _scene_is("island.gd")), "Jugar con esta criatura opens the island")
	await frames(5)
	check(current_scene.hosts[0].body.genome.get("name", "") == "Play Button Test", "the island has the creature that was just saved")
	# A31: in dev builds the creature keeps all its parts and C knows the player owns them (normal builds: the A25 rule above)
	var kept_types := {}
	for kp in current_scene.hosts[0].body.genome.parts:
		kept_types[str(kp.type)] = true
	check(dev_node != null and dev_was and kept_types.has("cuerno") and kept_types.keys().all(func(k): return saved_types.has(k)) and saved_types.keys().all(func(k): return kept_types.has(k)), "dev build: Jugar con esta criatura keeps all %d part types (%d kept)" % [saved_types.size(), kept_types.size()])
	await sim_ticks(2)
	var owned_ids := {}
	for row in game.stage.cur.parts.discovered:
		if bool(row.owned):
			owned_ids[str(row.id)] = true
	check(kept_types.keys().all(func(k): return owned_ids.has(k) or not preload("res://game/stage/lineage_session.gd").part_ids().has(k) or preload("res://game/stage/lineage_session.gd").part_ids().find(k) >= 46), "and C marks those parts owned (%d owned)" % owned_ids.size())
	check(current_scene.kit_reused and current_scene.terrain_chunks == terrain_node, "and the same built terrain (not rebuilt: %d ms build)" % int(current_scene.build_ms.get("total", -1)))
	await sim_ticks(20)
	# brief creature-fixes 6: resting the pointer on a plant notes it (whisper, journal page, saved with the game)
	var isl2 = current_scene
	check(isl2.props.records.size() > 0, "the island has plants (%d records)" % isl2.props.records.size())
	var rec: Dictionary = isl2.props.records[0]
	var seen: String = isl2.gaze.pick(isl2.props.records, (rec.p as Vector3) + Vector3(0, float(rec.height) + 10.0, 0), Vector3.DOWN)
	check(seen != "", "a ray down onto a plant picks a plant (%s)" % seen)
	isl2.gaze.known.clear()
	var noted := ""
	for i in 40:
		noted = isl2.gaze.tick(0.1, seen)
		if noted != "":
			break
	check(noted == seen, "%.1f s on it notes it" % isl2.gaze.DWELL)
	isl2.stage_ui.plant_noticed(noted)
	check(isl2.stage_ui.ui.words.whisper_text.begins_with("New plant") or isl2.stage_ui.ui.words.whisper_text.begins_with("Nueva planta"), "the whisper says it (%s)" % isl2.stage_ui.ui.words.whisper_text)
	check(isl2.stage_ui._journal_model().plants.size() == 1, "the journal model has the plant")
	check(isl2.scenario_ctx().plants == [noted], "the save carries the plant list")
	var built: Dictionary = preload("res://devtools/scenario.gd").build(isl2.stage, isl2.scenario_ctx(), "save", "plants", "", false)
	check(built.json.plants == [noted], "the scenario file has the plants")
	isl2.gaze.known.clear()
	isl2.gaze.from_list(built.json.plants)
	check(isl2.gaze.known.has(noted), "and loading brings them back")
	await sim_ticks(5)
