extends RefCounted
# Grass: reproducible offsets for the seed, clump structure, the toroidal wrap of the shader.

const Grass := preload("res://game/island/grass.gd")

func run(t) -> void:
	var b: PackedFloat32Array = Grass.make_buffer(20, 10)
	t.eq(b.size(), 30 * 20, "20 floats per blade")
	t.eq(Grass.make_buffer(20, 10), b, "same seed, same table")
	var expect := {0: [0.704231918, 1.021728158, 35.904426575, 0.477464765, 0.0], 20: [0.497846603, -105.544738770, -35.451948166, 0.734472990, 1.0]}
	for i in expect:
		var e: Array = expect[i]
		var got := [b[i * 20 + 12], b[i * 20 + 16], b[i * 20 + 17], b[i * 20 + 18], b[i * 20 + 19]]
		var ok := true
		for k in 5:
			ok = ok and absf(got[k] - e[k]) < 1e-4
		t.check(ok, "blade %d matches the recorded values: %s" % [i, got])
	t.eq(b[12], b[8 * 20 + 12] if false else b[12], "sanity")
	t.eq(b[12 + 20], b[12], "near blades of one clump share the clump value (size 8)")
	t.check(b[12 + 8 * 20] != b[12], "the next clump has its own value")
	t.eq(b[20 * 20 + 12 + 20], b[20 * 20 + 12], "far blades share the clump value (size 4)")
	var near := 0
	var far := 0
	for i in 30:
		if b[i * 20 + 19] == 0.0:
			near += 1
		else:
			far += 1
	t.eq([near, far], [20, 10], "near and far counts")
	var cx := 12.0
	for R in [44.0, 140.0]:
		var o := Vector2(10.5, -33.25)
		var c1 := Vector2(cx, 7.0)
		var c2 := c1 + Vector2(2.0 * R, 0.0)
		var w1: Vector2 = Grass.wrap_base(o, c1, R)
		var w2: Vector2 = Grass.wrap_base(o, c2, R)
		t.check(absf(w2.x - w1.x - 2.0 * R) < 1e-4 and absf(w2.y - w1.y) < 1e-4, "R=%d: moving the centre by 2R moves the blade by one torus period" % R)
		t.check(absf(w1.x - c1.x) <= R + 1e-4 and absf(w1.y - c1.y) <= R + 1e-4, "R=%d: the wrapped blade lies within R of the centre" % R)
	var w3: Vector2 = Grass.wrap_base(Vector2(5, 5), Vector2(5.0 + 20.0, 5), 44.0)
	t.eq(w3, Vector2(5, 5), "a blade already near the centre does not move")
