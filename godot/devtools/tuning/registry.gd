extends RefCounted
## D4 live tuning registry + A/B (PLAN-devtools step 10).
## Entry: {key, group, min, max, step, default, get: Callable, set: Callable, sim: bool}. C parameters (key
## "sim/<name>", from CporeWorld.params()) are set through PARAM debug ops, so they are logged and replayable;
## GDScript parameters (camera, locomotion) are presentation only and never reach C.
## A diff is {format, base_build, values: {key: value}, reason}; the A/B pair holds two diffs, swap applies the other.

const FORMAT := "primigenia.tuning/1"
const DBG_PARAM := 7
const DEV_DIR := "res://tuning"
const USER_DIR := "user://tuning"
const CAMERA := {"lead": [0.0, 0.5, 0.01], "pos_tau": [0.02, 0.5, 0.01], "vel_tau": [0.02, 0.6, 0.01], "yaw_tau": [0.1, 2.0, 0.05],
	"yaw_max": [0.5, 6.0, 0.05], "yaw_acc": [1.0, 20.0, 0.5], "away_max": [0.5, 3.1, 0.05], "pivot_rate": [0.5, 8.0, 0.1],
	"engage_time": [0.0, 1.0, 0.01], "engage_tol": [0.05, 1.0, 0.01]}
const LOCO := {"vault_gain": [0.0, 2.0, 0.05], "leg_axis_torque": [0.0, 1.0, 0.05], "bank_gain": [0.0, 2.0, 0.05],
	"stability_gain": [0.0, 2.0, 0.05], "girdle_gain": [0.0, 0.3, 0.005]}

var entries := {}
var order: Array = []
var slots := {"A": {}, "B": {}}
var slot_names := {"A": "", "B": ""}
var active := "A"
var stage = null
var island = null
var user_dir := USER_DIR
var dev_dir := DEV_DIR      # tests point it at a missing folder so they write under user://

func add(key: String, group: String, lo: float, hi: float, step: float, def: float, getter: Callable, setter: Callable, sim := false) -> void:
	entries[key] = {"key": key, "group": group, "min": lo, "max": hi, "step": step, "default": def, "get": getter, "set": setter, "sim": sim}
	if not order.has(key):
		order.append(key)

func bind_sim(st) -> void:
	stage = st
	for p in CporeWorld.params():
		var idx: int = p.index
		add("sim/" + p.name, "movement", p.min, p.max, (p.max - p.min) / 200.0, p.default,
			func(): return stage.world.param(idx),
			func(v): stage.debug_now({"op": DBG_PARAM, "a": idx, "v": v}), true)

func bind_island(isl) -> void:
	island = isl
	for k in CAMERA:
		var c: Array = CAMERA[k]
		var prop: String = k.to_upper()
		var def: float = float(island.chase.get(prop)) if island.chase != null and island.chase.get(prop) != null else 0.0
		add("camera/" + k, "camera", c[0], c[1], c[2], def,
			func(): return float(island.chase.get(prop)) if island.chase != null else 0.0,
			func(v): if island.chase != null: island.chase.set(prop, v))
	for k in LOCO:
		var c: Array = LOCO[k]
		var prop: String = k
		add("loco/" + k, "locomotion", c[0], c[1], c[2], _loco_default(prop),
			func(): return _loco_get(prop),
			func(v): _loco_set(prop, v))

	if island.get("flight") != null:
		island.flight.bind_tuning(self)

func _controller():
	if island == null or not island.hosts.has(0):
		return null
	var d = island.hosts[0].get("driver")
	return d.get("controller") if d != null else null

func _loco_default(prop: String) -> float:
	var c = _controller()
	return float(c.get(prop)) if c != null and c.get(prop) != null else {"vault_gain": 1.0, "leg_axis_torque": 0.25, "bank_gain": 0.7, "stability_gain": 0.9, "girdle_gain": 0.085}[prop]

func _loco_get(prop: String) -> float:
	var c = _controller()
	return float(c.get(prop)) if c != null else _loco_default(prop)

func _loco_set(prop: String, v: float) -> void:
	for h in island.hosts.values():
		var d = h.get("driver")
		var c = d.get("controller") if d != null else null
		if c != null:
			c.set(prop, v)

func value(key: String) -> float:
	return float(entries[key].get.call())

func set_value(key: String, v: float) -> String:
	if not entries.has(key):
		return "unknown parameter '%s' (tune list shows them)" % key
	var e: Dictionary = entries[key]
	e.set.call(clampf(v, e.min, e.max))
	return ""

func reset(key: String) -> void:
	if entries.has(key):
		entries[key].set.call(entries[key].default)

func is_changed(key: String) -> bool:
	return absf(value(key) - float(entries[key].default)) > 1e-6

func current_values() -> Dictionary:
	var out := {}
	for k in order:
		if is_changed(k):
			out[k] = snappedf(value(k), 1e-6)
	return out

func diff(reason := "") -> Dictionary:
	return {"format": FORMAT, "base_build": _build(), "values": current_values(), "reason": reason}

static func _build() -> String:
	var p := "res://devtools/build.txt"
	return FileAccess.get_file_as_string(p).strip_edges() if FileAccess.file_exists(p) else "unknown"

## Everything back to defaults, then the diff's values.
func apply(d: Dictionary) -> String:
	if str(d.get("format", "")) != FORMAT:
		return "tuning file: format '%s' is not %s" % [d.get("format", ""), FORMAT]
	for k in order:
		if is_changed(k):
			reset(k)
	for k in d.get("values", {}):
		var err := set_value(k, float(d.values[k]))
		if err != "":
			return err
	return ""

func store_active() -> void:
	slots[active] = current_values()

func swap() -> String:
	store_active()
	var other := "B" if active == "A" else "A"
	var err := apply({"format": FORMAT, "values": slots[other]})
	if err == "":
		active = other
	return err

func chip() -> String:
	if active == "B" or not slots.B.is_empty():
		return "Tuning %s: %s" % [active, slot_names[active] if slot_names[active] != "" else ("%d changed" % slots[active].size())]
	return ""

func state() -> Dictionary:
	store_active()
	return {"active": active, "A": slots.A.duplicate(), "B": slots.B.duplicate(), "names": slot_names.duplicate()}

func restore_state(s: Dictionary) -> String:
	slots.A = s.get("A", {})
	slots.B = s.get("B", {})
	slot_names = s.get("names", {"A": "", "B": ""})
	active = s.get("active", "A")
	return apply({"format": FORMAT, "values": slots[active]})

func save_file(name: String, reason := "") -> String:
	var dir := dev_dir if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(dev_dir)) else user_dir
	var real := ProjectSettings.globalize_path(dir)
	DirAccess.make_dir_recursive_absolute(real)
	var path := "%s/%s.json" % [dir, name]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(diff(reason), "\t"))
	f.close()
	return path

func load_file(name: String) -> String:
	for dir in [dev_dir, user_dir]:
		var p := "%s/%s.json" % [dir, name]
		if FileAccess.file_exists(p):
			var v = JSON.parse_string(FileAccess.get_file_as_string(p))
			if typeof(v) != TYPE_DICTIONARY:
				return "tuning file %s is not a JSON object" % p
			var err := apply(v)
			if err == "":
				slot_names[active] = name
			return err
	return "no tuning file '%s' (looked in %s and %s)" % [name, dev_dir, user_dir]

func register_commands(r) -> void:
	r.services["tuning"] = self
	r.register("tune", "<param> <value> | list | reset [param] | save <name> | load <name>", "live tuning (F3 panel)", func(a):
		if a.size() == 0 or a[0] == "list":
			var lines := PackedStringArray()
			for k in order:
				lines.append("  %-26s %s  (default %s, %s..%s)" % [k, snappedf(value(k), 0.0001), snappedf(entries[k].default, 0.0001), entries[k].min, entries[k].max])
			return r.ok("\n".join(lines) if not lines.is_empty() else "no parameters yet (start the island)")
		if a[0] == "reset":
			if a.size() > 1:
				reset("sim/" + a[1] if entries.has("sim/" + a[1]) else a[1])
			else:
				apply({"format": FORMAT, "values": {}})
			return r.ok("reset")
		if a[0] == "save" and a.size() == 2:
			var p := save_file(a[1])
			return r.ok("saved " + p) if p != "" else r.fail("could not write the tuning file")
		if a[0] == "load" and a.size() == 2:
			var e := load_file(a[1])
			return r.ok("loaded " + a[1]) if e == "" else r.fail(e)
		if a.size() == 2 and a[1].is_valid_float():
			var key: String = a[0] if entries.has(a[0]) else "sim/" + a[0]
			var err := set_value(key, a[1].to_float())
			return r.fail(err) if err != "" else r.ok("%s = %s" % [key, snappedf(value(key), 0.0001)])
		return r.fail("usage: tune <param> <value> | list | reset [param] | save <name> | load <name>"),
		{"changes_sim": true, "complete": func(i, p, t): return (order + ["list", "reset", "save", "load"]) if i == 0 else []})
	r.register("ab", "", "swap tuning slots A and B", func(a):
		var e := swap()
		return r.fail(e) if e != "" else r.ok("tuning %s active" % active), {"changes_sim": true})
