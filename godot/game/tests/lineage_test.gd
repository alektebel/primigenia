extends SceneTree
const Session := preload("res://game/stage/lineage_session.gd")
const TreeView := preload("res://game/stage/family_tree.gd")
const Bridge := preload("res://game/stage/stage_world.gd")
const Scenario := preload("res://devtools/scenario.gd")
const Controller := preload("res://game/stage/lineage_controller.gd")
const Pause := preload("res://ui/pause_menu.gd")
const CreatureMesh := preload("res://creature/creature.gd")
class TestUI extends Node:
	var paused := false
	var pause_menu
	func set_paused(value: bool) -> void:
		paused = value
		pause_menu.visible = value
class TestStageUI extends RefCounted:
	var ui
class TestIcons extends RefCounted:
	var pois_fn: Callable
class TestChase extends RefCounted:
	var map_center := Vector2.ZERO
	var z_target := 0.15
class TestIsland extends Node3D:
	var stage
	var stage_ui
	var icons
	var chase

var failures := 0
var pins := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Bridge.new()
	root.add_child(stage)
	stage.set_process(false)
	var setup := CporeWorld.default_setup(42)
	setup.terrain = 1
	setup.wild = []
	check(stage.reset(setup) == 0, "reset")
	check(stage.debug_now({"op": 6, "a": 2}) == 0, "AI frozen for history fixture")
	var bodies := CreatureMesh.seeds()
	var keys := bodies.keys()
	var first: Dictionary = bodies[keys[0]].duplicate(true)
	first.name = "Junco"
	check(Session.install(stage, first) == "", "first lineage body")
	check(stage.world.lineage_award(0, 3, 1) == 0, "hunter award")
	stage.step_ticks(3)
	var second: Dictionary = bodies[keys[1]].duplicate(true)
	second.name = "Junco"
	check(Session.install(stage, second, true) == "", "second generation")
	check(stage.world.lineage_award(1, 4, 1) == 0, "social award")
	stage.step_ticks(3)
	var third: Dictionary = bodies[keys[2]].duplicate(true)
	third.name = "Junco"
	check(Session.install(stage, third, true) == "", "third generation")
	var data: Dictionary = JSON.parse_string(stage.world.lineage())
	check(data.generation == 3, "generation three")
	check(data.generations.size() == 3, "three stored bodies")
	check(data.generations[0].cousin_id != data.generations[1].cousin_id, "distinct cousin species")
	check(not data.generations[0].counts_progress, "cousins excluded from progress")
	var path := "res://../build/lineage-godot/slot"
	check(Scenario.save(stage, {"genome": third}, path, "save", "lineage test") == "", "scenario save")
	var saved := Scenario.read(path + ".json")
	check(saved.ok, "scenario read")
	stage.step_ticks(2)
	var loaded := Scenario.load_into(saved, stage)
	check(loaded.ok, "scenario restore")
	check(stage.world.hash() == str(saved.dict.hash), "scenario restores lineage hash")
	check(saved.dict.lineage.generations.size() == 3, "save embeds lineage export")
	check(InputMap.has_action("family_tree"), "family tree input action")
	var legend = JSON.parse_string(FileAccess.get_file_as_string("res://devtools/legend.json"))
	check(legend.actions.has("family_tree"), "D13 legend entry")
	var snap := stage.world.snapshot()
	var before := stage.world.hash()
	stage.step_ticks(10)
	check(stage.restore_from(snap) == 0, "snapshot restored")
	check(stage.world.hash() == before, "hash restored")
	# A snapshot-backed segment reproduces ledger, generation bodies and types.
	stage.step_ticks(8)
	var expected := stage.world.hash()
	check(stage.restore_from(snap) == 0, "segment reset")
	stage.step_ticks(8)
	check(stage.world.hash() == expected, "segment replay deterministic")
	var screen := TreeView.new()
	root.add_child(screen)
	screen.cousin_pin_requested.connect(func(_g: Dictionary) -> void: pins += 1)
	screen.show_lineage(data)
	check(screen.generation_count == 3, "three tree nodes")
	check(screen.portraits.size() == 3, "three live SubViewports")
	for vp in screen.portraits:
		check(vp.own_world_3d and vp.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "live independent portrait")
	var pin_buttons := screen.find_children("*", "Button", true, false)
	for button in pin_buttons:
		if button.text.begins_with("Cousin branch"):
			button.pressed.emit()
	check(pins == 2, "both cousin map pins selectable")
	var island := TestIsland.new()
	island.stage = stage
	island.stage_ui = TestStageUI.new()
	var ui := TestUI.new()
	root.add_child(ui)
	ui.pause_menu = Pause.new()
	ui.add_child(ui.pause_menu)
	island.stage_ui.ui = ui
	island.icons = TestIcons.new()
	island.icons.pois_fn = func() -> Array: return [{"id": "nest"}]
	island.chase = TestChase.new()
	root.add_child(island)
	var controller := Controller.new()
	island.add_child(controller)
	controller.setup(island)
	ui.pause_menu.family_tree_requested.emit()
	check(controller.screen.visible and ui.paused, "pause menu opens family tree")
	controller.close()
	check(not controller.screen.visible and not ui.paused, "tree closes to gameplay")
	controller.open()
	controller.screen.cousin_pin_requested.emit(data.generations[0])
	check(island.icons.pois_fn.call().size() == 2, "strategic map adds one cousin pin")
	check(island.chase.z_target == 1.0, "pin opens strategic view")
	check(not ui.paused, "pin returns to running map")
	controller.open()
	controller.screen.cousin_pin_requested.emit(data.generations[1])
	check(island.icons.pois_fn.call().size() == 2, "pin replacement does not duplicate branches")
	island.queue_free()
	ui.queue_free()
	for i in 20:
		await process_frame
	if "--evidence" in OS.get_cmdline_user_args():
		var evidence_path := "res://../docs/evidence/godot/lineage"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(evidence_path))
		var file := FileAccess.open(evidence_path + "/lineage.json", FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t"))
	print("lineage Godot: %d failures; three live portraits, save/replay and cousin pins" % failures)
	screen.queue_free()
	stage.queue_free()
	for i in 3:
		await process_frame
	quit(0 if failures == 0 else 1)
