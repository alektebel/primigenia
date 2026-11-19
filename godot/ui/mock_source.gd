extends RefCounted
## Mock data source used by tests and evidence; stands in for the stage and C world.

const JournalData := preload("res://ui/journal_data.gd")

static func creature(i: int = 0) -> Dictionary:
	var species := ["Garfio", "Rondo", "Espinodo", "Coloso"]
	var likes := ["fruit and slow, steady songs", "meat; dislikes loud displays", "shiny seeds", ""]
	return {
		"id": i, "name": "%s #%d" % [species[i % 4], i], "species": species[i % 4],
		"temperament": i % 3, "diet": i % 3, "relationship": i % 4,
		"resolved": i % 5, "resolved_total": 4, "likes": likes[i % 4],
		"hp": 62.0, "hp_max": 100.0, "world_pos": Vector3(2, 1.5, -6),
	}

static func all_combinations() -> Array:
	var out: Array = []
	for t in JournalData.TEMPERAMENTS.size():
		for r in JournalData.RELATIONSHIPS.size():
			var c := creature(t * 4 + r)
			c["temperament"] = t
			c["relationship"] = r
			out.append(c)
	return out
