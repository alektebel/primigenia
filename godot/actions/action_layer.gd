extends RefCounted
## Per-actor action layer (docs/godot/PLAN-actions.md 1.7): slots, priorities, track sampling, blending, springs.
##   layer.setup(map, raw_actions, creature, entity_id)
##   layer.update(dt, ctx)      ctx from the island (see below)
##   layer.apply(pose)          after LocoController.step, before the adapter writes the rig
## ctx: {sig: ActionFeed signal, tick, alpha, pos, yaw, speed, target: {id, pos, radius, height, spheres}, beat_phase,
##       mode: "" | "observe", attend: bool, dodge_dir: -1|0|1}
## C is the only authority for combat: the layer mirrors its state and never decides a hit or a cancel.

signal action_event(name: String, data: Dictionary)
## A64 chain: a peck that starts within this many C ticks of the creature's own bite hit plays as the chained peck.
const CHAIN_TICKS := 7

const Clock := preload("action_clock.gd")
const Data := preload("action_data.gd")
const Springs := preload("action_springs.gd")
const Solver := preload("action_solver.gd")
const Rig := preload("action_rig.gd")
const Impact := preload("impact_fx.gd")
const G := 9.81

var map
var solver
var springs
var creature
var entity_id := 0
var actions := {}            # id -> compiled (variants resolved for this body)
var fidgets: Array = []
var inst: Array = []         # live instances
var time := 0.0
var debug := {}
var enabled := true
var light := false            # far actors: no CCD reach, no aim
var idle_on := true          # tests switch the idle layer (breathing, look-around, fidgets) off
var rng := RandomNumberGenerator.new()
var _pending: Array = []     # cosmetic triggers waiting for the next tick boundary
var _last_tick := -1
var _dt_hint := 0.016
var _alt := 0
var _ctx: Dictionary = {}
var _acc_prev := Vector3.ZERO
var _lp_acc := Vector3.ZERO
var _vel_prev := Vector3.ZERO
var _off_prev := Vector3.ZERO
var _idle_t := 0.0
var _next_fidget := 8.0
var _look := {"yaw": 0.0, "pitch": 0.0, "ty": 0.0, "tp": 0.0, "side": 0.0, "ts": 0.0, "next": 1.0, "next_s": 4.0}
var _still_time := 0.0
var _last_hit_dir := 1.0
var _last_hit_amount := 12.0
var _pull := {}               # visual grip of a bite on THIS creature: {t, len, dir (body frame), amp}; C owns positions
var _mouth_world := Vector3.ZERO
var _extra_prev := {}         # last follow-through (held through a hit-pause)
var _out := {}               # last channel result
var last_act: Dictionary = {}
var flash := 0.0              # 0..1: the pale flash of a creature that was just hit (the driver writes it on the meshes)
var _pause_left := 0.0        # seconds of hit-pause left: the layer's own clock stands still (C ticks go on)
var _bite_hit_tick := -1000   # C tick of this creature's last bite that connected (the chain window opens here)

func setup(body_map, raw: Dictionary, c, id: int) -> void:
	map = body_map
	creature = c
	entity_id = id
	rng.seed = 1000 + id
	solver = Solver.new()
	solver.setup(map, float(c.ground_offset))
	springs = Springs.new()
	actions.clear()
	fidgets.clear()
	for k in raw:
		var comp: Dictionary = Data.compile(Data.resolve(raw[k], map.caps))
		actions[k] = comp
		if comp.driver.kind == "idle" and k != "idle_base":
			fidgets.append(comp)
	_next_fidget = rng.randf_range(6.0, 10.0)
	_start_base()

func _start_base() -> void:
	if actions.has("idle_base"):
		inst.append(_new_inst(actions.idle_base, "idle_base"))

func _new_inst(act: Dictionary, kind: String) -> Dictionary:
	return {"id": act.id, "act": act, "kind": kind, "age": 0.0, "tau": 0.0, "tscale": 1.0, "ending": false, "fading": false, "fade_t": 0.0,
		"fade_len": 0.12, "amp": 1.0, "side": 1.0, "hit": false, "hit_time": 0.0, "grid_shift": 0.0, "fired": {}, "move": -1, "e_seen": 0, "removed": false}

# ---------------------------------------------------------------------------------------------
# public
# ---------------------------------------------------------------------------------------------

## Cosmetic start (social, intimidate, observe one-shots). Quantised to the next C tick. Returns false if unknown.
func trigger(id: String, args := {}) -> bool:
	if not actions.has(id) or actions[id].driver.kind != "cosmetic":
		return false
	_pending.append([id, args])
	return true

## Impulse reactions (2.2): dir = unit vector from the attacker to this creature in its body frame (x left, z forward).
func react(kind: String, dir: Vector3, amount: float, move := -1, knock := 1.0) -> void:
	var m := clampf(amount / 20.0, 0.3, 1.5) * knock
	match kind:
		"hit":
			# a clear hit reaction, scaled by damage: the body recoils away from the hit, the head snaps back,
			# a 2-3 frame squash (root.lift spring dip) and a brief stumble (the loco legs follow the recoil)
			var k := 1.0 if move != 1 else 1.5     # a charge hits harder than its damage says
			springs.kick("root.side", 4.0 * k * m * dir.x)
			springs.kick("root.lunge", 5.0 * k * m * dir.z)
			springs.kick("root.roll", -2.5 * k * m * dir.x)
			springs.kick("root.pitch", -2.5 * k * m * dir.z)
			springs.kick("root.lift", -3.0 * m)
			springs.kick("head.yaw", -6.0 * m * dir.x)
			springs.kick("head.pitch", 5.0 * m)
			springs.kick("tail.yaw", 5.0 * m * dir.x)
			_start_oneshot("hit", clampf(0.6 + 0.5 * m, 0.6, 1.4))
			if move == 0:
				# the bite holds on: after the first jolt the creature is tugged toward the biter and shaken
				_pull = {"t": 0.0, "len": 0.3, "dir": dir, "amp": clampf(m, 0.5, 1.2)}
		"block":
			springs.kick("root.lunge", -3.0)
			springs.kick("head.pitch", -2.0)
		"break":
			springs.kick("root.lunge", -3.5)
			springs.kick("head.pitch", -3.0)
			springs.kick("root.roll", 2.0 * signf(dir.x if dir.x != 0.0 else 1.0))

func current_ids() -> Array:
	var out := []
	for i in inst:
		out.append(i.id)
	return out

func weight_of(id: String) -> float:
	var w := 0.0
	for i in inst:
		if i.id == id:
			w = maxf(w, _weight(i))
	return w

func clear() -> void:
	inst.clear()
	springs.clear()
	_pull = {}
	_pending.clear()
	solver.rdy.fill(0.0)
	solver.rdp.fill(0.0)
	solver.extra_lunge = 0.0
	_start_base()

## Hit-pause (impact_fx.gd): the layer holds every instance where it is for `seconds` of real time. C keeps ticking; when
## the pause ends the instances jump to C's tau (the keys right after a contact are flat, so the catch-up does not show).
func hit_pause(seconds: float) -> void:
	_pause_left = maxf(_pause_left, seconds)
	for i in inst:
		i["ftau"] = i.tau

func paused() -> bool:
	return _pause_left > 0.0

# ---------------------------------------------------------------------------------------------
# instances
# ---------------------------------------------------------------------------------------------

func _find(kind: String) -> Dictionary:
	for i in inst:
		if i.kind == kind and not i.fading and not i.removed:
			return i
	return {}

func _find_id(id: String) -> Dictionary:
	for i in inst:
		if i.id == id and not i.fading and not i.removed:
			return i
	return {}

func _fade(i: Dictionary, len: float) -> void:
	if i.fading:
		return
	i.fading = true
	i.fade_t = 0.0
	i.fade_len = maxf(len, 0.02)

func _fade_len(i: Dictionary, key: String, d: float) -> float:
	return float((i.act.fade as Dictionary).get(key, d))

func _weight(i: Dictionary) -> float:
	var f: Dictionary = i.act.fade
	var win := float(f.get("in", 0.1))
	var w := smoothstep(0.0, maxf(win, 1e-3), i.age) if win > 0.0 else 1.0
	if i.fading:
		w *= 1.0 - clampf(i.fade_t / i.fade_len, 0.0, 1.0)
	return w

func _start(act: Dictionary, kind: String, args := {}) -> Dictionary:
	# priority: a running instance of higher priority in the action slot keeps the slot
	var slot_action := kind in ["c_move", "c_move_end", "c_state", "cosmetic"]
	if slot_action:
		for o in inst:
			if o.kind in ["c_move", "c_move_end", "c_state", "cosmetic"] and not o.fading and o.act.priority > act.priority:
				return {}
		for o in inst:
			if o.kind in ["c_move", "c_move_end", "c_state", "cosmetic"] and not o.fading:
				_fade(o, _fade_len(o, "cancel", 0.08))
	var i := _new_inst(act, kind)
	i.side = _side_for(act, args)
	if slot_action:
		for k in args:
			i[k] = args[k]
	inst.append(i)
	return i

func _start_oneshot(id: String, amp := 1.0) -> void:
	if actions.has(id):
		var i := _new_inst(actions[id], "oneshot")
		i.amp = amp
		inst.append(i)

func _side_for(act: Dictionary, args: Dictionary) -> float:
	var s = act.side
	var tgt: Dictionary = _ctx.get("target", {})
	var bearing := 1.0
	if not tgt.is_empty() and _ctx.has("pos"):
		var d: Vector3 = (tgt.pos as Vector3) - (_ctx.pos as Vector3)
		var left := Vector3(cos(_ctx.yaw), 0.0, -sin(_ctx.yaw))
		var x := d.dot(left)
		bearing = 1.0 if x >= 0.0 else -1.0
	if typeof(s) == TYPE_FLOAT or typeof(s) == TYPE_INT:
		return float(s)
	match str(s):
		"target": return bearing
		"dash":
			var dd := int(_ctx.get("dodge_dir", 0))
			if dd != 0:
				return -float(dd)
			var v: Vector3 = _ctx.get("vel", Vector3.ZERO)
			var left2 := Vector3(cos(_ctx.get("yaw", 0.0)), 0.0, -sin(_ctx.get("yaw", 0.0)))
			return 1.0 if v.dot(left2) >= 0.0 else -1.0
		"alternate":
			_alt += 1
			return 1.0 if _alt % 2 == 0 else -1.0
		"away_hit": return _last_hit_dir
	return 1.0

# ---------------------------------------------------------------------------------------------
# update
# ---------------------------------------------------------------------------------------------

func update(dt: float, ctx: Dictionary) -> void:
	if not enabled:
		return
	_ctx = ctx
	_dt_hint = dt
	time += dt
	var sig: Dictionary = ctx.get("sig", {})
	var tick: int = ctx.get("tick", 0)
	var tick_changed := tick != _last_tick
	_last_tick = tick
	_handle_state(dt, sig, ctx)
	var frozen := _pause_left > 0.0
	var fdt := 0.0 if frozen else dt
	if frozen:
		for fi in inst:
			if fi.has("ftau"):
				fi.tau = fi.ftau
		_pause_left = maxf(0.0, _pause_left - dt)
	else:
		for fi in inst:
			fi.erase("ftau")
		flash = maxf(0.0, flash - dt / Impact.FLASH_LIFE)
	if tick_changed and not _pending.is_empty():
		for p in _pending:
			_start_cosmetic(p[0], p[1], tick, ctx)
		_pending.clear()
	_handle_eat(ctx)
	_handle_stances(sig, ctx)
	_idle_update(dt, sig)
	# advance
	if not _pull.is_empty():
		_pull.t += fdt
		if _pull.t >= _pull.len:
			_pull = {}
	var keep: Array = []
	for i in inst:
		i.age += fdt
		if i.fading:
			i.fade_t += fdt
			if i.fade_t >= i.fade_len:
				i.removed = true
		if i.kind == "c_move" and not i.ending:
			pass
		elif i.get("slaved", false):
			pass          # the eat meal: tau is set from the C eat action every frame (_handle_eat)
		elif i.id != "idle_base" and i.kind != "stance":
			i.tau += fdt / Clock.DT / i.tscale
			if not i.act.hold:
				var l: Dictionary = Clock.locate(i.tau, i.act.w, i.act.a, i.act.r, i.act.settle)
				if l.done and not i.fading:
					_fade(i, _fade_len(i, "out", 0.12))
		if not i.removed:
			keep.append(i)
	inst = keep

func _handle_state(dt: float, sig: Dictionary, ctx: Dictionary) -> void:
	if sig.is_empty():
		return
	var marks: Array = sig.get("marks", [])
	var cm := _find("c_move")
	# death
	if sig.get("dead", false):
		if _find_id("death").is_empty():
			for o in inst:
				if o.id != "idle_base":
					_fade(o, 0.1)
			if actions.has("death"):
				var i := _new_inst(actions.death, "c_state")
				i.tscale = clampf(0.45 * sqrt(map.height / 0.5), 0.35, 1.2) / 0.6
				i.side = _last_hit_dir
				inst.append(i)
		return
	elif not _find_id("death").is_empty() or _death_present():
		clear()
		return
	# marks
	for m in marks:
		if m == "cancel" and not cm.is_empty():
			if cm.act.on_cancel == "recover":
				cm.ending = true
				cm.tau = maxf(cm.tau, cm.act.w + cm.act.a)
			else:
				_fade(cm, _fade_len(cm, "cancel", 0.08))
			cm = {}
		elif m == "end" and not cm.is_empty():
			cm.ending = true
			cm.kind = "c_move_end"
			cm = {}
	# events
	for ev in sig.get("events", []):
		_on_event(ev, ctx)
	# a C move
	var mv: int = sig.get("move", -1)
	if mv >= 0 and sig.get("e", 0) > 0:
		var name: String = Clock.MOVE_NAMES.get(mv, "")
		if name == "peck" and actions.has("peck_chain") and int(ctx.get("tick", 0)) - _bite_hit_tick <= CHAIN_TICKS:
			name = "peck_chain"           # A64: the quick peck right after our own bite
		if cm.is_empty() or cm.move != mv or "start" in marks:
			if not cm.is_empty():
				_fade(cm, _fade_len(cm, "cancel", 0.08))
			for o in inst:
				if o.id in ["stun", "stagger"]:
					_fade(o, 0.08)          # C lets a creature act again: its stun (whose length C does not tell) is over
			if actions.has(name):
				var i := _start(actions[name], "c_move")
				if not i.is_empty():
					i.move = mv
					i.tau = sig.tau
					i.e_seen = sig.e
					# a cosmetic action is cancelled by any C move (1.7)
					for o in inst:
						if o.kind == "cosmetic":
							_fade(o, 0.08)
					cm = i
		else:
			cm.tau = maxf(cm.tau, sig.tau)
			cm.e_seen = sig.e
	elif not cm.is_empty():
		# state no longer shows the move (marks missed): finish it normally from where it is
		cm.ending = true
		cm.kind = "c_move_end"
	# stagger
	if sig.get("stagger", false):
		if _find_id("stagger").is_empty() and actions.has("stagger"):
			for o in inst:
				if o.kind in ["c_move", "c_move_end", "cosmetic"]:
					_fade(o, 0.08)
			var s := _new_inst(actions.stagger, "c_state")
			s.amp = clampf(_last_hit_amount / 12.0, 0.6, 1.6)
			s.tscale = maxf(float(sig.stagger_len), 1.0) / maxf(actions.stagger.a, 1.0)
			s.age = 0.0
			inst.append(s)
	else:
		var sg := _find_id("stagger")
		if not sg.is_empty():
			sg.ending = true

func _death_present() -> bool:
	for i in inst:
		if i.id == "death":
			return true
	return false

func _on_event(ev: Dictionary, ctx: Dictionary) -> void:
	var tgt: Dictionary = ctx.get("target", {})
	var dir_local := Vector3(0, 0, -1)
	if not tgt.is_empty() and ctx.has("pos"):
		var dw: Vector3 = (ctx.pos as Vector3) - (tgt.pos as Vector3)
		dw.y = 0.0
		dw = dw.normalized() if dw.length() > 1e-4 else Vector3(0, 0, 1)
		var left := Vector3(cos(ctx.yaw), 0.0, -sin(ctx.yaw))
		var fwd := Vector3(sin(ctx.yaw), 0.0, cos(ctx.yaw))
		dir_local = Vector3(dw.dot(left), 0.0, dw.dot(fwd))
	var me := entity_id
	match int(ev.type):
		1:      # HIT: a damaged b
			var melee := Impact.is_melee(int(ev.move))
			var other_h: float = float(tgt.get("height", map.height))
			if ev.a == me:
				var cm := _find("c_move")
				if not cm.is_empty():
					cm.hit = true
					cm.hit_tau = cm.tau
					if melee:
						cm.tau = maxf(cm.tau, cm.act.w)       # the contact pose is the one the pause holds
				if int(ev.move) == 1:
					_start_oneshot("strike")      # the charge lands: squash and rebound of the attacker
				if int(ev.move) == 0:
					_bite_hit_tick = int(ctx.get("tick", 0))
				_force_impact()
				if melee:
					hit_pause(Impact.pause_seconds(map.height, other_h))
					_emit_hit_fx(ev, tgt, other_h)
			if ev.b == me:
				_last_hit_dir = -signf(dir_local.x) if dir_local.x != 0.0 else 1.0
				_last_hit_amount = float(ev.amount)
				react("hit", dir_local, ev.amount, int(ev.move), Impact.knock_scale(other_h, map.height) if melee else 1.0)
				if melee:
					flash = Impact.flash_strength(float(ev.amount))
					hit_pause(Impact.pause_seconds(map.height, other_h))
				for o in inst:
					if o.kind == "cosmetic":
						_fade(o, 0.08)
		2:      # BLOCKED
			if ev.b == me:
				react("block", dir_local, ev.amount)
		3, 5:   # GUARD_BROKEN / INTERRUPTED
			if ev.b == me:
				react("break", dir_local, ev.amount)
		6:      # STUNNED
			if ev.b == me and actions.has("stun"):
				var s := _new_inst(actions.stun, "c_state")
				inst.append(s)

## The contact effect of a melee hit this creature dealt: where (the target's surface nearest the mouth), which way (attacker to
## victim, horizontal), how hard and how big. The driver spawns the dust and sparks, the island shakes the camera.
func _emit_hit_fx(ev: Dictionary, tgt: Dictionary, other_h: float) -> void:
	var pos: Vector3 = _ctx.get("pos", Vector3.ZERO)
	var at: Vector3 = pos + Vector3.UP * map.height * 0.5
	var dir := Vector3(sin(float(_ctx.get("yaw", 0.0))), 0.0, cos(float(_ctx.get("yaw", 0.0))))
	if not tgt.is_empty():
		var p = _goal_point("target_surface", {"root": Transform3D(Basis.IDENTITY, pos)})
		if p != null:
			at = p
		var d: Vector3 = (tgt.pos as Vector3) - pos
		d.y = 0.0
		if d.length() > 0.05:
			dir = d.normalized()
	action_event.emit("hit_fx", {"entity": entity_id, "pos": at, "dir": dir, "amount": float(ev.amount), "move": int(ev.move),
		"size": map.height, "victim_size": other_h, "attacker": entity_id, "victim": int(ev.b)})

## C says this creature hit something. Normally the instance reaches tau = W in the same frame; when C cancelled the
## move in the very tick it hit (a clash), the impact is still delivered, once, to whatever instance has not fired it.
func _force_impact() -> void:
	for k in range(inst.size() - 1, -1, -1):
		var i: Dictionary = inst[k]
		if i.move < 0:
			continue
		for idx in i.act.events.size():
			if i.act.events[idx].emit == "impact" and not i.fired.has(idx):
				i.fired[idx] = true
				action_event.emit("impact", {"id": i.id, "entity": entity_id, "tau": i.tau, "forced": true})
		return

func _start_cosmetic(id: String, args: Dictionary, tick: int, ctx: Dictionary) -> void:
	var act: Dictionary = actions[id]
	var sig: Dictionary = ctx.get("sig", {})
	if sig.get("move", -1) >= 0 or sig.get("dead", false):
		return
	var i := _start(act, "cosmetic")
	if i.is_empty():
		return
	i.grid_shift = Clock.grid_shift(tick, int(act.w), int(act.a), int(ctx.get("beat_phase", 0)))
	for k in args:
		i[k] = args[k]

## The meal (eat verb). ctx.eat = {mode: "act", t: C act tick, pos: food point, kind: "carcass" | "plant" | ...}.
## While C runs the eat action the instance's tau follows its tick (first bite = ticks 0..10, then the 10..20 loop), so a bite
## lands on the C bite tick; when C ends or cancels it the instance plays its recovery, and a C move (a fight) cancels it.
const EAT_LOOP := 10.0
func eat_tau(act: Dictionary, t: int, alpha: float) -> float:
	var te := float(t) if t < int(EAT_LOOP) else EAT_LOOP + float((t - int(EAT_LOOP)) % int(EAT_LOOP))
	return float(act.w) + te + alpha

func eating() -> bool:
	return not _slaved_eat().is_empty()

func _slaved_eat() -> Dictionary:
	for i in inst:
		if i.id == "eat" and i.get("slaved", false) and not i.fading and not i.removed:
			return i
	return {}

func _handle_eat(ctx: Dictionary) -> void:
	var eat: Dictionary = ctx.get("eat", {})
	var cur := _slaved_eat()
	var mode: String = str(eat.get("mode", ""))
	var sig: Dictionary = ctx.get("sig", {})
	if not actions.has("eat"):
		return
	var act: Dictionary = actions.eat
	if mode != "act" or sig.get("move", -1) >= 0 or sig.get("dead", false):
		if not cur.is_empty():
			cur.slaved = false                    # C ended it: the recovery (swallow, head up) plays out, then it fades
			if mode != "act" and sig.get("move", -1) < 0:
				cur.tau = float(act.w) + float(act.a)
			elif sig.get("move", -1) >= 0:
				_fade(cur, 0.08)
		return
	if cur.is_empty():
		if float(ctx.get("speed", 0.0)) > 0.03 * sqrt(G * map.height):
			return
		var i := _start(act, "cosmetic")
		if i.is_empty():
			return
		i.slaved = true
		i.tau = float(act.w)
		i.grid_shift = 0.0
		cur = i
	cur.tau = eat_tau(act, int(eat.get("t", 0)), float(ctx.get("alpha", 0.0)))

## A C bite landed (EV_EAT): the layer announces it for the crumbs, the chunk and the sound at the mouth.
func eat_bite(bites_left: int, kind := "carcass") -> void:
	action_event.emit("eat_bite", {"entity": entity_id, "left": bites_left, "kind": kind, "mouth": _mouth_world})

func _handle_stances(sig: Dictionary, ctx: Dictionary) -> void:
	var want := {}
	if ctx.get("mode", "") == "observe":
		want["observe"] = true
	if ctx.get("attend", false):
		want["attend"] = true
	if sig.get("in_fight", false) and sig.get("phase", 0) == 0 and sig.get("move", -1) < 0 and not sig.get("stagger", false) and not sig.get("dead", false):
		want["combat_ready"] = true
	for id in ["observe", "attend", "combat_ready"]:
		var cur := _find_id(id)
		if want.get(id, false) and actions.has(id):
			if cur.is_empty():
				var i := _new_inst(actions[id], "stance")
				inst.append(i)
		elif not cur.is_empty():
			_fade(cur, _fade_len(cur, "out", 0.25))
	# rooted cosmetic actions are cancelled by moving
	var thr := 0.03 * sqrt(G * map.height)
	for i in inst:
		if i.kind == "cosmetic" and i.act.rooted and float(ctx.get("speed", 0.0)) > thr and not i.fading:
			_fade(i, 0.08)
		if i.id == "observe" and not i.fading:
			pass

func _idle_update(dt: float, sig: Dictionary) -> void:
	# look around and weight shift targets
	var L := _look
	L.next -= dt
	if L.next <= 0.0:
		L.next = rng.randf_range(2.0, 6.0)
		L.ty = rng.randf_range(-0.5, 0.5)
		L.tp = rng.randf_range(-0.15, 0.15)
	L.next_s -= dt
	if L.next_s <= 0.0:
		L.next_s = rng.randf_range(6.0, 12.0)
		L.ts = rng.randf_range(-0.08, 0.08)
	var f := 1.0 - exp(-dt / 0.7)
	L.yaw = lerpf(L.yaw, L.ty, f)
	L.pitch = lerpf(L.pitch, L.tp, f)
	L.side = lerpf(L.side, L.ts, 1.0 - exp(-dt / 1.5))
	# fidgets: only when nothing else is happening for a while
	var busy := false
	for i in inst:
		if i.id != "idle_base" and i.kind != "idle":
			busy = true
	if busy or sig.get("in_fight", false) or not idle_on:
		_idle_t = 0.0
	else:
		_idle_t += dt
	_next_fidget -= dt if not busy else 0.0
	if _idle_t > 0.0 and _next_fidget <= 0.0 and not fidgets.is_empty():
		_next_fidget = rng.randf_range(8.0, 16.0)
		var tot := 0.0
		for fa in fidgets:
			tot += fa.weight
		var r := rng.randf() * tot
		for fa in fidgets:
			r -= fa.weight
			if r <= 0.0:
				if _find("idle").is_empty():
					var i := _new_inst(fa, "idle")
					inst.append(i)
				break
	elif busy:
		_next_fidget = maxf(_next_fidget, 8.0)

# ---------------------------------------------------------------------------------------------
# channels
# ---------------------------------------------------------------------------------------------

func _clocks(i: Dictionary) -> Dictionary:
	var t: float = i.age
	if i.id == "idle_base":
		t = time
	return {"time": t, "breath": time * clampf(0.8 / sqrt(map.height + 0.5), 0.2, 1.2), "grid_shift": i.grid_shift, "grid_origin": i.act.w, "hit": i.hit, "beat_t": fposmod(float(_ctx.get("tick", 0)) + float(_ctx.get("alpha", 0.0)) - float(_ctx.get("beat_phase", 0)), 12.0)}

func _eval(pose: Dictionary) -> Dictionary:
	var ch := {}
	for k in Data.CHANNELS:
		ch[k] = 0.0
	var kin := {}
	var goals := {}          # channel -> [weight, kind]
	var busy := 0.0
	var plant_w := 0.0
	var m_head := 0.0
	var m_tail := 0.0
	var order := inst.duplicate()
	order.sort_custom(func(a, b): return (a.id == "idle_base") > (b.id == "idle_base"))
	order.reverse()          # non-idle first: `still` is needed by the idle base
	for i in order:
		var w := _weight(i)
		if w <= 0.0005:
			continue
		var idle_base: bool = i.id == "idle_base"
		if idle_base and not idle_on:
			continue
		var k := 1.0
		if idle_base:
			k = (1.0 - clampf(ch["still"], 0.0, 1.0)) * (1.0 - 0.7 * busy)
		else:
			if i.act["class"] in ["combat", "reaction"] or i.kind in ["c_move", "c_move_end", "c_state"]:
				busy = maxf(busy, w)
			if i.act.legs == "plant":
				plant_w = maxf(plant_w, w)
		var clocks := _clocks(i)
		for t in i.act.tracks:
			var v: float = Data.sample(t, i.tau, clocks) * float(i.amp)
			if t.signed:
				v *= i.side
			if t.alternate and i.side < 0.0:
				v = -v
			ch[t.ch] += w * v * k
			kin[t.ch] = maxf(kin.get(t.ch, 0.0), w * t.kin * (k if idle_base else 1.0))
			if t.goal != "" and (not goals.has(t.ch) or goals[t.ch][0] < w):
				goals[t.ch] = [w, t.goal]
			if not idle_base and i.act["class"] == "combat":
				var mk: float = t.mask if t.mask >= 0.0 else (1.0 if t.ch.begins_with("tail.") else (0.5 if t.ch.begins_with("head.") or t.ch.begins_with("neck.") else 0.0))
				if t.ch.begins_with("tail."):
					m_tail = maxf(m_tail, w * mk)
				elif t.ch.begins_with("head.") or t.ch.begins_with("neck."):
					m_head = maxf(m_head, w * mk)
	# the grip of a bite on this creature (visual only): pulled toward the biter, shaken, then let go
	if not _pull.is_empty():
		var pt: float = _pull.t
		var pl: float = _pull.len
		var env := smoothstep(0.0, 0.06, pt) * (1.0 - smoothstep(pl - 0.12, pl, pt))
		var d: Vector3 = _pull.dir
		var amp: float = _pull.amp
		var shake := sin(TAU * 11.0 * pt) * env
		ch["root.lunge"] += -d.z * 0.35 * amp * env + 0.04 * amp * shake
		ch["root.side"] += -d.x * 0.35 * amp * env + 0.05 * amp * shake
		ch["head.yaw"] += 0.25 * amp * shake
		ch["root.roll"] += 0.05 * amp * sin(TAU * 11.0 * pt + 1.0) * env
		busy = maxf(busy, env)
	# observe: freeze after stopping for 0.3 s
	var ob := _find_id("observe")
	if not ob.is_empty():
		var fr := clampf((_still_time - 0.3) / 0.1, 0.0, 1.0)
		ch["still"] += _weight(ob) * fr
	# idle look-around and weight shift (scaled by 1 - moving, busy and still)
	var idle_k := (1.0 - clampf(ch["still"], 0.0, 1.0)) * (1.0 - busy) * (1.0 if idle_on else 0.0)
	var mv := smoothstep(0.02, 0.15, float(pose.get("froude", 0.0)))
	ch["head.yaw"] += _look.yaw * idle_k * (1.0 - mv)
	ch["head.pitch"] += _look.pitch * idle_k * (1.0 - mv)
	ch["root.side"] += _look.side * idle_k * (1.0 - mv)
	return {"ch": ch, "kin": kin, "goals": goals, "busy": busy, "plant_w": plant_w, "m_head": m_head, "m_tail": m_tail, "moving": mv}

# ---------------------------------------------------------------------------------------------
# goals
# ---------------------------------------------------------------------------------------------

func _goal_point(kind: String, pose: Dictionary) -> Variant:
	var pos: Vector3 = _ctx.get("pos", (pose.root as Transform3D).origin)
	var yaw: float = _ctx.get("yaw", 0.0)
	var fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var tgt: Dictionary = _ctx.get("target", {})
	var has_t := not tgt.is_empty()
	var tpos: Vector3 = tgt.get("pos", pos + fwd * 4.0)
	var theight: float = tgt.get("height", 1.0)
	match kind:
		"target_surface":
			if not has_t:
				return pos + fwd * 4.0 + Vector3.UP * map.height
			var from: Vector3 = _mouth_world if _mouth_world != Vector3.ZERO else pos + Vector3.UP * map.height
			var best := Vector3.ZERO
			var bd := 1e9
			var spheres: Array = tgt.get("spheres", [])
			if spheres.is_empty():
				spheres = [Vector4(tpos.x, tpos.y + theight * 0.5, tpos.z, tgt.get("radius", 0.6))]
			for s4 in spheres:
				var c := Vector3(s4.x, s4.y, s4.z)
				var d: float = from.distance_to(c) - s4.w
				if d < bd:
					bd = d
					best = c + (from - c).normalized() * s4.w
			return best
		"target_head":
			return tpos + Vector3.UP * theight * 0.8
		"target_ground":
			var g := pos.lerp(tpos, 0.4)
			g.y = pos.y
			return g
		"ground_front":
			return pos + fwd * map.height * 0.5
		"forward":
			return pos + fwd * 5.0 + Vector3.UP * map.height * 0.8
		"up":
			return pos + Vector3.UP * 10.0
		"sky_target":
			var d := (tpos - pos)
			d.y = 0.0
			var dist := d.length()
			return tpos + Vector3.UP * (0.8 * theight + tan(deg_to_rad(35.0)) * dist) if has_t else pos + fwd * 5.0 + Vector3.UP * 4.0
		"away":
			return pos - (tpos - pos).normalized() * 5.0 if has_t else pos - fwd * 5.0
		"item":
			var food: Dictionary = _ctx.get("eat", {})
			if food.has("pos"):
				return food.pos
			return pos + fwd * map.height * 0.5
	return null

# ---------------------------------------------------------------------------------------------
# apply
# ---------------------------------------------------------------------------------------------

func apply(pose: Dictionary, dt: float) -> void:
	if not enabled:
		return
	# the speed of the real body freezes `observe` (still time)
	if float(_ctx.get("speed", 0.0)) < 0.05 * sqrt(G * map.height):
		_still_time += dt
	else:
		_still_time = 0.0
	var e := _eval(pose)
	var ch: Dictionary = e.ch
	var kin: Dictionary = e.kin
	# springs
	var head_len: float = maxf(0.3, map._chain_len([map.head_chain[0]] + map.head_chain) if map.head_chain.size() > 0 else 0.3)
	var tail_len: float = maxf(0.3, map._chain_len(map.tail_chain) if map.tail_chain.size() > 1 else 0.3)
	var w_head := clampf(2.2 * sqrt(G / head_len), 6.0, 40.0)
	var w_tail := clampf(1.6 * sqrt(G / tail_len), 6.0, 40.0)
	var stiff := 1.0
	var ks: float = kin.get("tail.stiff", 0.0)
	if ks > 0.01:
		stiff = lerpf(1.0, ch["tail.stiff"] / ks, clampf(ks, 0.0, 1.0))
	var w_tail_s := clampf(w_tail * sqrt(maxf(stiff, 0.05)), 5.0, 60.0)
	var dt_a := 0.0001 if _pause_left > 0.0 else dt          # hit-pause: springs and solver stand still
	var extra := _follow_through(ch, dt_a, w_head, w_tail_s, head_len, tail_len)
	var out := ch.duplicate()
	var specs := {
		"root.lunge": [16.0, 1.0], "root.side": [16.0, 1.0], "root.lift": [18.0, 1.0], "root.pitch": [16.0, 1.0], "root.roll": [16.0, 1.0], "root.yaw": [16.0, 1.0],
		"head.pitch": [w_head, 0.8], "head.yaw": [w_head, 0.8], "tail.pitch": [w_tail_s, 0.45], "tail.yaw": [w_tail_s, 0.45], "tail.curl": [w_tail_s, 0.45],
		"display": [17.0, 0.5], "arms": [17.0, 0.6]}
	for k in specs:
		out[k] = springs.step(k, ch[k], kin.get(k, 0.0), specs[k][0], specs[k][1], extra.get(k, 0.0), dt_a)
	_out = out
	# loco masks: the action replaces part of the loco head and tail motion while it runs
	var neck: Dictionary = pose.neck
	var tail: Dictionary = pose.tail
	neck.pitch *= 1.0 - e.m_head
	neck.yaw *= 1.0 - e.m_head
	tail.pitch *= 1.0 - e.m_tail
	tail.yaw *= 1.0 - e.m_tail
	# goals to world points
	var goals := {}
	for chn in e.goals:
		var gp = _goal_point(e.goals[chn][1], pose)
		goals[chn] = gp
	pose["ground_y"] = (_ctx.get("pos", Vector3.ZERO) as Vector3).y
	if light:
		out["head.reach"] = 0.0
		out["head.aim"] = 0.0
	var solved: Dictionary = solver.apply(pose, out, goals, dt_a, e.moving * e.plant_w, 1.0)
	if solver.debug.has("mouth"):
		_mouth_world = (pose.root as Transform3D) * ((solver.debug.mouth as Vector3) + Vector3(0.0, solver.go, 0.0))
	var parts := {"jaw": clampf(out["jaw.open"], -0.3, 1.3), "tremble": out["jaw.tremble"], "lids": out["lids"], "sacs": out["sacs"],
		"display": out["display"], "arms": out["arms"], "inflate": clampf(out["body.inflate"], -0.1, 0.1), "time": time, "still": clampf(out["still"], 0.0, 1.0)}
	last_act = {"bone_dy": solved.bone_dy, "bone_dp": solved.bone_dp, "bone_dr": solved.bone_dr, "parts": parts, "com": map.com}
	pose["act"] = last_act
	_fire_events()
	debug = {"ids": current_ids(), "k": solved.k, "busy": e.busy, "out": out}

func _follow_through(ch: Dictionary, dt: float, w_head: float, w_tail: float, head_len: float, tail_len: float) -> Dictionary:
	# acceleration of the action's own root translation (metres) in body space
	var off := Vector3(ch["root.side"] * map.side_cap, ch["root.lift"] * map.height, ch["root.lunge"] * map.lunge_cap)
	if dt <= 0.001:          # hit-pause: nothing moves, so nothing follows through (and no spike when the clock restarts)
		_off_prev = off
		_vel_prev = Vector3.ZERO
		return _extra_prev
	var vel := (off - _off_prev) / maxf(dt, 1e-4)
	var acc := (vel - _vel_prev) / maxf(dt, 1e-4)
	_off_prev = off
	_vel_prev = vel
	_lp_acc = _lp_acc.lerp(acc, 1.0 - exp(-dt / 0.05))
	var a := _lp_acc
	var c := 0.6
	var out := {}
	var th := maxf(map.tail_range, 0.3)
	var hh := maxf(map.head_range, 0.3)
	out["tail.yaw"] = clampf(-c * a.x / (maxf(tail_len, 0.05) * w_tail * w_tail) / th, -0.6, 0.6)
	out["tail.pitch"] = clampf(-c * a.y / (maxf(tail_len, 0.05) * w_tail * w_tail) / th, -0.6, 0.6)
	out["head.yaw"] = clampf(-c * a.x / (maxf(head_len, 0.05) * w_head * w_head) / hh, -0.6, 0.6)
	out["head.pitch"] = clampf(-c * a.y / (maxf(head_len, 0.05) * w_head * w_head) / hh, -0.6, 0.6)
	_extra_prev = out
	return out

func _fire_events() -> void:
	for i in inst:
		for idx in i.act.events.size():
			var ev: Dictionary = i.act.events[idx]
			if not i.fired.has(idx) and i.tau >= ev.tau and not i.fading:
				i.fired[idx] = true
				action_event.emit(ev.emit, {"id": i.id, "entity": entity_id, "tau": i.tau})
