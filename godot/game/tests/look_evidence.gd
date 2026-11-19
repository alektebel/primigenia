extends SceneTree
# Terrain look frames (terrain/look-hydro): godot --path godot --rendering-driver opengl3 --script res://game/tests/look_evidence.gd -- <out dir> [views] [tod]
# Viewpoints are found by rule on seed 1 so BEFORE/AFTER frames share cameras. tod = optional hour (0..24) for the sun/clouds.
const TerrainCache := preload("res://game/island/terrain_cache.gd")
const Views := preload("res://game/tests/rock_views.gd")
const ALL := ["cliff_lit", "cliff_shade", "ridge", "scree", "valley", "coast", "far", "river"]
const CLOSE := ["close_gully", "close_scree", "close_cliff", "close_bank", "close_cave"]   # terrain v5 close-ups (a person-height camera)
const Rivers := preload("res://game/island/rivers.gd")
const Clouds := preload("res://game/island/clouds.gd")

# {pos, look} for a look view.
static func camera_for(td, v: String) -> Dictionary:
	match v:
		"cliff_lit", "cliff_shade", "mid":
			return Views.camera_for(td, v)
		"ridge":
			var p := Views.highest(td)
			return {"pos": Vector3(p.x + 140.0, p.h - 20.0, p.z + 160.0), "look": Vector3(p.x, p.h - 30.0, p.z)}
		"scree":
			var best := {}
			var br := 1e30
			for j in range(2, td.n - 2, 2):
				for i in range(2, td.n - 2, 2):
					if td.material[j * td.n + i] != 2:
						continue
					var x: float = td.cell_center(i)
					var z: float = td.cell_center(j)
					var r := Vector2(x, z).length()
					if r > 300.0 and r < br and td.height[j * td.n + i] > 60.0:
						br = r
						best = {"x": x, "z": z, "h": td.height[j * td.n + i]}
			return {"pos": Vector3(best.x, best.h + 70.0, best.z + 90.0), "look": Vector3(best.x, best.h, best.z)}
		"valley":
			return {"pos": Vector3(-300, td.ground(-300, 250) + 3.0, 250), "look": Vector3(0, 160, -500)}
		"coast":
			var br2 := 1e30
			var at := Vector3.ZERO
			for j in range(2, td.n - 2, 2):
				for i in range(2, td.n - 2, 2):
					var h: float = td.height[j * td.n + i]
					if h > 0.5 and h < 3.0 and td.height[j * td.n + i - 2] < 0.0:
						var x2: float = td.cell_center(i)
						var z2: float = td.cell_center(j)
						var d := absf(Vector2(x2, z2).length() - 1300.0)
						if d < br2:
							br2 = d
							at = Vector3(x2, h, z2)
			return {"pos": at + Vector3(-80, 40, 0), "look": at + Vector3(40, 10, 0)}
		"far":
			return {"pos": Vector3(0, 900, 2600), "look": Vector3(0, 150, 0)}
		"river":
			return {"pos": Vector3(0, 1700, 1400), "look": Vector3(0, 0, -100)}
		"river_close":
			# The shallow/deep river cell (class >= 2) closest to 250 m from the origin: the trunk through the east gap.
			var best_k := -1
			var best_d := 1e30
			for k in td.n * td.n:
				var nxk: int = Rivers.next_cell(td, k)
				if td.river_class(k) >= 2 and nxk >= 0 and absf(td.height[k] - td.height[nxk]) < 0.5 and td.height[k] > 8.0:
					var d := absf(Vector2(td.cell_center(k % td.n), td.cell_center(k / td.n)).length() - 700.0)
					if d < best_d:
						best_d = d
						best_k = k
			# Look downstream from 40 m upstream of the cell (walk four receivers up is not possible; use the receiver direction).
			var at := Vector3(td.cell_center(best_k % td.n), td.height[best_k], td.cell_center(best_k / td.n))
			var nxb: int = Rivers.next_cell(td, best_k)
			var dn := Vector3(td.cell_center(nxb % td.n) - at.x, 0.0, td.cell_center(nxb / td.n) - at.z).normalized()
			return {"pos": at - dn * 30.0 + Vector3(0, 9, 0), "look": at + dn * 40.0 + Vector3(0, -3, 0)}
		"fall":
			# The river/stream cell with the steepest bed drop to its receiver.
			var best_k2 := -1
			var best_drop := 0.0
			for k in td.n * td.n:
				if td.river_class(k) >= 1:
					var nx: int = Rivers.next_cell(td, k)
					if nx >= 0:
						var dr: float = td.height[k] - td.height[nx]
						if dr > best_drop:
							best_drop = dr
							best_k2 = k
			var at2 := Vector3(td.cell_center(best_k2 % td.n), td.height[best_k2], td.cell_center(best_k2 / td.n))
			print("fall drop ", best_drop, " at ", at2)
			var nrm: Vector3 = td.normal(at2.x, at2.z)
			var side := Vector3(nrm.x, 0.0, nrm.z).normalized()
			return {"pos": at2 + side * 45.0 + Vector3(0, 10, 0), "look": at2}
		"close_gully", "close_scree", "close_cliff":
			return _close(td, v)
		"close_cave":
			# The cave entrance with the widest mouth, seen from 16 m out along its facing at person height (rock_photo: the cave notch's rock up close).
			var cv: Dictionary = {}
			for c in td.caves:
				if cv.is_empty() or c.size.x > cv.size.x:
					cv = c
			var cp0: Vector3 = cv.position
			var fc := Vector3(cv.facing.x, 0.0, cv.facing.z).normalized()
			var mouth := Vector3(cp0.x, td.visual_ground(cp0.x, cp0.z), cp0.z)
			var eye := mouth + fc * 16.0
			return {"pos": Vector3(eye.x, td.visual_ground(eye.x, eye.z) + 2.0, eye.z), "look": mouth + Vector3(0, 2.0, 0)}
		"close_bank":
			var bk := -1
			var bd := 1e30
			for k in td.n * td.n:
				if td.river_class(k) >= 2 and td.height[k] > 20.0 and td.height[k] < 120.0:
					var d3 := absf(Vector2(td.cell_center(k % td.n), td.cell_center(k / td.n)).length() - 650.0)
					if d3 < bd:
						bd = d3
						bk = k
			var rp := Vector3(td.cell_center(bk % td.n), td.height[bk], td.cell_center(bk / td.n))
			var nxk2: int = Rivers.next_cell(td, bk)
			var dn2 := Vector3(td.cell_center(nxk2 % td.n) - rp.x, 0.0, td.cell_center(nxk2 / td.n) - rp.z).normalized()
			var side2 := Vector3(-dn2.z, 0.0, dn2.x)
			var cp := rp + side2 * 14.0
			return {"pos": Vector3(cp.x, td.visual_ground(cp.x, cp.z) + 2.2, cp.z), "look": rp + dn2 * 6.0 - side2 * 2.0}
	return {}

# Close-up spots found by rule on the erosion maps: a gully (flow, 25-45 degrees), a scree apron (talus apron) and a cliff (steeper than 55 degrees),
# nearest to 500 m from the origin. The camera is a few metres above the ground 13 m (cliff: 26 m) away on the downhill side, looking at the spot.
static func _close(td, v: String) -> Dictionary:
	var mn: int = td.vn / 2
	var best := Vector3.INF
	var bs := -1e30
	for j in range(8, mn - 8, 3):
		for i in range(8, mn - 8, 3):
			var m := (j * mn + i) * 4
			var x: float = (float(i) * 2.0 + 1.0) * td.vcell - td.half
			var z: float = (float(j) * 2.0 + 1.0) * td.vcell - td.half
			var h: float = td.visual_ground(x, z)
			if h < 60.0 or Vector2(x, z).length() > 1200.0:
				continue
			var n: Vector3 = td.normal(x, z)
			var sl: float = acos(n.y) * 57.2958
			var score := -1e30
			if v == "close_gully" and sl > 25.0 and sl < 45.0 and td.material[td.cell_index(x, z)] == 1:
				score = float(td.vmaps[m])
			elif v == "close_scree" and sl > 22.0 and sl < 40.0:
				score = float(td.vmaps[m + 2]) + (50.0 if td.material[td.cell_index(x, z)] == 2 else 0.0)
			elif v == "close_cliff" and sl > 55.0 and sl < 75.0 and td.material[td.cell_index(x, z)] == 1:
				score = 100.0 - absf(Vector2(x, z).length() - 500.0) * 0.1 + h * 0.01
			score -= absf(Vector2(x, z).length() - 500.0) * 0.02
			if score > bs:
				bs = score
				best = Vector3(x, h, z)
	var nn: Vector3 = td.normal(best.x, best.z)
	var out := Vector3(nn.x, 0.0, nn.z).normalized()
	var dist := 26.0 if v == "close_cliff" else 13.0
	var cx: float = best.x + out.x * dist
	var cz: float = best.z + out.z * dist
	return {"pos": Vector3(cx, maxf(td.visual_ground(cx, cz) + 2.5, best.y + (10.0 if v == "close_cliff" else 3.5)), cz), "look": best + Vector3(0, 1.0, 0)}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else "/tmp/look"
	var views: PackedStringArray = (args[1] if args.size() > 1 and args[1] != "" else ",".join(ALL)).split(",")
	if args.size() > 1 and args[1] == "close":
		views = PackedStringArray(CLOSE)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1280, 720)
	var game = root.get_node("Game")
	var weather: String = args[2] if args.size() > 2 else ""
	game.settings.weather = weather
	game.settings.grass = 20000
	var entry := TerrainCache.load_entry({"seed": 1})
	if entry.is_empty():
		entry = TerrainCache.build({"seed": 1}, CporeTerrain.new())
	game.set_island(entry)
	var island: Node3D = load("res://game/island/island.tscn").instantiate()
	root.add_child(island)
	for i in 30:
		await process_frame
	# LOOK_SET="name=value,name=value": float shader uniforms of the terrain materials, for tuning without editing the shaders.
	for kv in OS.get_environment("LOOK_SET").split(",", false):
		var p := kv.split("=")
		island.terrain_chunks.set_uniform(p[0], float(p[1]) if "." in p[1] or p[1].is_valid_float() else p[1])
		print("uniform ", p[0], " = ", p[1])
	for v in views:
		var cv := camera_for(game.data, v)
		print(v, " ", cv)
		island.chase_enabled = false
		island.camera.position = cv.pos
		island.camera.look_at(cv.look)
		island.camera.far = 12000.0
		island.terrain_chunks.update_lods(island.camera.global_position, true)
		Clouds.frozen_time = 600.0   # fixed wind phase so frames compare
		Clouds.set_time(0.0)
		island.grass.visible = false
		for i in 6:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_jpg(out_dir.path_join(v + ".jpg"), 0.85)
	quit()
