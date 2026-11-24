extends SceneTree
## A73 headless: the way out of the nest editor (Done / Cancel / Enter / Esc, the in-game confirm panel) and the hatch sequence's timeline.
##   godot --headless --path godot --script res://game/tests/editor_exit_test.gd
const Genome := preload("res://studio/genome.gd")
const Parts := preload("res://studio/parts_db.gd")
const Profile := preload("res://game/stage/profile.gd")

var fails := 0
var checks := 0

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: " + msg)

func _init() -> void:
	call_deferred("run")

func key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e

func run() -> void:
	var Studio = load("res://studio/ui/studio.gd")
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	w.reset(setup)
	var db := Parts.new()
	var starter: Dictionary = Genome.parse(Profile.load_json("res://game/data/merodeador.json"), db.by_id).genome
	starter.parts = [{"type": "pico", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0}]
	var profile := Profile.from_studio(starter, Profile.load_json("res://game/data/parts.json"))
	var counts: Array = []
	counts.resize(64)
	counts.fill(0)
	counts[2] = 1
	w.lineage_form(JSON.stringify(starter), profile.profile, counts, starter.name, false)
	var editor = Studio.new()
	editor.nest_world = w
	editor.nest_genome = starter
	root.add_child(editor)
	await process_frame
	await process_frame
	var left := [0]
	editor.exit_requested.connect(func() -> void: left[0] += 1)
	ok(editor.done_button != null and editor.done_button.visible, "the Done button exists and is visible")
	ok(editor.done_button.text == "Hecho · volver al nido", "Done label in Spanish: %s" % editor.done_button.text)
	editor.set_lang("en")
	ok(editor.done_button.text == "Done · back to the nest" or editor._exit_label() == "Done · back to the nest", "Done label in English: %s" % editor._exit_label())
	editor.set_lang("es")
	# 1. no changes: Done and Cancel leave at once, nothing applied, no panel
	ok(not editor.has_changes(), "a fresh editor has no changes")
	editor.request_done()
	ok(left[0] == 1 and editor.applied_genome.is_empty() and not editor.confirm_open(), "Done without changes leaves, applies nothing")
	editor.request_cancel()
	ok(left[0] == 2 and not editor.confirm_open(), "Cancel without changes leaves without asking")
	# 2. a change, then Cancel: an in-game panel asks; Esc keeps editing; Discard leaves without applying
	var doc: Dictionary = editor.model.get_doc()
	doc.skin.cA = "#00ff00"
	editor.model.import_doc(doc)
	ok(editor.has_changes(), "a repaint is a change")
	editor.request_cancel()
	ok(editor.confirm_open() and left[0] == 2, "Cancel with changes opens the confirm panel, does not leave")
	editor._unhandled_key_input(key(KEY_ESCAPE))
	ok(not editor.confirm_open() and left[0] == 2, "Esc on the panel keeps editing")
	editor.request_cancel()
	var secondary := editor._confirm.find_child("ConfirmSecondary", true, false) as Button
	ok(secondary != null and secondary.text == "Descartar y salir", "the panel offers Discard")
	secondary.pressed.emit()
	ok(left[0] == 3 and editor.applied_genome.is_empty() and not editor.confirm_open(), "Discard leaves without applying")
	# 3. Enter does the same as the Done button: a repaint is free, applies and leaves
	editor._unhandled_key_input(key(KEY_ENTER))
	ok(left[0] == 4 and editor.applied_genome.skin.cA == "#00ff00" and not editor.confirm_open(), "Enter = Done: the free repaint is applied and the editor leaves")
	# 4. a level-up needs Evolve and DNA: Done asks, with the cost; with no DNA it only offers to keep editing or discard
	editor.applied_genome = {}
	editor.nest_choice.select(0)
	editor._nest_try(0)
	ok(editor.nest_pending_cost() > 0, "a level-up has a price")
	editor.request_done()
	ok(editor.confirm_open() and left[0] == 4, "Done on a priced change asks first")
	ok(editor._confirm.find_child("ConfirmPrimary", true, false).text.contains("Seguir"), "with no DNA the default is Keep editing")
	editor._unhandled_key_input(key(KEY_ENTER))
	ok(not editor.confirm_open() and left[0] == 4, "Enter on the panel presses its default (keep editing here)")
	editor.queue_free()
	await process_frame
	await _hatch()
	print("editor exit: %d checks, %d failures" % [checks, fails])
	quit(1 if fails else 0)

class FakeHost extends Node3D:
	func height() -> float:
		return 1.2

class FakeIsland extends Node3D:
	var hosts := {}
	var camera: Camera3D
	var chase_enabled := true

func _hatch() -> void:
	var isl := FakeIsland.new()
	root.add_child(isl)
	var cam := Camera3D.new()
	isl.add_child(cam)
	cam.global_position = Vector3(0, 3, 8)
	cam.look_at(Vector3(0, 1, 0))
	isl.camera = cam
	var h := FakeHost.new()
	isl.add_child(h)
	h.global_position = Vector3(1, 0, 0)
	isl.hosts[0] = h
	var cam0 := cam.global_transform
	var seq: Node3D = load("res://game/stage/hatch_sequence.gd").new()
	var fin := [0]
	seq.finished.connect(func() -> void: fin[0] += 1)
	seq.start(isl, true)
	ok(seq.is_inside_tree() and not isl.chase_enabled, "the sequence took the camera")
	seq.set_process(false)
	for i in 10:
		seq._process(0.1)
	ok(not h.visible and seq.get_node("Egg") != null, "at 1.0 s the egg sits there and the creature is hidden")
	for i in 15:
		seq._process(0.1)
	ok(h.visible and h.scale.y < 1.0 and h.scale.y > 0.5, "after the burst the creature is up and standing (scale.y %.2f), never from zero" % h.scale.y)
	ok(fin[0] == 0, "not finished yet")
	for i in 20:
		seq._process(0.1)
	ok(fin[0] == 1, "finished once after about 3.6 s")
	ok(isl.chase_enabled and h.visible and is_equal_approx(h.scale.y, 1.0), "control returns: chase camera on, creature normal size")
	ok(cam.global_transform.origin.distance_to(cam0.origin) < 0.01, "the camera is back where it was")
	# skip with any key
	await process_frame
	var s2: Node3D = load("res://game/stage/hatch_sequence.gd").new()
	var fin2 := [0]
	s2.finished.connect(func() -> void: fin2[0] += 1)
	s2.start(isl, true)
	s2.set_process(false)
	s2._process(0.3)
	s2._input(key(KEY_SPACE))
	ok(fin2[0] == 1 and isl.chase_enabled and h.visible, "any key skips at once")
	# headless without force: no sequence at all, finished at once
	var s3: Node3D = load("res://game/stage/hatch_sequence.gd").new()
	var fin3 := [0]
	s3.finished.connect(func() -> void: fin3[0] += 1)
	s3.start(isl)
	await process_frame
	ok(fin3[0] == 1 and isl.chase_enabled, "headless runs skip the sequence")
