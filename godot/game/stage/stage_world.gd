extends Node
# The 10 Hz bridge: a fixed-step accumulator over one CporeWorld, with interpolation samples and
# a replayable CPORE_WORLD_LOG of the exact inputs fed to the C world. Presentation state (camera,
# interpolation, grass) never flows back into C; only the player's intent does.

const WorldLog := preload("res://game/stage/world_log.gd")

signal ticked(state: Dictionary)
signal combat_events(events: Array)

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
var _setup: Dictionary = {}

func reset(setup: Dictionary) -> int:
	var rc := world.reset(setup)
	if rc != 0:
		return rc
	_setup = world.get_setup()
	cur = world.state()
	prev = cur
	pprev = cur
	acc = 0.0
	log_inputs = []
	hashes = PackedStringArray()
	return 0

func step_once() -> void:
	var input := {}
	if input_provider.is_valid():
		input = input_provider.call()
	var h := world.step(input)
	if h == "":
		push_error("stage: the C world rejected an input: %s" % [input])
		return
	pprev = prev
	prev = cur
	cur = world.state()
	log_inputs.append(input.duplicate())
	hashes.append(h)
	ticked.emit(cur)
	if not cur.combat.events.is_empty():
		combat_events.emit(cur.combat.events)
	if after_tick.is_valid():
		after_tick.call(cur)

# Called every frame with the frame time; steps as many 0.1 s ticks as have accumulated.
func advance(delta: float) -> int:
	acc += minf(delta, 0.25)
	var steps := 0
	while acc + 1e-9 >= DT:
		step_once()
		acc = maxf(0.0, acc - DT)
		steps += 1
	return steps

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
	return {"pos": Vector3(pos2.x, y, pos2.y), "yaw": wrapf(yaw, -PI, PI), "speed": vel2.length(), "speed_c": c.speed,
		"vel": Vector3(vel2.x, 0.0, vel2.y)}

func export_log() -> String:
	return WorldLog.write(_setup, log_inputs)
