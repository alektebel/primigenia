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
const ARMOUR_PARTS := ["mandible_shear", "pinzas", "jaw_nipper"]



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
		var ct := str(lib.get(t, {}).get("c_type", ""))
		if ct == "CP4_MOUTH_C":
			carn += 1
		elif ct == "CP4_MOUTH_G":
			herb += 1
	for r in genome.get("regions", []):
		if str(r.get("family", "")) == "plates":
			plates += 1
	var max_r := .1
	for n in genome["nodes"]:
		max_r = maxf(max_r, float(n["r"]))
	var legs_total := n_leg * 2          # every leg part is a mirrored pair unless centred (legs always mirror)
	var avg_w := w_sum / maxf(n_leg, 1)
	var actuation := "muscle"
	if n_leg == 0:
		actuation = "hydrostatic"
	elif plates >= 2 or (plates >= 1 and armour >= 1):
		actuation = "exo"
	elif legs_total >= 6 and avg_w < max_r * .3:
		actuation = "hydraulic"
	# Classes the parts allow; the player may choose among them (skin.act), "auto" takes the first.
	var allowed := [actuation]
	if n_leg > 0:
		if plates >= 1 and not "exo" in allowed:
			allowed.append("exo")
		if legs_total >= 6 and avg_w < max_r * .45 and not "hydraulic" in allowed:
			allowed.append("hydraulic")
		if not "muscle" in allowed and actuation != "hydrostatic":
			allowed.append("muscle")
	var chosen := str(genome["skin"].get("act", "auto"))
	if chosen in allowed:
		actuation = chosen
	var diet := "omni"
	if carn > herb:
		diet = "carn"
	elif herb > carn:
		diet = "herb"
	var skin: Dictionary = genome["skin"]
	var seed_ := hash(str(genome.get("name", ""))) & 0x7fffffff
	var pat := int(skin["pat"])
	var out := {
		"actuation": actuation, "toxic": venom, "diet": diet, "seed": seed_, "pat": pat,
		"legs": legs_total, "plates": plates, "wet": float(skin["wet"]),
		"body_r": max_r, "allowed": allowed,
	}
	out["palette"] = palette(skin, venom, diet, float(skin["wet"]))
	return out


# ---------------------------------------------------------------- colour

## The player's colours are authoritative: the palette is returned untouched. Biology only adds light, detail and
## (optional, stored in the genome) countershading and pattern controls on top, never a hue change.
static func palette(skin: Dictionary, _toxic := 0.0, _diet := "", _wet := 0.0) -> Dictionary:
	return {"cA": Color(skin["cA"]), "cB": Color(skin["cB"]), "cC": Color(skin["cC"])}


## Plain-language reason for the actuation class, shown in the creator (Spanish source strings, i18n key = text).
static func actuation_reason(b: Dictionary) -> String:
	match b["actuation"]:
		"hydrostatic": return "Sin patas: esqueleto hidrostático, avanza por ondas de músculo"
		"exo": return "Placas duras: músculo dentro de un exoesqueleto"
		"hydraulic": return "Muchas patas finas: patas hidráulicas a presión"
	return "Patas gruesas: músculo sobre esqueleto interno"


static func actuation_label(b: Dictionary) -> String:
	return {"muscle": "músculo", "hydraulic": "hidráulica", "exo": "exoesqueleto", "hydrostatic": "hidrostática"}[b["actuation"]]
