extends RefCounted
# Verb-first targeting, the pure parts (docs/briefs/verb-target.md): the screen-space pick with its generous radius, the verb bar's
# geometry and the marker's colours. The whole flow through the island is game/tests/verb_target_test.gd.

const Pointer := preload("res://game/player/pointer.gd")
const VerbBar := preload("res://ui/verb_bar.gd")
const Marker := preload("res://ui/target_marker.gd")
const Modes := preload("res://ui/modes.gd")

# A pinhole camera at the origin looking down -Z: x' = 640 + 900 x / d, y' = 360 - 900 y / d.
static func project(w: Vector3) -> Variant:
	var d := -w.z
	if d <= 0.1:
		return null
	return Vector2(640.0 + 900.0 * w.x / d, 360.0 - 900.0 * (w.y - 1.5) / d)

func run(t) -> void:
	var pr := Callable(self, "_project")
	var near := {"id": 1, "feet": Vector3(0, 0, -10), "height": 1.5}
	var far := {"id": 2, "feet": Vector3(3, 0, -60), "height": 1.5}
	var at_near: Vector2 = project(Vector3(0, 0.75, -10))
	t.eq(Pointer.pick_screen(at_near, [near, far], pr), 1, "pick: the mouse on a creature picks it")
	t.eq(Pointer.pick_screen(at_near + Vector2(70, 30), [near, far], pr), 1, "pick: 70 px off a near body still picks it")
	t.eq(Pointer.pick_screen(Vector2(20, 20), [near, far], pr), -1, "pick: far from everything picks nothing")
	var at_far: Vector2 = project(Vector3(3, 0.75, -60))
	t.eq(Pointer.pick_screen(at_far + Vector2(30, 0), [near, far], pr), 2, "pick: a far creature (small on screen) is still caught 30 px away")
	t.eq(Pointer.pick_screen(at_far + Vector2(70, 0), [far], pr), -1, "pick: but not 70 px away")
	# two creatures: the one whose body the mouse is nearer, by its own scale
	var a := {"id": 3, "feet": Vector3(-0.5, 0, -10), "height": 1.5}
	var b := {"id": 4, "feet": Vector3(0.5, 0, -10), "height": 1.5}
	t.eq(Pointer.pick_screen(project(Vector3(0.4, 0.75, -10)), [a, b], pr), 4, "pick: of two neighbours the nearer wins")
	t.eq(Pointer.pick_screen(at_near, [{"id": 5, "feet": Vector3(0, 0, 5), "height": 1.5}], pr), -1, "pick: a creature behind the camera is ignored")
	t.eq(Pointer.pick_screen(at_near, [], pr), -1, "pick: no candidates")
	# verb bar
	var bar = VerbBar.new()
	bar.size = Vector2(1280, 720)
	t.eq(VerbBar.SLOTS.map(func(s): return s.mode), [Modes.ATTACK, Modes.BEFRIEND, Modes.EAT, Modes.OBSERVE, Modes.INTIMIDATE], "bar: Attack, Befriend, Eat, Observe, Intimidate")
	t.check(bar.slot_pos(0).x == bar.slot_pos(4).x and bar.slot_pos(0).x < 100.0 and bar.slot_pos(4).y > bar.slot_pos(0).y, "bar: a column on the left edge")
	for i in 5:
		t.eq(bar.slot_at(bar.slot_pos(i)), i, "bar: circle %d is hit at its centre" % i)
	t.eq(bar.slot_at(Vector2(10, 10)), -1, "bar: a click elsewhere is a world click")
	var chosen := []
	bar.verb_chosen.connect(func(m): chosen.append(m))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = bar.slot_pos(1)
	t.check(bar.handle_input(press), "bar: a press on a circle is used")
	t.eq(chosen, [Modes.BEFRIEND], "bar: it chooses Befriend")
	press.position = Vector2(5, 5)
	t.check(not bar.handle_input(press), "bar: a press elsewhere is not used")
	bar.arm(Modes.ATTACK)
	t.eq(bar.armed, Modes.ATTACK, "bar: arm")
	bar.free()
	# marker
	var red: Color = Marker.color_of(Modes.ATTACK)
	var green: Color = Marker.color_of(Modes.BEFRIEND)
	t.check(red.r > 0.8 and red.r > red.g * 1.5 and red.r > red.b * 1.5, "marker: Attack arrows are red")
	t.check(green.g > green.r and green.g > green.b * 0.9, "marker: Befriend arrows are green")
	for ac in ["verb_attack", "verb_befriend", "verb_eat", "verb_observe", "verb_intimidate"]:
		t.check(InputMap.has_action(ac), "input: %s exists" % ac)

func _project(w: Vector3) -> Variant:
	return project(w)
