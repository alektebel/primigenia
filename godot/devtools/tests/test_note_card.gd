extends RefCounted
# N notes (DT-NOTE-N): the card, Ctrl+N, the metadata, the F11 overlay, the Shift+N browser. Isolated: never the owner's feedback dirs.

const StageWorld := preload("res://game/stage/stage_world.gd")
const Store := preload("res://devtools/notes/note_store.gd")
const Meta := preload("res://devtools/notes/note_meta.gd")
const Overlay := preload("res://devtools/notes/meta_overlay.gd")
const Browser := preload("res://devtools/notes/notes_browser.gd")
const Isolation := preload("res://devtools/test_isolation.gd")

const DIR := "user://devtools-test/n-notes"

static func key(code: Key, ctrl := false, shift := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.ctrl_pressed = ctrl
	e.shift_pressed = shift
	e.pressed = true
	return e

static func fake_image() -> Image:
	var img := Image.create(320, 180, false, Image.FORMAT_RGB8)
	img.fill(Color(0.3, 0.5, 0.7))
	return img

func _files(base: String) -> PackedStringArray:
	var d := DirAccess.open(base)
	return d.get_directories() if d != null else PackedStringArray()

func run(t) -> void:
	var base := ProjectSettings.globalize_path(DIR)
	_wipe(base)
	# --- isolation: the real notes dir is never used by a harness
	t.check(Isolation.active() and Store.notes_dir().contains("test-feedback"), "the notes dir is isolated in tests (%s)" % Store.notes_dir())
	# --- pure helpers
	var times := PackedFloat32Array()
	for i in 100:
		times.append(0.010 if i < 95 else 0.050)
	t.eq(Meta.p95_ms(times), 10.0, "p95 of 95 fast and 5 slow frames is the last fast one")
	t.eq(Meta.p95_ms(PackedFloat32Array()), 0.0, "p95 of nothing is 0")
	t.eq(Meta.heading_deg(0.0, 1.0), 0.0, "heading: +z is 0")
	t.eq(Meta.heading_deg(1.0, 0.0), 90.0, "heading: +x is 90")
	t.eq(Meta.heading_deg(0.0, -1.0), 180.0, "heading: -z is 180")
	t.eq(Meta.mode_of("res://game/island/island.tscn", false, false, false), "island", "mode: island")
	t.eq(Meta.mode_of("res://game/island/island.tscn", false, false, true), "nest", "mode: nest")
	t.eq(Meta.mode_of("res://game/island/island.tscn", true, true, true), "combat", "mode: combat wins")
	t.eq(Meta.mode_of("res://game/island/island.tscn", false, true, false), "flight", "mode: flight")
	t.eq(Meta.mode_of("res://studio/ui/studio.tscn", false, false, false), "studio", "mode: studio")
	t.eq(Meta.mode_of("res://cell/cell_stage.tscn", false, false, false), "cell", "mode: cell")
	var ents: Array = [{"id": 0, "x": 0.0, "z": 0.0, "species": -1}]
	for i in 12:
		ents.append({"id": i + 1, "x": float(i + 1) * 3.0, "z": 0.0, "species": 3, "hp": 80.0, "hp_max": 80.0, "temperament": 2, "speed": 0.0})
	ents[1].dead = true
	ents[2].hostile = true
	var nb := Meta.nearby(ents, {3: "Garfio"}, 0.0, 0.0)
	t.check(nb.size() == 8 and nb[0].id == 1 and nb[0].dist == 3.0 and nb[7].id == 8, "nearby: at most 8, nearest first, the player excluded")
	t.check(nb[0].state == "dead" and nb[1].state == "hostile" and nb[2].state == "idle" and nb[0].species == "Garfio" and nb[2].temperament == "aggressive", "nearby: state, species, temperament")
	t.eq(Meta.nearby(ents, {}, 0.0, 0.0, 8, 10.0).size(), 3, "nearby honours the range")
	t.eq(Overlay.hover_line({}, ents, {}, 0.0, 0.0), "", "hover: nothing under the cursor, no line")
	t.check(Overlay.hover_line({"kind": "creature", "id": 3, "name": "Garfio #3"}, ents, {3: "Garfio"}, 0.0, 0.0).contains("Garfio #3  9.0 m  idle  aggressive  hp 80/80"), "hover line of a creature")
	t.eq(Overlay.hover_line({"kind": "plant", "name": "fern"}, ents, {}, 0.0, 0.0), "plant fern", "hover line of a plant")
	# --- no stage (the cell, the studio, the menu): the meta still collects, without the sim sections
	Game.stage = null
	var m0 := Meta.collect(t)
	t.check(m0.has("mode") and m0.has("perf") and m0.has("render") and m0.has("window") and not m0.has("player") and not m0.has("tick"), "meta without a stage keeps mode, perf, render and window")
	t.check(not Meta.lines(m0).is_empty(), "and still has lines")
	# --- a world and a stand-in scene
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	sw.reset(setup)
	for i in 5:
		sw.step_once()
	Game.stage = sw
	var scene := Node.new()
	scene.set_script(load("res://devtools/tests/fake_scene.gd"))
	t.root.add_child(scene)
	var prev_scene = t.current_scene
	t.current_scene = scene
	var card = Dev.note_card
	var flag = Dev.flag
	var browser = Dev.browser
	var overlay = Dev.meta_overlay
	card.base_dir = base
	flag.base_dir = base
	browser.base_dir = base
	card.image_provider = Callable(self, "fake_image")
	t.check(card != null and browser != null and overlay != null, "the dev tools create the card, browser and overlay")
	# --- N opens the card, pauses, grabs
	t.check(not Game.options_open and not sw.paused, "free before N")
	t.check(card.handle_key(key(KEY_N)), "N opens the card")
	t.check(card.is_open and Game.options_open and sw.paused, "the card pauses the sim and suspends the game keys")
	t.check(card.shot != null and card.shot.get_width() == 320, "the frame was grabbed when N was pressed")
	t.check(not card.handle_key(key(KEY_N)) or card.is_open, "N again does not stack a second card")
	# --- Esc cancels without a file
	t.check(card.handle_key(key(KEY_ESCAPE)), "Esc is used by the card")
	t.check(not card.is_open and not sw.paused and not Game.options_open, "Esc closes, unpauses and frees the keys")
	t.eq(_files(base).size(), 0, "Esc cancels without writing a note")
	# --- a saved note with text and tags
	card.handle_key(key(KEY_N))
	card.handle_key(key(KEY_2, true))
	card.handle_key(key(KEY_4, true))
	card.handle_key(key(KEY_4, true))
	t.eq(card.tags, ["movement"], "Ctrl+2 toggles movement, Ctrl+4 twice toggles ui off again")
	t.eq(card.commit("legs cross when I turn"), "", "Enter saves")
	t.check(not card.is_open and not sw.paused, "saving closes the card and unpauses")
	var dirs := _files(base)
	t.eq(dirs.size(), 1, "one note folder")
	var nd := base.path_join(dirs[0])
	for f in ["note.json", "screenshot.jpg", "crop.jpg", "scenario.json", "scenario.cpstate"]:
		t.check(FileAccess.file_exists(nd.path_join(f)), "the note folder has %s" % f)
	var n: Dictionary = Store.list(base)[0]
	t.check(n.format == "primigenia.note/1" and n.text == "legs cross when I turn" and n.tags == ["movement"] and n.origin == "n", "note.json: format /1, text, tags, origin")
	t.eq(n.target.kind, "state", "a state note by default (no entity)")
	var m: Dictionary = n.meta
	t.eq(m.schema, "primigenia.note.meta/1", "meta schema")
	for k in ["time", "build", "mode", "tick", "seed", "player", "creature", "nearby", "camera", "options", "perf", "render", "window", "scenario"]:
		t.check(m.has(k), "meta has %s" % k)
	t.check(m.build.has("commit") and m.build.has("dirty"), "meta.build: commit and dirty flag")
	for k in ["pos", "heading_deg", "speed", "gait", "style", "hp", "hp_max", "stamina", "stamina_max"]:
		t.check(m.player.has(k), "meta.player has %s" % k)
	t.check(m.perf.has("fps") and m.perf.has("frame_ms_p95") and m.render.has("gpu") and m.render.has("renderer") and m.window.size() == 2, "fps, p95, renderer, gpu, window size")
	t.check(m.creature.has("dna") and m.creature.has("parts") and m.creature.has("name"), "creature: name, parts, DNA")
	t.check(m.nearby.size() > 0 and m.nearby[0].has("species") and m.nearby[0].has("dist") and m.nearby[0].has("state") and m.nearby[0].has("hp"), "nearby entities with species, distance, state, hp")
	t.check(m.nearby.size() <= 8 and m.tick == 5 and m.scenario == "scenario.json", "nearby <= 8, the sim tick, the scenario reference")
	t.check(m.camera.has("yaw"), "camera state is in the meta")
	t.check(not Meta.lines(m).is_empty() and "\n".join(Meta.lines(m)).contains("tick 5  ") and not "\n".join(Meta.lines(m)).contains("tick 5.0"), "meta lines read well (whole numbers stay whole after the JSON round trip)")
	# --- Ctrl+N: no card, no pause, no text
	t.check(card.handle_key(key(KEY_N, true)), "Ctrl+N is used")
	t.check(not card.is_open and not sw.paused, "Ctrl+N opens no card and does not pause")
	t.eq(_files(base).size(), 2, "Ctrl+N writes a note at once")
	var quick: Dictionary = Store.find(base, card.last_saved)
	t.check(quick.text == "" and quick.origin == "quick" and quick.has("meta") and FileAccess.file_exists(base.path_join(Store.folder_name(quick)).path_join("screenshot.jpg")), "the quick note has meta and a screenshot but no text")
	t.check(Store.line(quick).contains("(no text)"), "a quick note lists as (no text)")
	# --- a pinned note, and the pin mode
	card.handle_key(key(KEY_N))
	card.handle_key(key(KEY_P, true))
	t.check(card.pinning, "Ctrl+P starts the pin pick")
	card.handle_key(key(KEY_ESCAPE))
	t.check(not card.pinning and card.is_open, "Esc leaves the pick but keeps the card")
	card.target = {"kind": "creature", "id": 3, "species": "Garfio", "part": "", "name": "Garfio #3", "pos": Vector3(1, 0, 2)}
	t.eq(card.commit("this one"), "", "save a pinned note")
	t.eq(Store.find(base, card.last_saved).target.name, "Garfio #3", "the pinned entity is the target")
	# --- not triggered while typing, with the console, with a question card, with the F10 HUD
	var le := LineEdit.new()
	t.root.add_child(le)
	le.grab_focus()
	t.check(card.typing_in_field(), "a focused LineEdit counts as typing")
	t.check(not card.handle_key(key(KEY_N)) and not card.is_open, "N while typing does nothing")
	t.check(not card.handle_key(key(KEY_N, true)) and _files(base).size() == 3, "Ctrl+N while typing does nothing")
	t.check(not browser.handle_key(key(KEY_N, false, true)) or not browser.is_open, "Shift+N while typing does not open the browser")
	le.release_focus()
	le.queue_free()
	Game.console_open = true
	t.check(not card.handle_key(key(KEY_N)), "N with the console open does nothing")
	Game.console_open = false
	var qc = Dev.questions
	qc.current = {"id": "x", "text": "q", "options": [], "context": "", "where": {}, "allow_free_text": false}
	t.check(not card.handle_key(key(KEY_N)) and not card.is_open, "N with a question card showing is the card's (its attach-a-note key)")
	qc.current = {}
	Dev.options_hud.open()
	t.check(not card.handle_key(key(KEY_N)), "N with the F10 HUD open does nothing")
	Dev.options_hud.close()
	# --- stays paused if the sim already was
	sw.paused = true
	card.handle_key(key(KEY_N))
	card.cancel()
	t.check(sw.paused, "a sim that was paused stays paused after the card")
	sw.paused = false
	# --- the overlay
	t.check(not overlay.is_on, "the overlay starts off")
	var f11 := key(KEY_F11)
	t.check(f11.is_action_pressed("dev_meta"), "F11 is the dev_meta action")
	overlay._input(f11)
	t.check(overlay.is_on and overlay.last_meta.has("mode") and overlay.last_meta.has("perf"), "F11 turns the overlay on with live meta")
	overlay._input(key(KEY_F11))
	t.check(not overlay.is_on, "F11 again turns it off")
	overlay.set_on(true)
	overlay.hover_provider = func(_m): return {"kind": "creature", "id": 1, "name": "Garfio #1"}
	overlay._ht = 1.0
	overlay._process(0.0)
	t.check(overlay.hover_text.begins_with("creature"), "the overlay shows the entity under the cursor (%s)" % overlay.hover_text)
	overlay.set_on(false)
	# --- the console
	t.check(Dev.console.registry.execute("meta now").out.contains("tick 5"), "console: meta now")
	# --- the browser
	t.check(browser.handle_key(key(KEY_N, false, true)), "Shift+N opens the notes browser")
	t.check(browser.is_open and sw.paused and Game.options_open, "the browser pauses the sim")
	t.eq(browser.rows.size(), 3, "it lists every open note")
	t.eq(browser.rows[0].text, "this one", "newest first (the notes were saved within one second: the millisecond clock orders them)")
	var oi := 0
	for i in browser.rows.size():
		if browser.rows[i].text == "legs cross when I turn":
			oi = i
	browser.select(oi)
	var oldest: Dictionary = browser.current()
	t.eq(oldest.text, "legs cross when I turn", "select picks a note")
	var seen := []
	browser.scenario_loader = func(parsed): seen.append(parsed.dict.get("name", "")); return ""
	t.eq(browser.load_moment(), "", "load this moment")
	t.check(browser.loaded_scenario.ends_with("scenario.json") and seen.size() == 1, "it asked the island to load that note's scenario")
	browser.select(oi)
	t.check(Browser.row_text(oldest).contains("[movement]"), "a row shows text, tags and time")
	t.eq(browser.mark_done(), "", "mark done from the browser")
	t.eq(Store.list(base, true).size(), 2, "a done note leaves the open list")
	t.check(browser.handle_key(key(KEY_ESCAPE)) and not browser.is_open and not sw.paused and not Game.options_open, "Esc closes the browser and unpauses")
	# --- notes.py shows the meta
	var script := ProjectSettings.globalize_path("res://../tools/feedback/notes.py").simplify_path()
	var out: Dictionary = t.exec("python3", ["-I", script, "--dir", base, "show", oldest.id])
	t.check(out.rc == 0 and out.out.contains("legs cross when I turn") and out.out.contains("tick 5") and out.out.contains("nearby"), "notes.py show prints the meta: %s" % out.out.left(300))
	out = t.exec("python3", ["-I", script, "--dir", base, "show", oldest.id, "--json"])
	t.check(out.rc == 0 and out.out.contains("\"meta\""), "notes.py show --json prints the raw note")
	out = t.exec("python3", ["-I", script, "--dir", base, "list", "--all"])
	t.check(out.rc == 0 and out.out.contains("(no text)") and out.out.contains("Garfio #3"), "notes.py list handles quick and pinned notes: %s" % out.out.left(200))
	out = t.exec("python3", ["-I", script, "--dir", base, "export-md", "--all"])
	t.check(out.rc == 0 and out.out.contains("state"), "notes.py export-md handles state notes")
	# --- Shift+F8 flag mode still saves, now with meta
	t.eq(flag.save_note("flag still works", ["look"], 2, {"kind": "terrain", "id": -1, "name": "ground", "pos": Vector3(1, 0, 1)}, false), "", "flag mode saves")
	var fn: Dictionary = Store.find(base, flag.last_saved)
	t.check(fn.has("meta") and fn.origin == "flag" and fn.meta.mode != "", "a flag-mode note carries the meta too")
	t.check(InputMap.has_action("dev_flag") and InputMap.has_action("dev_note") and InputMap.has_action("dev_note_quick") and InputMap.has_action("dev_notes_browser"), "the actions exist")
	# --- cleanup
	t.current_scene = prev_scene
	scene.queue_free()
	Game.stage = null
	card.base_dir = ""
	flag.base_dir = ""
	browser.base_dir = ""
	card.image_provider = Callable()
	_wipe(base)

func _wipe(base: String) -> void:
	var d := DirAccess.open(base)
	if d == null:
		return
	for sub in d.get_directories():
		_wipe(base.path_join(sub))
		DirAccess.remove_absolute(base.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(base.path_join(f))
