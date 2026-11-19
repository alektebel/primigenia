extends SceneTree
## Headless studio tests: godot --headless --path godot/studio --script res://tests/test_studio.gd

const Genome := preload("../genome.gd")
const Model := preload("../model.gd")
const PartsDB := preload("../parts_db.gd")
const Storage := preload("../storage.gd")
const Placeholder := preload("../placeholder/placeholder_view.gd")
const I18n := preload("../i18n.gd")

var fails := 0
var checks := 0
var root_dir := ""
var db: RefCounted

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)

func norm(d) -> String:
	return Model.snapshot_of(JSON.parse_string(JSON.stringify(d)))

func fixture(name: String) -> String:
	return FileAccess.get_file_as_string(root_dir.path_join("tests/fixtures/studio/" + name))

func _init() -> void:
	root_dir = ProjectSettings.globalize_path("res://").path_join("../..").simplify_path()
	db = PartsDB.new()
	test_parts_table()
	test_fixtures_and_migrations()
	test_validator_rejects()
	test_plan_cases()
	test_every_part()
	test_undo_redo_every_edit()
	test_transactions()
	test_spine()
	test_roundtrip_and_storage()
	test_placeholder_view()
	await test_ui()
	await test_parity_panels()
	print("studio tests: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

func test_parts_table() -> void:
	var web := FileAccess.get_file_as_string(root_dir.path_join("web/studio/parts.json"))
	var mine := FileAccess.get_file_as_string("res://data/parts.json")
	ok(web == mine, "data/parts.json identical to web/studio/parts.json")
	ok(db.categories.size() == 9, "nine categories")
	ok(db.parts.size() >= 40, "parts loaded")
	for c in db.categories:
		ok(db.ids_in(c).size() > 0, "category not empty: " + c)

func test_fixtures_and_migrations() -> void:
	var out_dir := root_dir.path_join("build/studio-godot")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for f in ["v1.json", "v2.json", "v3.json", "v4-glb-parts.json"]:
		var r := Genome.parse(fixture(f), db.by_id)
		ok(r["ok"], "fixture parses: %s (%s)" % [f, r["error"]])
		if not r["ok"]:
			continue
		var g: Dictionary = r["genome"]
		ok(g["schema"] == "cpore.creature/5", f + " is v5 after parse")
		if f.begins_with("v4"):
			ok(r["warnings"].is_empty() and not g.has("migration"), "v4 has no migration block")
		else:
			var from := int(f.substr(1, 1))
			ok(int(g["migration"]["from"]) == from, "%s migration.from" % f)
			ok(r["warnings"].has("migration.body"), f + " has migration warnings")
			ok(g["migration"]["source"]["schema"] == "cpore.creature/%d" % from, f + " keeps original source")
			ok(g["nodes"].size() == 7, f + " 7 spine nodes")
		var w := FileAccess.open(out_dir.path_join("parsed-" + f), FileAccess.WRITE)
		w.store_string(JSON.stringify(g, " ", true))
		w.close()
		# re-validating the parsed output must pass again and survive a text round trip
		var again := Genome.parse(JSON.stringify(g), db.by_id)
		ok(again["ok"] and norm(again["genome"]) == norm(g), "round trip stable: " + f)
	var v2 := Genome.parse(fixture("v2.json"), db.by_id)
	ok(v2["ok"] and v2["genome"]["regions"].size() <= 1, "v2 growth maps to at most one region")
	var v3 := Genome.parse(fixture("v3.json"), db.by_id)
	ok(v3["ok"] and v3["genome"]["regions"].size() >= 1, "v3 regions preserved")
	var bad: Dictionary = JSON.parse_string(fixture("v1.json"))
	bad["body"]["torso"] = 99
	ok(not Genome.parse(bad, db.by_id)["ok"], "v1 with torso out of range rejected")
	bad = JSON.parse_string(fixture("v1.json"))
	bad["parts"] = []
	ok(not Genome.parse(bad, db.by_id)["ok"], "v1 without mouth rejected")

func test_plan_cases() -> void:
	var cases = JSON.parse_string(FileAccess.get_file_as_string(root_dir.path_join("godot/creature/tests/parity/plan_cases.json")))
	ok(typeof(cases) == TYPE_ARRAY and cases.size() >= 30, "plan_cases.json present")
	for c in cases:
		var r := Genome.parse(JSON.stringify(c["genome"]), db.by_id)
		if c["error"] == null:
			ok(r["ok"], "plan case '%s' accepted (%s)" % [c["name"], r["error"]])
		else:
			ok(not r["ok"] and r["error"] == c["error"], "plan case '%s' -> %s (got %s)" % [c["name"], c["error"], r["error"]])

func test_validator_rejects() -> void:
	var base := Model.seed_doc("Merodeador")
	ok(Genome.validate(base, db.by_id)["ok"], "seed Merodeador valid")
	for s in Model.SEEDS:
		ok(Genome.validate(Model.seed_doc(s), db.by_id)["ok"], "seed valid: " + s)
	var cases := {
		"schema": func(d): d["schema"] = "cpore.creature/9",
		"name": func(d): d["name"] = "a<b",
		"nodes (3)": func(d): d["nodes"] = d["nodes"].slice(0, 3),
		"node radius": func(d): d["nodes"][0]["r"] = 9,
		"node distance": func(d): d["nodes"][1] = d["nodes"][0].duplicate(),
		"part type": func(d): d["parts"][0]["type"] = "nope",
		"part t": func(d): d["parts"][0]["t"] = 1.5,
		"leg without k": func(d): d["parts"][3].erase("k"),
		"horn len": func(d): d["parts"][2].erase("len"),
		"skin colour": func(d): d["skin"]["cA"] = "red",
		"skin pat": func(d): d["skin"]["pat"] = 1.5,
		"extra key": func(d): d["foo"] = 1,
		"part extra key": func(d): d["parts"][0]["bar"] = 1,
		"region family": func(d): d["regions"] = [{"id": "r", "schema": "cpore.growth/1", "family": "x", "seed": 1, "count": 1, "length": 1, "curve": 0, "branches": 0, "surface": "torso", "position": 0, "coverage": 0, "angle": 0, "mirror": true}],
	}
	for k in cases:
		var d: Dictionary = Model.seed_doc("Merodeador")
		cases[k].call(d)
		ok(not Genome.validate(d, db.by_id)["ok"], "validator rejects: " + k)
	var d := Model.seed_doc("Merodeador")
	d["regions"] = [{"id": "r-1", "schema": "cpore.growth/1", "family": "horns", "seed": 5, "count": 3, "length": 1, "curve": .2, "branches": 1, "surface": "torso", "position": .5, "coverage": .5, "angle": 0, "mirror": true}]
	ok(Genome.validate(d, db.by_id)["ok"], "valid region accepted")

func test_every_part() -> void:
	var m := Model.new(db)
	var view := Placeholder.new(db)
	var base_n: int = m.doc["parts"].size()
	for p in db.parts:
		var id: String = p["id"]
		m.new_from_seed("Merodeador")
		var before: String = m.snapshot()
		var i: int = m.add_part(id, .5, .8)
		ok(i == base_n, "add_part index for " + id)
		var r: Dictionary = m.validate()
		ok(r["ok"], "doc valid with part %s (%s)" % [id, r["error"]])
		ok(Genome.parse(m.to_json(), db.by_id)["ok"], "saved JSON parses with " + id)
		ok(m.doc["parts"][i]["type"] == id, "type stored " + id)
		# view interface
		view.set_genome(m.doc)
		ok(view.get_genome()["parts"].size() == base_n + 1, "view synced " + id)
		view.remove_part(i)
		ok(view.get_genome()["parts"].size() == base_n, "view remove " + id)
		var j: int = view.attach_part(id, .5, .8, {})
		ok(j == base_n and view.part_anchor(j).has("pos"), "view attach " + id)
		ok(m.remove_part(i), "remove_part " + id)
		ok(m.snapshot() == before, "remove restores doc " + id)
		ok(m.undo() and m.doc["parts"].size() == base_n + 1, "undo remove " + id)
		ok(m.undo() and m.snapshot() == before, "undo add " + id)
		ok(m.redo() and m.doc["parts"].size() == base_n + 1, "redo add " + id)
	view.free()

func test_undo_redo_every_edit() -> void:
	var edits := {
		"add_part": func(m): m.add_part("ojo", .3, .7),
		"remove_part": func(m): m.remove_part(0),
		"place_part": func(m): m.place_part(1, .2, 1.2),
		"nudge_part": func(m): m.nudge_part(1, .02, .05),
		"set_param size": func(m): m.set_param(0, "size", 1.7),
		"set_param rot": func(m): m.set_param(1, "rot", .6),
		"set_param tilt": func(m): m.set_param(1, "tilt", -.4),
		"set_param len": func(m): m.set_param(2, "len", 1.5),
		"set_param curve": func(m): m.set_param(2, "curve", .1),
		"set_param w": func(m): m.set_param(3, "w", .3),
		"move_node": func(m): m.move_node(3, 3.0, -.4),
		"set_node_radius": func(m): m.set_node_radius(3, 1.0),
		"add_vertebra": func(m): m.add_vertebra(2),
		"remove_vertebra": func(m): m.remove_vertebra(2),
		"set_skin pat": func(m): m.set_skin("pat", 3),
		"set_skin colour": func(m): m.set_skin("cB", "#112233"),
		"set_skin wet": func(m): m.set_skin("wet", .9),
		"set_skin scale": func(m): m.set_skin("scale", 12),
		"apply_palette": func(m): m.apply_palette(3),
		"set_name": func(m): m.set_name_("Nuevo nombre"),
		"new_from_seed": func(m): m.new_from_seed("Babosa"),
		"import_doc": func(m): m.import_doc(FileAccess.get_file_as_string(root_dir.path_join("tests/fixtures/studio/v3.json"))),
	}
	for k in edits:
		var m := Model.new(db)
		var before: String = m.snapshot()
		edits[k].call(m)
		var after := m.snapshot()
		ok(after != before, "edit changes doc: " + k)
		ok(m.can_undo(), "can undo: " + k)
		ok(m.validate()["ok"], "doc valid after: " + k)
		ok(m.undo() and m.snapshot() == before, "undo restores: " + k)
		ok(m.redo() and m.snapshot() == after, "redo reapplies: " + k)
		ok(not m.can_redo(), "redo empty after redo: " + k)
	# whole-sequence undo back to start, then redo to end
	var m := Model.new(db)
	var start := m.snapshot()
	for k in ["add_part", "set_param size", "move_node", "set_skin pat", "add_vertebra", "set_name", "remove_part"]:
		edits[k].call(m)
	var end_state := m.snapshot()
	var n := 0
	while m.undo(): n += 1
	ok(n == 7 and m.snapshot() == start, "7 undos return to start (%d)" % n)
	while m.redo(): pass
	ok(m.snapshot() == end_state, "full redo reaches end state")
	# a new edit clears redo
	m.undo()
	m.set_name_("Otro")
	ok(not m.can_redo(), "new edit clears redo")

func test_transactions() -> void:
	var m := Model.new(db)
	var start := m.snapshot()
	m.begin()
	for k in 20:
		m.move_node(3, 3.0 + k * .01, -.5)
		m.set_param(0, "size", 1.0 + k * .02)
	m.end()
	ok(m.undo(), "drag transaction undoes")
	ok(m.snapshot() == start and not m.can_undo(), "20 live updates = one undo step")
	m.begin()
	m.set_skin("pat", 2)
	m.cancel()
	ok(m.snapshot() == start and not m.can_undo(), "cancel restores and records nothing")
	m.begin(); m.end()
	ok(not m.can_undo(), "empty transaction records nothing")
	var live := [0]
	m.changed.connect(func(l): live[0] += 1 if l else 0)
	m.begin(); m.set_skin("wet", .1); m.end()
	ok(live[0] > 0, "live change signals during a transaction")

func test_spine() -> void:
	var m := Model.new(db)
	var n0: int = m.doc["nodes"].size()
	ok(m.add_vertebra(1) and m.doc["nodes"].size() == n0 + 1, "add vertebra")
	ok(m.remove_vertebra(1) and m.doc["nodes"].size() == n0, "remove vertebra")
	m.new_from_seed("Babosa")
	m.remove_vertebra(0); m.remove_vertebra(0)
	ok(m.doc["nodes"].size() == 4, "down to four vertebrae")
	ok(not m.remove_vertebra(0), "cannot go below four vertebrae")
	m.new_from_seed("Merodeador")
	var before_y: float = m.doc["nodes"][3]["y"]
	m.move_node(3, before_y + 1.0, m.doc["nodes"][3]["z"])
	ok(m.doc["nodes"][3]["y"] > before_y, "vertical bend moves node up")
	for i in range(1, m.doc["nodes"].size()):
		var a: Dictionary = m.doc["nodes"][i - 1]; var b: Dictionary = m.doc["nodes"][i]
		var d := Vector2(a["y"] - b["y"], a["z"] - b["z"]).length()
		ok(d >= .29 and d <= 1.96, "vertebra spacing kept at %d (%.2f)" % [i, d])
	# dragging the head end far away grows the spine, then back shrinks it
	var n1: int = m.doc["nodes"].size()
	var idx: int = n1 - 1
	var last: Dictionary = m.doc["nodes"][idx]
	m.begin()
	idx = m.move_node(idx, last["y"], last["z"] + 1.9)
	idx = m.move_node(idx, last["y"], last["z"] + 1.9)
	m.end()
	ok(m.doc["nodes"].size() >= n1, "end drag may add vertebra")
	ok(m.validate()["ok"], "spine edit keeps the document valid")
	m.set_node_radius(2, 99.0)
	ok(m.doc["nodes"][2]["r"] <= 1.7, "radius clamped")

func test_roundtrip_and_storage() -> void:
	var st := Storage.new("user://studio_test")
	for f in st.list():
		st.delete(f)
	var m := Model.new(db)
	m.set_name_("Criatura de prueba")
	m.add_part("pico", 1.0, 0.0)
	m.set_skin("cA", "#aabbcc")
	m.apply_palette(2)
	var path := st.save(m.get_doc())
	ok(path != "" and FileAccess.file_exists(path), "saved in user dir: " + path)
	ok(st.list().has("criatura-de-prueba.json"), "listed")
	var r := st.load_named("criatura-de-prueba.json", db.by_id)
	ok(r["ok"], "reloaded and validated")
	ok(norm(r["genome"]) == norm(m.doc), "genome round-trips through disk unchanged")
	var m2 := Model.new(db)
	var res := m2.import_doc(FileAccess.get_file_as_string(path))
	ok(res["ok"] and norm(m2.doc) == norm(m.doc), "import_doc round trip")
	ok(not m2.import_doc("{not json")["ok"], "garbage rejected")
	var before := m2.snapshot()
	ok(not m2.import_doc({"schema": "cpore.creature/4", "nodes": []})["ok"] and m2.snapshot() == before, "invalid import leaves doc untouched")
	var export_path := st.export_to(m.get_doc(), "user://studio_test/export.json")
	ok(export_path != "" and st.import_from(export_path, db.by_id)["ok"], "export/import file")
	# output for the web validator cross-check (tests/node_check.js)
	var out_dir := root_dir.path_join("build/studio-godot")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for sname in Model.SEEDS:
		var mm := Model.new(db)
		mm.new_from_seed(sname)
		mm.add_part("horn_crown", .6, 1.0)
		mm.add_part("leg_sprinter", .5, 2.0)
		mm.set_skin("pat", 2)
		st.export_to(mm.get_doc(), out_dir.path_join("saved-" + sname + ".json"))
	st.export_to(m.get_doc(), out_dir.path_join("saved-edited.json"))
	for f in st.list():
		st.delete(f)

func test_placeholder_view() -> void:
	var m := Model.new(db)
	var view := Placeholder.new(db)
	view.set_genome(m.doc)
	var nodes: PackedVector3Array = view.spine_node_positions()
	ok(nodes.size() == m.doc["nodes"].size(), "spine positions per node")
	ok(is_equal_approx(nodes[3].y, m.doc["nodes"][3]["y"]) and is_equal_approx(nodes[3].z, m.doc["nodes"][3]["z"]), "node position matches doc")
	# ray from the side at the torso centre hits the body at ang ~ +-90deg
	var c: Vector3 = nodes[3]
	var h: Dictionary = view.hit_body(Vector3(8, c.y, c.z), Vector3(-1, 0, 0))
	ok(not h.is_empty(), "side ray hits body")
	if not h.is_empty():
		ok(absf(absf(h["ang"]) - PI / 2) < .1, "side hit ang ~ 90deg (%f)" % h["ang"])
		ok(h["t"] > .3 and h["t"] < .8, "torso t in the middle (%f)" % h["t"])
	var top: Dictionary = view.hit_body(Vector3(0, c.y + 9, c.z), Vector3(0, -1, 0))
	ok(not top.is_empty() and absf(top["ang"]) < .1, "top ray hits at ang ~ 0")
	ok(view.hit_body(Vector3(8, 40, 0), Vector3(-1, 0, 0)).is_empty(), "miss returns empty")
	ok(view.hit_node(Vector3(8, c.y, c.z), Vector3(-1, 0, 0)) == 3, "ray through the side finds spine node 3")
	# attach a part at the hit point and find it back with hit_part
	var idx: int = view.attach_part("cuerno", top["t"], top["ang"], {"size": 1.0, "len": .9, "curve": .5})
	var a: Dictionary = view.part_anchor(idx)
	ok(not a.is_empty(), "anchor for attached part")
	var o: Vector3 = a["pos"] + Vector3(0, 6, 0)
	ok(view.hit_part(o, Vector3(0, -1, 0)) == idx, "hit_part finds attached part")
	view.free()

func test_ui() -> void:
	var scene = preload("../ui/studio.gd")
	var ui = scene.new()
	root.add_child(ui)
	await process_frame
	await process_frame
	ok(ui.model != null and ui.view != null, "UI built with model and view")
	var m = ui.model
	# palette: one button per part, grouped by the nine categories
	ok(ui.palette_button_count() == db.parts.size(), "palette has a slot for each part (%d)" % ui.palette_button_count())
	ok(ui.category_count() == 9, "nine palette categories")
	# drop a part from the palette on the body
	var n0: int = m.doc["parts"].size()
	var i: int = ui.drop_part_at_t("ojo", .5, 1.0)
	ok(i == n0 and m.selected == i, "palette drop adds and selects")
	ok(ui.view.get_genome()["parts"].size() == n0 + 1, "view updated after drop")
	ui.on_key_delete()
	ok(m.doc["parts"].size() == n0, "Delete key removes the selected part")
	ui.on_undo()
	ok(m.doc["parts"].size() == n0 + 1, "UI undo")
	ui.on_redo()
	ok(m.doc["parts"].size() == n0, "UI redo")
	# modes
	for mode in ["paint", "test", "build"]:
		ui.set_mode(mode)
		await process_frame
		ok(m.mode == mode, "mode " + mode)
	ui.set_mode("test")
	ui.toggle_play()
	ok(m.playing, "test mode play")
	ui.toggle_play()
	ok(not m.playing, "test mode stop")
	ui.set_mode("build")
	# language
	ui.set_lang("en")
	await process_frame
	ok(ui.mode_button_text("build") == "Build" and ui.mode_button_text("paint") == "Paint" and ui.mode_button_text("test") == "Test", "english labels")
	ui.set_lang("es")
	await process_frame
	ok(ui.mode_button_text("build") == "Construir", "spanish labels")
	ui.queue_free()
	await process_frame

func test_parity_panels() -> void:
	# model: random creature and growth regions validate through the web-compatible validator
	for sd in [1, 2, 3, 12345]:
		var rd: Dictionary = Model.random_doc(sd)
		ok(Genome.parse(JSON.stringify(rd), db.by_id)["ok"], "random creature %d validates" % sd)
	ok(norm(Model.random_doc(7)) == norm(Model.random_doc(7)), "random creature is deterministic per seed")
	ok(norm(Model.random_doc(7)) != norm(Model.random_doc(8)), "random creature differs per seed")
	var m := Model.new(db)
	ok(m.doc["regions"].size() == 0 and m.selected_region == -1, "no regions at start")
	var base := m.snapshot()
	ok(m.add_region(false) == 0 and m.doc["regions"].size() == 1, "add region")
	m.set_region("family", "plates"); m.set_region("count", 40); m.set_region("angle", 9.0); m.set_region("surface", "tail")
	var r: Dictionary = m.doc["regions"][0]
	ok(r["family"] == "plates" and r["count"] == 18 and absf(r["angle"] - PI) < .001 and r["surface"] == "tail", "region params clamp")
	ok(m.add_region(true) == 1 and m.doc["regions"][1]["family"] == "plates" and m.doc["regions"][1]["id"] == "region-2", "duplicate region gets a new id")
	m.vary_region()
	ok(m.doc["regions"][1]["seed"] == 18, "new variant bumps the seed")
	ok(Genome.parse(JSON.stringify(m.doc), db.by_id)["ok"], "document with regions validates")
	m.delete_region()
	ok(m.doc["regions"].size() == 1 and m.selected_region == 0, "delete region")
	while m.can_undo():
		m.undo()
	ok(m.snapshot() == base, "region edits undo back to the start")
	# UI: DNA meter, capabilities, regions, test actions, palette dimming
	var ui = preload("../ui/studio.gd").new()
	root.add_child(ui)
	await process_frame
	await process_frame
	ok(ui.dna_label != null and ui.dna_label.text.ends_with("/ 320"), "DNA meter shows the budget (%s)" % ui.dna_label.text)
	var dna0: int = ui.dna_value()
	ui.drop_part_at_t("cuerno", .6, .5)
	await process_frame
	ok(ui.dna_value() > dna0 or not ("stats" in ui.view and ui.view.stats().has("dna")), "DNA grows when a part is added")
	var has_caps: bool = not ui.view.stats().is_empty()
	if has_caps:
		await process_frame
		ok(ui.panel_box.find_child("Pips_vel", true, false) != null, "capabilities pips in the build panel")
	ok(ui.panel_box.find_child("AddRegion", true, false) != null, "regions panel in build mode")
	ui.panel_box.find_child("AddRegion", true, false).pressed.emit()
	await process_frame
	await process_frame
	ok(ui.model.doc["regions"].size() == 1 and ui.panel_box.find_child("Opt_family", true, false) != null, "adding a region shows its controls")
	ok(ui.view.get_genome()["regions"].size() == 1, "view receives the region")
	ui.panel_box.find_child("RandomButton", true, false).pressed.emit()
	await process_frame
	ok(ui.model.doc["name"].begins_with("Creature "), "Random button makes a random creature")
	ui.set_mode("test")
	await process_frame
	await process_frame
	ok(ui.panel_box.find_child("Act_bite", true, false) != null and ui.panel_box.find_child("Act_sing", true, false) != null, "bite and sing buttons in test mode")
	ui.toggle_run()
	ok(ui._run, "run toggle")
	ui.do_action("bite")
	ok(ui.palette_card.modulate.a < 1.0 and ui.palette_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "palette dims outside build mode")
	ui.set_mode("build")
	ok(ui.palette_card.modulate.a == 1.0, "palette back in build mode")
	ui.queue_free()
	await process_frame
