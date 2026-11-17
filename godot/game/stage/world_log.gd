extends RefCounted
# CPORE_WORLD_LOG 2: the text replay format of apps/world_cli.c (--replay).
# parse(text) -> {ok, setup, inputs: Array[Dictionary], error}
# write(setup, inputs) -> String  (setup in the CporeWorld.reset schema, fully resolved)

const MAGIC := "CPORE_WORLD_LOG"
const VERSION := 2

static func f32(v: float) -> float:
	return PackedFloat32Array([v])[0]

# Shortest decimal text that parses back to the same float32 (up to 9 significant digits).
static func num(v: float) -> String:
	var want := f32(v)
	for digits in range(6, 10):
		var s := _sig(want, digits)
		if f32(s.to_float()) == want:
			return s
	return _sig(want, 9)

static func _sig(v: float, digits: int) -> String:
	if v == 0.0:
		return "0"
	var e := floori(log(absf(v)) / log(10.0))
	var decimals := maxi(digits - 1 - e, 0)
	return String.num(v, mini(decimals, 40))

static func _profile_tokens(p: Dictionary) -> String:
	return "%d %d %d %d %d %s %s %s %d" % [p.mouth, p.charge, p.spit, p.tail, p.guard,
		num(p.hp), num(p.stamina), num(p.speed), p.radius_cm]

static func write(setup: Dictionary, inputs: Array) -> String:
	var lines := PackedStringArray()
	lines.append("%s %d" % [MAGIC, VERSION])
	var nest: Vector2 = setup.nest
	var water: Vector3 = setup.water
	lines.append("%d %d %d %s %s %s %s %s %s %d %d" % [setup.seed, setup.terrain_seed, setup.terrain,
		num(nest.x), num(nest.y), num(setup.flat_height), num(water.x), num(water.y), num(water.z),
		setup.wild.size(), setup.obstacles.size()])
	lines.append(_profile_tokens(setup.player))
	for w in setup.wild:
		lines.append("%s %s %s %s %d %d" % [num(w.x), num(w.z), num(w.home_x), num(w.home_z), w.species, w.bot])
		lines.append(_profile_tokens(w.profile))
	for o in setup.obstacles:
		lines.append("%s %s %s %d" % [num(o.x), num(o.z), num(o.r), o.type])
	lines.append(str(inputs.size()))
	for i in inputs:
		lines.append("%d %d %d %d %d %d %d %s %s" % [i.get("verb", 0), i.get("target", 0), i.get("move", 0),
			i.get("dir", 0), int(i.get("sprint", 0)), i.get("hx", 0), i.get("hz", 0), num(i.get("x", 0.0)), num(i.get("z", 0.0))])
	return "\n".join(lines) + "\n"

static func parse(text: String) -> Dictionary:
	var tok := PackedStringArray()
	for part in text.replace("\t", " ").replace("\r", " ").replace("\n", " ").split(" ", false):
		tok.append(part)
	var cur := [0]  # lambdas capture ints by value; a one-element array is shared
	var fail := func(msg: String): return {"ok": false, "error": msg}
	if tok.size() < 3 or tok[0] != MAGIC or tok[1].to_int() != VERSION:
		return fail.call("bad header")
	cur[0] = 2
	var take := func() -> String:
		var s: String = tok[cur[0]] if cur[0] < tok.size() else "0"
		cur[0] += 1
		return s
	var setup := {}
	setup.seed = take.call().to_int()
	setup.terrain_seed = take.call().to_int()
	setup.terrain = take.call().to_int()
	var nx: float = take.call().to_float()
	var nz: float = take.call().to_float()
	setup.nest = Vector2(nx, nz)
	setup.flat_height = take.call().to_float()
	var wx: float = take.call().to_float()
	var wz: float = take.call().to_float()
	var wr: float = take.call().to_float()
	setup.water = Vector3(wx, wz, wr)
	var n_wild: int = take.call().to_int()
	var n_obs: int = take.call().to_int()
	var read_profile := func() -> Dictionary:
		var p := {}
		for k in ["mouth", "charge", "spit", "tail", "guard"]:
			p[k] = take.call().to_int()
		for k in ["hp", "stamina", "speed"]:
			p[k] = take.call().to_float()
		p.radius_cm = take.call().to_int()
		return p
	setup.player = read_profile.call()
	var wild := []
	for i in n_wild:
		var w := {}
		w.x = take.call().to_float()
		w.z = take.call().to_float()
		w.home_x = take.call().to_float()
		w.home_z = take.call().to_float()
		w.species = take.call().to_int()
		w.bot = take.call().to_int()
		w.profile = read_profile.call()
		wild.append(w)
	setup.wild = wild
	var obstacles := []
	for i in n_obs:
		var o := {}
		o.x = take.call().to_float()
		o.z = take.call().to_float()
		o.r = take.call().to_float()
		o.type = take.call().to_int()
		obstacles.append(o)
	setup.obstacles = obstacles
	var ticks: int = take.call().to_int()
	if cur[0] > tok.size() or ticks < 0 or tok.size() - cur[0] != ticks * 9:
		return fail.call("bad length")
	var inputs := []
	for i in ticks:
		var a := {}
		a.verb = take.call().to_int()
		a.target = take.call().to_int()
		a.move = take.call().to_int()
		a.dir = take.call().to_int()
		a.sprint = take.call().to_int()
		a.hx = take.call().to_int()
		a.hz = take.call().to_int()
		a.x = take.call().to_float()
		a.z = take.call().to_float()
		inputs.append(a)
	return {"ok": true, "setup": setup, "inputs": inputs, "error": ""}
