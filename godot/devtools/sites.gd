extends RefCounted
## D2 sites and bookmarks. `for_island` is pure and deterministic for a seed (ids are stable slugs).
## Sites: {id, name, kind, pos: Vector3 (x, ground y, z), hidden, source}. Hidden ones (dens, shards, fossils of
## later stages) show only after the console's `reveal`.

const MAT_SAND := 4

var list: Array = []
var bookmarks: Array = []     # [{name, pos: [x, y, z], camera: {}}], persisted per seed
var seed_id := 1
const TestIsolation := preload("res://devtools/test_isolation.gd")
var bookmark_dir := TestIsolation.user("bookmarks")

static func _site(id: String, name: String, kind: String, x: float, z: float, data, source: String, hidden := false) -> Dictionary:
	return {"id": id, "name": name, "kind": kind, "pos": Vector3(x, data.ground(x, z), z), "hidden": hidden, "source": source}

## data: TerrainData, entry_params: the terrain params dictionary, setup: CporeWorld.get_setup() dictionary.
static func for_island(data, entry_params: Dictionary, setup: Dictionary) -> Array:
	var out: Array = []
	var nest: Vector2 = setup.nest
	out.append(_site("nest", "nest", "nest", nest.x, nest.y, data, "setup"))
	var i := 1
	for w in setup.wild:
		out.append(_site("home-%d" % i, "garfio home" if i == 1 else "wild home %d" % i, "den", w.home_x, w.home_z, data, "setup"))
		i += 1
	var n := 1
	for c in data.caves:
		var p: Vector3 = c.position
		var nm := "waterfall cave" if bool(c.get("waterfall", false)) else "cave %d" % n
		out.append(_site("cave-%d" % n, nm, "cave", p.x, p.z, data, "caves"))
		n += 1
	var v: Vector4 = data.volcano
	if v.z > 0.0:
		out.append(_site("volcano", "volcano", "volcano", v.x, v.y, data, "volcano"))
		out.append(_site("crater", "crater", "crater", v.x + v.w, v.y, data, "volcano"))
	out.append(_site("lake", "lake", "lake", float(entry_params.get("lake_x_m", 0.0)), float(entry_params.get("lake_y_m", 0.0)), data, "params"))
	var ring := (float(entry_params.get("ring_inner_m", 0.0)) + float(entry_params.get("ring_outer_m", 0.0))) * 0.5
	for k in ["pass", "col"]:
		var d := Vector2(float(entry_params.get(k + "_x", 0.0)), float(entry_params.get(k + "_y", 0.0)))
		d = d.normalized() if d.length() > 0.0 else Vector2(1, 0)
		out.append(_site(k, k, "site", d.x * ring, d.y * ring, data, "params"))
	for vp in _viewpoints(data):
		out.append(vp)
	var sand = _nearest_sand(data, nest)
	if sand != null:
		out.append(_site("shore", "shore", "site", sand.x, sand.y, data, "material"))
	return out

# The three highest local maxima more than 200 m apart (on a stride-4 scan: deterministic, ~65k cells at n = 1024).
static func _viewpoints(data) -> Array:
	var cells: Array = []
	var step := 4
	for j in range(step, data.n - step, step):
		for i in range(step, data.n - step, step):
			var k: int = j * data.n + i
			var h: float = data.height[k]
			if h > 150.0 and h >= data.height[k - step] and h >= data.height[k + step] and h >= data.height[k - step * data.n] and h >= data.height[k + step * data.n]:
				cells.append([h, i, j])
	cells.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and (a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]))))
	var picked: Array = []
	var out: Array = []
	for c in cells:
		var pos := Vector2(data.cell_center(c[1]), data.cell_center(c[2]))
		var far := true
		for q in picked:
			if q.distance_to(pos) <= 200.0:
				far = false
		if far:
			picked.append(pos)
			out.append(_site("viewpoint-%d" % picked.size(), "viewpoint %d" % picked.size(), "site", pos.x, pos.y, data, "height"))
			if picked.size() == 3:
				break
	return out

static func _nearest_sand(data, to: Vector2):
	var best = null
	var best_d := 1e30
	for j in range(0, data.n, 2):
		for i in range(0, data.n, 2):
			if data.material[j * data.n + i] != MAT_SAND:
				continue
			var p := Vector2(data.cell_center(i), data.cell_center(j))
			var d := p.distance_squared_to(to)
			if d < best_d:
				best_d = d
				best = p
	return best

# --- lookup --------------------------------------------------------------------------------------

func visible_list(revealed: bool) -> Array:
	return list.filter(func(s): return revealed or not s.hidden)

func names() -> Array:
	var out := []
	for s in list:
		out.append(str(s.id))
	for i in bookmarks.size():
		out.append("bookmark-%d" % (i + 1))
	return out

## Exact id or name first, then the best token match; null when nothing matches.
func find(query: String) -> Variant:
	var q := query.strip_edges().to_lower()
	if q == "":
		return null
	if q.begins_with("bookmark"):
		var idx := q.trim_prefix("bookmark").trim_prefix("-").trim_prefix(" ").to_int() - 1
		if idx >= 0 and idx < bookmarks.size():
			var b: Dictionary = bookmarks[idx]
			return {"id": "bookmark-%d" % (idx + 1), "name": b.name, "kind": "bookmark", "pos": Vector3(b.pos[0], b.pos[1], b.pos[2]), "hidden": false}
	for s in list:
		if s.id == q or str(s.name).to_lower() == q:
			return s
	var best = null
	var best_score := 0
	for s in list:
		var sc := score(q, s)
		if sc > best_score:
			best_score = sc
			best = s
	return best

## Substring or per-token match score (0 = no match).
static func score(query: String, s: Dictionary) -> int:
	var hay := (str(s.id) + " " + str(s.name) + " " + str(s.kind)).to_lower()
	var q := query.to_lower()
	if hay.contains(q):
		return 100 - mini(hay.find(q), 50)
	var total := 0
	for tok in q.split(" ", false):
		if hay.contains(tok):
			total += 10
		else:
			return 0
	return total

## Sorted candidates for the picker: [{site, score}], best first; all when the query is empty.
func search(query: String, revealed: bool, from: Vector2 = Vector2.ZERO) -> Array:
	var out: Array = []
	for s in visible_list(revealed):
		var sc := 1 if query.strip_edges() == "" else score(query, s)
		if sc > 0:
			out.append({"site": s, "score": sc, "dist": Vector2(s.pos.x, s.pos.z).distance_to(from)})
	out.sort_custom(func(a, b): return a.score > b.score or (a.score == b.score and a.dist < b.dist))
	return out

# --- bookmarks -----------------------------------------------------------------------------------

func _path() -> String:
	return "%s/%d.json" % [bookmark_dir, seed_id]

func load_bookmarks() -> void:
	bookmarks = []
	if FileAccess.file_exists(_path()):
		var v = JSON.parse_string(FileAccess.get_file_as_string(_path()))
		if v is Array:
			bookmarks = v

func save_bookmarks() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(bookmark_dir))
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(bookmarks))

func add_bookmark(pos: Vector3, camera: Dictionary) -> int:
	bookmarks.append({"name": "bookmark %d" % (bookmarks.size() + 1), "pos": [pos.x, pos.y, pos.z], "camera": camera})
	save_bookmarks()
	return bookmarks.size()

func rename_bookmark(index: int, name: String) -> void:
	if index >= 0 and index < bookmarks.size():
		bookmarks[index].name = name
		save_bookmarks()

func delete_bookmark(index: int) -> void:
	if index >= 0 and index < bookmarks.size():
		bookmarks.remove_at(index)
		save_bookmarks()
