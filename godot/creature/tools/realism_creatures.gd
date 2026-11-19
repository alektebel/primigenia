extends RefCounted
## The four creatures of the realism pilot (docs/godot/CREATURE-REALISM.md): the hero, a heavy quadruped, a
## many-legged hydraulic walker and an armoured exoskeleton one. Built from the bundled Merodeador (zoo morphologies)
## so nothing here is a per-creature asset: every look comes from the genome at build time.

const Zoo := preload("res://devtools/zoo/zoo_genomes.gd")

## Extra ids "slug" (Babosa seed, legless) and "stilt" (Zancuda seed) are not in the default set.
static func ids() -> Array:
	return ["hero", "giant", "spider", "beetle"]

static func genome(id: String) -> Dictionary:
	match id:
		"hero":
			return Zoo.genome("hero")
		"giant":
			return Zoo.genome("giant")
		"spider":
			var g: Dictionary = Zoo.genome("centipede")
			g.name = "Zancuda araña"
			for p in g.parts:
				if p.type == "pata":
					p.w = 0.07
			g.skin = {"pat": 2, "cA": "#6b4a2a", "cB": "#2b1d12", "cC": "#cdb48a", "wet": 0.2, "scale": 9}
			return g
		"beetle":
			var g: Dictionary = Zoo.genome("hexapod")
			g.name = "Escarabajo"
			g.parts = g.parts.filter(func(p): return p.type != "pua" and p.type != "cuerno" and p.type != "fauces")
			g.parts.append({"type": "pinzas", "t": 1, "ang": 0, "size": 1.0})
			for t in [0.42, 0.52, 0.62, 0.72]:
				g.parts.append({"type": "placa", "t": t, "ang": 0, "size": 1.1})
				g.parts.append({"type": "placa", "t": t, "ang": 0.9, "size": 0.8})
			g.parts.append({"type": "shell_plate", "t": 0.57, "ang": 0.0, "size": 1.3})
			g.skin = {"pat": 0, "cA": "#3a2f22", "cB": "#1d1710", "cC": "#7a6a4c", "wet": 0.5, "scale": 12}
			return g
	if id == "slug":
		return Creature.seeds()["Babosa"]
	if id == "stilt":
		return Creature.seeds()["Zancuda"]
	return {}
