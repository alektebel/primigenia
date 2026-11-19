extends RefCounted
## Studio document model: every UI action goes through here, so headless tests drive the same code.
## History is a list of canonical JSON snapshots; an edit is a transaction (begin/end), so a drag is ONE undo step.

const Genome := preload("genome.gd")
const PartsDB := preload("parts_db.gd")

signal changed(live: bool)       # document changed (live=true while a transaction is open)
signal selection_changed
signal history_changed
signal message(text: String)

const MAX_HISTORY := 100
const MAX_NODES_EDIT := 14   # same cap as the web studio's end-of-spine growth

var parts_db: RefCounted
var doc: Dictionary = {}
var selected := -1
var mode := "build"          # build | paint | test
var playing := false
var _hist: Array = []
var _fut: Array = []
var _depth := 0
var _tx_start := ""
var dirty := false
var selected_region := -1             # index into doc.regions (UI state, not in the history)

const SEEDS := {
	"Hatchling": {"name": "Hatchling", "nodes": [{"y": 0.256, "z": -0.544, "r": 0.03}, {"y": 0.272, "z": -0.396, "r": 0.033}, {"y": 0.296, "z": -0.247, "r": 0.066}, {"y": 0.32, "z": -0.099, "r": 0.115}, {"y": 0.328, "z": 0.066, "r": 0.135}, {"y": 0.344, "z": 0.215, "r": 0.107}, {"y": 0.4, "z": 0.33, "r": 0.11}, {"y": 0.44, "z": 0.446, "r": 0.134}],
		"parts": [{"type": "pico", "t": 1, "ang": 0, "size": 0.3}, {"type": "ojo", "t": 0.9, "ang": 0.95, "size": 0.314}, {"type": "pata", "t": 0.44, "ang": 2.1, "w": 0.05, "k": [0.05, -0.091, 0.066], "f": [0.066, -0.223, -0.008]}, {"type": "pata", "t": 0.7, "ang": 2.1, "w": 0.05, "k": [0.041, -0.115, -0.05], "f": [0.058, -0.239, 0.008]}],
		"skin": {"pat": 1, "cA": "#b0553a", "cB": "#2a1414", "cC": "#e6cfa0", "wet": 0.4, "scale": 4}},
	"Merodeador": {"name": "Merodeador", "nodes": [{"y": 1.6, "z": -3.3, "r": .06}, {"y": 1.7, "z": -2.4, "r": .2}, {"y": 1.85, "z": -1.5, "r": .4}, {"y": 2.0, "z": -.6, "r": .7}, {"y": 2.05, "z": .4, "r": .78}, {"y": 2.15, "z": 1.3, "r": .62}, {"y": 2.5, "z": 2.0, "r": .46}, {"y": 2.75, "z": 2.7, "r": .56}],
		"parts": [{"type": "fauces", "t": 1, "ang": 0, "size": 1.15}, {"type": "ojo", "t": .9, "ang": .95, "size": 1}, {"type": "cuerno", "t": .87, "ang": .4, "size": 1, "len": .9, "curve": .6}, {"type": "pata", "t": .44, "ang": 2.1, "w": .23, "k": [.3, -.55, .4], "f": [.4, -1.35, -.05]}, {"type": "pata", "t": .7, "ang": 2.1, "w": .2, "k": [.25, -.7, -.3], "f": [.35, -1.45, .05]}, {"type": "pua", "t": .5, "ang": 0, "size": 1, "len": .5}, {"type": "pua", "t": .58, "ang": 0, "size": 1, "len": .6}, {"type": "pua", "t": .66, "ang": 0, "size": 1, "len": .5}],
		"skin": {"pat": 1, "cA": "#9a3b28", "cB": "#2a1414", "cC": "#e6cfa0", "wet": .3, "scale": 7}},
	"Zancuda": {"name": "Zancuda", "nodes": [{"y": 2.8, "z": -1.9, "r": .08}, {"y": 2.9, "z": -1.1, "r": .35}, {"y": 2.9, "z": -.2, "r": .72}, {"y": 3.0, "z": .6, "r": .6}, {"y": 3.6, "z": 1.1, "r": .3}, {"y": 4.4, "z": 1.25, "r": .24}, {"y": 5.1, "z": 1.5, "r": .26}, {"y": 5.35, "z": 2.0, "r": .36}],
		"parts": [{"type": "pico", "t": 1, "ang": 0, "size": 1}, {"type": "ojo", "t": .92, "ang": 1.1, "size": 1.25}, {"type": "zanca", "t": .4, "ang": 2.2, "w": .14, "k": [.1, -1.05, .45], "f": [.18, -2.2, .05]}, {"type": "aleta", "t": .42, "ang": 0, "size": 1.3}, {"type": "antena", "t": .9, "ang": .35, "size": 1, "len": .9}, {"type": "cresta", "t": .93, "ang": 0, "size": .9}],
		"skin": {"pat": 3, "cA": "#3d5fa8", "cB": "#8a4fb0", "cC": "#f0e6c8", "wet": .45, "scale": 9}},
	"Babosa": {"name": "Babosa", "nodes": [{"y": .5, "z": -2, "r": .15}, {"y": .6, "z": -1.1, "r": .5}, {"y": .7, "z": -.1, "r": .72}, {"y": .8, "z": .9, "r": .66}, {"y": 1.2, "z": 1.6, "r": .5}, {"y": 1.5, "z": 2.1, "r": .5}],
		"parts": [{"type": "romo", "t": 1, "ang": 0, "size": 1.2}, {"type": "tallo", "t": .88, "ang": .5, "size": 1.2, "len": .8}, {"type": "maza", "t": 0, "ang": 0, "size": .9}, {"type": "placa", "t": .4, "ang": 0, "size": 1}, {"type": "placa", "t": .55, "ang": 0, "size": 1.1}],
		"skin": {"pat": 2, "cA": "#5d8a3a", "cB": "#203818", "cC": "#e9e2a8", "wet": .7, "scale": 11}},
}
const PALETTES := [["#9a3b28", "#2a1414", "#e6cfa0"], ["#2f8a5a", "#12382c", "#e9e2a8"], ["#3d5fa8", "#8a4fb0", "#f0e6c8"], ["#c9892b", "#4a2a12", "#f3e3b8"], ["#6c7440", "#2f3320", "#d8cfa6"], ["#22313f", "#d9a441", "#c8d2d8"], ["#b84a6a", "#3a1830", "#f2d9c9"]]
const REGION_DEFAULTS := {"schema": "cpore.growth/1", "family": "horns", "seed": 17, "count": 7, "length": 1.0, "curve": .45, "branches": 1,
	"surface": "torso", "position": .6, "coverage": .4, "angle": .55, "mirror": true}
const MAX_REGIONS := 64
const PATTERNS := ["liso", "rayas", "manchas", "veteado"]

func _init(db: RefCounted = null) -> void:
	parts_db = db if db else PartsDB.new()
	new_from_seed("Merodeador", false)

static func seed_doc(seed_name: String) -> Dictionary:
	var d: Dictionary = SEEDS[seed_name].duplicate(true)
	d["schema"] = Genome.SCHEMA
	d["regions"] = []
	for part in d.parts:
		part["level"] = 1
		part["tier"] = 0
	return d

## Canonical text of a document (ints and floats are not distinguished, as in JSON itself).
static func snapshot_of(d: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(d)), "", true)

func snapshot() -> String:
	return snapshot_of(doc)

# ---------------------------------------------------------------- history
func begin() -> void:
	if _depth == 0:
		_tx_start = snapshot()
	_depth += 1

func end() -> void:
	_depth -= 1
	if _depth > 0:
		return
	_depth = 0
	var now := snapshot()
	if now == _tx_start:
		return
	_hist.append(_tx_start)   # state before the edit
	if _hist.size() > MAX_HISTORY:
		_hist.pop_front()
	_fut.clear()
	dirty = true
	history_changed.emit()
	changed.emit(false)

## Abort an open transaction (Escape during a drag), restoring the starting state.
func cancel() -> void:
	if _depth == 0:
		return
	_depth = 0
	doc = JSON.parse_string(_tx_start)
	_clamp_selection()
	changed.emit(false)

func can_undo() -> bool:
	return _hist.size() > 0

func can_redo() -> bool:
	return _fut.size() > 0

func undo() -> bool:
	if _hist.is_empty():
		return false
	_fut.append(snapshot())
	doc = JSON.parse_string(_hist.pop_back())
	_after_restore()
	return true

func redo() -> bool:
	if _fut.is_empty():
		return false
	_hist.append(snapshot())
	doc = JSON.parse_string(_fut.pop_back())
	_after_restore()
	return true

func _after_restore() -> void:
	dirty = true
	_clamp_selection()
	history_changed.emit()
	changed.emit(false)

func _clamp_selection() -> void:
	if selected >= doc["parts"].size():
		selected = -1
		selection_changed.emit()

func clear_history() -> void:
	_hist.clear()
	_fut.clear()
	history_changed.emit()

func _touch() -> void:
	changed.emit(_depth > 0)

# ---------------------------------------------------------------- document
func new_from_seed(seed_name: String, record := true) -> void:
	_replace(seed_doc(seed_name), record)

func _replace(d: Dictionary, record: bool) -> void:
	begin()
	doc = d
	selected = -1
	selected_region = 0 if d.get("regions", []).size() > 0 else -1
	selection_changed.emit()
	end()
	if not record:
		clear_history()
		dirty = false
		changed.emit(false)

## Import any /1../4 document through the validator. Returns {ok, error, warnings}.
func import_doc(input) -> Dictionary:
	var res := Genome.parse(input, parts_db.by_id)
	if res["ok"]:
		_replace(res["genome"], true)
	return res

func get_doc() -> Dictionary:
	return doc.duplicate(true)

func validate() -> Dictionary:
	return Genome.validate(doc, parts_db.by_id)

func to_json() -> String:
	return JSON.stringify(doc, " ", true)

func set_name_(n: String) -> void:
	begin()
	doc["name"] = n.substr(0, 80)
	end()

func select(i: int) -> void:
	if i == selected:
		return
	selected = i
	selection_changed.emit()

func set_mode(m: String) -> void:
	mode = m
	if m != "build":
		select(-1)
	if m != "test":
		playing = false
	changed.emit(false)

func set_playing(p: bool) -> void:
	playing = p and mode == "test"
	changed.emit(false)

# ---------------------------------------------------------------- parts
const LEG_MIN_SIN := .2
const MID_MIN_SIN := .14

## Web `place` rule: abs(ang), keep legs off the midline and mid parts snapped to it.
func _fit_ang(type: String, ang: float) -> float:
	var a := absf(ang)
	if parts_db.is_lateral(type):
		if absf(sin(a)) < LEG_MIN_SIN:
			a = .2 if a < 1.57 else PI - .2
	elif absf(sin(a)) < MID_MIN_SIN:
		a = 0.0 if cos(a) > 0 else PI
	return a

func add_part(type: String, t := -1.0, ang := NAN, params := {}) -> int:
	if not parts_db.has(type) or doc["parts"].size() >= 256:
		return -1
	begin()
	var p: Dictionary = parts_db.defaults(type)
	if t >= 0.0:
		p["t"] = clampf(t, 0.0, 1.0)
	if not is_nan(ang):
		p["ang"] = _fit_ang(type, ang)
	for k in params:
		p[k] = params[k]
	doc["parts"].append(p)
	selected = doc["parts"].size() - 1
	selection_changed.emit()
	_touch()
	end()
	return selected

func remove_part(i: int) -> bool:
	if i < 0 or i >= doc["parts"].size():
		return false
	begin()
	doc["parts"].remove_at(i)
	if selected == i:
		selected = -1
		selection_changed.emit()
	elif selected > i:
		selected -= 1
		selection_changed.emit()
	_touch()
	end()
	return true

func place_part(i: int, t: float, ang: float) -> void:
	begin()
	var p: Dictionary = doc["parts"][i]
	p["t"] = clampf(t, 0.0, 1.0)
	p["ang"] = _fit_ang(p["type"], ang)
	_touch()
	end()

## Leg knee ("k") or foot ("f") position relative to the hip (web joint handles).
func set_leg_joint(i: int, key: String, value: Array) -> void:
	if key != "k" and key != "f":
		return
	begin()
	doc["parts"][i][key] = value
	_touch()
	end()

func nudge_part(i: int, dt: float, dang: float) -> void:
	begin()
	var p: Dictionary = doc["parts"][i]
	p["t"] = clampf(p["t"] + dt, 0.0, 1.0)
	p["ang"] = clampf(p["ang"] + dang, 0.0, PI)
	_touch()
	end()

func set_param(i: int, key: String, value: float) -> void:
	if not PartsDB.RANGES.has(key):
		return
	begin()
	var p: Dictionary = doc["parts"][i]
	var r: Array = PartsDB.RANGES[key]
	p[key] = clampf(value, r[0], r[1])
	_touch()
	end()

## Wheel scaling of one part (creator direct manipulation). `factor` multiplies the part's size; a leg scales its
## reach (knee and foot vectors) and thickness together. Clamped to the genome limits. The mirrored pair is one genome
## entry, so both sides follow. Returns {kind: "size"|"reach", value, at_limit, changed}.
const LEG_REACH_MIN := .5
const LEG_REACH_MAX := 6.0

func scale_part(i: int, factor: float) -> Dictionary:
	if i < 0 or i >= doc["parts"].size():
		return {}
	var p: Dictionary = doc["parts"][i]
	var out := {"kind": "size", "value": 0.0, "at_limit": false, "changed": false}
	begin()
	if parts_db.is_leg(p["type"]):
		var r: Array = PartsDB.RANGES["w"]
		var k: Array = p["k"]
		var f: Array = p["f"]
		var reach := Vector3(f[0], f[1], f[2]).length()
		var fac := clampf(reach * factor, LEG_REACH_MIN, LEG_REACH_MAX) / maxf(reach, 1e-6)
		var w := clampf(float(p.get("w", .2)) * fac, r[0], r[1])
		var changed: bool = absf(fac - 1.0) > 1e-6
		if changed:
			p["k"] = [k[0] * fac, k[1] * fac, k[2] * fac]
			p["f"] = [f[0] * fac, f[1] * fac, f[2] * fac]
			p["w"] = w
		out["kind"] = "reach"
		out["value"] = reach * fac
		out["at_limit"] = absf(fac - factor) > 1e-6
		out["changed"] = changed
	elif p.has("size"):
		var r2: Array = PartsDB.RANGES["size"]
		var want: float = float(p["size"]) * factor
		var v := clampf(want, r2[0], r2[1])
		out["changed"] = absf(v - float(p["size"])) > 1e-6
		out["at_limit"] = absf(v - want) > 1e-9
		p["size"] = v
		out["value"] = v
	_touch()
	end()
	return out

## Optional per-part genome keys of the realism round: act (limb actuation), single (-1 / 0 / 1: only that side),
## pupil (auto, round, slit, bar). Absent = default; "auto" / 0 remove the key so old genomes stay byte-identical.
func set_part_key(i: int, key: String, value) -> void:
	set_part_keys([i], key, value)

## Same, for several parts in one undo step (the creator groups identical limbs).
func set_part_keys(idx: Array, key: String, value) -> void:
	if not key in ["act", "single", "pupil"]:
		return
	begin()
	for i in idx:
		_set_part_key(int(i), key, value)
	_touch()
	end()

## The actuator ring of a limb (A24, creator direct manipulation). Four choices, each tied to the body skeleton the
## realism layer derives (`creature_bio.gd`): muscle on bone (endo), muscle in an exoskeleton (exo), hydraulic (exo),
## hydrostat (endo or hydro). `bio` is `creature.bio`. Returns [{id, act, skels, allowed, current}]; a choice is
## allowed when some skeleton the body can take (`skel_cands`, or the current one) carries it.
const RING := [["muscle", "muscle", ["endo"]], ["hydraulic", "hydraulic", ["exo"]], ["exo", "muscle", ["exo"]], ["hydrostat", "hydrostat", ["endo", "hydro"]]]

func actuation_options(bio: Dictionary, i: int) -> Array:
	var out := []
	if bio.is_empty() or not bio["limbs"].has(i):
		return out
	var L: Dictionary = bio["limbs"][i]
	var skel: String = bio["skeleton"]
	var cands: Array = bio["skel_cands"]
	for r in RING:
		var ok := false
		for s in r[2]:
			ok = ok or s == skel or s in cands
		var cur: bool = L["act"] == r[1] and skel in r[2]
		out.append({"id": r[0], "act": r[1], "skels": r[2], "allowed": ok, "current": cur})
	return out

## Apply a ring choice to limb `i` in one undo step. Switches the body skeleton only when the choice needs another one.
func set_limb_actuation(bio: Dictionary, i: int, id: String) -> bool:
	for o in actuation_options(bio, i):
		if o["id"] != id or not o["allowed"]:
			continue
		var skel: String = bio["skeleton"]
		var cands: Array = bio["skel_cands"]
		begin()
		if not skel in o["skels"]:
			for s in o["skels"]:
				if s in cands:
					set_skin("sk", s)
					break
		_set_part_key(i, "act", o["act"])
		_touch()
		end()
		return true
	return false

func _set_part_key(i: int, key: String, value) -> void:
	if i < 0 or i >= doc["parts"].size():
		return
	var p: Dictionary = doc["parts"][i]
	if value == null or (typeof(value) == TYPE_STRING and value == "auto") or (key == "single" and int(value) == 0):
		p.erase(key)
	else:
		p[key] = int(value) if key == "single" else str(value)

# ---------------------------------------------------------------- spine
## Port of moveNode(): neighbour distance clamp .3..1.95, grows or shrinks the end vertebrae.
## Returns the index of the node being dragged (it changes when a vertebra is added at an end).
func move_node(i: int, y: float, z: float) -> int:
	begin()
	var out := _move_node(i, y, z)
	end()
	return out

func _move_node(i: int, y: float, z: float) -> int:
	var N: Array = doc["nodes"]
	var n: Dictionary = N[i]
	var a := Vector2(y, z)
	for j in [i - 1, i + 1]:
		if j < 0 or j >= N.size():
			continue
		var b := Vector2(N[j]["y"], N[j]["z"])
		var d := a.distance_to(b)
		if d < .3 or d > 1.95:
			a = b + (a - b).normalized() * clampf(d, .3, 1.95)
	n["y"] = clampf(a.x, n["r"] + .1, 20.0)
	n["z"] = clampf(a.y, -30.0, 30.0)
	var out := i
	var is_end: bool = i == 0 or i == N.size() - 1
	if is_end:
		var j := 1 if i == 0 else N.size() - 2
		var m: Dictionary = N[j]
		var d := Vector2(n["y"] - m["y"], n["z"] - m["z"]).length()
		if d > 1.5 and N.size() < MAX_NODES_EDIT:
			N.insert(1 if i == 0 else N.size() - 1, {"y": (n["y"] + m["y"]) / 2, "z": (n["z"] + m["z"]) / 2, "r": (n["r"] + m["r"]) / 2})
			if i != 0:
				out = N.size() - 1
		elif d < .34 and N.size() > 4:
			var k := 2 if i == 0 else N.size() - 3
			var q: Dictionary = N[k]
			if Vector2(n["y"] - q["y"], n["z"] - q["z"]).length() < 1.45:
				N.remove_at(j)
				if i != 0:
					out = N.size() - 1
	_touch()
	return out

## Drag of a spine end (neck/head = last node, tail = node 0): the end follows (y, z) with the usual spacing rules,
## which add or remove end vertebrae, and the two vertebrae behind it lean along (50 % and 25 % of the sideways part of
## the move; the part along the segment extends by vertebrae instead), so the neck or tail bends. Returns the index of
## the end node afterwards.
func bend_end(i: int, y: float, z: float) -> int:
	var N: Array = doc["nodes"]
	if i != 0 and i != N.size() - 1:
		return i
	var head: bool = i != 0
	var old := Vector2(N[i]["y"], N[i]["z"])
	var nb: int = i - 1 if head else 1
	var axis := (old - Vector2(N[nb]["y"], N[nb]["z"])).normalized()
	begin()
	var out := _move_node(i, y, z)
	N = doc["nodes"]
	var moved := Vector2(N[out]["y"], N[out]["z"]) - old
	moved -= axis * moved.dot(axis)   # only the sideways part bends the neighbours; the axial part extends by vertebrae
	for step in 2:
		var k: int = out - 1 - step if head else out + 1 + step
		if k <= 0 or k >= N.size() - 1:
			continue   # never drag the opposite end (only reached on a 4-node spine)
		var w: float = .5 if step == 0 else .25
		_move_node(k, N[k]["y"] + moved.x * w, N[k]["z"] + moved.y * w)
	_touch()
	end()
	return out

func set_node_radius(i: int, r: float) -> void:
	begin()
	doc["nodes"][i]["r"] = clampf(r, .05, 1.7)
	_touch()
	end()

func can_add_vertebra() -> bool:
	return doc["nodes"].size() < 32

func can_remove_vertebra() -> bool:
	return doc["nodes"].size() > 4

## Insert a vertebra after node i (midpoint of segment i..i+1).
func add_vertebra(i: int) -> bool:
	var N: Array = doc["nodes"]
	if not can_add_vertebra() or i < 0 or i >= N.size() - 1:
		return false
	begin()
	var a: Dictionary = N[i]; var b: Dictionary = N[i + 1]
	N.insert(i + 1, {"y": (a["y"] + b["y"]) / 2, "z": (a["z"] + b["z"]) / 2, "r": (a["r"] + b["r"]) / 2})
	_touch()
	end()
	return true

func remove_vertebra(i: int) -> bool:
	var N: Array = doc["nodes"]
	if not can_remove_vertebra() or i < 0 or i >= N.size():
		return false
	begin()
	N.remove_at(i)
	_touch()
	end()
	return true

# ---------------------------------------------------------------- paint
func set_skin(key: String, value) -> void:
	begin()
	var s: Dictionary = doc["skin"]
	match key:
		"pat": s[key] = clampi(int(value), 0, 3)
		"wet": s[key] = clampf(value, 0.0, 1.0)
		"scale": s[key] = clampf(value, 3.0, 14.0)
		"cA", "cB", "cC": s[key] = str(value).to_lower()
		"cs", "pc": s[key] = clampf(value, 0.0, 1.0)      # countershading, pattern contrast (realism pilot)
		"ps": s[key] = clampf(value, 0.5, 2.0)            # pattern scale
		"sk": s[key] = str(value) if str(value) in ["auto", "endo", "exo", "hydro"] else "auto"   # body skeleton choice
		"ros": s[key] = clampi(int(value), 0, 1)          # spots become rosettes
	_touch()
	end()

func apply_palette(i: int) -> void:
	begin()
	var p: Array = PALETTES[i]
	doc["skin"]["cA"] = p[0]; doc["skin"]["cB"] = p[1]; doc["skin"]["cC"] = p[2]
	_touch()
	end()

# ---------------------------------------------------------------- growth regions (web growthPanel)
func _next_region_id() -> String:
	var n := 1
	while doc["regions"].any(func(r): return r["id"] == "region-%d" % n):
		n += 1
	return "region-%d" % n

func add_region(duplicate := false) -> int:
	if doc["regions"].size() >= MAX_REGIONS:
		return -1
	begin()
	var r: Dictionary = (doc["regions"][selected_region] if duplicate and selected_region >= 0 else REGION_DEFAULTS).duplicate(true)
	r["id"] = _next_region_id()
	doc["regions"].append(r)
	selected_region = doc["regions"].size() - 1
	selected = -1
	selection_changed.emit()
	_touch()
	end()
	return selected_region

func delete_region() -> void:
	if selected_region < 0 or selected_region >= doc["regions"].size():
		return
	begin()
	doc["regions"].remove_at(selected_region)
	selected_region = mini(selected_region, doc["regions"].size() - 1)
	_touch()
	end()

func set_region(key: String, value) -> void:
	if selected_region < 0 or selected_region >= doc["regions"].size():
		return
	begin()
	var r: Dictionary = doc["regions"][selected_region]
	match key:
		"family", "surface": r[key] = str(value)
		"mirror": r[key] = bool(value)
		"count": r[key] = clampi(int(value), 1, 18)
		"branches": r[key] = clampi(int(value), 0, 3)
		"length": r[key] = clampf(value, .2, 2.4)
		"curve": r[key] = clampf(value, -1.0, 1.0)
		"position", "coverage": r[key] = clampf(value, 0.0, 1.0)
		"angle": r[key] = clampf(value, -PI, PI)
	_touch()
	end()

func vary_region() -> void:
	if selected_region >= 0 and selected_region < doc["regions"].size():
		begin()
		doc["regions"][selected_region]["seed"] = (int(doc["regions"][selected_region]["seed"]) + 1) % 4294967296
		_touch()
		end()

# ---------------------------------------------------------------- random creature (web randomCreature)
static func random_doc(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var names := SEEDS.keys()
	var d := seed_doc(names[seed_value % names.size()])
	d["name"] = "Creature %d" % seed_value
	for n in d["nodes"]:
		n["r"] = clampf(float(n["r"]) * (.8 + rng.randf() * .4), .05, 1.7)
		n["y"] = float(n["y"]) + rng.randf() * .15
	d["skin"]["pat"] = rng.randi() % 4
	return d

func new_random(seed_value := -1) -> void:
	if seed_value < 0:
		seed_value = randi()
	_replace(random_doc(seed_value), true)
