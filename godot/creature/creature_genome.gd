class_name CreatureGenome
extends RefCounted
## cpore.creature/4 document: validation and /1 /2 /3 migration.
## Port of web/studio/genome.js. Validation is pure; nothing is mutated.
## GDScript has no exceptions, so parse() returns
## {ok: bool, genome: Dictionary, warnings: Array, error: String}; `error` is
## the same path string genome.js throws (e.g. "parts.type").

const SCHEMA := "cpore.creature/4"
const LEG_TYPES := ["pata", "zanca", "pezuna"]

var _error := ""


static func parse(input, types: Dictionary) -> Dictionary:
	var v := CreatureGenome.new()
	return v._parse(input, types)


## Convenience: types dictionary {id: entry} from a parsed parts.json table.
static func types_from_table(table: Dictionary) -> Dictionary:
	var out := {}
	for p in table.get("parts", []):
		out[p["id"]] = p
	return out


func _parse(input, types: Dictionary) -> Dictionary:
	var g = input
	if typeof(input) == TYPE_STRING:
		var json := JSON.new()
		if json.parse(input) != OK:
			return _result_fail("json")
		g = json.data
	if not _object(g, "document"):
		return _result_fail(_error)
	if not (g.get("schema") in ["cpore.creature/1", "cpore.creature/2", "cpore.creature/3", SCHEMA]):
		return _result_fail("schema")
	var doc = g if g["schema"] == SCHEMA else _migrate(g)
	if doc == null:
		return _result_fail(_error)
	var genome = _validate(doc, types)
	if genome == null:
		return _result_fail(_error)
	var warnings: Array = []
	if genome.has("migration"):
		warnings = genome["migration"]["warnings"].duplicate()
	return {"ok": true, "genome": genome, "warnings": warnings, "error": ""}


func _result_fail(path: String) -> Dictionary:
	return {"ok": false, "genome": {}, "warnings": [], "error": path}


func _fail(path: String) -> bool:
	if _error == "":
		_error = path
	return false


static func _is_num(x) -> bool:
	return (typeof(x) == TYPE_FLOAT or typeof(x) == TYPE_INT) and is_finite(float(x))


func _object(x, path: String) -> bool:
	if typeof(x) != TYPE_DICTIONARY:
		return _fail(path)
	return true


func _number(x, lo: float, hi: float, path: String) -> bool:
	if not _is_num(x) or float(x) < lo or float(x) > hi:
		return _fail(path)
	return true


func _integer(x, lo: float, hi: float, path: String) -> bool:
	if not _number(x, lo, hi, path):
		return false
	if float(x) != floor(float(x)):
		return _fail(path)
	return true


func _keys(o, allowed: Array, path: String) -> bool:
	if not _object(o, path):
		return false
	for k in o.keys():
		if not (k in allowed):
			return _fail(path + "." + str(k))
	return true


static func _regex(pattern: String) -> RegEx:
	var r := RegEx.new()
	r.compile(pattern)
	return r


func _region(r):
	if not _keys(r, ["id", "schema", "family", "seed", "count", "length", "curve", "branches", "surface", "position", "coverage", "angle", "mirror"], "regions"):
		return null
	var id = r.get("id")
	if typeof(id) != TYPE_STRING or _regex("^[-A-Za-z0-9_]{1,64}$").search(id) == null \
			or r.get("schema") != CreatureGrowth.VERSION \
			or not (r.get("surface") in ["torso", "neck", "tail"]) \
			or typeof(r.get("mirror")) != TYPE_BOOL:
		_fail("regions")
		return null
	if not (r.get("family") in ["horns", "plates", "tendrils"]):
		_fail("regions.family")
		return null
	for spec in [["seed", 0, 4294967295], ["count", 1, 18], ["length", .2, 2.4], ["curve", -1, 1], ["branches", 0, 3]]:
		if not _number(r.get(spec[0]), spec[1], spec[2], "regions." + spec[0]):
			return null
	var grown := CreatureGrowth.validate(r)
	if not grown["ok"]:
		_fail(grown["error"])
		return null
	if not _number(r.get("position"), 0, 1, "regions.position"):
		return null
	if not _number(r.get("coverage"), 0, 1, "regions.coverage"):
		return null
	if not _number(r.get("angle"), -PI, PI, "regions.angle"):
		return null
	return r.duplicate(true)


func _validate(g, types: Dictionary):
	if not _keys(g, ["schema", "name", "nodes", "parts", "skin", "regions", "migration"], "document"):
		return null
	if g.get("schema") != SCHEMA:
		_fail("schema")
		return null
	var name = g.get("name")
	if typeof(name) != TYPE_STRING or name.length() > 80 or _regex("[<>\\x{00}-\\x{1f}]").search(name) != null:
		_fail("name")
		return null
	var nodes = g.get("nodes")
	if typeof(nodes) != TYPE_ARRAY or nodes.size() < 4 or nodes.size() > 32:
		_fail("nodes")
		return null
	for i in nodes.size():
		var n = nodes[i]
		if not _keys(n, ["y", "z", "r"], "nodes"):
			return null
		if not (_number(n.get("y"), -5, 20, "nodes.y") and _number(n.get("z"), -30, 30, "nodes.z") and _number(n.get("r"), .03, 3, "nodes.r")):
			return null
		if i > 0 and Vector2(n["y"] - nodes[i - 1]["y"], n["z"] - nodes[i - 1]["z"]).length() < .05:
			_fail("nodes.distance")
			return null
	var parts = g.get("parts")
	if typeof(parts) != TYPE_ARRAY or parts.size() > 256:
		_fail("parts")
		return null
	for p in parts:
		if not _keys(p, ["type", "t", "ang", "size", "len", "curve", "w", "k", "f", "rot", "tilt", "act", "single", "pupil"], "parts"):
			return null
		if typeof(p.get("type")) != TYPE_STRING or not types.has(p["type"]):
			_fail("parts.type")
			return null
		if not (_number(p.get("t"), 0, 1, "parts.t") and _number(p.get("ang"), -PI, PI, "parts.ang")):
			return null
		for spec in [["size", .1, 4], ["len", .1, 5], ["curve", -1.5, 1.5], ["w", .05, .8], ["rot", -PI, PI], ["tilt", -1.5, 1.5]]:
			if p.has(spec[0]) and not _number(p[spec[0]], spec[1], spec[2], "parts." + spec[0]):
				return null
		if p.has("act") and not (p["act"] in ["muscle", "tendon", "spring", "hydrostat", "hydraulic", "peristaltic", "tubefeet", "cilia"]):
			_fail("parts.act")
			return null
		if p.has("single") and not (_integer(p["single"], -1, 1, "parts.single")):
			return null
		if p.has("pupil") and not (p["pupil"] in ["auto", "round", "slit", "bar"]):
			_fail("parts.pupil")
			return null
		if p["type"] in LEG_TYPES:
			if not _number(p.get("w"), .05, .8, "parts.w"):
				return null
			for k in ["k", "f"]:
				var arr = p.get(k)
				if typeof(arr) != TYPE_ARRAY or arr.size() != 3:
					_fail("parts." + k)
					return null
				for v in arr:
					if not _number(v, -20, 20, "parts." + k):
						return null
		else:
			if not _number(p.get("size"), .1, 4, "parts.size"):
				return null
			if p["type"] in ["cuerno", "asta", "pua", "tallo", "antena"] and not _number(p.get("len"), .1, 5, "parts.len"):
				return null
			if p["type"] == "cuerno" and not _number(p.get("curve"), -1.5, 1.5, "parts.curve"):
				return null
	var skin = g.get("skin")
	if not _keys(skin, ["pat", "cA", "cB", "cC", "wet", "scale", "cs", "ps", "pc", "ros", "act", "sk"], "skin"):
		return null
	if not (_integer(skin.get("pat"), 0, 3, "skin.pat") and _number(skin.get("wet"), 0, 1, "skin.wet") and _number(skin.get("scale"), 3, 14, "skin.scale")):
		return null
	# Optional realism-pilot controls (absent = defaults): countershading, pattern scale, pattern contrast, rosettes.
	for k in [["cs", 0, 1], ["ps", .5, 2], ["pc", 0, 1]]:
		if skin.has(k[0]) and not _number(skin[k[0]], k[1], k[2], "skin." + k[0]):
			return null
	if skin.has("sk") and not (skin["sk"] in ["auto", "endo", "exo", "hydro"]):
		_fail("skin.sk")
		return null
	if skin.has("act") and not (skin["act"] in ["auto", "muscle", "hydraulic", "exo"]):
		_fail("skin.act")
		return null
	if skin.has("ros") and not _integer(skin["ros"], 0, 1, "skin.ros"):
		return null
	var hex := _regex("^#[0-9a-fA-F]{6}$")
	for k in ["cA", "cB", "cC"]:
		if typeof(skin.get(k)) != TYPE_STRING or hex.search(skin[k]) == null:
			_fail("skin." + k)
			return null
	var regions = g.get("regions")
	if typeof(regions) != TYPE_ARRAY or regions.size() > 64:
		_fail("regions")
		return null
	var ids := {}
	for r in regions:
		if _region(r) == null:
			return null
		if ids.has(r["id"]):
			_fail("regions.id")
			return null
		ids[r["id"]] = true
	if g.has("migration") and g["migration"]:
		var m = g["migration"]
		if not _keys(m, ["from", "warnings", "source"], "migration"):
			return null
		if not (m.get("from") in [1, 2, 3, 1.0, 2.0, 3.0]) or typeof(m.get("warnings")) != TYPE_ARRAY:
			_fail("migration")
			return null
		for w in m["warnings"]:
			if typeof(w) != TYPE_STRING:
				_fail("migration")
				return null
		if not _object(m.get("source"), "migration.source"):
			return null
	return g.duplicate(true)


func _migrate(g):
	var v := int(String(g["schema"]).split("/")[1])
	var b = g.get("body")
	if not _object(b, "body"):
		return null
	var l = g.get("legs")
	if not _object(l, "legs"):
		return null
	var h = g.get("head")
	if not _object(h, "head"):
		return null
	var s = g.get("skin")
	if not _object(s, "skin"):
		return null
	var arm_len = .7
	if typeof(g.get("arms")) == TYPE_DICTIONARY and g["arms"].get("length") != null:
		arm_len = g["arms"]["length"]
	for spec in [[b.get("torso"), 1.6, 5, "body.torso"], [b.get("girth"), .45, 1.5, "body.girth"], [b.get("neck"), .4, 3.4, "body.neck"], [b.get("tail"), .8, 5.5, "body.tail"],
			[l.get("length"), .8, 3.2, "legs.length"], [l.get("width"), .12, .42, "legs.width"], [l.get("stride"), 0, 4.5, "legs.stride"],
			[h.get("size"), .4, 1, "head.size"], [h.get("eyes"), .14, .38, "head.eyes"], [arm_len, .3, 1.4, "arms.length"]]:
		if not _number(spec[0], spec[1], spec[2], spec[3]):
			return null
	if not _integer(l.get("pairs"), 1, 3, "legs.pairs"):
		return null
	var warnings: Array = ["migration.body", "migration.motion", "migration.levels", "migration.projection"]
	var base_y: float = l["length"] * .84 + b["girth"] * .3
	var nodes: Array = []
	# Sample a single vertical chain. Legacy sliders have no exact spine inverse.
	for yzr in [[base_y, -b["tail"], .06], [base_y, -b["tail"] * .5, b["girth"] * .4], [base_y, 0, b["girth"] * .8],
			[base_y + b["torso"] * .05, b["torso"] * .5, b["girth"]], [base_y + b["torso"] * .05, b["torso"], b["girth"] * .8],
			[base_y + b["neck"] * .5, b["torso"] + b["neck"] * .6, h["size"] * .65], [base_y + b["neck"] * .7, b["torso"] + b["neck"], h["size"]]]:
		nodes.append({"y": yzr[0], "z": yzr[1], "r": yzr[2]})
	var parts: Array = [{"type": "ojo", "t": .94, "ang": .9, "size": h["eyes"] / .2}]
	var pairs := int(l["pairs"])
	for i in pairs:
		parts.append({"type": "pata", "t": .42 + i * .27 / max(1, pairs - 1), "ang": 2.1, "w": l["width"],
			"k": [.25, -l["length"] * .5, .1], "f": [.35, -l["length"], 0]})
	var mapping := {
		"mouth": {"blunt": "romo", "jaws": "fauces", "beak": "pico"},
		"arms": {"claws": "arm_grasper", "hands": "arm_grasper", "none": null},
		"horns": {"none": null, "pair": "cuerno", "nasal": "cuerno", "crown": "asta"},
		"back": {"none": null, "spikes": "pua", "plates": "placa", "sail": "aleta"},
		"tailTip": {"none": null, "club": "maza", "spikes": "pua"}}
	var seen := {}
	if typeof(g.get("parts")) != TYPE_ARRAY:
		_fail("parts")
		return null
	for p in g["parts"]:
		if not _object(p, "parts"):
			return null
		if not _integer(p.get("level"), 1, 5, "parts.level"):
			return null
		var slot = p.get("slot")
		if typeof(slot) != TYPE_STRING or not mapping.has(slot) or typeof(p.get("type")) != TYPE_STRING \
				or not mapping[slot].has(p["type"]) or seen.has(slot):
			_fail("parts.type")
			return null
		seen[slot] = true
		var type = mapping[slot][p["type"]]
		if type == null:
			continue
		var t := .58
		match slot:
			"mouth": t = 1
			"arms": t = .72
			"tailTip": t = .05
			"horns": t = .9
		var ang := 0.0
		if slot == "arms":
			ang = 1.4
		elif slot == "horns" and p["type"] == "pair":
			ang = .5
		var n := {"type": type, "t": t, "ang": ang, "size": .8 + .1 * p["level"]}
		if type in ["cuerno", "asta", "pua"]:
			n["len"] = .55 if type == "pua" else .9
		if type == "cuerno":
			n["curve"] = .5
		parts.append(n)
	if not seen.has("mouth"):
		_fail("parts.mouth")
		return null
	var pattern := ["plain", "stripes", "spots", "marbled"].find(s.get("pattern"))
	if pattern < 0:
		_fail("skin.pattern")
		return null
	if not _object(s.get("colors"), "skin.colors"):
		return null
	var regions: Array = []
	if v == 3:
		if typeof(g.get("regions")) != TYPE_ARRAY:
			_fail("regions")
			return null
		for r in g["regions"]:
			var rr = _region(r)
			if rr == null:
				return null
			regions.append(rr)
	if v == 2:
		if not _object(g.get("growth"), "growth"):
			return null
		var gr: Dictionary = g["growth"].duplicate(true)
		gr["family"] = "horns" if gr.get("family") == "none" else gr.get("family")
		gr["id"] = "region-1"
		gr["surface"] = "torso"
		var r2 = _region(gr)
		if r2 == null:
			return null
		if g["growth"].get("family") != "none":
			regions = [r2]
	if v == 1 and g.has("growth"):
		warnings.append("migration.extra:growth")
	if v != 3 and g.has("regions"):
		warnings.append("migration.extra:regions")
	var arms = g.get("arms") if typeof(g.get("arms")) == TYPE_DICTIONARY else {}
	for spec in [["body", b, ["torso", "girth", "neck", "tail"]], ["legs", l, ["pairs", "length", "width", "stride"]], ["head", h, ["size", "eyes"]],
			["arms", arms, ["length"]], ["skin", s, ["pattern", "colors", "scale", "gloss"]]]:
		for key in spec[1].keys():
			if not (key in spec[2]):
				warnings.append("migration.extra:" + spec[0] + "." + key)
	for k in g.keys():
		if not (k in ["schema", "body", "legs", "head", "arms", "parts", "skin", "regions", "growth", "dna", "abilities", "name"]):
			warnings.append("migration.extra:" + k)
	var name = g.get("name")
	if name == null or (typeof(name) == TYPE_STRING and name == "") or (typeof(name) == TYPE_BOOL and not name):
		name = "Migrada"
	return {"schema": SCHEMA, "name": name, "nodes": nodes, "parts": parts,
		"skin": {"pat": pattern, "cA": s["colors"].get("base"), "cB": s["colors"].get("pattern"), "cC": s["colors"].get("belly"), "wet": s.get("gloss"), "scale": s.get("scale")},
		"regions": regions, "migration": {"from": v, "warnings": warnings, "source": g.duplicate(true)}}
