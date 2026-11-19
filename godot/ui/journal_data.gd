extends RefCounted
## What the old creature card showed, now the data of the journal page of a species (J). In play only the field note
## (name, diet glyph, relationship dashes) is on screen; the rest lives here until the journal pages are designed.

const TEMPERAMENTS := ["Timid", "Territorial", "Aggressive"]
const DIETS := ["Herbivore", "Carnivore", "Omnivore"]
const RELATIONSHIPS := ["Stranger", "Neutral", "Trusted", "Ally"]
const TEMPERAMENT_NOTES := [
	"Wary; easy to scare, easy to calm.",
	"Defends its ground; warn before approaching.",
	"Refuses social play until calmed.",
]

static func index_of(value, names: Array) -> int:
	if value is int or value is float:
		return clampi(int(value), 0, names.size() - 1)
	var s := String(value).to_lower()
	for i in names.size():
		if String(names[i]).to_lower() == s:
			return i
	return 0

## The rows of the species page for a creature info dictionary (the old card's strings).
static func page(d: Dictionary) -> Dictionary:
	var t := index_of(d.get("temperament", 0), TEMPERAMENTS)
	var diet := index_of(d.get("diet", 0), DIETS)
	var rel := index_of(d.get("relationship", 0), RELATIONSHIPS)
	var mood := int(d.get("mood", 0))
	var likes = d.get("likes", "")
	var likes_text := ", ".join(likes) if likes is Array else String(likes)
	var dislikes = d.get("dislikes", [])
	var dislikes_text := ", ".join(dislikes) if dislikes is Array else String(dislikes)
	var likes_row := ("Likes: " + likes_text) if likes_text != "" else "Likes: unknown yet. Try a skill or a gift, or observe it."
	if dislikes_text != "":
		likes_row += "\nDislikes: " + dislikes_text
	var trust := int(d.get("trust", 0))
	var out := {
		"species": String(d.get("species", "Unknown")), "name": String(d.get("name", "")),
		"temperament": TEMPERAMENTS[t], "diet": DIETS[diet], "relationship": RELATIONSHIPS[rel],
		"resolved": "%d / %d" % [int(d.get("resolved", 0)), int(d.get("resolved_total", 4))],
		"likes": likes_row, "note": TEMPERAMENT_NOTES[t],
		"trust": "%d / 100%s" % [trust, "  (bonded)" if bool(d.get("bonded", false)) else ""],
		"mood": "%s (%d)" % [("Upset" if mood <= -20 else "Wary" if mood < 0 else "Calm" if mood < 20 else "Joyful"), mood],
	}
	if int(d.get("carcass_meat", -1)) >= 0:
		out["note"] = "Remains: %d bites of meat left." % int(d.carcass_meat)
	return out
