extends Node3D
# The island scene: sky/environment, sun, terrain chunks, water, grass, the 10 Hz stage world,
# creatures, chase camera and controls. Built in code from Game.data (set by the boot flow).

const Look := preload("res://game/island/look.gd")
const EnvironmentFactory := preload("res://game/island/environment.gd")
const TerrainChunks := preload("res://game/island/terrain_chunks.gd")
const Water := preload("res://game/island/water.gd")
const Rivers := preload("res://game/island/rivers.gd")
const Clouds := preload("res://game/island/clouds.gd")
const Grass := preload("res://game/island/grass.gd")
const StageWorld := preload("res://game/stage/stage_world.gd")
const CaveSite := preload("res://game/island/cave_site.gd")
const DayNight := preload("res://game/island/day_night.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const PlayerInput := preload("res://game/player/player_input.gd")
const Pointer := preload("res://game/player/pointer.gd")
const Gesture := preload("res://game/player/pointer_gesture.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const FlightMode := preload("res://game/player/flight_mode.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")
const StageUI := preload("res://game/stage/stage_ui.gd")
const Scenario := preload("res://devtools/scenario.gd")
const StrategicIcons := preload("res://game/island/strategic_icons.gd")
const GroundMarks := preload("res://game/island/ground_marks.gd")

const FAR_GRASS_Z := 0.6          # zoom above which grass, shadows and models are switched off
const MODEL_OFF_Z := 0.85
const DEN_SEEN := 60.0
const ActionFeed := preload("res://actions/action_feed.gd")
const PlantGaze := preload("res://game/island/plant_gaze.gd")

var terrain_chunks: Node3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var day_night                  # DayNight: sun, ambient and exposure follow the C clock
var cave_site                  # CaveSite: the hidden chamber (null/off when the world has none)
var _hidden := {}              # entity id -> true while a nocturnal creature sleeps (draw nothing)
var water: Node3D
var rivers: Node3D
var props := preload("res://game/island/island_props.gd").new()
var grass: MultiMeshInstance3D
var camera: Camera3D
var debug_camera: Camera3D       # alias of camera (tests and evidence move it directly)
var stage: Node
var player_input
var chase
var stage_ui
var ground_marks               # GroundMarks: the white circle where you click, the rings under creatures
var _had_dest := false
var _hover_id := -1            # the creature under the pointer (7.16): its ring shows after 0.25 s
var _hover_t := 0.0
var _hover_poll := 0.0
var _hover_mouse := Vector2(-1, -1)
var hosts := {}                  # entity id -> ActorHost
var chase_enabled := true
var player_pos := Vector3.INF
var flight                         # FlightMode: the dev-flag flight test (null before the stage is built)
var last_click := Vector2.ZERO     # screen position of the last click that picked a creature (the radial opens there)
var occluders_enabled := true
var icons: CanvasLayer
var pois_fn: Callable            # sites hook for the strategic map (see strategic_icons.gd; D2 registry plugs in here)
var _mouse_held := false
var _follow_clock := 0.0       # hold to follow: the mouse target is sent at most every FOLLOW_PERIOD s
const FOLLOW_PERIOD := 0.15
var _genome: Dictionary = {}
var _garfio_profile: Dictionary = {}   # kept so creatures spawned later (dev console, scenarios) get a body
var gaze := PlantGaze.new()        # plants noticed by resting the pointer on them (brief creature-fixes 6)
var _gaze_poll := 0.0
var gesture := Gesture.new()       # the left button: click, hold or orbit drag
var _orbit_btn := 0               # right/middle button held (1 = right, 2 = middle)
var _mid_travel := 0.0
var _far := false
var _nest := Vector2.ZERO
var _den = null
var _den_seen := false
var action_feed := ActionFeed.new()   # C state -> action signals (read only)
var dodge_hint := {"dir": 0, "until": 0}     # the player's dodge key, for the dodge animation's side
var ui_mode := &""
var selected_id := -1
var action_signals: Dictionary = {}   # last frame's per-entity signals (tests read it)

func _ready() -> void:
	build()

# PLAN-rock step 9 switch (Game.settings.sun_shadows, off by default): terrain, scree, meadow and grass go dark in terrain shadows.
func set_sun_shadows(on: bool) -> void:
	if on:
		var ms: int = data_for_shadows().apply_sun_shadows(Look.sun_dir())
		print("sun shadows baked in %d ms" % ms)
	terrain_chunks.set_uniform("rock_shadows", 1.0 if on else 0.0)
	grass.set_sun_shadows(on)

func _place_props(setup: Dictionary) -> void:
	_nest = setup.nest
	grass.material.set_shader_parameter("nest_center", _nest)
	var tier: int = terrain_chunks.tier
	if Game.settings.quality == "auto" and tier == 2:
		tier = 1
	props.build(Game.data, setup, int(Game.terrain.seed), tier, Game.settings)

func data_for_shadows():
	return Game.data

var kit_reused := false            # terrain, water, rivers, grass and props came from Game's kit instead of being built
var build_ms := {}                # phase -> milliseconds of the last build (brief creature-fixes 5; printed once per entry)
var _phase_t := 0

# The pieces that only depend on the terrain and the quality settings: Game parks them across a scene change.
func kit_nodes() -> Dictionary:
	return {"terrain": terrain_chunks, "water": water, "rivers": rivers, "grass": grass, "props": props}

func _phase(name: String) -> void:
	var now := Time.get_ticks_msec()
	build_ms[name] = now - _phase_t
	_phase_t = now

func build() -> void:
	var data = Game.data
	_phase_t = Time.get_ticks_msec()
	var t_start := _phase_t
	Clouds.apply(Game.settings.get("weather", ""))
	world_env = WorldEnvironment.new()
	world_env.environment = EnvironmentFactory.make_environment()
	add_child(world_env)
	sun = EnvironmentFactory.make_sun()
	add_child(sun)
	_phase("environment")
	var kit: Dictionary = Game.take_kit()
	if not kit.is_empty():
		# the terrain, water, rivers, grass and flora of the last island are still built: take them back (see Game.park_island)
		terrain_chunks = kit.terrain
		water = kit.water
		rivers = kit.rivers
		grass = kit.grass
		props.free()
		props = kit.props
		for n in [terrain_chunks, water, rivers, grass]:
			add_child(n)
		kit_reused = true
		_phase("kit_reused")
	else:
		terrain_chunks = TerrainChunks.new()
		terrain_chunks.name = "Terrain"
		add_child(terrain_chunks)
		terrain_chunks.build(data)
		_phase("terrain_meshes")
		water = Water.new()
		water.name = "Water"
		add_child(water)
		water.build(data)
		_phase("water")
		rivers = Rivers.new()
		rivers.name = "Rivers"
		add_child(rivers)
		rivers.build(data)
		_phase("rivers")
		var t0 := Time.get_ticks_msec()
		grass = Grass.new()
		grass.name = "Grass"
		add_child(grass)
		grass.build(data, int(Game.settings.grass))
		_phase("grass")
		if Game.settings.get("sun_shadows", false):
			set_sun_shadows(true)
		print("grass built in %d ms (%d blades)" % [Time.get_ticks_msec() - t0, int(Game.settings.grass)])
	RenderTier.apply_viewport(get_viewport())
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 48.0
	camera.near = 0.25
	camera.far = 12000.0
	add_child(camera)
	camera.current = true
	debug_camera = camera
	Game.camera = camera
	_phase("camera")
	_build_stage()
	build_ms["total"] = Time.get_ticks_msec() - t_start
	Game.report_entry(build_ms)
	set_process(true)
	Game.island_ready.emit()

func _build_stage() -> void:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome: Dictionary = Game.player_genome().duplicate(true)
	if Game.pending_scenario.is_empty():
		var keep_wings: bool = FlightMode._dev_on()      # the flight test needs the wings of the creature the owner made
		genome.parts = genome.parts.filter(func(p): return p.type in ["pico", "pata", "ojo"] or (keep_wings and str(p.type).begins_with("wing_")))
		if not genome.parts.any(func(p): return p.type == "pico"):
			genome.parts.append({"type": "pico", "t": 1.0, "ang": 0.0, "size": 1.0, "level": 1, "tier": 0})
		genome.schema = "cpore.creature/5"
		for part in genome.parts:
			part["level"] = 1
			part["tier"] = 0
	_genome = genome
	var pr := Profile.from_studio(genome, manifest)
	if not pr.ok:
		push_error("player genome has no combat profile: %s" % pr.error)
		return
	var garfio_profile := StageSetup.garfio_profile(manifest)
	_garfio_profile = garfio_profile
	stage = StageWorld.new()
	stage.name = "Stage"
	# The C world walks on the generated heights (PLAN-heights): attach them before anything resets it.
	if stage.world.set_field(Game.terrain) != 0:
		push_error("the island field was rejected: %s" % stage.world.last_error())
		return
	stage.world.reset({"terrain": 2})     # a probe state so StageSetup can ask the C walk rule
	var setup := StageSetup.build(Game.data, int(Game.settings.seed), pr.profile, garfio_profile, bool(Game.settings.wild), stage.world, bool(Game.settings.get("herds", true)), bool(Game.settings.get("secrets", true)))
	stage.edit_anywhere = bool(Game.settings.get("edit_anywhere", true))
	stage.process_priority = -10     # the world ticks before the actors read it (action timing, G77)
	add_child(stage)
	_phase("stage_setup")
	props.name = "IslandProps"
	add_child(props)
	_place_props(setup)
	_phase("props_flora")
	_den = Vector2(setup.wild[0].home_x, setup.wild[0].home_z) if setup.wild.size() > 0 else null
	var ground := Callable(Game, "visual_ground")
	stage.ground_fn = ground
	player_input = PlayerInput.new()
	player_input.blocked = Callable(Game, "movement_blocked")
	_sync_controls()
	stage.input_provider = player_input.sample
	player_input.limit = stage.world.bound() - 0.1
	stage.after_tick = player_input.after_tick
	if stage.reset(setup) != 0:
		push_error("the C world rejected the island setup")
		return
	_phase("stage_reset")
	stage.world.nav_warm()    # fill the GO walk grid now (about 0.6 s), so no click pays for it later
	_phase("nav_warm")
	stage.ticked.connect(func(state: Dictionary) -> void: Game.world_ticked.emit(state))
	stage.combat_events.connect(func(events: Array) -> void: Game.combat_events.emit(events))
	Game.stage = stage
	var player_host := ActorHost.new()
	player_host.name = "Player"
	add_child(player_host)
	player_host.setup(genome, 0, setup.player, ground)
	hosts[0] = player_host
	for i in setup.wild.size():
		var h := ActorHost.new()
		h.name = "Wild%d" % (i + 1)
		add_child(h)
		h.setup(_species_body(int(setup.wild[i].species)), i + 1, setup.wild[i].profile, ground)
		h.set_meta("base_scale", _species_scale(int(setup.wild[i].species)))
		hosts[i + 1] = h
	_phase("creatures")
	var yaw := PI
	if setup.wild.size() > 0:
		yaw = atan2(setup.nest.x - setup.wild[0].home_x, setup.nest.y - setup.wild[0].home_z)
	chase = ChaseCamera.new(player_host.height(), yaw, ground)
	chase.strategic_distance = Game.data.size_m * 0.85
	chase.free_orbit = bool(Game.settings.get("camera/free_orbit", false))
	icons = StrategicIcons.new()
	icons.camera = camera
	icons.ground_fn = ground
	icons.pois_fn = pois_fn if pois_fn.is_valid() else _default_pois
	icons.actors_fn = _icon_actors
	add_child(icons)
	ground_marks = GroundMarks.new()
	ground_marks.name = "GroundMarks"
	ground_marks.island = self
	add_child(ground_marks)
	Game.creature_clicked.connect(func(_id: int, _p: Vector3) -> void: ground_marks.clear_move(false))
	stage_ui = StageUI.new()
	stage_ui.name = "StageUI"
	add_child(stage_ui)
	stage_ui.setup(self, str(genome.get("name", "Merodeador")))
	flight = FlightMode.new()
	flight.setup(self, stage)
	if bool(Game.settings.wild):    # S5a: visual-only radial fauna (no C entities), see radial_fauna.gd
		var radial_fauna := preload("res://game/island/radial_fauna.gd").new()
		radial_fauna.name = "RadialFauna"
		add_child(radial_fauna)
		radial_fauna.setup(Game.data, int(Game.settings.seed), setup.nest, ground, func() -> Vector3: return camera.global_position)
	_build_secrets(ground)      # before the part nodes: the cave fossil stands on the chamber floor, not on the rock above it
	var part_nodes := preload("res://game/stage/part_nodes.gd").new()
	add_child(part_nodes)
	part_nodes.setup(stage, ground)
	var lineage_error := preload("res://game/stage/lineage_session.gd").install(stage, genome)
	if lineage_error != "":
		push_error(lineage_error)
	for h in hosts.values():
		h.footfall.connect(stage_ui.on_footfall)
	stage_ui.ui.menu_requested.connect(Game.goto_menu)
	var lineage_controller := preload("res://game/stage/lineage_controller.gd").new()
	add_child(lineage_controller)
	lineage_controller.setup(self)
	_update_actors(0.0)
	_update_camera(0.0)
	_phase("ui_and_rest")
	if not Game.pending_scenario.is_empty():
		var parsed: Dictionary = Game.pending_scenario
		Game.pending_scenario = {}
		var err := load_scenario(parsed)
		if err != "":
			Game.startup_error = err
			push_error(err)

# --- scenarios and saves (devtools/scenario.gd) ------------------------------------------------------

func camera_state() -> Dictionary:
	var out := {}
	if chase != null:
		for k in ["yaw", "pitch", "distance", "orbit_pitch", "z_target"]:
			var v = chase.get(k)
			if v != null:
				out[k] = v
	return out

func scenario_ctx() -> Dictionary:
	var isl := {}
	if stage.world.has_field():
		var info: Dictionary = stage.world.field_info()
		isl = {"seed": info.seed, "terrain_version": CporeTerrain.version(), "terrain_hash": info.hash}
	var ctx := {"genome": _genome, "island": isl, "camera": camera_state(), "plants": gaze.to_list()}
	var dev = get_tree().root.get_node_or_null("Dev")
	if dev != null and dev.has_method("tuning_state"):
		ctx["tuning"] = dev.tuning_state()
	return ctx

func save_scenario(path: String, kind: String, note: String) -> String:
	return Scenario.save(stage, scenario_ctx(), path, kind, note)

func save_game() -> String:
	return Scenario.save(stage, scenario_ctx(), "%s/%s" % [Scenario.save_dir, Scenario.SAVE_SLOT], "save", "")

func load_game() -> String:
	var parsed := Scenario.read("%s/%s" % [Scenario.save_dir, Scenario.SAVE_SLOT])
	if not parsed.ok:
		return parsed.error
	return load_scenario(parsed)

# Applies a read() scenario to the running island. Returns "" or one readable sentence.
func load_scenario(parsed: Dictionary) -> String:
	var res := Scenario.load_into(parsed, stage, scenario_ctx())
	if not res.ok:
		return res.error
	var d: Dictionary = parsed.dict
	var genome: Dictionary = d.get("genome", {})
	var setup: Dictionary = stage.world.get_setup()
	_place_props(setup)
	if not genome.is_empty() and genome != _genome:
		_genome = genome
		hosts[0].queue_free()
		var h := ActorHost.new()
		h.name = "Player"
		add_child(h)
		h.setup(genome, 0, setup.player, Callable(Game, "visual_ground"))
		hosts[0] = h
		if stage_ui != null:
			h.footfall.connect(stage_ui.on_footfall)
	for id in hosts.keys():
		if id <= 0:
			continue
		var remove: bool = id >= stage.cur.entities.size()
		if not remove:
			var e: Dictionary = stage.cur.entities[id]
			var cousin: Dictionary = preload("res://game/stage/lineage_session.gd").cousin(stage.world, id) if int(e.get("cousin_generation", 0)) > 0 else {}
			if cousin.is_empty():
				remove = hosts[id].has_meta("lineage_body")
			else:
				remove = str(hosts[id].get_meta("lineage_body", "")) != str(cousin.body_json)
		if remove:
			hosts[id].queue_free()
			hosts.erase(id)
	_sync_hosts()
	if player_input != null:
		player_input.clear_destination()
	if stage_ui != null:
		stage_ui.ui.clear_selection()
	gaze.from_list(d.get("plants", []))
	if chase != null:
		for k in d.get("camera", {}):
			if chase.get(k) != null:
				chase.set(k, d.camera[k])
	_update_actors(0.0)
	_update_camera(0.0)
	if res.get("note", "") != "" and stage_ui != null:
		stage_ui.ui.show_message(res.note, "warn")
	return ""

# Each wild species has its own genome (res://game/data/<name>.json: Rondo, Zanco, Espinodo, Garfio), built by the same
# procedural creature builder and realism layer as the player. The C collision radius is the same 0.6 m for all four
# (radius_cm 0 in CP_STAGE_SPECIES), so the scale puts each body's footprint width at about that circle: Garfio's is 1.12 m
# unscaled, Rondo 1.22 x 0.8, Zanco 1.08 x 0.75 (tall: legs and neck), Espinodo 1.72 x 0.65 (its tail hammer sticks out).
const SPECIES_BODY := ["rondo", "zanco", "espinodo", "garfio", "acechalunas", "babosa"]
const SPECIES_SCALE := [0.8, 0.75, 0.65, 1.0, 0.8, 0.85]
static var _body_cache := {}

func _species_body(species: int) -> Dictionary:
	var k := clampi(species, 0, SPECIES_BODY.size() - 1)
	if not _body_cache.has(k):
		_body_cache[k] = Profile.load_json("res://game/data/%s.json" % SPECIES_BODY[k])
	return _body_cache[k].duplicate(true)

func _species_scale(species: int) -> float:
	return SPECIES_SCALE[clampi(species, 0, SPECIES_SCALE.size() - 1)]

# Creatures that appear after the build (console spawn, restored scenarios) get a body when their species has one.
func _sync_hosts() -> void:
	var es: Array = stage.cur.entities
	for i in range(1, es.size()):
		if hosts.has(i):
			continue
		var cousin: Dictionary = preload("res://game/stage/lineage_session.gd").cousin(stage.world, i) if int(es[i].get("cousin_generation", 0)) > 0 else {}
		var h := ActorHost.new()
		h.name = "Wild%d" % i
		add_child(h)
		var body: Dictionary = _species_body(int(es[i].species)) if cousin.is_empty() else JSON.parse_string(cousin.body_json)
		var profile: Dictionary = _garfio_profile if cousin.is_empty() else stage.world.get_setup().wild[i - 1].profile
		h.setup(body, i, profile, Callable(Game, "visual_ground"))
		h.set_meta("base_scale", _species_scale(int(es[i].species)))
		if not cousin.is_empty():
			h.set_meta("lineage_body", str(cousin.body_json))
		hosts[i] = h
		if stage_ui != null:
			h.footfall.connect(stage_ui.on_footfall)

# C2 secrets: the hidden cave chamber (ground rule + interior), the five shards and the day/night dressing. The C world owns all
# three (stage_secrets.c); a world reset without secrets simply has nothing to draw.
func _build_secrets(ground: Callable) -> void:
	day_night = DayNight.new()
	day_night.name = "DayNight"
	day_night.env = world_env.environment
	day_night.sun = sun
	add_child(day_night)
	day_night.apply_state(stage.cur)
	day_night.k = float(stage.cur.get("day", {}).get("light", 1000)) / 1000.0
	day_night.update_now()
	stage.ticked.connect(day_night.apply_state)
	var cave: Dictionary = stage.cur.get("cave", {})
	cave_site = CaveSite.from_state(cave)
	Game.data.cave_site = cave_site if cave_site.on else null
	if cave_site.on:
		cave_site.build(self)
	if not stage.cur.get("shards", {}).get("items", []).is_empty():
		var shards := preload("res://game/stage/shard_nodes.gd").new()
		add_child(shards)
		shards.setup(stage, ground)

# The player's pose: the C world's, or the flyer's while the flight test is in the air.
func player_sample() -> Dictionary:
	var base: Dictionary = stage.sample(0)
	return flight.sample(base) if flight != null else base

func _update_actors(dt: float) -> void:
	_sync_hosts()
	if flight != null:
		flight.tick(dt)
	action_signals = action_feed.read(stage.prev, stage.cur, stage.alpha())
	var tick: int = int(stage.cur.combat.tick)
	var alpha: float = stage.alpha()
	var p0: Vector3 = player_sample().pos
	_hidden.clear()
	for e in stage.cur.entities:
		if bool(e.get("hidden", false)):
			_hidden[int(e.id)] = true
	for id in hosts:
		var sm: Dictionary = stage.sample(id) if id != 0 else player_sample()
		if id == 0:
			sm["intent"] = player_input.intent_yaw()      # head and shoulders lead the body
		var d: float = (sm.pos as Vector3).distance_to(p0)
		var sig: Dictionary = action_signals.get(id, {})
		var ctx := {"sig": sig, "tick": tick, "alpha": alpha, "beat_phase": (7 * id) % 12, "lod": 0 if d < 40.0 else (1 if d < 80.0 else 2), "mode": "", "attend": false}
		var tid: int = int(sig.get("target_id", -1))
		if tid < 0 and id == 0 and selected_id > 0:
			tid = selected_id
		if tid >= 0 and hosts.has(tid) and tid != id:
			var th: Node3D = hosts[tid]
			var ts: Dictionary = stage.sample(tid)
			var ent: Dictionary = stage.cur.entities[tid]
			ctx["target"] = {"id": tid, "pos": ts.pos, "radius": float(ent.get("radius_cm", 60)) * 0.01, "height": th.height(), "spheres": th.occluders() if d < 40.0 else []}
		if id == 0:
			ctx["dodge_dir"] = int(dodge_hint.dir) if Time.get_ticks_msec() < int(dodge_hint.until) else 0
			if int(stage.cur.order.verb) == 13:      # C is running the player's observe order
				ctx["mode"] = "observe"
		elif ui_mode == &"befriend" and id == selected_id and not bool(sig.get("in_fight", false)) and d < 12.0:
			ctx["attend"] = true
		hosts[id].update(dt, sm, ctx)
		if id > 0:
			# the driver sets the host basis (yaw) every frame, so the size goes on after it: a species' size, and a carcass
			# shrinks as it is eaten (4 bites)
			var ent0: Dictionary = stage.cur.entities[id]
			var base: float = float(hosts[id].get_meta("base_scale", 1.0))
			hosts[id].scale = Vector3.ONE * base * (0.3 + 0.7 * float(ent0.get("meat", 0)) / 4.0 if bool(ent0.get("dead", false)) else 1.0)
	if flight != null:
		flight.post_update(dt)
	var p: Dictionary = player_sample()
	player_pos = p.pos
	var occ := []
	if occluders_enabled:
		for id in hosts:
			if id == 0 or (hosts[id].global_position - player_pos).length() < 40.0:
				occ.append_array(hosts[id].occluders())
	while occ.size() > 12:
		occ.pop_back()
	while occ.size() < 12:
		occ.append(Vector4(0, -999, 0, 0))
	terrain_chunks.apply_occluders(player_pos, occ)
	grass.apply_occluders(player_pos, occ)
	grass.set_center(player_pos)

func _update_camera(dt: float) -> void:
	if not chase_enabled or chase == null:
		_apply_zoom_budget(chase.z if chase != null else 0.0)    # creature visibility (hidden sleepers) must not depend on the chase camera
		return
	var p: Dictionary = player_sample()
	var state: Dictionary = stage.cur
	var fighting: bool = state.active >= 0
	if flight != null:
		chase.air_on = flight.active() and flight.model.airborne()
		chase.air_y = p.pos.y
		chase.air_dive = flight.model != null and flight.model.mode == "dive"
	var enemy = null
	if fighting:
		var e: Dictionary = state.entities[state.active + 1]
		enemy = {"x": e.x, "z": e.z}
	var vp := get_viewport().get_visible_rect().size
	chase.kick = bool(Game.settings.get("camera/kick", false))
	chase.mouse_walk = player_input.destination != null      # walking to a click or following the mouse: the camera does not turn for it
	var r: Dictionary = chase.update({"x": p.pos.x, "z": p.pos.z, "yaw": p.yaw, "speed": p.speed, "vx": p.vel.x, "vz": p.vel.z}, enemy, fighting, dt, vp.x / maxf(vp.y, 1.0))
	camera.fov = 48.0 + float(r.fov_add)
	camera.near = clampf(float(r.distance) * 0.012, 0.05, 40.0)       # keep the depth buffer precise at 3 km
	var view := _cave_camera(r, p.pos)
	camera.position = view.position
	camera.look_at(view.aim)
	player_input.view_yaw = chase.view_yaw
	_apply_zoom_budget(chase.z)
	icons.update_alpha(chase.icon_alpha())

# Inside the hidden cave the chase camera is replaced by a close one under the roof: 6.5 m back along the chase direction and 2.4 m
# up, pulled toward the player until it is inside the shell (or in front of the mouth, in the open air), no higher than the roof.
func _cave_camera(r: Dictionary, player: Vector3) -> Dictionary:
	if cave_site == null or not cave_site.on or cave_site.zone(player.x, player.z) == 0:
		return {"position": r.position, "aim": r.aim}
	var back := Vector3(r.position.x - player.x, 0.0, r.position.z - player.z)
	back = Vector3(0, 0, 1) if back.length() < 0.1 else back.normalized()
	var fl: float = cave_site.floor_h
	var cam: Vector3 = player + back * 6.5 + Vector3(0, 2.4, 0)
	for i in 12:
		var roof: float = cave_site.roof_at(cam.x, cam.z)
		if (roof < 1e8 and roof > 1.6) or cave_site.frame(cam.x, cam.z).x < -3.0:
			break
		cam = player + (cam - player) * 0.8
	var roof2: float = cave_site.roof_at(cam.x, cam.z)
	var top: float = fl + (roof2 - 0.7 if roof2 < 1e8 else 6.0)
	cam.y = clampf(cam.y, fl + 0.6, maxf(top, fl + 1.0))
	return {"position": cam, "aim": player + Vector3(0, 1.0, 0)}

# Cheap far zoom: grass, sun shadows and creature models are off where they cannot be seen (icons replace models).
func _apply_zoom_budget(zz: float) -> void:
	var far := zz >= FAR_GRASS_Z
	if far != _far:
		_far = far
		grass.visible = not far
		sun.shadow_enabled = not far
	var models := zz < MODEL_OFF_Z
	for id in hosts:
		var h = hosts[id]
		var want: bool = models and not _hidden.has(id)
		if h.visible != want:
			h.visible = want

# Default sites for the strategic map: the nest, and the den of the wild species (a `?` until the player has come
# within DEN_SEEN metres). The sites registry (D2) replaces this through `pois_fn` (see strategic_icons.gd).
func _default_pois() -> Array:
	var out: Array = [{"id": "nest", "kind": "nest", "pos": _nest, "discovered": true, "label": "Nest"}]
	if _den != null:
		if not _den_seen and Vector2(player_pos.x, player_pos.z).distance_to(_den) < DEN_SEEN:
			_den_seen = true
		out.append({"id": "den", "kind": "den", "pos": _den, "discovered": _den_seen, "label": "Den"})
	return out

func _icon_actors() -> Array:
	var out: Array = []
	if stage == null or stage.cur.is_empty():
		return out
	for id in hosts:
		var e: Dictionary = stage.cur.entities[id]
		if e.get("dead", false) or bool(e.get("hidden", false)):
			continue
		var smp: Dictionary = stage.sample(id)
		out.append({"id": id, "kind": "player" if id == 0 else "creature", "pos": smp.pos, "yaw": smp.yaw})
	return out

# Controls settings and the creature's pose into the input (latch frame, tank steering, intent).
func _sync_controls() -> void:
	player_input.strafe_latch = bool(Game.settings.get("controls/strafe_latch", true))
	player_input.tank = bool(Game.settings.get("controls/tank", false))
	if stage != null and not stage.cur.is_empty():
		var e: Dictionary = stage.cur.entities[0]
		player_input.facing_yaw = atan2(e.fx, e.fz)
		player_input.position = Vector2(e.x, e.z)

func _process(delta: float) -> void:
	Clouds.set_time(Time.get_ticks_msec() * 0.001)
	if stage == null:
		return
	_sync_controls()
	_update_actors(delta)
	_update_camera(delta)
	gesture.tick(delta)
	_update_move_marker()
	_update_hover(delta)
	_update_plants(delta)
	_mouse_held = gesture.holding
	if _mouse_held and not Game.movement_blocked():
		_follow_clock -= delta
		if _follow_clock <= 0.0:
			_follow_clock = FOLLOW_PERIOD
			_click_ground(false, get_viewport().get_mouse_position(), true)
	else:
		_follow_clock = 0.0

# Mouse (docs/godot/CAMERA-ZOOM.md section 1): wheel zooms along the one curve; the LEFT button never moves the camera (a
# press that moves more than DRAG_PX is ignored, otherwise it is a click acted on at release or, held, steers the creature
# towards the mouse); right and middle drag orbit; a middle click or Home puts the camera back behind the creature.
func _unhandled_input(event: InputEvent) -> void:
	if stage == null or chase == null:
		return
	if flight != null and flight.handle_input(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_on_motion(event as InputEventMouseMotion)
	elif event.is_action_pressed("zoom_in"):
		chase.zoom(-1.0)
	elif event.is_action_pressed("zoom_out"):
		chase.zoom(1.0)
	elif event.is_action_pressed("camera_reset"):
		chase.reset_behind()
	elif event is InputEventMouseButton:
		_on_button(event as InputEventMouseButton)

func _on_button(e: InputEventMouseButton) -> void:
	if e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			gesture.press(e.position, e.double_click)
		else:
			var kind := gesture.release()
			chase.orbit_active = _orbit_btn != 0
			if kind == "click":
				_click(gesture.press_pos, gesture.double)
			elif kind == "hold" and ground_marks != null:
				ground_marks.follow_release()
			_mouse_held = false
	elif e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
		var bit := 1 if e.button_index == MOUSE_BUTTON_RIGHT else 2
		if e.pressed:
			_orbit_btn |= bit
			_mid_travel = 0.0
			chase.orbit_active = true
		else:
			_orbit_btn &= ~bit
			chase.orbit_active = _orbit_btn != 0
			if e.button_index == MOUSE_BUTTON_MIDDLE and _mid_travel < Gesture.DRAG_PX:
				chase.reset_behind()

func _on_motion(e: InputEventMouseMotion) -> void:
	gesture.motion(e.position)           # a left drag is classified (and then ignored): the left button never moves the camera
	var orbiting := _orbit_btn != 0
	if _orbit_btn != 0:
		_mid_travel += e.relative.length()
	if orbiting:
		chase.orbit_active = true
		chase.orbit(e.relative.x, e.relative.y)
		if player_input.frame_yaw != null:
			player_input.frame_yaw = chase.view_yaw     # steering with the mouse while keys are held

# A click: a strategic icon (select; double-click zooms back down), a creature, or the ground (walk there).
func _click(pos: Vector2, _double: bool) -> void:
	if icons != null and icons.alpha >= 0.3:
		var it: Dictionary = icons.pick(pos)
		if not it.is_empty():
			last_click = pos
			Game.creature_clicked.emit(it.id, it.pos)
			return
	_click_ground(true, pos)

func _click_ground(allow_pick: bool, mouse: Vector2, follow: bool = false) -> void:
	var ground := Callable(Game, "visual_ground")
	if allow_pick:
		var picked := Pointer.pick_entity(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse), stage.cur.entities, ground)
		if not picked.is_empty():
			player_input.clear_destination()
			last_click = mouse
			Game.creature_clicked.emit(picked.id, picked.pos)
			return
	if allow_pick and stage_ui != null and selected_id > 0:
		stage_ui.ui.clear_selection()       # a click on empty ground deselects (and walks there)
	var hit = Pointer.ground_hit(camera, mouse, ground, maxf(900.0, chase.distance * 2.0))
	if hit != null:
		if walk_blocked(hit):
			player_input.clear_destination()
			if not follow:
				ground_marks.move_blocked(hit)
			return
		if follow:
			player_input.follow_to(Vector2(hit.x, hit.z))
			ground_marks.follow_marker(hit)
		else:
			player_input.set_destination(Vector2(hit.x, hit.z))
			ground_marks.move_marker(hit)

# Deep water (sea, lake, deep river: the C world blocks on them) or ground steeper than the slope ceiling: a click there
# orders nothing and shows the cut "cannot go there" ring.
func walk_blocked(hit: Vector3) -> bool:
	var d = Game.data
	var k: int = d.cell_index(hit.x, hit.z)
	if d.is_sea(k) or d.is_pond(k) or d.river_class(k) >= 3:
		return true
	return d.normal(hit.x, hit.z).y < 0.621     # cos(51.6 degrees): creatures never rest on steeper ground

# The marker clears when the destination goes away: arrived (it expands and fades) or cancelled (WASD, a new order: quick).
func _update_move_marker() -> void:
	if ground_marks == null or player_input == null:
		return
	ground_marks.player_radius = maxf(0.6, float(stage.cur.entities[0].get("radius_cm", 60)) * 0.01) if not stage.cur.is_empty() else 0.6
	var has: bool = player_input.destination != null
	if _had_dest and not has and not ground_marks.follow_active() and ground_marks.move_visible():
		var d := Vector2(player_pos.x - ground_marks.destination().x, player_pos.z - ground_marks.destination().z).length()
		ground_marks.clear_move(d < GroundMarks.ARRIVE_RADIUS + 1.5)
	_had_dest = has

# Pointer over a creature for 0.25 s: its ring shows at 0.4 in its relationship style (docs/godot/UI-DIEGETIC.md 7.16).
# Observing plants: the pointer resting on a plant for PlantGaze.DWELL seconds writes it into the journal. Creatures come first
# (a hovered creature, a fight, a held button or an open book never count), so this never competes with the radial.
func _update_plants(dt: float) -> void:
	if camera == null or stage == null or stage_ui == null:
		return
	_gaze_poll += dt
	if _gaze_poll < 0.1:
		return
	var step := _gaze_poll
	_gaze_poll = 0.0
	var id := ""
	if not Game.movement_blocked() and not gesture.down and _hover_id < 0 and int(stage.cur.active) < 0 and selected_id <= 0:
		var m := get_viewport().get_mouse_position()
		id = gaze.pick(props.records, camera.project_ray_origin(m), camera.project_ray_normal(m))
	var found := gaze.tick(step, id)
	if found != "":
		stage_ui.plant_noticed(found)

func plant_rows() -> Array:
	return gaze.journal_rows(preload("res://game/island/flora_placement.gd").recipes())

func _update_hover(dt: float) -> void:
	if ground_marks == null or camera == null or stage == null:
		return
	_hover_poll -= dt
	if _hover_poll > 0.0:
		return
	_hover_poll = 0.1
	var id := -1
	if not Game.movement_blocked() and not gesture.down:
		var m := get_viewport().get_mouse_position()
		if m == _hover_mouse and _hover_id >= -1:
			id = _hover_id
		else:
			_hover_mouse = m
			var picked := Pointer.pick_entity(camera.project_ray_origin(m), camera.project_ray_normal(m), stage.cur.entities, Callable(Game, "ground"))
			id = int(picked.id) if not picked.is_empty() else -1
	if id != _hover_id:
		_hover_id = id
		_hover_t = 0.0
	else:
		_hover_t += 0.1
	var want := _hover_id if _hover_t >= 0.25 else -1
	if want >= 0 and want < stage.cur.entities.size():
		var e: Dictionary = stage.cur.entities[want]
		ground_marks.set_hover(want, int(e.get("relationship", 0)), bool(e.get("hostile", false)))
	else:
		ground_marks.set_hover(-1)
