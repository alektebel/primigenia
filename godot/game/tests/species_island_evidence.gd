extends SceneTree
# Species bodies on the real island: a herd frame per species (chase distance and close) and the player at the nest.
# xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/species_island_evidence.gd -- <out dir>
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const NAMES := ["rondo", "zanco", "espinodo", "garfio"]

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, name: String) -> void:
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(name), 0.9)

func _run() -> void:
	print("start")
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 4000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	print("island up")
	await settle(30)
	var island = current_scene
	var stage = game.stage
	stage.debug_now({"op": 6, "a": 2})    # freeze the wild
	island.chase_enabled = false
	island.stage_ui.ui.visible = false
	var cam: Camera3D = island.debug_camera
	var which := OS.get_cmdline_user_args().slice(1)
	for sp in 4:
		if not which.is_empty() and not which.has(str(sp)):
			continue
		var ids := []
		for i in range(1, stage.cur.entities.size()):
			if int(stage.cur.entities[i].species) == sp:
				ids.append(i)
		var c := Vector2.ZERO
		for i in ids:
			c += Vector2(stage.cur.entities[i].x, stage.cur.entities[i].z)
		c /= ids.size()
		var e0: Dictionary = stage.cur.entities[ids[0]]
		var look := Vector3(c.x, game.visual_ground(c.x, c.y) + 1.0, c.y)
		for view in [["chase", 16.0, 0.0], ["close", 6.0, 0.9]]:
			var d: float = view[1]
			var a: float = 0.7 + view[2]
			var p := Vector3(c.x + sin(a) * d, 0, c.y + cos(a) * d)
			p.y = game.visual_ground(p.x, p.z) + 2.2
			cam.position = p
			cam.look_at(look)
			await settle(12)
			await shot(out, "herd_%s_%s.jpg" % [NAMES[sp], view[0]])
		print(NAMES[sp], " x", ids.size())
	quit()
