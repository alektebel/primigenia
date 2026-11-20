extends RefCounted
## Wing families and the optional `wing` block of a wing part (motion-flight plan 3a, slices W1-lite/W2/F1).
##
## A wing part entry may carry
##   "wing": {span (m per side at size 1), breadth (chord / span), spars 1..5, anchor "flank"|"hind"|"none",
##            mode "forelimb"|"extra", fold "flank"|"back"|"spread", muscle 0.08..0.25 (flight muscle share of mass)}
## Every key is optional; absent keys (or an absent block) keep today's look: the legacy builders size the wing from the
## body (`size * radius / 0.6`), so saved creatures render as before. Pure data and maths, no nodes.

const FAMILY_IDS := ["wing_glider", "wing_vane", "wing_insect", "wing_flap"]
const KEYS := ["span", "breadth", "spars", "anchor", "mode", "fold", "muscle"]
const ANCHORS := ["flank", "hind", "none"]
const MODES := ["forelimb", "extra"]
const FOLDS := ["flank", "back", "spread"]
const MUSCLE_MIN := 0.08
const MUSCLE_MAX := 0.25

## base_tip: x of the wingtip in the unit-size builder (the rig scales it by `s`); ld: best lift-to-drag ratio (plan table);
## e: Oswald efficiency; stroke: [low, high] stroke angle in degrees; retract: share of span pulled in on the upstroke;
## flaps: false = patagium, glide only; muscle: default flight-muscle share of body mass; breadth0: chord/span of the base shape.
const FAMILIES := {
	"wing_glider": {"base_tip": 2.25, "ld": 8.0, "e": 0.7, "stroke": [70.0, 110.0], "retract": 0.25, "flaps": true, "muscle": 0.15, "pitch_reverse": false},
	"wing_vane": {"base_tip": 2.0, "ld": 11.0, "e": 0.8, "stroke": [70.0, 110.0], "retract": 0.25, "flaps": true, "muscle": 0.16, "pitch_reverse": false},
	"wing_insect": {"base_tip": 2.25, "ld": 5.0, "e": 0.6, "stroke": [90.0, 150.0], "retract": 0.0, "flaps": true, "muscle": 0.2, "pitch_reverse": true},
	"wing_flap": {"base_tip": 1.6, "ld": 2.5, "e": 0.5, "stroke": [0.0, 0.0], "retract": 0.0, "flaps": false, "muscle": 0.08, "pitch_reverse": false},
}


static func is_wing(type: String) -> bool:
	return FAMILIES.has(type)


static func family(type: String) -> Dictionary:
	return FAMILIES.get(type, {})


## The part's wing block with every default filled. `span` and `breadth` are 0.0 when absent (legacy sizing).
static func params(type: String, p: Dictionary) -> Dictionary:
	var f: Dictionary = family(type)
	var w: Dictionary = p.get("wing", {})
	return {
		"span": float(w.get("span", 0.0)), "breadth": float(w.get("breadth", 0.0)),
		"spars": int(w.get("spars", 5)), "anchor": str(w.get("anchor", "flank")), "mode": str(w.get("mode", "forelimb")),
		"fold": str(w.get("fold", "flank")), "muscle": float(w.get("muscle", f.get("muscle", 0.15))),
	}


## "" when the block is valid for `type`, else the failing path suffix (used by creature_genome).
static func validate(type: String, w) -> String:
	if typeof(w) != TYPE_DICTIONARY:
		return "wing"
	if not is_wing(type):
		return "wing.type"
	for k in w.keys():
		if not (k in KEYS):
			return "wing." + str(k)
	for spec in [["span", 0.3, 6.0], ["breadth", 0.12, 1.2], ["muscle", MUSCLE_MIN, MUSCLE_MAX]]:
		if w.has(spec[0]):
			var v = w[spec[0]]
			if not ((typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v)) and float(v) >= spec[1] and float(v) <= spec[2]):
				return "wing." + spec[0]
	if w.has("spars"):
		var s = w["spars"]
		if not ((typeof(s) == TYPE_FLOAT or typeof(s) == TYPE_INT) and float(s) == floor(float(s)) and float(s) >= 1 and float(s) <= 5):
			return "wing.spars"
	if w.has("anchor") and not (w["anchor"] in ANCHORS):
		return "wing.anchor"
	if w.has("mode") and not (w["mode"] in MODES):
		return "wing.mode"
	if w.has("fold") and not (w["fold"] in FOLDS):
		return "wing.fold"
	return ""


## Area of a polygon given as Vector3 points, projected on the wing plane (x span, z chord).
static func polygon_area(pts: Array) -> float:
	var a := 0.0
	var n := pts.size()
	for i in n:
		var p: Vector3 = pts[i]
		var q: Vector3 = pts[(i + 1) % n]
		a += p.x * q.z - q.x * p.z
	return absf(a) * 0.5


## Creates the info block a built wing group carries as meta "wing_info" (everything the flight model needs):
## {type, span (m per side), area (m2 per side), chord, muscle, mode, fold, flaps, ld, e}
static func info(type: String, p: Dictionary, base_area: float, scale_x: float, zk: float) -> Dictionary:
	var f: Dictionary = family(type)
	var w := params(type, p)
	var span: float = float(f.base_tip) * scale_x
	var area: float = base_area * scale_x * scale_x * zk
	return {"type": type, "span": span, "area": area, "chord": area / maxf(span, 1e-6), "muscle": w.muscle, "mode": w.mode, "fold": w.fold,
		"flaps": bool(f.flaps), "ld": float(f.ld), "e": float(f.e), "stroke": f.stroke, "retract": float(f.retract), "pitch_reverse": bool(f.pitch_reverse)}
