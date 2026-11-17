extends RefCounted
## Console commands of the creature stage (C0). Sim-changing commands build a debug op (StageWorld.debug_now,
## which logs it like the queued ones) or an order (StageWorld.queue_order); nothing writes C state otherwise.

const Registry := preload("res://devtools/console/registry.gd")

const DBG_TELEPORT := 1
const DBG_SPAWN := 2
const DBG_KILL := 3
const DBG_HEAL := 4
const DBG_CLOCK := 5
const DBG_FLAGS := 6
const FLAG_GOD := 1
const FLAG_AI_OFF := 2
## Species with a body (godot/game/data/*.json). Others spawn nothing: "no body for species X yet".
const BODIES := {3: "res://game/data/garfio.json"}
const SPAWN_AHEAD := 12.0
const SPAWN_STEP := 8.0

static func ok(s: String = "") -> Dictionary:
	return Registry.ok(s)

static func fail(s: String) -> Dictionary:
	return Registry.fail(s)

static func _need_stage(r):
	return r.stage()

static func _id(tok: String) -> int:
	if tok.begins_with("#") and tok.substr(1).is_valid_int():
		return tok.substr(1).to_int()
	return -1

static func _op(st, op: Dictionary) -> String:
	var rc: int = st.debug_now(op)
	return "" if rc == 0 else CporeWorld.debug_error(rc)

static func species_index(name: String) -> int:
	if name.is_valid_int():
		return name.to_int()
	for s in CporeWorld.species():
		if str(s.name).to_lower() == name.to_lower():
			return int(s.id)
	return -1

static func register_all(r) -> void:
	r.register("help", "[command]", "list the commands, or explain one", func(a): return ok(r.help_text(a[0] if a.size() > 0 else "")), {"dev": false,
		"complete": func(i, p, t): return r.commands.keys() if i == 0 else []})
	r.register("tp", "<site> | <x> <z> | #id <x> <z>", "teleport the player (or a creature) to a site or a spot",
		func(a): return _tp(r, a), {"changes_sim": true, "complete": func(i, p, t): return _site_names(r) if i == 0 else []})
	r.register("spawn", "<species> [count]", "spawn creatures 12 m ahead of the player (only species with a body)",
		func(a): return _spawn(r, a), {"changes_sim": true, "complete": func(i, p, t): return _species_names() if i == 0 else []})
	r.register("kill", "#id | radius <m>", "kill a creature, or every wild creature within a radius",
		func(a): return _kill(r, a), {"changes_sim": true, "complete": func(i, p, t): return ["radius"] if i == 0 else []})
	r.register("heal", "[#id]", "restore hp and stamina (the player by default)", func(a): return _heal(r, a), {"changes_sim": true})
	r.register("give", "hp <n> | stamina <n> | dna <n>", "set the player's hp or stamina", func(a): return _give(r, a),
		{"changes_sim": true, "complete": func(i, p, t): return ["hp", "stamina", "dna"] if i == 0 else []})
	r.register("time", "<hh:mm>", "set the time of day (a day is 12000 ticks)", func(a): return _time(r, a), {"changes_sim": true})
	r.register("timescale", "<x>", "simulation speed (0.01 to 100)", func(a): return _timescale(r, a))
	r.register("pause", "[on|off]", "pause or resume the simulation", func(a): return _pause(r, a),
		{"complete": func(i, p, t): return ["on", "off"] if i == 0 else []})
	r.register("step", "[n]", "advance n ticks now (default 1)", func(a): return _step(r, a))
	r.register("ai", "on|off", "wild creatures stop (off) or resume (on) walking and attacking",
		func(a): return _flag(r, a, FLAG_AI_OFF, true), {"changes_sim": true, "complete": func(i, p, t): return ["on", "off"] if i == 0 else []})
	r.register("god", "[on|off]", "the player cannot die", func(a): return _flag(r, a, FLAG_GOD, false),
		{"changes_sim": true, "complete": func(i, p, t): return ["on", "off"] if i == 0 else []})
	r.register("reveal", "", "show hidden sites in the site picker", func(a):
		r.flags["reveal"] = true
		return ok("hidden sites are now listed"))
	r.register("order", "<text>", "give the player a command text (attack #1 bite, go 10 20, heading 90, flee...)",
		func(a): return _order(r, a), {"changes_sim": true})
	r.register("trait", "add <name>", "lineage traits", func(a): return fail("lineage traits arrive with L0 (C2)"))
	r.register("stage", "<name>", "jump to another stage", func(a): return fail("stage jump is DT2"))
	r.register("hash", "", "state hash of the C world", func(a): return _with_stage(r, func(st): return ok(st.world.hash())))
	r.register("tick", "", "world tick", func(a): return _with_stage(r, func(st): return ok(str(st.world.state().tick))))
	r.register("obs", "", "the observation text the agents get", func(a): return _with_stage(r, func(st): return ok(st.world.observe())))
	r.register("overlay", "path [on|off]", "debug overlays (off by default): path = the planned GO route drawn on the ground",
		func(a): return _overlay(r, a), {"complete": func(i, p, t): return ["path"] if i == 0 else (["on", "off"] if i == 1 else [])})
	r.register("clear", "", "clear the console", func(a): return {"ok": true, "out": "", "error": "", "clear": true}, {"dev": false})

static func _with_stage(r, fn: Callable) -> Dictionary:
	var st = r.stage()
	if st == null:
		return fail("no stage is running (start the island first)")
	return fn.call(st)

static func _species_names() -> Array:
	var out := []
	for s in CporeWorld.species():
		out.append(str(s.name))
	return out

static func _site_names(r) -> Array:
	var s = r.services.get("sites")
	return s.names() if s != null and s.has_method("names") else []

static func _tp(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		var id := 0
		var args := a
		if args.size() > 0 and args[0].begins_with("#"):
			id = _id(args[0])
			if id < 0:
				return fail("bad creature id '%s' (use #1, #2...)" % args[0])
			args = args.slice(1)
		var x := 0.0
		var z := 0.0
		if args.size() == 2 and args[0].is_valid_float() and args[1].is_valid_float():
			x = args[0].to_float()
			z = args[1].to_float()
		elif args.size() >= 1 and id == 0:
			var sites = r.services.get("sites")
			var q := " ".join(args)
			if sites == null:
				return fail("unknown site '%s' (no site list yet); use: tp <x> <z>" % q)
			var site = sites.find(q)
			if site == null:
				return fail("unknown site '%s' (F2 lists them)" % q)
			x = site.pos.x
			z = site.pos.z
		else:
			return fail("usage: tp <site> | tp <x> <z> | tp #id <x> <z>")
		var err := _op(st, {"op": DBG_TELEPORT, "id": id, "x": x, "z": z})
		return fail(err) if err != "" else ok("teleported #%d to %.1f, %.1f" % [id, x, z]))

static func _spawn(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.size() < 1:
			return fail("usage: spawn <species> [count]")
		var sp := species_index(a[0])
		if sp < 0 or sp > 3:
			return fail("unknown species '%s' (Rondo, Zanco, Espinodo, Garfio)" % a[0])
		var name: String = CporeWorld.species()[sp].name
		if not BODIES.has(sp):
			return fail("no body for species %s yet" % name)
		var count := 1
		if a.size() > 1:
			if not a[1].is_valid_int() or a[1].to_int() < 1 or a[1].to_int() > 12:
				return fail("count must be 1 to 12")
			count = a[1].to_int()
		var p: Dictionary = st.cur.entities[0]
		var f := Vector2(p.fx, p.fz)
		var perp := Vector2(-f.y, f.x)
		var made := PackedInt32Array()
		var last_err := ""
		for i in count:
			var k := (i + 1) / 2
			var off := SPAWN_STEP * k * (1.0 if i % 2 == 1 else -1.0)
			var pos := Vector2(p.x, p.z) + f * SPAWN_AHEAD + perp * off
			var err := _op(st, {"op": DBG_SPAWN, "a": sp, "x": pos.x, "z": pos.y})
			if err == "":
				made.append(int(st.world.state().entities.size()) - 1)
			else:
				last_err = err
		if made.is_empty():
			return fail("nothing spawned: %s" % last_err)
		var msg := "spawned %d %s (#%d..#%d)" % [made.size(), name, made[0], made[made.size() - 1]]
		return ok(msg + ("; some were rejected: %s" % last_err if last_err != "" else "")))

static func _kill(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.size() == 2 and a[0] == "radius" and a[1].is_valid_float():
			var rad := a[1].to_float()
			var s: Dictionary = st.world.state()
			var p: Dictionary = s.entities[0]
			var n := 0
			for e in s.entities.slice(1):
				if not e.dead and int(e.id) - 1 != int(s.active) and Vector2(e.x - p.x, e.z - p.z).length() <= rad:
					if _op(st, {"op": DBG_KILL, "id": int(e.id)}) == "":
						n += 1
			return ok("killed %d" % n)
		if a.size() == 1 and _id(a[0]) > 0:
			var err := _op(st, {"op": DBG_KILL, "id": _id(a[0])})
			return fail(err) if err != "" else ok("killed %s" % a[0])
		return fail("usage: kill #id | kill radius <m>"))

static func _heal(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		var id := 0
		if a.size() == 1:
			id = _id(a[0])
			if id < 0:
				return fail("usage: heal [#id]")
		var err := _op(st, {"op": DBG_HEAL, "id": id, "x": -1.0, "z": -1.0})
		return fail(err) if err != "" else ok("healed #%d" % id))

static func _give(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.size() < 1:
			return fail("usage: give hp <n> | stamina <n> | dna <n>")
		if a[0] == "dna":
			return fail("DNA arrives with C2 (P4)")
		if a.size() != 2 or not a[1].is_valid_float() or a[1].to_float() <= 0.0 and a[0] == "hp":
			return fail("usage: give hp <n> | give stamina <n> (n > 0)")
		var e: Dictionary = st.world.state().entities[0]
		var v := a[1].to_float()
		var op := {"op": DBG_HEAL, "id": 0, "x": float(e.hp), "z": float(e.stamina)}
		if a[0] == "hp":
			op.x = v
		elif a[0] == "stamina":
			op.z = maxf(v, 0.0)
		else:
			return fail("give what? hp, stamina or dna")
		var err := _op(st, op)
		return fail(err) if err != "" else ok("%s set to %s (clamped to the maximum)" % [a[0], a[1]]))

static func _time(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		var parts: PackedStringArray = a[0].split(":") if a.size() == 1 else PackedStringArray()
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
			return fail("usage: time <hh:mm>, for example time 06:30")
		var h := parts[0].to_int()
		var m := parts[1].to_int()
		if h < 0 or h > 23 or m < 0 or m > 59:
			return fail("time must be 00:00 to 23:59")
		var tick := int((h * 60 + m) * 12000.0 / 1440.0)
		var err := _op(st, {"op": DBG_CLOCK, "a": tick})
		return fail(err) if err != "" else ok("clock set to %02d:%02d (tick %d of 12000)" % [h, m, tick]))

static func _timescale(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.size() != 1 or not a[0].is_valid_float() or a[0].to_float() < 0.01 or a[0].to_float() > 100.0:
			return fail("usage: timescale <x> with x from 0.01 to 100")
		st.timescale = a[0].to_float()
		return ok("timescale x%s" % a[0]))

static func _pause(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.size() == 0:
			st.paused = not st.paused
		elif a[0] == "on" or a[0] == "off":
			st.paused = a[0] == "on"
		else:
			return fail("usage: pause [on|off]")
		return ok("paused" if st.paused else "running"))

static func _step(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		var n := 1
		if a.size() == 1:
			if not a[0].is_valid_int() or a[0].to_int() < 1 or a[0].to_int() > 10000:
				return fail("usage: step [n] with n from 1 to 10000")
			n = a[0].to_int()
		st.step_ticks(n)
		return ok("tick %d" % int(st.cur.tick)))

static func _overlay(r, a: PackedStringArray) -> Dictionary:
	if a.size() < 1 or a[0] != "path":
		return fail("usage: overlay path [on|off]")
	var o = r.services.get("path_overlay")
	if o == null:
		return fail("the path overlay needs the island running")
	var on: bool = not o.enabled
	if a.size() > 1:
		if a[1] != "on" and a[1] != "off":
			return fail("usage: overlay path [on|off]")
		on = a[1] == "on"
	o.set_enabled(on)
	return ok("path overlay %s" % ("on" if on else "off"))

static func _flag(r, a: PackedStringArray, bit: int, off_means_set: bool) -> Dictionary:
	return _with_stage(r, func(st):
		var flags: int = int(st.world.state().flags)
		var on: bool
		if a.size() == 0:
			if off_means_set:
				return fail("usage: ai on|off")
			on = (flags & bit) == 0
		elif a[0] == "on" or a[0] == "off":
			on = a[0] == "on"
			if off_means_set:
				on = not on        # "ai off" sets the AI_OFF bit
		else:
			return fail("usage: %s on|off" % ("ai" if off_means_set else "god"))
		flags = (flags | bit) if on else (flags & ~bit)
		var err := _op(st, {"op": DBG_FLAGS, "a": flags})
		if err != "":
			return fail(err)
		return ok("god mode %s" % ("on" if (flags & FLAG_GOD) else "off") if not off_means_set else "wild AI %s" % ("off" if (flags & FLAG_AI_OFF) else "on")))

static func _order(r, a: PackedStringArray) -> Dictionary:
	return _with_stage(r, func(st):
		if a.is_empty():
			return fail("usage: order <text>, for example: order attack #1 bite")
		var text := " ".join(a)
		var res: Dictionary = st.world.command_input(text)
		if int(res.rc) != 0:
			return fail("%s ('%s')" % [CporeWorld.order_error(int(res.rc)), text])
		st.queue_order(res.input)
		return ok("queued for the next tick: %s" % text))
