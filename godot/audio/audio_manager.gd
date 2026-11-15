extends Node
## Audio system: bus layout, positional 3D sounds, ambience, UI clicks, persisted volumes.
##
## Buses: Master, Music, SFX, Ambience (created at runtime if the project has no layout).
## Add as a child of the stage. The listener is the active Camera3D (Godot default).

const Settings := preload("res://audio/audio_settings.gd")
const SOUND_DIR := "res://audio/sounds/"
const NAMES: Array[String] = ["step-0", "step-1", "step-2", "grass-rustle", "wind", "meadow", "idle", "aggro",
	"hurt", "death", "hit", "block", "dodge", "spit", "click"]
const BUS_NAMES := {"master": "Master", "music": "Music", "sfx": "SFX", "ambience": "Ambience"}

signal volume_changed(bus: String, value: float)

var settings
var streams: Dictionary = {}
var errors: Array[String] = []
var played: Dictionary = {}
var paused := false
var _step := 0
var _pool: Array[AudioStreamPlayer3D] = []
var _ui: AudioStreamPlayer
var _wind: AudioStreamPlayer
var _meadow: AudioStreamPlayer
var _rustle: AudioStreamPlayer3D
var sound_dir := SOUND_DIR

func _init(settings_path: String = "user://settings.cfg") -> void:
	settings = Settings.new(settings_path)

func _ready() -> void:
	ensure_buses()
	load_all()
	apply_settings()
	_ui = AudioStreamPlayer.new()
	_ui.bus = "SFX"
	add_child(_ui)
	for i in 16:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.unit_size = 5.0
		p.max_distance = 100.0
		add_child(p)
		_pool.append(p)
	_wind = _loop2d("wind", "Ambience")
	_meadow = _loop2d("meadow", "Ambience")
	_wind.volume_db = linear_to_db(0.08)
	_meadow.volume_db = linear_to_db(0.5)
	_rustle = AudioStreamPlayer3D.new()
	_rustle.bus = "Ambience"
	_rustle.stream = _looped(streams.get("grass-rustle"))
	_rustle.volume_db = -80.0
	add_child(_rustle)

# --- buses -------------------------------------------------------------------

static func ensure_buses() -> void:
	for key in ["music", "sfx", "ambience"]:
		var n: String = BUS_NAMES[key]
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")

func apply_settings() -> void:
	ensure_buses()
	for k in Settings.BUSES:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(BUS_NAMES[k]), linear_to_db(maxf(settings.values[k], 0.0001)))
	AudioServer.set_bus_mute(0, bool(settings.values["mute"]) or paused)

func set_volume(bus: String, value) -> void:
	settings.set_value(bus, value)
	apply_settings()
	volume_changed.emit(bus, float(settings.values.get(bus, 0.0)))

func get_volume(bus: String) -> float:
	return float(settings.values.get(bus, 0.0))

func set_mute(on: bool) -> void:
	set_volume("mute", on)

func is_muted() -> bool:
	return bool(settings.values["mute"])

# --- loading -----------------------------------------------------------------

func load_all() -> void:
	for n in NAMES:
		var s := load_stream(n)
		if s:
			streams[n] = s
		else:
			errors.append(n)

func load_stream(n: String) -> AudioStream:
	var p := sound_dir + n + ".ogg"
	if ResourceLoader.exists(p):
		var r = load(p)
		if r is AudioStream:
			return r
	if FileAccess.file_exists(p):
		return AudioStreamOggVorbis.load_from_file(p)
	return null

func _looped(s: AudioStream) -> AudioStream:
	if s == null:
		return null
	var c: AudioStream = s.duplicate()
	if c is AudioStreamOggVorbis:
		c.loop = true
	return c

func _loop2d(n: String, bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	p.stream = _looped(streams.get(n))
	add_child(p)
	return p

# --- playback ----------------------------------------------------------------

func start_ambience() -> void:
	for p in [_wind, _meadow]:
		if p.stream and not p.playing:
			p.play()
	if _rustle.stream and not _rustle.playing:
		_rustle.play()

func _voice() -> AudioStreamPlayer3D:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]

## Positional one-shot on the SFX bus. Returns the player (null if the sound is missing).
func play_at(name: String, pos: Vector3, volume: float = 0.5, rate: float = 1.0) -> AudioStreamPlayer3D:
	if paused or not streams.has(name):
		return null
	var p := _voice()
	p.stream = streams[name]
	p.global_position = pos if is_inside_tree() else Vector3.ZERO
	p.volume_db = linear_to_db(maxf(volume, 0.001))
	p.pitch_scale = clampf(rate, 0.5, 2.0)
	p.play()
	played[name] = int(played.get(name, 0)) + 1
	return p

static func size_rate(radius_cm: float) -> float:
	## Big bodies sound lower (same curve as the web stage).
	return clampf(1.25 / sqrt(maxf(radius_cm, 1.0) / 100.0), 0.6, 1.6)

## Call from the rig's foot-contact signal.
func footstep(pos: Vector3, speed: float, radius_cm: float = 60.0) -> void:
	if paused or speed < 0.15:
		return
	var size := maxf(0.5, radius_cm / 100.0)
	var vol := minf(0.65, 0.12 + speed * 0.055) * minf(1.5, sqrt(size))
	play_at("step-%d" % (_step % 3), pos, vol, clampf(1.15 / sqrt(size), 0.65, 1.4))
	_step += 1

## kind: idle, aggro, hurt, death.
func cry(kind: String, pos: Vector3, radius_cm: float = 60.0, volume: float = 0.5) -> void:
	play_at(kind, pos, volume, size_rate(radius_cm))

func hit(pos: Vector3) -> void:
	play_at("hit", pos, 0.5)

func block(pos: Vector3) -> void:
	play_at("block", pos, 0.5)

func dodge(pos: Vector3) -> void:
	play_at("dodge", pos, 0.35)

func spit(pos: Vector3) -> void:
	play_at("spit", pos, 0.4)

func ui_click() -> void:
	if paused or not streams.has("click"):
		return
	_ui.stream = streams["click"]
	_ui.volume_db = linear_to_db(0.2)
	_ui.play()
	played["click"] = int(played.get("click", 0)) + 1

## Wind level for a ground height in metres (louder on high ground).
static func wind_gain(height: float) -> float:
	return 0.08 + minf(0.4, maxf(0.0, height) * 0.009)

## Rustle level: grass only (low, gentle slope), scales with walking speed.
static func rustle_gain(height: float, slope: float, speed: float) -> float:
	var on_grass := height > 0.0 and height < 35.0 and slope < 1.0
	return minf(0.26, speed * 0.04) if on_grass else 0.0

## Per-frame ambience update from the player's state.
func update_ambience(player_pos: Vector3, height: float, slope: float, speed: float) -> void:
	if _wind == null:
		return
	_wind.volume_db = linear_to_db(maxf(wind_gain(height), 0.0001))
	_rustle.global_position = player_pos
	var g := 0.0 if paused else rustle_gain(height, slope, speed)
	_rustle.volume_db = linear_to_db(g) if g > 0.001 else -80.0

func set_paused(on: bool) -> void:
	paused = on
	apply_settings()
	for p in [_wind, _meadow, _rustle]:
		if p:
			p.stream_paused = on

## Connect a stage-side event: type 1 hit, 2/3 block, 4 dodge, 7 death (web event ids).
func combat_event(type: int, pos: Vector3, radius_cm: float = 60.0) -> void:
	match type:
		1:
			cry("hurt", pos, radius_cm, 0.35)
			hit(pos)
		2, 3:
			block(pos)
		4:
			dodge(pos)
		7:
			cry("death", pos, radius_cm, 0.7)
