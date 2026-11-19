extends RefCounted
# Step 2: the key legend is generated from the InputMap.

const Legend := preload("res://devtools/legend.gd")
const TestInputMap := preload("res://devtools/tests/test_inputmap.gd")

static func sig(ev: InputEventKey) -> String:
	return "%d|%s%s%s" % [ev.physical_keycode, ev.ctrl_pressed, ev.alt_pressed, ev.shift_pressed]

func run(t) -> void:
	var spec := Legend.spec()
	t.eq(spec.get("format"), "primigenia.legend/1", "legend.json parses")
	var actions: Dictionary = spec.actions
	for a in actions:
		t.check(InputMap.has_action(a), "legend action %s exists in the InputMap" % a)
		var expect: PackedStringArray = []
		for ev in InputMap.action_get_events(a):
			expect.append(Legend.event_text(ev))
		t.eq(Legend.action_text(a), " / ".join(expect), "legend text of %s is generated from its events" % a)
	for a in InputMap.get_actions():
		if not str(a).begins_with("ui_"):
			t.check(actions.has(str(a)), "InputMap action %s is listed in legend.json" % a)
	# No two actions of one context share an event.
	for ctx in spec.contexts:
		var seen := {}
		for a in actions:
			var e: Dictionary = actions[a]
			if not (ctx in e.contexts) or not InputMap.has_action(a):
				continue
			for ev in InputMap.action_get_events(a):
				if ev is InputEventKey:
					var s := sig(ev)
					t.check(not seen.has(s) or seen[s] == a, "context %s: %s and %s do not share %s" % [ctx, a, seen.get(s, ""), Legend.event_text(ev)])
					seen[s] = a
	# Readable key labels (one mapping function), headless names are the physical-key names.
	for pair in [["QuoteLeft", "`"], ["BracketLeft", "["], ["BracketRight", "]"], ["Period", "."], ["Escape", "Esc"], ["W", "W"], ["F12", "F12"], ["Home", "Home"]]:
		t.eq(Legend.pretty_key_name(pair[0]), pair[1], "key name %s reads %s" % pair)
	t.eq(Legend.key_text(KEY_QUOTELEFT, false), "`", "physical QuoteLeft reads ` without a layout")
	t.eq(Legend.key_text(KEY_BRACKETLEFT, false), "[", "physical BracketLeft reads [")
	t.eq(Legend.key_text(KEY_BRACKETRIGHT, false), "]", "physical BracketRight reads ]")
	t.eq(Legend.key_text(KEY_PERIOD, false), ".", "physical Period reads .")
	t.eq(Legend.key_text(KEY_ESCAPE, false), "Esc", "physical Escape reads Esc")
	t.eq(Legend.event_text(TestInputMap.key(KEY_ESCAPE)), "Esc", "event text of Escape")
	for a in actions:
		if InputMap.has_action(a):
			var txt := Legend.action_text(a)
			for bad in ["QuoteLeft", "BracketLeft", "BracketRight", "Period", "Escape"]:
				t.check(not txt.contains(bad), "legend text of %s has no enum name (%s)" % [a, txt])
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	t.eq(Legend.event_text(mb), "Left click", "left mouse button reads Left click")
	mb.button_index = MOUSE_BUTTON_RIGHT
	t.eq(Legend.event_text(mb), "Right click", "right mouse button reads Right click")
	# Mouse gestures are listed for walk and fight.
	for ctx in [&"walk", &"fight"]:
		var gk := Legend.rows(ctx, false).filter(func(r): return r.get("gesture", false)).map(func(r): return r.keys)
		for want in ["Left drag", "Right / Middle drag", "Wheel", "Middle click"]:
			t.check(gk.has(want), "%s legend lists the gesture %s" % [ctx, want])
	t.check(Legend.rows(&"walk", false).any(func(r): return r.keys == "Left click"), "left click (move) is listed")
	t.check(Legend.rows(&"walk", false).any(func(r): return r.action == "camera_reset" and r.keys.contains("Home")), "Home resets the camera")
	# Context switch changes the corner hint.
	var game = t.root.get_node("Game")
	var walk := Legend.corner_rows(game.legend_context(), true)
	t.eq(String(game.legend_context()), "walk", "default context is walk")
	game.stage = {"cur": {"active": 0}}
	t.eq(String(game.legend_context()), "fight", "an active fight is the fight context")
	var fight := Legend.corner_rows(game.legend_context(), true)
	game.radial_open = true
	t.eq(String(game.legend_context()), "radial", "radial wins over fight")
	var radial := Legend.corner_rows(game.legend_context(), true)
	game.console_open = true
	t.eq(String(game.legend_context()), "console", "console wins over everything")
	game.console_open = false
	game.radial_open = false
	game.stage = null
	t.check(str(walk) != str(fight) and str(fight) != str(radial) and str(walk) != str(radial), "walk, fight and radial show different corner hints")
	t.check(walk.size() >= 3 and walk.size() <= 5 and radial.size() >= 3, "corner hints are 3-5 entries")
	# Dev rows hidden when dev tools are off.
	var with_dev := Legend.rows(&"walk", true)
	var without := Legend.rows(&"walk", false)
	t.check(with_dev.any(func(r): return r.dev) and not without.any(func(r): return r.dev), "Dev.enabled=false hides the dev rows")
	t.check(without.any(func(r): return r.action == "sprint"), "player rows stay with dev tools off")
	# A rebound action shows the new key.
	var old := InputMap.action_get_events("sprint")
	InputMap.action_erase_events("sprint")
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_X
	InputMap.action_add_event("sprint", ev)
	t.check(Legend.action_text("sprint").contains("X"), "a rebound sprint shows X (%s)" % Legend.action_text("sprint"))
	InputMap.action_erase_events("sprint")
	for o in old:
		InputMap.action_add_event("sprint", o)
	t.check(not Legend.action_text("sprint").contains("X"), "rebinding restored")
	# The diegetic UI: no corner hint in play (the onboarding hints replace it), the ring's gestures are listed for the radial context.
	var lg = load("res://devtools/legend.gd").new()
	t.check(lg.corner_visible == false, "the corner hint is off by default")
	lg.free()
	var radial_rows := Legend.rows(&"radial", false)
	t.check(radial_rows.filter(func(r): return r.get("gesture", false)).size() == 4, "the radial context lists the four ring gestures (observe, befriend, intimidate, attack)")
	t.check(not InputMap.has_action("radial_attack") and InputMap.has_action("journal") and InputMap.has_action("family_tree"), "journal and family tree actions exist, the radial_* letters are gone")
	# Hard-coded studio keys are listed as `fixed`; flag them so the studio migrates.
	var fixed := Legend.fixed_entries()
	print("  NOTE legend: %d studio key(s) are still hard-coded (fixed) until the studio migrates to the InputMap" % fixed.size())
	t.check(fixed.all(func(f): return f.group == "Studio"), "only studio keys are fixed")
	# Dev.compute_enabled: --dev / --no-dev override the debug-build default.
	var Dev := load("res://devtools/dev.gd")
	t.check(Dev.compute_enabled(PackedStringArray(), true) and not Dev.compute_enabled(PackedStringArray(), false), "dev tools follow the debug build")
	t.check(Dev.compute_enabled(PackedStringArray(["--dev"]), false) and not Dev.compute_enabled(PackedStringArray(["--dev", "--no-dev"]), true), "--dev and --no-dev override")
