extends SceneTree
# Regenerates the curated scenarios in godot/scenarios/creature/ (run after an engine or terrain change):
#   godot --headless --path godot --script res://devtools/tools/make_scenarios.gd
# Each is built by a session from reset (setup + debug ops) on the seed-1 island, so it keeps its recipe.

const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Profile := preload("res://game/stage/profile.gd")
const Scenario := preload("res://devtools/scenario.gd")
const RockViews := preload("res://game/tests/rock_views.gd")

const OUT := "res://scenarios/creature"
const RADIUS := 0.6
const DBG_CLOCK := 5

func _initialize() -> void:
	_run.call_deferred()

func _slope_deg(data, x: float, z: float) -> float:
	var n: Vector3 = data.normal(x, z)
	return rad_to_deg(acos(clampf(n.y, -1.0, 1.0)))

func _session(entry: Dictionary, data, with_wild: bool, genome_path := "res://game/data/merodeador.json") -> Dictionary:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome := Profile.load_json(genome_path)
	var player: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	sw.world.reset({"terrain": 2})
	var setup: Dictionary = StageSetup.build(data, 1, player, garfio, with_wild, sw.world)
	sw.reset(setup)
	sw.input_provider = func() -> Dictionary: return {}
	var ctx := {"genome": genome, "island": {"seed": 1, "terrain_version": CporeTerrain.version(), "terrain_hash": entry.hash}, "camera": {}}
	return {"sw": sw, "ctx": ctx}

func _save(s: Dictionary, name: String, note: String) -> void:
	var err := Scenario.save(s.sw, s.ctx, "%s/%s" % [OUT, name], "scenario", note)
	print("%s: %s (tick %d)" % [name, "ok" if err == "" else err, int(s.sw.cur.tick)])
	if err != "":
		quit(1)

func _tp(sw, x: float, z: float) -> int:
	return sw.debug_now({"op": 1, "id": 0, "x": x, "z": z})

func _heal_entity(sw, id: int, hp: float) -> int:
	return sw.debug_now({"op": 4, "id": id, "x": hp, "z": -1.0})

func _clock_tick(h: int, m: int) -> int:
	return int((h * 60 + m) * 12000.0 / 1440.0)

func _far_meadow_spot(data) -> Variant:
	for r in range(500, 1200, 20):
		for k in 24:
			var ang := k * TAU / 24.0
			var x := sin(ang) * r
			var z := cos(ang) * r
			if StageSetup.dry(data, x, z) and _slope_deg(data, x, z) > 18.0 and _slope_deg(data, x, z) < 32.0 and StageSetup.dry(data, x + 6, z) and _slope_deg(data, x + 6, z) < 38.0:
				return Vector2(x, z)
	return null

func _dry_stand(data, world: CporeWorld, x: float, z: float) -> bool:
	return StageSetup.dry(data, x, z) and absf(x) < 1700.0 and absf(z) < 1700.0 and data.normal(x, z).y > 0.85 and world.can_walk(x, z, x + 1.0, z, RADIUS)

func _try_go_plan(sw, player: Vector2, target: Vector2) -> Dictionary:
	if _tp(sw, player.x, player.y) != 0:
		return {}
	sw.world.nav_warm()
	sw.queue_order({"verb": 2, "x": target.x, "z": target.y, "sprint": 0})
	sw.step_once()
	var st: Dictionary = sw.cur
	if int(st.order.verb) != 2:
		return {}
	var path: PackedVector2Array = sw.world.path()
	if path.size() < 2:
		return {}
	var pts: Array = []
	for p in path:
		pts.append(p)
	return {"player": player, "target": target, "path_len": path.size(), "path_m": _path_length(pts, player)}

func _path_length(pts: Array, start: Vector2) -> float:
	var d := start.distance_to(pts[0])
	for i in range(1, pts.size()):
		d += pts[i - 1].distance_to(pts[i])
	return d

func _consider_cliff_pair(entry, data, world: CporeWorld, px: float, pz: float, tx: float, tz: float, best: Dictionary) -> Dictionary:
	if not _dry_stand(data, world, px, pz) or not _dry_stand(data, world, tx, tz):
		return best
	if world.can_walk(px, pz, tx, tz, RADIUS):
		return best
	var probe := _session(entry, data, false)
	var res := _try_go_plan(probe.sw, Vector2(px, pz), Vector2(tx, tz))
	if res.is_empty() or res.path_m < 25.0:
		return best
	if res.path_m > best.get("path_m", 0.0):
		print("  cliff candidate detour %.0f m, %d waypoints" % [res.path_m, res.path_len])
		return res
	return best

func _find_cliff_crossing(data, entry) -> Dictionary:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome := Profile.load_json("res://game/data/merodeador.json")
	var player_prof: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	var sw = StageWorld.new()
	sw.world.set_field(entry)
	var setup: Dictionary = StageSetup.build(data, 1, player_prof, garfio, false, sw.world)
	sw.reset(setup)
	var world: CporeWorld = sw.world
	var best: Dictionary = {}
	for lit in [true, false]:
		var cliff: Dictionary = RockViews.find_cliff(data, lit)
		if cliff.is_empty():
			continue
		var face := Vector2(cliff.nx, cliff.nz).normalized()
		var lateral := Vector2(-face.y, face.x)
		for back in [18.0, 30.0, 45.0]:
			var px: float = cliff.x - face.x * back
			var pz: float = cliff.z - face.y * back
			for side in [-35.0, -15.0, 0.0, 15.0, 35.0]:
				px = cliff.x - face.x * back + lateral.x * side
				pz = cliff.z - face.y * back + lateral.y * side
				for fwd in [25.0, 45.0, 70.0]:
					var tx: float = cliff.x + face.x * fwd + lateral.x * side * 0.6
					var tz: float = cliff.z + face.y * fwd + lateral.y * side * 0.6
					best = _consider_cliff_pair(entry, data, world, px, pz, tx, tz, best)
	for r in range(300, 900, 40):
		for k in 24:
			var ang := k * TAU / 24.0
			var px: float = sin(ang) * r
			var pz: float = cos(ang) * r
			for dist in [50.0, 80.0]:
				var tx: float = px + sin(ang + 0.4) * dist
				var tz: float = pz + cos(ang + 0.4) * dist
				best = _consider_cliff_pair(entry, data, world, px, pz, tx, tz, best)
	return best

func _find_water_edge(data, entry) -> Dictionary:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome := Profile.load_json("res://game/data/merodeador.json")
	var player_prof: Dictionary = Profile.from_studio(genome, manifest).profile
	var garfio: Dictionary = StageSetup.garfio_profile(manifest)
	for r in range(80, 1400, 20):
		for k in 48:
			var ang := k * TAU / 48.0
			var px := sin(ang) * r
			var pz := cos(ang) * r
			if not StageSetup.dry(data, px, pz):
				continue
			for dist in [18.0, 28.0, 40.0, 55.0]:
				var tx: float = px + sin(ang) * dist
				var tz: float = pz + cos(ang) * dist
				var mid := Vector2((px + tx) * 0.5, (pz + tz) * 0.5)
				var sw0 = StageWorld.new()
				sw0.world.set_field(entry)
				var setup: Dictionary = StageSetup.build(data, 1, player_prof, garfio, false, sw0.world)
				sw0.reset(setup)
				if sw0.world.water_depth(mid.x, mid.y) < 0.45:
					continue
				if sw0.world.can_walk(px, pz, tx, tz, RADIUS):
					continue
				var s := _session(entry, data, false)
				if _tp(s.sw, px, pz) != 0:
					continue
				s.sw.world.nav_warm()
				s.sw.queue_order({"verb": 2, "x": tx, "z": tz, "sprint": 0})
				s.sw.step_once()
				if int(s.sw.cur.order.verb) == 2:
					continue
				if int(s.sw.cur.error) == -4:
					print("  water_edge at %.0f,%.0f -> %.0f,%.0f" % [px, pz, tx, tz])
					return {"session": s, "player": Vector2(px, pz), "target": Vector2(tx, tz)}
	return {}

func _near_garfio(s: Dictionary) -> Vector2:
	var w: Dictionary = s.sw.cur.entities[1]
	var toward := (Vector2(0, 0) - Vector2(w.x, w.z)).normalized()
	return Vector2(w.x, w.z) + toward * 8.0

func _spawn_ring(sw, species: int, count: int) -> int:
	var p: Dictionary = sw.cur.entities[0]
	var f := Vector2(p.fx, p.fz).normalized()
	if f.length_squared() < 0.01:
		f = Vector2(0, 1)
	var perp := Vector2(-f.y, f.x)
	var made := 0
	for i in count:
		var k := (i + 1) / 2
		var off := 8.0 * k * (1.0 if i % 2 == 0 else -1.0)
		var ahead := 10.0 + k * 4.0
		var pos := Vector2(p.x, p.z) + f * ahead + perp * off
		if sw.debug_now({"op": 2, "a": species, "x": pos.x, "z": pos.y}) == 0:
			made += 1
	return made

# The flight test scenario: the light winged test creature (game/data/flyer.json) standing on a plateau a few metres behind a cliff
# edge, facing out over a drop of 30 m or more, no wild creatures. Space takes off (dev builds), see docs/godot/WINGS-FLIGHT.md.
func _flight_cliff(entry, data) -> bool:
	var best := {}
	for lit in [true, false]:
		var cliff: Dictionary = RockViews.find_cliff(data, lit)
		if cliff.is_empty():
			continue
		var face := Vector2(cliff.nx, cliff.nz).normalized()
		var lateral := Vector2(-face.y, face.x)
		for side in [0.0, 12.0, -12.0, 25.0, -25.0]:
			var base: Vector2 = Vector2(cliff.x, cliff.z) + lateral * side
			# walk uphill (against the face normal) until the ground is flat again: that is the plateau
			for back in range(2, 60, 2):
				var p: Vector2 = base - face * float(back)
				var n: Vector3 = data.normal(p.x, p.y)
				if n.y > 0.93 and data.ground(p.x, p.y) > data.ground(cliff.x, cliff.z) + 4.0:
					var stand: Vector2 = p - face * 4.0
					var drop: float = data.ground(stand.x, stand.y) - data.ground(stand.x + face.x * 40.0, stand.y + face.y * 40.0)
					if drop > best.get("drop", 0.0) and StageSetup.dry(data, stand.x, stand.y) and data.normal(stand.x, stand.y).y > 0.93:
						best = {"stand": stand, "face": face, "drop": drop}
					break
	if best.is_empty():
		printerr("flight_cliff: no plateau behind a cliff edge found")
		return false
	var f := _session(entry, data, false, "res://game/data/flyer.json")
	var stand: Vector2 = best.stand
	if _tp(f.sw, stand.x, stand.y) != 0:
		printerr("flight_cliff: the stand spot was refused")
		return false
	f.sw.world.nav_warm()
	var edge: Vector2 = stand + (best.face as Vector2) * 5.0
	f.sw.queue_order({"verb": 2, "x": edge.x, "z": edge.y, "sprint": 0})       # walk towards the edge so the creature faces the drop
	for i in 90:
		f.sw.step_once()
	f.sw.input_provider = func() -> Dictionary: return {"verb": 1}
	for i in 12:
		f.sw.step_once()
	_save(f, "flight_cliff", "The light winged test creature (Planeador) on a plateau %.0f m above the valley, facing the drop. Space takes off, then Space flap, Ctrl dive, W/S pitch, A/D turn; F3 tuning has flight/lift_mul." % best.drop)
	return true

func _run() -> void:
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		var p: Dictionary = CporeTerrain.defaults()
		p.seed = 1
		entry = CporeTerrain.new().generate(p)
		TerrainData.prepare(entry)
	var data = TerrainData.new()
	data.setup(entry, false)
	if "--only-flight" in OS.get_cmdline_user_args():
		quit(0 if _flight_cliff(entry, data) else 1)
		return
	# 1. the start of a game
	var a := _session(entry, data, true)
	_save(a, "nest_start", "The start of a game: at the nest, Garfio at its home 60 m away.")
	# 2. 8 m from Garfio, not fighting
	var b := _session(entry, data, true)
	var spot := _near_garfio(b)
	if _tp(b.sw, spot.x, spot.y) != 0:
		printerr("teleport rejected")
		quit(1)
		return
	_save(b, "garfio_close", "The player is 8 m from Garfio, not fighting yet. Good for the first exchange and for combat tuning.")
	# 3. a slope far from the valley
	var c := _session(entry, data, false)
	var found = _far_meadow_spot(data)
	if found == null:
		printerr("no far slope found")
		quit(1)
		return
	_tp(c.sw, found.x, found.y)
	_save(c, "far_meadow", "A slope about %d m from the nest, no creatures near: to look at the island heights and the camera on slopes." % int(found.length()))
	# 4. cliff detour GO
	print("== cliff_crossing")
	var cliff := _find_cliff_crossing(data, entry)
	if cliff.is_empty():
		printerr("no cliff_crossing pair found")
		quit(1)
		return
	var d := _session(entry, data, false)
	var go_cliff := _try_go_plan(d.sw, cliff.player, cliff.target)
	if go_cliff.is_empty():
		printerr("cliff_crossing GO failed to plan")
		quit(1)
		return
	_save(d, "cliff_crossing", "Below a cliff with a GO target on the rim (~%.0f m detour, %d waypoints): path overlay and A* routing." % [cliff.path_m, cliff.path_len])
	# 5. unreachable across shallow water
	print("== water_edge")
	var wet := _find_water_edge(data, entry)
	if wet.is_empty():
		printerr("no water_edge pair found")
		quit(1)
		return
	_save(wet.session, "water_edge", "On the shore with a GO order to unreachable dry ground across shallow water: snap, unreachable and blocked readouts.")
	# 6. Garfio low hp
	var e := _session(entry, data, true)
	if _tp(e.sw, _near_garfio(e).x, _near_garfio(e).y) != 0:
		quit(1)
	if _heal_entity(e.sw, 1, 18.0) != 0:
		printerr("heal garfio failed")
		quit(1)
	_save(e, "garfio_low_hp", "Garfio at about 20 %% hp, player full: finishers, kill events and combat end.")
	# 7. player low hp
	var f := _session(entry, data, true)
	if _tp(f.sw, _near_garfio(f).x, _near_garfio(f).y) != 0:
		quit(1)
	if _heal_entity(f.sw, 0, 15.0) != 0:
		quit(1)
	_save(f, "player_low_hp", "Player at about 15 %% hp beside Garfio: flee, death and respawn.")
	# 8. dusk at the far meadow
	var meadow: Vector2 = _far_meadow_spot(data)
	var g := _session(entry, data, false)
	_tp(g.sw, meadow.x, meadow.y)
	if g.sw.debug_now({"op": DBG_CLOCK, "a": _clock_tick(19, 30)}) != 0:
		quit(1)
	_save(g, "dusk_meadow", "The far meadow slope at 19:30: lighting and time-of-day on heights.")
	# 9. crowd around the nest
	var h := _session(entry, data, false)
	var nspawn := _spawn_ring(h.sw, 3, 5)
	if nspawn < 4:
		printerr("crowd: only spawned %d" % nspawn)
		quit(1)
	_save(h, "crowd", "%d Garfios around the player at the nest: UI icons, nameplates and camera readability." % nspawn)
	quit(0)