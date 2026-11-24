extends SceneTree
# Render test of the ground marks (PLAN-ui-diegetic.md S1), software GL under xvfb:
#   make godot-ground-marks-render-test
# A bone ring is put on the ground at a chase and at a mid zoom, on flat ground and on a slope, and the test counts bone-coloured
# pixels in the screen box where it must be; then the player's body is put in front of it and the count must drop.

const TerrainCache := preload("res://game/island/terrain_cache.gd")

var checks := 0
var failures := 0

func check(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
	else:
		print("  ok ", what)

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func bone_pixels(img: Image, box: Rect2i) -> int:
	var n := 0
	for y in range(maxi(box.position.y, 0), mini(box.end.y, img.get_height())):
		for x in range(maxi(box.position.x, 0), mini(box.end.x, img.get_width())):
			var c := img.get_pixel(x, y)
			if c.r > 0.72 and c.g > 0.7 and c.b > 0.58 and c.r - c.b < 0.25:
				n += 1
	return n

func _run() -> void:
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
	await settle(20)
	var island = current_scene
	island.chase_enabled = false
	island.stage.process_mode = Node.PROCESS_MODE_DISABLED
	island.stage_ui.ui.visible = false
	island.grass.visible = false
	var d = game.data
	# a flat spot and a slope near the nest
	var flat := Vector3.INF
	var slope := Vector3.INF
	var best_slope := 0.0
	var nest: Vector2 = island._nest
	for r in range(30, 200, 10):
		for a in 24:
			var x: float = nest.x + cos(a * 15.0 * PI / 180.0) * float(r)
			var z: float = nest.y + sin(a * 15.0 * PI / 180.0) * float(r)
			var k: int = d.cell_index(x, z)
			if d.river_class(k) > 0 or d.is_pond(k) or d.is_sea(k) or d.height[k] < 3.0:
				continue
			var ny: float = d.normal(x, z).y
			if flat == Vector3.INF and ny > 0.99:
				flat = Vector3(x, d.ground(x, z), z)
			if 1.0 - ny > best_slope and ny > 0.75:
				best_slope = 1.0 - ny
				slope = Vector3(x, d.ground(x, z), z)
	check(flat != Vector3.INF and slope != Vector3.INF, "found flat ground and a slope (1 - n.y = %.2f)" % best_slope)
	var gm = island.ground_marks
	var cam: Camera3D = island.camera
	for spot in [["flat", flat], ["slope", slope]]:
		for dist in [7.0, 16.0]:       # chase distance and a mid zoom
			var p: Vector3 = spot[1]
			gm.move_marker(p)
			gm.move_mark.alpha = 1.0
			gm.move_mark.scale_mul = 1.0
			gm.move_mark._scale_t = 1.0
			gm.move_mark.breathe = false
			var from := p + Vector3(0, dist * 0.55, dist * 0.8)
			cam.global_position = from
			cam.look_at(p)
			await settle(6)
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var sp: Vector2 = cam.unproject_position(p)
			var rpx: float = gm.move_radius() / dist * 808.0 * 1.2
			var box := Rect2i(Vector2i(sp) - Vector2i(int(rpx * 1.3), int(rpx * 0.9)), Vector2i(int(rpx * 2.6), int(rpx * 1.8)))
			var n := bone_pixels(img, box)
			check(n > 12, "the move ring is visible on %s ground at %.0f m (%d bone pixels in its box)" % [spot[0], dist, n])
	# hidden behind the player's body: put the player between the camera and the ring
	var p2: Vector3 = flat
	gm.move_marker(p2)
	gm.move_mark.alpha = 1.0
	gm.move_mark._scale_t = 1.0
	gm.move_mark.scale_mul = 1.0
	gm.move_mark.breathe = false
	var from2 := p2 + Vector3(0, 5.0, 7.0)
	cam.global_position = from2
	cam.look_at(p2)
	await settle(6)
	await RenderingServer.frame_post_draw
	var sp2: Vector2 = cam.unproject_position(p2)
	var rpx2: float = gm.move_radius() / 9.0 * 808.0 * 1.2
	var box2 := Rect2i(Vector2i(sp2) - Vector2i(int(rpx2 * 1.3), int(rpx2 * 0.9)), Vector2i(int(rpx2 * 2.6), int(rpx2 * 1.8)))
	var before := bone_pixels(root.get_texture().get_image(), box2)
	var dir := (from2 - p2).normalized()
	island.stage.debug_now({"op": 1, "id": 0, "x": p2.x + dir.x * 1.2, "z": p2.z + dir.z * 1.2})
	island.stage.process_mode = Node.PROCESS_MODE_INHERIT
	await settle(30)
	island.stage.process_mode = Node.PROCESS_MODE_DISABLED
	cam.global_position = from2
	cam.look_at(p2)
	await settle(6)
	await RenderingServer.frame_post_draw
	var after := bone_pixels(root.get_texture().get_image(), box2)
	check(before > 12 and after < before, "the player's body hides part of the ring (%d -> %d bone pixels)" % [before, after])
	print("ground marks render: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
