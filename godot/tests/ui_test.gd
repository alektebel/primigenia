extends SceneTree
## Headless tests for godot/ui and godot/audio. Run: make godot-ui-test

const Modes := preload("res://ui/modes.gd")
const Card := preload("res://ui/creature_card.gd")
const Mock := preload("res://ui/mock_source.gd")
const GameUI := preload("res://ui/game_ui.gd")
const Radial := preload("res://ui/radial_menu.gd")
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
	test_modes()
	test_card()
	test_radial_geometry()
	test_volumes()
	test_sounds()
	call_deferred("_finish")

func _finish() -> void:
	await test_ui_flow()
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

func test_card() -> void:
	var card := Card.new()
	var seen := {}
	for info in Mock.all_combinations():
		card.set_info(info)
		var s := card.snapshot()
		ok(s.temperament == Card.TEMPERAMENTS[info.temperament], "temperament text %s" % s.temperament)
		ok(s.relationship == Card.RELATIONSHIPS[info.relationship], "relationship text %s" % s.relationship)
		ok(s.diet != "" and s.species != "" and s.resolved.contains("/"), "diet/species/resolved shown")
		ok(s.likes.begins_with("Likes:"), "likes hint shown")
		seen["%s/%s" % [s.temperament, s.relationship]] = true
	ok(seen.size() == 12, "card renders all 3x4 temperament/relationship pairs (%d)" % seen.size())
	card.set_info({"species": "X", "temperament": "aggressive", "diet": "omnivore", "relationship": "ally"})
	var s2 := card.snapshot()
	ok(s2.temperament == "Aggressive" and s2.diet == "Omnivore" and s2.relationship == "Ally", "string enums accepted")
	ok(s2.likes.contains("unknown"), "missing likes handled")
	card.free()

func test_radial_geometry() -> void:
	ok(Radial.sector_at(Vector2(0, -80)) == 0, "north = attack")
	ok(Radial.sector_at(Vector2(80, 0)) == 1, "east = befriend")
	ok(Radial.sector_at(Vector2(0, 80)) == 2, "south = observe")
	ok(Radial.sector_at(Vector2(-80, 0)) == 3, "west = intimidate")
	ok(Radial.sector_at(Vector2(5, 5)) == -1, "centre = none")

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
	ok(ids(ui.abilities) == ["bite", "charge", "spit", "tail_strike"], "default mode attack")
	ui.set_mode(Modes.BEFRIEND)
	ok(ui.mode == Modes.BEFRIEND and ids(ui.abilities) == ["sing", "dance", "charm", "pose"], "befriend sets abilities")
	ok(ui.hud.slots[0].text.contains("Sing") and ui.hud.slots[3].text.contains("Pose"), "move bar shows befriend")
	ui.set_mode(Modes.OBSERVE)
	ok(ui.hud.slots[0].visible and not ui.hud.slots[1].visible, "observe shows one slot")
	ui.set_mode(Modes.INTIMIDATE)
	ok(ids(ui.abilities) == ["roar", "display"], "intimidate abilities in ui")
	ok(modes == [Modes.BEFRIEND, Modes.OBSERVE, Modes.INTIMIDATE], "mode_changed emitted")
	ui.set_mode("bogus")
	ok(ui.mode == Modes.INTIMIDATE, "unknown mode ignored")
	ui.select(Mock.creature(1))
	ok(ui.card.visible and ui.radial.visible, "select shows card and radial")
	ok(ui.hud.target_panel.visible, "target marker visible")
	ui.radial.choose(0)
	ok(ui.mode == Modes.ATTACK and not ui.radial.visible, "radial chooses attack")
	var key := InputEventKey.new()
	key.keycode = KEY_2
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
	ok(ui.hud.toasts.get_child_count() == 1 and ui.hud.dna_box.get_child_count() == 1, "toasts shown")
	ok(ui.hud.windup_bar.visible, "wind-up tell visible")
	ui.set_paused(true)
	ok(ui.pause_menu.visible, "pause menu visible")
	ui.set_paused(false)
	ui.clear_selection()
	ok(not ui.card.visible and not ui.hud.target_panel.visible, "clear selection")
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
