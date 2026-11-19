extends "res://game/tests/flora_evidence.gd"
# World-look frames (docs/godot/WORLD-LOOK-WL1.md): flora_evidence.gd plus rule-found cameras for boulders, scree and
# player-height meadow views from the nest, so every slice shares cameras. Same arguments:
#   -- <out dir> <quality low|medium|high> <base|volcano> [shot prefixes, comma separated]
# e.g. valley_chase,madre_spring,forest_floor,rk_,sh_  (prefix filter; plants close-ups need an explicit prefix too, see `wanted`).

func _extra(np: Vector3) -> void:
	for id in ["boulder", "outcrop", "scree"]:
		var r := densest(id, 30.0)
		if r.is_empty():
			print("none ", id)
			continue
		var p: Vector3 = r.p
		var e := p + Vector3(6, 0, 4) * (2.0 if id == "outcrop" else 1.0)
		await shot("rk_" + id + "_close", clear_eye(Vector3(e.x, ground(e) + 1.7, e.z), p), p + Vector3.UP * 0.8, 60.0)
		var e2 := p + Vector3(30, 0, 22)
		await shot("rk_" + id + "_wide", clear_eye(Vector3(e2.x, ground(e2) + 3.0, e2.z), p), p, 60.0)
	# Player-height meadow looks in 4 directions, 40 m off the nest.
	for a in 4:
		var dir := Vector3.RIGHT.rotated(Vector3.UP, a * PI * 0.5)
		var e := np + dir * 40.0
		await shot("rk_meadow_%d" % a, Vector3(e.x, ground(e) + 2.0, e.z), e + dir * 80.0 + Vector3.UP * 4.0, 62.0)
	# Shadow of a tall plant on the meadow. The sun is low (about 16 degrees) and behind the tree from this side, so the long shadow lies
	# across the grass between the tree and the camera, to the lower left of the frame.
	for id in ["madre_de_agua", "nieblon"]:
		var r := pick(id)
		if r.is_empty():
			continue
		var p: Vector3 = r.p
		var e := p + Vector3(40, 0, 20)
		await shot("sh_" + id, Vector3(e.x, ground(e) + 2.0, e.z), p + Vector3(-10, 6, -10), 62.0)
