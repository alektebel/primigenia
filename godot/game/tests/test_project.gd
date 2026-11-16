extends RefCounted
# Project wiring: input actions, autoload, main scene.

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "sprint", "walk_to",
	"camera_orbit", "zoom_in", "zoom_out"]

func run(t) -> void:
	for a in ACTIONS:
		t.check(InputMap.has_action(a), "input action " + a)
	t.eq(ProjectSettings.get_setting("application/run/main_scene"), "res://game/main.tscn", "main scene")
	t.check(ResourceLoader.exists("res://game/main.tscn"), "main scene exists")
	t.check(ResourceLoader.exists("res://game/island/island.tscn"), "island scene exists")
	t.eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60, "physics stays at 60 Hz")
	t.eq(ProjectSettings.get_setting("rendering/renderer/rendering_method"), "gl_compatibility", "GL compatibility")
	t.check(ProjectSettings.has_setting("autoload/Game"), "Game autoload registered")
