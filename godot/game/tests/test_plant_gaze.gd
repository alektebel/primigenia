extends RefCounted
# Observing plants (brief creature-fixes 6): the pick ray, the dwell, the journal rows, the saved list.

const PlantGaze := preload("res://game/island/plant_gaze.gd")
const Placement := preload("res://game/island/flora_placement.gd")

func run(t) -> void:
	var rows := Placement.recipes()
	for r in rows:
		t.check(r.has("lore") and String(r.lore.en) != "" and String(r.lore.es) != "", "lore line in both languages: " + String(r.id))
		t.check(PlantGaze.HABITATS.has(r.habitat), "habitat words for " + String(r.habitat))
	var g := PlantGaze.new()
	var records := [
		{"id": "caramillo", "variant": 0, "p": Vector3(0, 0, 20), "height": 6.0},
		{"id": "paja_dulce", "variant": 0, "p": Vector3(0, 0, 10), "height": 0.4},
		{"id": "nieblon", "variant": 0, "p": Vector3(300, 0, 20), "height": 8.0},        # out of reach
		{"id": "velilla", "variant": 0, "p": Vector3(-30, 0, 20), "height": 0.3},
	]
	var origin := Vector3(0, 1.5, 0)
	t.eq(g.pick(records, origin, (Vector3(0, 0.2, 10) - origin).normalized()), "paja_dulce", "the nearest plant on the ray is picked")
	t.eq(g.pick(records, origin, (Vector3(0, 3, 20) - origin).normalized()), "caramillo", "a tall plant is picked at its middle")
	t.eq(g.pick(records, origin, Vector3(1, 0, 0)), "", "nothing on the ray: nothing")
	t.eq(g.pick(records, origin, (Vector3(300, 4, 20) - origin).normalized()), "", "beyond the reach nothing counts")
	t.eq(g.pick([], origin, Vector3(0, 0, 1)), "", "no plants, no pick")
	# dwell
	t.eq(g.tick(1.0, "caramillo"), "", "one second is not enough")
	t.check(g.progress() > 0.3 and g.progress() < 0.5, "progress follows the dwell (%.2f)" % g.progress())
	t.eq(g.tick(1.0, "velilla"), "", "moving to another plant starts over")
	t.eq(g.tick(1.0, ""), "", "looking away resets")
	t.check(g.progress() == 0.0, "progress back to 0")
	var found := ""
	for i in 30:
		found = g.tick(0.1, "caramillo")
		if found != "":
			break
	t.eq(found, "caramillo", "resting on a plant for %.1f s notes it" % PlantGaze.DWELL)
	t.check(g.known.has("caramillo"), "it is known")
	t.eq(g.tick(5.0, "caramillo"), "", "a known plant is not noted twice")
	# the journal and the save
	var jr := g.journal_rows(rows)
	t.eq(jr.size(), 1, "one plant in the journal")
	t.eq(jr[0].name.en, "Whistlewood", "with its name")
	t.check(String(jr[0].lore.en) != "" and String(jr[0].habitat_text.es) != "", "its lore and habitat")
	var saved := g.to_list()
	var g2 := PlantGaze.new()
	g2.from_list(JSON.parse_string(JSON.stringify(saved)))
	t.check(g2.known.has("caramillo") and g2.known.size() == 1, "the list survives JSON (saved with the game)")
	g2.from_list(null)
	t.check(g2.known.is_empty(), "a save without plants starts empty")
