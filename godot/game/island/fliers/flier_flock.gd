extends Node3D
## Ambient fliers (DESIGN A59, first step): visual-only flocks, no C entities and no snapshot field. Everything is a pure function of
## (terrain, world seed, nest, the player position you feed it) stepped at a fixed 60 Hz, so the same inputs replay the same flight.
##   plan()        habitat planner: flocks with a home and perch spots per species, from terrain data + seed only
##   step(dt, p)   the simulation; p = player position (perched fliers flee inside the species radius, flying ones sheer away when it passes close)
##   birds         one Dictionary per bird: state, pos, yaw, pitch, speed, ...
## Flight is flap-glide as the ported flight modes (flight_mode.gd / loco_wing.gd DOWNSTROKE 0.58): bursts of flapping climb and hold
## speed, a glide trades height at 1/LD, the Alariz soars (long glides, slow beat, thermals over the ridges). Landing = approach point,
## final glide, flare (legs down, wings out, speed to walking pace), touchdown on the perch; takeoff = wing-up hop, climb out, wings
## unfold. Terrain: the height ahead (0.6 s, 1.5 s, 3 s) raises the altitude target and the position is clamped above the visual ground.

const Species := preload("res://game/island/fliers/flier_species.gd")
const FlierMesh := preload("res://game/island/fliers/flier_mesh.gd")
const RadialFauna := preload("res://game/island/radial_fauna.gd")

const SIM_DT := 1.0 / 60.0
const G := 9.81
const DOWNSTROKE := 0.58
const CULL := [700.0, 260.0, 260.0, 90.0]     # beyond this from the camera a species is not drawn
const NIGHT := 0.65                            # moon_k above this: the day fliers roost
const RING := [28.0, 7.0, 9.0, 0.0]            # radius of each bird's ring round the moving flock centre
const PATH_R := [150.0, 60.0, 75.0, 6.0]       # the flock's ellipse round its home
const PERCH_PITCH := [0.2, 0.15, 0.45, 0.95]
const GLIDE_LD := [14.0, 10.0, 7.0, 4.0]

enum S { PERCH, TAKEOFF, FLY, APPROACH, FINAL }

var flocks: Array = []
var birds: Array = []
var spots: Array = []           # [{pos: Vector3, species, taken: bird index or -1}]
var time := 0.0
var night_fn: Callable          # 0 day .. 1 night, from the sky (island.gd passes the DayNight light)
var night := 0.0                # 0 day .. 1 night; tests set it
var stats := {"takeoffs": 0, "landings": 0, "flees": 0, "min_clear": 1e9, "aborts": 0}

var _ground: Callable
var _cam: Callable
var _player: Callable
var _acc := 0.0
var _mm: Array = []             # MultiMesh per species
var _player_prev := Vector3.INF
var _player_speed := 0.0
var _render := false


# ------------------------------------------------------------------ planning (pure: terrain data + seed)

static func _rng_for(world_seed: int, tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([world_seed, "fliers", tag])
	return r


static func _near_water(d, p: Vector2, r: float) -> bool:
	for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2(0.71, 0.71), Vector2(-0.71, 0.71), Vector2(0.71, -0.71), Vector2(-0.71, -0.71)]:
		var q: Vector2 = p + dir * r
		if absf(q.x) >= d.half or absf(q.y) >= d.half:
			continue
		var k: int = d.cell_index(q.x, q.y)
		if d.is_sea(k) or d.is_pond(k) or d.is_river(k):
			return true
	return false


## Can a bird of this species stand at p? `hmax` = a high ground level of the island (the Alariz perch on ridges).
static func _habitat(d, species: int, p: Vector2, hmax: float) -> bool:
	if not RadialFauna._free_ground(d, p):
		return false
	var h: float = d.visual_ground(p.x, p.y)
	var ny: float = d.normal(p.x, p.y).y
	match species:
		Species.ALARIZ:
			return ny > 0.55 and h > 0.5 * hmax
		Species.PICO:
			return ny > 0.9 and h > 0.15 and h < 25.0 and _near_water(d, p, 80.0)
		Species.ZANCUILLA:
			return ny > 0.9 and h > 0.15 and _near_water(d, p, 25.0)
		_:
			return ny > 0.85 and h > 0.4 and h < 40.0 and not _near_water(d, p, 4.0)


static func plan(d, world_seed: int, nest: Vector2) -> Dictionary:
	var out := {"flocks": [], "log": []}
	var rs := _rng_for(world_seed, "hmax")
	var hmax := 0.0
	for i in 400:
		var q := Vector2(rs.randf_range(-d.half + 20.0, d.half - 20.0), rs.randf_range(-d.half + 20.0, d.half - 20.0))
		hmax = maxf(hmax, d.visual_ground(q.x, q.y))
	# where to look for a home, by distance from the nest (the island is 3.6 km across; flat low ground is a few percent of it)
	var near_nest := [Vector2(60.0, 1500.0), Vector2(40.0, 450.0), Vector2(40.0, 500.0), Vector2(30.0, 300.0)]
	var radii := [40.0, 28.0, 24.0, 12.0]
	var spacings := [7.0, 1.1, 1.6, 0.9]
	for sp in Species.COUNT:
		var sd: Dictionary = Species.get_data(sp)
		var rng := _rng_for(world_seed, str(sp))
		for f in int(sd.flocks):
			var home = null
			for t in 4000:
				var ang := rng.randf() * TAU
				var r: float = lerpf(near_nest[sp].x, near_nest[sp].y, rng.randf() * rng.randf())      # biased towards the nest, the player sees them
				var q := nest + Vector2(sin(ang), cos(ang)) * r
				if absf(q.x) > d.half - 30.0 or absf(q.y) > d.half - 30.0:
					continue
				if _habitat(d, sp, q, hmax):
					home = q
					break
			if home == null:
				out.log.append("fliers: no home for %s flock %d" % [sd.id, f])
				continue
			var n: int = rng.randi_range(int(sd.flock.x), int(sd.flock.y))
			var pts: Array = [home]
			for t in 300:
				if pts.size() >= n + 5:
					break
				var a := rng.randf() * TAU
				var q: Vector2 = home + Vector2(sin(a), cos(a)) * sqrt(rng.randf()) * radii[sp]
				if q.distance_to(nest) < 12.0 or not _habitat(d, sp, q, hmax):
					continue
				var ok := true
				for o: Vector2 in pts:
					if o.distance_to(q) < spacings[sp]:
						ok = false
						break
				if ok:
					pts.append(q)
			out.flocks.append({"species": sp, "home": home, "n": mini(n, pts.size()), "spots": pts, "seed": rng.randi(), "start_flying": f % 2 == 0, "rot": rng.randf() * TAU})
	return out


# ------------------------------------------------------------------ setup

## `render`: build the MultiMeshes (false for the unit test, which only steps the simulation).
func setup(d, world_seed: int, nest: Vector2, ground: Callable, camera_fn: Callable = Callable(), player_fn: Callable = Callable(), plan_in = null, render: bool = true) -> void:
	_ground = ground
	_cam = camera_fn
	_player = player_fn
	_render = render
	var pl: Dictionary = plan(d, world_seed, nest) if plan_in == null else plan_in
	for line in pl.log:
		print(line)
	for f in pl.flocks:
		var sp: int = f.species
		var sd: Dictionary = Species.get_data(sp)
		var fl := {"species": sp, "home": f.home, "members": [], "spots": [], "rng": RandomNumberGenerator.new(), "state": "fly" if f.start_flying else "perch",
			"timer": 0.0, "phase": 0.0, "w": 0.0, "rx": 0.0, "rz": 0.0, "tp": 0.0, "alt": 0.0, "rot": f.rot, "roost": 0}
		fl.rng.seed = int(f.seed)
		var r: RandomNumberGenerator = fl.rng
		for p: Vector2 in f.spots:
			spots.append({"pos": Vector3(p.x, _ground.call(p.x, p.y), p.y), "species": sp, "taken": -1})
			fl.spots.append(spots.size() - 1)
		# the flock's lazy ellipse around its home: speed along the path is about 0.55 of cruise
		var rad: float = PATH_R[sp] * r.randf_range(0.8, 1.2)
		fl.rx = rad
		fl.rz = rad * r.randf_range(0.6, 0.9)
		fl.w = 0.55 * float(sd.cruise) / rad * (1.0 if r.randf() < 0.5 else -1.0)
		fl.phase = r.randf() * TAU
		fl.alt = lerpf(sd.alt.x, sd.alt.y, r.randf())
		fl.timer = r.randf_range(sd.fly_wait.x, sd.fly_wait.y) if f.start_flying else r.randf_range(sd.perch_wait.x * 0.3, sd.perch_wait.y)
		var fi := flocks.size()
		for i in f.n:
			var b := _new_bird(fl, fi, i)
			b.gi = birds.size()
			fl.members.append(b.gi)
			birds.append(b)
		flocks.append(fl)
	for b in birds:
		var fl: Dictionary = flocks[b.flock]
		if fl.state == "perch":
			_take_spot(b, fl.spots[b.i % fl.spots.size()])
			_to_perch(b)
		else:
			var tp := _flock_target(fl, b)
			b.pos = Vector3(tp.x, maxf(_ground.call(tp.x, tp.z), 0.0) + tp.y, tp.z)
			b.yaw = fl.rot + b.i
			b.speed = float(Species.get_data(b.species).cruise)
			b.state = S.FLY
			b.legs = 0.0
			b.fold = 0.0
	if _render:
		_build_nodes()


func _new_bird(fl: Dictionary, _fi: int, i: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash([fl.rng.seed, i, "bird"])
	return {"species": fl.species, "flock": _fi, "i": i, "gi": 0, "rng": r, "state": S.PERCH, "pos": Vector3.ZERO, "yaw": r.randf() * TAU, "pitch": 0.0,
		"roll": 0.0, "speed": 0.0, "vy": 0.0, "yaw_rate": 0.0, "phase": r.randf() * TAU, "amp": 0.0, "fold": 1.0, "legs": 1.0, "flap_t": 0.0,
		"flapping": false, "t": 0.0, "delay": 0.0, "spot": -1, "off_a": TAU * float(i) / 6.0 + r.randf() * 0.5, "off_r": r.randf_range(0.6, 1.0),
		"flee_t": 0.0, "flee_dir": Vector2.ZERO, "app": Vector3.ZERO, "hover_t": 0.0, "goal": Vector3.ZERO, "timeout": 0.0, "hold": false}


func _build_nodes() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://game/shaders/flier.gdshader")
	_mm.resize(Species.COUNT)
	for sp in Species.COUNT:
		var n := 0
		for b in birds:
			if b.species == sp:
				n += 1
		if n == 0:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true            # the shader's COLOR is vertex colour x instance colour: keep the instance one white
		mm.use_custom_data = true
		mm.mesh = FlierMesh.mesh_for(sp)
		mm.instance_count = n
		mm.custom_aabb = AABB(Vector3(-3000, -200, -3000), Vector3(6000, 1500, 6000))
		var mi := MultiMeshInstance3D.new()
		mi.name = "Fliers_" + str(Species.get_data(sp).id)
		mi.multimesh = mm
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_mm[sp] = mm
	_draw()


# ------------------------------------------------------------------ frame

func _process(delta: float) -> void:
	var p := Vector3.INF
	if _player.is_valid():
		p = _player.call()
	if night_fn.is_valid():
		night = night_fn.call()
	_acc += minf(delta, 0.1)
	var n := 0
	while _acc >= SIM_DT and n < 6:
		step(SIM_DT, p)
		_acc -= SIM_DT
		n += 1
	if _render:
		_draw()


func step(dt: float, player: Vector3 = Vector3.INF) -> void:
	time += dt
	if player != Vector3.INF:
		if _player_prev != Vector3.INF:
			_player_speed = lerpf(_player_speed, player.distance_to(_player_prev) / dt, minf(dt * 3.0, 1.0))
		_player_prev = player
	for fl in flocks:
		_flock_tick(fl, dt, player)
	for b in birds:
		_bird_tick(b, dt, player)


func _flock_tick(fl: Dictionary, dt: float, player: Vector3) -> void:
	var sd: Dictionary = Species.get_data(fl.species)
	var rng: RandomNumberGenerator = fl.rng
	fl.tp += dt
	fl.timer -= dt
	var dark: bool = night > NIGHT and fl.species != Species.ZANCUILLA
	if fl.state == "fly":
		if dark:
			fl.timer = 0.0
		if fl.timer <= 0.0:
			# roost: a spot far enough from the player; members take the free spots nearest to it
			var cands: Array = []
			for si in fl.spots:
				var s: Dictionary = spots[si]
				if s.taken < 0 and (player == Vector3.INF or Vector2(s.pos.x - player.x, s.pos.z - player.z).length() > float(sd.flee) * 1.6):
					cands.append(si)
			if cands.is_empty():
				fl.timer = rng.randf_range(10.0, 30.0)
			else:
				fl.state = "land"
				fl.roost = cands[rng.randi() % cands.size()]
				for bi in fl.members:
					_pick_spot(birds[bi], fl)
	elif fl.state == "perch":
		if fl.timer <= 0.0:
			if dark:
				fl.timer = 20.0
			else:
				_launch_flock(fl, Vector2.ZERO)
	elif fl.state == "land":
		var all_down := true
		for bi in fl.members:
			if birds[bi].state != S.PERCH:
				all_down = false
		if all_down:
			fl.state = "perch"
			fl.timer = rng.randf_range(sd.perch_wait.x, sd.perch_wait.y)


## The whole flock leaves its perches (staggered); birds still on approach break off and fly on.
func _launch_flock(fl: Dictionary, away: Vector2) -> void:
	var sd: Dictionary = Species.get_data(fl.species)
	var rng: RandomNumberGenerator = fl.rng
	fl.state = "fly"
	fl.timer = rng.randf_range(sd.fly_wait.x, sd.fly_wait.y)
	if away != Vector2.ZERO:
		fl.timer = maxf(fl.timer * 0.6, 18.0)
	var t0 := 0.0
	for bi in fl.members:
		var b: Dictionary = birds[bi]
		if b.state == S.PERCH:
			if not b.hold:
				b.hold = true
				b.delay = t0
				t0 += rng.randf_range(0.04, 0.35)
				b.flee_dir = away
				b.flee_t = 3.5 if away != Vector2.ZERO else 0.0
		elif b.state == S.APPROACH or b.state == S.FINAL:
			_free_spot(b)
			b.state = S.TAKEOFF       # break off the approach: climb out again
			b.t = 0.0
			b.flapping = true
			b.flee_dir = away
			b.flee_t = 3.5 if away != Vector2.ZERO else 0.0


func _free_spot(b: Dictionary) -> void:
	if b.spot >= 0:
		if spots[b.spot].taken == b.gi:
			spots[b.spot].taken = -1
		b.spot = -1


func _take_spot(b: Dictionary, si: int) -> void:
	_free_spot(b)
	b.spot = si
	spots[si].taken = b.gi


func _pick_spot(b: Dictionary, fl: Dictionary) -> void:
	if b.state == S.PERCH:
		return
	# the free spot nearest the roost, with a little noise, so a flock lands as a group
	var rpos: Vector3 = spots[fl.roost].pos
	var best := -1
	var best_d := 1e9
	for si in fl.spots:
		var s: Dictionary = spots[si]
		if s.taken >= 0 and s.taken != b.gi:
			continue
		var dd: float = Vector2(s.pos.x - rpos.x, s.pos.z - rpos.z).length() + b.rng.randf() * 3.0
		if dd < best_d:
			best_d = dd
			best = si
	if best < 0:
		return
	_take_spot(b, best)
	b.state = S.APPROACH
	b.timeout = 0.0
	b.flee_t = 0.0
	_plan_approach(b)


func _plan_approach(b: Dictionary) -> void:
	var sd: Dictionary = Species.get_data(b.species)
	var s: Vector3 = spots[b.spot].pos
	var from := Vector2(b.pos.x - s.x, b.pos.z - s.z)
	var dapp := clampf(float(sd.cruise) * 3.5, 6.0, 55.0)
	var dir := from.normalized() if from.length() > 1.0 else -Vector2(sin(b.yaw), cos(b.yaw))
	var ap := Vector2(s.x, s.z) + dir * dapp
	b.app = Vector3(ap.x, 0.0, ap.y)


# ------------------------------------------------------------------ one bird

## The flock's moving target for this bird: x, z in the world and y = altitude above the ground wanted.
func _flock_target(fl: Dictionary, b: Dictionary) -> Vector3:
	var sd: Dictionary = Species.get_data(b.species)
	var ph: float = fl.phase + fl.w * fl.tp
	var c := Vector2(fl.home.x + sin(ph) * fl.rx, fl.home.y + cos(ph) * fl.rz)
	var ring: float = RING[b.species] * b.off_r
	var a: float = b.off_a
	if ring > 0.0:
		a += fl.tp * float(sd.cruise) * 0.5 / maxf(ring, 1.0) * (1.0 if fl.w > 0.0 else -1.0)
	var p := c + Vector2(sin(a), cos(a)) * ring
	var alt: float = fl.alt + 0.25 * (sd.alt.y - sd.alt.x) * sin(fl.tp * 0.13 + b.off_a)
	return Vector3(p.x, alt, p.y)


func _ground_ahead(b: Dictionary, base: float, max_dist: float = 1e9) -> float:
	var f := Vector2(sin(b.yaw), cos(b.yaw))
	var best: float = _ground.call(b.pos.x, b.pos.z)
	var v: float = maxf(b.speed, 2.0)
	for k in [0.6, 1.5, 3.0]:
		var q: Vector2 = Vector2(b.pos.x, b.pos.z) + f * minf(v * float(k), max_dist)
		best = maxf(best, _ground.call(q.x, q.y))
	return maxf(best, 0.0) + base


func _bird_tick(b: Dictionary, dt: float, player: Vector3) -> void:
	var sp: int = b.species
	var sd: Dictionary = Species.get_data(sp)
	var fl: Dictionary = flocks[b.flock]
	b.t += dt
	match b.state:
		S.PERCH:
			_perch_tick(b, fl, sd, dt, player)
		S.TAKEOFF:
			_takeoff_tick(b, fl, sd, dt)
		S.FLY:
			_fly_tick(b, fl, sd, dt, player)
		_:
			_land_tick(b, fl, sd, dt)
	# wings: the phase runs while beating; the amplitude eases between a beat and a held glide
	var want_amp := 0.0
	if b.state != S.PERCH and b.flapping:
		want_amp = 1.0 if sp != Species.ALASUCENA else 0.55
	b.amp = lerpf(b.amp, want_amp, minf(dt * 9.0, 1.0))
	if b.amp > 0.05:
		var hz: float = sd.beat * (lerpf(0.7, 1.0, b.amp) if sp != Species.ALARIZ else 1.0)
		var cyc := fposmod(b.phase, TAU) / TAU
		# downstroke takes 58 % of the beat, the upstroke the rest (a quicker recovery)
		var k := 0.5 / DOWNSTROKE if cyc < DOWNSTROKE else 0.5 / (1.0 - DOWNSTROKE)
		b.phase += TAU * hz * k * dt
	if b.state == S.FLY:
		stats.min_clear = minf(stats.min_clear, b.pos.y - maxf(_ground.call(b.pos.x, b.pos.z), 0.0))


func _perch_tick(b: Dictionary, fl: Dictionary, sd: Dictionary, dt: float, player: Vector3) -> void:
	var s: Vector3 = spots[b.spot].pos
	var foot := float(sd.foot) * cos(float(PERCH_PITCH[b.species]))
	b.pos = Vector3(s.x, s.y + foot, s.z)
	b.speed = 0.0
	b.vy = 0.0
	b.flapping = false
	b.roll = lerpf(b.roll, 0.0, minf(dt * 6.0, 1.0))
	b.pitch = lerpf(b.pitch, PERCH_PITCH[b.species], minf(dt * 6.0, 1.0))
	b.legs = move_toward(b.legs, 1.0, dt * 5.0)
	if b.hold:
		# launching: wait the stagger, unfold and go
		b.delay -= dt
		b.fold = move_toward(b.fold, 0.0, dt * 6.0)
		if b.delay <= 0.0:
			_begin_takeoff(b, fl, sd)
		return
	b.fold = move_toward(b.fold, 1.0, dt * 3.0)
	b.yaw += sin(b.t * 0.7 + b.off_a * 3.0) * 0.12 * dt       # a look about
	if player != Vector3.INF and fl.state != "fly":
		var thr: float = float(sd.flee) * (1.0 + clampf(_player_speed / 10.0, 0.0, 1.0) * 0.6)
		var dp := Vector3(player.x - b.pos.x, (player.y - b.pos.y) * 0.5, player.z - b.pos.z).length()
		if dp < thr:
			var away := Vector2(b.pos.x - player.x, b.pos.z - player.z)
			away = away.normalized() if away.length() > 0.1 else Vector2(sin(b.yaw), cos(b.yaw))
			stats.flees += 1
			_launch_flock(fl, away)


func _begin_takeoff(b: Dictionary, fl: Dictionary, sd: Dictionary) -> void:
	_free_spot(b)
	b.state = S.TAKEOFF
	b.t = 0.0
	b.flapping = true
	b.hold = false
	var dir := Vector2(sin(b.yaw), cos(b.yaw))
	if b.flee_dir != Vector2.ZERO:
		dir = b.flee_dir
	else:
		var tp := _flock_target(fl, b)
		var to := Vector2(tp.x - b.pos.x, tp.z - b.pos.z)
		if to.length() > 1.0:
			dir = to.normalized()
	b.yaw = atan2(dir.x, dir.y)
	b.speed = maxf(0.5, float(sd.stall) * 0.25)
	b.flap_t = 0.0
	stats.takeoffs += 1


func _takeoff_tick(b: Dictionary, _fl: Dictionary, sd: Dictionary, dt: float) -> void:
	# a wing-up hop, then the climb out: speed builds, the pitch is the species' steep one
	var hover: bool = Species.hover_capable(b.species)
	var v_to: float = float(sd.cruise) * (0.6 if hover else 0.9)
	b.speed = move_toward(b.speed, v_to, dt * (3.0 if hover else 4.5 + float(sd.cruise) * 0.25))
	b.flapping = true
	b.fold = move_toward(b.fold, 0.0, dt * 6.0)
	b.legs = move_toward(b.legs, 0.0, dt * 1.6)
	var want_pitch := 0.75 if hover else (0.32 if b.species == Species.ALARIZ else 0.5)
	var ramp := clampf(b.t / 0.5, 0.0, 1.0)         # the first half second is the hop: the climb starts as the wings bite
	b.pitch = lerpf(b.pitch, want_pitch * ramp, minf(dt * 4.0, 1.0))
	b.roll = lerpf(b.roll, 0.0, minf(dt * 4.0, 1.0))
	var f := Vector2(sin(b.yaw), cos(b.yaw))
	b.pos.x += f.x * b.speed * dt * cos(b.pitch)
	b.pos.z += f.y * b.speed * dt * cos(b.pitch)
	b.vy = b.speed * sin(b.pitch) * (0.35 + 0.65 * ramp)
	b.pos.y += b.vy * dt
	_clamp_ground(b, float(sd.foot))
	if b.flee_t > 0.0:
		b.flee_t -= dt
	var g: float = maxf(_ground.call(b.pos.x, b.pos.z), 0.0)
	if b.t > 0.9 and b.pos.y - g > float(sd.clear) * 1.2 and b.speed > float(sd.stall) * 0.8:
		b.state = S.FLY
		b.t = 0.0
		b.flapping = true
		b.flap_t = float(sd.burst_len)


func _clamp_ground(b: Dictionary, min_clear: float) -> void:
	var g: float = maxf(_ground.call(b.pos.x, b.pos.z), 0.0)
	if b.pos.y < g + min_clear:
		b.pos.y = g + min_clear
		if b.vy < 0.0:
			b.vy = 0.0


func _fly_tick(b: Dictionary, fl: Dictionary, sd: Dictionary, dt: float, player: Vector3) -> void:
	var sp: int = b.species
	b.fold = move_toward(b.fold, 0.0, dt * 5.0)
	b.legs = move_toward(b.legs, 0.0, dt * 2.0)
	if sp == Species.ALASUCENA:
		_flit_tick(b, fl, sd, dt)
		return
	var tgt := _flock_target(fl, b)
	var to := Vector2(tgt.x - b.pos.x, tgt.z - b.pos.z)
	var dist := to.length()
	var want_yaw := atan2(to.x, to.y)
	if b.flee_t > 0.0:
		b.flee_t -= dt
		want_yaw = atan2(b.flee_dir.x, b.flee_dir.y)
	var alt_want: float = maxf(maxf(_ground.call(b.pos.x, b.pos.z), 0.0) + tgt.y, _ground_ahead(b, float(sd.clear)))
	# sheer away when the player passes close
	if player != Vector3.INF:
		var rel := Vector2(b.pos.x - player.x, b.pos.z - player.z)
		var r: float = float(sd.flee) * 0.3
		if rel.length() < r and absf(b.pos.y - player.y) < r:
			want_yaw = atan2(rel.x, rel.y)
			alt_want = maxf(alt_want, player.y + r * 0.6)
	var v_want: float = clampf(float(sd.cruise) * (0.9 + clampf((dist - 8.0) / 60.0, 0.0, 0.5)), float(sd.stall) * 1.1, float(sd.vmax))
	b.speed = move_toward(b.speed, v_want, dt * 2.5)
	_steer(b, sd, want_yaw, dt, 1.0)
	# flap-glide: a burst, then a glide; a burst is forced when low or slow
	var alt: float = b.pos.y
	var lift := 0.0
	if sp == Species.ALARIZ:
		lift = 1.5 if Vector2(b.pos.x - fl.home.x, b.pos.z - fl.home.y).length() < fl.rx * 1.1 else 0.3     # thermals over the ridges
	b.flap_t -= dt
	if b.flap_t <= 0.0:
		b.flapping = not b.flapping
		b.flap_t = float(sd.burst_len if b.flapping else sd.glide_len) * b.rng.randf_range(0.7, 1.3)
	if alt < alt_want - (6.0 if sp == Species.ALARIZ else 1.2) or b.speed < float(sd.stall) * 1.15:
		if not b.flapping:
			b.flapping = true
			b.flap_t = float(sd.burst_len) * 0.7
	# vertical: flapping climbs at the species' rate, a glide only sinks at 1/LD (less the thermal)
	var vy_want: float = clampf((alt_want - alt) * 0.6, -b.speed * 0.35, b.speed * float(sd.climb))
	if not b.flapping:
		vy_want = minf(vy_want, -b.speed / GLIDE_LD[sp] + lift)
	b.vy = move_toward(b.vy, vy_want, dt * 3.5)
	b.pitch = lerpf(b.pitch, asin(clampf(b.vy / maxf(b.speed, 1.0), -0.7, 0.7)), minf(dt * 5.0, 1.0))
	_advance(b, dt)
	_clamp_ground(b, float(sd.clear) * 0.5)


## The alasucena: short flits between hover points, hanging on the beat (only this species hovers).
func _flit_tick(b: Dictionary, fl: Dictionary, sd: Dictionary, dt: float) -> void:
	b.flapping = true
	var r: RandomNumberGenerator = b.rng
	var arrived: bool = b.goal != Vector3.ZERO and Vector2(b.pos.x - b.goal.x, b.pos.z - b.goal.z).length() < 0.4
	if arrived and b.hover_t <= 0.0:
		b.hover_t = r.randf_range(0.8, 2.6)
		b.goal = Vector3.ZERO
	if b.hover_t > 0.0:
		b.hover_t -= dt
		b.speed = move_toward(b.speed, 0.0, dt * 6.0)
	elif b.goal == Vector3.ZERO:
		var a := r.randf() * TAU
		var rr := r.randf_range(2.0, 10.0)
		b.goal = Vector3(fl.home.x + sin(a) * rr, r.randf_range(float(sd.alt.x), float(sd.alt.y)), fl.home.y + cos(a) * rr)
	var gy: float = b.goal.y if b.goal != Vector3.ZERO else 1.2
	if b.flee_t > 0.0:
		b.flee_t -= dt
		_steer(b, sd, atan2(b.flee_dir.x, b.flee_dir.y), dt, 1.0)
		b.speed = move_toward(b.speed, float(sd.vmax), dt * 8.0)
	elif b.goal != Vector3.ZERO:
		var to := Vector2(b.goal.x - b.pos.x, b.goal.z - b.pos.z)
		b.speed = move_toward(b.speed, clampf(to.length() * 1.5, 0.0, float(sd.cruise)), dt * 7.0)
		_steer(b, sd, atan2(to.x, to.y), dt, 1.0)
	var alt_want: float = maxf(maxf(_ground.call(b.pos.x, b.pos.z), 0.0) + gy, _ground_ahead(b, float(sd.clear)))
	b.vy = move_toward(b.vy, clampf((alt_want - b.pos.y) * 2.0, -2.0, 2.5), dt * 8.0)
	b.pitch = lerpf(b.pitch, lerpf(0.9, -0.1, clampf(b.speed / 3.0, 0.0, 1.0)), minf(dt * 6.0, 1.0))   # upright when still, nose down in a flit
	_advance(b, dt)
	_clamp_ground(b, float(sd.clear))


func _steer(b: Dictionary, sd: Dictionary, want_yaw: float, dt: float, gain: float) -> void:
	var diff := wrapf(want_yaw - b.yaw, -PI, PI)
	# the turn rate a bank allows at this speed: w = g tan(bank) / v
	var wmax: float = minf(G * tan(float(sd.bank)) / maxf(b.speed, 1.5), float(sd.turn) * 3.0) * gain
	if Species.hover_capable(b.species):
		wmax = float(sd.turn) * 3.0 * gain          # a hoverer pivots on the spot
	var w_want := clampf(diff * 2.0, -wmax, wmax)
	b.yaw_rate = move_toward(b.yaw_rate, w_want, dt * wmax * 2.5)
	b.yaw += b.yaw_rate * dt
	var bank_want := -atan(b.yaw_rate * maxf(b.speed, 1.0) / G)       # yaw up = a left turn: the left (+X) wing goes down
	b.roll = lerpf(b.roll, clampf(bank_want, -float(sd.bank), float(sd.bank)), minf(dt * 6.0, 1.0))


func _land_tick(b: Dictionary, fl: Dictionary, sd: Dictionary, dt: float) -> void:
	var sp: int = b.species
	var s: Vector3 = spots[b.spot].pos
	var cruise: float = sd.cruise
	b.timeout += dt
	b.fold = move_toward(b.fold, 0.0, dt * 5.0)
	if b.timeout > 60.0:
		# could not make it: give the spot back and fly on; the flock roosts again later
		stats.aborts += 1
		_free_spot(b)
		b.state = S.TAKEOFF
		b.t = 0.0
		b.flapping = true
		fl.state = "fly"
		fl.timer = 8.0
		return
	if b.state == S.APPROACH:
		var to := Vector2(b.app.x - b.pos.x, b.app.z - b.pos.z)
		var alt_want: float = maxf(maxf(_ground.call(b.pos.x, b.pos.z), 0.0) + float(sd.alt.x) * 0.6, _ground_ahead(b, float(sd.clear)))
		alt_want = maxf(alt_want, s.y + 2.0)
		b.speed = move_toward(b.speed, maxf(cruise * 0.85, float(sd.stall) * 1.1), dt * 2.5)
		_steer(b, sd, atan2(to.x, to.y), dt, 1.0)
		b.vy = move_toward(b.vy, clampf((alt_want - b.pos.y) * 0.5, -b.speed * 0.3, b.speed * float(sd.climb)), dt * 3.5)
		b.flap_t -= dt
		if b.flap_t <= 0.0:
			b.flapping = not b.flapping
			b.flap_t = float(sd.burst_len if b.flapping else sd.glide_len) * b.rng.randf_range(0.7, 1.3)
		if b.speed < float(sd.stall) * 1.15 or b.vy > 0.2:
			b.flapping = true
		b.pitch = lerpf(b.pitch, asin(clampf(b.vy / maxf(b.speed, 1.0), -0.7, 0.7)), minf(dt * 5.0, 1.0))
		_advance(b, dt)
		_clamp_ground(b, float(sd.clear) * 0.5)
		if to.length() < maxf(4.0, cruise * 0.8):
			b.state = S.FINAL
		return
	# FINAL: straight glide to the perch, speed bleeds off, flare near the end
	var to_s := Vector2(s.x - b.pos.x, s.z - b.pos.z)
	var d := to_s.length()
	var foot: float = float(sd.foot) * cos(float(PERCH_PITCH[sp]))
	var hover: bool = Species.hover_capable(sp)
	var flare_d: float = 1.2 if hover else clampf(cruise * 0.45, 2.0, 7.0)
	var above := foot + d * (0.12 if sp == Species.ALARIZ else 0.16)        # the glide path: height over the perch
	var ahead := _ground_ahead(b, 0.6 * clampf(d / 6.0, 0.0, 1.0), maxf(d - 1.5, 0.0))     # the terrain up to the perch only
	var target_y: float = maxf(s.y + above, minf(ahead, s.y + above + 8.0))
	var v_want: float = clampf(d * 1.4 + 0.15, 0.15, cruise * 0.85) if hover else clampf(d * 0.55 + 0.9, 0.9, cruise * 0.85)
	b.speed = move_toward(b.speed, v_want, dt * (7.0 if hover else 3.0))
	_steer(b, sd, atan2(to_s.x, to_s.y), dt, 2.0 if d < 8.0 else 1.2)
	b.vy = move_toward(b.vy, clampf((target_y - b.pos.y) * 1.5, -b.speed * 0.45, b.speed * 0.5), dt * 4.0)
	var flaring: bool = d < flare_d + 1.0
	if flaring or hover or b.speed < float(sd.stall) * 1.1:
		b.flapping = true
	else:
		b.flapping = fposmod(b.t * 3.0, 2.0) < 1.0
	if flaring:
		b.legs = move_toward(b.legs, 1.0, dt * 6.0)
		b.pitch = lerpf(b.pitch, 0.95 if hover else 0.55, minf(dt * 6.0, 1.0))
	else:
		b.legs = move_toward(b.legs, 0.35 if d < flare_d * 3.0 else 0.0, dt * 2.0)
		b.pitch = lerpf(b.pitch, asin(clampf(b.vy / maxf(b.speed, 1.0), -0.6, 0.6)), minf(dt * 5.0, 1.0))
	var f := Vector2(sin(b.yaw), cos(b.yaw))
	var step := minf(b.speed * dt, d)                    # never overshoot the perch
	b.pos.x += f.x * step
	b.pos.z += f.y * step
	b.pos.y += b.vy * dt
	var gmin: float = maxf(_ground.call(b.pos.x, b.pos.z), 0.0) + foot
	if b.pos.y < gmin:
		b.pos.y = gmin
		if b.vy < 0.0:
			b.vy = 0.0
	# touchdown: on the spot at a walking pace with the feet at the perch
	var dy: float = b.pos.y - (s.y + foot)
	if (d < 0.35 and dy < 0.6) or (d < 1.0 and b.speed < 1.0 and dy < 0.25):
		_to_perch(b)
		stats.landings += 1
	elif d < 2.5 and b.speed < 0.9 and dy < 0.5:
		b.pos = b.pos.move_toward(Vector3(s.x, s.y + foot, s.z), dt * 1.2)      # a hoverer settling the last bit


func _advance(b: Dictionary, dt: float) -> void:
	var f := Vector2(sin(b.yaw), cos(b.yaw))
	b.pos.x += f.x * b.speed * dt
	b.pos.z += f.y * b.speed * dt
	b.pos.y += b.vy * dt


func _to_perch(b: Dictionary) -> void:
	var s: Vector3 = spots[b.spot].pos
	b.state = S.PERCH
	b.pos = Vector3(s.x, s.y + float(Species.get_data(b.species).foot) * cos(float(PERCH_PITCH[b.species])), s.z)
	b.speed = 0.0
	b.vy = 0.0
	b.flapping = false
	b.hold = false
	b.t = 0.0
	b.yaw_rate = 0.0
	b.delay = 0.0
	b.flee_dir = Vector2.ZERO
	b.flee_t = 0.0


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var cam := Vector3.INF
	if _cam.is_valid():
		cam = _cam.call()
	var next := [0, 0, 0, 0]
	for b in birds:
		var sp: int = b.species
		var mm: MultiMesh = _mm[sp]
		if mm == null:
			continue
		var i: int = next[sp]
		next[sp] += 1
		if cam != Vector3.INF and b.pos.distance_to(cam) > CULL[sp]:
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), b.pos))
			continue
		var basis := Basis(Vector3.UP, b.yaw) * Basis(Vector3.RIGHT, -b.pitch) * Basis(Vector3.BACK, b.roll)
		mm.set_instance_transform(i, Transform3D(basis, b.pos))
		mm.set_instance_custom_data(i, Color(b.phase, b.amp, b.fold, b.legs))
		mm.set_instance_color(i, Color.WHITE)
