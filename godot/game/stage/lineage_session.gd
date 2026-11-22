extends RefCounted
## Converts validated studio bodies to the C ancestry record. Presentation never earns deeds.
const Profile := preload("res://game/stage/profile.gd")
const Genome := preload("res://creature/creature.gd")

static func part_ids() -> Array:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var ids: Array = []
	for p in manifest.get("parts", []):
		ids.append(str(p.id))
	# Manifest order is the version-1 part-id contract; append new ids, never reorder.
	return ids

static func install(stage, genome: Dictionary, evolve: bool = false) -> String:
	var valid: Dictionary = Genome.parse_genome(genome)
	if not valid.get("ok", false):
		return str(valid.get("error", "Invalid creature"))
	var pr := Profile.from_studio(genome, Profile.load_json("res://game/data/parts.json"))
	if not pr.ok:
		return str(pr.error)
	var counts: Array = []
	counts.resize(64)
	counts.fill(0)
	var ids := part_ids()
	for p in genome.parts:
		var id := ids.find(str(p.type))
		if id < 0 or id >= counts.size():
			return "Part has no lineage id: %s" % p.type
		counts[id] += 1
	var rc: int = stage.world.lineage_form(JSON.stringify(genome), pr.profile, counts, str(genome.get("name", "Creature")), evolve)
	if rc != 0:
		return "Evolution refused: finish the fight, leave room for a cousin, or start a new lineage when its history is full."
	# A body change starts a snapshot-backed replay segment. The immutable snapshot
	# embeds every older generation and ledger entry; later inputs replay from it.
	if stage.restore_from(stage.world.snapshot()) != 0:
		return "Cannot start lineage replay segment."
	var game = Engine.get_main_loop().root.get_node_or_null("Game") if Engine.get_main_loop() is SceneTree else null
	if evolve and game != null and not game.evolved_once:
		game.evolved_once = true
		game.loop_event.emit("first_evolve", {})
	return ""

static func evolve_file(island, path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Creature file does not exist: %s" % path
	var genome := Profile.load_json(path)
	var err := install(island.stage, genome, true)
	if err != "":
		return err
	# Reuse the normal scenario restoration path to redress all bodies and player.
	var built = preload("res://devtools/scenario.gd").build(island.stage, island.scenario_ctx(), "save", "evolution", "", false)
	built.json.genome = genome
	return island.load_scenario({"dict": built.json, "state": built.state, "recipe": ""})

static func generations(world) -> Array:
	var d = JSON.parse_string(world.lineage())
	return d.get("generations", []) if d is Dictionary else []

static func cousin(world, id: int) -> Dictionary:
	for g in generations(world):
		if int(g.cousin_id) == id:
			return g
	return {}
