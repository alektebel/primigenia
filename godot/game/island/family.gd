extends Node3D
## The player's family at the nest (docs/briefs/verb-target.md, part 2; owner 2026-11-22: "at the nest there should be more
## creatures like me"). Two to four siblings of the player's species: the same genome with a small colour variation each, living
## near the nest. They wander on a seeded walk, come back when they drift, follow the player a little when he is near and stop to
## look at him when he comes close (a greeting).
##
## VISUAL ONLY for now, no C slots: they are ActorHost bodies moved by this script, not entities of the C world. So they cannot be
## picked, fought, befriended or hurt, and they do not exist in snapshots or replays.
## HOOK for the C version (roster v9, T9, is merged in the core): the world has 32 wild slots and the island setup fills at most 24
## (CP_STAGE_ROSTER_CAP); CP_STAGE_RESERVE_FAMILY = 4 of the rest are kept free for the nest family and 4 for cousins
## (CP_STAGE_RESERVE_COUSIN). To back a sibling by a slot: append it to the wild roster at reset (or with a debug SPAWN op) using the
## player's species genome, a home on the nest, and a family flag in the slot's social state; evolve already takes the next free
## index (setup.n) for the cousin, so the family slots must be filled after the roster and before any evolve. That needs a new
## snapshot bump only for the family flag; the slots themselves already exist in layout 12.
## Placement and wandering are deterministic from the world seed and the number of frames the game has run, never from the C RNG.

const ActorHost := preload("res://game/actors/actor_host.gd")

const MIN_COUNT := 2
const MAX_COUNT := 4
const HOME_RADIUS := 11.0        # wander circle around the nest (m); starting value
const WALK := 1.5                # m/s, under the player's walk (A39: 2 m/s)
const FOLLOW_RANGE := 30.0       # the player is this near: the siblings drift to him
const KEEP_AWAY := 6.5           # they stop this far from the player
const GREET_RANGE := 9.0
const GREET_TIME := 2.2
const GREET_COOLDOWN := 25.0

class Sib:
	var host: ActorHost
	var pos := Vector2.ZERO
	var yaw := 0.0
	var speed := 0.0
	var target := Vector2.ZERO
	var wait := 0.0
	var greet := 0.0
	var greet_cool := 0.0
	var follow := 0.5           # 0..1: how readily it comes to the player
	var skin := {}

var sibs: Array[Sib] = []
var nest := Vector2.ZERO
var ground := Callable()
var player_pos := Callable()         # () -> Vector3
var blocked := Callable()            # (Vector2) -> bool: water or ground too steep
var _rng := RandomNumberGenerator.new()
var _clock := 0.0

## How many siblings a world gets: 2..4 from its seed.
static func count_for(world_seed: int) -> int:
	return MIN_COUNT + int(absi(hash([world_seed, "family"])) % (MAX_COUNT - MIN_COUNT + 1))

## The colour variation: each sibling's skin colours nudged in hue, saturation and value (±6% hue, ±12% sat/val), same genome otherwise.
static func varied_genome(genome: Dictionary, world_seed: int, index: int) -> Dictionary:
	var g: Dictionary = genome.duplicate(true)
	var r := RandomNumberGenerator.new()
	r.seed = hash([world_seed, "sibling", index])
	var dh := r.randf_range(-0.06, 0.06)
	var ds := r.randf_range(-0.12, 0.12)
	var dv := r.randf_range(-0.12, 0.12)
	var skin: Dictionary = g.get("skin", {}).duplicate(true)
	for k in ["cA", "cB", "cC"]:
		if skin.has(k):
			var c := Color(str(skin[k]))
			skin[k] = "#" + Color.from_hsv(fposmod(c.h + dh, 1.0), clampf(c.s + ds, 0.0, 1.0), clampf(c.v + dv, 0.05, 1.0)).to_html(false)
	g["skin"] = skin
	g["name"] = "%s (sibling %d)" % [str(g.get("name", "Creature")), index + 1]
	return g

## Spots near the nest, pure of the scene: `count` points 3.5..HOME_RADIUS m from the nest, at least 2.5 m apart, on free ground.
static func spots(world_seed: int, nest_pos: Vector2, count: int, ok: Callable) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world_seed, "family-spots"])
	var out: Array = []
	var tries := 0
	while out.size() < count and tries < 400:
		tries += 1
		var a := r.randf() * TAU
		var d := r.randf_range(3.5, HOME_RADIUS)
		var p := nest_pos + Vector2(sin(a), cos(a)) * d
		if not ok.call(p):
			continue
		var close := false
		for q in out:
			if (q as Vector2).distance_to(p) < 2.5:
				close = true
		if not close:
			out.append(p)
	return out

func setup(genome: Dictionary, world_seed: int, nest_pos: Vector2, ground_fn: Callable, player_fn: Callable, blocked_fn: Callable) -> void:
	nest = nest_pos
	ground = ground_fn
	player_pos = player_fn
	blocked = blocked_fn
	_rng.seed = hash([world_seed, "family-walk"])
	var n := count_for(world_seed)
	var where := spots(world_seed, nest_pos, n, func(p: Vector2) -> bool: return not blocked.call(p))
	for i in where.size():
		var s := Sib.new()
		var g := varied_genome(genome, world_seed, i)
		s.skin = g.get("skin", {})
		s.host = ActorHost.new()
		s.host.name = "Sibling%d" % (i + 1)
		add_child(s.host)
		s.host.setup(g, 100000 + i, {}, ground)
		s.pos = where[i]
		s.target = where[i]
		s.yaw = _rng.randf() * TAU
		s.follow = _rng.randf_range(0.35, 1.0)
		s.wait = _rng.randf_range(0.5, 4.0)
		sibs.append(s)
		_place(s)

func _place(s: Sib) -> void:
	var y: float = ground.call(s.pos.x, s.pos.y) if ground.is_valid() else 0.0
	s.host.position = Vector3(s.pos.x, y, s.pos.y)

func _pick_target(s: Sib, near_player: bool) -> void:
	for k in 10:
		var a := _rng.randf() * TAU
		var d := _rng.randf_range(2.0, 7.0)
		var base := nest
		if near_player and player_pos.is_valid():
			var pp: Vector3 = player_pos.call()
			base = Vector2(pp.x, pp.z)
			d = _rng.randf_range(KEEP_AWAY, KEEP_AWAY + 3.5)
		var p := base + Vector2(sin(a), cos(a)) * d
		if not near_player and p.distance_to(nest) > HOME_RADIUS:
			p = nest + (p - nest).normalized() * HOME_RADIUS
		if not blocked.call(p):
			s.target = p
			return
	s.target = s.pos

func _process(dt: float) -> void:
	if sibs.is_empty() or not visible:
		return
	_clock += dt
	var pp := Vector3.INF
	if player_pos.is_valid():
		pp = player_pos.call()
	var ppv := Vector2(pp.x, pp.z)
	for s in sibs:
		_step(s, dt, ppv, pp)

func _step(s: Sib, dt: float, ppv: Vector2, pp: Vector3) -> void:
	var have_player := pp.x < 1e8
	var dp := s.pos.distance_to(ppv) if have_player else INF
	s.greet_cool = maxf(s.greet_cool - dt, 0.0)
	if s.greet > 0.0:
		s.greet -= dt
		s.speed = 0.0
		if have_player:
			s.yaw = _turn(s.yaw, atan2(ppv.x - s.pos.x, ppv.y - s.pos.y), dt, 5.0)
	elif have_player and dp < GREET_RANGE and s.greet_cool <= 0.0:
		s.greet = GREET_TIME
		s.greet_cool = GREET_COOLDOWN
	else:
		var want_player := have_player and dp < FOLLOW_RANGE and s.follow > 0.5
		if s.wait > 0.0:
			s.wait -= dt
			s.speed = 0.0
		else:
			var to := s.target - s.pos
			if to.length() < 0.6:
				s.wait = _rng.randf_range(1.5, 6.0)
				_pick_target(s, want_player and dp > KEEP_AWAY + 4.0)
				s.speed = 0.0
			else:
				var goal := atan2(to.x, to.y)
				s.yaw = _turn(s.yaw, goal, dt, 4.0)
				var spd := WALK * (1.5 if want_player and dp > 14.0 else 1.0)
				var step := Vector2(sin(s.yaw), cos(s.yaw)) * spd * dt
				var np := s.pos + step
				if blocked.call(np):
					s.target = s.pos
					s.wait = 1.0
					s.speed = 0.0
				else:
					s.pos = np
					s.speed = spd
		# strayed: drift back toward the nest unless it is with the player
		if not want_player and s.pos.distance_to(nest) > HOME_RADIUS + 3.0 and s.wait <= 0.0:
			s.target = nest + (s.pos - nest).normalized() * (HOME_RADIUS * 0.5)
	_place(s)
	var d3 := (s.host.global_position - pp).length() if have_player else 999.0
	var vel := Vector3(sin(s.yaw), 0.0, cos(s.yaw)) * s.speed
	var smp := {"pos": s.host.position, "yaw": s.yaw, "speed": s.speed, "speed_c": s.speed, "vel": vel}
	var ctx := {"sig": {}, "tick": int(_clock * 10.0), "alpha": 0.0, "beat_phase": 0, "lod": 0 if d3 < 40.0 else (1 if d3 < 80.0 else 2), "mode": "", "attend": false}
	if have_player and (s.greet > 0.0 or dp < GREET_RANGE * 1.4):
		ctx["target"] = {"id": 0, "pos": pp, "radius": 0.6, "height": 1.2, "spheres": []}
	s.host.update(dt, smp, ctx)

static func _turn(cur: float, goal: float, dt: float, rate: float) -> float:
	return cur + clampf(wrapf(goal - cur, -PI, PI), -rate * dt, rate * dt)
