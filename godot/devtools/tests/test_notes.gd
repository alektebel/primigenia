extends RefCounted
# In-game notes (flag mode): picking each kind of target, the note files and index, input suspension, pins on moving creatures,
# the console commands and tools/feedback/notes.py.

const Store := preload("res://devtools/notes/note_store.gd")
const Pick := preload("res://devtools/notes/note_pick.gd")
const Flag := preload("res://devtools/notes/flag_mode.gd")
const Cmds := preload("res://devtools/notes/note_commands.gd")
const CmdReg := preload("res://devtools/console/registry.gd")
const PlantGaze := preload("res://game/island/plant_gaze.gd")
const StageWorld := preload("res://game/stage/stage_world.gd")
const Hud := preload("res://devtools/tuning/options_hud.gd")
const Registry := preload("res://devtools/tuning/registry.gd")

const DIR := "user://devtools-test/notes"

static func flat(_x, _z) -> float:
	return 0.0

func _src() -> Dictionary:
	var ents := [
		{"id": 0, "x": 0.0, "z": 0.0, "dead": false, "radius_cm": 60, "species": 1},
		{"id": 1, "x": 10.0, "z": 0.0, "dead": false, "radius_cm": 80, "species": 3},
		{"id": 2, "x": -10.0, "z": 0.0, "dead": true, "meat": 5, "radius_cm": 80, "species": 3},
	]
	return {"entities": ents, "ground": Callable(self, "_flat"), "species_name": func(i): return "sp%d" % i,
		"props": [{"kind": "shard", "id": 7, "name": "meteor shard 7", "x": 0.0, "z": 20.0}],
		"nest": Vector2(0.0, -20.0),
		"records": [{"id": "fern", "p": Vector3(20, 0, 0), "height": 1.0}], "gaze": PlantGaze.new(),
		"water_depth": func(x, z): return 1.0 if x > 40.0 else 0.0}

func _flat(_x, _z) -> float:
	return 0.0

static func ray_to(from: Vector3, to: Vector3) -> Array:
	return [from, (to - from).normalized()]

func run(t) -> void:
	var src := _src()
	var eye := Vector3(0, 6, 40)    # looks at things on the ground from the south
	# --- picking
	var r = ray_to(Vector3(10, 4, 8), Vector3(10, 0.6, 0))
	var p := Pick.pick(r[0], r[1], src)
	t.check(p.kind == "creature" and p.id == 1 and p.species == "sp3" and p.name == "sp3 #1", "a creature: kind, id, species, name (%s)" % str(p))
	r = ray_to(Vector3(-10, 4, 8), Vector3(-10, 0.6, 0))
	p = Pick.pick(r[0], r[1], src)
	t.check(p.kind == "prop" and p.name == "remains of sp3", "a carcass is a prop: remains")
	r = ray_to(Vector3(0, 4, 28), Vector3(0, 0.4, 20))
	p = Pick.pick(r[0], r[1], src)
	t.check(p.kind == "prop" and p.part == "shard" and p.id == 7, "an artifact: the meteor shard")
	r = ray_to(Vector3(0, 4, -12), Vector3(0, 0.4, -20))
	p = Pick.pick(r[0], r[1], src)
	t.check(p.kind == "prop" and p.name == "nest", "the nest")
	r = ray_to(Vector3(20, 4, 12), Vector3(20, 0.5, 0))
	p = Pick.pick(r[0], r[1], src)
	t.check(p.kind == "plant" and p.id == "fern", "a plant by its flora id (%s)" % str(p))
	r = ray_to(Vector3(-30, 8, 30), Vector3(-30, 0, 5))
	p = Pick.pick(r[0], r[1], src)
	t.check(p.kind == "terrain" and p.pos.is_equal_approx(Vector3(-30, 0, 5)), "terrain at the ground hit")
	r = ray_to(Vector3(50, 8, 30), Vector3(50, 0, 5))
	p = Pick.pick(r[0], r[1], src)
	t.eq(p.kind, "water", "a wet ground point is water")
	t.eq(Pick.pick(Vector3(0, 6, 0), Vector3(0, 1, 0), src), {}, "the sky is nothing")
	# --- note files, index, round trip
	var base := ProjectSettings.globalize_path(DIR)
	_wipe(base)
	var tg := {"kind": "creature", "id": 1, "species": "garfio", "part": "", "name": "Garfio #1"}
	var n := Store.make("legs cross at the turn", ["motion", "nope"], 9, tg, Vector3(1.234, 0, 5), {"id": "aaa111", "stamp": "20261121-100000",
		"tick": 600, "hour": 12.0, "options": {"light": "dusk"}, "camera": {"yaw": 1.0}, "build": "b1"})
	t.check(n.format == "primigenia.note/1" and n.tags == ["motion"] and n.severity == 3 and n.status == "open", "make: format, tag filter, severity clamp, open")
	t.check(n.options == {"light": "dusk"} and n.tick == 600 and n.target.name == "Garfio #1" and n.pos == [1.23, 0.0, 5.0], "make keeps options, tick, target, position")
	var dir := Store.write(base, n)
	t.check(dir.ends_with("20261121-100000-aaa111") and FileAccess.file_exists(dir.path_join("note.json")), "note folder is <stamp>-<id>")
	var n2 := Store.make("grass floats", ["look"], 1, {"kind": "terrain", "name": "ground (3, 4)"}, Vector3.ZERO, {"id": "bbb222", "stamp": "20261121-110000"})
	Store.write(base, n2)
	var idx := FileAccess.get_file_as_string(base.path_join("index.jsonl")).strip_edges().split("\n")
	t.eq(idx.size(), 2, "one index line per note")
	var row = JSON.parse_string(idx[0])
	t.check(row.id == "aaa111" and row.status == "open" and row.kind == "creature" and row.text == "legs cross at the turn", "the index line summarises the note")
	var listed := Store.list(base, true)
	t.check(listed.size() == 2 and listed[0].id == "bbb222", "list is newest first")
	t.eq(Store.find(base, "aaa")["id"], "aaa111", "find by a prefix")
	t.eq(Store.mark_done(base, "aaa111", "abc1234"), "", "mark done")
	t.eq(Store.list(base, true).size(), 1, "done notes leave the open list")
	t.eq(Store.list(base)[1].fix, "abc1234", "and keep the fix commit")
	var idx2 := FileAccess.get_file_as_string(base.path_join("index.jsonl")).strip_edges().split("\n")
	t.check(idx2.size() == 2 and JSON.parse_string(idx2[0]).status == "done", "the index follows")
	t.check(Store.mark_done(base, "zzz", "") != "", "an unknown id is an error")
	# --- notes.py
	var py := "res://../tools/feedback/notes.py"
	var script := ProjectSettings.globalize_path(py).simplify_path()
	var out: Dictionary = t.exec("python3", ["-I", script, "--dir", base, "list"])
	t.check(out.rc == 0 and out.out.contains("#bbb222") and not out.out.contains("aaa111"), "notes.py list shows open notes only: %s" % out.out.strip_edges())
	out = t.exec("python3", ["-I", script, "--dir", base, "list", "--all"])
	t.check(out.out.contains("aaa111") and out.out.contains("abc1234"), "list --all adds the done ones with their fix")
	out = t.exec("python3", ["-I", script, "--dir", base, "show", "bbb", "--json"])
	t.check(out.rc == 0 and out.out.contains("\"grass floats\""), "show --json prints the raw note")
	out = t.exec("python3", ["-I", script, "--dir", base, "show", "bbb"])
	t.check(out.rc == 0 and out.out.contains("text: grass floats") and out.out.contains("no meta"), "show lays an older note out for people: %s" % out.out.left(120))
	out = t.exec("python3", ["-I", script, "--dir", base, "done", "bbb222", "deadbee"])
	t.check(out.rc == 0 and Store.find(base, "bbb222").status == "done" and Store.find(base, "bbb222").fix == "deadbee", "done closes it from the tool")
	out = t.exec("python3", ["-I", script, "--dir", base, "export-md", "--all"])
	t.check(out.out.contains("| id | sev |") and out.out.contains("legs cross at the turn") and out.out.contains("done (deadbee)"), "export-md writes a table: %s" % out.out.left(80))
	t.check(t.exec("python3", ["-I", script, "--dir", base, "done", "nope"]).rc != 0, "done on an unknown id fails")
	# --- crop rectangle
	t.eq(Flag.crop_rect(Vector2(10, 10), Vector2i(1280, 720)), Rect2i(0, 0, 384, 256), "crop stays inside the top-left corner")
	t.eq(Flag.crop_rect(Vector2(1270, 710), Vector2i(1280, 720)), Rect2i(896, 464, 384, 256), "and the bottom-right corner")
	# --- pins follow a moving creature, others stay
	var ents: Array = src.entities.duplicate(true)
	var cn := Store.make("c", [], 2, {"kind": "creature", "id": 1}, Vector3(10, 0, 0), {})
	var w0: Vector3 = Flag.pin_world(cn, ents, Callable(self, "_flat"))
	ents[1].x = 25.0
	ents[1].z = -3.0
	var w1: Vector3 = Flag.pin_world(cn, ents, Callable(self, "_flat"))
	t.check(absf(w0.x - 10.0) < 1e-4 and absf(w1.x - 25.0) < 1e-4 and absf(w1.z + 3.0) < 1e-4 and w1.y > 1.0, "a creature pin follows the body and sits above it")
	var tn := Store.make("t", [], 2, {"kind": "terrain", "id": -1}, Vector3(3, 0, 4), {})
	t.check(Flag.pin_world(tn, ents, Callable(self, "_flat")).is_equal_approx(Vector3(3, 1.2, 4)), "a terrain pin stays where it was")
	ents[1].dead = true
	t.check(Flag.pin_world(cn, ents, Callable(self, "_flat")).is_equal_approx(Vector3(10, 1.2, 0)), "a dead creature's pin goes back to the spot")
	# --- flag mode: saving, suspension, console
	var sw = StageWorld.new()
	var setup: Dictionary = CporeWorld.default_setup(42)
	setup.terrain = 1
	sw.reset(setup)
	Game.stage = sw
	var flag = Dev.flag
	flag.base_dir = base
	_wipe(base)
	t.check(not Game.options_open, "game keys are free before flag mode")
	flag.enter()
	t.check(flag.active and Game.options_open and Game.movement_blocked(), "flag mode suspends the game input")
	var hud = Dev.options_hud
	hud.open()
	flag.exit()
	t.check(Game.options_open, "leaving flag mode keeps the game suspended while the F10 HUD is open")
	flag.enter()
	hud.close()
	t.check(Game.options_open, "and the other way round")
	flag.exit()
	t.check(not Game.options_open, "closing both frees the game")
	flag.enter()
	flag.tag_i = 0
	flag.cycle_tag()
	t.eq(flag.tag_name(), "look", "Tab cycles tags")
	for i in 4:
		flag.cycle_tag()
	t.eq(flag.tag_name(), "", "and wraps through none")
	flag.cycle_severity()
	flag.cycle_severity()
	flag.cycle_severity()
	t.eq(flag.severity, 2, "severity cycles 1-3 and wraps")
	t.eq(flag.save_note("floats", ["look"], 2, {"kind": "terrain", "id": -1, "name": "ground", "pos": Vector3(1, 2, 3)}, false), "", "save_note")
	t.eq(flag.notes.size(), 1, "the open list reloads after a save")
	var saved: Dictionary = flag.notes[0]
	t.check(saved.tick == 0 and saved.pos == [1.0, 2.0, 3.0] and saved.build != "" and saved.options == {}, "the note carries tick, position, build, options")
	flag.exit()
	t.check(not Game.options_open, "exit frees the game")
	var cr = CmdReg.new()
	Cmds.register(cr, flag)
	t.check(cr.execute("notes").out.contains("floats"), "console notes lists it")
	var add: Dictionary = cr.execute("note add the leg clips the rock")
	t.check(add.ok and add.out.begins_with("note #"), "note add saves a note on the player")
	var id: String = flag.last_saved
	t.check(Store.find(base, id).target.kind == "creature", "on the player's creature")
	t.check(cr.execute("note show " + id).out.contains("the leg clips the rock"), "note show")
	t.check(cr.execute("note done %s fixed in abc" % id).ok, "note done with a fix")
	t.eq(Store.find(base, id).fix, "fixed in abc", "the fix is stored")
	t.check(not cr.execute("notes").out.contains("the leg clips"), "done notes leave the list")
	t.check(cr.execute("notes all").out.contains("the leg clips"), "notes all keeps them")
	t.check(not cr.execute("note done nope").ok, "unknown id fails")
	Game.stage = null
	flag.base_dir = ""
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
