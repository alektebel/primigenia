extends SceneTree
# Evidence for run and fall: xvfb + software GL.
#   godot --rendering-driver opengl3 --path godot --script res://game/tests/run_fall_evidence.gd -- <out dir>
# Shots: walk.png, run.png (run stamina line, run gait), fall_*.png (slide pose on a cliff face), landing.png (damage number).

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const RockViews := preload("res://game/tests/rock_views.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")

var out_dir := ""
var game
var island: Node3D

func _initialize() -> void:
	_run.call_deferred()

func shot(name: String) -> void:
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_dir.path_join(name))
	print("wrote ", name)

func fast(seconds: float, step: float = 0.05) -> void:
	RenderingServer.render_loop_enabled = false
	var t := 0.0
	while t < seconds:
		await process_frame
		t += step
	RenderingServer.render_loop_enabled = true
	await process_frame

func keys(fwd: bool, run: bool) -> void:
	island.player_input.keys_override = {"forward": fwd, "back": false, "left": false, "right": false, "sprint": false, "run": run}

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/run-fall-evidence"
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.settings.grass = 30000
	var entry := TerrainCache.load_entry(TerrainCache.game_params(1))
	if entry.is_empty():
		entry = TerrainCache.build(TerrainCache.game_params(1), CporeTerrain.new())
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	for i in 30:
		await process_frame
	var only_fall: bool = args.size() > 1 and args[1] == "fall"
	if not only_fall:
		keys(true, false)
		await fast(2.0)
		await shot("walk.png")
		keys(true, true)
		await fast(2.5)
		await shot("run.png")
		print("run state ", island.stage.cur.player, " speed ", island.stage.cur.entities[0].speed)
		keys(false, false)
		await fast(0.5)
	# a cliff face: slide
	var data = TerrainData.new()
	data.setup(entry, false)
	var cliff: Dictionary = RockViews.find_cliff(data, true)
	if cliff.is_empty():
		cliff = RockViews.find_cliff(data, false)
	print("cliff ", cliff)
	island.stage.debug_now({"op": 1, "id": 0, "x": cliff.x, "z": cliff.z})
	keys(true, false)
	var k := 0
	var landed := false
	for i in 160:
		await fast(0.1)
		var pl: Dictionary = island.stage.cur.player
		if bool(pl.falling) and k < 3 and i % 2 == 0:
			await shot("fall_%d.png" % k)
			k += 1
			if k == 3:
				keys(false, false)
		for ev in island.stage.cur.get("social_events", []):
			if int(ev.type) == 27 and not landed:
				landed = true
				print("fell: drop_cm ", ev.move, " damage ", ev.value)
				await shot("landing.png")
		if landed:
			break
	keys(false, false)
	await fast(0.5)
	await shot("after.png")
	quit()
