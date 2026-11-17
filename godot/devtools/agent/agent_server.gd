extends Node
## Agent interface (PLAN-devtools step 12): the real Godot game driven over a local socket by tools/agentplay.
## Start: godot --path godot [--headless] -- --agent [--agent-port=47110] [--scenario <name>]
## Protocol: agent/PROTOCOL.md. JSON lines, one request -> one response with the same id; pushed events have no id.
## Lock-step: in agent mode the stage never advances on its own; the agent steps it. Console commands go through
## the same registry.execute as the human console, so they take the same code path and are logged the same way.

const WorldLog := preload("res://game/stage/world_log.gd")
const Scenario := preload("res://devtools/scenario.gd")
const Feedback := preload("res://devtools/feedback.gd")

const PROTOCOL := 1
const STUCK_TICKS := 30
const MAX_STEP := 20000

var port := 47110
var server := TCPServer.new()
var peer: StreamPeerTCP = null
var ready_sent := false
var _buffer := ""
var _events: Array = []         # combat events of the stepped ticks
var _log_seen := 0
var _still := 0
var _installed_stage = null
var _shots := 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--agent-port="):
			port = int(a.substr(13))
	var err := server.listen(port, "127.0.0.1")
	if err != OK:
		printerr("AGENT_ERROR cannot listen on 127.0.0.1:%d (error %d)" % [port, err])
		get_tree().quit(2)
		return
	Feedback.install_logger()
	_log_seen = Feedback.log_ring.lines.size() if Feedback.log_ring != null else 0

func _process(_dt: float) -> void:
	_check_ready()
	if peer == null and server.is_connection_available():
		peer = server.take_connection()
		_buffer = ""
		_take_over()
	if peer == null:
		return
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		peer = null
		return
	var n := peer.get_available_bytes()
	if n > 0:
		_buffer += peer.get_utf8_string(n)
	while true:
		var nl := _buffer.find("\n")
		if nl < 0:
			break
		var line := _buffer.substr(0, nl).strip_edges()
		_buffer = _buffer.substr(nl + 1)
		if line != "":
			_handle(line)
	_push_log_events()

func _check_ready() -> void:
	var st = Game.stage
	if st != null and st != _installed_stage:
		_installed_stage = st
		st.paused = true                       # lock-step: the agent steps it
		st.combat_events.connect(func(ev): _events.append_array(ev))
		st.input_provider = func() -> Dictionary: return {}
	if not ready_sent and st != null and Game.startup_error == "":
		ready_sent = true
		print("AGENT_READY " + JSON.stringify({"port": port, "build": Scenario.build_text(), "protocol": PROTOCOL}))
	elif not ready_sent and Game.startup_error != "":
		ready_sent = true
		printerr("AGENT_ERROR " + Game.startup_error)

func _take_over() -> void:
	if Game.stage != null:
		Game.stage.paused = true
		Game.stage.input_provider = func() -> Dictionary: return {}

func _send(d: Dictionary) -> void:
	if peer != null:
		peer.put_data((JSON.stringify(d) + "\n").to_utf8_buffer())

func _push_log_events() -> void:
	var ring: Array = Feedback.log_ring.lines if Feedback.log_ring != null else []
	if ring.size() < _log_seen:
		_log_seen = 0
	for i in range(_log_seen, ring.size()):
		var l: String = ring[i]
		if l.begins_with("ERR") or l.begins_with("ERROR"):
			_send({"event": "error", "source": "c_input" if l.contains("rejected an input") else "engine", "text": l})
	_log_seen = ring.size()

func _invariant(name: String, detail: String) -> void:
	_send({"event": "invariant", "name": name, "detail": detail})

func _handle(line: String) -> void:
	var req = JSON.parse_string(line)
	if typeof(req) != TYPE_DICTIONARY:
		_send({"ok": false, "error": "request is not a JSON object"})
		return
	var resp: Dictionary = _dispatch(req)
	if req.has("id"):
		resp["id"] = req.id
	_send(resp)
	if req.get("cmd", "") == "quit" and resp.get("ok", false):
		get_tree().quit(0)

func _obs() -> Dictionary:
	var st = Game.stage
	var o = JSON.parse_string(st.world.observe())
	var d: Dictionary = o if typeof(o) == TYPE_DICTIONARY else {}
	var s: Dictionary = st.cur
	d["tick"] = int(s.tick)
	d["fighting"] = int(s.active) >= 0
	var scene := get_tree().current_scene
	var pr := Vector3.ZERO
	if scene != null and scene.get("player_pos") != null and scene.player_pos != Vector3.INF:
		pr = scene.player_pos
	d["player_rendered"] = {"x": pr.x, "y": pr.y, "z": pr.z}
	d["legend_context"] = String(Game.legend_context())
	return d

func _dispatch(req: Dictionary) -> Dictionary:
	var cmd := str(req.get("cmd", ""))
	var st = Game.stage
	if st == null and cmd != "quit":
		return {"ok": false, "error": "the island is not running yet"}
	match cmd:
		"console":
			var r: Dictionary = Dev.console.registry.execute(str(req.get("text", "")))
			return {"ok": r.ok, "out": r.out, "error": r.error}
		"act":
			if req.has("order"):
				var res: Dictionary = st.world.command_input(str(req.order))
				if int(res.rc) != 0:
					return {"ok": false, "error": "%s ('%s')" % [CporeWorld.order_error(int(res.rc)), req.order]}
				st.queue_order(res.input)
				return {"ok": true}
			if typeof(req.get("input")) == TYPE_DICTIONARY:
				st.queue_order(req.input)
				return {"ok": true}
			return {"ok": false, "error": "act needs 'order' (text) or 'input' (verb, hx, hz, sprint...)"}
		"step":
			var n := int(req.get("ticks", 1))
			if n < 1 or n > MAX_STEP:
				return {"ok": false, "error": "ticks must be 1 to %d" % MAX_STEP}
			_events = []
			for i in n:
				st.step_ticks(1)
				if _watch(st):
					pass
			return {"ok": true, "tick": int(st.cur.tick), "hash": st.world.hash(), "obs": _obs(), "events": _events.duplicate()}
		"observe":
			return {"ok": true, "tick": int(st.cur.tick), "hash": st.world.hash(), "obs": _obs()}
		"screenshot":
			if DisplayServer.get_name() == "headless":
				return {"ok": false, "error": "no renderer (run under xvfb without --headless)"}
			var img := get_viewport().get_texture().get_image()
			var path := ProjectSettings.globalize_path("user://agent-shots").path_join("shot-%06d.png" % int(st.cur.tick))
			DirAccess.make_dir_recursive_absolute(path.get_base_dir())
			img.save_png(path)
			return {"ok": true, "path": path}
		"scenario_save":
			var scene := get_tree().current_scene
			var name := str(req.get("name", "agent"))
			var err: String = scene.save_scenario("%s/%s" % [Scenario.USER_DIR, name], "scenario", str(req.get("note", "")))
			return {"ok": err == "", "error": err}
		"scenario_load":
			var parsed := Scenario.read(str(req.get("name", "")))
			if not parsed.ok:
				return {"ok": false, "error": parsed.error}
			var err2: String = get_tree().current_scene.load_scenario(parsed)
			return {"ok": err2 == "", "error": err2}
		"verify":
			return _verify(st)
		"quit":
			return {"ok": true}
	return {"ok": false, "error": "unknown cmd '%s'" % cmd}

# Per-tick invariants: non-finite positions and a creature ordered to move that does not move for STUCK_TICKS.
func _watch(st) -> bool:
	var bad := false
	for e in st.cur.entities:
		if not (is_finite(e.x) and is_finite(e.z)):
			_invariant("non_finite_position", "entity %d at %s,%s" % [e.id, e.x, e.z])
			bad = true
	var order: Dictionary = st.cur.order
	var moving_order: bool = int(order.verb) in [2, 3, 4, 6, 7] and int(st.cur.active) < 0 and int(st.cur.respawn_ticks) == 0
	if moving_order and float(st.cur.entities[0].speed) < 0.05:
		_still += 1
		if _still == STUCK_TICKS:
			_invariant("stuck", "the player was ordered to move (verb %d) and has not moved for %d ticks" % [int(order.verb), STUCK_TICKS])
	else:
		_still = 0
	return bad

func _verify(st) -> Dictionary:
	var parsed: Dictionary = WorldLog.parse(st.export_log())
	if not parsed.ok:
		return {"ok": false, "error": "the session log does not parse: %s" % parsed.error}
	var w := CporeWorld.new()
	if not parsed.field.is_empty():
		if w.set_field(Game.terrain) != 0:
			return {"ok": false, "error": w.last_error()}
	if w.reset(parsed.setup) != 0:
		return {"ok": false, "error": "the logged setup was rejected: %s" % w.last_error()}
	if st.start_snapshot.size() > 0 and w.restore(st.start_snapshot) != 0:
		return {"ok": false, "error": "the start snapshot was rejected: %s" % w.last_error()}
	var dbg: Array = parsed.debug
	var di := 0
	var hs: PackedStringArray = st.hashes
	for i in mini(parsed.inputs.size(), hs.size()):
		while di < dbg.size() and int(dbg[di].tick) == int(w.state().tick):
			w.debug(dbg[di].op)
			di += 1
		if w.step(parsed.inputs[i]) != hs[i]:
			_invariant("verify_mismatch", "tick index %d" % i)
			return {"ok": true, "match": false, "ticks": hs.size(), "first_mismatch": i}
	return {"ok": true, "match": true, "ticks": hs.size()}
