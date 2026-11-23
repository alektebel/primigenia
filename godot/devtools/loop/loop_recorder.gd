extends Node
## Creature-loop recorder (T1, docs/plans/creature-loop.md): every Game.loop_event goes to a JSONL file, one object per line:
##   {"n": <name>, "tick": <sim tick or -1>, "ms": <wall ms since the first event>, "ts": <unix s>, "d": {data}}
## The detector (loop_detector.gd) turns each C state into beats and publishes them through Game.loop_event, so the owner
## questions, this file and the scorecard all see the same stream. Session file, in order of precedence:
##   CPORE_LOOP_FILE env or --loop-file=<path>  (the scorecard)  >  test runs: <user data>/test-feedback/<pid>/loop/session.jsonl  >  user://loop/<stamp>.jsonl
## CPORE_LOOP=0 turns it off. Reading the file: tools/loop/score.py (metrics and targets), or the `loop` console/agent command.
const Detector := preload("res://devtools/loop/loop_detector.gd")
const TestIsolation := preload("res://devtools/test_isolation.gd")
const PERF_EVERY_MS := 10000
const KEEP := 40000

var enabled := true
var path := ""
var events: Array = []          # every event of this process, in memory (the `loop` command reads these)
var detector = Detector.new()
var _file: FileAccess
var _t0 := -1
var _frames: PackedFloat32Array = PackedFloat32Array()
var _perf_t := 0
var _flying := false
var _poll := 0
var _last_select_id := -1
var _last_select_tick := -1000

func _ready() -> void:
	process_priority = 100
	enabled = OS.get_environment("CPORE_LOOP") != "0"
	if not enabled:
		set_process(false)
		return
	Game.loop_event.connect(_on_event)
	Game.world_ticked.connect(_on_tick)

static func session_path() -> String:
	var f := OS.get_environment("CPORE_LOOP_FILE")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--loop-file="):
			f = a.substr(12)
	if f != "":
		return f
	if TestIsolation.active():
		return TestIsolation.dir_for("loop").path_join("session.jsonl")
	var t := Time.get_datetime_dict_from_system()
	return ProjectSettings.globalize_path("user://loop").path_join("%04d%02d%02d-%02d%02d%02d-%d.jsonl" % [t.year, t.month, t.day, t.hour, t.minute, t.second, OS.get_process_id()])

func _open() -> void:
	path = session_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	_file = FileAccess.open(path, FileAccess.WRITE)
	_t0 = Time.get_ticks_msec()
	_perf_t = _t0
	if _file == null:
		push_warning("loop recorder: cannot open %s" % path)
		return
	_write("session_start", {"seed": int(Game.settings.get("seed", 0)), "pid": OS.get_process_id(), "test": TestIsolation.active(),
		"version": str(ProjectSettings.get_setting("application/config/version", ""))})

func _write(name: String, data: Dictionary) -> void:
	var tick := -1
	if Game.stage != null and Game.stage.cur is Dictionary and not Game.stage.cur.is_empty():
		tick = int(Game.stage.cur.tick)
	var rec := {"n": name, "tick": tick, "ms": Time.get_ticks_msec() - _t0, "ts": int(Time.get_unix_time_from_system()), "d": data}
	if events.size() < KEEP:
		events.append(rec)
	if _file != null:
		_file.store_line(JSON.stringify(rec))
		_file.flush()

func _on_event(name: String, data: Dictionary) -> void:
	if _file == null:
		_open()
	if name == "island_ready":
		detector = Detector.new()           # a new island is a new run: the detector starts over
		_flying = false
	if name == "select":                    # a bot or a hover re-selects the same creature every frame: one event per creature and spell
		var tick := int(Game.stage.cur.tick) if Game.stage != null and not Game.stage.cur.is_empty() else -1
		if int(data.get("id", -1)) == _last_select_id and tick - _last_select_tick < 100:
			return
		_last_select_id = int(data.get("id", -1))
		_last_select_tick = tick
	_write(name, data)

func _on_tick(state: Dictionary) -> void:
	if _file == null:
		return
	if detector.nest == Vector2.INF:
		var scene := get_tree().current_scene
		if scene != null and "_nest" in scene and scene._nest is Vector2:
			detector.nest = scene._nest
	for ev in detector.feed(state):
		Game.loop_event.emit(ev[0], ev[1])

func _process(delta: float) -> void:
	if _file == null:
		return
	_frames.append(delta * 1000.0)
	var now := Time.get_ticks_msec()
	_poll += 1
	if _poll % 6 == 0:
		_poll_flight()
	if now - _perf_t >= PERF_EVERY_MS and _frames.size() > 4:
		var arr := Array(_frames)
		arr.sort()
		var sum := 0.0
		for v in arr:
			sum += v
		_write("perf", {"frames": arr.size(), "ms_avg": snappedf(sum / arr.size(), 0.01), "ms_p95": snappedf(arr[int(arr.size() * 0.95)], 0.01), "ms_max": snappedf(arr[-1], 0.01),
			"scale": snappedf(float(Game.stage.achieved_scale) if Game.stage != null else 0.0, 0.01)})
		_frames.clear()
		_perf_t = now

func _poll_flight() -> void:
	var scene := get_tree().current_scene
	if scene == null or not "flight" in scene or scene.flight == null:
		return
	var on: bool = scene.flight.active()
	if on != _flying:
		_flying = on
		Game.loop_event.emit("flight_start" if on else "flight_end", {})

## First tick of every event name, in sim ticks and wall ms.
func first_times() -> Dictionary:
	var out := {}
	for e in events:
		if not out.has(e.n):
			out[e.n] = {"tick": e.tick, "ms": e.ms}
	return out

func summary() -> String:
	var counts := {}
	var last_tick := -1
	var dist := 0.0
	for e in events:
		counts[e.n] = int(counts.get(e.n, 0)) + 1
		last_tick = maxi(last_tick, int(e.tick))
		if e.n == "sample":
			dist = float(e.d.get("dist", dist))
	var first := first_times()
	var lines := PackedStringArray()
	lines.append("loop session: %s" % (path if path != "" else "(no events yet)"))
	lines.append("%d events, last tick %d (%.1f min of game time), walked %.0f m" % [events.size(), last_tick, last_tick / 600.0, dist])
	var names := counts.keys()
	names.sort_custom(func(a, b): return int(first[a].tick) < int(first[b].tick) if int(first[a].tick) != int(first[b].tick) else str(a) < str(b))
	for n in names:
		if n in ["sample", "perf"]:
			continue
		lines.append("  %-22s x%-3d first at tick %d (%.1f s game, %.1f s wall)" % [n, counts[n], first[n].tick, maxf(0.0, first[n].tick) / 10.0, first[n].ms / 1000.0])
	return "\n".join(lines)

func dump(n: int) -> String:
	var lines := PackedStringArray()
	for e in events.slice(maxi(0, events.size() - n)):
		lines.append(JSON.stringify(e))
	return "\n".join(lines)
