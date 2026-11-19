class_name CreatureGeo
extends RefCounted
## Small CPU geometry buffer that reproduces the three.js primitives used by
## web/creature/rig.js (SphereGeometry, CylinderGeometry, ConeGeometry,
## OctahedronGeometry, the swept tubes and CatmullRomCurve3), so part shapes
## match vertex for vertex. Indices are kept in three.js winding
## (counter-clockwise front faces); to_mesh() flips them to Godot's clockwise
## convention. `skin` is the per-vertex vec4 that the skin shader reads from
## CUSTOM0: xyz = body-relative pattern coordinate, w = belly/back weight.

var pos := PackedVector3Array()
var nrm := PackedVector3Array()
var idx := PackedInt32Array()
var skin := PackedFloat32Array()
var uv := PackedVector2Array()      ## optional: body tube (arc along spine, arc around), keratin (along, 0)
var uv2 := PackedVector2Array()     ## optional: body tube (ring radius, spine parameter 0 tail .. 1 head)

const X0 := Vector3(1, 0, 0)
const Y := Vector3(0, 1, 0)


func clone() -> CreatureGeo:
	var g := CreatureGeo.new()
	g.pos = pos.duplicate()
	g.nrm = nrm.duplicate()
	g.idx = idx.duplicate()
	g.skin = skin.duplicate()
	g.uv = uv.duplicate()
	g.uv2 = uv2.duplicate()
	return g


func vertex_count() -> int:
	return pos.size()


# ---------------------------------------------------------------- transforms

func apply_transform(xf: Transform3D) -> CreatureGeo:
	var nb := xf.basis.inverse().transposed()
	for i in pos.size():
		pos[i] = xf * pos[i]
	for i in nrm.size():
		nrm[i] = (nb * nrm[i]).normalized()
	if xf.basis.determinant() < 0:
		flip_winding()
	return self


func scale(sx: float, sy: float, sz: float) -> CreatureGeo:
	return apply_transform(Transform3D(Basis.from_scale(Vector3(sx, sy, sz)), Vector3.ZERO))


func scale_all(s: float) -> CreatureGeo:
	return scale(s, s, s)


func translate(x: float, y: float, z: float) -> CreatureGeo:
	var o := Vector3(x, y, z)
	for i in pos.size():
		pos[i] += o
	return self


func rotate_x(a: float) -> CreatureGeo:
	return apply_transform(Transform3D(Basis(X0, a), Vector3.ZERO))


func rotate_y(a: float) -> CreatureGeo:
	return apply_transform(Transform3D(Basis(Y, a), Vector3.ZERO))


func rotate_z(a: float) -> CreatureGeo:
	return apply_transform(Transform3D(Basis(Vector3(0, 0, 1), a), Vector3.ZERO))


func flip_winding() -> void:
	for i in range(0, idx.size(), 3):
		var t := idx[i + 1]
		idx[i + 1] = idx[i + 2]
		idx[i + 2] = t


## three.js computeVertexNormals: area-weighted sum over indexed faces.
func compute_vertex_normals() -> CreatureGeo:
	nrm = PackedVector3Array()
	nrm.resize(pos.size())
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var n := (pos[c] - pos[b]).cross(pos[a] - pos[b])
		nrm[a] += n
		nrm[b] += n
		nrm[c] += n
	for i in nrm.size():
		nrm[i] = nrm[i].normalized() if nrm[i].length_squared() > 0 else Vector3.UP
	return self


## rig.js skinify(): pattern coordinate = local position + mount offset;
## w = given weight, or normal.y * .9 when weight is null.
func skinify(off: Vector3, d = null) -> CreatureGeo:
	skin = PackedFloat32Array()
	skin.resize(pos.size() * 4)
	for i in pos.size():
		var p := pos[i] + off
		skin[i * 4] = p.x
		skin[i * 4 + 1] = p.y
		skin[i * 4 + 2] = p.z
		skin[i * 4 + 3] = (nrm[i].y * .9) if d == null else float(d)
	return self


## Keratin parts: UV.x = position along the principal axis of the mesh, 0 at the wide root, 1 at the tip.
## Power iteration on the covariance (a few ms for the whole creature), nothing per creature is stored.
func compute_along() -> void:
	var n := pos.size()
	if n < 4:
		return
	var c := Vector3.ZERO
	for p in pos:
		c += p
	c /= n
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for p in pos:
		var d := p - c
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z
	var ax := Vector3(1, .7, .4).normalized()
	for it in 6:
		ax = Vector3(xx * ax.x + xy * ax.y + xz * ax.z, xy * ax.x + yy * ax.y + yz * ax.z, xz * ax.x + yz * ax.y + zz * ax.z).normalized()
	var t := PackedFloat32Array()
	t.resize(n)
	var lo := 1e9
	var hi := -1e9
	for i in n:
		var v := (pos[i] - c).dot(ax)
		t[i] = v
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, 1e-6)
	# The root is the end with the larger cross-section.
	var r_lo := 0.0
	var r_hi := 0.0
	var n_lo := 0
	var n_hi := 0
	for i in n:
		var f := (t[i] - lo) / span
		var d := pos[i] - c
		var rad := (d - ax * d.dot(ax)).length()
		if f < .3:
			r_lo += rad
			n_lo += 1
		elif f > .7:
			r_hi += rad
			n_hi += 1
	var flip := (r_hi / maxf(n_hi, 1)) > (r_lo / maxf(n_lo, 1))
	uv.resize(n)
	for i in n:
		var f := (t[i] - lo) / span
		uv[i] = Vector2(1.0 - f if flip else f, 0.0)


## Iris meshes: UV = coordinates in the plane of the disc, scaled to [-1, 1] at the rim, +Y of the part up the disc.
## The disc plane is the one of smallest variance (power iteration on tr(C) I - C).
func compute_disc() -> void:
	var n := pos.size()
	if n < 4:
		return
	var c := Vector3.ZERO
	for p in pos:
		c += p
	c /= n
	var xx := 0.0
	var xy := 0.0
	var xz := 0.0
	var yy := 0.0
	var yz := 0.0
	var zz := 0.0
	for p in pos:
		var d := p - c
		xx += d.x * d.x
		xy += d.x * d.y
		xz += d.x * d.z
		yy += d.y * d.y
		yz += d.y * d.z
		zz += d.z * d.z
	var tr := xx + yy + zz
	var ax := Vector3(.3, .5, 1).normalized()
	for it in 8:
		ax = Vector3((tr - xx) * ax.x - xy * ax.y - xz * ax.z, -xy * ax.x + (tr - yy) * ax.y - yz * ax.z, -xz * ax.x - yz * ax.y + (tr - zz) * ax.z).normalized()
	var up := Y - ax * Y.dot(ax)
	if up.length_squared() < 1e-4:
		up = X0 - ax * X0.dot(ax)
	up = up.normalized()
	var right := up.cross(ax).normalized()
	var rmax := 1e-6
	for p in pos:
		var d := p - c
		rmax = maxf(rmax, Vector2(d.dot(right), d.dot(up)).length())
	uv.resize(n)
	for i in n:
		var d := pos[i] - c
		uv[i] = Vector2(d.dot(right), d.dot(up)) / rmax


func with_index_subset(from: int) -> CreatureGeo:
	var g := clone()
	g.idx = idx.slice(from)
	return g


func append(other: CreatureGeo) -> void:
	var base := pos.size()
	pos.append_array(other.pos)
	nrm.append_array(other.nrm)
	skin.append_array(other.skin)
	for i in other.idx:
		idx.append(base + i)
	uv.append_array(other.uv)
	uv2.append_array(other.uv2)


func aabb() -> AABB:
	if pos.is_empty():
		return AABB()
	var box := AABB(pos[0], Vector3.ZERO)
	for p in pos:
		box = box.expand(p)
	return box


func all_finite() -> bool:
	for p in pos:
		if not (is_finite(p.x) and is_finite(p.y) and is_finite(p.z)):
			return false
	for n in nrm:
		if not (is_finite(n.x) and is_finite(n.y) and is_finite(n.z)):
			return false
	for i in idx:
		if i < 0 or i >= pos.size():
			return false
	return true


## Godot surface arrays. Bones/weights are optional (skinned body only).
func to_arrays(bones := PackedInt32Array(), weights := PackedFloat32Array()) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos
	arrays[Mesh.ARRAY_NORMAL] = nrm
	var gi := idx.duplicate()
	for i in range(0, gi.size(), 3):
		var t := gi[i + 1]
		gi[i + 1] = gi[i + 2]
		gi[i + 2] = t
	arrays[Mesh.ARRAY_INDEX] = gi
	var sk := skin
	if sk.size() != pos.size() * 4:
		sk = PackedFloat32Array()
		sk.resize(pos.size() * 4)
		for i in pos.size():
			sk[i * 4] = pos[i].x
			sk[i * 4 + 1] = pos[i].y
			sk[i * 4 + 2] = pos[i].z
			sk[i * 4 + 3] = nrm[i].y * .9
	arrays[Mesh.ARRAY_CUSTOM0] = sk
	if uv.size() == pos.size():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	if uv2.size() == pos.size():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
	if not bones.is_empty():
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	return arrays


const SURFACE_FLAGS := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT


func to_mesh() -> ArrayMesh:
	var m := ArrayMesh.new()
	if idx.is_empty():
		return m
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, to_arrays(), [], {}, SURFACE_FLAGS)
	return m


# ---------------------------------------------------------------- primitives

## THREE.SphereGeometry(r, ws, hs, phiStart, phiLength, thetaStart, thetaLength)
static func sphere(r: float, ws := 32, hs := 16, phi_start := 0.0, phi_len := TAU, theta_start := 0.0, theta_len := PI) -> CreatureGeo:
	var g := CreatureGeo.new()
	var theta_end: float = min(theta_start + theta_len, PI)
	var grid := []
	for iy in hs + 1:
		var row := []
		var v := float(iy) / hs
		for ix in ws + 1:
			var u := float(ix) / ws
			var p := Vector3(-r * cos(phi_start + u * phi_len) * sin(theta_start + v * theta_len),
				r * cos(theta_start + v * theta_len),
				r * sin(phi_start + u * phi_len) * sin(theta_start + v * theta_len))
			g.pos.append(p)
			g.nrm.append(p.normalized() if p.length_squared() > 0 else Vector3.UP)
			row.append(g.pos.size() - 1)
		grid.append(row)
	for iy in hs:
		for ix in ws:
			var a: int = grid[iy][ix + 1]
			var b: int = grid[iy][ix]
			var c: int = grid[iy + 1][ix]
			var d: int = grid[iy + 1][ix + 1]
			if iy != 0 or theta_start > 0:
				g.idx.append_array([a, b, d])
			if iy != hs - 1 or theta_end < PI:
				g.idx.append_array([b, c, d])
	return g


## rig.js ell(): unit sphere (22x16) scaled, then translated. Ellipsoid
## normals are analytic (three recomputes them from faces; same shape).
static func ell(sx: float, sy: float, sz: float, x := 0.0, y := 0.0, z := 0.0) -> CreatureGeo:
	var g := sphere(1, 22, 16)
	g.scale(sx, sy, sz)
	g.translate(x, y, z)
	return g


## THREE.CylinderGeometry(rTop, rBottom, h, radial, heightSegs), capped.
static func cylinder(r_top: float, r_bot: float, h: float, radial := 32, hseg := 1) -> CreatureGeo:
	var g := CreatureGeo.new()
	var half := h / 2.0
	var slope := (r_bot - r_top) / h
	var rows := []
	for y in hseg + 1:
		var row := []
		var v := float(y) / hseg
		var radius := v * (r_bot - r_top) + r_top
		for x in radial + 1:
			var th := float(x) / radial * TAU
			g.pos.append(Vector3(radius * sin(th), -v * h + half, radius * cos(th)))
			g.nrm.append(Vector3(sin(th), slope, cos(th)).normalized())
			row.append(g.pos.size() - 1)
		rows.append(row)
	for x in radial:
		for y in hseg:
			var a: int = rows[y][x]
			var b: int = rows[y + 1][x]
			var c: int = rows[y + 1][x + 1]
			var d: int = rows[y][x + 1]
			g.idx.append_array([a, b, d, b, c, d])
	for top in [true, false]:
		var radius := r_top if top else r_bot
		if radius <= 0:
			continue
		var sgn := 1.0 if top else -1.0
		var center_start := g.pos.size()
		for x in radial:
			g.pos.append(Vector3(0, half * sgn, 0))
			g.nrm.append(Vector3(0, sgn, 0))
		var center_end := g.pos.size()
		for x in radial + 1:
			var th := float(x) / radial * TAU
			g.pos.append(Vector3(radius * sin(th), half * sgn, radius * cos(th)))
			g.nrm.append(Vector3(0, sgn, 0))
		for x in radial:
			var c := center_start + x
			var i := center_end + x
			if top:
				g.idx.append_array([i, i + 1, c])
			else:
				g.idx.append_array([i + 1, i, c])
	return g


static func cone(r: float, h: float, radial := 32) -> CreatureGeo:
	return cylinder(0, r, h, radial)


## THREE.OctahedronGeometry(1, 0): flat-shaded, non-indexed.
static func octahedron() -> CreatureGeo:
	var v := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, -1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var f := [0, 2, 4, 0, 4, 3, 0, 3, 5, 0, 5, 2, 1, 2, 5, 1, 5, 3, 1, 3, 4, 1, 4, 2]
	var g := CreatureGeo.new()
	for i in f.size():
		g.pos.append(v[f[i]])
		g.idx.append(i)
	g.flat_normals()
	return g


func flat_normals() -> void:
	nrm = PackedVector3Array()
	nrm.resize(pos.size())
	for i in range(0, idx.size(), 3):
		var a := idx[i]
		var b := idx[i + 1]
		var c := idx[i + 2]
		var n := (pos[c] - pos[b]).cross(pos[a] - pos[b]).normalized()
		nrm[a] = n
		nrm[b] = n
		nrm[c] = n


# ---------------------------------------------------------------- tubes

## rig.js allocTube(): n rings of rad vertices, no caps.
static func alloc_tube(n: int, rad: int) -> CreatureGeo:
	var g := CreatureGeo.new()
	g.pos.resize(n * rad)
	g.nrm.resize(n * rad)
	for i in n - 1:
		for j in rad:
			var a := i * rad + j
			var b := i * rad + (j + 1) % rad
			var c := a + rad
			var d := b + rad
			g.idx.append_array([a, c, b, b, c, d])
	return g


## rig.js fillTube(). `ref` = null uses the X0 frame (body); `shape` squashes
## the belly (.9) and lifts the back (1.06). `frames` (optional Array of
## Dictionaries) receives {s,u,t,dr} per ring.
func fill_tube(pts: Array, rad: Array, rn: int, ref, shape: bool, frames = null) -> void:
	var n := pts.size()
	for i in n:
		var a: Vector3 = pts[max(i - 1, 0)]
		var b: Vector3 = pts[min(i + 1, n - 1)]
		var t := (b - a).normalized()
		var s: Vector3
		var u: Vector3
		if ref != null:
			s = (ref as Vector3).cross(t).normalized()
			u = t.cross(s)
		else:
			u = t.cross(X0).normalized()
			s = u.cross(t)
		var r: float = rad[i]
		var p: Vector3 = pts[i]
		var dist := b.distance_to(a)
		var dr := clampf((float(rad[min(i + 1, n - 1)]) - float(rad[max(i - 1, 0)])) / (dist if dist != 0.0 else 1.0), -4, 4)
		if frames != null:
			frames[i] = {"s": s, "u": u, "t": t, "dr": dr}
		for j in rn:
			var an := float(j) / rn * 6.28318
			var cx := sin(an)
			var cy := cos(an)
			var wy := (0.9 if cy < 0 else 1.06) if shape else 1.0
			var k := i * rn + j
			pos[k] = p + (s * cx + u * cy * wy) * r
			nrm[k] = (s * cx + u * cy - t * dr).normalized()


static func curve_tube(fn: Callable, r0: float, n: int, rn: int, ref) -> CreatureGeo:
	var pts := []
	var rad := []
	for i in n:
		var u := float(i) / (n - 1)
		pts.append(fn.call(u))
		rad.append(max(.004, r0 * pow(1 - u, .85)))
	var g := alloc_tube(n, rn)
	g.fill_tube(pts, rad, rn, ref, false)
	return g


## rig.js sweep(): centripetal Catmull-Rom through `points`, radii lerped.
static func sweep(points: Array, radii: Array) -> CreatureGeo:
	var vpts := []
	for p in points:
		vpts.append(p if p is Vector3 else Vector3(p[0], p[1], p[2]))
	var ps := []
	var rs := []
	var n := 26
	for i in n:
		var u := float(i) / (n - 1)
		var k := u * (radii.size() - 1)
		var j: int = min(int(k), radii.size() - 2)
		ps.append(catmull_point(vpts, u, false, "centripetal", .5))
		rs.append(max(.002, lerpf(radii[j], radii[j + 1], k - j)))
	var d: Vector3 = ps[n - 1] - ps[0]
	var ref := Y if abs(d.x) > abs(d.y) + abs(d.z) else X0
	var g := alloc_tube(n, 12)
	g.fill_tube(ps, rs, 12, ref, false)
	return g


## THREE.CatmullRomCurve3.getPoint(t) (parameter, not arc length).
static func catmull_point(points: Array, t: float, closed: bool, curve_type: String, tension: float) -> Vector3:
	var l := points.size()
	var p := (l if closed else l - 1) * t
	var ip := int(floor(p))
	var weight := p - ip
	if closed:
		ip += 0 if ip > 0 else (int(floor(abs(ip) / float(l))) + 1) * l
	elif weight == 0 and ip == l - 1:
		ip = l - 2
		weight = 1
	var p0: Vector3
	var p3: Vector3
	if closed or ip > 0:
		p0 = points[(ip - 1) % l]
	else:
		p0 = points[0] - points[1] + points[0]
	var p1: Vector3 = points[ip % l]
	var p2: Vector3 = points[(ip + 1) % l]
	if closed or ip + 2 < l:
		p3 = points[(ip + 2) % l]
	else:
		p3 = points[l - 1] - points[l - 2] + points[l - 1]
	var out := Vector3()
	if curve_type == "centripetal" or curve_type == "chordal":
		var pw := .25 if curve_type == "centripetal" else .5
		var dt0 := pow(p0.distance_squared_to(p1), pw)
		var dt1 := pow(p1.distance_squared_to(p2), pw)
		var dt2 := pow(p2.distance_squared_to(p3), pw)
		if dt1 < 1e-4:
			dt1 = 1.0
		if dt0 < 1e-4:
			dt0 = dt1
		if dt2 < 1e-4:
			dt2 = dt1
		for c in 3:
			out[c] = _nonuniform(p0[c], p1[c], p2[c], p3[c], dt0, dt1, dt2, weight)
	else:
		for c in 3:
			out[c] = _cubic(p1[c], p2[c], tension * (p2[c] - p0[c]), tension * (p3[c] - p1[c]), weight)
	return out


static func _cubic(x0: float, x1: float, t0: float, t1: float, t: float) -> float:
	var c2 := -3 * x0 + 3 * x1 - 2 * t0 - t1
	var c3 := 2 * x0 - 2 * x1 + t0 + t1
	return x0 + t0 * t + c2 * t * t + c3 * t * t * t


static func _nonuniform(x0: float, x1: float, x2: float, x3: float, dt0: float, dt1: float, dt2: float, t: float) -> float:
	var t1 := (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
	var t2 := (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
	return _cubic(x1, x2, t1 * dt1, t2 * dt1, t)
