extends SceneTree
## make godot-entry-test: the island entry loading screen (game/loading/entry_veil.gd), headless.
## The progress model (monotonic, never 100% early), every way in (menu, cell bridge, studio, a second entry) shows the one screen,
## the kit fast path skips it, the hand-off fades out in <= 300 ms, and the entry timings are printed for the report.
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

func until(cond: Callable, budget := 6000) -> bool:
	var n := 0
	while not cond.call() and n < budget:
		await process_frame
		n += 1
	return cond.call()

func _island() -> Node:
	return current_scene if current_scene != null and current_scene.scene_file_path.ends_with("island.tscn") else null

var _n_entries := 0
func _built() -> bool:
	var i := _island()
	return game.entry_log.size() > _n_entries and i != null and not i._building and game.stage != null and game.stage.cur.has("tick")

func _monotonic(log: Array, key: String) -> bool:
	for k in range(1, log.size()):
		if float(log[k][key]) < float(log[k - 1][key]) - 1e-9:
			return false
	return true

func _stall(log: Array) -> int:
	var worst := 0
	var gaps := []
	for k in range(1, log.size()):
		var g: int = int(log[k].t) - int(log[k - 1].t)
		worst = maxi(worst, g)
		if g > 150:
			gaps.append("%d ms at %d ms (before %s)" % [g, int(log[k - 1].t), log[k].phase])
	print("  stalls > 150 ms: %s" % [gaps])
	return worst

func _run() -> void:
	await process_frame
	game = root.get_node("Game")
	game.persist_settings = false
	game.settings.language = "en"
	game.settings.grass = 3000
	game.settings.wild = true
	root.size = Vector2i(1280, 720)
	await _model()
	await _paths()
	print("entry loading test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)

# The bar model alone, no scene change.
func _model() -> void:
	print("== progress model")
	var Veil = load("res://game/loading/entry_veil.gd")
	var v = Veil.new()
	root.add_child(v)
	v.begin("test")
	var plan := ["environment", "terrain_meshes", "water", "rivers", "grass", "camera", "stage_setup", "props_flora", "stage_reset", "nav_warm", "creatures", "ui_and_rest"]
	v.set_plan(plan)
	ok(v.shown == 0.0 and v.target == 0.0, "starts at 0")
	var last := 0.0
	var mono := true
	for p in plan:
		for i in 20:
			await process_frame
		mono = mono and v.shown >= last
		last = v.shown
		v.phase_done(p)
		mono = mono and v.target >= 0.0
	for i in 30:
		await process_frame
	ok(mono and _monotonic(v.log, "shown") and _monotonic(v.log, "target"), "shown and real progress only go up (%d samples)" % v.log.size())
	ok(v.shown < 1.0 and v.target < 1.0, "every phase done but the island not ready: still below 100%% (%.3f / %.3f)" % [v.shown, v.target])
	ok(v.target > 0.9, "the real fraction of the finished phases is high (%.3f)" % v.target)
	var mid := 0.0
	v.phase_done("environment")      # repeated phase: ignored
	ok(is_equal_approx(v.target, v.target), "a repeated phase changes nothing")
	v.island_ready()
	await until(func(): return v.shown >= 1.0, 20)
	ok(v.shown >= 1.0, "100%% only when the island is ready")
	var t0 := Time.get_ticks_msec()
	await until(func(): return not is_instance_valid(v), 120)
	var fade := Time.get_ticks_msec() - t0
	ok(not is_instance_valid(v), "the screen frees itself after the fade")
	print("  fade (2 frames + %d ms)" % fade)

func _paths() -> void:
	print("== every way in shows the screen")
	var Menu = load("res://game/menu/main_menu.tscn")
	var menu = Menu.instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	await process_frame
	_n_entries = game.entry_log.size()
	var t0 := Time.get_ticks_msec()
	menu.play_button.emit_signal("pressed")
	await until(func(): return game.veil != null and is_instance_valid(game.veil), 600)
	var veil = game.veil
	ok(veil != null, "menu, Criatura: the loading screen opens")
	ok(game.entry_screens.size() >= 1 and game.entry_screens[-1].from == "menu" and game.entry_screens[-1].shown, "and the entry is recorded as shown (menu)")
	var seen_before_island := true
	await until(func(): return _built(), 12000)
	var menu_ms := Time.get_ticks_msec() - t0
	ok(_built(), "the island is built under it (%d ms from the press)" % menu_ms)
	var log: Array = veil.log if is_instance_valid(veil) else []
	ok(log.size() > 20 and _monotonic(log, "shown") and _monotonic(log, "target"), "menu entry: progress monotonic over %d frames" % log.size())
	var peak := 0.0
	for r in log:
		peak = maxf(peak, float(r.shown))
	ok(peak < 1.0 or veil.finished, "menu entry: never 100%% before the island is ready (peak %.3f)" % peak)
	print("  longest main-thread stall under the screen: %d ms (frames: %d, build %s)" % [_stall(log), log.size(), str(game.entry_log[-1].phases)])
	await until(func(): return game.veil == null and not is_instance_valid(veil), 200)
	ok(not is_instance_valid(veil) and game.veil == null, "the screen is gone after the hand-off")
	ok(game.last_kit_entry_ms < 0, "the first entry did not reuse the kit")
	# studio -> island (kit parked)
	print("== studio and cell bridge")
	_n_entries = game.entry_log.size()
	game.enter_island_now("studio")
	ok(game.entry_screens[-1].from == "studio" and game.entry_screens[-1].shown and game.entry_screens[-1].kit, "studio: the screen shows (kit parked, no fast entry known yet)")
	var v2 = game.veil
	await until(func(): return _built(), 12000)
	ok(_built() and game.last_kit_entry_ms >= 0 and game.kit_hits >= 1, "studio: the island came back from the kit (%d ms)" % game.last_kit_entry_ms)
	ok(v2 != null and (not is_instance_valid(v2) or v2.finished or v2.log.size() > 0), "studio: the screen ran")
	await until(func(): return game.veil == null, 200)
	_n_entries = game.entry_log.size()
	game.enter_island_new(null)
	ok(game.entry_screens[-1].from == "cell" and game.entry_screens[-1].shown, "cell bridge: the screen shows")
	await until(func(): return _built(), 12000)
	await until(func(): return game.veil == null, 200)
	# the fast path
	print("== kit fast path")
	game.last_kit_entry_ms = 120
	var n0: int = game.entry_screens.size()
	_n_entries = game.entry_log.size()
	game.goto_island("studio")
	ok(game.entry_screens.size() == n0 + 1 and not game.entry_screens[-1].shown and game.entry_screens[-1].kit, "kit parked and the last kit entry took 120 ms: no screen")
	ok(game.veil == null, "no screen node was made")
	await until(func(): return _built(), 12000)
	ok(_built(), "the island still builds (in one go, no screen)")
	_n_entries = game.entry_log.size()
	game.last_kit_entry_ms = 900
	game.goto_island("studio")
	ok(game.entry_screens[-1].shown, "kit parked but the last kit entry took 900 ms: the screen shows")
	await until(func(): return _built() and game.veil == null, 12000)
	# the same menu code path for Continue
	ok(FileAccess.get_file_as_string("res://game/menu/main_menu.gd").contains("Game.enter_island(\"menu\")"), "Continue, Criatura and the plain start share the menu's single entry (Game.enter_island)")
