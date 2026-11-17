extends Node
## Autoload "Dev": the dev tools root (PLAN-devtools.md). The key legend is always on; everything else
## is created here only when `enabled`.
##
## Owner-question defaults live in the constants below so they are easy to change in one place.

const Legend := preload("res://devtools/legend.gd")
const TimeControl := preload("res://devtools/time_control.gd")

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
		time_control = TimeControl.new()
		time_control.name = "TimeControl"
		add_child(time_control)
