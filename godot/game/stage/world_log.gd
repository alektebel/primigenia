extends RefCounted
# CPORE_WORLD_LOG 2 / 3 / 4 / 5: the text replay format of apps/world_cli.c (--replay).
# parse(text) -> {ok, version, setup, inputs: Array[Dictionary], debug: Array[{tick, op}], snapshot: String,
#                 field: Dictionary ({seed, n, size_m, hash} or empty), error}
# write(setup, inputs, opts = {}) -> String  (setup in the CporeWorld.reset schema, fully resolved).
# v3 (PLAN-devtools step 4) is written only when opts has debug ops, a snapshot file name or a field;
# otherwise the output is the v2 text, byte for byte as before. v4 (A31) is v3 plus a tenth column on every input line, `run`
# (0/1, the run toggle wanted at that tick); it is written only when some input has run set, v2/v3 logs still parse and replay.
#   opts.debug: Array[{tick, op: {op,id,a,x,z,v}}]   opts.snapshot: file name relative to the log
#   opts.field: {seed, n, size_m, hash}

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

static func write(setup: Dictionary, inputs: Array, opts: Dictionary = {}) -> String:
	var lines := PackedStringArray()
	var debug: Array = opts.get("debug", [])
	var snapshot: String = opts.get("snapshot", "")
	var field: Dictionary = opts.get("field", {})
	var any_legs := int(setup.get("player_legs", 0)) != 0
	for w in setup.wild:
		any_legs = any_legs or int(w.get("legs", 0)) != 0
	var any_secrets := int(setup.get("secrets", 0)) != 0 or int(setup.get("start_clock", 0)) != 0
	var any_run := false
	var any_jump := false
	for i in inputs:
		any_run = any_run or int(i.get("run", 0)) != 0
		any_jump = any_jump or int(i.get("jump", 0)) != 0
	any_run = any_run or any_jump
	var any_grip := int(setup.player.get("grip_traits", 0)) != 0 or int(setup.player.get("grip_legs", 0)) != 0
	for w in setup.wild:
		any_grip = any_grip or int(w.profile.get("grip_traits", 0)) != 0 or int(w.profile.get("grip_legs", 0)) != 0
	var v3 := any_grip or any_run or not debug.is_empty() or snapshot != "" or not field.is_empty() or any_legs or any_secrets
	lines.append("%s %d" % [MAGIC, 5 if any_jump else (4 if any_run else (3 if v3 else VERSION))])
	if any_grip:
		var g := "grip %d" % setup.wild.size()
		for p in [setup.player] + setup.wild.map(func(w): return w.profile):
			g += " %d %d" % [int(p.get("grip_traits", 0)), int(p.get("grip_legs", 0))]
		lines.append(g)
	if snapshot != "":
		lines.append("snapshot " + snapshot)
	if any_legs:
		var l := "legs %d %d" % [setup.wild.size(), int(setup.get("player_legs", 0))]
		for w in setup.wild:
			l += " %d" % int(w.get("legs", 0))
		lines.append(l)
	if any_secrets:
		# C2 secrets: bits, clock at tick 0 and the cave record (x z fx fz half length radius; zeros when there is none)
		var c: Dictionary = setup.get("cave", {})
		lines.append("secrets %d %d %d %s %s %s %s %s %s %s" % [int(setup.get("secrets", 0)), int(setup.get("start_clock", 0)), 1 if not c.is_empty() else 0,
			num(c.get("x", 0.0)), num(c.get("z", 0.0)), num(c.get("fx", 0.0)), num(c.get("fz", 0.0)), num(c.get("half", 0.0)), num(c.get("length", 0.0)), num(c.get("radius", 0.0))])
	if not field.is_empty():
		lines.append("field %d %d %s %s" % [field.seed, field.n, num(field.size_m), field.hash])
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
		var row := "%d %d %d %d %d %d %d %s %s" % [i.get("verb", 0), i.get("target", 0), i.get("move", 0),
			i.get("dir", 0), int(i.get("sprint", 0)), i.get("hx", 0), i.get("hz", 0), num(i.get("x", 0.0)), num(i.get("z", 0.0))]
		if any_run:
			row += " %d" % ((1 if int(i.get("run", 0)) != 0 else 0) | (2 if int(i.get("jump", 0)) != 0 else 0))
		lines.append(row)
	if v3:
		lines.append(str(debug.size()))
		for e in debug:
			var o: Dictionary = e.op
			lines.append("%d %d %d %d %s %s %s" % [e.tick, o.get("op", 0), o.get("id", 0), o.get("a", 0),
				num(o.get("x", 0.0)), num(o.get("z", 0.0)), num(o.get("v", 0.0))])
	return "\n".join(lines) + "\n"

static func parse(text: String) -> Dictionary:
	var tok := PackedStringArray()
	for part in text.replace("\t", " ").replace("\r", " ").replace("\n", " ").split(" ", false):
		tok.append(part)
	var cur := [0]  # lambdas capture ints by value; a one-element array is shared
	var fail := func(msg: String): return {"ok": false, "error": msg}
	if tok.size() < 3 or tok[0] != MAGIC or (tok[1].to_int() < 2 or tok[1].to_int() > 5):
		return fail.call("bad header")
	var version: int = tok[1].to_int()
	cur[0] = 2
	var snapshot := ""
	var field := {}
	var legs: Array = []
	var secrets: Array = []
	var grips: Array = []
	while version >= 3 and cur[0] + 1 < tok.size() and (tok[cur[0]] == "snapshot" or tok[cur[0]] == "field" or tok[cur[0]] == "legs" or tok[cur[0]] == "secrets" or tok[cur[0]] == "grip"):
		if tok[cur[0]] == "snapshot":
			snapshot = tok[cur[0] + 1]
			cur[0] += 2
		elif tok[cur[0]] == "secrets":
			if cur[0] + 10 >= tok.size():
				return fail.call("bad secrets line")
			secrets = [tok[cur[0] + 1].to_int(), tok[cur[0] + 2].to_int(), tok[cur[0] + 3].to_int()]
			for k in 7:
				secrets.append(tok[cur[0] + 4 + k].to_float())
			cur[0] += 11
		elif tok[cur[0]] == "grip":
			var cnt: int = tok[cur[0] + 1].to_int()
			if cnt < 0 or cnt > 24 or cur[0] + 3 + 2 * cnt >= tok.size():
				return fail.call("bad grip line")
			for k in cnt + 1:
				grips.append([tok[cur[0] + 2 + 2*k].to_int(), tok[cur[0] + 3 + 2*k].to_int()])
			cur[0] += 4 + 2 * cnt
		elif tok[cur[0]] == "legs":
			var cnt: int = tok[cur[0] + 1].to_int()
			if cur[0] + 2 + cnt >= tok.size():
				return fail.call("bad legs line")
			for k in cnt + 1:
				legs.append(tok[cur[0] + 2 + k].to_int())
			cur[0] += 3 + cnt
		else:
			if cur[0] + 4 >= tok.size():
				return fail.call("bad field line")
			field = {"seed": tok[cur[0] + 1].to_int(), "n": tok[cur[0] + 2].to_int(), "size_m": tok[cur[0] + 3].to_float(), "hash": tok[cur[0] + 4]}
			cur[0] += 5
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
	if not grips.is_empty():
		if grips.size() != n_wild + 1:
			return fail.call("grip count mismatch")
		for k in grips.size():
			var p: Dictionary = setup.player if k == 0 else wild[k-1].profile
			p.grip_traits = grips[k][0]
			p.grip_legs = grips[k][1]
	if legs.size() == n_wild + 1:
		setup.player_legs = legs[0]
		for i in n_wild:
			wild[i].legs = legs[i + 1]
	if not secrets.is_empty():
		setup.secrets = int(secrets[0])
		setup.start_clock = int(secrets[1])
		if int(secrets[2]) != 0:
			setup.cave = {"x": secrets[3], "z": secrets[4], "fx": secrets[5], "fz": secrets[6], "half": secrets[7], "length": secrets[8], "radius": secrets[9]}
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
	var cols := 10 if version >= 4 else 9
	if cur[0] > tok.size() or ticks < 0 or tok.size() - cur[0] < ticks * cols or (version == 2 and tok.size() - cur[0] != ticks * cols):
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
		if version >= 4:
			var r: int = take.call().to_int()
			if r < 0 or r > (3 if version == 5 else 1):
				return fail.call("bad run column")
			a.run = r & 1
			if r & 2:
				a.jump = 1           # v5: bit 1 of the column is the jump of that tick
		inputs.append(a)
	var debug := []
	if version >= 3:
		var nd: int = take.call().to_int()
		if nd < 0 or tok.size() - cur[0] != nd * 7:
			return fail.call("bad debug section")
		for i in nd:
			var e := {"tick": take.call().to_int()}
			var o := {}
			o.op = take.call().to_int()
			o.id = take.call().to_int()
			o.a = take.call().to_int()
			o.x = take.call().to_float()
			o.z = take.call().to_float()
			o.v = take.call().to_float()
			e.op = o
			debug.append(e)
	return {"ok": true, "version": version, "setup": setup, "inputs": inputs, "debug": debug, "snapshot": snapshot, "field": field, "error": ""}
