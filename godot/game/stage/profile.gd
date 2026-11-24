extends RefCounted
# Combat-only projection of a cpore.creature/4 genome: port of web/engine/profile.js
# (profileFromStudio). Output keys follow the CporeWorld profile schema (radius_cm).

const RULES := [
	{"c_type": "CP4_MOUTH_C", "category": "mouths", "mouth": 2},
	{"c_type": "CP4_MOUTH_O", "category": "mouths", "mouth": 1, "spit": 1},
	{"c_type": "CP4_MOUTH_G", "category": "mouths", "spit": 2},
	{"c_type": "CP4_HORN", "category": "weapons", "charge": 1},
	{"c_type": "CP4_TAIL", "category": "weapons", "tail": 1},
	{"c_type": "CP4_PLATE", "category": "details", "guard": 1},
	{"c_type": "CP4_FIRE", "category": "weapons", "fire": 1},
]
const LEVELS := ["mouth", "charge", "spit", "tail", "guard", "fire"]
const RADIUS_CM_MIN := 40
const RADIUS_CM_MAX := 400
const RADIUS_CM_DEFAULT := 60

# JS Math.round for non-negative values (GDScript round() differs on negative halves).
static func js_round(v: float) -> int:
	return int(floor(v + 0.5))

static func body_radius_cm(nodes) -> int:
	if typeof(nodes) != TYPE_ARRAY or nodes.size() < 2:
		return 0
	var min_z := INF
	var max_z := -INF
	var max_r := 0.0
	for n in nodes:
		if typeof(n) != TYPE_DICTIONARY or not _num(n.get("z")) or not _num(n.get("r")):
			return 0
		min_z = minf(min_z, n.z)
		max_z = maxf(max_z, n.z)
		max_r = maxf(max_r, n.r)
	var cm := js_round(maxf(max_z - min_z, 2.0 * max_r) / 2.0 * 100.0)
	cm = clampi(cm, RADIUS_CM_MIN, RADIUS_CM_MAX)
	return 0 if cm == RADIUS_CM_DEFAULT else cm

static func _num(v) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))

# Returns {ok: true, profile: {...}} or {ok: false, error: String}.
static func from_studio(creature: Dictionary, manifest: Dictionary) -> Dictionary:
	if creature.get("schema", "") not in ["cpore.creature/4", "cpore.creature/5"]:
		return {"ok": false, "error": "expected studio schema cpore.creature/4"}
	var parts = creature.get("parts")
	if typeof(parts) != TYPE_ARRAY or parts.size() > 256:
		return {"ok": false, "error": "invalid studio parts"}
	var mparts = manifest.get("parts")
	if typeof(mparts) != TYPE_ARRAY:
		return {"ok": false, "error": "invalid parts manifest"}
	var catalog := {}
	for p in mparts:
		catalog[p.id] = p
	var result := {"mouth": 0, "charge": 0, "spit": 0, "tail": 0, "guard": 0, "fire": 0, "hp": 100.0, "stamina": 100.0, "speed": 4.0}
	for part in parts:
		var entry = catalog.get(part.get("type", "") if typeof(part) == TYPE_DICTIONARY else "")
		if entry == null:
			return {"ok": false, "error": "unknown studio part: %s" % [part.get("type") if typeof(part) == TYPE_DICTIONARY else part]}
		for rule in RULES:
			if rule.c_type == entry.c_type and rule.category == entry.category:
				for key in LEVELS:
					result[key] = mini(5, result[key] + int(rule.get(key, 0)) * int(part.get("level", 1)))
				break
	result.hp += result.guard * 5
	result["radius_cm"] = body_radius_cm(creature.get("nodes"))
	result.merge(CporeWorld.grip_profile(JSON.stringify(creature)), true)
	return {"ok": true, "profile": result}

static func load_json(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	var v = JSON.parse_string(text)
	return v if typeof(v) == TYPE_DICTIONARY else {}
