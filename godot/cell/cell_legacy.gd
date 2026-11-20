extends RefCounted
## What the cell passes to the creature (DESIGN.md A26): metabolism -> starting diet, defence -> one starting part,
## size -> starter size class. Saved as user://cell_legacy.json (versioned). Game.cell_legacy() reads it, the main menu's Criatura
## card shows it and the bridge (docs/godot/CELL-BRIDGE.md) applies it to a NEW creature game: the island scales and equips the
## hatchling (apply_genome), the C world gets the diet and the owned part (CporeWorld.apply_legacy).
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

## defense -> the starter part (catalogue id); owned, equipped and a starter in the C world.
const PART := {"espinas": "pua", "placas": "placa"}
## diet -> CP_DIET_* of the C social state (HERBIVORE 0, CARNIVORE 1, OMNIVORE 2). The scavenger eats carcasses and anything else: omnivore.
const DIET_C := {"herbivoro": 0, "cazador": 1, "carronero": 2}
## size class -> hatchling scale (HATCHLING.md: 1.0 is the 1.18 m, 36 kg hatchling; 0.9 and 1.1 keep the camera floor, the 0.05 m near
## plane and the Garfio winnability within the measured range).
const SCALE := {"small": 0.9, "medium": 1.0, "large": 1.1}

static func part_for(legacy: Dictionary) -> String:
	return str(PART.get(str(legacy.get("defense", "")), ""))

static func diet_for(legacy: Dictionary) -> int:
	return int(DIET_C.get(str(legacy.get("diet", "")), -1))

static func scale_for(legacy: Dictionary) -> float:
	return float(SCALE.get(str(legacy.get("size_class", "")), 1.0))

## The hatchling genome of a creature game that starts from this legacy: every length scaled (nodes, part sizes, leg joints), the starter
## part added to the body (equipped). `{}` or an unknown legacy returns the genome unchanged. Pure; the original is not touched.
static func apply_genome(genome: Dictionary, legacy: Dictionary) -> Dictionary:
	if legacy.is_empty():
		return genome
	var g: Dictionary = genome.duplicate(true)
	var k := scale_for(legacy)
	if k != 1.0:
		for n in g.get("nodes", []):
			for key in ["y", "z", "r"]:
				if n.has(key):
					n[key] = float(n[key]) * k
			n["r"] = maxf(float(n.get("r", 0.03)), 0.03)       # the creature module's floors (creature_genome.gd): node r 0.03, leg w 0.05, part size 0.1
		for p in g.get("parts", []):
			for key in ["size", "w"]:
				if p.has(key):
					p[key] = maxf(float(p[key]) * k, 0.05 if key == "w" else 0.1)
			for key in ["k", "f"]:
				if p.get(key) is Array:
					p[key] = (p[key] as Array).map(func(v): return float(v) * k)
	var part := part_for(legacy)
	if part != "" and not g.get("parts", []).any(func(p): return p.get("type", "") == part):
		var np := {"type": part, "t": 0.55 if part == "pua" else 0.45, "ang": 0.0, "size": 0.25 * k, "level": 1, "tier": 0}
		if part == "pua":
			np["len"] = 0.55
		g.parts.append(np)
	return g

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
