extends RefCounted
## Observing plants (brief creature-fixes 6): keeping the pointer on a plant for a few seconds writes it into the journal (visual only,
## no C state). The plants come from the flora batches the island placed (island_props.gd `records`); what is known is saved with
## the game (the scenario's "plants" list).

const DWELL := 2.5                     # s the pointer has to rest on one plant
const REACH := 70.0                    # m from the camera
const CELL := 48.0                     # m: the spatial index of the plant records

const HABITATS := {
	"valley_edge": ["valley edge", "borde de valle"], "bare_lava": ["bare lava", "lava desnuda"], "tidal": ["tide line", "línea de marea"],
	"mineral_seep": ["mineral seep", "rezume mineral"], "lava_crack": ["lava cracks", "grietas de lava"], "crater": ["meteor crater", "cráter del meteorito"],
	"lava_seep": ["warm seep", "rezume tibio"], "spring": ["springs", "manantiales"], "cave": ["cave mouths", "bocas de cueva"], "forest": ["forest", "bosque"],
	"meadow": ["meadow", "pradera"], "litter": ["leaf litter", "hojarasca"], "wet_fringe": ["wet fringe", "orilla húmeda"], "shade": ["deep shade", "sombra profunda"],
	"snowline": ["snowline", "línea de nieve"], "spray": ["sea spray", "rocío marino"], "host": ["on a host tree", "sobre un árbol huésped"],
	"bank": ["river banks", "orillas de río"], "hollow": ["hollows", "hondonadas"], "disturbed": ["disturbed ground", "suelo removido"],
}

var known: Dictionary = {}             # id -> true
var _id := ""
var _t := 0.0
var _index_stamp := []                 # [size, first p, last p] of the records the index was built from (cheap identity)
var _index := {}

## What is written in the journal: [{id, name{en,es}, habitat, habitat_text{en,es}, lore{en,es}}] in the order of the flora table.
func journal_rows(recipes: Array) -> Array:
	var out: Array = []
	for r in recipes:
		var id := String(r.get("id", ""))
		if not known.has(id):
			continue
		var hab := String(r.get("habitat", ""))
		var ht: Array = HABITATS.get(hab, [hab.replace("_", " "), hab.replace("_", " ")])
		out.append({"id": id, "name": r.get("name", {"en": id, "es": id}), "habitat": hab, "habitat_text": {"en": ht[0], "es": ht[1]}, "lore": r.get("lore", {"en": "", "es": ""})})
	return out

func to_list() -> Array:
	var ids: Array = known.keys()
	ids.sort()
	return ids

func from_list(ids: Variant) -> void:
	known.clear()
	if ids is Array:
		for id in ids:
			known[String(id)] = true

func _build_index(records: Array) -> void:
	_index_stamp = [records.size(), records[0].p, records[records.size() - 1].p]
	_index.clear()
	for r in records:
		var p: Vector3 = r.p
		var key := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not _index.has(key):
			_index[key] = []
		_index[key].append(r)

## The id of the plant the ray (origin, unit dir) passes through, the nearest to the origin, or "". Plants are tested as a vertical stick
## with a radius that grows with distance, so a small plant far away is still catchable.
func pick(records: Array, origin: Vector3, dir: Vector3) -> String:
	if records.is_empty():
		return ""
	if _index.is_empty() or _index_stamp != [records.size(), records[0].p, records[records.size() - 1].p]:
		_build_index(records)
	var best := ""
	var best_t := REACH
	var cx := floori(origin.x / CELL)
	var cz := floori(origin.z / CELL)
	var span := ceili(REACH / CELL)
	for i in range(cx - span, cx + span + 1):
		for j in range(cz - span, cz + span + 1):
			var cell: Array = _index.get(Vector2i(i, j), [])
			for r in cell:
				var h: float = maxf(float(r.height), 0.05)
				var v: Vector3 = (r.p as Vector3) + Vector3(0, h * 0.5, 0) - origin
				var t := v.dot(dir)
				if t < 1.0 or t >= best_t:
					continue
				var rad := maxf(h * 0.5, 0.35 + 0.012 * t)
				if (v - dir * t).length() <= rad:
					best_t = t
					best = String(r.id)
	return best

## Feed the plant under the pointer (or "" for none) once per step; returns the id the moment it becomes known, else "".
func tick(dt: float, id: String) -> String:
	if id == "" or id != _id:
		_id = id
		_t = 0.0 if id == "" or known.has(id) else dt
		return ""
	if known.has(id):
		return ""
	_t += dt
	if _t >= DWELL:
		known[id] = true
		_t = 0.0
		return id
	return ""

## 0..1 of the dwell on the current plant (for tests and a future mark).
func progress() -> float:
	return clampf(_t / DWELL, 0.0, 1.0) if _id != "" and not known.has(_id) else 0.0
