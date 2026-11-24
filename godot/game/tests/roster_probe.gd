extends SceneTree
# Measuring probe (loop tuning): boots the island like first_quest_e2e, leaves the player idle, and prints every wild creature's
# species, distance from the nest and from the player at tick 0 and every 600 ticks (60 s of the 10 Hz world) up to 6000.
# Usage: godot --headless --path godot --script res://game/tests/roster_probe.gd -- seed=1
var game
var island
var seed_n := 1

func tick() -> int:
	return int(game.stage.cur.tick)

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="):
			seed_n = int(a.substr(5))
	_run.call_deferred()

func _dump(tag: String) -> void:
	var st: Dictionary = game.stage.cur
	var me: Dictionary = st.entities[0]
	var nest := Vector2(float(me.x), float(me.z)) if tag == "t0" else Vector2.ZERO
	var names := {}
	var roster: Array = st.get("species", [])
	for k in roster.size():
		names[k] = str(roster[k].get("name", k))
	var rows := {}
	for i in range(1, st.entities.size()):
		var e: Dictionary = st.entities[i]
		var sp := int(e.species)
		var p := Vector2(float(e.x), float(e.z))
		var row := "%s#%d(%.0f,%.0f nest %.0f%s)" % [names.get(sp, str(sp)), i, p.x, p.y, p.length(), " dead" if bool(e.dead) else ""]
		rows[sp] = str(rows.get(sp, "")) + " " + row
	print("== ", tag, " tick ", tick())
	for sp in rows:
		print("  ", rows[sp])

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
	game.settings["onboarding"] = 0x1ff
	change_scene_to_file("res://game/main.tscn")
	var n := 0
	while not (current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with("main_menu.gd")) and n < 3000:
		await process_frame
		n += 1
	current_scene.play_button.pressed.emit()
	var t0 := Time.get_ticks_msec()
	while not (current_scene != null and current_scene.get_script() != null and current_scene.get_script().resource_path.ends_with("island.gd") and not current_scene._building) and Time.get_ticks_msec() - t0 < 90000:
		await process_frame
	island = current_scene
	await process_frame
	game.stage.timescale = 16.0
	game.stage.max_steps_per_frame = 60
	_dump("t0")
	for k in range(1, 11):
		while tick() < k * 600:
			await process_frame
		_dump("t%d" % (k * 60))
	quit(0)
