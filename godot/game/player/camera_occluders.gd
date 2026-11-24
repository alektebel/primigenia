extends RefCounted
## Camera-only occluder proxies (docs/plans/creature-loop.md T4). The flora and rocks are MultiMesh batches with no physics, so the
## chase camera cannot ray-cast them. This is a cheap stand-in: each tall plant or rock becomes an upright elliptic cylinder
## (a tree is its trunk only, the crown is see-through; a shrub or rock is its bounding ellipse), kept in a uniform grid.
## `cast` is a sphere-cast along a segment (the sphere inflates the cylinders), pure maths, no scene nodes, no physics server.

const CELL := 12.0                 # m: grid cell edge
const MIN_TOP := 0.45              # m: an occluder lower than this above its ground cannot hide a creature
const TRUNK_R := 0.050             # trunk radius per metre of mesh scale (the trunk is 0.014..0.142 of a unit; 0.05 is its mean)
const TRUNK_H := 0.52              # the trunk's height in mesh units: above it the limbs and leaves begin
const ROCKS := ["boulder", "scree", "outcrop"]

# One row per occluder, 8 floats: x, z, inverse radius along local x, along local z, cos(yaw), sin(yaw), y bottom, y top.
var rows := PackedFloat32Array()
var grid := {}                     # Vector2i -> PackedInt32Array of row indices
var count := 0

## records: island_props.gd `records` ({id, variant, p, height, yaw, up}); props: the island_props node (for the mesh bounds and recipes).
func build(records: Array, props) -> void:
	rows.clear()
	grid.clear()
	count = 0
	var bounds := {}
	for item in records:
		var id: String = item.id
		var form: String = "rock" if id in ROCKS else String(props.recipe.get(id, {}).get("form", ""))
		if form != "tree" and form != "shrub" and form != "rock":
			continue
		var height: float = item.height
		if height < MIN_TOP and form != "rock":
			continue
		var key := [id, item.variant]
		if not bounds.has(key):
			bounds[key] = props.geometry(id, item.variant, false).get_aabb()
		var bb: AABB = bounds[key]
		var s: float = height / maxf(0.001, bb.end.y)      # the instance scale (island_props.gd batch)
		var p: Vector3 = item.p
		var rx: float
		var rz: float
		var y0: float
		var y1: float
		if form == "tree":
			rx = TRUNK_R * s
			rz = rx
			y0 = p.y
			y1 = p.y + TRUNK_H * s
		else:
			# the lumps are centred on the mesh origin: the footprint is the AABB's xz extent, scaled
			rx = maxf(0.2, 0.5 * bb.size.x * s * 0.85)
			rz = maxf(0.2, 0.5 * bb.size.z * s * 0.85)
			y0 = p.y + bb.position.y * s
			y1 = p.y + bb.end.y * s
		if y1 - p.y < MIN_TOP:
			continue
		var yaw: float = item.yaw
		_add(p.x, p.z, rx, rz, yaw, y0, y1)
	_index()

func _add(x: float, z: float, rx: float, rz: float, yaw: float, y0: float, y1: float) -> void:
	rows.append_array(PackedFloat32Array([x, z, 1.0 / rx, 1.0 / rz, cos(yaw), sin(yaw), y0, y1]))
	count += 1

func _index() -> void:
	for i in count:
		var o := i * 8
		var r := maxf(1.0 / rows[o + 2], 1.0 / rows[o + 3]) + 1.0       # the grid margin covers the sphere radius
		for cx in range(floori((rows[o] - r) / CELL), floori((rows[o] + r) / CELL) + 1):
			for cz in range(floori((rows[o + 1] - r) / CELL), floori((rows[o + 1] + r) / CELL) + 1):
				var k := Vector2i(cx, cz)
				if not grid.has(k):
					grid[k] = PackedInt32Array()
				grid[k].append(i)

## Distance along a -> b (0..1 of the segment) of the first contact of a sphere of `radius` swept from a to b with an occluder,
## or 1.0 when the way is clear. `skip` lets a start point inside a cylinder (the creature standing in a bush) pass that cylinder.
func cast(a: Vector3, b: Vector3, radius: float) -> float:
	var best := 1.0
	var lo := Vector2(minf(a.x, b.x) - radius, minf(a.z, b.z) - radius)
	var hi := Vector2(maxf(a.x, b.x) + radius, maxf(a.z, b.z) + radius)
	var d := b - a
	for cx in range(floori(lo.x / CELL), floori(hi.x / CELL) + 1):
		for cz in range(floori(lo.y / CELL), floori(hi.y / CELL) + 1):
			var cell = grid.get(Vector2i(cx, cz))
			if cell == null:
				continue
			for i in cell:
				var t := _hit(i * 8, a, d, radius)
				if t < best:
					best = t
	return best

# Segment a + d t, t in 0..1, against the inflated cylinder in row `o`. Returns the entry t, or 1 when it misses.
func _hit(o: int, a: Vector3, d: Vector3, radius: float) -> float:
	var y0 := rows[o + 6] - radius
	var y1 := rows[o + 7] + radius
	if maxf(a.y, a.y + d.y) < y0 or minf(a.y, a.y + d.y) > y1:
		return 1.0
	# into the ellipse's local frame, scaled so it is a circle of radius 1 (inflated by the sphere on both axes)
	var c := rows[o + 4]
	var s := rows[o + 5]
	var ix := 1.0 / (1.0 / rows[o + 2] + radius)
	var iz := 1.0 / (1.0 / rows[o + 3] + radius)
	var ox := a.x - rows[o]
	var oz := a.z - rows[o + 1]
	var px := (ox * c - oz * s) * ix
	var pz := (ox * s + oz * c) * iz
	var vx := (d.x * c - d.z * s) * ix
	var vz := (d.x * s + d.z * c) * iz
	var qa := vx * vx + vz * vz
	if qa < 1e-12:
		return 1.0
	var qb := 2.0 * (px * vx + pz * vz)
	var qc := px * px + pz * pz - 1.0
	if qc <= 0.0:
		return 1.0           # starts inside: the creature stands in or against it; that one is not a wall
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return 1.0
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	if t < 0.0 or t > 1.0:
		return 1.0
	var y := a.y + d.y * t
	if y < y0 or y > y1:
		return 1.0
	return t

## True when the point is inside an occluder's footprint and height (used by the test to ignore frames where the creature walked into one).
func contains(p: Vector3, radius: float = 0.0) -> bool:
	var cell = grid.get(Vector2i(floori(p.x / CELL), floori(p.z / CELL)))
	if cell == null:
		return false
	for i in cell:
		var o: int = i * 8
		if p.y < rows[o + 6] - radius or p.y > rows[o + 7] + radius:
			continue
		var ox := p.x - rows[o]
		var oz := p.z - rows[o + 1]
		var c := rows[o + 4]
		var s := rows[o + 5]
		var ix := 1.0 / (1.0 / rows[o + 2] + radius)
		var iz := 1.0 / (1.0 / rows[o + 3] + radius)
		var px := (ox * c - oz * s) * ix
		var pz := (ox * s + oz * c) * iz
		if px * px + pz * pz <= 1.0:
			return true
	return false
