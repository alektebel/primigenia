extends SceneTree
## make godot-bridge-test: the whole bridge headless. The cell (demo colony to its end) -> the end card's "Continuar como criatura" ->
## the fade -> the island with the legacy applied (diet and owned part in the C world, the part equipped, the hatchling scaled, the whisper,
## the cell as the root of the family tree); then a plain start ("sin herencia") and the menu's choice. Docs: docs/godot/CELL-BRIDGE.md.
## godot --headless --fixed-fps 60 --path godot --script res://game/tests/test_bridge.gd

const Legacy := preload("res://cell/cell_legacy.gd")
const Strings := preload("res://ui/strings.gd")
var checks := 0
var fails := 0
var game

func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		printerr("FAIL: ", msg)
	else:
		print("  ok ", msg)

func _initialize() -> void:
	_run.call_deferred()

func until(cond: Callable, budget := 3000) -> bool:
	var n := 0
	while not cond.call() and n < budget:
		await process_frame
		n += 1
	return cond.call()

func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e)

func _island() -> Node:
	return current_scene if current_scene != null and current_scene.scene_file_path.ends_with("island.tscn") else null

func _run() -> void:
	await process_frame
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.language = "en"
	game.settings.grass = 3000
	game.settings.wild = true
	game.legacy_path = "user://cell_legacy_bridge_test.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.legacy_path))
	root.size = Vector2i(1280, 720)
	_pure()
	await _flow()
	await _plain()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.legacy_path))
	print("bridge test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

# The tables and the genome transform, without scenes.
func _pure() -> void:
	print("== legacy -> genome, part, diet")
	var base: Dictionary = game._read_genome("res://game/data/hatchling.json")
	ok(Legacy.apply_genome(base, {}) == base, "no legacy: the genome is untouched")
	for size_class in ["small", "medium", "large"]:
		var leg := {"diet": "cazador", "defense": "ninguna", "size_class": size_class}
		var g: Dictionary = Legacy.apply_genome(base, leg)
		var k: float = Legacy.SCALE[size_class]
		ok(is_equal_approx(float(g.nodes[2].r), float(base.nodes[2].r) * k) and g.parts.size() == base.parts.size(), "%s: scale %.1f, no part added" % [size_class, k])
	ok(Legacy.SCALE == {"small": 0.9, "medium": 1.0, "large": 1.1}, "scales 0.9 / 1.0 / 1.1")
	for pair in [["espinas", "pua"], ["placas", "placa"]]:
		var g2: Dictionary = Legacy.apply_genome(base, {"diet": "cazador", "defense": pair[0], "size_class": "medium"})
		ok(g2.parts.any(func(p): return p.type == pair[1]) and g2.parts.size() == base.parts.size() + 1, "%s: the %s part is equipped" % [pair[0], pair[1]])
	ok(base.parts.size() == 4, "the source genome is not modified")
	ok(Legacy.diet_for({"diet": "herbivoro"}) == 0 and Legacy.diet_for({"diet": "cazador"}) == 1 and Legacy.diet_for({"diet": "carronero"}) == 2, "diets map to the C diets")
	var w := CporeWorld.new()
	var setup := CporeWorld.default_setup(7)
	setup.terrain = 1
	setup.wild = []
	setup.obstacles = []
	ok(w.reset(setup) == 0, "a C world resets")
	var h0: String = w.state().hash
	ok(w.apply_legacy(-1, "") == 0 and w.state().hash == h0, "an empty legacy leaves the world hash alone")
	ok(w.apply_legacy(1, "nope") != 0, "an unknown part is refused")
	ok(w.apply_legacy(1, "pua") == 0 and w.state().social.diet == 1 and w.state().hash != h0, "the C world takes a diet and a part")
	var owned := false
	for p in w.state().parts.discovered:
		if p.id == "pua" and p.owned:
			owned = true
	ok(owned, "pua is discovered and owned")

func _flow() -> void:
	print("== cell (demo colony to its end) -> bridge -> island")
	var st = load("res://cell/cell_stage.tscn").instantiate()
	root.add_child(st)
	current_scene = st
	await process_frame
	await process_frame
	st.sim.agg_done = true
	st.sim.threats.done = true
	st._refresh_hud(true)
	_key(KEY_6)
	await process_frame
	ok(st._phase6, "the colony board is up")
	st.find_child("Demo", true, false).emit_signal("pressed")
	st.colony.done = true
	st.colony.done_t = 2.0
	await until(func(): return st._leg_card.visible)
	ok(st._leg_card.visible, "the end card shows")
	var cont: Button = st._leg_cont
	ok(cont != null and cont.text == "Continue as a creature" and cont.is_visible_in_tree(), "the primary button: Continue as a creature")
	ok(st._leg_go.text == "Back to the menu", "and the menu button stays")
	var leg: Dictionary = st._leg_cur.duplicate(true)
	ok(leg.get("source", "") == "colony" and leg.diet in ["carronero", "cazador", "herbivoro"], "the legacy comes from the colony (%s, %s, %s)" % [leg.get("diet"), leg.get("defense"), leg.get("size_class")])
	ok(game.creature_legacy.is_empty(), "nothing is queued for the creature before the press")
	cont.emit_signal("pressed")
	var t0 := Time.get_ticks_msec()
	ok(game.creature_legacy == leg, "the press queues the legacy of the card")
	ok(await until(func(): return st._bridge_veil != null and st._bridge_veil.color.a > 0.99, 600), "the water-coloured fade completes")
	var fade_ms := Time.get_ticks_msec() - t0
	ok(fade_ms <= 700 and st._bridge_veil.color.is_equal_approx(Color("0F2229", st._bridge_veil.color.a)), "in about 500 ms through the water colour (%d ms wall time)" % fade_ms)
	st._to_creature()
	ok(st._bridging, "a second press while fading does nothing")
	ok(await until(func(): return _island() != null and game.stage != null and game.stage.cur.has("tick") and int(game.stage.cur.tick) >= 3, 9000), "the island is entered")
	var isl := _island()
	if isl == null:
		return
	await process_frame
	var state: Dictionary = game.stage.world.state()
	ok(game.applied_legacy == leg and game.creature_legacy.is_empty(), "the island consumed the legacy once")
	ok(state.social.diet == Legacy.diet_for(leg), "the C diet is the legacy's (%d)" % state.social.diet)
	var part := Legacy.part_for(leg)
	if part != "":
		var owned := false
		for p in state.parts.discovered:
			if p.id == part and p.owned:
				owned = true
		ok(owned, "the starter part %s is owned in the C world" % part)
		ok(isl._genome.parts.any(func(p): return p.type == part), "and equipped on the body")
	else:
		ok(state.parts.discovered.size() == 3, "no starter part for 'ninguna'")
	var base: Dictionary = game._read_genome("res://game/data/hatchling.json")
	var k: float = Legacy.scale_for(leg)
	ok(is_equal_approx(float(isl._genome.nodes[2].r) / float(base.nodes[2].r), k), "the hatchling is scaled x%.1f" % k)
	ok(isl.stage_ui.ui.words.whisper_text.begins_with("Your lineage began as a "), "the whisper at the first frames: %s" % isl.stage_ui.ui.words.whisper_text)
	var ctrl = null
	for c in isl.get_children():
		if c.get_script() != null and str(c.get_script().resource_path).ends_with("lineage_controller.gd"):
			ctrl = c
	ok(ctrl != null, "the lineage controller exists")
	if ctrl != null:
		ctrl.open()
		await process_frame
		ok(ctrl.screen.root_shown and ctrl.screen.find_child("RootAncestor", true, false) != null, "the family tree starts at the cell")
		ctrl.close()
	var bytes: PackedByteArray = game.stage.world.snapshot()
	ok(bytes.size() > 0, "the world snapshots with the legacy applied")
	# the saved scenario keeps the legacy for Continue
	var sc: Dictionary = isl.scenario_ctx()
	ok(sc.legacy == leg, "the scenario context carries the legacy")

func _plain() -> void:
	print("== plain start (sin herencia) and the menu")
	game.begin_creature(true)
	ok(game.creature_legacy.is_empty(), "plain: nothing queued")
	game.goto_island("menu")
	ok(await until(func(): return _island() != null and game.stage != null and game.stage.cur.has("tick") and int(game.stage.cur.tick) >= 3, 9000), "the plain island is entered")
	var isl := _island()
	if isl == null:
		return
	var state: Dictionary = game.stage.world.state()
	ok(game.applied_legacy.is_empty() and state.social.diet == 2 and state.parts.discovered.size() == 3, "no legacy: omnivore, the three starter parts")
	ok(isl.stage_ui.ui.words.whisper_text == "", "no whisper")
	# the menu: a saved legacy is used by the card, "sin herencia" starts plain
	var d := {"version": 1, "source": "dev", "diet": "carronero", "defense": "placas", "size_class": "large", "stats": {}, "tally": {}}
	ok(Legacy.save(d, game.legacy_path), "a legacy is saved")
	var menu = load("res://game/menu/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	ok(menu.plain_button != null and menu.legacy_label != null, "the Criatura card shows the legacy and a 'sin herencia' option")
	menu.free()
	Legacy.save({}, game.legacy_path)
	var menu2 = load("res://game/menu/main_menu.tscn").instantiate()
	root.add_child(menu2)
	await process_frame
	ok(menu2.plain_button == null and menu2.legacy_label == null, "without a legacy there is no such option")
	menu2.free()
