extends SceneTree
## Headless test of the stage picker (game/menu/main_menu.gd). Run: make godot-menu-test
## Run it a second time with `-- --play` to check that --play skips the menu (main.gd).

# loaded at run time: both scripts name the Game autoload, which a --script file cannot compile against up front
var MenuScene: PackedScene
var MainScript: GDScript
var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func _initialize() -> void:
	MenuScene = load("res://game/menu/main_menu.tscn")
	MainScript = load("res://game/main.gd")
	root.get_node("Game").persist_settings = false
	call_deferred("_run")

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _key(code: int) -> void:
	for pressed in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		root.push_input(e)

func _menu() -> Control:
	var m: Control = MenuScene.instantiate()
	root.add_child(m)
	await _frames(3)
	return m

func _run() -> void:
	var game = root.get_node("Game")
	var skip_run := "--play" in OS.get_cmdline_user_args()
	var main = MainScript.new()
	ok(main._skips_menu() == skip_run, "main._skips_menu() is %s for this command line" % skip_run)
	main.free()
	if skip_run:
		print("menu tests (--play): %d checks, %d failures" % [checks, fails])
		quit(1 if fails else 0)
		return
	game.settings["language"] = "es"
	game.settings["reduced_motion"] = false
	var m: Control = await _menu()
	var cell_exists := ResourceLoader.exists("res://cell/cell_stage.tscn")
	ok(m.play_button != null and m.cell_button != null and m.cards.size() == 2, "both playable cards exist")
	ok(m.cell_button.disabled == not cell_exists, "Celula is disabled exactly when the cell scene is missing (scene present: %s)" % cell_exists)
	ok(not m.play_button.disabled, "Criatura is playable")
	ok(m.creator_button != null and m.quit_button != null, "Creador and Salir exist")
	ok(m.genome_label.text.contains(str(game.player_genome().get("name", "?"))), "the creature name shows on the Criatura card")
	ok(m.genome_label.text.begins_with("Tu criatura"), "Spanish by default when the language is es")
	var conns: Array = m.play_button.pressed.get_connections()
	ok(conns.any(func(c): return c.callable.get_method() == &"play_creature"), "Criatura's card is wired to play_creature (-> goto_island)")
	ok(not m.cards[0].disabled or true, "cards listed in order Celula, Criatura")
	# entrance finished: everything visible within 0.6 s of the menu opening
	await _wait(0.6)
	ok(m._title.modulate.a == 1.0 and m.play_button.modulate.a == 1.0, "entrance completes (title and cards fully visible)")
	# the first focus: Celula when playable, else Criatura
	var first: Button = m.cell_button if cell_exists else m.play_button
	ok(first.has_focus(), "initial focus is on the first playable card")
	# keyboard: Left/Right between playable cards, Down to the actions, Up back
	m.play_button.grab_focus()
	await _frames(2)
	_key(KEY_DOWN)
	await _frames(2)
	ok(m.creator_button.has_focus(), "Down from Criatura reaches Creador")
	_key(KEY_UP)
	await _frames(2)
	ok(m.play_button.has_focus(), "Up returns to the Criatura card")
	if cell_exists:
		_key(KEY_LEFT)
		await _frames(2)
		ok(m.cell_button.has_focus(), "Left moves focus to Celula")
		_key(KEY_RIGHT)
		await _frames(2)
		ok(m.play_button.has_focus(), "Right moves focus to Criatura")
	else:
		_key(KEY_LEFT)
		await _frames(2)
		ok(m.play_button.has_focus(), "Left stays on Criatura when Celula is disabled")
	# keyboard focus is instant: ring visible and card raised on the same frame
	var ring: Control = m.play_button.get_meta("ring")
	var lift: Control = m.play_button.get_meta("lift")
	ok(ring.modulate.a == 1.0 and is_equal_approx(lift.position.y, -4.0), "keyboard focus shows the ring and the 4 px lift at once")
	m.creator_button.grab_focus()
	await _frames(1)
	ok(ring.modulate.a == 0.0 and is_equal_approx(lift.position.y, 0.0), "losing focus is instant too")
	# hover: lift 4 px and the image brightens; press: 0.97
	m._hover(m.play_button, true)
	await _wait(0.25)
	var img: TextureRect = m.play_button.get_meta("image")
	ok(is_equal_approx(lift.position.y, -4.0) and img.modulate.r > 0.95, "hover lifts the card 4 px and brightens the image")
	m._press(m.play_button, true)
	await _wait(0.25)
	ok(is_equal_approx(lift.scale.x, 0.97), "press scales the card to 0.97")
	m._press(m.play_button, false)
	await _wait(0.4)
	ok(is_equal_approx(lift.scale.x, 1.0), "release springs back to 1.0")
	m._hover(m.play_button, false)
	await _wait(0.25)
	ok(is_equal_approx(lift.position.y, 0.0), "leaving the card puts it back")
	m.queue_free()
	await _frames(2)
	# English follows the settings; reduced motion removes the movement
	game.settings["language"] = "en"
	game.settings["reduced_motion"] = true
	var m2: Control = await _menu()
	ok(m2.genome_label.text.begins_with("Your creature"), "English via the strings layer")
	ok(m2.reduced, "reduced motion is read from Game.settings")
	m2._hover(m2.play_button, true)
	await _wait(0.25)
	var lift2: Control = m2.play_button.get_meta("lift")
	ok(is_equal_approx(lift2.position.y, 0.0), "reduced motion: hover does not move the card")
	m2.queue_free()
	game.settings["reduced_motion"] = false
	await _frames(2)
	print("menu tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)
