extends RefCounted
# The fixed camera views of the rock work (docs/godot/PLAN-rock.md step 0), shared by the evidence script,
# the benchmark and the tests. Everything is found by rule on the generated island, never hard-coded.

const Look := preload("res://game/island/look.gd")

const VIEWS := ["chase", "mid", "far", "cliff_lit", "cliff_shade"]

# Rock cell (material id 1) nearest the origin whose slope is 55-65 degrees, which lies farther than 250 m from
# the origin, and whose horizontal normal dotted with the horizontal sun direction passes `lit` (> 0.6 or < -0.6).
# Returns {i, j, x, z, h, nx, nz} or {} when there is none.
static func find_cliff(td, lit: bool) -> Dictionary:
	var sun := Look.sun_dir()
	var sh := Vector2(sun.x, sun.z).normalized()
	var best := {}
	var best_r := 1e30
	for j in range(2, td.n - 2):
		for i in range(2, td.n - 2):
			var k: int = j * td.n + i
			if td.material[k] != 1:
				continue
			var x: float = td.cell_center(i)
			var z: float = td.cell_center(j)
			var r := Vector2(x, z).length()
			if r <= 250.0 or r >= best_r:
				continue
			var nrm: Vector3 = td.normal(x, z)
			var slope := rad_to_deg(acos(clampf(nrm.y, -1.0, 1.0)))
			if slope < 55.0 or slope > 65.0:
				continue
			var hn := Vector2(nrm.x, nrm.z).normalized()
			var d := hn.dot(sh)
			if (lit and d > 0.6) or (not lit and d < -0.6):
				best_r = r
				best = {"i": i, "j": j, "x": x, "z": z, "h": td.height[k], "nx": hn.x, "nz": hn.y, "slope": slope}
	return best

static func highest(td) -> Dictionary:
	var best := -1e30
	var at := 0
	for k in td.height.size():
		if td.height[k] > best:
			best = td.height[k]
			at = k
	return {"x": td.cell_center(at % td.n), "z": td.cell_center(at / td.n), "h": best}

# {pos, look} for a named view; "chase" returns {} (the island's own chase camera).
static func camera_for(td, view: String) -> Dictionary:
	match view:
		"mid":
			var p := highest(td)
			return {"pos": Vector3(0, 80, 0), "look": Vector3(p.x, p.h, p.z)}
		"far":
			return {"pos": Vector3(0, 900, 2600), "look": Vector3(0, 150, 0)}
		"cliff_lit", "cliff_shade":
			var c := find_cliff(td, view == "cliff_lit")
			if c.is_empty():
				return {}
			var at := Vector3(c.x, c.h, c.z)
			return {"pos": at + Vector3(c.nx, 0.0, c.nz) * 60.0 + Vector3(0, 15, 0), "look": at}
	return {}

# Puts the island camera on a view. Returns false for "chase" (left to the game).
static func apply(island: Node3D, td, view: String) -> bool:
	if view == "chase":
		island.chase_enabled = true
		return false
	var cv := camera_for(td, view)
	island.chase_enabled = false
	island.camera.position = cv.pos
	island.camera.look_at(cv.look)
	island.terrain_chunks.update_lods(island.camera.global_position, true)
	return true
