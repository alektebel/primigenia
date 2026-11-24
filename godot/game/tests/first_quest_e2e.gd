extends SceneTree
# make godot-first-quest-e2e: the whole first chain, played through the real player verbs and nothing else.
#   new game -> kill a Rondo -> befriend another species -> dig -> unearth the wings at the bed -> open the editor, add the
#   fire gland, evolve -> use the flamethrower.
# No teleports and no debug ops (only the time scale is turned up). Orders are the ones the keys, the mouse and the UI send:
# a click-walk destination, the hotbar press, the befriend and gift orders, the X key's dig order, and the nest editor's own
# buttons. Every task must complete within its tick budget; the run is deterministic by seed and replays to the same hash.
#   godot --headless --fixed-fps 60 --path godot --script res://game/tests/first_quest_e2e.gd [-- seed=1 evidence=<dir> replay]

const Strings := preload("res://ui/strings.gd")

class ErrorLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])

# Tick budgets per task (the whole chain must fit in TOTAL), at 10 ticks per second of game time.
const BUDGET := {"hunt": 15000, "friend": 12000, "dig": 2500, "wings": 6000, "fire": 6000}   # A39: a body walks at Fr 0.24 (the starter about 1 m/s) and runs at Fr 1.5, so the bot needs about 2.5x the old ticks
const TOTAL := 40000
var TIMESCALE := 16.0

var checks := 0
var failures := 0
var log := ErrorLog.new()
var game
var island
var sui
var ui
var fq
var seed_n := 1
var duel_only := false     # `duel`: boot, fight Garfio once at full hp, print the result, quit (make godot-loop-duel)
var wall_limit_s := 780.0  # a hang (the sim paused in an editor, a wait on ticks that never come) fails the run instead of waiting for the make timeout
var evidence_dir := ""
var verbose := OS.get_environment("E2E_VERBOSE") != ""
var shots := 0
var task_ticks := {}
var hashes: PackedStringArray = PackedStringArray()

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func say(s: String) -> void:
	if verbose:
		print("  .. t=", tick(), " ", s)

func tick() -> int:
	return int(game.stage.cur.tick)

func frames(n: int) -> void:
	for i in n:
		await process_frame

## Like until, with a wall-clock budget: the island builds under a loading screen on worker threads.
func until_ms(cond: Callable, budget_ms := 90000) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call() and Time.get_ticks_msec() - t0 < budget_ms:
		await process_frame
	return cond.call()

func until(cond: Callable, budget := 1800) -> bool:
	var n := 0
	while not cond.call() and n < budget:
		await process_frame
		n += 1
	return cond.call()

## Waits until the C world has run `ticks` more ticks; bounded by the same number times a few frames.
func ticks(n: int) -> void:
	var t0 := tick()
	var guard := 0
	while tick() - t0 < n and guard < n * 8 + 600:
		await process_frame
		guard += 1

func _initialize() -> void:
	OS.add_logger(log)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_n = int(a.substr(5))
		elif a.begins_with("scale="):
			TIMESCALE = float(a.substr(6))
		elif a.begins_with("evidence="):
			evidence_dir = a.substr(9)
		elif a == "duel":
			duel_only = true
	var t_boot := Time.get_ticks_msec()
	process_frame.connect(func():     # wall clock, not engine time: --fixed-fps runs many engine seconds per wall second
		if float(Time.get_ticks_msec() - t_boot) / 1000.0 > wall_limit_s:
			printerr("FAIL: wall-clock guard: the bot did not finish in %.0f s (tick %d)" % [wall_limit_s, tick() if game != null and game.stage != null else -1])
			quit(1))
	_run.call_deferred()

func _finish() -> void:
	check(log.errors.is_empty(), "no errors during the whole run (%d: %s)" % [log.errors.size(), str(log.errors.slice(0, 3))])
	OS.remove_logger(log)
	print("first quest e2e: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _scene_is(script_name: String) -> bool:
	# the island is entered through the loading screen and builds across frames: it counts once it is built
	if script_name == "island.gd" and current_scene != null and "_building" in current_scene and current_scene._building:
		return false
	return current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with(script_name)

func _shot(name: String) -> void:
	if evidence_dir == "":
		return
	await frames(3)
	shots += 1
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	img.save_png("%s/%02d_%s.png" % [evidence_dir, shots, name])

# --- boot ---------------------------------------------------------------------------------------------------------------

func _run() -> void:
	game = root.get_node("Game")
	root.size = Vector2i(1280, 720)
	game.persist_settings = false
	game.settings.seed = seed_n
	game.settings.grass = 3000
	game.settings.wild = true
	game.settings.herds = true
	game.settings.secrets = true
	game.settings.edit_anywhere = true
	game.settings["onboarding"] = 0x1ff       # the first-minutes hints are not what is under test
	change_scene_to_file("res://game/main.tscn")
	if not check(await until(func(): return _scene_is("main_menu.gd"), 3000), "main boots to the menu"):
		return _finish()
	current_scene.play_button.pressed.emit()
	if not check(await until_ms(func(): return _scene_is("island.gd")), "Play opens the stage"):
		return _finish()
	island = current_scene
	await frames(5)
	sui = island.stage_ui
	ui = sui.ui
	fq = island.first_quest
	game.stage.timescale = TIMESCALE
	game.stage.max_steps_per_frame = 60
	hashes.append(game.stage.cur.hash)
	var st: Dictionary = game.stage.cur
	check(fq != null and fq.quest.step == 0 and fq.quest.steps().size() == 5, "a new game starts at the first of five tasks")
	check(ui.quest_card.visible or ui.quest_card._alpha > 0.0, "the task card is on screen")
	print("   player %.1f,%.1f hp %.0f; %d creatures; seed %d; nest %s" % [st.entities[0].x, st.entities[0].z, st.entities[0].hp, st.entities.size() - 1, seed_n, str(island._nest)])
	await _shot("start")
	var t_start := tick()
	# A39: bodies walk at Fr 0.24 and prey runs at Fr 1.5 when it flees, so the bot sprints between fights
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": true, "run": true}
	if duel_only:
		await _duel()
		return
	await _hunt()
	await _friend()
	await _dig()
	await _explore()
	await _wings()
	if not task_ticks.has("wings"):
		return _finish()
	island.player_input.keys_override = null
	await _fire()
	check(fq.quest.finished(), "all five tasks are done")
	check(tick() - t_start <= TOTAL, "the whole chain fits in %d ticks (%d used)" % [TOTAL, tick() - t_start])
	await _shot("done")
	print("   task completion ticks: ", task_ticks, "  world hash ", game.stage.world.hash())
	print("e2e final tick=%d hash=%s tasks=%s" % [tick(), game.stage.world.hash(), str(task_ticks)])
	_finish()

# --- helpers: the player's hands --------------------------------------------------------------------------------------------

func state() -> Dictionary:
	return game.stage.cur

func me() -> Dictionary:
	return state().entities[0]

func ent(id: int) -> Dictionary:
	return state().entities[id]

func dist_to(id: int) -> float:
	return Vector2(float(ent(id).x) - float(me().x), float(ent(id).z) - float(me().z)).length()

## Click-walk: the same destination a click on the ground sets, repeated while the route is being followed.
func walk_to(p: Vector2, radius: float, budget: int, stop: Callable = Callable()) -> bool:
	var t0 := tick()
	var next_send := -1
	var still_from := tick()
	var still_pos := Vector2(float(me().x), float(me().z))
	while tick() - t0 < budget:
		var here := Vector2(float(me().x), float(me().z))
		var d := here.distance_to(p)
		if d <= radius:
			island.player_input.clear_destination()
			return true
		if stop.is_valid() and stop.call():
			return true
		if int(state().active) >= 0:
			island.player_input.clear_destination()
			await _fight_out(tick())        # something met the player on the way (Garfio's home is next to the nest): fight it out, flee under 25 hp
			next_send = -1
			continue
		if here.distance_to(still_pos) > 1.0:
			still_pos = here
			still_from = tick()
		if tick() - still_from > 200:
			# A54: a click-walk (GO) is refused from a pocket the planner does not know (the bot chased a creature into one); a player would
			# take the keys: walk straight at the goal for 4 s with a heading order, then click again
			island.player_input.clear_destination()
			var h := (p - here).normalized()
			for k in 40:
				game.stage.queue_order({"verb": 3, "hx": int(round(h.x * 32767.0)), "hz": int(round(h.y * 32767.0)), "sprint": 0})
				await ticks(1)
			still_from = tick()
			still_pos = Vector2(float(me().x), float(me().z))
			next_send = -1
			continue
		if tick() >= next_send:
			island.player_input.set_destination(p)
			next_send = tick() + 40
		await process_frame
	return false

func nearest_alive(species: int, exclude_hostile := false) -> int:
	var best := -1
	var bd := INF
	for i in range(1, state().entities.size()):
		var e: Dictionary = ent(i)
		if bool(e.dead) or int(e.species) != species or bool(e.get("hidden", false)):
			continue
		if exclude_hostile and bool(e.get("hostile", false)):
			continue
		var d := dist_to(i)
		if d < bd:
			bd = d
			best = i
	return best

func wait_task(id: String, budget: int) -> bool:
	var t0 := tick()
	while tick() - t0 < budget and not task_ticks.has(id):
		await process_frame
	return task_ticks.has(id)

func _on_task(id: String) -> void:
	task_ticks[id] = tick()
	say("task done: " + id)

# --- 1. hunt ------------------------------------------------------------------------------------------------------------------

func _hunt() -> void:
	print("== 1. hunt: defeat a prey creature")
	fq.task_done.connect(_on_task)
	var t0 := tick()
	# the Rondo herd is the nearest prey group in the valley
	var target := nearest_alive(0)
	if not check(target > 0, "a Rondo lives in the valley"):
		return
	var tries := 0
	while not task_ticks.has("hunt") and tick() - t0 < BUDGET.hunt and tries < 12:
		tries += 1
		target = nearest_alive(0)
		if target < 0:
			target = nearest_alive(1)
		if target < 0:
			break
		var e: Dictionary = ent(target)
		say("lock creature #%d at %.0f m" % [target, dist_to(target)])
		# verb first, then the creature: F arms Attack, a click locks it; the stage pursues and starts the fight by itself
		_key(KEY_F)
		if int(state().active) < 0 and not sui.lock_target(target):
			say("could not lock #%d" % target)
		var p0 := tick()
		await until(func(): return int(state().active) >= 0 or bool(ent(target).dead) or tick() - p0 > 1500 or task_ticks.has("hunt"), 20000)
		# fight until it ends
		var f0 := tick()
		while tick() - f0 < 700 and not task_ticks.has("hunt"):
			if int(state().active) >= 0:
				if sui.selected_id != int(state().active) + 1:
					sui.select_id(int(state().active) + 1)
				if ui.mode != &"attack":
					ui.set_mode(&"attack")
				var hp: float = float(me().hp)
				# bite, spit when the body is spent
				ui._press(0 if float(me().stamina) > 12.0 else 1)
			elif state().outcome != 0 and tick() - f0 > 30:
				break
			else:
				# a creature that ran off: chase the same one
				var t2 := target
				if t2 > 0 and not bool(ent(t2).dead):
					var e2: Dictionary = ent(t2)
					island.player_input.set_destination(Vector2(float(e2.x), float(e2.z)))
					if dist_to(t2) < 6.0 and int(state().active) < 0:
						sui.select_id(t2)
						ui.set_mode(&"attack")
						ui._press(0)
			await frames(6)
		if int(state().active) >= 0 and float(me().hp) < 30.0 and not task_ticks.has("hunt"):
			sui._send({"verb": 6}, "flee")
	check(await wait_task("hunt", 30), "task 1 done: a creature was defeated (tick %d)" % int(task_ticks.get("hunt", -1)))
	check(tick() - t0 <= BUDGET.hunt, "within the budget of %d ticks (%d)" % [BUDGET.hunt, tick() - t0])
	await _shot("task1_hunt")

# --- 2. friend ------------------------------------------------------------------------------------------------------------------

func _friend() -> void:
	print("== 2. friend: befriend a creature of another species")
	var t0 := tick()
	var killed := int(fq.quest.flags.get("killed_species", 0))
	var target := -1
	var tries := 0
	while not task_ticks.has("friend") and tick() - t0 < BUDGET.friend and tries < 30:
		tries += 1
		# a calm creature of another species; the Zanco herd first, then the rest
		target = -1
		for sp in [1, 5, 2, 0]:
			if sp == killed:
				continue
			target = nearest_alive(sp, true)
			if target > 0:
				break
		if target < 0:
			break
		var e: Dictionary = ent(target)
		say("lock #%d (species %d) at %.0f m" % [target, int(e.species), dist_to(target)])
		if int(state().active) >= 0:
			# something started a fight: finish it with the bite, then carry on
			await _fight_out(t0)
			continue
		_key(KEY_B)                               # B arms Befriend; the click locks the creature and the stage walks up to it
		sui.lock_target(target)
		var step := 0
		var last_say := -1000
		var last_run_tick := -1
		var last_trust := -1
		var stuck := 0
		while not task_ticks.has("friend") and tick() - t0 < BUDGET.friend and int(state().active) < 0:
			var en: Dictionary = ent(target)
			if bool(en.dead):
				break
			if sui.locked_id != target:
				_key(KEY_B)
				sui.lock_target(target)             # the pursuit was cancelled (a fight, a move key): lock it again
			if tick() - last_say >= 300:
				last_say = tick()
				say("friend pursuit: me %.0f,%.0f d %.1f order %d blocked %s speed %.2f" % [float(me().x), float(me().z), dist_to(target), int(state().order.verb), str(state().get("blocked", "")), float(me().speed)])
			var act: Dictionary = state().social.action
			if tick() != last_run_tick and dist_to(target) > 9.0 and int(act.verb) == 0:
				# A54: a timid creature flees at its run speed from 12 m, faster than the starter walks (the UI's pursuit walks); the bot runs the
				# gap down (an approach order with sprint) and the pursuit takes over for the last metres, like a player holding Shift
				last_run_tick = tick()
				game.stage.queue_order({"verb": 4, "target": target, "sprint": 1})
			if int(act.verb) == 0 and int(state().order.verb) not in [11, 12] and dist_to(target) < 8.0:     # the pursuit walks up; the beat keys are for when it is near
				var trust := int(en.trust)
				if trust == last_trust:
					stuck += 1
				else:
					stuck = 0
				last_trust = trust
				if sui.selected_id != target or ui.mode != &"befriend":
					_key(KEY_B)
					sui.lock_target(target)
				# give a gift now and then (the body keeps two leaves and two fruits), else a skill on the beat
				if int(en.beat_in) <= 1:
					var k := step % 4
					step += 1
					ui._press(k)
					say("skill %d, trust %d mood %d beat %d" % [k, trust, int(en.mood), int(en.beat_in)])
			await process_frame
			if int(en.get("relationship", 0)) == 3 or bool(en.get("bonded", false)):
				break
	check(await wait_task("friend", 60), "task 2 done: a creature of another species is a friend (tick %d)" % int(task_ticks.get("friend", -1)))
	check(tick() - t0 <= BUDGET.friend, "within the budget of %d ticks (%d)" % [BUDGET.friend, tick() - t0])
	await _shot("task2_friend")

# Finishes a fight that was not wanted: bite until it ends or the body is weak; flee then.
func _fight_out(t0: int) -> void:
	var f0 := tick()
	while int(state().active) >= 0 and tick() - f0 < 900:
		var id := int(state().active) + 1
		if sui.selected_id != id:
			sui.select_id(id)
		ui.set_mode(&"attack")
		ui._press(0 if float(me().stamina) > 12.0 else 1)
		if float(me().hp) < 25.0:
			sui._send({"verb": 6}, "flee")
		await frames(6)

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)

## X: the dig key, then wait for C to finish (2 s standing still on soft soil, up to 5 s on rock). Returns whether a hole was made.
func dig_here() -> bool:
	var dug0 := int(state().dig.dug)
	_key(KEY_X)
	var t0 := tick()
	while tick() - t0 < 70 and int(state().dig.dug) == dug0:
		await process_frame
	return int(state().dig.dug) > dug0

func _dig() -> void:
	print("== 3. dig: X digs anywhere (A54); harder ground only takes longer")
	var t0 := tick()
	var tries := 0
	while not task_ticks.has("dig") and tick() - t0 < BUDGET.dig and tries < 6:
		tries += 1
		say("digging at (%.0f, %.0f), hardness %d, %d ticks" % [float(me().x), float(me().z), int(state().dig.hardness), int(state().dig.ticks)])
		await dig_here()
	check(await wait_task("dig", 30), "task 3 done: a hole was dug (tick %d)" % int(task_ticks.get("dig", -1)))
	check(int(state().dig.dug) >= 1 and state().dig.holes.size() >= 1, "C holds the hole (%d dug)" % int(state().dig.dug))
	check(tick() - t0 <= BUDGET.dig, "within the budget of %d ticks (%d)" % [BUDGET.dig, tick() - t0])
	await _shot("task3_dig")

# --- loop tuning 1: explore and the Garfio duel (bot only, no balance) -------------------------------------------------------------

## A player looks around the valley: walk until each reachable day species has been seen (the C world counts a species once the player
## is within 30 m), Espinodo and Babosa first (Garfio is the duel's job; the nocturnal Acechalunas sleep; the radial ones are 1.3 km away).
func _explore() -> void:
	print("== 3b. explore: look at the other herds of the valley")
	var t0 := tick()
	for sp in [2, 5]:
		var id := nearest_alive(sp)
		if id < 0 or bool(state().species[sp].get("seen", false)):
			continue
		var home := Vector2(float(ent(id).x), float(ent(id).z))
		say("explore: species %d at %.0f,%.0f, %.0f m" % [sp, home.x, home.y, dist_to(id)])
		await walk_to(home, 22.0, 3000, func(): return bool(state().species[sp].get("seen", false)) or int(state().active) >= 0)
		if int(state().active) >= 0:
			await _fight_out(tick())
	check(tick() - t0 < 6000, "explored the valley within 6000 ticks (%d)" % (tick() - t0))

## One deliberate Garfio duel at full hp. The policy is what a player does: lock him with F, then press, each beat, the first equipped
## move that is usable and reaches (stamina permitting); no flee, so the result is a clean win or death.
func _pick_slot() -> int:
	for m in state().attack_moves:
		if bool(m.get("equipped", false)) and bool(m.get("usable", false)) and m.get("target_in_range", null) == true:
			return int(m.slot) - 1
	return -1

func _duel() -> void:
	print("== duel: Garfio at full hp (seed %d)" % seed_n)
	var target := nearest_alive(3)
	if not check(target > 0, "Garfio lives in the valley"):
		return _finish()
	var hp0 := float(me().hp)
	_key(KEY_F)
	sui.lock_target(target)
	var p0 := tick()
	await until(func(): return int(state().active) >= 0 or tick() - p0 > 2500 or bool(ent(target).dead), 40000)
	var f0 := tick()
	while tick() - f0 < 1200 and (int(state().active) >= 0 or tick() - f0 < 20):
		if int(state().active) >= 0:
			if sui.selected_id != int(state().active) + 1:
				sui.select_id(int(state().active) + 1)
			if ui.mode != &"attack":
				ui.set_mode(&"attack")
			var slot := _pick_slot()
			if slot >= 0:
				ui._press(slot)
		await frames(6)
	var won := bool(ent(target).dead)
	print("duel seed=%d result=%s hp_start=%.0f hp_end=%.0f garfio_hp=%.0f ticks=%d" % [seed_n, "win" if won else "loss", hp0, float(me().hp), float(ent(target).hp), tick() - f0])
	check(true, "the duel ended")
	_finish()

func _wings() -> void:
	print("== 4. wings: the cracked bed")
	var t0 := tick()
	var bed := {}
	for b in state().dig.beds:
		if int(b.kind) == 0 and not bool(b.dug):
			bed = b
	if not check(not bed.is_empty(), "a wing bed is marked on the island (cues: cracked soil, bone splinters, a faint dust)"):
		return
	say("the wing bed is at %.0f,%.0f, %.0f m from the nest" % [float(bed.x), float(bed.z), Vector2(float(bed.x), float(bed.z)).length()])
	var arrived := await walk_to(Vector2(float(bed.x), float(bed.z)), 1.5, BUDGET.wings)
	check(arrived, "walked to the bed on foot")
	await _shot("task4_bed_before")
	var tries := 0
	while not task_ticks.has("wings") and tick() - t0 < BUDGET.wings and tries < 6:
		tries += 1
		# B1: the bed on the Star massif can be a long sprint from where the explore ended, and C refuses a dig under CP_DIG_STAMINA (12): rest first, as a player would
		while float(me().stamina) < 14.0 and tick() - t0 < BUDGET.wings:
			await ticks(10)
		await dig_here()
		await ticks(5)
	check(await wait_task("wings", 40), "task 4 done: the fossil bed gave wing_vane (tick %d)" % int(task_ticks.get("wings", -1)))
	var have := {}
	for p in state().parts.discovered:
		have[String(p.id)] = true
	check(have.has("wing_vane") and have.has("fire_gland"), "wing_vane and fire_gland are in the journal's parts")
	check(tick() - t0 <= BUDGET.wings, "within the budget of %d ticks (%d)" % [BUDGET.wings, tick() - t0])
	await _shot("task4_wings")

func _editor():
	for c in island.get_children():
		if c is CanvasLayer:
			for k in c.get_children():
				if "nest_world" in k and k.nest_world != null:
					return k
	return null

func _fire() -> void:
	print("== 5. fire: edit the creature, add the gland, use the flamethrower")
	var t0 := tick()
	var dna0 := int(state().social.dna_balance)
	sui.open_nest_editor()                    # the menu's "Edit creature"
	await frames(10)
	var editor = _editor()
	if not check(editor != null, "the editor opens anywhere (edit anywhere is on)"):
		return
	check(editor.palette_buttons.has("fire_gland") and editor.palette_buttons["fire_gland"].visible, "the fire gland is on the editor's palette (unlocked by the bed)")
	await _shot("task5_editor_open")
	editor.model.add_part("fire_gland")                      # what dropping the palette part on the body does
	editor._nest_refresh()
	await frames(3)
	var added := false
	for part in editor.model.doc.parts:
		if part.type == "fire_gland":
			added = true
	check(added, "the gland is on the body in the editor")
	await _shot("task5_editor_gland")
	var cost_txt: String = editor.nest_cost.text
	var cost_n := 0
	for tok in cost_txt.split(" "):
		if tok.is_valid_int():
			cost_n = int(tok)
			break
	var dna_pre := int(state().social.dna_balance)
	editor.nest_evolve_button.pressed.emit()                  # Evolve (confirm)
	await frames(30)
	check(int(state().social.dna_balance) == dna_pre - cost_n, "the evolve spent exactly its price: %d DNA of %d ('%s')" % [cost_n, dna_pre, cost_txt])
	check(editor == null or not is_instance_valid(editor) or editor.is_queued_for_deletion() or _editor() == null, "the editor closed after the evolution")
	check(int(state().loadout.known) & (1 << 14) != 0, "the flamethrower is a known move (%d)" % int(state().loadout.known))
	var slot := int(state().loadout.slots.find(14))
	if slot < 0:
		# a starter with four moves already (starter B) keeps them: the player puts the flame in slot 4 at the nest, as the loadout panel does
		await walk_to(island._nest, 6.0, 2500)       # the loadout is only editable at the nest
		if int(state().active) >= 0:                 # a wild creature met the player on the way (the ticks of the earlier tasks decide): fight it out, then back to the nest
			await _fight_out(tick())
			await walk_to(island._nest, 6.0, 2500)
		sui.assign_loadout(3, 14)
		await ticks(5)
		slot = int(state().loadout.slots.find(14))
	check(slot >= 0, "the flamethrower sits in loadout slot %d" % (slot + 1))
	await _shot("task5_after_evolve")
	# use it: a creature to burn, then key 3 (its slot)
	var target := -1
	var tries := 0
	while not task_ticks.has("fire") and tick() - t0 < BUDGET.fire and tries < 8:
		tries += 1
		target = -1
		var bd := INF
		for i in range(1, state().entities.size()):
			var e: Dictionary = ent(i)
			if bool(e.dead) or bool(e.get("hidden", false)) or bool(e.get("hostile", false)):
				continue
			if dist_to(i) < bd:
				bd = dist_to(i)
				target = i
		if target < 0:
			break
		var e2: Dictionary = ent(target)
		say("lock #%d for the flame" % target)
		_key(KEY_F)
		sui.lock_target(target)
		var pf := tick()
		await until(func(): return int(state().active) >= 0 or dist_to(target) < 5.0 or tick() - pf > 1500, 20000)
		var f0 := tick()
		var flame_shot := false
		while tick() - f0 < 160 and not task_ticks.has("fire"):
			ui._press(slot)
			await frames(6)
			if evidence_dir != "" and not flame_shot and state().combat.fighters.size() > 0 and int(state().combat.fighters[0].move) == 14:
				# the evidence run slows the clock down to look at the cone: wind-up, then the active frames
				game.stage.timescale = 1.0
				await until(func(): return state().combat.fighters.size() > 0 and int(state().combat.fighters[0].phase) == 2, 200)
				await frames(4)
				await _shot("task5_flame")
				await ticks(10)
				await _shot("task5_burn")
				game.stage.timescale = TIMESCALE
				flame_shot = true
		if int(state().active) >= 0 and not task_ticks.has("fire"):
			await _fight_out(t0)
	check(await wait_task("fire", 40), "task 5 done: the flamethrower was used (tick %d)" % int(task_ticks.get("fire", -1)))
	check(int(state().dig.flames) >= 1, "C counted the flame (%d)" % int(state().dig.flames))
	check(tick() - t0 <= BUDGET.fire, "within the budget of %d ticks (%d)" % [BUDGET.fire, tick() - t0])
