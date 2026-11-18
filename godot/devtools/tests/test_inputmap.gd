extends RefCounted
# Step 1: the InputMap migration (every key binding is an action with a physical keycode).

const Radial := preload("res://ui/radial_menu.gd")
const GAME_ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4", "guard", "dodge_left", "dodge_right",
	"radial_reopen", "pause_menu", "gift", "gift_cycle", "radial_attack", "radial_befriend", "radial_observe", "radial_intimidate"]
const DEV_ACTIONS := ["legend_hold", "dev_console", "dev_sites", "dev_bookmark", "dev_tuning", "dev_ab_swap",
	"dev_quicksave", "dev_quickload", "dev_feedback", "time_pause", "time_step", "time_slower", "time_faster"]

static func key(code: Key, ctrl := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.ctrl_pressed = ctrl
	e.pressed = true
	return e

func run(t) -> void:
	for a in GAME_ACTIONS + DEV_ACTIONS:
		t.check(InputMap.has_action(a), "action %s exists" % a)
		if InputMap.has_action(a):
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					t.check(ev.physical_keycode != 0 and ev.keycode == 0, "%s uses a physical keycode" % a)
	t.check(InputMap.action_get_events("dev_console").size() == 2, "console on the key left of 1 and F12")
	# Ctrl+B with the radial open must not choose Befriend (the dev bookmark owns it).
	var radial = Radial.new()
	var chosen := []
	radial.chosen.connect(func(m): chosen.append(m))
	radial.size = Vector2(800, 600)
	radial.open_at(Vector2(400, 300))
	radial._gui_input(key(KEY_B, true))
	t.check(chosen.is_empty() and radial.visible, "Ctrl+B leaves the radial unchanged")
	radial._gui_input(key(KEY_B))
	t.eq(chosen.size(), 1, "plain B still chooses Befriend")
	radial.open_at(Vector2(400, 300))
	radial._gui_input(key(KEY_ESCAPE))
	t.check(not radial.visible, "Esc closes the radial")
	radial.free()
