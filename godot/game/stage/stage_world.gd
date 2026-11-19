extends Node
# The 10 Hz bridge: a fixed-step accumulator over one CporeWorld, with interpolation samples and
# a replayable CPORE_WORLD_LOG of the exact inputs fed to the C world. Presentation state (camera,
# interpolation, grass) never flows back into C; only the player's intent does.

const WorldLog := preload("res://game/stage/world_log.gd")

signal ticked(state: Dictionary)
signal combat_events(events: Array)
signal debug_applied(op: Dictionary, rc: int)   # a queued debug op ran (rc 0 = accepted; see CporeWorld.debug_error)

const DT := 0.1

var world := CporeWorld.new()
var pprev: Dictionary = {}     # the state before prev (one-sided tangents)
var prev: Dictionary = {}
var cur: Dictionary = {}
var acc := 0.0
var input_provider: Callable = Callable()   # () -> Dictionary (CpStageInput fields)
var ground_fn: Callable = Callable()        # (x, z) -> float
var after_tick: Callable = Callable()       # (state) -> void, e.g. clear a finished destination
var log_inputs: Array = []
var hashes: PackedStringArray = PackedStringArray()
var log_debug: Array = []                   # accepted debug ops: [{tick, op}] (tick = world tick they applied at)
var log_start_tick := 0                     # world tick of log_inputs[0]
var start_snapshot := PackedByteArray()     # set when the session started from restore_from()
var snapshot_ring: Array = []               # [{tick, bytes}] every RING_EVERY ticks, RING_KEEP kept (feedback replays)
var _setup: Dictionary = {}
var _debug_queue: Array = []
var _order_queue: Array = []               # console/agent orders for the next tick(s), logged like player input

# D7 time control (PLAN-devtools step 6): presentation only, it changes *when* ticks run, never what they compute.
var timescale := 1.0
var paused := false
var max_steps_per_frame := 60
var achieved_scale := 1.0     # simulated seconds per real second in the last frame (< timescale when capped)

# Dev: look at the player moving `vis_speed` times faster than the C world moves it (console `runvis`). Pure presentation:
# the shown position gains an offset that grows by (vis_speed - 1) times each tick's displacement, so the animation sees
# run speeds before the C sim can produce them. 1.0 = off, and the offset is dropped.
var vis_speed := 1.0
var _vis_off_prev := Vector2.ZERO
var _vis_off := Vector2.ZERO

func set_vis_speed(k: float) -> void:
	vis_speed = clampf(k, 1.0, 6.0)
	if vis_speed == 1.0:
		_vis_off_prev = Vector2.ZERO
		_vis_off = Vector2.ZERO

func _vis_tick() -> void:
	_vis_off_prev = _vis_off
	if vis_speed == 1.0 or cur.entities.is_empty() or prev.entities.is_empty():
		return
	var d := Vector2(cur.entities[0].x - prev.entities[0].x, cur.entities[0].z - prev.entities[0].z)
	if d.length() <= JUMP:
		_vis_off += d * (vis_speed - 1.0)

const RING_EVERY := 100
const RING_KEEP := 8

# Setting edit_anywhere: the creature may be edited away from the nest (the C rule stays; the flag is not hashed and not a
# tick input, so the world is re-told after every reset and restore, which would otherwise bring back a snapshot's value).
var edit_anywhere := false:
	set(v):
		edit_anywhere = v
		world.set_edit_anywhere(v)

func reset(setup: Dictionary) -> int:
	var rc := world.reset(setup)
	if rc != 0:
		return rc
	world.set_edit_anywhere(edit_anywhere)
	_setup = world.get_setup()
	cur = world.state()
	prev = cur
	pprev = cur
	acc = 0.0
	log_inputs = []
	hashes = PackedStringArray()
	_reset_log(false)
	return 0

func _reset_log(from_snapshot: bool) -> void:
	log_debug = []
	_debug_queue = []
	snapshot_ring = []
	log_start_tick = int(cur.tick)
	if not from_snapshot:
		start_snapshot = PackedByteArray()

# Restores a snapshot (CporeWorld.snapshot()) and starts a fresh log from it. Returns CporeWorld's restore code.
func restore_from(bytes: PackedByteArray) -> int:
	var rc := world.restore(bytes)
	if rc != 0:
		return rc
	world.set_edit_anywhere(edit_anywhere)
	_setup = world.get_setup()
	cur = world.state()
	prev = cur
	pprev = cur
	acc = 0.0
	log_inputs = []
	hashes = PackedStringArray()
	_reset_log(true)
	start_snapshot = bytes
	return 0

# Debug ops (teleport, spawn, tuning...) are queued and applied at the start of the next tick, before that
# tick's input, so the order is the same here, in world_cli and in cp_stage_replay_ex.
func queue_debug(op: Dictionary) -> void:
	_debug_queue.append(op)

# Applies a debug op right now, between ticks: the same effect and log position as queue_debug (the op is
# logged at the next tick), but the caller gets the result code at once. Returns the rc.
func debug_now(op: Dictionary) -> int:
	_apply_debug()
	var rc: int = world.debug(op)
	if rc == 0:
		log_debug.append({"tick": int(cur.tick), "op": op.duplicate()})
	debug_applied.emit(op, rc)
	return rc

# Rebuilds a session from a parsed v3 log (WorldLog.parse): reset, then every logged tick with its debug ops
# and input. The field (if any) must already be attached. Returns the reset's rc (0 = replayed).
func replay_recipe(parsed: Dictionary) -> int:
	var rc := reset(parsed.setup)
	if rc != 0:
		return rc
	var dbg: Array = parsed.get("debug", [])
	var di := 0
	for inp in parsed.inputs:
		while di < dbg.size() and int(dbg[di].tick) == int(cur.tick):
			debug_now(dbg[di].op)
			di += 1
		queue_order(inp)
		step_once()
	while di < dbg.size() and int(dbg[di].tick) == int(cur.tick):    # ops at the final tick (e.g. a scenario made at tick 0)
		debug_now(dbg[di].op)
		di += 1
	return 0

# Replaces the input of one upcoming tick (FIFO). The input is validated by CporeWorld.step like any other.
func queue_order(input: Dictionary) -> void:
	_order_queue.append(input)

func _apply_debug() -> void:
	var queue := _debug_queue
	_debug_queue = []
	for op in queue:
		var rc: int = world.debug(op)
		if rc == 0:
			log_debug.append({"tick": int(cur.tick), "op": op.duplicate()})
		debug_applied.emit(op, rc)

func step_once() -> void:
	if not _debug_queue.is_empty():
		_apply_debug()
	var input := {}
	if not _order_queue.is_empty():
		input = _order_queue.pop_front()
	elif input_provider.is_valid():
		input = input_provider.call()
	if input.has("run"):
		world.set_run(int(input.run) != 0)       # before the step, so it is part of that tick; the C log has no setter record
	var h := world.step(input)
	if h == "":
		push_error("stage: the C world rejected an input: %s" % [input])
		return
	pprev = prev
	prev = cur
	cur = world.state()
	_vis_tick()
	log_inputs.append(input.duplicate())
	hashes.append(h)
	if int(cur.tick) % RING_EVERY == 0:
		snapshot_ring.append({"tick": int(cur.tick), "bytes": world.snapshot()})
		if snapshot_ring.size() > RING_KEEP:
			snapshot_ring.pop_front()
	ticked.emit(cur)
	if not cur.combat.events.is_empty():
		combat_events.emit(cur.combat.events)
	if after_tick.is_valid():
		after_tick.call(cur)

# Called every frame with the frame time; steps as many 0.1 s ticks as have accumulated (times timescale),
# at most max_steps_per_frame. Paused adds nothing. Returns the ticks stepped.
func advance(delta: float) -> int:
	if paused:
		achieved_scale = 0.0
		return 0
	acc += minf(delta, 0.25) * timescale
	var steps := 0
	while acc + 1e-9 >= DT and steps < max_steps_per_frame:
		step_once()
		acc = maxf(0.0, acc - DT)
		steps += 1
	if acc + 1e-9 >= DT:
		acc = fmod(acc, DT)   # the backlog beyond the cap is dropped, not carried
	achieved_scale = steps * DT / maxf(delta, 1e-6)
	return steps

# Steps n ticks now, paused or not (the `.` key while paused, the agent's lock-step).
func step_ticks(n: int) -> int:
	for i in n:
		step_once()
	return n

func alpha() -> float:
	return clampf(acc / DT, 0.0, 1.0)

func _process(delta: float) -> void:
	advance(delta)

func _entity(state: Dictionary, id: int) -> Dictionary:
	return state.entities[id] if id < state.entities.size() else state.entities[0]

const JUMP := 2.5            # metres per tick: more than this is a teleport (respawn, arena), not motion

# Interpolated pose of entity `id` (0 = player): {pos: Vector3, yaw, speed, speed_c, vel: Vector3}.
# C1 cubic Hermite through the C ticks with one-sided tangents (the chord of the previous tick at the
# start, this tick's chord at the end), so there is no added latency, the path has no corners at the 10 Hz
# ticks and the velocity is continuous. Yaw tangents use the Fritsch-Carlson limiter (no overshoot when
# C snaps to the target heading); teleports and fight start/finish fall back to a straight line.
func sample(id: int, a: float = -1.0) -> Dictionary:
	if a < 0.0:
		a = alpha()
	var p := _entity(prev, id)
	var c := _entity(cur, id)
	var pp := _entity(pprev, id)
	var P0 := Vector2(p.x, p.z)
	var P1 := Vector2(c.x, c.z)
	var m1 := P1 - P0
	var m0 := P0 - Vector2(pp.x, pp.z)
	var y0 := atan2(p.fx, p.fz)
	var y1 := y0 + wrapf(atan2(c.fx, c.fz) - y0, -PI, PI)
	var n1 := y1 - y0
	var n0 := wrapf(y0 - atan2(pp.fx, pp.fz), -PI, PI)
	var jump := m1.length() > JUMP or m0.length() > JUMP or int(pprev.get("active", -1)) != int(prev.get("active", -1)) \
			or int(prev.get("active", -1)) != int(cur.get("active", -1))
	if jump:
		m0 = m1
		n0 = n1
	else:
		var l1 := m1.length()
		if m0.length() > 3.0 * l1:
			m0 = m0.normalized() * 3.0 * l1 if l1 > 0.0 else Vector2.ZERO
		if n0 * n1 <= 0.0:
			n0 = 0.0
		else:
			n0 = signf(n1) * minf(absf(n0), 3.0 * absf(n1))
	var a2 := a * a
	var a3 := a2 * a
	var h00 := 2.0 * a3 - 3.0 * a2 + 1.0
	var h10 := a3 - 2.0 * a2 + a
	var h01 := -2.0 * a3 + 3.0 * a2
	var h11 := a3 - a2
	var d00 := 6.0 * a2 - 6.0 * a
	var d10 := 3.0 * a2 - 4.0 * a + 1.0
	var d01 := -6.0 * a2 + 6.0 * a
	var d11 := 3.0 * a2 - 2.0 * a
	var pos2 := P0 * h00 + m0 * h10 + P1 * h01 + m1 * h11
	var vel2 := (P0 * d00 + m0 * d10 + P1 * d01 + m1 * d11) / DT
	var yaw := y0 * h00 + n0 * h10 + y1 * h01 + n1 * h11
	var y := 0.0
	if ground_fn.is_valid():
		y = ground_fn.call(pos2.x, pos2.y)
	if id == 0 and vis_speed != 1.0:
		pos2 += _vis_off_prev.lerp(_vis_off, a)
		vel2 += (_vis_off - _vis_off_prev) / DT
		if ground_fn.is_valid():
			y = ground_fn.call(pos2.x, pos2.y)
	# C owns airborne height; the animation consumer receives falling separately.
	if id == 0 and (bool(cur.get("player", {}).get("falling", false)) or bool(prev.get("player", {}).get("falling", false))):
		y = lerpf(float(prev.get("player", {}).get("y", y)), float(cur.get("player", {}).get("y", y)), a)
	return {"pos": Vector3(pos2.x, y, pos2.y), "yaw": wrapf(yaw, -PI, PI), "speed": vel2.length(), "speed_c": c.speed,
		"vel": Vector3(vel2.x, 0.0, vel2.y)}

# The v3 text log of the session. `snapshot_name` is written as the `snapshot` line when the session started
# from a snapshot (the caller saves start_snapshot next to the log under that name).
func export_log(snapshot_name: String = "replay_start.cpstate") -> String:
	var opts := {}
	if not log_debug.is_empty():
		opts.debug = log_debug
	if start_snapshot.size() > 0:
		opts.snapshot = snapshot_name
	if world.has_field() and int(_setup.get("terrain", 0)) == 2:
		var info: Dictionary = world.field_info()
		opts.field = {"seed": info.seed, "n": info.n, "size_m": info.size_m, "hash": info.hash}
	return WorldLog.write(_setup, log_inputs, opts)
