extends RefCounted
## Part table from web/studio/parts.json (copy in data/parts.json, kept identical by a test).

var categories: Array = []
var parts: Array = []
var by_id: Dictionary = {}

# Slider ranges, from PLBL in web/creature/rig.js. [min, max]
const RANGES := {"size": [.5, 2.2], "len": [.3, 3.2], "curve": [0.0, 1.3], "w": [.1, .45], "rot": [-PI, PI], "tilt": [-1.3, 1.3]}
const LABELS := {"size": "Tamaño", "len": "Largo", "curve": "Curva", "w": "Grosor", "rot": "Giro", "tilt": "Inclinación"}
const LEG := {"pata": {"w": .2, "k": [.28, -.72, .12], "f": [.38, -1.4, -.02]},
	"zanca": {"w": .13, "k": [.1, -1.1, -.3], "f": [.18, -2.35, .05]},
	"pezuna": {"w": .3, "k": [.08, -.62, .1], "f": [.1, -1.2, 0.0]}}
const LEN_DEFAULT := {"tallo": .7, "antena": 1.1, "asta": 1.2, "cuerno": .9, "pua": .55}

func _init(path: String = "") -> void:
	if path == "":
		path = (get_script() as Script).resource_path.get_base_dir().path_join("data/parts.json")
	var f := FileAccess.open(path, FileAccess.READ)
	assert(f != null, "parts.json missing: " + path)
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	categories = d["categories"]
	parts = d["parts"]
	for p in parts:
		by_id[p["id"]] = p

func has(id) -> bool:
	return by_id.has(id)

func ids_in(category: String) -> Array:
	var out: Array = []
	for p in parts:
		if p["category"] == category:
			out.append(p["id"])
	return out

func display_name(id: String, lang: String) -> String:
	return by_id[id]["name"].get(lang, by_id[id]["name"]["es"])

func is_leg(type: String) -> bool:
	return LEG.has(type)

## Editable numeric params for the part panel (leg types only expose thickness).
func param_keys(type: String) -> Array:
	if is_leg(type):
		return ["w"]
	var keys: Array = ["size"]
	if LEN_DEFAULT.has(type):
		keys.append("len")
	if type == "cuerno":
		keys.append("curve")
	keys.append_array(["rot", "tilt"])
	return keys

## Default part dictionary, mirroring `defaults(type)` in web/creature/rig.js.
func defaults(type: String) -> Dictionary:
	var cat: String = by_id[type]["category"]
	var leg := is_leg(type)
	var fitted: bool = cat == "legs" and not leg
	var t := .62
	if cat == "mouths": t = 1.0
	elif type.begins_with("tail_"): t = .12
	elif type == "eye_triad": t = .92
	elif type == "sac_spitter": t = 1.0
	elif type.begins_with("arm_"): t = .72
	elif cat == "wings": t = .72
	elif leg or fitted: t = .5
	var ang := 0.0
	if cat == "mouths" or type == "eye_triad": ang = 0.0
	elif leg or fitted: ang = 2.1
	elif cat == "wings": ang = 1.3
	elif type.begins_with("arm_"): ang = .95
	var p := {"type": type, "t": t, "ang": ang}
	if leg:
		p["w"] = LEG[type]["w"]
		p["k"] = LEG[type]["k"].duplicate()
		p["f"] = LEG[type]["f"].duplicate()
	else:
		p["size"] = 1.0
	if LEN_DEFAULT.has(type):
		p["len"] = LEN_DEFAULT[type]
	if type == "cuerno":
		p["curve"] = .5
	return p

## Legs and fitted legs keep a lateral position (never centred on the spine).
func is_lateral(type: String) -> bool:
	return is_leg(type) or by_id[type]["category"] == "legs"
