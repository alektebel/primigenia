extends SceneTree
# The radial fauna in its island habitat (S5a): brujula on the intertidal shelf, cuarteta in the shallows, corona on a tide-pool flat (a cave mouth when none).
# LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --path godot --script res://game/tests/radial_island_evidence.gd -- <out dir> [brujula cuarteta corona]
const TerrainCache := preload("res://game/island/terrain_cache.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func shot(out: String, name: String) -> void:
	await settle(6)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out.path_join(name), 0.9)
	print("saved ", name)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var which := args.slice(1)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	var island = current_scene
	game.stage.debug_now({"op": 6, "a": 2})
	island.chase_enabled = false
	island.stage_ui.ui.visible = false
	var fauna = island.get_node("RadialFauna")
	var cam: Camera3D = island.debug_camera
	for id in ["brujula", "cuarteta", "corona"]:
		if not which.is_empty() and not which.has(id):
			continue
		var group := []
		for a in fauna.animals:
			if a.id == id:
				group.append(a)
		if group.is_empty():
			print("no ", id)
			continue
		var c := Vector3.ZERO
		for a in group:
			c += a.creature.global_position
		c /= group.size()
		if id == "cuarteta":
			c = group[0].creature.global_position       # the bells are 15..60 m apart: look at one
		print(id, " at ", c, " x", group.size())
		var views: Array = [["wide", 11.0, 4.5, 0.6], ["close", 5.5, 2.2, 0.9]]
		if id == "cuarteta":
			views = [["wide", 9.0, 4.0, 0.6], ["close", 4.0, 1.8, 0.9]]
		if id == "corona" and fauna.placement.corona.get("site", "") == "cave":
			views = [["wide", 5.0, 1.8, 0.5], ["close", 2.4, 1.0, 0.8]]
		for v in views:
			var inward: Vector2 = fauna.placement.corona.inward if id == "corona" else Vector2.ZERO
			var yaw: float = v[3]
			var look := c + Vector3(0, 0.2, 0)
			var p := look + Vector3(sin(yaw) * v[1], v[2], cos(yaw) * v[1])
			if id == "corona" and fauna.placement.corona.get("site", "") == "cave":
				# stand outside the entrance (against `inward`), looking into the cave
				var side := Vector3(-inward.y, 0, inward.x)
				p = look + side * v[1] + Vector3(0, v[2] * .6, 0) - Vector3(inward.x, 0, inward.y) * v[1] * .3
			cam.position = p
			cam.look_at(look)
			await settle(14)
			print("  cam ", cam.global_position, " look ", look, " now ", cam.global_position)
			await shot(out, "%s_island_%s.jpg" % [id, v[0]])
	quit()
