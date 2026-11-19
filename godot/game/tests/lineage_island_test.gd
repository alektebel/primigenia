extends SceneTree
## Full island integration: real console -> C evolution -> cousin actors -> save/restore -> tree.
const Cache := preload("res://game/island/terrain_cache.gd")
const CreatureMesh := preload("res://creature/creature.gd")
const Registry := preload("res://devtools/console/registry.gd")
var Commands = null

const Scenario := preload("res://devtools/scenario.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = root.get_node("Game")
	game.settings.quality = "low"
	game.settings.grass = 0
	var terrain := Cache.get_or_build({"seed": int(game.settings.seed)})
	check(terrain.entry.get("error", -1) == 0, "terrain ready")
	game.set_island(terrain.entry)
	game.goto_island()
	for i in 5:
		await process_frame
	var island = current_scene
	check(island != null and island.stage_ui != null, "real island ready")
	island.stage.set_process(false)
	var initial: Dictionary = JSON.parse_string(island.stage.world.lineage())
	var old_n: int = island.stage.cur.entities.size() - 1
	var original_wild = island.hosts[1]
	var registry := Registry.new()
	registry.stage_provider = func(): return island.stage
	Commands = load("res://devtools/console/commands_creature.gd")
	Commands.register_all(registry)
	if "--evidence" in OS.get_cmdline_user_args():
		# Live somewhere other than the spawn so the home range (most occupied 64 m cell) is not the origin.
		registry.execute("tp 150 90")
		island.stage.set_process(true)
		for i in 60:
			await process_frame
		island.stage.set_process(false)
	var bodies := CreatureMesh.seeds()
	var keys := bodies.keys()
	var dir := "res://../build/lineage-island"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for i in [1, 2]:
		var body: Dictionary = bodies[keys[i]].duplicate(true)
		body.name = "Junco"
		var path := "%s/form%d.json" % [dir, i]
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(JSON.stringify(body))
		f.close()
		var result: Dictionary = registry.execute("evolve " + path)
		check(result.ok, "console evolution %d: %s" % [i, result.get("error", "")])
		check(island.hosts.has(old_n + i), "cousin actor spawned")
		check(island.hosts[1] == original_wild, "unchanged wild actor survives evolution")
		if i == 1:
			check(island.save_scenario(dir + "/generation2", "save", "integration test") == "", "save generation two")
	check(JSON.parse_string(island.stage.world.lineage()).generation == 3, "three generations on real island")
	var cousin_id := old_n + 1
	if "--evidence" in OS.get_cmdline_user_args():
		var home: Array = initial.get("generations", [])
		var gens: Array = JSON.parse_string(island.stage.world.lineage()).generations
		check(absf(float(gens[0].home_cm[0]) - 15000.0) < 6400.0 and absf(float(gens[0].home_cm[1]) - 9000.0) < 6400.0, "cousin home is where the player lived (%s)" % str(gens[0].home_cm))
	check(str(island.hosts[cousin_id].get_meta("lineage_body")) == str(initial.generations[0].body_json), "cousin retains founding body")
	var controller = null
	for child in island.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("lineage_controller.gd"):
			controller = child
	check(controller != null, "tree controller attached")
	controller.open()
	check(controller.screen.generation_count == 3, "real island tree has three portraits")
	if "--evidence" in OS.get_cmdline_user_args():
		await _evidence(island, controller, cousin_id, registry)
	controller.close()
	var old_cousin = island.hosts[cousin_id]
	var restored: String = island.load_scenario(Scenario.read(dir + "/generation2.json"))
	check(restored == "", "restore earlier lineage: " + restored)
	check(island.hosts[1] == original_wild and island.hosts[cousin_id] == old_cousin, "matching actors survive lineage restore")
	check(not island.hosts.has(old_n + 2), "future cousin removed on earlier save restore")
	check(JSON.parse_string(island.stage.world.lineage()).generation == 2, "generation two restored")
	registry.commands.clear()
	registry.stage_provider = Callable()
	print("lineage island: %d failures; console evolution, cousin bodies, restore and tree" % failures)
	quit(0 if failures == 0 else 1)

## Software-GL captures: a cousin standing in the valley with its card selected, then the family tree on the real island (T).
func _evidence(island, controller, cousin_id: int, registry) -> void:
	var out := ProjectSettings.globalize_path("res://../docs/evidence/godot/lineage")
	DirAccess.make_dir_recursive_absolute(out)
	controller.close()
	var e: Dictionary = island.stage.cur.entities[cousin_id]
	var p: Dictionary = island.stage.cur.entities[0]
	var dir := Vector2(float(e.x) - float(p.x), float(e.z) - float(p.z))
	print("evidence: cousin %.1f m from the player" % dir.length())
	registry.execute("tp %.1f %.1f" % [float(e.x) - 7.0, float(e.z)])
	island.stage.set_process(true)
	island.stage_ui._on_clicked(cousin_id, Vector3.ZERO)
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_jpg(out + "/cousin-in-valley.jpg", 0.9)
	controller.open()
	for i in 40:
		await process_frame
	root.get_texture().get_image().save_jpg(out + "/family-tree-island.jpg", 0.9)
	controller.close()
	island.stage.set_process(false)
