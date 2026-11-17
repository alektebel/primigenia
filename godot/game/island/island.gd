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
const Gesture := preload("res://game/player/pointer_gesture.gd")
const ChaseCamera := preload("res://game/player/chase_camera.gd")
const ActorHost := preload("res://game/actors/actor_host.gd")
const StageUI := preload("res://game/stage/stage_ui.gd")
const StrategicIcons := preload("res://game/island/strategic_icons.gd")

const FAR_GRASS_Z := 0.6          # zoom above which grass, shadows and models are switched off
const MODEL_OFF_Z := 0.85
const DEN_SEEN := 60.0

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
var icons: CanvasLayer
var pois_fn: Callable            # sites hook for the strategic map (see strategic_icons.gd; D2 registry plugs in here)
var _mouse_held := false
var gesture := Gesture.new()       # the left button: click, hold or orbit drag
var _orbit_btn := 0               # right/middle button held (1 = right, 2 = middle)
var _mid_travel := 0.0
var _far := false
var _nest := Vector2.ZERO
var _den = null
var _den_seen := false

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
	var pr := Profile.from_studio(genome, manifest)
	if not pr.ok:
		push_error("player genome has no combat profile: %s" % pr.error)
		return
	var garfio_profile := StageSetup.garfio_profile(manifest)
	var setup := StageSetup.build(Game.data, int(Game.settings.seed), pr.profile, garfio_profile, bool(Game.settings.wild))
	stage = StageWorld.new()
	stage.name = "Stage"
	add_child(stage)
	_nest = setup.nest
	_den = Vector2(setup.wild[0].home_x, setup.wild[0].home_z) if setup.wild.size() > 0 else null
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

func _update_actors(dt: float) -> void:
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
	camera.near = clampf(float(r.distance) * 0.012, 0.25, 40.0)       # keep the depth buffer precise at 3 km
	camera.position = r.position
	camera.look_at(r.target)
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
	if stage == null:
		return
	_sync_controls()
	_update_actors(delta)
	_update_camera(delta)
	gesture.tick(delta)
	_mouse_held = gesture.holding
	if _mouse_held and not Game.movement_blocked():
		_click_ground(false, get_viewport().get_mouse_position())

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

func _click_ground(allow_pick: bool, mouse: Vector2) -> void:
	var ground := Callable(Game, "ground")
	if allow_pick:
		var picked := Pointer.pick_entity(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse), stage.cur.entities, ground)
		if not picked.is_empty():
			player_input.clear_destination()
			last_click = mouse
			Game.creature_clicked.emit(picked.id, picked.pos)
			return
	var hit = Pointer.ground_hit(camera, mouse, ground, maxf(900.0, chase.distance * 2.0))
	if hit != null:
		player_input.set_destination(Vector2(hit.x, hit.z))
