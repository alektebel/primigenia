extends SceneTree
# Flora evidence frames (JPG, software GL under xvfb):
#   LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 --resolution 1280x720 --path godot \
#     --script res://game/tests/flora_evidence.gd -- <out dir> <quality low|medium|high> <base|volcano> [shot prefixes, comma separated]
# Cameras are found by rule from the placed instances (island.props.records), never hard-coded.

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Placement := preload("res://game/island/flora_placement.gd")

var out_dir := ""
var island: Node3D
var game
var suffix := ""
var only := PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func settle(n: int) -> void:
	for i in n:
		await process_frame

func wanted(name: String) -> bool:
	if only.is_empty():
		return true
	for o in only:
		if name.begins_with(o):
			return true
	return false

func shot(name: String, pos: Vector3, look: Vector3, fov := 55.0) -> void:
	if not wanted(name):
		return
	island.chase_enabled = false
	island.camera.fov = fov
	island.camera.near = 0.03
	pos.y = maxf(pos.y, ground(pos) + 0.5)
	island.camera.position = pos
	island.camera.look_at(look)
	await settle(8)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_jpg(out_dir.path_join(name + suffix + ".jpg"), 0.9)
	print("wrote ", name)

func ground(p: Vector3) -> float:
	return game.visual_ground(p.x, p.z)

func of(id: String) -> Array:
	var out := []
	for r in island.props.records:
		if r.id == id:
			out.append(r)
	return out

# The median-height specimen standing on gentle ground, not too close to the origin's spawn clearing.
func pick(id: String) -> Dictionary:
	var list := of(id)
	if list.is_empty():
		return {}
	list.sort_custom(func(a, b): return a.height < b.height)
	var flat := list.filter(func(r): return r.up.y > 0.93)
	if flat.is_empty():
		flat = list
	return flat[flat.size() / 2]

# The specimen with the most same-id neighbours within `radius`.
func densest(id: String, radius: float) -> Dictionary:
	var list := of(id)
	var best := {}
	var best_n := -1
	var step := maxi(1, list.size() / 400)
	for i in range(0, list.size(), step):
		var a: Dictionary = list[i]
		var n := 0
		for b in list:
			if Vector2(a.p.x - b.p.x, a.p.z - b.p.z).length() < radius:
				n += 1
		if n > best_n and a.up.y > 0.9:
			best_n = n
			best = a
	return best

func downhill(r: Dictionary) -> Vector3:
	var n: Vector3 = r.up
	var h := Vector3(n.x, 0, n.z)
	return h.normalized() if h.length() > 0.05 else Vector3(1, 0, 0)

func close_up(id: String) -> void:
	var r := pick(id)
	if r.is_empty():
		print("no ", id, " placed")
		return
	var p: Vector3 = r.p
	var patch := id in ["ceniza_roja", "costra_de_azufre", "musgo_faro", "pan_de_humus"]
	var dist: float = clampf(float(r.height) * 2.3, 1.0, 45.0) if not patch else 1.2
	if id == "soga_de_dosel":
		dist = 6.0
	var nrm: Vector3 = r.up
	var ang := atan2(nrm.z, nrm.x) if Vector2(nrm.x, nrm.z).length() > 0.05 else 0.7
	var eye := p + Vector3(cos(ang), 0, sin(ang)) * dist
	var hh: float = r.height
	var cam_h: float = (0.7 + hh * 0.45) if not patch else 0.8
	if id in ["madre_de_agua", "nieblon"]:
		cam_h = 1.7
		dist *= 1.3
		eye = p + Vector3(cos(ang), 0, sin(ang)) * dist
	eye.y = ground(eye) + cam_h
	var look: Vector3 = p + Vector3.UP * (hh * 0.45 if not patch else 0.0)
	await shot("plant_" + id, eye, look, 55.0)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/flora-evidence"
	var quality: String = args[1] if args.size() > 1 else "high"
	var mode: String = args[2] if args.size() > 2 else "base"
	if args.size() > 3:
		only = args[3].split(",", false)
	suffix = "" if quality == "high" else "-" + quality
	if mode == "volcano":
		suffix = "-volcano" + suffix
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(int(OS.get_environment("FLORA_W")) if OS.get_environment("FLORA_W") != "" else 1280, int(OS.get_environment("FLORA_H")) if OS.get_environment("FLORA_H") != "" else 720)
	game = root.get_node("Game")
	game.settings.grass = int(OS.get_environment("FLORA_GRASS")) if OS.get_environment("FLORA_GRASS") != "" else 120000
	game.settings.quality = quality
	game.settings.wild = true
	if OS.get_environment("FLORA_DENSITY") != "":
		game.settings.flora_density = float(OS.get_environment("FLORA_DENSITY"))
	var params := {"seed": 1}
	if mode == "volcano":
		params["volcano"] = 1.0
	var entry := TerrainCache.load_entry(params)
	if entry.is_empty():
		entry = TerrainCache.build(params, CporeTerrain.new())
	game.set_island(entry)
	island = load("res://game/island/island.tscn").instantiate()
	island.tree_entered.connect(func(): current_scene = island, CONNECT_ONE_SHOT)
	root.add_child(island)
	await settle(40)
	print("flora counts ", island.props.counts)
	var nest: Vector2 = island._nest
	var np := Vector3(nest.x, ground(Vector3(nest.x, 0, nest.y)), nest.y)

	if mode == "base":
		# Player view: the chase camera at three zoom levels.
		for z in [0.0, 0.35, 0.7]:
			var name := "valley_chase_z%d" % int(z * 100)
			if wanted(name):
				island.chase_enabled = true
				island.chase.set_zoom(z, true)
				await settle(40)
				await RenderingServer.frame_post_draw
				var img := root.get_texture().get_image()
				img.convert(Image.FORMAT_RGB8)
				img.save_jpg(out_dir.path_join(name + suffix + ".jpg"), 0.9)
				print("wrote ", name)
		await shot("nest_ground", np + Vector3(3.6, 0.9, 1.8), np + Vector3(0, 0.25, 0), 60.0)
		await shot("nest_high", np + Vector3(5, 3.2, 5), np, 55.0)
		await shot("valley_east", np + Vector3(-5, 2.2, 0), np + Vector3(60, 3, 12), 62.0)
		await shot("valley_west", np + Vector3(5, 2.2, 0), np + Vector3(-60, 6, -10), 62.0)
		await shot("vista_wide", np + Vector3(-300, 90, 260), np + Vector3(200, 5, -80), 62.0)
		await shot("vista_island", Vector3(0, 700, 1900), Vector3(0, 120, 0), 55.0)
		# Tier comparison: the same valley frame.
		await shot("tier_valley", np + Vector3(-12, 2.2, 12), np + Vector3(40, 1.5, -10), 62.0)
		# Western fog forest: the densest nieblon group from its edge and from the floor.
		var grove := densest("nieblon", 40.0)
		if not grove.is_empty():
			var g: Vector3 = grove.p
			var from := g + Vector3(34, 0, -26)
			await shot("forest_edge", Vector3(from.x, ground(from) + 2.0, from.z), g + Vector3(0, 9, 0), 62.0)
			var inside := g + Vector3(8, 0, 5)
			await shot("forest_floor", Vector3(inside.x, ground(inside) + 1.7, inside.z), g + Vector3(-10, 8, -6), 70.0)
			var from2 := g + Vector3(75, 0, 60)
			await shot("tier_forest", Vector3(from2.x, ground(from2) + 4.0, from2.z), g + Vector3(0, 8, 0), 55.0)
		var madre := pick("madre_de_agua")
		if not madre.is_empty():
			var m: Vector3 = madre.p
			await shot("madre_spring", m + Vector3(40, 0, 20) + Vector3(0, ground(m + Vector3(40, 0, 20)) - m.y + 2.0, 0), m + Vector3(0, 14, 0), 62.0)
			await shot("madre_base", m + Vector3(12, 0, 8) + Vector3(0, ground(m + Vector3(12, 0, 8)) - m.y + 1.7, 0), m + Vector3(0, 6, 0), 70.0)
		var rod := densest("rodela_de_nieve", 30.0)
		if not rod.is_empty():
			var r: Vector3 = rod.p
			var e := r + downhill(rod) * 7.0
			await shot("snow_rosettes", Vector3(e.x, ground(e) + 1.6, e.z), r + Vector3(0, 1.2, 0), 62.0)
			var e2 := r + downhill(rod) * 35.0
			await shot("snow_slope", Vector3(e2.x, ground(e2) + 8.0, e2.z), r, 62.0)
		var rib := densest("trenza_de_ribera", 25.0)
		if not rib.is_empty():
			var r: Vector3 = rib.p
			var e := r + Vector3(12, 0, 9)
			await shot("riverbank", Vector3(e.x, ground(e) + 2.0, e.z), r + Vector3(0, 1.2, 0), 62.0)
		var coast := densest("salvisca", 30.0)
		if not coast.is_empty():
			var r: Vector3 = coast.p
			var e := r + Vector3(10, 0, 8)
			await shot("coast_spray", Vector3(e.x, ground(e) + 1.6, e.z), r, 62.0)
		var tide := densest("cinta_de_marea", 20.0)
		if not tide.is_empty():
			var r: Vector3 = tide.p
			var e := r + Vector3(4, 0, 3)
			await shot("coast_tide", Vector3(e.x, maxf(ground(e), -0.2) + 1.4, e.z), r, 62.0)
	else:
		var lava := densest("grama_de_ceniza", 30.0)
		if not lava.is_empty():
			var l: Vector3 = lava.p
			var e := l + downhill(lava) * 4.0
			await shot("lava_tussock", Vector3(e.x, ground(e) + 1.2, e.z), l + Vector3.UP * 0.2, 62.0)
			var e2 := l + Vector3(60, 0, 45)
			await shot("lava_wide", Vector3(e2.x, ground(e2) + 14, e2.z), l, 60.0)
		var crust := densest("ceniza_roja", 20.0)
		if not crust.is_empty():
			var c: Vector3 = crust.p
			var e := c + downhill(crust) * 1.8
			await shot("lava_crust", Vector3(e.x, ground(e) + 0.8, e.z), c, 62.0)
		var tongue := densest("lengua_de_lava", 30.0)
		if not tongue.is_empty():
			var c: Vector3 = tongue.p
			var e := c + downhill(tongue) * 1.6
			await shot("lava_tongue", Vector3(e.x, ground(e) + 0.7, e.z), c, 62.0)
		var meteor := densest("hierroflor", 30.0)
		if not meteor.is_empty():
			var c: Vector3 = meteor.p
			var e := c + downhill(meteor) * 2.4
			await shot("meteor_plants", Vector3(e.x, ground(e) + 0.9, e.z), c, 62.0)
	for id in ["ceniza_roja","cinta_de_marea","costra_de_azufre","grama_de_ceniza","hierroflor","lengua_de_lava","madre_de_agua","musgo_faro","nieblon","paja_dulce","pan_de_humus","pluma_de_sombra","rodela_de_nieve","salvisca","soga_de_dosel","trenza_de_ribera","perlilla","velilla","caramillo","vetirroja"]:
		await close_up(id)
	quit(0)
