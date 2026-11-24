extends SceneTree
# A59 ambient fliers: a close recording of one flier doing one thing in the real island (software GL, xvfb).
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 960x540 --fixed-fps 30 \
#     --write-movie <out>.avi --path godot --script res://game/tests/fliers_clip.gd -- <mode> <species> [seconds] [seed]
# mode: fly (a bird in cruise, three-quarter chase) | land (from the approach to the perch) | takeoff (a perched flock leaves)
#       | flee (a walking player approaches a perched flock) | flock (a wide view of the whole flock)
# species: alariz pico zancuilla alasucena
const TerrainCache := preload("res://game/island/terrain_cache.gd")
var Flock = null     # loaded at run time: the script chain reaches the Game autoload, which does not exist yet when this script compiles
const Species := preload("res://game/island/fliers/flier_species.gd")

var game
var island
var fl
var bird: Dictionary = {}
var walker := Vector3.INF
var every := OS.get_environment("FLIERS_EVERY") == "1"     # with FLIERS_SHOTS: every frame (assemble with ffmpeg -framerate 30), else one still a second
var shots := OS.get_environment("FLIERS_SHOTS")     # a path prefix: save stills every 1.5 s (a quick look without --write-movie)

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func _pick(mode: String, sp: int) -> Dictionary:
	# pre-roll the sim (the node stays paused) until the wanted moment shows up
	for i in 60 * 60 * 25:
		for b in fl.birds:
			if b.species != sp:
				continue
			match mode:
				"fly":
					if b.state == Flock.S.FLY and b.t > 3.0:
						return b
				"land":
					if b.state == Flock.S.APPROACH:
						return b
				"takeoff", "flee", "flock":
					if b.state == Flock.S.PERCH and fl.flocks[b.flock].state == "perch" and i > 60 * 5:
						return b
		fl.step(1.0 / 60.0, Vector3.INF)
	return {}

func _run() -> void:
	Flock = load("res://game/island/fliers/flier_flock.gd")
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0]
	var sp: int = ["alariz", "pico", "zancuilla", "alasucena"].find(args[1])
	var secs := float(args[2]) if args.size() > 2 else 12.0
	var wseed := int(args[3]) if args.size() > 3 else 1
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 3000
	game.settings.seed = wseed
	var entry := TerrainCache.load_entry({"seed": wseed})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": wseed}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 6000:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(20)
	island = current_scene
	island.chase_enabled = false
	island.stage_ui.ui.visible = false
	fl = island.get_node("Fliers")
	fl.set_process(false)
	print("flocks ", fl.flocks.size(), " birds ", fl.birds.size())
	bird = _pick(mode, sp)
	if bird.is_empty():
		print("no bird for ", mode, " ", args[1])
		quit(1)
		return
	var sd: Dictionary = Species.get_data(sp)
	print("following ", args[1], " state ", bird.state, " at ", bird.pos)
	var fl_state: Dictionary = fl.flocks[bird.flock]
	if mode == "flee":
		var dirv := Vector2(1, 0.4).normalized()
		walker = bird.pos + Vector3(dirv.x, 0, dirv.y) * float(sd.flee) * 2.2
		walker.y = fl._ground.call(walker.x, walker.z)
	fl._player = func() -> Vector3: return walker if walker != Vector3.INF else Vector3.INF
	fl._player_prev = Vector3.INF
	island.player_pos = Vector3.INF
	var cam: Camera3D = island.camera
	cam.fov = 45.0
	var size: float = float(sd.span)
	var look: Vector3 = bird.pos
	var cam_pos: Vector3 = Vector3.ZERO
	var frames := int(secs * 30.0)
	var first := true
	for fr in frames:
		var dt := 1.0 / 30.0
		if mode == "flee" and walker != Vector3.INF:
			var to: Vector3 = (bird.pos - walker)
			to.y = 0.0
			if fr > 20 and to.length() > 1.5:
				walker += to.normalized() * 3.0 * dt
				walker.y = fl._ground.call(walker.x, walker.z)
		for k in 2:
			fl.step(1.0 / 60.0, walker)
		if fl._render:
			fl._draw()
		# camera: a framed three-quarter view that follows the bird with a soft lag
		var fwd := Vector3(sin(bird.yaw), 0, cos(bird.yaw))
		var right := fwd.cross(Vector3.UP).normalized()
		var dist := size * (2.4 if mode != "flock" else 9.0)
		if mode == "flee" or mode == "takeoff":
			dist = size * 5.5 + 2.0
		var want: Vector3 = bird.pos + right * dist * 0.85 + fwd * dist * 0.45 + Vector3.UP * dist * 0.28
		if mode == "flee" or mode == "takeoff":
			if first:
				# the player's own view: from the side the walker comes from, a little above, looking at the flock
				var tw: Vector3 = (walker - bird.pos) if walker != Vector3.INF else Vector3(1, 0, 0.4)
				tw.y = 0.0
				tw = tw.normalized()
				want = bird.pos + tw * (size * 6.0 + 2.5) + Vector3.UP * (size * 3.0 + 1.0) + tw.cross(Vector3.UP) * (size * 2.0)
		if first:
			cam_pos = want
			look = bird.pos
		cam_pos = cam_pos.lerp(want, 0.12 if mode != "flee" and mode != "takeoff" else 0.0)
		look = look.lerp(bird.pos + Vector3.UP * size * 0.1, 0.25)
		cam.position = cam_pos
		cam.look_at(look)
		first = false
		await process_frame
		if fr % 30 == 0:
			print("frame ", fr, " bird ", bird.pos, " state ", bird.state, " cam ", cam.position, " ground at bird ", fl._ground.call(bird.pos.x, bird.pos.z))
		if shots != "" and (every or fr % 30 == 10):
			root.get_texture().get_image().save_jpg("%s_%04d.jpg" % [shots, fr], 0.88)
	quit()
