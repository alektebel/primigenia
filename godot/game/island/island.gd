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
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const PlayerInput := preload("res://game/player/player_input.gd")
const Pointer := preload("res://game/player/pointer.gd")
const Gesture := preload("res://game/player/pointer_gesture.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")
const StageUI := preload("res://game/stage/stage_ui.gd")
const Scenario := preload("res://devtools/scenario.gd")
const StrategicIcons := preload("res://game/island/strategic_icons.gd")

const FAR_GRASS_Z := 0.6          # zoom above which grass, shadows and models are switched off
const MODEL_OFF_Z := 0.85
const DEN_SEEN := 60.0
const ActionFeed := preload("res://actions/action_feed.gd")

var terrain_chunks: Node3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var water: Node3D
var rivers: Node3D
var grass: MultiMeshInstance3D
var camera: Camera3D
var debug_camera: Camera3D       # alias of camera (tests and evidence move it directly)
var stage: Node
var player_input
var chase
var stage_ui
var hosts := {}                  # entity id -> ActorHost
var chase_enabled := true
var player_pos := Vector3.INF
var last_click := Vector2.ZERO     # screen position of the last click that picked a creature (the radial opens there)
var occluders_enabled := true
var icons: CanvasLayer
var pois_fn: Callable            # sites hook for the strategic map (see strategic_icons.gd; D2 registry plugs in here)
var _mouse_held := false
var _follow_clock := 0.0       # hold to follow: the mouse target is sent at most every FOLLOW_PERIOD s
const FOLLOW_PERIOD := 0.15
var _genome: Dictionary = {}
var _garfio_profile: Dictionary = {}   # kept so creatures spawned later (dev console, scenarios) get a body
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

func data_for_shadows():
	return Game.data

func build() -> void:
	var data = Game.data
	Clouds.apply(Game.settings.get("weather", ""))
	world_env = WorldEnvironment.new()
	world_env.environment = EnvironmentFactory.make_environment()
	add_child(world_env)
	sun = EnvironmentFactory.make_sun()
	add_child(sun)
	terrain_chunks = TerrainChunks.new()
	terrain_chunks.name = "Terrain"
	add_child(terrain_chunks)
	terrain_chunks.build(data)
	water = Water.new()
	water.name = "Water"
	add_child(water)
	water.build(data)
	rivers = Rivers.new()
	rivers.name = "Rivers"
	add_child(rivers)
	rivers.build(data)
	var t0 := Time.get_ticks_msec()
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(data, int(Game.settings.grass))
	if Game.settings.get("sun_shadows", false):
		set_sun_shadows(true)
	print("grass built in %d ms (%d blades)" % [Time.get_ticks_msec() - t0, int(Game.settings.grass)])
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = 48.0
	camera.near = 0.25
	camera.far = 12000.0
	add_child(camera)
	camera.current = true
	debug_camera = camera
	Game.camera = camera
	_build_stage()
	set_process(true)
	Game.island_ready.emit()

func _build_stage() -> void:
	var manifest := Profile.load_json("res://game/data/parts.json")
	var genome: Dictionary = Game.player_genome()
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
	var setup := StageSetup.build(Game.data, int(Game.settings.seed), pr.profile, garfio_profile, bool(Game.settings.wild), stage.world, bool(Game.settings.get("herds", true)))
	stage.process_priority = -10     # the world ticks before the actors read it (action timing, G77)
	add_child(stage)
	_nest = setup.nest
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
	stage.world.nav_warm()    # fill the GO walk grid now (about 0.6 s), so no click pays for it later
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
		h.setup(Profile.load_json("res://game/data/garfio.json"), i + 1, setup.wild[i].profile, ground)
		h.set_meta("base_scale", _species_scale(int(setup.wild[i].species)))
		hosts[i + 1] = h
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
	stage_ui = StageUI.new()
	stage_ui.name = "StageUI"
	add_child(stage_ui)
	stage_ui.setup(self, str(genome.get("name", "Merodeador")))
	for h in hosts.values():
		h.footfall.connect(stage_ui.on_footfall)
	stage_ui.ui.menu_requested.connect(Game.goto_menu)
	_update_actors(0.0)
	_update_camera(0.0)
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
	var ctx := {"genome": _genome, "island": isl, "camera": camera_state()}
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
		if id > 0 and id >= stage.cur.entities.size():
			hosts[id].queue_free()
			hosts.erase(id)
	_sync_hosts()
	if player_input != null:
		player_input.clear_destination()
	if stage_ui != null:
		stage_ui.ui.clear_selection()
	if chase != null:
		for k in d.get("camera", {}):
			if chase.get(k) != null:
				chase.set(k, d.camera[k])
	_update_actors(0.0)
	_update_camera(0.0)
	if res.get("note", "") != "" and stage_ui != null:
		stage_ui.ui.show_message(res.note, "warn")
	return ""

# Until the other species have their own art they borrow Garfio's body, scaled by size so a herd reads as a different animal.
func _species_scale(species: int) -> float:
	return [0.6, 0.7, 0.9, 1.0][clampi(species, 0, 3)]

# Creatures that appear after the build (console spawn, restored scenarios) get a body when their species has one.
func _sync_hosts() -> void:
	var es: Array = stage.cur.entities
	for i in range(1, es.size()):
		if hosts.has(i):
			continue
		var h := ActorHost.new()
		h.name = "Wild%d" % i
		add_child(h)
		h.setup(Profile.load_json("res://game/data/garfio.json"), i, _garfio_profile, Callable(Game, "visual_ground"))
		h.set_meta("base_scale", _species_scale(int(es[i].species)))
		hosts[i] = h
		if stage_ui != null:
			h.footfall.connect(stage_ui.on_footfall)

func _update_actors(dt: float) -> void:
	_sync_hosts()
	action_signals = action_feed.read(stage.prev, stage.cur, stage.alpha())
	var tick: int = int(stage.cur.combat.tick)
	var alpha: float = stage.alpha()
	var p0: Vector3 = stage.sample(0).pos
	for id in hosts:
		var sm: Dictionary = stage.sample(id)
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
	var p: Dictionary = stage.sample(0)
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
		return
	var p: Dictionary = stage.sample(0)
	var state: Dictionary = stage.cur
	var fighting: bool = state.active >= 0
	var enemy = null
	if fighting:
		var e: Dictionary = state.entities[state.active + 1]
		enemy = {"x": e.x, "z": e.z}
	var vp := get_viewport().get_visible_rect().size
	chase.kick = bool(Game.settings.get("camera/kick", false))
	var r: Dictionary = chase.update({"x": p.pos.x, "z": p.pos.z, "yaw": p.yaw, "speed": p.speed, "vx": p.vel.x, "vz": p.vel.z}, enemy, fighting, dt, vp.x / maxf(vp.y, 1.0))
	camera.fov = 48.0 + float(r.fov_add)
	camera.near = clampf(float(r.distance) * 0.012, 0.25, 40.0)       # keep the depth buffer precise at 3 km
	camera.position = r.position
	camera.look_at(r.aim)
	player_input.view_yaw = chase.view_yaw
	_apply_zoom_budget(chase.z)
	icons.update_alpha(chase.icon_alpha())

# Cheap far zoom: grass, sun shadows and creature models are off where they cannot be seen (icons replace models).
func _apply_zoom_budget(zz: float) -> void:
	var far := zz >= FAR_GRASS_Z
	if far != _far:
		_far = far
		grass.visible = not far
		sun.shadow_enabled = not far
	var models := zz < MODEL_OFF_Z
	for h in hosts.values():
		if h.visible != models:
			h.visible = models

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
		if e.get("dead", false):
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
	_mouse_held = gesture.holding
	if _mouse_held and not Game.movement_blocked():
		_follow_clock -= delta
		if _follow_clock <= 0.0:
			_follow_clock = FOLLOW_PERIOD
			_click_ground(false, get_viewport().get_mouse_position(), true)
	else:
		_follow_clock = 0.0

# Mouse (docs/godot/CAMERA-ZOOM.md section 1): wheel zooms along the one curve; a left press that moves more than
# DRAG_PX is an orbit drag, otherwise it is a click (acted on at release) or, held, steers towards the mouse; right and
# middle drag orbit; a middle click or Home puts the camera back behind the creature.
func _unhandled_input(event: InputEvent) -> void:
	if stage == null or chase == null:
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
			_mouse_held = false
	elif e.button_index == MOUSE_BUTTON_RIGHT or e.button_index == MOUSE_BUTTON_MIDDLE:
		var bit := 1 if e.button_index == MOUSE_BUTTON_RIGHT else 2
		if e.pressed:
			_orbit_btn |= bit
			_mid_travel = 0.0
			chase.orbit_active = true
		else:
			_orbit_btn &= ~bit
			chase.orbit_active = _orbit_btn != 0 or gesture.dragging
			if e.button_index == MOUSE_BUTTON_MIDDLE and _mid_travel < Gesture.DRAG_PX:
				chase.reset_behind()

func _on_motion(e: InputEventMouseMotion) -> void:
	var orbiting := _orbit_btn != 0 or gesture.motion(e.position)
	if _orbit_btn != 0:
		_mid_travel += e.relative.length()
	if orbiting:
		chase.orbit_active = true
		chase.orbit(e.relative.x, e.relative.y)
		if player_input.frame_yaw != null:
			player_input.frame_yaw = chase.view_yaw     # steering with the mouse while keys are held

# A click: a strategic icon (select; double-click zooms back down), a creature, or the ground (walk there).
func _click(pos: Vector2, double: bool) -> void:
	if icons != null and icons.alpha >= 0.3:
		var it: Dictionary = icons.pick(pos)
		if not it.is_empty():
			if double:
				chase.set_zoom(chase.Z_CHASE)
			last_click = pos
			Game.creature_clicked.emit(it.id, it.pos)
			return
		if double:
			chase.set_zoom(chase.Z_CHASE)
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
		if follow:
			player_input.follow_to(Vector2(hit.x, hit.z))
		else:
			player_input.set_destination(Vector2(hit.x, hit.z))
