extends SceneTree
# P0 of docs/plans/island-realism.md (section 2): the fixed orbit-to-ground review camera path OG0..OG9 at four times of day.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 --path godot \
#     --script res://game/tests/island_path_shots.gd -- <out dir> <tier low|medium> [island] [shots OG2,OG5|all] [tods dawn,night|all]
# island: "0" or "default" = the game's own island (CporeTerrain.defaults()); a path to a packed island (.isl: the authored Star massif with its
# climate maps; `make godot-island-path ISLAND=godot/game/data/islands/star_massif.isl`); a path to a JSON file = terrain params (the "params"
# object of `terrain_cli layout-json --layout N`, or that whole output; later steps point it at an island file). `make godot-island-path`
# turns LAYOUT=N into that file. The shot list below is in world metres (x east, z south) for the Star massif; since B1 the nest is not the origin (seed 1: (0, 115), on the dry shore of the nest valley lake), so OG8 stands at the nest.
# Writes <out>/<tier>_<tod>_<OGn>.jpg, <out>/times_<tier>.json (software-GL ms per frame, a relative number only) and
# <out>/path_<tier>.json (the exact camera of every frame). Deterministic: frozen clouds, fixed times of day, no wildlife, fixed fps.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Clouds := preload("res://game/island/clouds.gd")

# Times of day (plan section 2). light = the C clock's light 0..1 (0.5 at 06:00 and 19:00), hour = the sun's position.
const TODS := {
	"dawn": {"light": 0.55, "hour": 6.5, "cloud": {"tod": 0.0, "cover": 0.55, "fog": 0.8}},
	"midday": {"light": 1.0, "hour": 12.5, "cloud": {"tod": 0.5, "cover": 0.55, "fog": 0.0}},
	"dusk": {"light": 0.55, "hour": 18.67, "cloud": {"tod": 1.0, "cover": 0.55, "fog": 0.0}},
	"night": {"light": 0.0, "hour": 23.0, "cloud": {"tod": 1.0, "cover": 0.55, "fog": 0.0}},
}
# pos/look are x, y, z in world metres. "agl" / "look_agl": y is metres above the visual ground instead of absolute.
# "stand_in": true until the step that makes the real shot (OG0/OG1 need the orbit sky, O1; nothing renders a planet yet).
const SHOTS := [
	{"name": "OG0", "pos": [0, 20000, 30000], "look": [0, 0, 0], "fov": 50.0, "stand_in": true, "note": "stand-in for 400 km orbit (O1)"},
	{"name": "OG1", "pos": [0, 12000, 1], "look": [0, 0, 0], "fov": 50.0, "stand_in": true, "note": "stand-in: 12 km straight down (60 km from O1)"},
	{"name": "OG2", "pos": [3500, 12000, -3500], "look": [-468, 600, -374], "fov": 55.0},
	{"name": "OG3", "pos": [1800, 3000, -2400], "look": [-300, 300, -200], "fov": 55.0},
	{"name": "OG4", "pos": [-300, 800, 2200], "look": [-936, 80, 1186], "fov": 55.0},
	{"name": "OG5", "pos": [874, 150, -1076], "agl": true, "look": [1248, 100, -1560], "look_agl": true, "fov": 62.0},
	{"name": "OG6", "pos": [520, 4, -640], "agl": true, "look": [874, 10, -1076], "look_agl": true, "fov": 62.0},
	{"name": "OG7", "pos": [940, 1.8, -1180], "agl": true, "look": [961, 1.6, -1214], "look_agl": true, "fov": 70.0},
	{"name": "OG8", "pos": [0, 2.5, 115], "agl": true, "look": [390, 60, -515], "look_agl": true, "fov": 62.0},
	{"name": "OG9", "chase": 0.45},
]

var game
var island: Node3D
var times := {}
var path_log := {}

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func ground(x: float, z: float) -> float:
	return game.visual_ground(x, z)

func hide_ui(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasLayer:
			c.visible = false
		else:
			hide_ui(c)

func set_tod(t: String) -> void:
	var d: Dictionary = TODS[t]
	Clouds.apply(d.cloud)
	var dn: Node = island.day_night
	dn.force_light = d.light
	dn.force_hour = d.hour
	dn.k = d.light
	dn.update_now()

func island_params(arg: String) -> Dictionary:
	if arg == "" or arg == "star" or arg == "default":
		return TerrainCache.game_params(1)     # B1: the game's island, the frozen Star massif desc
	var p := {"seed": 1}
	if arg == "ring" or arg == "0":
		return p                                # the old layout-0 ring island
	if arg.ends_with(".isl"):
		# a packed island (core/include/cpore/island.h): the authored Star massif with its climate maps (island-realism M2)
		var blob := FileAccess.get_file_as_bytes(arg)
		var info: Dictionary = CporeTerrain.island_info(blob)
		if blob.is_empty() or info.get("error", -1) != 0:
			push_error("cannot read island blob " + arg)
			quit(2)
			return {}
		p["n"] = int(info.n)
		p["island_blob"] = blob
		return p
	var f := FileAccess.open(arg, FileAccess.READ)
	if f == null:
		push_error("cannot read island file " + arg)
		quit(2)
		return {}
	var j: Variant = JSON.parse_string(f.get_as_text())
	if typeof(j) != TYPE_DICTIONARY:
		push_error("island file is not a JSON object: " + arg)
		quit(2)
		return {}
	var src: Dictionary = j.get("params", j)
	for k in src:
		p[k] = src[k]
	return p

func pick_list(arg: String, all: Array) -> Array:
	if arg == "" or arg == "all":
		return all
	var out := []
	for s in arg.split(",", false):
		if s in all:
			out.append(s)
		else:
			push_error("unknown name " + s)
			quit(2)
	return out

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/island-path"
	var tier: String = args[1] if args.size() > 1 else "medium"
	var params := island_params(args[2] if args.size() > 2 else "")
	var names := []
	for s in SHOTS:
		names.append(s.name)
	var want_shots := pick_list(args[3] if args.size() > 3 else "all", names)
	var want_tods := pick_list(args[4] if args.size() > 4 else "all", TODS.keys())
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	Clouds.frozen_time = 40.0
	game.settings.grass = 120000
	game.settings.quality = tier
	game.settings.wild = false   # no wildlife: the frames must not depend on creature motion
	var t0 := Time.get_ticks_msec()
	var entry := TerrainCache.load_entry(params)
	if entry.is_empty():
		entry = TerrainCache.build(params, CporeTerrain.new())
	if entry.is_empty() or entry.get("error", 0) != 0:
		push_error("terrain build failed: %s" % [entry.get("error", "?")])
		quit(3)
		return
	print("island ", params, " ready in ", Time.get_ticks_msec() - t0, " ms, hash ", entry.get("hash"))
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	await settle(40)
	hide_ui(root)
	for tod in want_tods:
		set_tod(tod)
		for s in SHOTS:
			if not s.name in want_shots:
				continue
			var nm := "%s_%s_%s" % [tier, tod, s.name]
			if s.has("chase"):
				island.chase_enabled = true
				island.camera.far = 12000.0   # the game's own far plane (the free shots use 200 km)
				island.chase.set_zoom(float(s.chase), true)
				await settle(8)
				island.terrain_chunks.update_lods(island.camera.global_position, true)   # the chase camera jumped: re-select the terrain chunks
				await settle(24)
				path_log[nm] = {"chase_zoom": s.chase}
			else:
				island.chase_enabled = false
				var pos := Vector3(s.pos[0], s.pos[1], s.pos[2])
				var look := Vector3(s.look[0], s.look[1], s.look[2])
				if s.get("agl", false):
					pos.y = ground(pos.x, pos.z) + float(s.pos[1])
				if s.get("look_agl", false):
					look.y = ground(look.x, look.z) + float(s.look[1])
				var cam: Camera3D = island.camera
				cam.fov = float(s.fov)
				cam.near = 0.03
				cam.far = 200000.0
				cam.position = pos
				cam.look_at(look)
				island.terrain_chunks.update_lods(cam.global_position, true)
				await settle(14)
				path_log[nm] = {"pos": [pos.x, pos.y, pos.z], "look": [look.x, look.y, look.z], "fov": s.fov, "stand_in": s.get("stand_in", false)}
			var t1 := Time.get_ticks_usec()
			for i in 2:
				await process_frame
			times[nm] = float(Time.get_ticks_usec() - t1) / 2000.0
			await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			img.save_jpg(out_dir.path_join(nm + ".jpg"), 0.88)
			print("wrote ", nm)
	island.chase_enabled = false
	for pair in [["times_%s.json" % tier, times], ["path_%s.json" % tier, path_log]]:
		var f := FileAccess.open(out_dir.path_join(pair[0]), FileAccess.WRITE)
		f.store_string(JSON.stringify(pair[1], "  ", true))
		f.close()
	quit(0)
