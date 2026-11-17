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
	game.settings.grass = 3000
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
	check(await until(func(): return _scene_is("island.gd"), 600), "Play opens the stage")
	var island = current_scene
	await frames(5)
	var ui = island.stage_ui.ui
	check(ui != null and ui.hud != null, "the HUD is mounted")
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
	var watch := _watch_tick.bind(ui)
	game.world_ticked.connect(watch)
	if OS.get_environment("PLAY_TEST_VERBOSE") != "":
		game.world_ticked.connect(func(st: Dictionary):
			if st.order.verb > 1 and st.active >= 0:
				print("  tick ", st.tick, " order ", st.order, " accepted ", st.accepted, " err ", st.error, " p.st ", st.entities[0].stamina, " fighters ", st.combat.fighters.map(func(f): return [f.move, f.phase, snappedf(f.x, 0.01), snappedf(f.z, 0.01), snappedf(f.fx, 0.01), snappedf(f.fz, 0.01)])))
	var hp_before: float = game.stage.cur.entities[0].hp
	check(String(ui.hud.player_hp_text.text) == str(ceili(hp_before)), "the HUD shows the player's HP (%s)" % ui.hud.player_hp_text.text)
	check(ui.hud.player_name.text == player.body.genome.get("name", ""), "the HUD shows the creature's name")

	print("== walk 10 s with scripted input")
	var start: Vector3 = island.player_pos
	var played0: int = int(root.get_node("Audio").played.get("step-0", 0)) + int(root.get_node("Audio").played.get("step-1", 0)) + int(root.get_node("Audio").played.get("step-2", 0))
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	var t0: int = game.stage.cur.tick
	await sim_ticks(100)
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	var moved := Vector2(island.player_pos.x - start.x, island.player_pos.z - start.z).length()
	check(game.stage.cur.tick - t0 >= 100, "10 s of game time passed (%d ticks)" % (game.stage.cur.tick - t0))
	check(moved > 8.0, "the player walked %.1f m" % moved)
	check(footfalls >= 6, "locomotion produced %d foot contacts" % footfalls)
	var played1: int = int(root.get_node("Audio").played.get("step-0", 0)) + int(root.get_node("Audio").played.get("step-1", 0)) + int(root.get_node("Audio").played.get("step-2", 0))
	check(played1 > played0, "footstep sounds played (%d)" % (played1 - played0))
	var lowest := 1e9
	for l in player.body.legs:
		lowest = minf(lowest, l.foot.global_position.y - game.ground(l.foot.global_position.x, l.foot.global_position.z))
	check(lowest > -0.03, "feet are on Game.ground (lowest %.1f mm relative)" % (lowest * 1000.0))
	check(absf(player.position.y - game.ground(player.position.x, player.position.z)) < 0.05, "the actor stands on Game.ground")

	print("== camera: left drag orbits, a click does not")
	var yaw_before: float = island.chase.yaw
	island.player_input.clear_destination()
	await _drag(Vector2(640, 500), Vector2(720, 500))
	await frames(2)
	check(island.chase.yaw != yaw_before, "a left drag orbits the camera (yaw %.3f -> %.3f)" % [yaw_before, island.chase.yaw])
	check(island.player_input.destination == null, "a left drag does not set a destination")
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
	check(ui.card.visible, "the creature card is shown")
	check(ui.radial.visible, "the radial menu opened")
	check(game.modal_open, "the radial blocks movement (modal_open)")
	await _frame_png("radial")
	# choose Attack: the north sector
	var c: Vector2 = ui.radial.centre
	_click(c + Vector2(0, -108))
	await frames(2)
	check(not ui.radial.visible and ui.mode == &"attack", "choosing Attack closes the radial and sets the attack mode")
	check(ui.abilities.size() == 4 and ui.abilities[0].id == "bite", "keys 1-4 carry the attack moves")
	check(await until(func(): return game.stage.cur.active >= 0, 2400), "an encounter starts (active = %d)" % game.stage.cur.active)
	await sim_ticks(2)
	_key(KEY_2)
	await sim_ticks(25)
	_key(KEY_SPACE)
	await sim_ticks(10)
	_key(KEY_Q)
	await sim_ticks(20)
	_key(KEY_1)
	await sim_ticks(40)
	var p_now: Dictionary = game.stage.cur.entities[0]
	var e_now: Dictionary = game.stage.cur.entities[1]
	check(events_seen > 0, "combat events reached the stage (%d)" % events_seen)
	check(windup_seen, "the wind-up tell was shown for an enemy wind-up")
	check(damage_seen > 0 or flash_seen, "damage numbers or flashes appeared (%d numbers, flash %s)" % [damage_seen, flash_seen])
	check(String(ui.hud.player_hp_text.text) == str(ceili(maxf(p_now.hp, 0.0))), "the HUD HP follows the world (%s vs %.1f)" % [ui.hud.player_hp_text.text, p_now.hp])
	check(min_player_hp < hp_before or min_enemy_hp < e_now.hp_max, "the fight changed HP (player min %.1f of %.1f, Garfio min %.1f of %.1f)" % [min_player_hp, hp_before, min_enemy_hp, e_now.hp_max])
	check(root.get_node("Audio").played.get("hit", 0) + root.get_node("Audio").played.get("block", 0) + root.get_node("Audio").played.get("dodge", 0) + root.get_node("Audio").played.get("hurt", 0) > 0, "combat sounds played")
	await _frame_png("fight")
	game.world_ticked.disconnect(watch)
	await _actions_end(island, act_state)

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
	for kind in [0, 1]:
		for hf in st.hits[kind]:
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
		w2.reset(parsed.setup)
		var hs: PackedStringArray = game.stage.hashes
		for i in mini(parsed.inputs.size(), hs.size()):
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

func _watch_tick(state: Dictionary, ui) -> void:
	min_player_hp = minf(min_player_hp, state.entities[0].hp)
	if state.entities.size() > 1:
		min_enemy_hp = minf(min_enemy_hp, state.entities[1].hp)
	for f in state.combat.fighters:
		if f.world_id != 0 and f.phase == 1 and ui.hud.windup_bar.visible:
			windup_seen = true
	damage_seen = maxi(damage_seen, ui.hud._numbers.size())
	if ui.hud.flash_rect.modulate.a > 0.01:
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
	_press(current_scene.play_button)
	check(await until(func(): return _scene_is("island.gd"), 600), "Play opens the stage again")
	await frames(5)
	var host = current_scene.hosts[0]
	check(host.body.genome.get("name", "") == "Wire Test" and host.body.genome.parts.size() == before_parts + 1, "the stage creature is the saved genome (%d parts)" % host.body.genome.parts.size())
	check(host.driver.controller != null and host.driver.problems.is_empty(), "the edited creature is still driven by locomotion")
	await sim_ticks(20)
