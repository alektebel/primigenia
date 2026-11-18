extends RefCounted
## Test ground and scripted courses of the locomotion zoo. Pure data: a height field the C world walks on and, per lane,
## a list of steps a runner turns into orders. Lane i is a strip LANE_W wide along z; every lane has the same layout, so
## the creatures run the same course side by side:
##   z -108 .. -76   start, figure-8 (two tangent circles of radius 5, centred z -84)
##   z  -66 .. -50   steps (a 1.8 m stair pyramid at x +9.5); z -40 .. -4 slalom (7 gates, 5 m either side)
##   z  -10 .. +28   U-turn lane (run to z 26, turn back, again)
##   z  +34 .. +90   five ramps of 10, 20, 30, 40 and 50 degrees (rise 6 m, plateau 10 m), side by side

const LANE_W := 24.0
const N := 256
const SIZE := 256.0
const BASE_H := 5.0
const RAMP_DEG := [10.0, 20.0, 30.0, 40.0, 50.0]
const RAMP_RISE := 6.0
const RAMP_Z0 := 40.0
const RAMP_SPACING := 4.8
const RAMP_HALF := 2.0
const START_Z := -100.0
const NAMES := ["figure8", "zigzag", "steps", "uturn", "ramps", "all"]

static func lane_x(i: int, count: int) -> float:
	return (float(i) - float(count - 1) * 0.5) * LANE_W

static func ramp_x(k: int) -> float:
	return (float(k) - 2.0) * RAMP_SPACING

static func ramp_len(k: int) -> float:
	return RAMP_RISE / tan(deg_to_rad(RAMP_DEG[k]))

# Ground height at a world point for a zoo of `count` lanes.
static func height(x: float, z: float, count: int) -> float:
	var i := clampi(int(round(x / LANE_W + float(count - 1) * 0.5)), 0, count - 1)
	var lx := x - lane_x(i, count)
	var h := BASE_H
	for k in RAMP_DEG.size():
		var cov := clampf((RAMP_HALF + 0.5 - absf(lx - ramp_x(k))) / 1.0, 0.0, 1.0)
		if cov <= 0.0:
			continue
		var len := ramp_len(k)
		var hz := clampf((z - RAMP_Z0) * tan(deg_to_rad(RAMP_DEG[k])), 0.0, RAMP_RISE)
		if z > RAMP_Z0 + len + 10.0:
			hz *= clampf(1.0 - (z - (RAMP_Z0 + len + 10.0)), 0.0, 1.0)
		h = maxf(h, BASE_H + hz * cov)
	if lx > 8.5 and lx < 10.5 and z > -67.0 and z < -49.0:
		var s := int(floor((z + 66.0) / 1.5))
		var up := 0.0
		if s < 0:
			up = 0.0
		elif s <= 5:
			up = 0.3 * float(s + 1)
		elif s <= 7:
			up = 1.8
		elif s <= 13:
			up = 0.3 * float(13 - s)
		h = maxf(h, BASE_H + up)
	return h

# The C field entry for CporeWorld.set_field: n*n heights at the cell centres.
static func field_entry(count: int) -> Dictionary:
	var cell := SIZE / float(N)
	var arr := PackedFloat32Array()
	arr.resize(N * N)
	for j in N:
		var z := (float(j) + 0.5) * cell - SIZE * 0.5
		for i in N:
			arr[j * N + i] = height((float(i) + 0.5) * cell - SIZE * 0.5, z, count)
	return {"n": N, "size_m": SIZE, "height": arr, "hash": "20%02x" % count, "seed": 0}

static func go(x: float, z: float, r: float = 2.5) -> Dictionary:
	return {"k": "go", "x": x, "z": z, "r": r, "max": 900}

static func head(hx: int, hz: int, ticks: int) -> Dictionary:
	return {"k": "head", "hx": hx, "hz": hz, "ticks": ticks}

static func wait(ticks: int) -> Dictionary:
	return {"k": "wait", "ticks": ticks}

static func figure8(x0: float) -> Array:
	var s: Array = [go(x0, -84.0, 3.0)]
	var zc := -84.0
	for q in range(1, 17):
		var a := float(q) * TAU / 16.0
		s.append(go(x0 - 5.0 + 5.0 * cos(a), zc + 5.0 * sin(a), 2.6 if q < 16 else 2.0))
	for q in range(1, 17):
		var b := float(q) * TAU / 16.0
		s.append(go(x0 + 5.0 - 5.0 * cos(b), zc + 5.0 * sin(b), 2.6 if q < 16 else 2.0))
	return s

static func zigzag(x0: float) -> Array:
	var s: Array = [go(x0, -46.0, 3.0)]
	for k in 7:
		s.append(go(x0 + (5.0 if k % 2 == 0 else -5.0), -40.0 + 6.0 * float(k), 2.5))
	return s

static func steps(x0: float) -> Array:
	return [go(x0 + 9.5, -72.0, 2.0), go(x0 + 9.5, -46.0, 2.0)]

static func uturn(x0: float) -> Array:
	return [go(x0, -8.0, 2.5), go(x0, 26.0, 2.5), go(x0 + 4.0, -6.0, 2.5), go(x0, 26.0, 2.5), go(x0 - 4.0, 30.0, 1.5)]

static func ramps(x0: float) -> Array:
	var s: Array = []
	for k in RAMP_DEG.size():
		var xc := x0 + ramp_x(k)
		var ticks := int(maxf(12.0, (ramp_len(k) + 10.0) / 2.0) * 10.0)
		s.append(go(xc, 34.0, 1.5))
		s.append(head(0, 32767, ticks))
		s.append(wait(15))
		if k == RAMP_DEG.size() - 1:
			# the steepest ramp: whoever is not on it is dropped half way up and slides if its legs cannot hold
			s.append({"k": "tp", "x": xc, "z": RAMP_Z0 + ramp_len(k) * 0.5})
			s.append(wait(40))
		s.append(head(0, -32767, ticks))
		s.append(wait(10))
	return s

static func course(name: String, x0: float) -> Array:
	match name:
		"figure8":
			return figure8(x0)
		"zigzag":
			return zigzag(x0)
		"steps":
			return steps(x0)
		"uturn":
			return uturn(x0)
		"ramps":
			return ramps(x0)
		_:
			return figure8(x0) + steps(x0) + zigzag(x0) + uturn(x0) + ramps(x0)
