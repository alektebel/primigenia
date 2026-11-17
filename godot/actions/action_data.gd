extends RefCounted
## Loads, validates and resolves the action files (godot/actions/data/*.json, schema cpore.action/1,
## docs/godot/PLAN-actions.md section 3). Times inside a resolved action are action time in ticks
## (1 tick = 0.1 s), so a track is a plain piecewise curve of tau.

const Clock := preload("action_clock.gd")

## Channel vocabulary (1.2): the only place where code knows anatomy. Value = default.
const CHANNELS := {
	"root.lunge": 0.0, "root.side": 0.0, "root.lift": 0.0, "root.pitch": 0.0, "root.roll": 0.0, "root.yaw": 0.0,
	"body.inflate": 0.0, "head.pitch": 0.0, "head.yaw": 0.0, "head.roll": 0.0, "neck.coil": 0.0, "head.aim": 0.0,
	"head.reach": 0.0, "jaw.open": 0.0, "jaw.tremble": 0.0, "tail.pitch": 0.0, "tail.yaw": 0.0, "tail.curl": 0.0,
	"tail.stiff": 0.0, "display": 0.0, "arms": 0.0, "lids": 0.0, "sacs": 0.0, "still": 0.0,
}
const GOALS := ["target_surface", "target_head", "target_ground", "ground_front", "forward", "up", "sky_target", "away", "item"]
const EASES := ["lin", "in", "out", "inout", "snap", "hold"]
const CLASSES := ["combat", "reaction", "social", "intimidate", "observe", "idle"]
const DRIVERS := ["c_move", "c_state", "c_event", "cosmetic", "stance", "idle"]
const LEGS := ["free", "plant", "gesture", "hop", "pivot", "brace"]
const TOP_KEYS := ["schema", "id", "class", "driver", "ticks", "settle", "priority", "fade", "legs", "rooted", "side", "tracks", "events", "variants", "note", "on_cancel", "hold", "weight", "min_gap"]
const TRACK_KEYS := ["ch", "goal", "keys", "osc", "env", "kin", "mask", "lag", "signed", "alternate", "if"]
const OSC_KEYS := ["clock", "hz", "amp", "shape", "phase"]
const SEGS := ["w", "a", "r", "s", "hold"]

static func load_all(dir: String) -> Dictionary:
	var out := {}
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var txt := FileAccess.get_file_as_string(dir.path_join(f))
		var js = JSON.parse_string(txt)
		if typeof(js) != TYPE_DICTIONARY:
			push_error("action file %s is not a JSON object" % f)
			continue
		var errs := validate(js, f)
		if not errs.is_empty():
			push_error("action file %s: %s" % [f, "; ".join(errs)])
			continue
		out[js.id] = js
	return out

static func validate(a: Dictionary, file := "") -> Array:
	var e: Array = []
	for k in a:
		if not TOP_KEYS.has(k):
			e.append("%s: unknown key '%s'" % [file, k])
	if a.get("schema", "") != "cpore.action/1":
		e.append("%s: schema must be cpore.action/1" % file)
	if not a.has("id"):
		e.append("%s: missing id" % file)
	if not CLASSES.has(a.get("class", "")):
		e.append("%s: bad class" % file)
	var dr: Dictionary = a.get("driver", {})
	if not DRIVERS.has(dr.get("kind", "")):
		e.append("%s: bad driver.kind" % file)
	if not LEGS.has(a.get("legs", "plant")):
		e.append("%s: bad legs" % file)
	var tr: Array = a.get("tracks", [])
	for i in tr.size():
		_validate_track(tr[i], "%s: tracks[%d]" % [file, i], e)
	for vi in a.get("variants", []).size():
		var v: Dictionary = a.variants[vi]
		for k in v:
			if not ["when", "set", "drop", "ticks", "legs", "settle"].has(k):
				e.append("%s: variants[%d] unknown key '%s'" % [file, vi, k])
		var w = v.get("when", {})
		if typeof(w) != TYPE_DICTIONARY:
			e.append("%s: variants[%d].when must be an object" % [file, vi])
		else:
			for k in w:
				if not ["has", "lacks"].has(k):
					e.append("%s: variants[%d].when unknown key '%s'" % [file, vi, k])
		for j in v.get("set", []).size():
			_validate_track(v.set[j], "%s: variants[%d].set[%d]" % [file, vi, j], e)
	return e

static func _validate_track(t: Dictionary, path: String, e: Array) -> void:
	for k in t:
		if not TRACK_KEYS.has(k):
			e.append("%s unknown key '%s'" % [path, k])
	if not CHANNELS.has(t.get("ch", "")):
		e.append("%s unknown channel '%s'" % [path, t.get("ch", "")])
	if t.has("goal") and not GOALS.has(t.goal):
		e.append("%s unknown goal '%s'" % [path, t.goal])
	if not t.has("keys") and not t.has("osc"):
		e.append("%s needs keys or osc" % path)
	for kn in ["keys", "env"]:
		if t.has(kn):
			var last := -1e9
			var order := {"w": 0, "a": 1, "r": 2, "s": 3, "hold": 4}
			for ki in t[kn].size():
				var k: Array = t[kn][ki]
				if k.size() < 3 or not SEGS.has(k[0]):
					e.append("%s.%s[%d] bad segment" % [path, kn, ki])
					continue
				var key := float(order[k[0]]) + clampf(float(k[1]), 0.0, 1.0) * 0.999
				if key < last - 1e-9:
					e.append("%s.%s[%d] keys out of order" % [path, kn, ki])
				last = key
				if k.size() > 3 and not EASES.has(k[3]):
					e.append("%s.%s[%d] bad ease '%s'" % [path, kn, ki, k[3]])
	if t.has("osc"):
		for k in t.osc:
			if not OSC_KEYS.has(k):
				e.append("%s.osc unknown key '%s'" % [path, k])

## Variants applied for a body whose capability set is `caps` (Array of String). Returns a new dictionary.
static func resolve(a: Dictionary, caps: Array) -> Dictionary:
	var r: Dictionary = a.duplicate(true)
	for v in a.get("variants", []):
		var w: Dictionary = v.get("when", {})
		var ok := true
		for c in w.get("has", []):
			if not caps.has(c):
				ok = false
		for c in w.get("lacks", []):
			if caps.has(c):
				ok = false
		if not ok:
			continue
		for t in v.get("set", []):
			var done := false
			for i in r.tracks.size():
				if r.tracks[i].ch == t.ch and r.tracks[i].get("goal", "") == t.get("goal", ""):
					r.tracks[i] = t.duplicate(true)
					done = true
			if not done:
				r.tracks.append(t.duplicate(true))
		for ch in v.get("drop", []):
			var keep: Array = []
			for t in r.tracks:
				if t.ch != ch:
					keep.append(t)
			r.tracks = keep
		for k in ["ticks", "legs", "settle"]:
			if v.has(k):
				r[k] = v[k]
		break
	return r

## Compiled form: times in ticks.  {id, w, a, r, settle, tracks:[{ch, goal, keys:[[tau, v, ease]], env, osc, kin, mask, lag, signed, alternate, if}], events}
static func compile(a: Dictionary) -> Dictionary:
	var tk: Dictionary = a.get("ticks", {"w": 1, "a": 1, "r": 1})
	var w := float(tk.get("w", 0)); var ac := float(tk.get("a", 0)); var r := float(tk.get("r", 0))
	var settle: float = float(a.get("settle", 0.2)) / Clock.DT
	var c := {"id": a.id, "class": a["class"], "driver": a.driver, "w": w, "a": ac, "r": r, "settle": settle,
		"priority": int(a.get("priority", 40)), "fade": a.get("fade", {}), "legs": a.get("legs", "plant"),
		"rooted": bool(a.get("rooted", false)), "side": a.get("side", 1), "on_cancel": a.get("on_cancel", ""), "hold": bool(a.get("hold", false)),
		"weight": float(a.get("weight", 1.0)), "min_gap": float(a.get("min_gap", 8.0)), "tracks": [], "events": []}
	for t in a.get("tracks", []):
		var ct := {"ch": t.ch, "goal": t.get("goal", ""), "kin": float(t.get("kin", 1.0)), "mask": t.get("mask", -1.0),
			"lag": float(t.get("lag", 0.0)), "signed": bool(t.get("signed", false)), "alternate": bool(t.get("alternate", false)),
			"if": t.get("if", ""), "keys": _keys(t.get("keys", []), w, ac, r, settle), "env": _keys(t.get("env", []), w, ac, r, settle),
			"osc": t.get("osc", {})}
		c.tracks.append(ct)
	for ev in a.get("events", []):
		var at: Array = ev.at
		c.events.append({"tau": Clock.seg_time(at[0], float(at[1]), w, ac, r, settle), "emit": ev.emit})
	return c

static func _keys(ks: Array, w: float, a: float, r: float, settle: float) -> Array:
	var out: Array = []
	for k in ks:
		var tau := 0.0 if k[0] == "hold" else Clock.seg_time(k[0], float(k[1]), w, a, r, settle)
		out.append([tau, float(k[2]), k[3] if k.size() > 3 else "lin"])
	return out

static func ease(kind: String, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	match kind:
		"in": return u * u
		"out": return 1.0 - (1.0 - u) * (1.0 - u)
		"inout": return u * u * (3.0 - 2.0 * u)
	return u

## Piecewise value of a key list at tau (ticks). `snap` reaches its value within 0.02 s (0.2 tick) of the
## interval's end; `hold` stays at the previous value and jumps at the key.
static func curve(keys: Array, tau: float, default := 0.0) -> float:
	var n := keys.size()
	if n == 0:
		return default
	if tau <= keys[0][0]:
		return keys[0][1]
	for i in range(1, n):
		var k1: Array = keys[i]
		if tau <= k1[0] + 1e-9:
			var k0: Array = keys[i - 1]
			var span: float = k1[0] - k0[0]
			if span <= 1e-9:
				return k1[1]
			var u: float = (tau - k0[0]) / span
			match k1[2]:
				"hold":
					return k0[1] if tau < k1[0] else k1[1]
				"snap":
					var win := minf(0.2, span)
					u = clampf((tau - (k1[0] - win)) / win, 0.0, 1.0)
					return lerpf(k0[1], k1[1], u)
			return lerpf(k0[1], k1[1], ease(k1[2], u))
	return keys[n - 1][1]

## clocks: {time: seconds since the instance started, grid_shift: ticks, hit: bool, side: float}
static func sample(t: Dictionary, tau: float, clocks: Dictionary) -> float:
	if t["if"] == "hit" and not clocks.get("hit", false):
		return 0.0
	var v: float = curve(t.keys, tau, 0.0)
	var osc: Dictionary = t.osc
	if not osc.is_empty():
		var env: float = curve(t.env, tau, 1.0) if not t.env.is_empty() else 1.0
		var hz := float(osc.get("hz", 1.0))
		var p: float
		match osc.get("clock", "time"):
			"tick": p = tau * hz
			"beat": p = float(clocks.get("beat_t", tau)) / 12.0 * hz
			"grid": p = (tau - clocks.get("grid_shift", 0.0)) / 3.0 * hz
			_: p = clocks.get("time", 0.0) * hz
		p += float(osc.get("phase", 0.0))
		var o: float
		match osc.get("shape", "sin"):
			"abs": o = absf(sin(PI * p))
			"square": o = 1.0 if sin(TAU * p) >= 0.0 else -1.0
			"pulse": o = maxf(0.0, 1.0 - fposmod(p, 1.0) * 10.0)
			"blink": o = pow(maxf(0.0, sin(TAU * p)), 60.0)
			"noise": o = 0.5 * (sin(TAU * p * 1.0) + sin(TAU * p * 2.37 + 1.3))
			_: o = sin(TAU * p)
		v += float(osc.get("amp", 1.0)) * o * env
	return v
