extends RefCounted
## What the cell passes to the creature (DESIGN.md A26): metabolism -> starting diet, defence -> one starting part,
## size -> starter size class. Saved as user://cell_legacy.json (versioned). The creature stage does not consume it yet;
## Game.cell_legacy() reads it and the main menu's Criatura card shows it.
##
## Rules (all from the sheet of the cell, see Sim.legacy_sheet(), and the colony composition):
##   diet     herbivoro if the colony has a photosynthetic cell (locked for now, so never yet);
##            carronero when waste handling (lactate DH + exporters) is >= WASTE_SHARE of the factory's pieces
##            (a fermentation-heavy metabolism), else cazador (lean, efficient glycolysis).
##   defense  espinas = spines on the membrane + defensive colony cells; placas = flippases / 4 + 1 for a membrane >= 95 %.
##            More spines than plates (or equal and at least one) -> espinas; else plates; nothing -> ninguna.
##   size     the cell's growth tier: 0-1 small, 2-3 medium, 4-5 large.

const VERSION := 1
const PATH := "user://cell_legacy.json"
const WASTE_SHARE := 0.25

static func derive(sheet: Dictionary, colony: Dictionary = {}, source: String = "colony") -> Dictionary:
	var p: Dictionary = sheet.get("pieces", {})
	var total := 0
	for k in p:
		total += int(p[k])
	var waste := float(int(p.get("ldh", 0)) + int(p.get("ex", 0))) / maxf(1.0, float(total))
	var diet := "cazador"
	if int(colony.get("photo", 0)) > 0:
		diet = "herbivoro"
	elif waste >= WASTE_SHARE:
		diet = "carronero"
	var spines := int(p.get("spn", 0)) + int(colony.get("defense", 0))
	var plates := int(floor(int(p.get("fl", 0)) / 4.0)) + (1 if int(sheet.get("mem", 0)) >= 95 else 0)
	var defense := "ninguna"
	if spines >= 1 and spines >= plates:
		defense = "espinas"
	elif plates >= 1:
		defense = "placas"
	var tier := clampi(int(sheet.get("tier", 0)), 0, 5)
	var size_class := "small" if tier <= 1 else ("medium" if tier <= 3 else "large")
	return {"version": VERSION, "source": source, "diet": diet, "defense": defense, "size_class": size_class,
		"stats": {"atp_min": int(sheet.get("atp_min", 0)), "mem": int(sheet.get("mem", 0)), "tier": tier, "colony_cells": int(colony.get("cells", 1))},
		"tally": {"waste_share": snappedf(waste, 0.01), "spines": spines, "plates": plates}}

static func save(d: Dictionary, path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(d, "\t", true))
	f.close()
	return true

## {} when the file is missing, not JSON, from another version or with unknown values.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	var v = j.data
	if typeof(v) != TYPE_DICTIONARY:
		return {}
	if int(v.get("version", 0)) != VERSION:
		return {}
	if not (v.get("diet", "") in ["carronero", "cazador", "herbivoro"]):
		return {}
	if not (v.get("defense", "") in ["espinas", "placas", "ninguna"]):
		return {}
	if not (v.get("size_class", "") in ["small", "medium", "large"]):
		return {}
	return v
