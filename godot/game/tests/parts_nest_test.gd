extends SceneTree
const Genome := preload("res://studio/genome.gd")
const Parts := preload("res://studio/parts_db.gd")
const Studio := preload("res://studio/ui/studio.gd")
const Profile := preload("res://game/stage/profile.gd")
func _init() -> void:
	call_deferred("run")
func run() -> void:
	assert(load("res://game/stage/stage_ui.gd").can_instantiate())
	assert(load("res://game/stage/part_nodes.gd").can_instantiate())
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	assert(w.reset(setup) == 0)
	var state := w.state()
	assert(state.parts.eggs == 3 and state.parts.can_edit)
	assert(state.parts.discovered.size() == 3)
	var db := Parts.new()
	var v4 := Profile.load_json("res://game/data/merodeador.json")
	var migrated := Genome.parse(v4, db.by_id)
	assert(migrated.ok and migrated.genome.schema == "cpore.creature/5")
	for p in migrated.genome.parts:
		assert(p.level == 1 and p.tier == 0)
	var editor := Studio.new()
	editor.nest_world = w
	editor.nest_genome = migrated.genome
	root.add_child(editor)
	await process_frame
	assert(editor.nest_rows.size() == 3)
	assert(editor.palette_buttons.pua.visible == false)
	assert(editor.dna_label.text.contains("0"))
	editor.set_lang("en")
	assert(editor.nest_actions.size() == 3 and not editor.palette_buttons.pua.visible)
	editor.set_lang("es")
	editor._nest_confirm()
	assert(editor.nest_status.text.contains("rechazada"))
	var starter: Dictionary = migrated.genome.duplicate(true)
	starter.parts = [{"type": "pico", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0}]
	var profile := Profile.from_studio(starter, Profile.load_json("res://game/data/parts.json"))
	var counts: Array = []
	counts.resize(64)
	counts.fill(0)
	counts[2] = 1
	assert(w.lineage_form(JSON.stringify(starter), profile.profile, counts, starter.name, false) == 0)
	assert(editor.model.import_doc(starter).ok)
	var confirmed := [false]
	editor.nest_confirmed.connect(func(_g: Dictionary) -> void: confirmed[0] = true)
	editor._nest_confirm()
	assert(confirmed[0])
	assert(JSON.parse_string(w.lineage()).generations.size() == 2)
	editor.queue_free()
	await process_frame
	print("parts nest headless PASS")
	quit(0)
