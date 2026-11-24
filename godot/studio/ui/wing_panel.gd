extends RefCounted
## Creator controls of the selected wing part (motion-flight plan 3a): family, span, breadth, spars, attachment, fold, flight
## muscle, and the derived numbers (area, aspect ratio, wing loading, stall speed, best glide, capability). A separate file so the
## creator's own panel code only gains one call; it edits the part's optional `wing` block through the model's undo transaction.

# The creature and game modules are loaded at run time: the standalone studio project (godot/studio) does not contain them,
# and there wings are simply not offered (is_wing is false).
const WING_PATH := "res://creature/creature_wing.gd"
const FLIGHT_PATH := "res://game/player/flight_test.gd"

static func _wd():
	return load(WING_PATH) if ResourceLoader.exists(WING_PATH) else null

static func _ft():
	return load(FLIGHT_PATH) if ResourceLoader.exists(FLIGHT_PATH) else null

const FAMILY_NAMES := {"wing_glider": "Membrana (dedos)", "wing_vane": "Plumas", "wing_insect": "Velo de insecto", "wing_flap": "Patagio"}
const MODE_NAMES := {"forelimb": "Miembro anterior", "extra": "Par extra"}
const FOLD_NAMES := {"flank": "Plegada al flanco", "back": "Plegada sobre el lomo", "spread": "Abierta"}

static func is_wing(p: Dictionary) -> bool:
	var wd = _wd()
	return wd != null and _ft() != null and wd.is_wing(str(p.get("type", "")))

## Adds the wing section to `box`. `T`: the creator's translate Callable. `view`: the creator view (its `creature` is the live rig).
static func build(box: VBoxContainer, model, view, sel: int, T: Callable) -> void:
	var WingData = _wd()
	var p: Dictionary = model.doc["parts"][sel]
	var type := str(p.type)
	var w: Dictionary = WingData.params(type, p)
	var info := _built_info(view, sel)
	box.add_child(HSeparator.new())
	var h := Label.new()
	h.text = str(T.call("Ala")).to_upper()
	h.add_theme_color_override("font_color", Color("e8a23a"))
	h.add_theme_font_size_override("font_size", 13)
	box.add_child(h)
	# family
	var fam := OptionButton.new()
	fam.name = "WingFamily"
	for id in WingData.FAMILY_IDS:
		fam.add_item(T.call(FAMILY_NAMES[id]))
	fam.select(WingData.FAMILY_IDS.find(type))
	fam.item_selected.connect(func(i):
		model.begin()
		model.doc["parts"][sel]["type"] = WingData.FAMILY_IDS[i]
		model._touch()
		model.end())
	box.add_child(fam)
	box.add_child(_slider(model, "WingSpan", T.call("Envergadura por lado (m)"), float(info.get("span", 1.0)) if w.span <= 0.0 else w.span, 0.3, 6.0, 0.05, func(v): _put(model, sel, "span", v)))
	var b0 := float(info.get("chord", 0.5)) / maxf(float(info.get("span", 1.0)), 1e-3)
	box.add_child(_slider(model, "WingBreadth", T.call("Anchura (cuerda / envergadura)"), b0 if w.breadth <= 0.0 else w.breadth, 0.12, 1.2, 0.01, func(v): _put(model, sel, "breadth", v)))
	box.add_child(_slider(model, "WingSpars", T.call("Varillas / plumas"), float(w.spars), 1.0, 5.0, 1.0, func(v): _put(model, sel, "spars", int(v))))
	box.add_child(_slider(model, "WingMuscle", T.call("Músculo de vuelo (parte de la masa)"), w.muscle, WingData.MUSCLE_MIN, WingData.MUSCLE_MAX, 0.01, func(v): _put(model, sel, "muscle", v)))
	box.add_child(_choice(model, sel, "WingMode", "mode", WingData.MODES, MODE_NAMES, w.mode, T))
	box.add_child(_choice(model, sel, "WingFold", "fold", WingData.FOLDS, FOLD_NAMES, w.fold, T))
	var stats := Label.new()
	stats.name = "WingStats"
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.custom_minimum_size = Vector2(226, 0)
	stats.add_theme_color_override("font_color", Color("9fb0a0"))
	stats.add_theme_font_size_override("font_size", 12)
	stats.text = stats_text(view, T)
	box.add_child(stats)

static func _built_info(view, sel: int) -> Dictionary:
	var c = view.get("creature") if view != null else null
	if c == null or not ("parts" in c):
		return {}
	for e in c.parts:
		if int(e.index) == sel and e.node != null and e.node.has_meta("wing_info"):
			return e.node.get_meta("wing_info")
	return {}

## Derived numbers of the whole creature's wings (approximate mass: body volume at density 1000).
static func stats_text(view, T: Callable) -> String:
	var c = view.get("creature") if view != null else null
	var FlightTest = _ft()
	if c == null or FlightTest == null or not ("parts" in c) or not c.has_method("body_volume"):
		return ""
	var infos: Array = []
	for e in c.parts:
		if e.node != null and e.node.has_meta("wing_info"):
			infos.append(e.node.get_meta("wing_info"))
	if infos.is_empty():
		return ""
	var mass: float = maxf(float(c.body_volume()) * 1000.0, 0.5)
	var f = FlightTest.new(FlightTest.make_spec(mass, infos, 1.0, 0.3))
	if not f.valid():
		return ""
	var r: Dictionary = f.report()
	var cap: String = {"ground": "no vuela", "glide": "planea", "flap": "aletea"}.get(r.capability, "")
	return "%s %.1f m2, AR %.1f, %s %.0f N/m2\n%s %.0f m/s, %s %.1f:1 -> %s  (%.0f kg)" % [T.call("Área"), r.area, r.ar, T.call("carga"), r.wing_loading, T.call("pérdida"), r.stall, T.call("planeo"), r.ld, T.call(cap), mass]

static func _put(model, sel: int, key: String, value) -> void:
	if sel < 0 or sel >= model.doc["parts"].size():
		return
	model.begin()
	var p: Dictionary = model.doc["parts"][sel]
	var w: Dictionary = p.get("wing", {})
	w[key] = value
	p["wing"] = w
	model._touch()
	model.end()

static func _slider(model, node_name: String, label: String, value: float, lo: float, hi: float, step: float, on_change: Callable) -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label
	box.add_child(l)
	var s := HSlider.new()
	s.name = node_name
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.set_value_no_signal(clampf(value, lo, hi))
	s.custom_minimum_size = Vector2(226, 20)
	s.drag_started.connect(func(): model.begin())          # one undo step per drag
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_c): model.end())
	box.add_child(s)
	return box

static func _choice(model, sel: int, node_name: String, key: String, ids: Array, names: Dictionary, cur: String, T: Callable) -> Control:
	var ob := OptionButton.new()
	ob.name = node_name
	for id in ids:
		ob.add_item(T.call(names[id]))
	ob.select(maxi(ids.find(cur), 0))
	ob.item_selected.connect(func(i): _put(model, sel, key, ids[i]))
	return ob
