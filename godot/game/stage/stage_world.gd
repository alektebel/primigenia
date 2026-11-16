extends Node
# The 10 Hz bridge: a fixed-step accumulator over one CporeWorld, with interpolation samples and
# a replayable CPORE_WORLD_LOG of the exact inputs fed to the C world. Presentation state (camera,
# interpolation, grass) never flows back into C; only the player's intent does.

const WorldLog := preload("res://game/stage/world_log.gd")

signal ticked(state: Dictionary)
signal combat_events(events: Array)

const DT := 0.1

var world := CporeWorld.new()
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

# Interpolated pose of entity `id` (0 = player): {pos: Vector3, yaw, speed, vel: Vector3}.
func sample(id: int, a: float = -1.0) -> Dictionary:
	if a < 0.0:
		a = alpha()
	var p := _entity(prev, id)
	var c := _entity(cur, id)
	var x := lerpf(p.x, c.x, a)
	var z := lerpf(p.z, c.z, a)
	var y := 0.0
	if ground_fn.is_valid():
		y = ground_fn.call(x, z)
	var yaw := lerp_angle(atan2(p.fx, p.fz), atan2(c.fx, c.fz), a)
	return {"pos": Vector3(x, y, z), "yaw": yaw, "speed": c.speed,
		"vel": Vector3((c.x - p.x) / DT, 0.0, (c.z - p.z) / DT)}

func export_log() -> String:
	return WorldLog.write(_setup, log_inputs)
