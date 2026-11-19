extends SceneTree
# Field journal evidence (software GL under xvfb): every section and spread in Spanish and English, plus the overflow cases.
#   make godot-journal-evidence                 (1280x720)
#   xvfb-run -a godot --rendering-driver opengl3 --resolution 1024x600 --path godot \
#     --script res://game/tests/journal_evidence.gd -- <out dir> [suffix]
# The state is the real C world's (CporeWorld.state()), with a few fields overlaid where the fresh world has nothing yet
# (species seen / bonded / hunted, discovered parts, shard lines, recipes), so every page has something to show.
# Shard lines and recipe clues are DRAFT placeholders, not canon.

const Model := preload("res://ui/journal_model.gd")
const GameUI := preload("res://ui/game_ui.gd")

var out := ""
var suffix := ""
var ui

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out.path_join(name + suffix + ".jpg"), 0.9)
	print("wrote ", name + suffix)

func _backdrop() -> void:
	var g := Gradient.new()
	g.set_color(0, Color("#7d8c84"))
	g.set_color(1, Color("#3d4a41"))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	var r := TextureRect.new()
	r.texture = gt
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(r)

func _state() -> Dictionary:
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	assert(w.reset(setup) == 0)
	var st: Dictionary = w.state()
	st.social.dna_total = 213
	var rows: Array = st.social.species
	rows[0].seen = true
	rows[0].bonded = 2
	rows[0].observed = 2
	rows[1].seen = true
	rows[1].bonded = 3
	rows[1].resolution = 1
	rows[1].observed = 3
	rows[3].seen = true
	rows[3].kills = 3
	rows[3].resolution = 2
	rows[3].observed = 1
	var disc: Array = st.parts.discovered
	var have := {}
	for p in disc:
		have[p.id] = true
	for id in ["romo", "cuerno", "pua", "fauces", "placa", "zanca", "tail_spike", "jaw_nipper", "cresta"]:
		if not have.has(id):
			disc.append({"id": id, "index": 0, "owned": id in ["romo", "pua"], "level": 2 if id == "romo" else (1 if id == "pua" else 0), "tier": 0})
	st.parts.nodes = [{"kind": 3, "inspected": true}, {"kind": 3, "inspected": false}, {"kind": 3, "inspected": false}, {"kind": 4, "inspected": true}, {"kind": 4, "inspected": false}]
	st.parts.clues = 2
	return st

func _run() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else "user://journal"
	suffix = a[1] if a.size() > 1 else ""
	DirAccess.make_dir_recursive_absolute(out)
	var game = root.get_node("Game")
	game.persist_settings = false
	_backdrop()
	ui = GameUI.new()
	root.add_child(ui)
	await settle(3)
	var catalogue: Array = JSON.parse_string(FileAccess.get_file_as_string("res://game/data/parts.json")).parts
	var st := _state()
	var base := Model.build(st, CporeWorld.species(), CporeWorld.chains(), catalogue)
	# the shape state().shards and state().recipes are expected to have once the other branches land (DRAFT lines)
	base["shards"] = [
		{"index": 0, "found": true, "name": "", "line": {"en": "A warm grey splinter, ringing faintly when struck.", "es": "Una astilla gris y tibia que suena débilmente al golpearla."}},
		{"index": 1, "found": true, "name": "", "line": {"en": "Far from the crater, as if something had skipped across the sky and fallen apart.", "es": "Lejos del cráter, como si algo hubiera rebotado por el cielo y se hubiera deshecho."}},
		{"index": 2, "found": false, "name": "", "line": ""}, {"index": 3, "found": false, "name": "", "line": ""}, {"index": 4, "found": false, "name": "", "line": ""}]
	base["cave"] = "known"
	base["recipes"] = [
		{"id": "bone_spines", "name": {"en": "Bone spines", "es": "Espinas óseas"}, "state": "known", "clues_seen": 2, "clues_total": 3,
			"clues": [{"en": "An Espinodo fired a volley at a pursuer.", "es": "Un Espinodo lanzó una andanada a un perseguidor."}, {"en": "The fossil by the dry river shows back spines and a jaw.", "es": "El fósil del río seco muestra espinas en el lomo y una mandíbula."}],
			"note": "", "parts_have": 1, "parts_need": 2, "diet_ok": false},
		{"id": "rock_armour", "name": {"en": "Rock armour", "es": "Coraza de roca"}, "state": "hinted", "clues_seen": 1, "clues_total": 3,
			"clues": [{"en": "Something was chewing stones on the alpine slope.", "es": "Algo masticaba piedras en la ladera alpina."}], "note": "", "parts_have": -1, "parts_need": -1, "diet_ok": null},
		{"id": "secret_c", "name": "", "state": "unknown", "clues_seen": 0, "clues_total": 3, "clues": [], "note": "", "parts_have": -1, "parts_need": -1, "diet_ok": null}]
	ui.journal.source = func() -> Dictionary: return base
	ui.open_view("journal")
	await settle(10)
	for lang in ["en", "es"]:
		game.settings["language"] = lang
		for t in 4:
			ui.journal.set_tab(t)
			for pg in ui.journal.page_count():
				ui.journal.page = pg
				ui.journal._request_art()
				# wait for the pictures of the spread (bounded)
				for i in 240:
					await process_frame
					if _art_ready():
						break
				await settle(10)
				print("%s tab %s spread %d: %d cut lines" % [lang, ui.journal.TABS[t], pg, ui.journal.truncated])
				await shot("journal_%s_%s_%d" % [lang, ui.journal.TABS[t], pg])
	# a fresh world: what exists today (no shards, no cave, no recipes list) leaves those sections out
	var fresh := Model.build(CporeWorld.new().state(), CporeWorld.species(), CporeWorld.chains(), catalogue)
	ui.journal.set_model(fresh)
	for t in 4:
		ui.journal.set_tab(t)
		ui.journal.page = 0
		ui.journal._request_art()
		for i in 240:
			await process_frame
			if _art_ready():
				break
		await settle(10)
		await shot("journal_en_fresh_%s" % ui.journal.TABS[t])
	# overflow: seven long shard stories and every part found
	game.settings["language"] = "en"
	var long_line := "The shard is warm to the touch and hums when the wind turns. Nothing about it looks made, and yet its edges are too even, and the lichen will not grow on it however long it lies in the open. "
	var over := base.duplicate(true)
	over["shards"] = []
	for i in 7:
		over.shards.append({"index": i, "found": i < 5, "name": "", "line": long_line + long_line})
	over["fossils"] = []
	for i in 23:
		over.fossils.append({"kind": 3 if i % 3 else 4, "studied": i % 2 == 0})
	ui.journal.set_model(over)
	ui.journal.set_tab(2)
	for pg in ui.journal.page_count():
		ui.journal.page = pg
		await settle(10)
		print("overflow secrets spread %d: %d cut lines" % [pg, ui.journal.truncated])
		await shot("journal_overflow_secrets_%d" % pg)
	var all := base.duplicate(true)
	for t in all.parts:
		t.found = true
		t.owned = true
		t.level = 5
	all.parts_found = all.parts.size()
	all.parts_owned = all.parts.size()
	ui.journal.set_model(all)
	ui.journal.set_tab(1)
	ui.journal.page = ui.journal.page_count() - 1
	ui.journal._request_art()
	for i in 240:
		await process_frame
		if _art_ready():
			break
	await settle(10)
	await shot("journal_overflow_parts")
	quit(0)

func _art_ready() -> bool:
	var jv = ui.journal
	var m: Dictionary = jv.model
	match jv.TABS[jv.tab]:
		"species":
			for k in range(jv.page * 2, mini(jv.page * 2 + 2, m.species.size())):
				if jv.art.portrait(String(m.species[k].body), true) == null:
					return false
		"parts":
			var per: int = jv.parts_per_page()
			for k in range(jv.page * 2 * per, mini((jv.page + 1) * 2 * per, m.parts.size())):
				if jv.art.part(String(m.parts[k].id), true) == null:
					return false
	return true
