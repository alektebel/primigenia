extends RefCounted
# Step 1: the InputMap migration (every key binding is an action with a physical keycode).

const Ring := preload("res://ui/mode_ring.gd")
const GAME_ACTIONS := ["ability_1", "ability_2", "ability_3", "ability_4", "guard", "dodge_left", "dodge_right",
	"radial_reopen", "pause_menu", "gift", "gift_cycle", "journal", "family_tree"]
const DEV_ACTIONS := ["legend_hold", "dev_console", "dev_sites", "dev_bookmark", "dev_tuning", "dev_ab_swap",
	"dev_quicksave", "dev_quickload", "dev_feedback", "dev_options", "time_pause", "time_step", "time_slower", "time_faster"]

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
	# The mode ring is mouse only (the owner's answer): no key chooses on it, with or without Ctrl.
	for ac in ["radial_attack", "radial_befriend", "radial_observe", "radial_intimidate"]:
		t.check(not InputMap.has_action(ac), "%s is gone (the ring is chosen with the mouse)" % ac)
	var ring = Ring.new()
	var chosen := []
	ring.chosen.connect(func(m): chosen.append(m))
	ring.open_at(Vector2(400, 300), 70.0)
	for code in [KEY_A, KEY_B, KEY_W, KEY_S, KEY_D, KEY_O, KEY_I]:
		ring.handle_input(key(code))
		ring.handle_input(key(code, true))
	t.check(chosen.is_empty() and ring.visible, "no key chooses a mode on the ring")
	ring.free()
