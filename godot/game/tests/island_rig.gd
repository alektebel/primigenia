extends RefCounted
# Shared by render tests and evidence: loads the island data (cache or generate) and builds the scene.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const IslandScene := preload("res://game/island/island.tscn")

static func load_island(tree: SceneTree, seed: int = 1, grass: int = 20000) -> Node3D:
	var entry := TerrainCache.load_entry(TerrainCache.game_params(seed))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(seed), CporeTerrain.new())
	Game.set_island(entry)
	Game.settings.grass = grass
	var island: Node3D = IslandScene.instantiate()
	tree.root.add_child(island)
	return island

static func look(island: Node3D, from: Vector3, at: Vector3) -> void:
	var cam: Camera3D = island.debug_camera
	cam.position = from
	cam.look_at(at)
