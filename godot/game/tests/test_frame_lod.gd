extends SceneTree
## Regression: visual LOD must preserve near creatures, root tracking, and resume without time debt.
const Host := preload("res://game/actors/actor_host.gd")
class FakeDriver extends RefCounted:
	var updates := 0
	var rebases := 0
	var last_dt := 0.0
	func update(dt: float, _s: Dictionary, _ctx: Dictionary) -> void:
		updates += 1
		last_dt = dt
	func rebase() -> void:
		rebases += 1
var failed := 0
func check(value: bool, message: String) -> void:
	if not value:
		failed += 1
		printerr("FAIL ", message)
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var h := Host.new()
	h.driver = FakeDriver.new()
	var sm := {"pos": Vector3(8, 0, 3), "yaw": 0.4, "speed": 1.0}
	for i in 8:
		h.update_visual(1.0 / 60.0, sm, {}, 1, i)
	check(h.driver.updates == 8, "near poses update every frame")
	for i in 60:
		h.update_visual(1.0 / 60.0, sm, {}, 0, i)
	check(h.driver.updates == 8, "offscreen poses stop")
	check(h.position == sm.pos and absf(h.rotation.y - sm.yaw) < 0.00001, "culled roots still follow C")
	h.update_visual(1.0 / 60.0, sm, {}, 1, 60)
	check(h.driver.updates == 9 and h.driver.rebases == 1, "resume rebases once")
	check(h.driver.last_dt < 0.02, "offscreen time is never replayed")
	for i in 8:
		h.update_visual(1.0 / 60.0, sm, {}, 4, i)
	check(h.driver.updates == 11, "far poses are staggered at quarter rate")
	root.add_child(h)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 5, 0)
	camera.look_at(Vector3(0, 5, -100))
	h.entity_id = 1
	h.position = Vector3(0, 0, -20)
	check(h.visual_interval(camera, 20.0) == 1, "near creature keeps full IK")
	h.position = Vector3(0, 0, -60)
	check(h.visual_interval(camera, 60.0) == 2, "visible middle distance uses half rate")
	h.position = Vector3(0, 0, -100)
	check(h.visual_interval(camera, 100.0) == 4, "visible distance uses quarter rate")
	h.position = Vector3(0, 0, 100)
	check(h.visual_interval(camera, 100.0) == 0, "offscreen distance stops IK in headless too")
	h.visible = false
	h.position = Vector3(0, 0, -20)
	check(h.visual_interval(camera, 20.0) == 0, "hidden sleepers skip poses even near")
	h.entity_id = 0
	check(h.visual_interval(camera, 100.0) == 1, "player is never throttled")
	camera.free()
	h.free()
	print("frame LOD: %d failed" % failed)
	quit(1 if failed else 0)
