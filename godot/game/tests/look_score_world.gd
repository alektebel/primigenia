extends "res://game/tests/flora_evidence.gd"
# Visual scorecard, world part (docs/briefs/look-score.md): fixed cameras found by rule, four times of day, one quality tier per run.
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --fixed-fps 30 --resolution 1280x720 --path godot \
#     --script res://game/tests/look_score_world.gd -- <out dir> <quality low|medium>
# Writes <out>/<tier>_<tod>_<shot>.jpg, <tier>_<tod>_creature_dist_mask.png (pixels that change when the player creature is hidden)
# and <out>/times_<tier>.json (wall-clock ms per frame per shot, software GL).
# Times of day: the C clock's light (0 night .. 1) drives day_night.gd (sun colour/energy, ambient, exposure) and Clouds presets tint
# sky, clouds and fog. The sun direction and the terrain's baked light are fixed by the hero look (clouds.gd header).

const DayNight := preload("res://game/island/day_night.gd")
const Clouds := preload("res://game/island/clouds.gd")
const TODS := {
	"dawn": {"light": 0.30, "cloud": {"tod": 0.0, "cover": 0.55, "fog": 0.8}},
	"midday": {"light": 1.0, "cloud": {"tod": 0.5, "cover": 0.55, "fog": 0.0}},
	"dusk": {"light": 0.30, "cloud": {"tod": 1.0, "cover": 0.55, "fog": 0.0}},
	"night": {"light": 0.0, "cloud": {"tod": 1.0, "cover": 0.55, "fog": 0.0}},
}
var tier := ""
var times := {}
var cams := []   # {name, pos, look, fov} or {name, chase: zoom}

func set_tod(t: String) -> void:
	var d: Dictionary = TODS[t]
	Clouds.apply(d.cloud)
	var dn: Node = island.day_night
	dn.force_light = d.light
	dn.k = d.light
	dn.update_now()

func grab(name: String) -> Image:
	await settle(10)
	var t0 := Time.get_ticks_usec()
	for i in 6:
		await process_frame
	times[name] = float(Time.get_ticks_usec() - t0) / 6000.0
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

func add_cam(name: String, pos: Vector3, look: Vector3, fov: float) -> void:
	cams.append({"name": name, "pos": pos, "look": look, "fov": fov})

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/look-score"
	var quality: String = args[1] if args.size() > 1 else "medium"
	tier = quality
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	Clouds.frozen_time = 40.0
	game.settings.grass = 120000
	game.settings.quality = quality
	game.settings.wild = true
	var params := {"seed": 1}
	var entry := TerrainCache.load_entry(params)
	if entry.is_empty():
		entry = TerrainCache.build(params, CporeTerrain.new())
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	await settle(40)
	var nest: Vector2 = island._nest
	var np := Vector3(nest.x, ground(Vector3(nest.x, 0, nest.y)), nest.y)
	# Fixed camera rules (same as flora_evidence.gd / world_look_evidence.gd).
	add_cam("valley_east", np + Vector3(-5, 2.2, 0), np + Vector3(60, 3, 12), 62.0)
	add_cam("vista_wide", np + Vector3(-300, 90, 260), np + Vector3(200, 5, -80), 62.0)
	var rib := densest("trenza_de_ribera", 25.0)
	if not rib.is_empty():
		var r: Vector3 = rib.p
		var e := r + Vector3(12, 0, 9)
		add_cam("riverbank", Vector3(e.x, ground(e) + 2.0, e.z), r + Vector3(0, 1.2, 0), 62.0)
	var grove := densest("nieblon", 40.0)
	if not grove.is_empty():
		var g: Vector3 = grove.p
		var inside := g + Vector3(8, 0, 5)
		add_cam("forest_floor", Vector3(inside.x, ground(inside) + 1.7, inside.z), g + Vector3(-10, 8, -6), 70.0)
	var madre := pick("madre_de_agua")
	if not madre.is_empty():
		var m: Vector3 = madre.p
		add_cam("madre_spring", m + Vector3(40, 0, 20) + Vector3(0, ground(m + Vector3(40, 0, 20)) - m.y + 2.0, 0), m + Vector3(0, 14, 0), 62.0)
	for tod in TODS:
		set_tod(tod)
		# Player chase view and the creature at strategic distance (zoom 0.8: models still on, grass and shadows off).
		for zz in [["valley_chase", 0.35], ["creature_dist", 0.8]]:
			island.chase_enabled = true
			island.chase.set_zoom(zz[1], true)
			await settle(40)
			var nm := "%s_%s_%s" % [tier, tod, zz[0]]
			var img := await grab(nm)
			img.save_jpg(out_dir.path_join(nm + ".jpg"), 0.92)
			if zz[0] == "creature_dist":
				island.hosts[0].visible = false
				await settle(6)
				await RenderingServer.frame_post_draw
				var bg := root.get_texture().get_image()
				bg.convert(Image.FORMAT_RGB8)
				island.hosts[0].visible = true
				var px := img.get_data()
				var pb := bg.get_data()
				var md := PackedByteArray()
				md.resize(img.get_width() * img.get_height())
				for i in md.size():
					var d := absi(px[i * 3] - pb[i * 3]) + absi(px[i * 3 + 1] - pb[i * 3 + 1]) + absi(px[i * 3 + 2] - pb[i * 3 + 2])
					md[i] = 255 if d > 12 else 0
				var mask := Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_L8, md)
				mask.save_png(out_dir.path_join(nm + "_mask.png"))
			print("wrote ", nm)
		island.chase_enabled = false
		for c in cams:
			island.camera.fov = c.fov
			island.camera.near = 0.03
			island.camera.position = c.pos
			island.camera.look_at(c.look)
			var nm := "%s_%s_%s" % [tier, tod, c.name]
			var img := await grab(nm)
			img.save_jpg(out_dir.path_join(nm + ".jpg"), 0.92)
			print("wrote ", nm)
	var f := FileAccess.open(out_dir.path_join("times_%s.json" % tier), FileAccess.WRITE)
	f.store_string(JSON.stringify(times, "  ", true))
	f.close()
	quit(0)
