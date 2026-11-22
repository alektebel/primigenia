extends SceneTree
# make godot-verb-target-test: verb-first targeting through the real island, UI and C world (docs/briefs/verb-target.md).
#   arm a verb (key or bar), hover, click to lock, red/green arrows follow the creature, the player pursues and acts, Esc / right
#   click cancel, switching verb keeps a valid target, the pick radius on a fast creature. With an output dir argument it also
#   writes the evidence JPGs (software GL under xvfb); headless it only checks.
# godot --headless --fixed-fps 60 --path godot --script res://game/tests/verb_target_test.gd -- [<output dir>]

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Pointer := preload("res://game/player/pointer.gd")
const Marker := preload("res://ui/target_marker.gd")

class ErrorLog extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _bt: Array) -> void:
		if error_type != Logger.ERROR_TYPE_WARNING:
			errors.append("%s:%d %s %s" % [file.get_file(), line, code, rationale])

var out_dir := ""
var checks := 0
var failures := 0
var log := ErrorLog.new()
var game
var island
var sui
var ui
var stage

func check(ok: bool, what: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)
	return ok

func _initialize() -> void:
	OS.add_logger(log)
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	if out_dir == "":
		return
	await settle(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_jpg(out_dir.path_join(name + ".jpg"), 0.9)
	print("wrote ", name)

func ticks(n: int) -> void:
	var t0: int = stage.cur.tick
	var guard := 0
	while stage.cur.tick - t0 < n and guard < 20000:
		await process_frame
		guard += 1

func key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e

func press_key(code: Key) -> void:
	# through the UI's own input path, as a key press reaches it
	ui._unhandled_input(key(code))

func me() -> Dictionary:
	return stage.cur.entities[0]

func ent(id: int) -> Dictionary:
	return stage.cur.entities[id]

func dist(id: int) -> float:
	return Vector2(float(ent(id).x) - float(me().x), float(ent(id).z) - float(me().z)).length()

## Brings creature `id` to `d` metres ahead of the camera on the ground (so it is on screen), rotated `side` metres to the right.
func place_ahead(id: int, d: float, side: float = 0.0) -> void:
	var cam: Camera3D = game.camera
	var fwd := -cam.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var p := Vector3(float(me().x), 0.0, float(me().z)) + fwd * d + right * side
	stage.debug_now({"op": 1, "id": id, "x": p.x, "z": p.z})

func screen_of(id: int) -> Vector2:
	var h: Node3D = island.hosts[id]
	var feet: Vector3 = h.global_position
	return game.camera.unproject_position(feet + Vector3(0, h.height() * 0.5, 0))

func finish() -> void:
	check(log.errors.is_empty(), "no errors during the run (%d: %s)" % [log.errors.size(), str(log.errors.slice(0, 3))])
	OS.remove_logger(log)
	print("verb target test: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ""
	if out_dir != "":
		DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	game.settings["onboarding"] = 0x1ff
	var entry := TerrainCache.load_entry({"seed": 1}, "user://terrain-secrets")
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new(), "user://terrain-secrets")
	game.set_island(entry)
	game.goto_island()
	var t_wait := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_wait < 150000:       # the island builds under a loading screen on worker threads
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null and not current_scene._building:
			break
	await settle(30)
	island = current_scene
	if island == null or island.get("stage_ui") == null:
		check(false, "the island did not open")
		return finish()
	sui = island.stage_ui
	ui = sui.ui
	stage = game.stage
	stage.timescale = 1.0 if out_dir == "" else 4.0        # software GL renders slowly: the evidence run keeps the clock quick
	if not check(sui != null and ui.verb_bar != null and ui.marker != null, "the stage has the verb bar and the target marker"):
		return finish()
	# a quiet field: the wild freezes while we place things, then runs again for the moving tests
	stage.debug_now({"op": 6, "a": 2})
	stage.debug_now({"op": 1, "id": 1, "x": float(me().x) + 150.0, "z": float(me().z) + 150.0})      # Garfio (hostile) stays out of the way
	var rondo := -1
	var zanco := -1
	for i in range(1, stage.cur.entities.size()):
		var sp := int(stage.cur.entities[i].species)
		if sp == 0 and rondo < 0:
			rondo = i
		elif sp == 1 and zanco < 0:
			zanco = i
	check(rondo > 0 and zanco > 0, "a Rondo (%d) and a Zanco (%d) live on the island" % [rondo, zanco])
	await ticks(3)

	# --- 1. arm a verb -------------------------------------------------------------------------------------------------
	check(not sui.verb_is_armed() and ui.verb_bar.armed == &"", "no verb is armed at the start")
	check(InputMap.has_action("verb_attack") and InputMap.has_action("verb_befriend") and InputMap.has_action("verb_eat"), "the verb keys exist (F, B, R, O, I)")
	var orders0: int = sui.attack_orders.size()
	press_key(KEY_F)
	check(sui.verb == &"attack" and ui.verb_bar.armed == &"attack", "F arms Attack")
	check(sui.attack_orders.size() == orders0 and int(stage.cur.order.verb) <= 1, "arming orders nothing")
	press_key(KEY_B)
	check(sui.verb == &"befriend" and ui.verb_bar.armed == &"befriend", "B switches to Befriend")
	ui.verb_bar.choose(0)
	check(sui.verb == &"attack", "a click on the bar's first circle arms Attack too")
	var s0: Vector2 = ui.verb_bar.slot_pos(0)
	check(ui.verb_bar.slot_at(s0) == 0 and ui.verb_bar.slot_at(Vector2(5, 5)) == -1, "the bar's circles are hit-tested")

	# --- 2. hover and lock on a still creature -------------------------------------------------------------------------
	place_ahead(rondo, 14.0)
	await ticks(3)
	await settle(3)
	var c: Vector2 = screen_of(rondo)
	check(c.x > 0 and c.x < 1280 and c.y > 0 and c.y < 720, "the Rondo is on screen at %s" % str(c))
	check(sui.pick_for_verb(c) == rondo, "hover: the pick at the creature is the Rondo")
	check(sui.pick_for_verb(c + Vector2(60, 40)) == rondo, "hover: a generous radius, 60 px right and 40 px down still picks it")
	check(sui.pick_for_verb(Vector2(40, 40)) == -1, "hover: far from every creature picks nothing")
	check(sui.pick_for_verb(c, &"eat") == -1, "Eat does not pick a living creature")
	await shot("1_attack_armed_hover")
	island._click_ground(true, c + Vector2(30, -20))
	await settle(2)
	check(sui.locked_id == rondo and ui.marker.locked_id == rondo, "a click near it locks the Rondo")
	check(ui.selected.get("id", -1) == rondo and not ui.ring.visible, "the lock selects it and opens no mode ring")
	check(ui.mode == &"attack", "the mode is Attack")
	check(Marker.color_of(&"attack").r > 0.8 and Marker.color_of(&"attack").g < 0.5, "Attack arrows are red")
	check(Marker.color_of(&"befriend").g > Marker.color_of(&"befriend").r, "Befriend arrows are green")
	check(ui.marker.lock_label == "Rondo" and ui.marker.lock_relation != "", "the marker names it: %s, %s" % [ui.marker.lock_label, ui.marker.lock_relation])
	check(ui.marker.head_point(rondo) != Vector2.INF, "the marker has a head point on screen")
	await shot("2_attack_locked_red")

	# --- 3. auto-pursuit and the verb ----------------------------------------------------------------------------------
	var d0 := dist(rondo)
	await ticks(25)
	check(sui.attack_orders.any(func(o): return str(o.order).begins_with("attack #%d" % rondo)), "the stage sent the attack order by itself")
	check(dist(rondo) < d0 - 1.0 or stage.cur.active >= 0, "the player walked towards it unasked (%.1f -> %.1f m)" % [d0, dist(rondo)])
	var guard := 0
	while stage.cur.active < 0 and guard < 600 and not bool(ent(rondo).dead):
		await ticks(5)
		guard += 1
	check(stage.cur.active >= 0 or bool(ent(rondo).dead), "the attack began on its own when in range (fight %s)" % str(stage.cur.active >= 0))
	check(ui.marker.locked_id == rondo or bool(ent(rondo).dead), "the marker stayed on it through the pursuit")
	await shot("3_pursuit_fight")

	# --- 4. the marker follows a moving creature -----------------------------------------------------------------------
	stage.debug_now({"op": 6, "a": 2})
	stage.debug_now({"op": 3, "id": rondo})         # the fight ends with its target
	var gd := 0
	while stage.cur.active >= 0 and gd < 30:
		await ticks(10)
		gd += 1
	if stage.cur.active >= 0:
		sui._send({"verb": 6}, "flee")
		await ticks(60)
	check(stage.cur.active < 0, "the fight ended")
	press_key(KEY_ESCAPE)
	await settle(2)
	check(not sui.verb_is_armed() and sui.locked_id < 0 and ui.marker.locked_id < 0 and not ui.paused, "Esc cancels the verb and the lock (and does not pause)")
	press_key(KEY_B)
	var target := zanco
	place_ahead(target, 16.0, -4.0)
	await ticks(3)
	await settle(3)
	var c0: Vector2 = screen_of(target)
	check(sui.lock_target(target), "Befriend locks a Zanco")
	await settle(3)
	check(ui.mode == &"befriend" and ui.marker.lock_mode == &"befriend" and ui.marker.lock_hint != "", "Befriend: the card says what to press (%s)" % ui.marker.lock_hint)
	var h_before: Vector2 = ui.marker.head_point(target)
	var tp0: Vector3 = island.hosts[target].global_position
	# the creature runs 6 m across the view over 12 frames while the stage keeps running
	var p := Vector3(float(ent(target).x), 0, float(ent(target).z))
	for k in 12:
		var cam: Camera3D = game.camera
		var right := cam.global_transform.basis.x
		right.y = 0.0
		right = right.normalized()
		p += Vector3(right.x, 0, right.z) * 0.6
		stage.debug_now({"op": 1, "id": target, "x": p.x, "z": p.z})
		await process_frame
	await settle(2)
	var h_after: Vector2 = ui.marker.head_point(target)
	var feet_now: Vector3 = island.hosts[target].global_position
	var expect: Vector2 = game.camera.unproject_position(feet_now + Vector3(0, island.hosts[target].height(), 0))
	check(feet_now.distance_to(tp0) > 2.0, "the creature moved %.1f m" % feet_now.distance_to(tp0))
	check(h_before.distance_to(h_after) > 15.0, "the marker moved with it (%.0f px)" % h_before.distance_to(h_after))
	check(h_after.distance_to(expect) < 5.0, "the marker sits over the head of the moving creature (%.1f px off)" % h_after.distance_to(expect))
	await shot("4_befriend_locked_green")

	# --- 5. befriend pursuit: APPROACH, then the keys ----------------------------------------------------------------
	stage.debug_now({"op": 6, "a": 2})
	place_ahead(target, 18.0)
	await ticks(2)
	sui.arm_verb(&"befriend")                     # re-arm: the lock stays and the order is re-sent
	check(sui.locked_id == target, "re-arming the same verb keeps the lock")
	var d1 := dist(target)
	var saw_approach := false
	for k in 40:
		await process_frame
		if int(stage.cur.order.verb) == 4:
			saw_approach = true
	await ticks(30)
	check(saw_approach, "Befriend walks up with the APPROACH order")
	check(dist(target) < d1 - 3.0, "and the player closed in (%.1f -> %.1f m)" % [d1, dist(target)])
	await ticks(60)
	press_key(KEY_1)
	await ticks(8)
	check(int(stage.cur.social.action.verb) == 11 or int(ent(target).trust) > 0, "key 1 sings: the rhythm keys still work after the lock")

	# --- 6. switching verb keeps a valid target ------------------------------------------------------------------------
	press_key(KEY_F)
	check(sui.verb == &"attack" and sui.locked_id == target and ui.marker.lock_mode == &"attack", "switching to Attack keeps the same target, now red")
	press_key(KEY_R)
	check(sui.verb == &"eat" and sui.locked_id < 0, "switching to Eat drops a living target (it is not remains)")
	cancel_all()

	# --- 7. Eat on remains, Observe -----------------------------------------------------------------------------------
	stage.debug_now({"op": 3, "id": rondo})
	await ticks(3)
	place_ahead(rondo, 7.0, 1.0)
	await ticks(2)
	await settle(3)
	press_key(KEY_R)
	var rc: Vector2 = screen_of(rondo)
	check(sui.pick_for_verb(rc) == rondo, "Eat picks the remains")
	island._click_ground(true, rc)
	await settle(2)
	check(sui.locked_id == rondo and ui.marker.lock_mode == &"eat", "a click locks the remains with Eat")
	await ticks(120)
	check(int(stage.cur.social.action.verb) == 15 or int(ent(rondo).meat) < 4, "the player ate on its own")
	cancel_all()
	# --- 8. right click cancels ---------------------------------------------------------------------------------------
	press_key(KEY_O)
	place_ahead(zanco, 15.0)
	await ticks(2)
	check(sui.lock_target(zanco), "Observe locks a Zanco")
	var rb := InputEventMouseButton.new()
	rb.button_index = MOUSE_BUTTON_RIGHT
	rb.position = Vector2(300, 300)
	rb.pressed = true
	island._on_button(rb)
	var rr := rb.duplicate()
	rr.pressed = false
	island._on_button(rr)
	check(not sui.verb_is_armed() and sui.locked_id < 0, "a right click (no orbit drag) cancels the verb and the lock")
	await shot("5_cancelled")

	# --- 9. the pick radius on a fast creature -------------------------------------------------------------------------
	stage.debug_now({"op": 6, "a": 2})
	press_key(KEY_F)
	await settle(2)
	var near_ok := 0
	for d in [8.0, 20.0, 45.0, 90.0]:
		place_ahead(zanco, d)
		await ticks(2)
		await settle(3)
		var p0: Vector2 = screen_of(zanco)
		var o: Vector3 = game.camera.global_transform.basis.x
		o.y = 0.0
		o = o.normalized()
		# it runs 8 m/s: 0.25 s after the aim (click reaction time) it is 2 m away from where the pointer was
		var h: Node3D = island.hosts[zanco]
		stage.debug_now({"op": 1, "id": zanco, "x": float(ent(zanco).x) + o.x * 2.0, "z": float(ent(zanco).z) + o.z * 2.0})
		await ticks(2)
		await settle(3)
		var moved: Vector2 = screen_of(zanco)
		var off := p0.distance_to(moved)
		var got: int = sui.pick_for_verb(p0)
		if got == zanco:
			near_ok += 1
		print("   at %2.0f m: a 2 m lag is %.0f px; the pick at the old spot gives #%d" % [d, off, got])
	check(near_ok == 4, "the pick finds a creature 2 m from the aim at 8, 20, 45 and 90 m (%d of 4)" % near_ok)
	cancel_all()
	if out_dir != "":
		await evidence_extra(zanco)
	finish()

# Evidence only: red arrows on the hostile Garfio while it moves, green arrows on a creature being befriended until it is a friend.
func evidence_extra(zanco: int) -> void:
	stage.debug_now({"op": 4, "id": 0})
	stage.debug_now({"op": 6, "a": 1})
	press_key(KEY_F)
	place_ahead(1, 13.0, 2.0)
	await ticks(2)
	await settle(3)
	sui.lock_target(1)
	await ticks(12)
	await settle(2)
	print("   garfio: relation '%s'" % ui.marker.lock_relation)
	await shot("hostile_red_arrows_moving")
	await ticks(4)
	await shot("hostile_red_arrows_moving_b")
	cancel_all()
	stage.debug_now({"op": 6, "a": 2})
	stage.debug_now({"op": 4, "id": 0})
	if stage.cur.active >= 0:
		sui._send({"verb": 6}, "flee")
		await ticks(40)
	stage.debug_now({"op": 1, "id": 1, "x": float(me().x) + 90.0, "z": float(me().z) + 90.0})
	press_key(KEY_B)
	place_ahead(zanco, 9.0, -2.0)
	await ticks(3)
	await settle(3)
	sui.lock_target(zanco)
	var n := 0
	var step := 0
	while n < 1400 and int(ent(zanco).get("relationship", 0)) < 2 and not bool(ent(zanco).get("bonded", false)):
		n += 1
		if int(ent(zanco).beat_in) <= 1 and int(stage.cur.social.action.verb) == 0:
			press_key([KEY_1, KEY_2, KEY_3, KEY_4][step % 4])
			step += 1
		await process_frame
	await settle(3)
	print("   friend: relationship %d trust %d after %d frames, label %s" % [int(ent(zanco).get("relationship", 0)), int(ent(zanco).trust), n, ui.marker.lock_relation])
	await shot("friend_green_arrows")
	cancel_all()

func cancel_all() -> void:
	if sui.verb_is_armed() or sui.locked_id > 0:
		sui.cancel_verb()
