extends SceneTree
# Evidence for the wiring step: godot --path godot --rendering-driver opengl3 --script res://game/tests/wire_evidence.gd -- <out dir> [steps]
# (xvfb + software GL). Steps (comma list, default all): chase, strip, radial, far, studio.

const TerrainCache := preload("res://game/island/terrain_cache.gd")

var out_dir := ""
var game
var island: Node3D

func _initialize() -> void:
	_run.call_deferred()

func shot(name: String) -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(name))
	print("wrote ", name)
	return img

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

# Run game time without drawing: the world ticks and the actors animate at 20 fps of game time.
func fast(seconds: float, step: float = 0.05) -> void:
	RenderingServer.render_loop_enabled = false
	var t := 0.0
	while t < seconds:
		await process_frame
		t += step
	RenderingServer.render_loop_enabled = true
	await process_frame

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/wire-evidence"
	var steps: PackedStringArray = (args[1] if args.size() > 1 else "chase,strip,radial,far,studio").split(",")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.settings.grass = 60000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	var IslandScene = load("res://game/island/island.tscn")
	island = IslandScene.instantiate()
	root.add_child(island)
	await settle(30)
	if "chase" in steps:
		await shot("chase.png")
	if "strip" in steps:
		await _strip()
	if "radial" in steps:
		await _radial()
	if "creatures" in steps:
		await _creatures()
	if "far" in steps:
		await _far()
	if "studio" in steps:
		await _studio()
	quit()

func _strip() -> void:
	island.player_input.keys_override = {"forward": true, "back": false, "left": false, "right": false, "sprint": false}
	await fast(2.5)
	island.chase_enabled = false
	var frames := []
	var tiles := 8
	var gait_s := 0.0
	for k in tiles:
		var pp: Vector3 = island.player_pos
		var fwd: Vector3 = island.hosts[0].basis * Vector3(0, 0, 1)
		var side := fwd.cross(Vector3.UP).normalized()
		island.camera.position = pp + side * -9.0 + Vector3(0, 2.2, 0)
		island.camera.look_at(pp + Vector3(0, 1.4, 0))
		var img := await shot("_strip_%d.png" % k)
		frames.append(img)
		await fast(0.12)
	island.chase_enabled = true
	island.player_input.keys_override = {"forward": false, "back": false, "left": false, "right": false, "sprint": false}
	var tw := 640
	var th := 360
	var sheet := Image.create(tw * 4, th * 2, false, Image.FORMAT_RGB8)
	for k in tiles:
		var im: Image = frames[k]
		im.convert(Image.FORMAT_RGB8)
		im.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, tw, th), Vector2i((k % 4) * tw, (k / 4) * th))
		DirAccess.remove_absolute(out_dir.path_join("_strip_%d.png" % k))
	sheet.save_png(out_dir.path_join("walk_strip.png"))

func _radial() -> void:
	pass

# The three seed creatures in the world's light, side views like creature/seeds.png (docs/evidence/godot/creature).
func _creatures() -> void:
	island.chase_enabled = false
	var ActorHost = load("res://game/actors/actor_host.gd")
	var Creature_ = load("res://creature/creature.gd")
	var seeds: Dictionary = Creature_.seeds()
	var base: Vector3 = island.player_pos + Vector3(10.0, 0.0, 0.0)
	var cells := []
	var k := 0
	for name in ["Merodeador", "Zancuda", "Babosa"]:
		var h = ActorHost.new()
		island.add_child(h)
		var gen: Dictionary = Creature_.parse_genome(seeds[name]).genome
		var at := Vector3(base.x + k * 14.0, 0.0, base.z)
		at.y = game.ground(at.x, at.z)
		h.setup(gen, 50 + k, {}, Callable(game, "ground"))
		h.update(0.0, {"pos": at, "yaw": PI * 0.5, "speed": 0.0, "vel": Vector3.ZERO})
		await settle(2)
		h.update(0.05, {"pos": at, "yaw": PI * 0.5, "speed": 0.0, "vel": Vector3.ZERO})
		var box: AABB = h.body.rest_aabb()
		var mid: Vector3 = at + Vector3(0, box.size.y * 0.5, 0)
		var dist: float = maxf(box.size.y, box.size.z) * 1.9
		island.camera.fov = 42.0
		island.camera.position = mid + Vector3(dist * 0.25, dist * 0.12, dist) 
		island.camera.look_at(mid)
		island.terrain_chunks.update_lods(island.camera.global_position, true)
		var img := await shot("_c%d.png" % k)
		img.convert(Image.FORMAT_RGB8)
		cells.append(img)
		DirAccess.remove_absolute(out_dir.path_join("_c%d.png" % k))
		h.queue_free()
		k += 1
	var cw := 640
	var chh := 360
	var sheet := Image.create(cw * 3, chh, false, Image.FORMAT_RGB8)
	for i in 3:
		var im: Image = cells[i]
		im.resize(cw, chh, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, cw, chh), Vector2i(i * cw, 0))
	sheet.save_png(out_dir.path_join("exposure.png"))
	island.camera.fov = 48.0

func _far() -> void:
	island.chase_enabled = false
	island.camera.position = Vector3(0, 900, 2600)
	island.camera.look_at(Vector3(0, 150, 0))
	island.terrain_chunks.update_lods(island.camera.global_position, true)
	await settle(3)
	await shot("far.png")

func _studio() -> void:
	pass
