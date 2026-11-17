extends Node3D
# The island scene: sky/environment, sun, terrain chunks, water, grass, the 10 Hz stage world,
# creatures, chase camera and controls. Built in code from Game.data (set by the boot flow).

const Look := preload("res://game/island/look.gd")
const EnvironmentFactory := preload("res://game/island/environment.gd")
const TerrainChunks := preload("res://game/island/terrain_chunks.gd")
const Water := preload("res://game/island/water.gd")
const Grass := preload("res://game/island/grass.gd")
const StageWorld := preload("res://game/stage/stage_world.gd")
const StageSetup := preload("res://game/stage/stage_setup.gd")
const Profile := preload("res://game/stage/profile.gd")
const PlayerInput := preload("res://game/player/player_input.gd")
const Pointer := preload("res://game/player/pointer.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")
const StageUI := preload("res://game/stage/stage_ui.gd")
const Scenario := preload("res://devtools/scenario.gd")

var terrain_chunks: Node3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var water: Node3D
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
var _mouse_held := false
var _genome: Dictionary = {}
var _garfio_profile: Dictionary = {}   # kept so creatures spawned later (dev console, scenarios) get a body

func _ready() -> void:
	build()

func build() -> void:
	var data = Game.data
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
	var t0 := Time.get_ticks_msec()
	grass = Grass.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(data, int(Game.settings.grass))
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
	var setup := StageSetup.build(Game.data, int(Game.settings.seed), pr.profile, garfio_profile, bool(Game.settings.wild))
	stage = StageWorld.new()
	stage.name = "Stage"
	add_child(stage)
	var ground := Callable(Game, "ground")
	stage.ground_fn = ground
	player_input = PlayerInput.new()
	player_input.blocked = Callable(Game, "movement_blocked")
	_sync_controls()
	stage.input_provider = player_input.sample
	stage.after_tick = player_input.after_tick
	if stage.reset(setup) != 0:
		push_error("the C world rejected the island setup")
		return
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
		hosts[i + 1] = h
	var yaw := PI
	if setup.wild.size() > 0:
		yaw = atan2(setup.nest.x - setup.wild[0].home_x, setup.nest.y - setup.wild[0].home_z)
	chase = ChaseCamera.new(player_host.height(), yaw, ground)
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
		for k in ["yaw", "pitch", "distance", "orbit_pitch"]:
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
		h.setup(genome, 0, setup.player, Callable(Game, "ground"))
		hosts[0] = h
		if stage_ui != null:
			h.footfall.connect(stage_ui.on_footfall)
	for id in hosts.keys():
		if id > 0 and (id >= stage.cur.entities.size() or int(stage.cur.entities[id].species) != 3):
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

# Creatures that appear after the build (console spawn, restored scenarios) get a body when their species has one.
func _sync_hosts() -> void:
	var es: Array = stage.cur.entities
	for i in range(1, es.size()):
		if hosts.has(i) or int(es[i].species) != 3:
			continue
		var h := ActorHost.new()
		h.name = "Wild%d" % i
		add_child(h)
		h.setup(Profile.load_json("res://game/data/garfio.json"), i, _garfio_profile, Callable(Game, "ground"))
		hosts[i] = h
		if stage_ui != null:
			h.footfall.connect(stage_ui.on_footfall)

func _update_actors(dt: float) -> void:
	_sync_hosts()
	for id in hosts:
		var sm: Dictionary = stage.sample(id)
		if id == 0:
			sm["intent"] = player_input.intent_yaw()      # head and shoulders lead the body
		hosts[id].update(dt, sm)
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
	camera.position = r.position
	camera.look_at(r.target)
	player_input.view_yaw = chase.view_yaw

# Controls settings and the creature's pose into the input (latch frame, tank steering, intent).
func _sync_controls() -> void:
	player_input.strafe_latch = bool(Game.settings.get("controls/strafe_latch", true))
	player_input.tank = bool(Game.settings.get("controls/tank", false))
	if stage != null and not stage.cur.is_empty():
		var e: Dictionary = stage.cur.entities[0]
		player_input.facing_yaw = atan2(e.fx, e.fz)
		player_input.position = Vector2(e.x, e.z)

func _process(delta: float) -> void:
	if stage == null:
		return
	_sync_controls()
	_update_actors(delta)
	_update_camera(delta)
	if _mouse_held and not Game.movement_blocked():
		_click_ground(false, get_viewport().get_mouse_position())

func _unhandled_input(event: InputEvent) -> void:
	if stage == null or chase == null:
		return
	if event is InputEventMouseMotion and Input.is_action_pressed("camera_orbit"):
		chase.orbit(event.relative.x, event.relative.y)
		if player_input.frame_yaw != null:
			player_input.frame_yaw = chase.view_yaw     # steering with the mouse while keys are held
	elif event.is_action_pressed("zoom_in"):
		chase.zoom(-1.0)
	elif event.is_action_pressed("zoom_out"):
		chase.zoom(1.0)
	elif event.is_action_pressed("walk_to"):
		_mouse_held = true
		_click_ground(true, (event as InputEventMouseButton).position if event is InputEventMouseButton else get_viewport().get_mouse_position())
	elif event.is_action_released("walk_to"):
		_mouse_held = false

func _click_ground(allow_pick: bool, mouse: Vector2) -> void:
	var ground := Callable(Game, "ground")
	if allow_pick:
		var picked := Pointer.pick_entity(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse), stage.cur.entities, ground)
		if not picked.is_empty():
			player_input.clear_destination()
			last_click = mouse
			Game.creature_clicked.emit(picked.id, picked.pos)
			return
	var hit = Pointer.ground_hit(camera, mouse, ground)
	if hit != null:
		player_input.set_destination(Vector2(hit.x, hit.z))
