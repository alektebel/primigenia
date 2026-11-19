class_name CreatureBio
extends RefCounted
## Biology derived from a cpore.creature/4 genome, at build time and only from the genome (no per-creature assets):
##   actuation  how the body moves, from the parts: "muscle" (muscle on an endoskeleton), "hydraulic" (many thin
##              pressurised legs, spiders), "exo" (muscle inside hard armour plates), "hydrostatic" (no legs, soft body)
##   toxic      0..1, from venom parts (aguijon, sac_spitter, tail_spike): the only thing that licenses saturated colour
##   diet       "carn" | "herb" | "omni" from the mouth parts (the parts library c_type)
##   seed       stable per creature (name), so editing parts or colours does not re-roll the pattern
##   palette    the player's own colours, untouched (the creator is authoritative)
## docs/godot/CREATURE-REALISM.md has the rules and the table of actuation systems.

const VENOM := ["aguijon", "sac_spitter", "tail_spike"]
const PLATES := ["placa", "shell_plate"]
const CARN_MOUTHS := ["fauces", "jaw_nipper", "mandible_shear", "pinzas"]
const HERB_MOUTHS := ["romo", "trompa", "snout_trumpet"]
const ARMOUR_PARTS := ["mandible_shear", "pinzas", "jaw_nipper"]

## A24: the body has a skeleton class; each limb has its own actuation among those the skeleton allows.
const SKELETONS := ["endo", "exo", "hydro"]
const SKEL_ALLOWED := {
	"endo": ["muscle", "tendon", "spring", "hydrostat"],
	"exo": ["muscle", "hydraulic", "spring"],
	"hydro": ["peristaltic", "hydrostat", "tubefeet", "cilia"],
}
const ACTUATIONS := ["muscle", "tendon", "spring", "hydrostat", "hydraulic", "peristaltic", "tubefeet", "cilia"]
## Shader mode of a limb: 1 muscle on bone, 2 hydraulic, 3 muscle in exoskeleton, 4 hydrostat, 5 elastic tendon,
## 6 spring-latch, 7 tube feet.
const ACT_MODE := {"muscle": 1.0, "hydraulic": 2.0, "hydrostat": 4.0, "tendon": 5.0, "spring": 6.0, "tubefeet": 7.0,
	"peristaltic": 4.0, "cilia": 4.0}


## Limb class of a part type ("" when it is not a limb in the A24 sense).
static func limb_kind(type: String, is_leg: Callable) -> String:
	if is_leg.call(type):
		return "leg"
	if type.begins_with("arm_"):
		return "arm"
	if type.begins_with("tail_"):
		return "tail"
	if type == "tongue_spring":
		return "tongue"
	if type == "trompa" or type == "snout_trumpet":
		return "trunk"
	if type == "excavadora":
		return "dig"
	return ""


static func _leg_length(p: Dictionary) -> float:
	var k := Vector3(p["k"][0], p["k"][1], p["k"][2]) if p.has("k") else Vector3(0, -.7, 0)
	var f := Vector3(p["f"][0], p["f"][1], p["f"][2]) if p.has("f") else Vector3(0, -1.5, 0)
	return k.length() + (f - k).length()


## genome: validated /4 genome. is_leg: Callable(type) -> bool (CreatureParts.is_leg). lib: parts library entries.
static func derive(genome: Dictionary, is_leg: Callable, lib: Dictionary) -> Dictionary:
	var parts: Array = genome["parts"]
	var n_leg := 0
	var w_sum := 0.0
	var plates := 0
	var armour := 0
	var venom := 0.0
	var carn := 0
	var herb := 0
	var eye_big := false
	for p in parts:
		var t: String = p["type"]
		if is_leg.call(t):
			n_leg += 1
			w_sum += float(p.get("w", .2))
		if t in PLATES:
			plates += 1
		if t in ARMOUR_PARTS:
			armour += 1
		if t in VENOM:
			venom = maxf(venom, .85 if t != "tail_spike" else .5)
		if t == "lure_lantern" or (t in ["ojo", "tallo"] and float(p.get("size", 1.0)) >= 1.35):
			eye_big = true
		if t in CARN_MOUTHS:
			carn += 1
		elif t in HERB_MOUTHS:
			herb += 1
	for r in genome.get("regions", []):
		if str(r.get("family", "")) == "plates":
			plates += 1
	var max_r := .1
	for n in genome["nodes"]:
		max_r = maxf(max_r, float(n["r"]))
	var legs_total := n_leg * 2
	var avg_w := w_sum / maxf(n_leg, 1)
	var thin := legs_total >= 6 and avg_w < max_r * .3
	# ---- skeleton of the body
	var skel_cands := ["endo"]
	var skel_why := "Patas con hueso: esqueleto interno"
	if n_leg == 0:
		skel_cands = ["hydro", "endo"] if plates < 2 else ["hydro", "exo", "endo"]
		skel_why = "Sin patas: esqueleto hidrostático"
	elif plates >= 2 or (plates >= 1 and armour >= 1):
		skel_cands = ["exo", "endo"]
		skel_why = "Placas duras: exoesqueleto"
	elif thin and legs_total >= 8:
		skel_cands = ["exo", "endo"]
		skel_why = "Ocho o más patas finas: exoesqueleto de artrópodo"
	elif plates == 1:
		skel_cands = ["endo", "exo"]
		skel_why = "Una placa suelta: esqueleto interno"
	var skin: Dictionary = genome["skin"]
	var skel: String = skel_cands[0]
	if str(skin.get("sk", "auto")) in skel_cands:
		skel = str(skin["sk"])
	# ---- each limb
	var limbs := {}
	var types := {}
	for i in parts.size():
		var p: Dictionary = parts[i]
		var kind := limb_kind(p["type"], is_leg)
		if kind == "":
			continue
		var c := _limb_candidates(p, kind, skel, legs_total, max_r)
		var act: String = c["cands"][0]
		var chosen := false
		var stored := str(p.get("act", ""))
		if stored != "" and stored in SKEL_ALLOWED[skel]:
			act = stored
			chosen = true
		limbs[i] = {"index": i, "type": p["type"], "kind": kind, "act": act, "cands": c["cands"], "why": c["why"],
			"chosen": chosen, "mode": _mode(act, skel)}
		types[act] = true
	var diet := "omni"
	if carn > herb:
		diet = "carn"
	elif herb > carn:
		diet = "herb"
	# Pupil of a creature from how it lives: ambush predators and night hunters slit, grazers a horizontal bar.
	var pupil := "round"
	if herb > carn:
		pupil = "bar"
	elif carn > herb or eye_big:
		pupil = "slit"
	var seed_ := hash(str(genome.get("name", ""))) & 0x7fffffff
	var pat := int(skin["pat"])
	var out := {
		"skeleton": skel, "skel_cands": skel_cands, "skel_why": skel_why, "limbs": limbs, "act_types": types.size(),
		"actuation": {"endo": "muscle", "exo": "exo", "hydro": "hydrostatic"}[skel],   # body class for the body shader
		"toxic": venom, "diet": diet, "seed": seed_, "pat": pat, "pupil": pupil,
		"legs": legs_total, "plates": plates, "wet": float(skin["wet"]), "body_r": max_r,
	}
	out["palette"] = palette(skin, venom, diet, float(skin["wet"]))
	return out


static func _mode(act: String, skel: String) -> float:
	if act == "muscle" and skel == "exo":
		return 3.0
	return ACT_MODE[act]


## Candidate actuations (best first) of one limb and the reason for the first. More than one candidate = ambiguous:
## the creator then lets the player pick. Every candidate is allowed by the skeleton.
static func _limb_candidates(p: Dictionary, kind: String, skel: String, legs_total: int, max_r: float) -> Dictionary:
	var allowed: Array = SKEL_ALLOWED[skel]
	var cands: Array = []
	var why := ""
	var t: String = p["type"]
	if kind == "leg":
		var L := _leg_length(p)
		var slender := float(p.get("w", .2)) / maxf(L, .1)
		if skel == "hydro":
			cands = ["tubefeet", "hydrostat"]
			why = "Cuerpo hidrostático: pies ambulacrales"
		elif t == "foot_spring":
			cands = ["spring", "muscle"]
			why = "Pie de resorte: mecanismo de cierre elástico"
		elif skel == "exo" and legs_total >= 8:
			cands = ["hydraulic", "muscle"]
			why = "Ocho o más patas finas: presión hidráulica"
		elif skel == "endo" and slender < .075 and L > 2.4 * max_r:
			cands = ["tendon", "muscle"]
			why = "Patas largas y finas: tendones elásticos"
		elif skel == "exo":
			cands = ["muscle", "spring"]
			why = "Patas con segmentos duros: músculo dentro del exoesqueleto"
		else:
			cands = ["muscle"]
			why = "Patas gruesas: músculo sobre hueso"
	elif kind == "arm":
		if t == "arm_smasher" and skel != "hydro":
			cands = ["spring", "muscle"]
			why = "Maza: golpe de resorte (como la galera)"
		elif skel == "hydro":
			cands = ["hydrostat"]
			why = "Brazo sin hueso: hidrostato muscular"
		else:
			cands = ["muscle"]
			why = "Brazo con articulaciones: músculo"
	elif kind == "tail":
		cands = ["peristaltic"] if skel == "hydro" else ["muscle"]
		why = "Cola: ondas del cuerpo" if skel == "hydro" else "Cola: músculo del tronco"
	elif kind == "tongue":
		cands = ["hydrostat", "spring"] if skel == "endo" else (["spring", "hydraulic"] if skel == "exo" else ["hydrostat"])
		why = "Lengua balística: hidrostato o resorte"
	elif kind == "trunk":
		cands = ["hydrostat", "muscle"] if skel == "endo" else (["hydraulic", "muscle"] if skel == "exo" else ["hydrostat"])
		why = "Trompa blanda: hidrostato muscular" if skel != "exo" else "Probóscide: presión hidráulica"
	else:
		cands = ["muscle"] if skel != "hydro" else ["hydrostat"]
		why = "Garra excavadora: músculo"
	var ok: Array = []
	for c in cands:
		if c in allowed:
			ok.append(c)
	if ok.is_empty():
		ok = [allowed[0]]
	return {"cands": ok, "why": why}


# ---------------------------------------------------------------- colour

## The player's colours are authoritative: the palette is returned untouched. Biology only adds light, detail and
## (optional, stored in the genome) countershading and pattern controls on top, never a hue change.
static func palette(skin: Dictionary, _toxic := 0.0, _diet := "", _wet := 0.0) -> Dictionary:
	return {"cA": Color(skin["cA"]), "cB": Color(skin["cB"]), "cC": Color(skin["cC"])}


const LABELS := {"muscle": "músculo", "tendon": "tendón elástico", "spring": "resorte", "hydrostat": "hidrostato", "hydraulic": "hidráulica",
	"peristaltic": "peristáltica", "tubefeet": "pies ambulacrales", "cilia": "cilios", "endo": "esqueleto interno", "exo": "exoesqueleto",
	"hydro": "esqueleto hidrostático"}


static func label(key: String) -> String:
	return LABELS.get(key, key)
