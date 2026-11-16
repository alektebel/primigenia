extends Node3D
# The island scene: sky/environment, sun, terrain chunks, water, grass, actors, camera.
# Built in code from Game.data (set by the boot flow before this scene loads).

const Look := preload("res://game/island/look.gd")
const EnvironmentFactory := preload("res://game/island/environment.gd")
const TerrainChunks := preload("res://game/island/terrain_chunks.gd")
const Water := preload("res://game/island/water.gd")
const Grass := preload("res://game/island/grass.gd")

var terrain_chunks: Node3D
var world_env: WorldEnvironment
var sun: DirectionalLight3D
var water: Node3D
var grass: MultiMeshInstance3D
var debug_camera: Camera3D

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
	debug_camera = Camera3D.new()
	debug_camera.name = "DebugCamera"
	debug_camera.fov = 48.0
	debug_camera.near = 0.25
	debug_camera.far = 12000.0
	add_child(debug_camera)
	debug_camera.current = true
	Game.camera = debug_camera
	set_process(true)
	Game.island_ready.emit()

func _process(_delta: float) -> void:
	if grass != null and Game.camera != null:
		grass.set_center(Game.camera.global_position if player_pos == Vector3.INF else player_pos)

var player_pos := Vector3.INF   # set by the actor code; until then grass follows the camera
