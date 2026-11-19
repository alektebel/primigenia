extends RefCounted
## Port of web/studio/genome.js (cpore.creature/4 document: validate, migrate, parse).
## No exceptions in GDScript: every function returns a Dictionary {ok, error, genome, warnings}.

const SCHEMA := "cpore.creature/5"
const GROWTH_VERSION := "cpore.growth/1"
const LEG_TYPES := ["pata", "zanca", "pezuna"]
const LEN_TYPES := ["cuerno", "asta", "pua", "tallo", "antena"]
const RADIAL_LEG_TYPES := ["pata", "zanca", "pezuna", "leg_sprinter", "leg_sucker", "foot_spring", "foot_hoof", "foot_gecko"]

static var _err := ""

static func _fail(path: String) -> bool:
	if _err == "":
		_err = path
	return false

static func _is_num(x) -> bool:
	var t := typeof(x)
	return (t == TYPE_FLOAT or t == TYPE_INT) and is_finite(float(x))

static func _num(x, lo: float, hi: float, path: String) -> bool:
	if not _is_num(x) or x < lo or x > hi:
		return _fail(path)
	return true

static func _int(x, lo: float, hi: float, path: String) -> bool:
	if not _num(x, lo, hi, path):
		return false
	if fposmod(float(x), 1.0) != 0.0:
		return _fail(path)
	return true

static func _obj(x, path: String) -> bool:
	if typeof(x) != TYPE_DICTIONARY:
		return _fail(path)
	return true

static func _keys(o, allowed: Array, path: String) -> bool:
	if not _obj(o, path):
		return false
	for k in o.keys():
		if not allowed.has(k):
			return _fail(path + "." + str(k))
	return true

static func _region(r) -> bool:
	if not _keys(r, ["id", "schema", "family", "seed", "count", "length", "curve", "branches", "surface", "position", "coverage", "angle", "mirror"], "regions"):
		return false
	var rid = r.get("id")
	if typeof(rid) != TYPE_STRING or not _id_ok(rid) or r.get("schema") != GROWTH_VERSION \
			or not ["torso", "neck", "tail"].has(r.get("surface")) or typeof(r.get("mirror")) != TYPE_BOOL:
		return _fail("regions")
	if not ["horns", "plates", "tendrils"].has(r.get("family")):
		return _fail("regions.family")
	for spec in [["seed", 0, 4294967295], ["count", 1, 18], ["length", .2, 2.4], ["curve", -1, 1], ["branches", 0, 3]]:
		if not _num(r.get(spec[0]), spec[1], spec[2], "regions." + spec[0]):
			return false
	for k in ["seed", "count", "branches"]:
		if not _int(r[k], -1e18, 1e18, "growth." + k):
			return false
	return _num(r.get("position"), 0, 1, "regions.position") and _num(r.get("coverage"), 0, 1, "regions.coverage") \
		and _num(r.get("angle"), -PI, PI, "regions.angle")

static func _id_ok(s: String) -> bool:
	if s.length() < 1 or s.length() > 64:
		return false
	for c in s:
		var ok: bool = c == "-" or c == "_" or (c >= "0" and c <= "9") or (c >= "a" and c <= "z") or (c >= "A" and c <= "Z")
		if not ok:
			return false
	return true

static func _name_ok(s: String) -> bool:
	if s.length() > 80:
		return false
	for i in s.length():
		var c := s.unicode_at(i)
		if c < 32 or s[i] == "<" or s[i] == ">":
			return false
	return true

static func _hex_ok(s) -> bool:
	if typeof(s) != TYPE_STRING or s.length() != 7 or s[0] != "#":
		return false
	return s.substr(1).is_valid_hex_number()

## Validate a v4 document. `types` is a Dictionary keyed by part id (or any container with has()).
static func validate(g, types) -> Dictionary:
	_err = ""
	var ok := _validate(g, types)
	if not ok:
		return {"ok": false, "error": _err, "genome": null}
	return {"ok": true, "error": "", "genome": g.duplicate(true)}

static func _validate(g, types) -> bool:
	if not _keys(g, ["schema", "name", "nodes", "parts", "skin", "regions", "migration", "plan"], "document"):
		return false
	if g.get("schema") != SCHEMA:
		return _fail("schema")
	if typeof(g.get("name")) != TYPE_STRING or not _name_ok(g["name"]):
		return _fail("name")
	var nodes = g.get("nodes")
	if typeof(nodes) != TYPE_ARRAY or nodes.size() < 4 or nodes.size() > 32:
		return _fail("nodes")
	for i in nodes.size():
		var n = nodes[i]
		if not _keys(n, ["y", "z", "r"], "nodes"):
			return false
		if not (_num(n.get("y"), -5, 20, "nodes.y") and _num(n.get("z"), -30, 30, "nodes.z") and _num(n.get("r"), .03, 3, "nodes.r")):
			return false
		if i > 0 and Vector2(n["y"] - nodes[i - 1]["y"], n["z"] - nodes[i - 1]["z"]).length() < .05:
			return _fail("nodes.distance")
	var parts = g.get("parts")
	if typeof(parts) != TYPE_ARRAY or parts.size() > 256:
		return _fail("parts")
	for p in parts:
		if not _keys(p, ["type", "t", "ang", "size", "len", "curve", "w", "k", "f", "rot", "tilt", "act", "single", "pupil", "level", "tier"], "parts"):
			return false
		if not _int(p.get("level"), 1, 5, "parts.level") or not _int(p.get("tier"), 0, 2, "parts.tier"):
			return false
		if typeof(p.get("type")) != TYPE_STRING or not types.has(p["type"]):
			return _fail("parts.type")
		if not (_num(p.get("t"), 0, 1, "parts.t") and _num(p.get("ang"), -PI, PI, "parts.ang")):
			return false
		for spec in [["size", .1, 4], ["len", .1, 5], ["curve", -1.5, 1.5], ["w", .05, .8], ["rot", -PI, PI], ["tilt", -1.5, 1.5]]:
			if p.has(spec[0]) and not _num(p[spec[0]], spec[1], spec[2], "parts." + spec[0]):
				return false
		if p.has("act") and not (p["act"] in ["muscle", "tendon", "spring", "hydrostat", "hydraulic", "peristaltic", "tubefeet", "cilia"]):
			return _fail("parts.act")
		if p.has("single") and not _int(p["single"], -1, 1, "parts.single"):
			return false
		if p.has("pupil") and not (p["pupil"] in ["auto", "round", "slit", "bar"]):
			return _fail("parts.pupil")
		if LEG_TYPES.has(p["type"]):
			if not _num(p.get("w"), .05, .8, "parts.w"):
				return false
			for k in ["k", "f"]:
				if typeof(p.get(k)) != TYPE_ARRAY or p[k].size() != 3:
					return _fail("parts." + k)
				for v in p[k]:
					if not _num(v, -20, 20, "parts." + k):
						return false
		else:
			if not _num(p.get("size"), .1, 4, "parts.size"):
				return false
			if LEN_TYPES.has(p["type"]) and not _num(p.get("len"), .1, 5, "parts.len"):
				return false
			if p["type"] == "cuerno" and not _num(p.get("curve"), -1.5, 1.5, "parts.curve"):
				return false
	var s = g.get("skin")
	if not _keys(s, ["pat", "cA", "cB", "cC", "wet", "scale", "cs", "ps", "pc", "ros", "act", "sk"], "skin"):
		return false
	if not (_int(s.get("pat"), 0, 3, "skin.pat") and _num(s.get("wet"), 0, 1, "skin.wet") and _num(s.get("scale"), 3, 14, "skin.scale")):
		return false
	for k in [["cs", 0, 1], ["ps", .5, 2], ["pc", 0, 1]]:
		if s.has(k[0]) and not _num(s[k[0]], k[1], k[2], "skin." + k[0]):
			return false
	if s.has("sk") and not (s["sk"] in ["auto", "endo", "exo", "hydro"]):
		return _fail("skin.sk")
	if s.has("act") and not (s["act"] in ["auto", "muscle", "hydraulic", "exo"]):
		return _fail("skin.act")
	if s.has("ros") and not _int(s["ros"], 0, 1, "skin.ros"):
		return false
	for k in ["cA", "cB", "cC"]:
		if not _hex_ok(s.get(k)):
			return _fail("skin." + k)
	var regs = g.get("regions")
	if typeof(regs) != TYPE_ARRAY or regs.size() > 64:
		return _fail("regions")
	var ids := {}
	for r in regs:
		if not _region(r):
			return false
		if ids.has(r["id"]):
			return _fail("regions.id")
		ids[r["id"]] = true
	if not _plan(g):
		return false
	if g.get("migration"):
		var m = g["migration"]
		if not _keys(m, ["from", "warnings", "source"], "migration"):
			return false
		if not [1, 2, 3].has(int(m.get("from", 0))) or typeof(m.get("warnings")) != TYPE_ARRAY:
			return _fail("migration")
		for w in m["warnings"]:
			if typeof(w) != TYPE_STRING:
				return _fail("migration")
		if not _obj(m.get("source"), "migration.source"):
			return false
	return true

## Radial body plan (A24, optional `plan` key; absent = bilateral). Error paths are shared with creature_genome.gd,
## studio/genome.gd and web/studio/genome.js (godot/creature/tests/parity/plan_cases.json).
static func _plan(g) -> bool:
	if not g.has("plan"):
		return true
	var p = g["plan"]
	if not _keys(p, ["sym", "fold", "star", "gel", "arm"], "plan"):
		return false
	if not (p.get("sym") in ["bilateral", "radial"]):
		return _fail("plan.sym")
	var radial: bool = p["sym"] == "radial"
	if (radial or p.has("fold")) and not _int(p.get("fold"), 3, 8, "plan.fold"):
		return false
	for k in [["star", 0, 1], ["gel", 0, 1]]:
		if p.has(k[0]) and not _num(p[k[0]], k[1], k[2], "plan." + k[0]):
			return false
	if p.has("arm"):
		var a = p["arm"]
		if not _keys(a, ["len", "w", "taper", "curl", "droop", "frill", "tip", "eye", "act"], "plan.arm"):
			return false
		for k in [["len", 0, 6], ["w", .1, 1], ["taper", 0, 1], ["curl", -1, 1], ["droop", 0, 1], ["frill", 0, 1]]:
			if a.has(k[0]) and not _num(a[k[0]], k[1], k[2], "plan.arm." + k[0]):
				return false
		if a.has("tip") and not (a["tip"] in ["point", "frill", "bulb"]):
			return _fail("plan.arm.tip")
		if a.has("eye") and not _int(a["eye"], 0, 1, "plan.arm.eye"):
			return false
		if a.has("act") and not (a["act"] in ["peristaltic", "hydrostat", "tubefeet", "cilia"]):
			return _fail("plan.arm.act")
	if not radial:
		return true
	var py := 0.0
	for i in g["nodes"].size():
		var n = g["nodes"][i]
		if float(n["z"]) != 0.0 or (i > 0 and float(n["y"]) <= py):
			return _fail("plan.nodes")
		py = float(n["y"])
	for q in g["parts"]:
		if RADIAL_LEG_TYPES.has(q["type"]):
			return _fail("plan.legs")
		if q.has("single") and float(q["single"]) < 0.0:
			return _fail("parts.single")
	for r in g["regions"]:
		if r["surface"] != "torso":
			return _fail("regions.surface")
	return true

static func _migrate(g: Dictionary):
	var sch = g.get("schema")
	var v := int(str(sch).split("/")[1])
	var b = g.get("body"); var l = g.get("legs"); var h = g.get("head"); var s = g.get("skin")
	if not (_obj(b, "body") and _obj(l, "legs") and _obj(h, "head") and _obj(s, "skin")):
		return null
	var arms = g.get("arms")
	var arm_len = .7
	if typeof(arms) == TYPE_DICTIONARY and arms.has("length"):
		arm_len = arms["length"]
	for spec in [[b.get("torso"), 1.6, 5, "body.torso"], [b.get("girth"), .45, 1.5, "body.girth"], [b.get("neck"), .4, 3.4, "body.neck"], [b.get("tail"), .8, 5.5, "body.tail"], [l.get("length"), .8, 3.2, "legs.length"], [l.get("width"), .12, .42, "legs.width"], [l.get("stride"), 0, 4.5, "legs.stride"], [h.get("size"), .4, 1, "head.size"], [h.get("eyes"), .14, .38, "head.eyes"], [arm_len, .3, 1.4, "arms.length"]]:
		if not _num(spec[0], spec[1], spec[2], spec[3]):
			return null
	if not _int(l.get("pairs"), 1, 3, "legs.pairs"):
		return null
	var warnings: Array = ["migration.body", "migration.motion", "migration.levels", "migration.projection"]
	var base_y: float = l["length"] * .84 + b["girth"] * .3
	var nodes: Array = []
	for q in [[base_y, -b["tail"], .06], [base_y, -b["tail"] * .5, b["girth"] * .4], [base_y, 0, b["girth"] * .8], [base_y + b["torso"] * .05, b["torso"] * .5, b["girth"]], [base_y + b["torso"] * .05, b["torso"], b["girth"] * .8], [base_y + b["neck"] * .5, b["torso"] + b["neck"] * .6, h["size"] * .65], [base_y + b["neck"] * .7, b["torso"] + b["neck"], h["size"]]]:
		nodes.append({"y": q[0], "z": q[1], "r": q[2]})
	var parts: Array = [{"type": "ojo", "t": .94, "ang": .9, "size": h["eyes"] / .2}]
	for i in int(l["pairs"]):
		parts.append({"type": "pata", "t": .42 + i * .27 / maxf(1, l["pairs"] - 1), "ang": 2.1, "w": l["width"], "k": [.25, -l["length"] * .5, .1], "f": [.35, -l["length"], 0]})
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
		if not _obj(p, "parts") or not _int(p.get("level"), 1, 5, "parts.level"):
			return null
		var slot = p.get("slot")
		if typeof(slot) != TYPE_STRING or not mapping.has(slot) or not mapping[slot].has(p.get("type")) or seen.has(slot):
			_fail("parts.type")
			return null
		seen[slot] = true
		var type = mapping[slot][p["type"]]
		if type == null:
			continue
		var tt := .58; var aa := 0.0
		match slot:
			"mouth": tt = 1.0
			"arms": tt = .72
			"tailTip": tt = .05
			"horns": tt = .9
		if slot == "mouth": aa = 0.0
		elif slot == "arms": aa = 1.4
		elif slot == "horns" and p["type"] == "pair": aa = .5
		var n := {"type": type, "t": tt, "ang": aa, "size": .8 + .1 * p["level"]}
		if ["cuerno", "asta", "pua"].has(type):
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
	if not _obj(s.get("colors"), "skin.colors"):
		return null
	var regions: Array = []
	if v == 3:
		if typeof(g.get("regions")) != TYPE_ARRAY:
			_fail("regions")
			return null
		for r in g["regions"]:
			if not _region(r):
				return null
			regions.append(r.duplicate(true))
	if v == 2:
		if not _obj(g.get("growth"), "growth"):
			return null
		var gr: Dictionary = g["growth"].duplicate(true)
		gr["family"] = "horns" if gr.get("family") == "none" else gr.get("family")
		gr["id"] = "region-1"
		gr["surface"] = "torso"
		if not _region(gr):
			return null
		if g["growth"].get("family") != "none":
			regions = [gr]
	if v == 1 and g.has("growth"):
		warnings.append("migration.extra:growth")
	if v != 3 and g.has("regions"):
		warnings.append("migration.extra:regions")
	var src_arms = g.get("arms", {})
	if typeof(src_arms) != TYPE_DICTIONARY or src_arms.is_empty():
		src_arms = {}
	for spec in [["body", b, ["torso", "girth", "neck", "tail"]], ["legs", l, ["pairs", "length", "width", "stride"]], ["head", h, ["size", "eyes"]], ["arms", src_arms, ["length"]], ["skin", s, ["pattern", "colors", "scale", "gloss"]]]:
		for key in spec[1].keys():
			if not spec[2].has(key):
				warnings.append("migration.extra:" + spec[0] + "." + str(key))
	for k in g.keys():
		if not ["schema", "body", "legs", "head", "arms", "parts", "skin", "regions", "growth", "dna", "abilities", "name"].has(k):
			warnings.append("migration.extra:" + str(k))
	var colors: Dictionary = s["colors"]
	var nm = g.get("name")
	return {"schema": SCHEMA, "name": nm if (typeof(nm) == TYPE_STRING and nm != "") else "Migrada",
		"nodes": nodes, "parts": parts,
		"skin": {"pat": pattern, "cA": colors.get("base"), "cB": colors.get("pattern"), "cC": colors.get("belly"), "wet": s.get("gloss"), "scale": s.get("scale")},
		"regions": regions, "migration": {"from": v, "warnings": warnings, "source": g.duplicate(true)}}

## Parse text or Dictionary of any schema /1../4 into a validated v4 document.
static func parse(input, types) -> Dictionary:
	_err = ""
	var g = input
	if typeof(input) == TYPE_STRING:
		var js := JSON.new()
		if js.parse(input) != OK:
			return {"ok": false, "error": "json", "genome": null, "warnings": []}
		g = js.data
		if g == null:
			return {"ok": false, "error": "json", "genome": null, "warnings": []}
	if typeof(g) != TYPE_DICTIONARY:
		return {"ok": false, "error": "document", "genome": null, "warnings": []}
	var sch = g.get("schema")
	if not ["cpore.creature/1", "cpore.creature/2", "cpore.creature/3", "cpore.creature/4", SCHEMA].has(sch):
		return {"ok": false, "error": "schema", "genome": null, "warnings": []}
	var doc = g
	if sch == "cpore.creature/4":
		doc = g.duplicate(true)
		doc.schema = SCHEMA
	elif sch != SCHEMA:
		doc = _migrate(g)
		if doc == null:
			return {"ok": false, "error": _err, "genome": null, "warnings": []}
	if sch != SCHEMA:
		if typeof(doc.get("parts")) != TYPE_ARRAY:
			return {"ok": false, "error": "parts", "genome": null, "warnings": []}
		for part in doc.parts:
			if typeof(part) != TYPE_DICTIONARY:
				return {"ok": false, "error": "parts", "genome": null, "warnings": []}
			part["level"] = 1
			part["tier"] = 0
	var res := validate(doc, types)
	if not res["ok"]:
		res["warnings"] = []
		return res
	var w: Array = []
	if res["genome"].get("migration"):
		w = res["genome"]["migration"]["warnings"]
	res["warnings"] = w
	return res
