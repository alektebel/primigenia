extends SceneTree
## Headless tests for godot/ui and godot/audio. Run: make godot-ui-test

const Modes := preload("res://ui/modes.gd")
const JournalData := preload("res://ui/journal_data.gd")
const Note := preload("res://ui/field_note.gd")
const Mock := preload("res://ui/mock_source.gd")
const GameUI := preload("res://ui/game_ui.gd")
const Ring := preload("res://ui/mode_ring.gd")
const Palette := preload("res://ui/palette.gd")
const Style := preload("res://ui/style.gd")
const Glyphs := preload("res://ui/glyphs.gd")
const Strings := preload("res://ui/strings.gd")
const Onboarding := preload("res://ui/onboarding.gd")
const AudioManager := preload("res://audio/audio_manager.gd")
const Settings := preload("res://audio/audio_settings.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)

func ids(list: Array) -> Array:
	return list.map(func(a): return a["id"])

func _initialize() -> void:
	root.get_node("Game").persist_settings = false           # the tests never write the player's settings
	root.get_node("Game").settings["language"] = "en"      # the tests read English strings whatever the OS language
	test_foundations()
	test_modes()
	test_journal_data()
	test_field_note()
	test_ring_geometry()
	test_minimap()
	test_social_ui()
	test_volumes()
	test_sounds()
	call_deferred("_finish")

func _finish() -> void:
	await test_ui_flow()
	await test_loadout_ui()
	await test_signs_and_words()
	await test_menu_and_onboarding()
	await test_audio_manager()
	print("ui tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func test_modes() -> void:
	ok(ids(Modes.abilities_for(Modes.ATTACK)) == ["bite", "charge", "spit", "tail_strike"], "attack abilities")
	ok(ids(Modes.abilities_for(Modes.BEFRIEND)) == ["sing", "dance", "charm", "pose"], "befriend abilities")
	ok(ids(Modes.abilities_for(Modes.OBSERVE)) == ["observe"], "observe abilities")
	ok(ids(Modes.abilities_for(Modes.INTIMIDATE)) == ["roar", "display"], "intimidate abilities")
	for m in Modes.ALL:
		ok(Modes.abilities_for(m).size() <= 4, "%s fits keys 1-4" % m)

func test_journal_data() -> void:
	# the old creature card's rows live in the journal data now
	var seen := {}
	for info in Mock.all_combinations():
		var s := JournalData.page(info)
		ok(s.temperament == JournalData.TEMPERAMENTS[info.temperament], "temperament text %s" % s.temperament)
		ok(s.relationship == JournalData.RELATIONSHIPS[info.relationship], "relationship text %s" % s.relationship)
		ok(s.diet != "" and s.species != "" and s.resolved.contains("/"), "diet/species/resolved shown")
		ok(s.likes.begins_with("Likes:"), "likes hint shown")
		seen["%s/%s" % [s.temperament, s.relationship]] = true
	ok(seen.size() == 12, "the page renders all 3x4 temperament/relationship pairs (%d)" % seen.size())
	var s2 := JournalData.page({"species": "X", "temperament": "aggressive", "diet": "omnivore", "relationship": "ally"})
	ok(s2.temperament == "Aggressive" and s2.diet == "Omnivore" and s2.relationship == "Ally", "string enums accepted")
	ok(s2.likes.contains("unknown"), "missing likes handled")
	var s3 := JournalData.page({"species": "Rondo", "temperament": 0, "diet": 0, "relationship": 2, "trust": 42, "mood": 25, "likes": ["sing", "fruit"], "dislikes": ["meat"], "resolved": 1, "resolved_total": 4})
	ok(s3.trust.begins_with("42") and s3.mood.begins_with("Joyful") and s3.likes.contains("sing, fruit") and s3.likes.contains("Dislikes: meat") and s3.resolved == "1 / 4", "page shows trust, mood, likes, dislikes and species resolved")
	ok(JournalData.page({"species": "Rondo", "carcass_meat": 3}).note.contains("3 bites"), "the page of a carcass shows the bites left")

func test_field_note() -> void:
	var note := Note.new()
	note.set_info({"id": 5, "species": "Rondo", "name": "Rondo", "diet": 0, "relationship": 2})
	var sn := note.snapshot()
	ok(sn.name == "Rondo" and sn.diet == "Herbivore" and sn.relationship == 2 and sn.sub == "", "the field note carries name, diet and relationship only")
	note.set_info({"id": 6, "species": "Rondo", "carcass_meat": 3})
	var sc := note.snapshot()
	ok(sc.sub == "remains" and sc.diet == "", "a carcass says remains")
	note.free()

func test_ring_geometry() -> void:
	var ring = Ring.new()
	ring.centre = Vector2(400, 300)
	ring.body_half_height = 70.0
	var r: float = ring.radius()
	ok(is_equal_approx(r, clampf(1.6 * 70.0, 84.0, 150.0)), "ring radius follows the body height (%.1f)" % r)
	ok(ring.sector_at(Vector2(0, -r)) == 0, "north = observe")
	ok(ring.sector_at(Vector2(r, 0)) == 1, "east = attack")
	ok(ring.sector_at(Vector2(0, r)) == 2, "south = intimidate")
	ok(ring.sector_at(Vector2(-r, 0)) == 3, "west = befriend")
	ok(ring.sector_at(Vector2(r * 0.7, -r * 0.7)) == 1 and ring.sector_at(Vector2(-r * 0.7, -r * 0.7)) == 3, "the whole east and west halves count, not only the axes")
	ok(ring.sector_at(Vector2(5, 5)) == -1 and ring.sector_at(Vector2(0, -r * 3.0)) == -1, "the centre and far outside are none")
	ok(ring.mode_at(0) == Modes.OBSERVE and ring.mode_at(1) == Modes.ATTACK and ring.mode_at(2) == Modes.INTIMIDATE and ring.mode_at(3) == Modes.BEFRIEND, "modes by side")
	ring.free()

func test_social_ui() -> void:
	# C2: the Eat mode, the carcass radial, the card's trust fields, the beat window
	ok(ids(Modes.abilities_for(Modes.EAT)) == ["eat"] and Modes.is_mode(Modes.EAT), "eat mode")
	ok(Modes.VERB_NUMBERS.befriend == 11 and Modes.VERB_NUMBERS.eat == 15 and Modes.ITEMS == ["plant", "fruit", "meat", "bone"], "verb numbers match world.h")
	var ring = Ring.new()
	ring.carcass = true
	ok(ring.mode_at(1) == Modes.EAT and ring.mode_at(0) == Modes.OBSERVE, "carcass ring: Eat east, Observe north")
	ok(ring.enabled_at(0) and ring.enabled_at(1) and not ring.enabled_at(2) and not ring.enabled_at(3), "carcass ring has no Befriend or Intimidate")
	var chosen := []
	ring.chosen.connect(func(m): chosen.append(m))
	ring.choose(3)
	ring.choose(1)
	ok(chosen == [Modes.EAT], "only Eat is chosen on a carcass")
	ring.free()
	var Gm = load("res://game/island/ground_marks.gd")
	ok(Gm.in_window(0) and Gm.in_window(2) and Gm.in_window(10) and Gm.in_window(11) and not Gm.in_window(3) and not Gm.in_window(9), "beat window is +-2 ticks of a 12 tick beat")

func test_volumes() -> void:
	var path := "user://test_settings_%d.cfg" % Time.get_ticks_usec()
	var s = Settings.new(path)
	ok(is_equal_approx(s.values.master, 0.7), "default master")
	s.set_value("master", 0.25)
	s.set_value("music", 2.0)
	s.set_value("sfx", 0.1)
	s.set_value("ambience", 0.9)
	s.set_value("mute", true)
	var s2 = Settings.new(path)
	ok(is_equal_approx(s2.values.master, 0.25), "master persisted")
	ok(is_equal_approx(s2.values.music, 1.0), "music clamped and persisted")
	ok(is_equal_approx(s2.values.sfx, 0.1) and is_equal_approx(s2.values.ambience, 0.9), "sfx/ambience persisted")
	ok(s2.values.mute == true, "mute persisted")
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("video", "vsync", true)
	cf.save(path)
	s2.set_value("master", 0.5)
	cf.load(path)
	ok(cf.get_value("video", "vsync", false) == true, "other settings sections preserved")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_sounds() -> void:
	var text := FileAccess.get_file_as_string("res://audio/sounds/CREDITS.md")
	var re := RegEx.new()
	re.compile("\\| `([a-z0-9\\-]+\\.ogg)` \\|")
	var files: Array[String] = []
	for m in re.search_all(text):
		files.append(m.get_string(1))
	ok(files.size() == 15, "CREDITS lists 15 sounds (%d)" % files.size())
	var am := AudioManager.new("user://unused.cfg")
	for f in files:
		ok(am.load_stream(f.get_basename()) != null, "loads %s" % f)
		ok(AudioManager.NAMES.has(f.get_basename()), "manager knows %s" % f)
	ok(AudioManager.NAMES.size() == files.size(), "manager list equals credits")
	am.free()

func test_ui_flow() -> void:
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	var presses := []
	ui.ability_pressed.connect(func(i, a): presses.append(a["id"]))
	var modes := []
	ui.mode_changed.connect(func(m): modes.append(m))
	ok(ui.mode == Modes.NONE and ui.abilities.is_empty(), "no default mode: nothing on keys 1-4")
	ui._unhandled_input(_key_event(KEY_1))
	ok(presses.is_empty(), "key 1 does nothing before a mode is chosen")
	ui.set_mode(Modes.BEFRIEND)
	ok(ui.mode == Modes.BEFRIEND and ids(ui.abilities) == ["sing", "dance", "charm", "pose"], "befriend sets abilities")
	ok(ui.petals.count() == 4 and ui.petals.id_at(0) == "sing" and ui.petals.glyph_at(0) == "sing" and ui.petals.id_at(3) == "pose", "the petals show the befriend skills with their glyphs")
	ui.set_mode(Modes.OBSERVE)
	ok(ui.petals.count() == 1 and ui.petals.glyph_at(0) == "observe", "observe shows one petal")
	ui.set_mode(Modes.INTIMIDATE)
	ok(ui.petals.count() == 2 and ui.petals.glyph_at(0) == "roar" and ui.petals.glyph_at(1) == "display", "intimidate shows two petals")
	ok(ids(ui.abilities) == ["roar", "display"], "intimidate abilities in ui")
	ok(modes == [Modes.BEFRIEND, Modes.OBSERVE, Modes.INTIMIDATE], "mode_changed emitted")
	ui.set_mode("bogus")
	ok(ui.mode == Modes.INTIMIDATE, "unknown mode ignored")
	ui.select(Mock.creature(1), true, Vector2(500, 380))
	ok(ui.mode == Modes.NONE and ui.abilities.is_empty() and ui.petals.count() == 0, "select() sets no mode and shows no petals")
	ok(not ui.defence.shown, "no guard and dodge marks without a fight or Attack mode")
	ok(ui.note.visible and ui.ring.visible, "select shows the field note and opens the ring")
	var nsnap: Dictionary = ui.note.snapshot()
	ok(nsnap.name == "Rondo" and nsnap.has("diet") and nsnap.has("relationship"), "the field note carries the species")
	presses.clear()
	ui._unhandled_input(_key_event(KEY_1))
	ok(presses.is_empty(), "keys 1-4 do nothing until a mode is chosen")
	# mouse only: the move keys do not choose a mode
	ui._unhandled_input(_key_event(KEY_A))
	ui._unhandled_input(_key_event(KEY_W))
	ok(ui.mode == Modes.NONE and ui.ring.visible, "W A S D do not choose on the ring (they keep walking)")
	# a click on the west side chooses Befriend; the click is consumed, one outside is not
	var c: Vector2 = ui.ring.centre
	var r: float = ui.ring.radius()
	var outside := _mouse(c + Vector2(0, -r * 4.0), true)
	ok(not ui.ring.handle_input(outside) and ui.ring.visible, "a click outside the hit zones is not consumed")
	var west := _mouse(c + Vector2(-r, 0), true)
	ok(ui.ring.handle_input(west), "a click on the west arc is consumed")
	ok(ui.mode == Modes.BEFRIEND and not ui.ring.visible, "the west side chooses Befriend and closes the ring")
	ok(ui.ring.handle_input(_mouse(c + Vector2(-r, 0), false)), "the release of that click is consumed too")
	ui._unhandled_input(_key_event(KEY_TAB))
	ok(ui.ring.visible, "Tab reopens the ring")
	ui.ring.choose_mode(Modes.ATTACK)
	ok(ui.mode == Modes.ATTACK and not ui.ring.visible, "choose_mode(Attack)")
	ok(ui.defence.shown, "Attack mode shows guard and dodge at your feet")
	var key := InputEventKey.new()
	key.keycode = KEY_2
	key.physical_keycode = KEY_2   # the InputMap actions match physical keys
	key.pressed = true
	ui._unhandled_input(key)
	ok(presses == ["charge"], "key 2 presses ability 2 (%s)" % [presses])
	ui.set_abilities([{"id": "x", "name": "X", "enabled": false}])
	ui._press(0)
	ok(presses.size() == 1, "disabled ability does not fire")
	ui.show_message("Hello")
	ui.show_dna(10)
	ui.show_damage(Vector2(300, 200), 17)
	ui.flash("hit")
	ui.set_windup(0.5, "Charge")
	ui.set_player("Test", 40, 100, 20, 50)
	await process_frame
	ok(ui.words.whisper_text == "Hello", "a message is a whisper line (%s)" % ui.words.whisper_text)
	ui.set_paused(true)
	ok(ui.menu.visible and ui.menu.open and ui.veil.flat_amount > 0.5, "the menu opens over the veil")
	ui.set_paused(false)
	# Esc: closes the ring, keeps the selection; then deselects; then the menu
	ui.select(Mock.creature(2), true, Vector2(500, 380))
	ui._unhandled_input(_key_event(KEY_ESCAPE))
	ok(not ui.ring.visible and not ui.selected.is_empty() and not ui.paused, "Esc closes the ring and keeps the selection")
	ui._unhandled_input(_key_event(KEY_ESCAPE))
	ok(ui.selected.is_empty() and not ui.paused, "a second Esc deselects")
	ui._unhandled_input(_key_event(KEY_ESCAPE))
	ok(ui.paused, "a third Esc opens the menu")
	ui.set_paused(false)
	ui.select(Mock.creature(1))
	ui.clear_selection()
	ok(not ui.note.visible or ui.note.info.is_empty(), "clear selection hides the field note")
	# a fight starts: select(info, false) with fight goes straight to attack
	var fi := Mock.creature(3)
	fi["fight"] = true
	ui.select(fi, false)
	ok(ui.mode == Modes.ATTACK and not ui.ring.visible, "a fight selects the attacker in attack mode with no ring")
	ui.queue_free()

func _mouse(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.position = pos
	m.pressed = pressed
	return m

func test_signs_and_words() -> void:
	var g = root.get_node("Game")
	g.settings["numbers"] = false
	g.settings["reduced_motion"] = false
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	var s = ui.signs
	ui.set_player("X", 100, 100, 50, 50)
	s._process(3.0)
	ui.set_player("X", 80, 100, 50, 50)
	ok(s.sign_alpha("health") > 0.99 and absf(s.hp_frac - 0.8) < 0.001, "a change brightens the health line (hp_frac %.2f)" % s.hp_frac)
	for k in 8:
		s._process(0.5)
	ok(is_equal_approx(s.sign_alpha("health"), Style.REST_ALPHA), "the resting opacity returns after REST (%.3f)" % s.sign_alpha("health"))
	ok(not s.stamina_visible, "the stamina line is hidden at full")
	ui.set_player("X", 80, 100, 20, 50)
	s._process(0.1)
	ok(s.stamina_visible, "the stamina line shows below full")
	ui.set_player("X", 80, 100, 50, 50)
	for k in 6:
		s._process(0.5)
	ok(not s.stamina_visible, "and hides 2 s after it is full again")
	ui.set_fight(true)
	s.set_fight(true)
	s._process(0.1)
	ok(s.stamina_visible, "a fight shows the stamina line")
	s.set_fight(false)
	ok(not s.low_health and ui.veil.low_health == 0.0, "no low health at 80 %")
	ui.set_player("X", 20, 100, 50, 50)
	ok(s.low_health and ui.veil.low_health > 0.0, "below 30 % sets low_health and the ember vignette")
	ok(ui.veil.edge_now() > 0.0, "the ember vignette is on")
	ui.set_player("X", 100, 100, 50, 50)
	# DNA: the spendable balance, species rings, a mote
	ui.set_meters(9, 4, 1, 4, 70, 100)
	ok(s.dna_text() == "4" and s.dna_total == 9, "the DNA sign shows the spendable balance, the total is the journal's (%s)" % s.dna_text())
	ok(s.pips_total == 4 and s.pips_filled == 1, "one ring per species present, filled when resolved")
	ui.set_meters(12, 7, 1, 4, 70, 100)
	ui.show_dna(3, "carcass", Vector3(0, 1, 0))
	ok(ui.motes.active() == 1 and s.dna_text() == "4" and ui.last_dna_source == "carcass", "a DNA gain creates one mote and the number waits for it (%s)" % s.dna_text())
	ui.motes._process(0.9)
	ok(ui.motes.active() == 0 and s.dna_text() == "7", "the number changes when the mote lands (%s)" % s.dna_text())
	g.settings["reduced_motion"] = true
	ui.set_meters(15, 10, 1, 4, 70, 100)
	ui.show_dna(3, "kill")
	ok(ui.motes.active() == 0 and s.dna_text() == "10", "with Less motion the number changes at once")
	g.settings["reduced_motion"] = false
	# the seed
	var pauses := []
	ui.pause_toggled.connect(func(p): pauses.append(p))
	s.size = Vector2(1280, 720)
	var down := _mouse(s.seed_center(), true)
	ok(s.handle_input(down), "a click on the seed is consumed")
	ok(pauses == [true] and ui.paused, "the seed opens the menu (pause_toggled(true))")
	ui.set_paused(false)
	# words: one whisper at a time, a moment line queues, numbers only with Numbers: On
	ui.show_message("A")
	ui.show_message("B")
	ok(ui.words.whisper_text == "B", "one whisper at a time: the newer replaces the older")
	ui.show_moment("First", "bone")
	ui.show_moment("Second")
	ok(ui.words.moment_text == "First" and ui.words._m_queue.size() == 1, "a moment line queues")
	ui.show_float(Vector3(0, 1, 0), "+9", Palette.LICHEN)
	ui.show_damage(Vector2(300, 200), 17)
	ok(ui.words._floats.is_empty(), "no numbers on screen with Numbers: Off")
	g.settings["numbers"] = true
	ui.show_damage(Vector2(300, 200), 17)
	ok(ui.words._floats.size() == 1, "damage numbers appear with Numbers: On")
	g.settings["numbers"] = false
	ui.flash("hit")
	ok(ui.veil.hit > 0.9, "a hit flashes the edge veil")
	ui.queue_free()

func test_minimap() -> void:
	var Mm := load("res://ui/minimap.gd")
	var mm = Mm.new()
	mm.player = Vector2(10, 20)
	mm.size = Vector2(1280, 720)
	var p: Vector2 = mm.world_to_map(Vector2(10 + Mm.WORLD_RADIUS, 20))
	ok(is_equal_approx(p.x, Style.u(Mm.RADIUS_U)) and is_zero_approx(p.y), "the map is centred on the player, its edge is WORLD_RADIUS away")
	var c: Vector2 = mm.map_centre()
	ok(c.x > 1100 and c.y < 100, "the round map sits top-right (%s)" % c)
	mm.free()

func test_menu_and_onboarding() -> void:
	var g = root.get_node("Game")
	var am := AudioManager.new("user://test_menu_%d.cfg" % Time.get_ticks_usec())
	root.add_child(am)
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	ui.bind_audio(am)
	var m = ui.menu
	m.size = Vector2(1280, 720)
	ui.set_paused(true)
	ok(m.open and m.column == 0 and m.focused_id() == "resume", "the menu opens on Resume")
	# keyboard reaches every item
	var seen := {}
	for i in 9:
		seen[m.focused_id()] = true
		m.handle_input(_key_event(KEY_DOWN))
	ok(seen.size() == m.item_ids().size(), "Down reaches every item (%d)" % seen.size())
	ok(m.focused_id() == "resume", "and wraps")
	m.handle_input(_key_event(KEY_UP))
	ok(m.focused_id() == "main_menu", "Up wraps to the last item")
	# the settings column: rows reachable, a choice changes a visible string at once
	m.focus = m.item_ids().find("settings")
	m.handle_input(_key_event(KEY_ENTER))
	ok(m.column == 1, "Enter on Settings opens the second column")
	var reached := {}
	for i in m.rows.size():
		reached[m.rows[m.row_focus].key] = true
		m.handle_input(_key_event(KEY_S))
	ok(reached.size() == m.rows.size(), "keyboard reaches every setting row (%d)" % reached.size())
	g.settings["language"] = "en"
	var en: String = Strings.t("resume")
	m.row_focus = 0
	m.handle_input(_key_event(KEY_RIGHT))
	ok(g.settings["language"] == "es" and Strings.t("resume") != en and Strings.t("resume") == "Seguir", "changing Language switches a visible string at once")
	m.handle_input(_key_event(KEY_LEFT))
	ok(g.settings["language"] == "en", "and back")
	# the size of the signs changes Style.u
	var old = g.settings.get("ui_scale", 1.0)
	m.set_value("ui_scale", 1.5)
	ok(is_equal_approx(Style.u(10.0), 15.0), "ui_scale changes Style.u(10)")
	m.set_value("ui_scale", old)
	# audio sliders write through the audio manager by bus key
	m.set_value("sfx", 0.35)
	ok(is_equal_approx(am.get_volume("sfx"), 0.35) and is_equal_approx(float(m.value_of("sfx")), 0.35), "the sound sliders write through AudioManager")
	m.set_value("mute", true)
	ok(AudioServer.is_bus_mute(0), "Mute writes through")
	m.set_value("mute", false)
	# Numbers, outlines and less motion are plain settings
	m.set_choice("numbers", 1)
	ok(g.settings["numbers"] == true and Style.numbers(), "Numbers: On is a setting")
	m.set_choice("numbers", 0)
	# "Show the hints again" clears the onboarding progress
	ui.onboarding.done_mask = 0b101
	m.row_focus = m.rows.size() - 1
	m.handle_input(_key_event(KEY_ENTER))
	ok(ui.onboarding.done_mask == 0, "Show the hints again resets the onboarding")
	# Esc goes back one level, then resumes
	m.handle_input(_key_event(KEY_ESCAPE))
	ok(m.column == 0 and ui.paused, "Esc goes back to the list")
	m.handle_input(_key_event(KEY_ESCAPE))
	ok(not ui.paused and not m.open, "Esc on the list resumes")
	# save and load availability, loadout away from the nest
	ok(not m.item_enabled("loadout") and m.item_enabled("save"), "Loadout is disabled away from the nest")
	ui.set_loadout_available(true)
	ok(m.item_enabled("loadout"), "and enabled at the nest")
	var reqs := []
	ui.journal_requested.connect(func(): reqs.append("journal"))
	ui.family_tree_requested.connect(func(): reqs.append("tree"))
	ui._unhandled_input(_key_event(KEY_J))
	ok(reqs == ["journal"] and ui.stub.open, "J opens the journal view")
	ui.stub.handle_input(_key_event(KEY_ESCAPE))
	ok(not ui.stub.open, "Esc closes it")
	ui._unhandled_input(_key_event(KEY_T))
	ok(reqs == ["journal", "tree"] and ui.stub.open and ui.stub.kind == "tree", "T opens the family tree view")
	ui.close_view()
	# onboarding
	var ob = Onboarding.new(null)
	ok(ob.pick() == 0, "the first hint is walking")
	ok(ob.update(0.1, {"fight": false}).get("text", "") == Strings.t("hint_walk"), "hint 1 shows at start")
	ob.notify("walk")
	ok(ob.pick() == 0, "one walk is not enough")
	ob.notify("walk")
	ok(ob.pick() == 1, "it advances after the action is done twice")
	ob.notify("look")
	ob.notify("look")
	ok(ob.pick() == 2, "then selecting")
	ob.notify("select")
	ob.notify("select")
	ok(ob.pick() == 8, "ring and keys wait for their situation (next is the F1 hint)")
	ok(ob.update(0.1, {"ring": true, "fight": false}).get("text", "") == Strings.t("hint_ring"), "with the ring open the hint is about the ring")
	ok(ob.update(0.1, {"ring": true, "fight": true}).get("keys", "") == "Space" or ob.pick() != 3, "never a hint in a fight except the fight one")
	var ob2 = Onboarding.new(null)
	ob2.update(0.1, {"fight": true})
	ok(ob2.pick() == 5, "in a fight only the guard hint can show")
	ob2.update(30.0, {"fight": false})
	ok(ob2.is_done(0) and ob2.pick() == 1, "a hint expires after 25 s")
	ob2.done_mask = (1 << Onboarding.STEPS.size()) - 1
	ok(ob2.complete() and ob2.update(1.0, {}).is_empty(), "silent when everything is learned")
	ui.queue_free()
	am.queue_free()

func _key_event(code: Key) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = code
	key.physical_keycode = code
	key.pressed = true
	return key

# A21: keys 1-4 fire the loadout slots (not fixed moves); role shapes, cooldown rings, the loadout sheet.
func test_loadout_ui() -> void:
	var ui := GameUI.new()
	root.add_child(ui)
	await process_frame
	var kit := [
		{"id": "tail_strike", "name": "Tail", "move": 4, "role": "control", "stamina": 10, "cooldown": 50},
		{"id": "bite", "name": "Bite", "move": 0, "role": "basic", "stamina": 9, "cooldown": 0},
		{"id": "", "name": "-", "empty": true, "enabled": false, "move": -1},
		{"id": "spit", "name": "Spit", "move": 3, "role": "poke", "stamina": 12, "cooldown": 0},
	]
	ui.set_mode(Modes.ATTACK)
	ui.set_loadout_abilities(kit)
	ok(ids(ui.abilities) == ["tail_strike", "bite", "", "spit"], "Attack mode shows the loadout slots in order (%s)" % [ids(ui.abilities)])
	var fired := []
	ui.ability_pressed.connect(func(i, a): fired.append([i, a["id"], a["move"]]))
	for code in [KEY_1, KEY_2, KEY_3, KEY_4]:
		ui._unhandled_input(_key_event(code))
	ok(fired == [[0, "tail_strike", 4], [1, "bite", 0], [3, "spit", 3]], "keys 1-4 fire slots 1-4 and an empty slot fires nothing (%s)" % [fired])
	await create_timer(0.3).timeout      # the pressed highlight of the key presses above ends
	ok(ui.petals.glyph_at(0) == "tail" and ui.petals.id_at(0) == "tail_strike" and ui.petals.glyph_at(2) == "" and ui.petals.state_at(2) == &"empty", "the petal shows the glyph of its move; an empty slot is a dashed circle with no glyph")
	var shapes := {}
	for role in ["basic", "engage", "poke", "control", "defence", "signature"]:
		shapes[Palette.ROLE_SHAPES[role]] = true
	ok(shapes.size() == 6, "the six roles have six different outline shapes")
	ok(ui.petals.shape_at(0) == &"square" and ui.petals.shape_at(1) == &"circle" and ui.petals.shape_at(3) == &"diamond", "petal outlines carry the role: control square, basic circle, poke diamond")
	ui.set_cooldowns([0.5, 0.0, 0.0, 0.0])
	ok(ui.petals.state_at(0) == &"cooling" and is_equal_approx(ui.petals.cooldown_at(0), 0.5) and ui.petals.state_at(1) == &"ready", "a cooling petal shows the part still to wait")
	ui.set_cooldowns([0.0, 0.0, 0.0, 0.0])
	ok(ui.petals.state_at(0) == &"ready", "and is ready when the move is")
	ui.set_mode(Modes.BEFRIEND)
	ok(ids(ui.abilities) == ["sing", "dance", "charm", "pose"], "other modes keep their own abilities")
	ui.set_mode(Modes.ATTACK)
	ok(ids(ui.abilities) == ["tail_strike", "bite", "", "spit"], "back to Attack restores the loadout petals")
	# a click on a petal presses its move
	ui.petals.centre = Vector2(640, 360)
	ui.petals.body_half_height = 70.0
	fired.clear()
	var p0: Vector2 = ui.petals.petal_pos(1)
	ok(ui.petals.handle_input(_mouse(p0, true)), "a click on a petal is consumed")
	ui.petals.handle_input(_mouse(p0, false))
	ok(fired == [[1, "bite", 0]], "a click on a petal presses the move (%s)" % [fired])
	ok(not ui.petals.handle_input(_mouse(Vector2(10, 10), true)), "a click elsewhere is not consumed")
	# the gift petal: item glyph and count, only in Befriend
	ui.set_gift(1, 2)
	ok(not ui.petals.gift_visible(), "no gift petal outside Befriend")
	ui.set_mode(Modes.BEFRIEND)
	ok(ui.petals.gift_visible() and ui.petals.gift_item == 1 and ui.petals.gift_count == 2, "Befriend shows the gift petal with the item and the count")
	var gifts := []
	ui.gift_pressed.connect(func(): gifts.append(true))
	ui.petals.handle_input(_mouse(ui.petals.gift_pos(), true))
	ok(gifts.size() == 1, "a click on the gift petal gives the gift")
	ui.set_gift(3, 1)
	ok(Glyphs.for_item(ui.petals.gift_item) == "bone", "H changes the glyph of the gift petal")
	# guard and dodge marks: a click presses them
	var gd := []
	ui.guard_pressed.connect(func(): gd.append("guard"))
	ui.dodge_pressed.connect(func(d): gd.append(d))
	ui.set_mode(Modes.ATTACK)
	ui.defence.centre = Vector2(640, 500)
	ui.defence.ring_radius = 56.0
	ui.defence.handle_input(_mouse(ui.defence.mark_pos("guard"), true))
	ui.defence.handle_input(_mouse(ui.defence.mark_pos("dodgeL"), true))
	ui.defence.handle_input(_mouse(ui.defence.mark_pos("dodgeR"), true))
	ok(gd == ["guard", -1, 1], "the marks at your feet emit guard and dodge (%s)" % [gd])
	ui.set_mode(Modes.NONE)
	ok(not ui.defence.shown, "the marks hide when no mode and no fight")
	ui.set_fight(true)
	ok(ui.defence.shown, "a fight shows the marks whatever the mode")
	ui.set_fight(false)
	# the sheet
	var panel = ui.loadout_panel
	var moves: Array = CporeWorld.moves()
	panel.setup(moves)
	var asked := []
	ui.loadout_assign.connect(func(slot, move): asked.append([slot, move]))
	var lo := {"slots": [4, 0, -1, 3], "known": 0b10011, "can_edit": true, "signature_slot": -1, "nest_radius": 12.0}
	panel.refresh(lo)
	ok(not panel.visible_open, "the sheet starts closed")
	var req := []
	ui.loadout_requested.connect(func(): req.append(true))
	ui._unhandled_input(_key_event(KEY_L))
	ok(req.size() == 1, "key L asks for the loadout sheet")
	panel.open_panel()
	ok(ui.veil.flat_amount > 0.3 and ui.veil.flat_amount < 0.5, "a light veil (0.42) comes with the sheet")
	ok(panel.token_count() == 4, "one token per slottable move, not guard or dodge (%d)" % panel.token_count())
	var names := []
	for i in panel.token_count():
		names.append(panel.token_id(i))
	ok(names == ["bite", "charge", "spit", "tail_strike"], "tokens are the four attack moves (%s)" % [names])
	ok(panel.token_glyph(0) == "bite" and panel.token_glyph(1) == "charge" and panel.token_glyph(2) == "", "a known move is a token with a glyph; one not learned has none (no spoiler)")
	ok(panel.token_enabled(0) and not panel.token_enabled(2), "a move not known cannot be chosen")
	var shapes2 := {}
	for role in ["basic", "engage", "poke", "control", "defence", "signature"]:
		shapes2[Palette.ROLE_SHAPES[role]] = true
	ok(shapes2.size() == 6 and panel.token_shape(0) == &"circle" and panel.token_shape(1) == &"triangle", "the role is the outline shape: basic circle, engage triangle")
	panel.choose(2, 1)
	ok(asked == [[2, 1]], "choosing a move asks for loadout SLOT MOVE (slot 0-based, move id) (%s)" % [asked])
	panel.choose(0, -1)
	ok(asked.back() == [0, -1], "choosing empty asks for -1")
	panel.choose(1, 4)
	ok(asked.back() == [1, 4], "a move the body cannot do still goes to C, which refuses it")
	asked.clear()
	panel.refresh(lo)
	ok(asked.is_empty(), "refreshing the sheet from the world sends nothing")
	# keys: Left/Right focus a token, 1-4 put it in that slot, Backspace empties
	panel.focus = 0
	panel.handle_input(_key_event(KEY_RIGHT))
	panel.handle_input(_key_event(KEY_3))
	ok(panel.focus == 1 and asked == [[2, 1]], "Right focuses the next token and key 3 puts it in slot 3 (%s)" % [asked])
	panel.focus = 2
	panel.handle_input(_key_event(KEY_1))
	ok(asked.size() == 1, "a token that is not learned ignores the slot keys")
	# mouse: click a token then a slot
	asked.clear()
	panel.size = Vector2(1280, 720)
	panel.handle_input(_mouse(panel.token_pos(0), true))
	panel.handle_input(_mouse(panel.slot_pos(3), true))
	ok(asked == [[3, 0]] and panel.picked == -1, "click a token then a slot assigns it (%s)" % [asked])
	lo["can_edit"] = false
	panel.refresh(lo)
	ok(not panel.token_enabled(0), "away from the nest the sheet is read-only")
	panel.handle_input(_key_event(KEY_ESCAPE))
	ok(not panel.visible_open and is_equal_approx(ui.veil.flat_amount, 0.0), "Esc closes the sheet and the veil")
	ui.queue_free()

func test_audio_manager() -> void:
	var path := "user://test_audio_%d.cfg" % Time.get_ticks_usec()
	var am := AudioManager.new(path)
	root.add_child(am)
	await process_frame
	for b in ["Master", "Music", "SFX", "Ambience"]:
		ok(AudioServer.get_bus_index(b) >= 0, "bus %s exists" % b)
	ok(am.errors.is_empty(), "all sounds loaded in manager")
	am.set_volume("sfx", 0.3)
	ok(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.3), "sfx bus volume applied")
	am.set_mute(true)
	ok(AudioServer.is_bus_mute(0), "mute applied")
	am.set_mute(false)
	am.footstep(Vector3.ZERO, 3.0, 60)
	am.cry("aggro", Vector3(1, 0, 1), 200)
	am.combat_event(1, Vector3.ZERO)
	am.combat_event(4, Vector3.ZERO)
	am.spit(Vector3.ZERO)
	am.ui_click()
	ok(am.played.get("step-0", 0) == 1 and am.played.get("aggro", 0) == 1 and am.played.get("hit", 0) == 1, "positional sounds played")
	ok(am.played.get("dodge", 0) == 1 and am.played.get("spit", 0) == 1 and am.played.get("click", 0) == 1, "dodge/spit/click played")
	ok(AudioManager.size_rate(200) < AudioManager.size_rate(30), "big creatures pitch lower")
	ok(AudioManager.wind_gain(60) > AudioManager.wind_gain(2), "wind louder on high ground")
	ok(AudioManager.rustle_gain(10, 0.2, 5) > 0.0 and AudioManager.rustle_gain(60, 0.2, 5) == 0.0, "rustle only on grass")
	am.footstep(Vector3.ZERO, 0.0)
	ok(am.played.get("step-1", 0) == 0, "standing still makes no footstep")
	var am2 := AudioManager.new(path)
	ok(is_equal_approx(am2.get_volume("sfx"), 0.3), "volume persisted across managers")
	am2.free()
	am.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# S0: fonts, glyphs, strings, sizes.
func test_foundations() -> void:
	for n in Glyphs.NAMES:
		ok(Glyphs.has(n), "glyph %s loads" % n)
	ok(Glyphs.NAMES.size() == 33, "33 glyphs")
	for id in ["bite", "charge", "spit", "tail_strike", "sing", "dance", "charm", "pose", "roar", "display", "observe", "eat", "guard", "dodge"]:
		ok(Glyphs.has(Glyphs.for_move(id)), "move %s has a glyph" % id)
	for i in 4:
		ok(Glyphs.has(Glyphs.for_item(i)), "item %d has a glyph" % i)
	for m in Modes.ALL + [Modes.EAT]:
		ok(Glyphs.has(Glyphs.for_mode(m)), "mode %s has a glyph" % m)
	ok(Glyphs.for_move("no_such_move") == "attack", "an unknown move falls back to attack")
	for k in Strings.TABLE:
		var row: Array = Strings.TABLE[k]
		ok(row.size() == 2 and str(row[0]) != "" and str(row[1]) != "", "string %s has both languages" % k)
		ok(str(row[1]).length() <= int(1.6 * str(row[0]).length()) + 4, "string %s: es is not much longer than en (%s)" % [k, row[1]])
	var g = root.get_node("Game")
	var old_lang = g.settings.get("language", "")
	g.settings["language"] = "es"
	ok(Strings.t("befriend") == "Amistad" and Strings.t("learned", ["Salto"]) == "Aprendido: Salto", "Spanish strings with arguments")
	g.settings["language"] = "en"
	ok(Strings.t("befriend") == "Befriend" and Strings.t("learned", ["Pounce"]) == "Learned: Pounce", "English strings with arguments")
	g.settings["language"] = old_lang
	var old_scale = g.settings.get("ui_scale", 1.0)
	g.settings["ui_scale"] = 1.0
	var u1 := Style.u(10.0)
	g.settings["ui_scale"] = 1.5
	ok(is_equal_approx(u1, 10.0) and is_equal_approx(Style.u(10.0), 15.0), "Style.u scales with ui_scale")
	g.settings["ui_scale"] = old_scale
	ok(Style.font_sans() != null and Style.font_sans(true) != null and Style.font_italic() != null, "fonts load")
	for f in ["OFL-AlegreyaSans.txt", "OFL-Alegreya.txt"]:
		ok(FileAccess.file_exists("res://ui/fonts/" + f), "licence %s sits next to the fonts" % f)
	ok(Modes.NONE == &"" and Modes.is_mode(Modes.NONE), "Modes.NONE exists")
