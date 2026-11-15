extends "../creature_view.gd"
## Temporary stand-in for the real creature builder: capsule spine + markers for parts.

const CAT_COLOR := {"mouths": Color("e0623f"), "senses": Color("6fd3ff"), "legs": Color("9fd45c"), "arms": Color("c9892b"),
	"weapons": Color("ff7a5c"), "wings": Color("b58cff"), "fins": Color("4fc3b0"), "digging_claws": Color("a98a62"), "details": Color("ffc04a")}

var genome: Dictionary = {}
var parts_db: RefCounted
var _body := Node3D.new()
var _markers := Node3D.new()
var _handles := Node3D.new()
var _sel := -1
var _playing := false
var _time := 0.0
var _skin_mat := StandardMaterial3D.new()
var _anchors: Array = []   # per part: [{pos, normal, up}] (first entry is the +X side)
var _pts: Array = []       # Vector3 per node
var _rad: Array = []
var _cum: Array = []       # cumulative arc length

func _init(db: RefCounted = null) -> void:
	parts_db = db
	add_child(_body); add_child(_markers); add_child(_handles)
	_skin_mat.roughness = .6
	var ground := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 9.0; cm.bottom_radius = 9.0; cm.height = .05
	ground.mesh = cm
	ground.position = Vector3(0, -.03, 1)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("2b3a2f"); gm.roughness = 1.0
	ground.material_override = gm
	add_child(ground)

# ------------------------------------------------------------------ interface
func set_genome(doc: Dictionary) -> void:
	genome = doc.duplicate(true)
	_rebuild()
	genome_applied.emit()

func get_genome() -> Dictionary:
	return genome.duplicate(true)

func attach_part(type: String, t: float, ang: float, params: Dictionary = {}) -> int:
	var p := {"type": type, "t": t, "ang": ang}
	if parts_db and parts_db.has(type):
		p = parts_db.defaults(type)
		p["t"] = t; p["ang"] = ang
	for k in params:
		p[k] = params[k]
	genome["parts"].append(p)
	_rebuild()
	return genome["parts"].size() - 1

func remove_part(index: int) -> void:
	if index >= 0 and index < genome["parts"].size():
		genome["parts"].remove_at(index)
		if _sel == index:
			_sel = -1
		_rebuild()

func update_part(index: int, fields: Dictionary) -> void:
	for k in fields:
		genome["parts"][index][k] = fields[k]
	_rebuild()

func spine_node_positions() -> PackedVector3Array:
	return PackedVector3Array(_pts)

func hit_body(origin: Vector3, dir: Vector3) -> Dictionary:
	if _pts.size() < 2:
		return {}
	dir = dir.normalized()
	var s := 0.0
	var prev := 0.0
	var found := -1.0
	var lo := 0.0
	while s < 120.0:
		if _sdf(origin + dir * s) <= 0.0:
			found = s; lo = prev
			break
		prev = s
		s += .06
	if found < 0.0:
		return {}
	var hi := found
	for _i in 12:
		var mid := (lo + hi) * .5
		if _sdf(origin + dir * mid) <= 0.0: hi = mid
		else: lo = mid
	var p := origin + dir * hi
	var near := _nearest(p)
	var up: Vector3 = near["up"]
	var local: Vector3 = p - near["pos"]
	return {"t": near["t"], "ang": atan2(local.x, local.dot(up)), "point": p}

func hit_part(origin: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in _anchors.size():
		for a in _anchors[i]:
			var r: float = a["radius"]
			var d := _ray_sphere(origin, dir, a["pos"], r)
			if d >= 0.0 and d < best_d:
				best_d = d; best = i
	return best

func hit_node(origin: Vector3, dir: Vector3) -> int:
	var best := -1
	var best_d := INF
	for i in _pts.size():
		var d := _ray_sphere(origin, dir, _pts[i], .2)
		if d >= 0.0 and d < best_d:
			best_d = d; best = i
	return best

func part_anchor(index: int) -> Dictionary:
	if index < 0 or index >= _anchors.size():
		return {}
	return _anchors[index][0]

func set_selection(index: int) -> void:
	_sel = index
	_rebuild_markers()

func set_spine_visible(on: bool) -> void:
	_handles.visible = on

func set_playing(on: bool) -> void:
	_playing = on
	if not on:
		_body.position = Vector3.ZERO
		_markers.position = Vector3.ZERO

func _process(dt: float) -> void:
	if _playing:
		_time += dt
		var bob := sin(_time * 6.0) * .06
		_body.position.y = bob
		_markers.position.y = bob

# ------------------------------------------------------------------ geometry
static func _ray_sphere(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	d = d.normalized()
	var oc := o - c
	var b := oc.dot(d)
	var disc := b * b - (oc.dot(oc) - r * r)
	if disc < 0.0:
		return -1.0
	var s := -b - sqrt(disc)
	return s if s >= 0.0 else -1.0

func _frame(i: int, u: float) -> Dictionary:
	# position/up/radius on segment i at fraction u
	var a: Vector3 = _pts[i]
	var b: Vector3 = _pts[i + 1]
	var tan := (b - a).normalized()
	return {"pos": a.lerp(b, u), "up": Vector3(0, tan.z, -tan.y), "r": lerpf(_rad[i], _rad[i + 1], u), "tan": tan}

func _sdf(p: Vector3) -> float:
	return _nearest(p)["d"]

func _nearest(p: Vector3) -> Dictionary:
	var best := {"d": INF}
	var total: float = _cum[-1]
	for i in _pts.size() - 1:
		var a: Vector3 = _pts[i]
		var ab: Vector3 = _pts[i + 1] - a
		var u := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var f := _frame(i, u)
		var d: float = p.distance_to(f["pos"]) - f["r"]
		if d < best["d"]:
			best = {"d": d, "pos": f["pos"], "up": f["up"], "r": f["r"], "tan": f["tan"],
				"t": (_cum[i] + u * ab.length()) / total}
	return best

func frame_at(t: float) -> Dictionary:
	var total: float = _cum[-1]
	var s := clampf(t, 0.0, 1.0) * total
	var i := 0
	while i < _pts.size() - 2 and _cum[i + 1] < s:
		i += 1
	var seg: float = _cum[i + 1] - _cum[i]
	return _frame(i, clampf((s - _cum[i]) / maxf(seg, 1e-6), 0.0, 1.0))

func _rebuild() -> void:
	_pts.clear(); _rad.clear(); _cum.clear()
	var acc := 0.0
	for i in genome["nodes"].size():
		var n: Dictionary = genome["nodes"][i]
		var v := Vector3(0, n["y"], n["z"])
		if i > 0:
			acc += v.distance_to(_pts[-1])
		_pts.append(v); _rad.append(n["r"]); _cum.append(acc)
	var s: Dictionary = genome["skin"]
	_skin_mat.albedo_color = Color(s["cA"])
	_skin_mat.metallic_specular = .3 + s["wet"] * .5
	for c in _body.get_children():
		c.queue_free()
	for c in _handles.get_children():
		c.queue_free()
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("ffc04a"); hm.no_depth_test = true; hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in _pts.size():
		var sp := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = _rad[i]; sm.height = _rad[i] * 2.0
		sp.mesh = sm; sp.position = _pts[i]; sp.material_override = _skin_mat
		_body.add_child(sp)
		var h := MeshInstance3D.new()
		var hmsh := SphereMesh.new()
		hmsh.radius = .12; hmsh.height = .24
		h.mesh = hmsh; h.position = _pts[i]; h.material_override = hm
		_handles.add_child(h)
		if i < _pts.size() - 1:
			var cy := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var seg: Vector3 = _pts[i + 1] - _pts[i]
			cm.top_radius = _rad[i + 1]; cm.bottom_radius = _rad[i]; cm.height = seg.length()
			cy.mesh = cm; cy.material_override = _skin_mat
			cy.position = (_pts[i] + _pts[i + 1]) * .5
			cy.basis = Basis(Quaternion(Vector3.UP, seg.normalized()))
			_body.add_child(cy)
	_rebuild_markers()

func _rebuild_markers() -> void:
	for c in _markers.get_children():
		c.queue_free()
	_anchors.clear()
	for i in genome["parts"].size():
		var p: Dictionary = genome["parts"][i]
		var cat: String = parts_db.by_id[p["type"]]["category"] if parts_db and parts_db.has(p["type"]) else "details"
		var col: Color = CAT_COLOR.get(cat, Color.WHITE)
		var f := frame_at(p["t"])
		var sides := [1.0]
		if absf(sin(p["ang"])) >= .14 or (parts_db and parts_db.is_lateral(p["type"])):
			sides = [1.0, -1.0]
		var list: Array = []
		for sg in sides:
			var dir: Vector3 = f["up"] * cos(p["ang"]) + Vector3(sg, 0, 0) * sin(p["ang"])
			var base: Vector3 = f["pos"] + dir * f["r"]
			var size: float = p.get("size", p.get("w", .3) * 2.0)
			var length: float = p.get("len", .4 * size) if not p.has("f") else 1.1
			var tip := base + dir * (.15 + length * .5)
			if p.has("f"):
				tip = base + Vector3(sg * p["f"][0], p["f"][1], p["f"][2])
				tip.y = maxf(tip.y, 0.0)
			var mat := StandardMaterial3D.new()
			mat.albedo_color = col.lightened(.35) if i == _sel else col
			if i == _sel:
				mat.emission_enabled = true; mat.emission = Color("ffc04a"); mat.emission_energy_multiplier = .6
			var stick := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			var seg := tip - base
			cm.top_radius = .02; cm.bottom_radius = .06 * maxf(size, .5); cm.height = maxf(seg.length(), .05)
			stick.mesh = cm; stick.material_override = mat
			stick.position = (base + tip) * .5
			stick.basis = Basis(Quaternion(Vector3.UP, seg.normalized() if seg.length() > .001 else Vector3.UP))
			_markers.add_child(stick)
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = .12 * maxf(size, .6); sm.height = sm.radius * 2.0
			ball.mesh = sm; ball.material_override = mat; ball.position = base
			_markers.add_child(ball)
			list.append({"pos": base, "normal": dir, "up": f["up"], "radius": maxf(.2, sm.radius * 1.4)})
		_anchors.append(list)
