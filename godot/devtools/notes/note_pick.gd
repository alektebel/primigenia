extends RefCounted
## What is under the mouse in flag mode. Pure: a ray plus a source dictionary, so tests need no scene.
##   src: {entities: [{id, x, z, dead, meat, radius_cm, species}], ground: Callable(x, z) -> y,
##         species_name: Callable(int) -> String, props: [{kind, id, name, x, z}], records: [flora records], gaze: PlantGaze,
##         water_depth: Callable(x, z) -> float, nest: Vector2 or null}
## Order: creature, prop or artifact (remains, nest, finds, shards), plant, then water or terrain at the ground hit.
## Result: {kind: creature|plant|prop|terrain|water, id, species, part, name, pos: Vector3}. The creature collider is one sphere, so
## `part` stays "" until a part collider exists.

const Pointer := preload("res://game/player/pointer.gd")
const PROP_RADIUS := 1.1
const WATER_MIN := 0.05

static func _species(src: Dictionary, e: Dictionary) -> String:
	var f: Callable = src.get("species_name", Callable())
	return str(f.call(int(e.get("species", -1)))) if f.is_valid() else str(e.get("species", ""))

static func _ray_sphere(origin: Vector3, dir: Vector3, centre: Vector3, r: float) -> float:
	var oc := centre - origin
	var tca := oc.dot(dir)
	if tca < 0.0:
		return -1.0
	var d2 := oc.dot(oc) - tca * tca
	return -1.0 if d2 > r * r else tca - sqrt(maxf(r * r - d2, 0.0))

static func pick(origin: Vector3, dir: Vector3, src: Dictionary) -> Dictionary:
	var ground: Callable = src.ground
	var ents: Array = src.get("entities", [])
	var ground_pt = Pointer.march(origin, dir, ground)
	var ground_t := origin.distance_to(ground_pt) if ground_pt != null else 1e9
	# 1. creatures (a carcass is remains, a prop)
	var c := Pointer.pick_entity(origin, dir, ents, ground)
	var best := {}
	var best_t := 1e9
	if not c.is_empty():
		var e: Dictionary = ents[int(c.id)]
		best_t = origin.distance_to(c.pos)
		if bool(e.get("dead", false)):
			best = {"kind": "prop", "id": int(c.id), "species": _species(src, e), "part": "", "name": "remains of %s" % _species(src, e), "pos": c.pos}
		else:
			best = {"kind": "creature", "id": int(c.id), "species": _species(src, e), "part": "", "name": "%s #%d" % [_species(src, e), int(c.id)], "pos": c.pos}
		if best.kind == "creature":
			return best
	# 2. props and artifacts: nest, food and finds, meteor shards
	var props: Array = src.get("props", []).duplicate()
	if src.get("nest") is Vector2:
		props.append({"kind": "nest", "id": 0, "name": "nest", "x": src.nest.x, "z": src.nest.y})
	for p in props:
		var centre := Vector3(p.x, ground.call(p.x, p.z) + 0.4, p.z)
		var t := _ray_sphere(origin, dir, centre, float(p.get("radius", PROP_RADIUS)))
		if t >= 0.0 and t < best_t and t < ground_t + PROP_RADIUS:
			best_t = t
			best = {"kind": "prop", "id": p.id, "species": "", "part": str(p.kind), "name": str(p.name), "pos": Vector3(p.x, ground.call(p.x, p.z), p.z)}
	if not best.is_empty():
		return best
	# 3. plants
	var gaze = src.get("gaze")
	var records: Array = src.get("records", [])
	if gaze != null and not records.is_empty():
		var pid: String = gaze.pick(records, origin, dir)
		if pid != "":
			var pos = ground_pt if ground_pt != null else origin
			return {"kind": "plant", "id": pid, "species": "", "part": "", "name": pid, "pos": pos}
	# 4. water or terrain
	if ground_pt == null:
		return {}
	var wd: Callable = src.get("water_depth", Callable())
	var wet: bool = wd.is_valid() and float(wd.call(ground_pt.x, ground_pt.z)) > WATER_MIN
	return {"kind": "water" if wet else "terrain", "id": -1, "species": "", "part": "",
		"name": "water" if wet else "ground (%d, %d)" % [roundi(ground_pt.x), roundi(ground_pt.z)], "pos": ground_pt}
