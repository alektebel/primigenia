extends RefCounted
## What the field journal shows, read from the world: pure functions of `CporeWorld.state()` (plus the static species,
## chain and part tables), so the pages can be tested without a scene. Sections the world does not report
## (recipes, or shards and the cave in a world without secrets) come out empty and the view hides them.
##
## Where each page reads its state:
##   species  state.species[i] {seen, bonded, kills, resolution ("open" | "ally" | "hunted"), observed, activity, hidden_now}
##            (state.social.species[i] has the same fields with resolution 0 | 1 | 2 and is the fallback)
##            + CporeWorld.species()[i] {name, roam, temperament, diet "herbivore" | "carnivore" | "omnivore", activity_name, nocturnal}
##            + CporeWorld.chains()[i].observe (clue texts)
##            + state.entities[*] {species, likes, dislikes} (the liked/disliked tests are per species)
##   parts    state.parts.discovered[] {id, owned, level, tier} + the catalogue res://game/data/parts.json (46 parts)
##   secrets  state.shards {total, found, items: [{index, name, found, line, line_es}]} (line only once found),
##            state.parts.nodes[] {kind 3 fossil, 4 old carcass, inspected},
##            state.cave {enabled, entered (the passage), chamber_entered}
##   recipes  state.recipes (array {id, name, state, clues_seen, clues_total, clues[], parts_have, parts_need, diet_ok, ...});
##            until it exists: bone spines from state.parts.clues (1 clue hinted, 2 or more known)

const ALLY_NEED := 3
const NODE_FOSSIL := 3
const NODE_OLD_CARCASS := 4

static func build(state: Dictionary, species: Array, chains: Array, catalogue: Array) -> Dictionary:
	return {
		"dna_total": int(state.get("social", {}).get("dna_total", 0)),
		"species": species_pages(state, species, chains),
		"parts": part_tiles(state, catalogue),
		"parts_found": discovered_count(state),
		"parts_owned": owned_count(state),
		"shards": shards(state),
		"fossils": fossils(state),
		"cave": cave(state),
		"recipes": recipes(state),
	}

static func species_pages(state: Dictionary, species: Array, chains: Array) -> Array:
	var soc: Dictionary = state.get("social", {})
	var rows: Array = state.get("species", [])
	if rows.size() < species.size():
		rows = soc.get("species", [])
	var out: Array = []
	for i in species.size():
		var sp: Dictionary = species[i]
		var r: Dictionary = rows[i] if i < rows.size() and rows[i] is Dictionary else {}
		var seen := bool(r.get("seen", false))
		var observed := int(r.get("observed", 0))
		var texts: Array = []
		if i < chains.size():
			var all: Array = chains[i].get("observe", [])
			for k in mini(observed, all.size()):
				texts.append(String(all[k]))
		var likes: Array = []
		var dislikes: Array = []
		for e in state.get("entities", []):
			if e is Dictionary and int(e.get("species", -1)) == i and not bool(e.get("dead", false)):
				likes = e.get("likes", []).duplicate()
				dislikes = e.get("dislikes", []).duplicate()
				break
		out.append({
			"id": i, "name": String(sp.get("name", "?")), "body": String(sp.get("name", "")).to_lower(),
			"seen": seen, "bonded": int(r.get("bonded", 0)), "kills": int(r.get("kills", 0)), "need": ALLY_NEED,
			"resolution": resolution_of(r.get("resolution", 0)),
			"activity": int(r.get("activity", sp.get("activity", 0))), "nocturnal": bool(sp.get("nocturnal", int(r.get("activity", 0)) == 1)),
			"temperament": int(sp.get("temperament", 1)), "diet": diet_of(sp, i), "roam": int(round(float(sp.get("roam", 0.0)))),
			"clues": texts, "clue_total": int(chains[i].get("observe", []).size()) if i < chains.size() else 3,
			"likes": likes, "dislikes": dislikes,
		})
	return out

## The species table has no diet field: the stage (stage_ui.info_for) takes the two heavy species as carnivores.
static func diet_of(sp: Dictionary, index: int) -> int:
	var d: Variant = sp.get("diet", null)
	if d is String:
		return {"herbivore": 0, "carnivore": 1, "omnivore": 2}.get(d, 0)
	if d != null:
		return clampi(int(d), 0, 2)
	return 1 if index >= 2 else 0

## 0 open, 1 ally, 2 hunted, from the number (state.social) or the word (state.species).
static func resolution_of(v: Variant) -> int:
	if v is String:
		return {"open": 0, "ally": 1, "hunted": 2}.get(v, 0)
	return clampi(int(v), 0, 2)

static func part_tiles(state: Dictionary, catalogue: Array) -> Array:
	var have := {}
	for p in state.get("parts", {}).get("discovered", []):
		if p is Dictionary:
			have[String(p.get("id", ""))] = p
	var out: Array = []
	for c in catalogue:
		var id := String(c.get("id", ""))
		var h: Dictionary = have.get(id, {})
		out.append({
			"id": id, "category": String(c.get("category", "")),
			"name": c.get("name", {"en": id, "es": id}),
			"found": not h.is_empty(), "owned": bool(h.get("owned", false)),
			"level": int(h.get("level", 0)), "tier": int(h.get("tier", 0)),
		})
	return out

static func discovered_count(state: Dictionary) -> int:
	return state.get("parts", {}).get("discovered", []).size()

static func owned_count(state: Dictionary) -> int:
	var n := 0
	for p in state.get("parts", {}).get("discovered", []):
		if p is Dictionary and bool(p.get("owned", false)):
			n += 1
	return n

## Shards as [{index, found, name, line: {en, es}}] from state.shards.items; [] when the world has none (secrets off).
## The story line exists only once the shard is found.
static func shards(state: Dictionary) -> Array:
	var raw: Variant = state.get("shards", null)
	if not (raw is Dictionary):
		return []
	var out: Array = []
	for s in raw.get("items", []):
		if not (s is Dictionary):
			continue
		var found := bool(s.get("found", false))
		out.append({
			"index": int(s.get("index", out.size())), "found": found, "name": String(s.get("name", "")),
			"line": {"en": String(s.get("line", "")), "es": String(s.get("line_es", s.get("line", "")))} if found else "",
		})
	return out

## Fossils and old carcasses of the valley: {kind, studied}; the part found is not in the state, so it is not shown.
static func fossils(state: Dictionary) -> Array:
	var out: Array = []
	for n in state.get("parts", {}).get("nodes", []):
		if n is Dictionary and int(n.get("kind", -1)) in [NODE_FOSSIL, NODE_OLD_CARCASS]:
			out.append({"kind": int(n.kind), "studied": bool(n.get("inspected", false))})
	return out

## "" (no cave in this world), "unknown", "entered" (inside the passage) or "chamber" (the chamber found), from state.cave.
static func cave(state: Dictionary) -> String:
	var raw: Variant = state.get("cave", null)
	if not (raw is Dictionary) or not bool(raw.get("enabled", false)):
		return ""
	if bool(raw.get("chamber_entered", false)):
		return "chamber"
	return "entered" if bool(raw.get("entered", false)) else "unknown"

## Recipes as [{id, name, state: unknown|hinted|known|mastered, clues_seen, clues_total, clues: [], parts_have, parts_need, diet_ok}].
static func recipes(state: Dictionary) -> Array:
	var raw: Variant = state.get("recipes", null)
	var out: Array = []
	if raw is Array:
		for r in raw:
			if not (r is Dictionary):
				continue
			var st := String(r.get("state", "unknown"))
			if not (st in ["unknown", "hinted", "known", "mastered"]):
				st = "unknown"
			out.append({
				"id": String(r.get("id", "")), "name": r.get("name", ""), "state": st,
				"clues_seen": int(r.get("clues_seen", 0)), "clues_total": int(r.get("clues_total", 3)),
				"clues": r.get("clues", []), "note": r.get("note", ""),
				"parts_have": int(r.get("parts_have", -1)), "parts_need": int(r.get("parts_need", -1)),
				"diet_ok": r.get("diet_ok", null),
			})
		return out
	var parts: Variant = state.get("parts", null)
	if parts is Dictionary and parts.has("clues"):
		var c := int(parts.clues)
		out.append({"id": "bone_spines", "name": "", "state": "known" if c >= 2 else ("hinted" if c == 1 else "unknown"),
			"clues_seen": mini(c, 3), "clues_total": 3, "clues": [], "note": "", "parts_have": -1, "parts_need": -1, "diet_ok": null})
	return out

## Localised text of a value that is a String or {en, es}.
static func text_of(v: Variant, lang: String) -> String:
	if v is Dictionary:
		return String(v.get(lang, v.get("en", "")))
	return String(v)
