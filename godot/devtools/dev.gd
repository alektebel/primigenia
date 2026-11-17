extends Node
## Autoload "Dev": the dev tools root (PLAN-devtools.md). The key legend is always on; everything else
## is created here only when `enabled`.
##
## Owner-question defaults live in the constants below so they are easy to change in one place.

const Legend := preload("res://devtools/legend.gd")
const TimeControl := preload("res://devtools/time_control.gd")
const Console := preload("res://devtools/console/console.gd")
const Sites := preload("res://devtools/sites.gd")
const TuningRegistry := preload("res://devtools/tuning/registry.gd")
const TuningPanel := preload("res://devtools/tuning/panel.gd")
const Feedback := preload("res://devtools/feedback.gd")
const SitePicker := preload("res://devtools/site_picker.gd")

## 1. Dev tools ON in every debug build (the editor and `godot --path godot`); `--dev` forces on in any
##    build, `--no-dev` forces off.
const ON_IN_DEBUG_BUILDS := true
## 2. The console key is the physical key left of 1 and F12 (see project.godot, action dev_console).
## 3. F8 feedback folder: repo-root `feedback/` (git-ignored) when writable, else user://feedback/.
const FEEDBACK_REPO_DIR := "feedback"
const FEEDBACK_USER_DIR := "user://feedback"
## 5. Island fights next to cliffs or water: stop the fighters at the edge (PLAN-heights H2).
## 6. Island mode (FIELD terrain) stays out of the WASM and Python bindings in C0.
## 7. Caves stay unwalkable in C0 (no interior in the heightfield).

var enabled := false
var legend: CanvasLayer
var time_control: CanvasLayer
var picker: CanvasLayer
var feedback: CanvasLayer
var tuning                    # TuningRegistry (entries appear when the island is ready)
var tuning_panel: CanvasLayer
var sites                     # Sites for the running island (built when it is ready)
var console: CanvasLayer     # console.console.registry is the command registry (also used by the agent socket)

static func compute_enabled(args: PackedStringArray, debug_build: bool) -> bool:
	if "--no-dev" in args:
		return false
	if "--dev" in args:
		return true
	return ON_IN_DEBUG_BUILDS and debug_build

func _ready() -> void:
	enabled = compute_enabled(OS.get_cmdline_user_args(), OS.is_debug_build())
	legend = Legend.new()
	legend.name = "Legend"
	add_child(legend)
	if enabled:
		Feedback.install_logger()
		feedback = Feedback.new()
		feedback.name = "Feedback"
		add_child(feedback)
		time_control = TimeControl.new()
		time_control.name = "TimeControl"
		add_child(time_control)
		console = Console.new()
		console.name = "Console"
		add_child(console)
		picker = SitePicker.new()
		picker.name = "SitePicker"
		picker.registry = console.registry if console.registry != null else null
		add_child(picker)
		tuning = TuningRegistry.new()
		tuning.register_commands(console.registry)
		tuning_panel = TuningPanel.new()
		tuning_panel.name = "TuningPanel"
		tuning_panel.tuning = tuning
		add_child(tuning_panel)
		Game.island_ready.connect(_on_island_ready)

func _on_island_ready() -> void:
	if Game.data == null or Game.stage == null:
		return
	sites = Sites.new()
	sites.seed_id = int(Game.settings.seed)
	sites.list = Sites.for_island(Game.data, Game.terrain.get("params", {}), Game.stage.world.get_setup())
	sites.load_bookmarks()
	console.registry.services["sites"] = sites
	tuning.bind_sim(Game.stage)
	tuning.bind_island(get_tree().current_scene)
	picker.sites = sites
	picker.registry = console.registry

## Both A/B slots and the active one, recorded by scenarios and feedback bundles.
func tuning_state() -> Dictionary:
	return tuning.state() if tuning != null else {}

func _process(_dt: float) -> void:
	if enabled and tuning != null and legend != null:
		legend.header_extra = tuning.chip()
