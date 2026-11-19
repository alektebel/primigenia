extends SceneTree
# Evidence for the diegetic UI (docs/godot/PLAN-ui-diegetic.md): the mockup states on the real island, JPG quality 88.
#   make godot-ui-diegetic-evidence                    (software GL under xvfb)
#   ... --script res://tests/ui_diegetic_evidence.gd -- <out dir> [scenes] [weather]
# scenes: comma list of move_marker, idle, selected, befriend, combat, carcass, low_health, menu, loadout, minimap, es, dawn, evening
# (default all). weather: dawn | midday | evening (default midday).

const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Modes := preload("res://ui/modes.gd")

var out_dir := ""
var game
var island: Node3D
var sui
var ui
var stage
var jpg_quality := 0.88
var weather_name := "midday"
const Strings := preload("res://ui/strings.gd")

func _initialize() -> void:
	_run.call_deferred()

func settle(frames: int) -> void:
	for i in frames:
		await process_frame

func ticks(n: int) -> void:
	var t0: int = stage.cur.tick
	var guard := 0
	while stage.cur.tick - t0 < n and guard < 20000:
		await process_frame
		guard += 1

func grab() -> Image:
	await settle(4)
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	return img

func shot(name: String) -> Image:
	if weather_name != "midday":
		name += "_" + weather_name        # dawn and evening variants sit next to the midday captures
	var img := await grab()
	img.save_jpg(out_dir.path_join(name + ".jpg"), jpg_quality)
	print("wrote ", name)
	return img

static func crop(img: Image, centre: Vector2, size: Vector2i) -> Image:
	var r := Rect2i(Vector2i(centre) - size / 2, size)
	r.position.x = clampi(r.position.x, 0, img.get_width() - size.x)
	r.position.y = clampi(r.position.y, 0, img.get_height() - size.y)
	return img.get_region(r)

static func strip(images: Array, tile: Vector2i) -> Image:
	var sheet := Image.create(tile.x * images.size(), tile.y, false, Image.FORMAT_RGB8)
	for k in images.size():
		var im: Image = images[k]
		if im.get_size() != tile:
			im.resize(tile.x, tile.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(Vector2i.ZERO, tile), Vector2i(k * tile.x, 0))
	return sheet

func key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = true
	return e

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp/ui-diegetic"
	var scenes: PackedStringArray = (args[1] if args.size() > 1 and args[1] != "" else "move_marker").split(",")
	var weather: String = args[2] if args.size() > 2 else "midday"
	weather_name = weather
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.grass = 20000
	game.settings.weather = weather
	game.settings["language"] = "en"
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	game.goto_island()
	for i in 900:
		await process_frame
		if game.stage != null and current_scene != null and current_scene.get("stage_ui") != null:
			break
	await settle(30)
	island = current_scene
	sui = island.stage_ui
	ui = sui.ui
	stage = game.stage
	if stage.cur.entities.size() > 1:
		stage.debug_now({"op": 6, "a": 2})        # freeze the wild: the shots are about the marks
	await relocate_player()
	for s in scenes:
		if has_method("scene_" + s):
			await call("scene_" + s)
		else:
			printerr("unknown scene ", s)
	quit()

# --- scenes ------------------------------------------------------------------------------------------------------

func ground_point_ahead(dist: float, side: float = 0.0) -> Vector3:
	var pp: Vector3 = island.player_pos
	var yaw: float = island.chase.view_yaw if island.chase != null else 0.0
	var f := Vector3(-sin(yaw), 0, -cos(yaw))
	var r := Vector3(f.z, 0, -f.x)
	var q := pp + f * dist + r * side
	q.y = game.ground(q.x, q.z)
	return q

func scene_move_marker() -> void:
	thaw()
	ui.onboarding.enabled = false
	var gm = island.ground_marks
	var frames := []
	var click_at := Vector2(850, 430)
	island._click_ground(false, click_at)
	var goal: Vector3 = gm.destination()
	await ticks(1)
	frames.append(crop(await grab(), click_at, Vector2i(420, 300)))
	await ticks(8)
	var s2: Vector2 = island.camera.unproject_position(goal)
	frames.append(crop(await grab(), s2, Vector2i(420, 300)))
	var guard := 0
	while Vector2(island.player_pos.x - goal.x, island.player_pos.z - goal.z).length() > 3.0 and guard < 60:
		await ticks(2)
		guard += 1
	var s3: Vector2 = island.camera.unproject_position(goal)
	frames.append(crop(await grab(), s3, Vector2i(420, 300)))
	await ticks(8)
	# hold to follow
	var s4 := Vector2(520, 470)
	island._click_ground(false, s4, true)
	await settle(10)
	frames.append(crop(await grab(), s4, Vector2i(420, 300)))
	island.ground_marks.follow_release()
	island.player_input.clear_destination()
	await settle(4)
	var blocked_pt = find_blocked()
	if blocked_pt != null:
		var s5: Vector2 = island.camera.unproject_position(blocked_pt)
		gm.move_blocked(blocked_pt)
		await settle(6)
		frames.append(crop(await grab(), s5, Vector2i(420, 300)))
	var sheet := strip(frames, Vector2i(420, 300))
	sheet.save_jpg(out_dir.path_join("move_marker.jpg"), jpg_quality)
	print("wrote move_marker")

func find_blocked() -> Variant:
	var pp: Vector3 = island.player_pos
	for r in [10.0, 16.0, 24.0, 36.0, 50.0, 70.0, 90.0]:
		for a in 36:
			var q: Vector3 = pp + Vector3(cos(a * 10.0 * PI / 180.0), 0, sin(a * 10.0 * PI / 180.0)) * float(r)
			q.y = game.ground(q.x, q.z)
			if island.walk_blocked(q) and not island.camera.is_position_behind(q):
				var s: Vector2 = island.camera.unproject_position(q)
				if s.x > 260 and s.x < 1000 and s.y > 260 and s.y < 640:
					return q
	return null

# A creature of species `sp` placed `dist` m ahead of the player along the camera's view, `side` m to the right.
func creature_ahead(sp: int, dist: float, side: float = 0.0, nth: int = 0) -> int:
	var id := -1
	var n := 0
	for i in range(1, stage.cur.entities.size()):
		if int(stage.cur.entities[i].species) == sp and not bool(stage.cur.entities[i].dead):
			if n == nth:
				id = i
				break
			n += 1
	var fwd: Vector3 = -island.camera.global_transform.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var rgt := Vector3(-fwd.z, 0, fwd.x)
	var p: Vector3 = island.player_pos + fwd * dist + rgt * side
	stage.debug_now({"op": 1, "id": id, "x": p.x, "z": p.z})
	return id

func face_player(id: int) -> void:
	pass

func freeze() -> void:
	stage.process_mode = Node.PROCESS_MODE_DISABLED

func thaw() -> void:
	stage.process_mode = Node.PROCESS_MODE_INHERIT

func scene_idle() -> void:
	thaw()
	ui.onboarding.enabled = false
	var screen := Vector2(850, 430)
	island._click_ground(false, screen)
	await settle(8)
	print("move marker at ", island.ground_marks.destination(), " visible ", island.ground_marks.move_visible())
	await shot("idle")
	island.player_input.clear_destination()

func scene_selected() -> void:
	thaw()
	var rondo := creature_ahead(0, 7.0, 4.5)
	await ticks(4)
	freeze()
	await settle(10)
	ui.onboarding.enabled = false
	ui.selections = 10                  # beyond the first three: the names show on hover only
	sui.select_id(rondo)
	await settle(2)
	ui.ring.hover = 3
	await settle(14)
	await shot("selected_ring")
	# Spanish, every name, and the onboarding hint (the first three selections show every name)
	ui.onboarding.enabled = true
	ui.onboarding.done_mask = 0b111
	ui.selections = 1
	ui.ring.hover = -1
	game.settings["language"] = "es"
	await settle(16)
	await shot("selected_ring_es_names")
	game.settings["language"] = "en"
	ui.onboarding.enabled = false
	ui.selections = 10
	ui.clear_selection()
	thaw()

func scene_befriend() -> void:
	thaw()
	var rondo := creature_ahead(0, 5.5, 4.0)
	await ticks(4)
	ui.onboarding.enabled = false
	ui.selections = 10
	sui.select_id(rondo)
	await settle(3)
	ui.ring.choose_mode(&"befriend")
	await settle(3)
	ui._unhandled_input(key_event(KEY_1))
	await ticks(20)
	# wait for the beat window so the ring is thick and the closing ring touches it
	var guard := 0
	while not island.ground_marks.in_window(int(stage.cur.entities[rondo].beat_in)) and guard < 60:
		await process_frame
		guard += 1
	island.ground_marks.set_pearls(3)
	freeze()
	await settle(10)
	await shot("befriend_rhythm")
	thaw()
	ui.clear_selection()

func scene_combat() -> void:
	thaw()
	ui.onboarding.enabled = false
	var gar := 1
	var fwd: Vector3 = -island.camera.global_transform.basis.z
	fwd.y = 0.0
	var p: Vector3 = island.player_pos + fwd.normalized() * 6.5 + Vector3(4.5, 0, 0)
	var rc: int = stage.debug_now({"op": 1, "id": gar, "x": p.x, "z": p.z})
	await ticks(3)
	freeze()
	await settle(6)
	print("combat: placed Garfio rc=", rc, " at ", Vector2(stage.cur.entities[gar].x, stage.cur.entities[gar].z), " player at ", island.player_pos, " wanted ", p)
	print("combat: screen garfio ", island.camera.unproject_position(island.hosts[gar].global_position), " player ", island.camera.unproject_position(island.hosts[0].global_position))
	var inf: Dictionary = sui.info_for(gar)
	inf["fight"] = true
	ui.select(inf, false)
	ui.set_fight(true)
	ui.set_loadout_abilities([
		{"id": "bite", "name": "Bite", "move": 0, "role": "basic", "stamina": 9, "cooldown": 8},
		{"id": "charge", "name": "Charge", "move": 1, "role": "engage", "stamina": 18, "cooldown": 6},
		{"id": "spit", "name": "Spit", "move": 3, "role": "poke", "stamina": 12, "cooldown": 20},
		{"id": "tail_strike", "name": "Tail", "move": 4, "role": "control", "stamina": 10, "cooldown": 15}])
	ui.set_cooldowns([0.0, 0.6, 0.0, 0.0])
	ui.set_player("Merodeador", 72, 100, 31, 50)
	island.ground_marks.set_value(0.62)
	island.ground_marks.value_target = 0.62
	island.ground_marks.set_windup(0.55)
	await settle(18)
	await shot("combat")
	island.ground_marks.set_windup(-1.0)
	ui.set_fight(false)
	ui.clear_selection()
	thaw()

func scene_carcass() -> void:
	thaw()
	var victim := creature_ahead(0, 6.0, 4.0, 1)
	stage.debug_now({"op": 3, "id": victim})
	await ticks(4)
	freeze()
	await settle(4)
	ui.onboarding.enabled = false
	ui.selections = 10
	sui.select_id(victim)
	await settle(2)
	ui.ring.hover = 1
	await settle(10)
	await shot("carcass_ring")
	ui.ring.choose_mode(&"eat")
	island.ground_marks.set_segments(4, 3)
	ui.set_meters(9, 7, 1, 4, 58, 100)
	ui.show_dna(3, "carcass", island.hosts[victim].global_position + Vector3(0, 0.5, 0))
	await settle(5)
	await shot("carcass_eat")
	ui.clear_selection()
	thaw()

func scene_low_health() -> void:
	thaw()
	ui.onboarding.enabled = false
	var gar := 1
	var fwd: Vector3 = -island.camera.global_transform.basis.z
	fwd.y = 0.0
	var p: Vector3 = island.player_pos + fwd.normalized() * 12.0 + Vector3(-7, 0, 0)
	stage.debug_now({"op": 1, "id": gar, "x": p.x, "z": p.z})
	await ticks(3)
	freeze()
	island.ground_marks.set_threats([gar])
	ui.set_player("Merodeador", 17, 100, 44, 50)
	ui.set_fight(true)
	await settle(25)
	await shot("low_health")
	island.ground_marks.set_threats([])
	ui.set_fight(false)
	ui.set_player("Merodeador", 100, 100, 50, 50)
	thaw()

func scene_menu() -> void:
	ui.set_paused(true)
	await settle(20)
	await shot("menu")
	ui.menu.column = 1
	ui.menu.focus = ui.menu.item_ids().find("settings")
	game.settings["language"] = "es"
	await settle(14)
	await shot("menu_settings_es")
	game.settings["language"] = "en"
	ui.set_paused(false)

func scene_keys() -> void:
	var dev = root.get_node("Dev")
	dev.legend.pin_sheet(true)
	await settle(14)
	await shot("keys_sheet")
	dev.legend.pin_sheet(false)


# A flat meadow near the nest with no water around, so the shots are about the marks and not about a river.
func find_meadow() -> Vector3:
	var d = game.data
	var nest: Vector2 = island._nest
	var best := Vector3.INF
	var best_score := 1e9
	for r in range(25, 160, 10):
		for a in 36:
			var x: float = nest.x + cos(a * 10.0 * PI / 180.0) * float(r)
			var z: float = nest.y + sin(a * 10.0 * PI / 180.0) * float(r)
			var ok := true
			var worst_n := 1.0
			for dx in range(-24, 25, 6):
				for dz in range(-24, 25, 6):
					var k: int = d.cell_index(x + dx, z + dz)
					if d.river_class(k) > 0 or d.is_pond(k) or d.is_sea(k):
						ok = false
					worst_n = minf(worst_n, d.normal(x + dx, z + dz).y)
			if ok and worst_n > 0.985 and d.ground(x, z) > 4.0:
				var score := float(r) + (1.0 - worst_n) * 400.0
				if score < best_score:
					best_score = score
					best = Vector3(x, 0, z)
	return best

func relocate_player() -> void:
	var m := find_meadow()
	print("meadow ", m)
	if m == Vector3.INF:
		return
	stage.debug_now({"op": 1, "id": 0, "x": m.x, "z": m.z})
	await ticks(4)
	island.chase.reset_behind()
	await settle(30)

func scene_loadout() -> void:
	freeze()                           # the world keeps ticking otherwise and the sheet closes (you are not at the nest)
	var moves: Array = CporeWorld.moves()
	ui.loadout_panel.setup(moves)
	var lo: Dictionary = stage.cur.loadout.duplicate(true)
	lo["can_edit"] = true
	lo["known"] = 0b1011
	lo["slots"] = [0, 1, 3, -1]
	ui.loadout_panel.refresh(lo)
	ui.loadout_panel.focus = 1
	ui.loadout_panel.open_panel()
	await settle(22)
	await shot("loadout")
	ui.loadout_panel.close_panel()
	await settle(10)
	thaw()

func scene_minimap() -> void:
	thaw()
	var d = game.data
	var best := Vector3.INF
	var best_d := 1e9
	for j in range(2, d.n - 2, 2):
		for i in range(2, d.n - 2, 2):
			var h: float = d.height[j * d.n + i]
			if h > 2.0 and h < 6.0 and d.height[j * d.n + i - 2] <= 0.0 and d.river_class(j * d.n + i) == 0:
				var x: float = d.cell_center(i)
				var z: float = d.cell_center(j)
				var dd: float = Vector2(x, z).distance_to(island._nest)
				if dd < best_d:
					best_d = dd
					best = Vector3(x + 6.0, 0, z)
	if best == Vector3.INF:
		return
	stage.debug_now({"op": 1, "id": 0, "x": best.x, "z": best.z})
	await ticks(6)
	island.chase.reset_behind()
	await settle(30)
	var rondo := creature_ahead(0, 14.0, 3.0)
	await ticks(2)
	sui.select_id(rondo)
	await settle(30)
	var img := await shot("minimap_coast")
	var crop_img := img.get_region(Rect2i(1060, 6, 220, 220))
	crop_img.resize(660, 660, Image.INTERPOLATE_LANCZOS)
	crop_img.save_jpg(out_dir.path_join("minimap.jpg"), jpg_quality)
	ui.clear_selection()
	await relocate_player()

# The side-by-side sheet: for each state the mockup (left) and the game (right), 640 x 360 each, rows in the mockups' order.
# Needs the captures of the other scenes in out_dir.
func scene_sheet() -> void:
	var pairs := [["01-idle", "idle"], ["02-selected-radial", "selected_ring"], ["02b-selected-radial-es", "selected_ring_es_names"],
		["03-befriend-rhythm", "befriend_rhythm"], ["04-combat", "combat"], ["05-carcass-eat", "carcass_eat"],
		["06-low-health", "low_health"], ["07-menu", "menu"], ["08-loadout", "loadout"]]
	var mock_dir := ProjectSettings.globalize_path("res://").path_join("../docs/godot/ui-mockups/render").simplify_path()
	var tile := Vector2i(640, 360)
	var sheet := Image.create(tile.x * 2, tile.y * pairs.size(), false, Image.FORMAT_RGB8)
	for r in pairs.size():
		for c in 2:
			var path: String = mock_dir.path_join(pairs[r][0] + ".jpg") if c == 0 else out_dir.path_join(pairs[r][1] + ".jpg")
			var im := Image.load_from_file(path)
			if im == null or im.is_empty():
				printerr("sheet: missing ", path)
				continue
			im.convert(Image.FORMAT_RGB8)
			im.resize(tile.x, tile.y, Image.INTERPOLATE_LANCZOS)
			sheet.blit_rect(im, Rect2i(Vector2i.ZERO, tile), Vector2i(c * tile.x, r * tile.y))
	sheet.save_jpg(out_dir.path_join("sheet.jpg"), jpg_quality)
	print("wrote sheet")
