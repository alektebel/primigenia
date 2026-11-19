extends RefCounted
## The hidden cave (G65, W18): the visual and the ground rule of the one walkable chamber.
##
## The C world defines it (core/src/stage_secrets.c, cp_stage_secrets_ground): a passage into the rock from the entrance
## plane, then a round chamber, where the walkable ground is flat at the entrance floor. The heightfield cannot hold a hollow,
## so this class mirrors that rule for the visual ground (creature feet, camera, pointer) and builds the interior as a closed
## mesh: floor, walls, ceiling, a rock mouth where the passage leaves the cliff, and a few cold lights. Keep adjust() in step
## with the C function: both use the same constants.

const LEAD := 4.0          # m before the entrance plane where the floor already follows the 0.30 trail slope
const BLEND := 3.0         # m over which the override fades into the heightfield
const TRAIL_SLOPE := 0.30
const CEILING := 4.4       # passage height above the floor
const DOME := 3.2          # extra height at the chamber centre

var on := false
var x := 0.0
var z := 0.0
var fx := 0.0
var fz := 1.0
var floor_h := 0.0
var half := 4.0
var length := 14.0
var radius := 10.0
var cx := 0.0
var cz := 0.0

## From state().cave (the C JSON): {enabled, x, z, fx, fz, floor, half, length, radius, chamber_x, chamber_z}.
static func from_state(c: Dictionary) -> RefCounted:
	var s = load("res://game/island/cave_site.gd").new()
	if not bool(c.get("enabled", false)):
		return s
	s.on = true
	s.x = float(c.x)
	s.z = float(c.z)
	s.fx = float(c.fx)
	s.fz = float(c.fz)
	s.floor_h = float(c.floor)
	s.half = float(c.half)
	s.length = float(c.length)
	s.radius = float(c.radius)
	s.cx = float(c.chamber_x)
	s.cz = float(c.chamber_z)
	return s

# Metres into the rock from the entrance plane (u) and sideways (v).
func frame(px: float, pz: float) -> Vector2:
	var dx := px - x
	var dz := pz - z
	return Vector2(-(dx * fx + dz * fz), -dx * fz + dz * fx)

func adjust(px: float, pz: float, h: float) -> float:
	if not on:
		return h
	var uv := frame(px, pz)
	var u := uv.x
	var v := uv.y
	var k := 0.0
	var fh := floor_h
	if u > -LEAD - BLEND and u < length + radius + 0.01:
		var wv := clampf((half - absf(v)) / 0.8, 0.0, 1.0)
		var wu := (u + LEAD + BLEND) / BLEND if u < -LEAD else 1.0
		k = wv * wu
		if u < 0.0:
			fh += TRAIL_SLOPE * u
	var d := Vector2(px - cx, pz - cz).length()
	var wd := clampf((radius - d) / 0.8, 0.0, 1.0)
	if wd > k:
		k = wd
		fh = floor_h
	return h + (fh - h) * k if k > 0.0 else h

# 0 outside, 1 in the passage, 2 in the chamber (same as cp_stage_in_cave).
func zone(px: float, pz: float) -> int:
	if not on:
		return 0
	if Vector2(px - cx, pz - cz).length() < radius:
		return 2
	var uv := frame(px, pz)
	if uv.x >= 0.0 and uv.x < length + radius and absf(uv.y) < half:
		return 1
	return 0

# Height of the roof above the floor at (px, pz): the passage arch, the chamber dome, or 1e9 outside the shell.
func roof_at(px: float, pz: float) -> float:
	if not on:
		return 1e9
	var d := Vector2(px - cx, pz - cz).length()
	if d < radius:
		return (CEILING + DOME) * sqrt(maxf(1.0 - (d / radius) * (d / radius), 0.0))
	var uv := frame(px, pz)
	if uv.x >= -3.0 and uv.x < length + radius * 0.6 and absf(uv.y) < half:
		return CEILING * sqrt(maxf(1.0 - (uv.y / half) * (uv.y / half), 0.0))
	return 1e9

func _world(u: float, v: float) -> Vector2:
	# inverse of frame(): u is along -f, v along (-fz, fx)
	return Vector2(x - fx * u - fz * v, z - fz * u + fx * v)

func _rock(seed_a: float, seed_b: float) -> float:
	return sin(seed_a * 1.7 + seed_b * 0.9) * 0.28 + sin(seed_a * 4.1 - seed_b * 2.3) * 0.12

# The interior as one node: an arched passage and a domed chamber (closed shell: floor, walls, ceiling), a flared rock mouth with boulders
# where the passage leaves the cliff, cold lights and glow patches on the chamber floor.
const ROCK_IN := Color(0.62, 0.55, 0.48)
const ROCK_MOUTH := Color(0.27, 0.24, 0.21)    # outdoors in full sun: the cliff rock
const ARCH := 12

func _floor_at(u: float) -> float:
	return floor_h + TRAIL_SLOPE * minf(u, 0.0)

# One cross-section of the passage: ARCH+1 points from the left floor edge over the roof to the right floor edge.
func _ring(u: float, scale: float, wobble: float) -> Array:
	var pts := []
	for i in ARCH + 1:
		var th := PI * float(i) / float(ARCH)
		var v := -cos(th) * half * scale
		var hh := sin(th) * CEILING * scale
		var n := 1.0 + wobble * _rock(u * 0.8 + 3.0, float(i)) if i > 0 and i < ARCH else 1.0
		pts.append(_p(u, v * n, _floor_at(u) + hh * n))
	return pts

func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "CaveInterior"
	parent.add_child(root)
	if not on:
		return root
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# --- passage: rings one metre apart; the first three flare into the rock mouth
	var u0 := -3.0
	var u1 := length + radius * 0.6
	var steps := int(u1 - u0)
	var prev: Array = []
	for i in steps + 1:
		var u := u0 + float(i)
		var flare := 1.0 + maxf(0.0, (-u - 0.0) * 0.12) if u < 0.0 else 1.0
		var ring := _ring(u, flare, 0.12 if u > 0.0 else 0.06)
		if not prev.is_empty():
			var col := ROCK_MOUTH if u < 4.0 else ROCK_IN
			for k in ARCH:
				_quad(st, prev[k], prev[k + 1], ring[k + 1], ring[k], col * (0.92 + 0.16 * absf(_rock(u, float(k)))))
			# floor
			_quad(st, prev[0], prev[ARCH], ring[ARCH], ring[0], (ROCK_MOUTH if u < 4.0 else ROCK_IN) * 1.05)
		prev = ring
	# --- chamber: a half-ellipsoid dome over a round floor, open toward the passage
	var centre := Vector3(cx, floor_h, cz)
	var hc := CEILING + DOME
	var open := asin(clampf(half / radius, 0.0, 0.99)) + 0.08
	var toward := atan2(-fz, -fx) + PI
	var segs := 36
	var rings := 6
	for j in rings:
		var e0 := (PI * 0.5) * float(j) / float(rings)
		var e1 := (PI * 0.5) * float(j + 1) / float(rings)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var mid := absf(angle_difference((a0 + a1) * 0.5, toward))
			if mid < open and j < 3:
				continue    # the passage enters here
			var r0 := radius * (1.0 + 0.05 * _rock(a0 * 4.0, float(j)))
			var r1 := radius * (1.0 + 0.05 * _rock(a1 * 4.0, float(j)))
			var q := []
			for ee in [[e0, a0, r0], [e0, a1, r1], [e1, a1, r1], [e1, a0, r0]]:
				q.append(centre + Vector3(cos(ee[1]) * cos(ee[0]) * ee[2], sin(ee[0]) * hc * (1.0 + 0.04 * _rock(ee[1] * 3.0, 1.0)), sin(ee[1]) * cos(ee[0]) * ee[2]))
			_quad(st, q[0], q[1], q[2], q[3], ROCK_IN * (0.85 + 0.2 * _rock(a0 * 3.0, float(j))))
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		_tri(st, centre, centre + Vector3(cos(a1), 0, sin(a1)) * radius, centre + Vector3(cos(a0), 0, sin(a0)) * radius, ROCK_IN * 1.1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.name = "Shell"
	root.add_child(mi)
	# the portal: a dark fill across the arch at the entrance plane, visible only from outside (it hides the cliff face that the
	# heightfield still has inside the opening; the player walks through it and, from inside, it is culled)
	var portal := SurfaceTool.new()
	portal.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pr := _ring(0.0, 1.0, 0.0)
	var pc := _p(0.0, 0.0, _floor_at(0.0) + CEILING * 0.45)
	for k in ARCH:
		_tri(portal, pc, pr[k + 1], pr[k], Color(0.02, 0.02, 0.03))
	portal.generate_normals()
	var pmi := MeshInstance3D.new()
	pmi.mesh = portal.commit()
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.vertex_color_use_as_albedo = true
	pmat.cull_mode = BaseMaterial3D.CULL_BACK
	pmi.material_override = pmat
	pmi.name = "Portal"
	root.add_child(pmi)
	# cold lights: dark inside, a faint blue-green glow from the chamber (the Acechalunas' country)
	for spec in [[Vector3(cx, floor_h + 3.2, cz), Color(0.5, 0.85, 1.0), 3.2, radius * 2.0], [_light_pos(length * 0.45), Color(0.55, 0.7, 0.9), 1.6, 12.0], [_light_pos(2.0), Color(0.6, 0.75, 0.95), 1.0, 8.0]]:
		var l := OmniLight3D.new()
		l.position = spec[0]
		l.light_color = spec[1]
		l.light_energy = spec[2]
		l.omni_range = spec[3]
		l.shadow_enabled = false
		root.add_child(l)
	# glow patches on the chamber floor (the ventral photophores of the sleepers)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.18, 0.5, 0.48)
	glow.emission_enabled = true
	glow.emission = Color(0.3, 0.95, 0.85)
	glow.emission_energy_multiplier = 1.1
	for k in 9:
		var a := TAU * float(k) / 9.0 + 0.3
		var rr := radius * (0.45 + 0.4 * fmod(float(k) * 0.37, 1.0))
		var m := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.22 + 0.1 * fmod(float(k) * 0.61, 1.0)
		sp.height = sp.radius * 0.7
		m.mesh = sp
		m.material_override = glow
		m.position = Vector3(cx + cos(a) * rr, floor_h + 0.05, cz + sin(a) * rr)
		root.add_child(m)
	return root

func _light_pos(u: float) -> Vector3:
	var p := _world(u, 0.0)
	return Vector3(p.x, floor_h + 2.6, p.y)

func _ceiling(u: float) -> float:
	# an arch at the mouth: lower toward the plane, full height after 3 m
	return CEILING if u > 1.0 else lerpf(CEILING * 0.72, CEILING, clampf((u + 2.0) / 3.0, 0.0, 1.0))

func _p(u: float, v: float, h: float) -> Vector3:
	var w := _world(u, v)
	return Vector3(w.x, h, w.y)

func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for p in [a, b, c]:
		st.set_color(col)
		st.add_vertex(p)

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)
