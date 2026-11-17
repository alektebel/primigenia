extends RefCounted
# Step 9: sites are deterministic, on land, reachable by tp; bookmarks persist.

const StageWorld := preload("res://game/stage/stage_world.gd")
const TerrainData := preload("res://game/island/terrain_data.gd")
const Sites := preload("res://devtools/sites.gd")
const Registry := preload("res://devtools/console/registry.gd")
const Commands := preload("res://devtools/console/commands_creature.gd")

func run(t) -> void:
	var p: Dictionary = CporeTerrain.defaults()
	p.n = 256
	p.seed = 1
	var entry: Dictionary = CporeTerrain.new().generate(p)
	TerrainData.prepare(entry)
	var data = TerrainData.new()
	data.setup(entry, false)
	var sw = StageWorld.new()
	t.eq(sw.world.set_field(entry), 0, "field attached")
	var setup: Dictionary = CporeWorld.default_setup(1)
	setup.terrain = 2
	setup.nest = Vector2(0, 0)
	setup.wild = []      # no Garfio: teleporting next to it would start a fight
	t.eq(sw.reset(setup), 0, "reset on the field")
	var a: Array = Sites.for_island(data, entry.params, sw.world.get_setup())
	var b: Array = Sites.for_island(data, entry.params, sw.world.get_setup())
	t.check(a.size() >= 8, "a usable list (%d sites)" % a.size())
	var same := a.size() == b.size()
	var ids := {}
	for i in a.size():
		same = same and a[i].id == b[i].id and a[i].pos == b[i].pos
		t.check(not ids.has(a[i].id), "id %s is unique" % a[i].id)
		ids[a[i].id] = true
	t.check(same, "the same seed gives the same list, ids and positions")
	for must in ["nest", "lake", "pass", "col", "viewpoint-1"]:
		t.check(ids.has(must), "site %s exists" % must)
	var far := 0
	for s in a:
		if not s.hidden:
			t.check(s.pos.y > 0.0, "site %s is on land (y %.1f)" % [s.id, s.pos.y])
	var reg = Registry.new()
	reg.stage_provider = func(): return sw
	Commands.register_all(reg)
	var sites = Sites.new()
	sites.list = a
	reg.services["sites"] = sites
	var moved := 0
	for s in a:
		if s.hidden:
			continue
		var res: Dictionary = reg.execute("tp " + s.id)
		if res.ok:
			sw.step_ticks(1)
			var e: Dictionary = sw.cur.entities[0]
			if Vector2(e.x, e.z).distance_to(Vector2(s.pos.x, s.pos.z)) < 0.5:
				moved += 1
			else:
				t.check(false, "tp %s landed %.1f m away" % [s.id, Vector2(e.x, e.z).distance_to(Vector2(s.pos.x, s.pos.z))])
		else:
			t.check(res.error.contains("water") or res.error.contains("outside"), "tp %s refused with a reason: %s" % [s.id, res.error])
	t.check(moved >= a.size() - 4, "tp reached %d of %d sites" % [moved, a.size()])
	t.eq(sites.find("lak").id if sites.find("lak") != null else "", "lake", "fuzzy find 'lak'")
	t.check(sites.find("nope zzz") == null, "no match is null")
	t.check(sites.search("cave", false).size() >= 0 and sites.search("", false).size() == a.size(), "empty search lists all")
	# bookmarks persist across restarts
	var dir := "user://devtools-test/bookmarks"
	var s1 = Sites.new()
	s1.bookmark_dir = dir
	s1.seed_id = 99
	s1.list = a
	s1.add_bookmark(Vector3(10, 5, 20), {"yaw": 1.0})
	var s2 = Sites.new()
	s2.bookmark_dir = dir
	s2.seed_id = 99
	s2.load_bookmarks()
	t.eq(s2.bookmarks.size(), 1, "a bookmark persists across restarts")
	t.check(s2.find("bookmark 1") != null and s2.find("bookmark-1").pos == Vector3(10, 5, 20), "bookmark lookup")
	s2.delete_bookmark(0)
	s2.load_bookmarks()
	t.eq(s2.bookmarks.size(), 0, "delete persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "/99.json"))
