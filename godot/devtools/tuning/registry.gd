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
## Choice entries (named variants, F10 option mode): {key, group, values, default, get, set, sim, disabled, desc, cur}.
## They are saved in the same diff as the numeric entries (values[key] = "name") and swap with the A/B slots.
var choices := {}
var choice_order: Array = []
const PRESET_SLOTS := 4
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

## A named-variant option. values: Array of names; def: one of them. getter() -> String reads the live state (leave it
## invalid and the registry remembers the last value set); setter(name) applies it. sim: the setter goes through debug
## ops (logged and replayable); presentation choices never reach C. extra: {desc, disabled: {value: reason}}.
func add_choice(key: String, group: String, values: Array, def: String, getter: Callable, setter: Callable, sim := false, extra := {}) -> void:
	choices[key] = {"key": key, "group": group, "values": values.duplicate(), "default": def, "get": getter, "set": setter, "sim": sim,
		"disabled": extra.get("disabled", {}), "desc": str(extra.get("desc", "")), "cur": def}
	if not choice_order.has(key):
		choice_order.append(key)

func is_choice(key: String) -> bool:
	return choices.has(key)

func choice_value(key: String) -> String:
	var e: Dictionary = choices[key]
	return str(e.get.call()) if e.get.is_valid() else str(e.cur)

func choice_changed(key: String) -> bool:
	return choice_value(key) != str(choices[key].default)

func set_choice(key: String, v: String) -> String:
	if not choices.has(key):
		return "unknown option '%s' (opt list shows them)" % key
	var e: Dictionary = choices[key]
	if not e.values.has(v):
		return "option %s has no value '%s' (%s)" % [key, v, ", ".join(PackedStringArray(e.values))]
	if e.disabled.has(v):
		return "%s = %s is not available: %s" % [key, v, e.disabled[v]]
	e.cur = v
	e.set.call(v)
	return ""

## Next (dir +1) or previous (-1) enabled value, wrapping. Returns "" or the error.
func cycle_choice(key: String, dir: int) -> String:
	if not choices.has(key):
		return "unknown option '%s'" % key
	var e: Dictionary = choices[key]
	var n: int = e.values.size()
	var i: int = e.values.find(choice_value(key))
	for step in n:
		i = posmod(i + dir, n)
		if not e.disabled.has(e.values[i]):
			return set_choice(key, e.values[i])
	return ""

func reset_choice(key: String) -> void:
	if choices.has(key) and choice_changed(key):
		set_choice(key, choices[key].default)

func current_choices() -> Dictionary:
	var out := {}
	for k in choice_order:
		if choice_changed(k):
			out[k] = choice_value(k)
	return out

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
	if choices.has(key):
		return set_choice(key, str(v))
	if not entries.has(key):
		return "unknown parameter '%s' (tune list shows them)" % key
	var e: Dictionary = entries[key]
	e.set.call(clampf(v, e.min, e.max))
	return ""

func reset(key: String) -> void:
	if choices.has(key):
		reset_choice(key)
	elif entries.has(key):
		entries[key].set.call(entries[key].default)

func is_changed(key: String) -> bool:
	return absf(value(key) - float(entries[key].default)) > 1e-6

func current_values() -> Dictionary:
	var out := {}
	for k in order:
		if is_changed(k):
			out[k] = snappedf(value(k), 1e-6)
	out.merge(current_choices())
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
	for k in choice_order:
		reset_choice(k)
	for k in d.get("values", {}):
		var err := ""
		if choices.has(k):
			err = set_choice(k, str(d.values[k]))
		else:
			err = set_value(k, float(d.values[k]))
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
	return {"active": active, "A": slots.A.duplicate(), "B": slots.B.duplicate(), "names": slot_names.duplicate(), "options": current_choices()}

func restore_state(s: Dictionary) -> String:
	slots.A = s.get("A", {})
	slots.B = s.get("B", {})
	slot_names = s.get("names", {"A": "", "B": ""})
	active = s.get("active", "A")
	return apply({"format": FORMAT, "values": slots[active]})

## One line for the corner: the active non-default choices, "gait froude · skin v1 · light day".
func choices_line() -> String:
	var parts := PackedStringArray()
	for k in choice_order:
		if choice_changed(k):
			parts.append("%s %s" % [k.get_slice("/", k.get_slice_count("/") - 1), choice_value(k)])
	return " · ".join(parts)

## Presets: the whole set (numeric and choices) as a tuning diff in user://tuning/preset_N.json.
func preset_path(n: int) -> String:
	return "%s/preset_%d.json" % [user_dir, n]

func save_preset(n: int) -> String:
	if n < 1 or n > PRESET_SLOTS:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(user_dir))
	var f := FileAccess.open(preset_path(n), FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(diff("preset %d" % n), "\t"))
	f.close()
	return preset_path(n)

func has_preset(n: int) -> bool:
	return FileAccess.file_exists(preset_path(n))

func recall_preset(n: int) -> String:
	if not has_preset(n):
		return "preset %d is empty (Ctrl+%d saves the current set)" % [n, n]
	var v = JSON.parse_string(FileAccess.get_file_as_string(preset_path(n)))
	if typeof(v) != TYPE_DICTIONARY:
		return "preset %d is not a JSON object" % n
	return apply(v)

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
	r.register("opt", "list | <key> <value> | <key>=<value>... | reset [key] | preset <n> | save <n>", "option mode (F10): named variants and tuning values",
		func(a): return _opt(r, a), {"changes_sim": true, "complete": func(i, p, t): return _opt_complete(i, t)})
	r.register("ab", "", "swap tuning slots A and B", func(a):
		var e := swap()
		return r.fail(e) if e != "" else r.ok("tuning %s active" % active), {"changes_sim": true})

## Full key from a full or short name ("light" for "light/time"); "" when unknown, "?" when ambiguous.
func resolve_key(name: String) -> String:
	if choices.has(name) or entries.has(name):
		return name
	var hit := ""
	for k in choice_order + order:
		if k.get_slice("/", k.get_slice_count("/") - 1) == name:
			if hit != "":
				return "?"
			hit = k
	return hit

func set_option(name: String, v: String) -> String:
	var k := resolve_key(name)
	if k == "?":
		return "'%s' matches several options, use the full key (opt list)" % name
	if k == "":
		return "unknown option '%s' (opt list shows them)" % name
	if choices.has(k):
		return set_choice(k, v)
	if not v.is_valid_float():
		return "%s takes a number" % k
	return set_value(k, v.to_float())

func list_text() -> String:
	var lines := PackedStringArray()
	for k in choice_order:
		var e: Dictionary = choices[k]
		var vals := PackedStringArray()
		for v in e.values:
			vals.append(v + ("*" if e.disabled.has(v) else ""))
		lines.append("  %-20s %-10s [%s] %s%s" % [k, choice_value(k), " ".join(vals), e.group, " (changed)" if choice_changed(k) else ""])
	for k in order:
		lines.append("  %-20s %s (default %s)" % [k, snappedf(value(k), 0.0001), snappedf(entries[k].default, 0.0001)])
	return "\n".join(lines)

func _opt(r, a: PackedStringArray) -> Dictionary:
	if a.size() == 0 or a[0] == "list":
		return r.ok(list_text() if not choice_order.is_empty() or not order.is_empty() else "no options yet (start the island)")
	if a[0] == "reset":
		if a.size() > 1:
			var k := resolve_key(a[1])
			if k == "" or k == "?":
				return r.fail("unknown option '%s'" % a[1])
			reset(k)
		else:
			apply({"format": FORMAT, "values": {}})
		return r.ok("reset")
	if (a[0] == "preset" or a[0] == "save") and a.size() == 2 and a[1].is_valid_int():
		var n := a[1].to_int()
		if a[0] == "save":
			var p := save_preset(n)
			return r.ok("saved " + p) if p != "" else r.fail("preset slots are 1 to %d" % PRESET_SLOTS)
		var err := recall_preset(n)
		return r.fail(err) if err != "" else r.ok("preset %d recalled" % n)
	var pairs: Array = []
	if a[0].contains("="):
		for t in a:
			if not t.contains("="):
				return r.fail("usage: opt key=value key=value ...")
			pairs.append([t.get_slice("=", 0), t.substr(t.find("=") + 1)])
	elif a.size() == 2:
		pairs.append([a[0], a[1]])
	else:
		return r.fail("usage: opt list | <key> <value> | <key>=<value>... | reset [key] | preset <n> | save <n>")
	for p in pairs:
		var err2 := set_option(p[0], p[1])
		if err2 != "":
			return r.fail(err2)
	return r.ok(choices_line() if choices_line() != "" else "ok")

func _opt_complete(i: int, tokens: Array) -> Array:
	if i == 0:
		return choice_order + order + ["list", "reset", "preset", "save"]
	if i == 1 and tokens.size() > 0:
		var k := resolve_key(str(tokens[0]))
		if choices.has(k):
			return choices[k].values
	return []
