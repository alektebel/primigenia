#!/usr/bin/env python3
"""Seeded random draw for Primigenia's food-web batch (brief docs/briefs/trophic-web.md, step 2).

  python3 tools/lore/council/foodweb_draw.py [--seed N]  -> lore/foodweb/primigenia.draw.json

Each SLOT is a gap found in the classification (level x role x habitat). The draw picks body plan (legs 0/2/4/6/8+, radial, sessile), size
class and activity at random from a WIDE list; a draw is kept only if the niche can justify it from the planet physics (rules JUSTIFY below).
Rejected draws are recorded. The council (qwen / DeepSeek / Composer) then derives the species around each accepted draw (foodweb.py).
"""
import argparse, json, os, random, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
SEED = 20261121
PLANS = ["legs0", "legs2", "legs4", "legs6", "legs8plus", "radial", "sessile"]
SIZES = ["insect", "small", "medium", "large", "giant"]   # <5 cm | 5 cm-1 kg | 1-30 kg | 30-300 kg | >300 kg
ACTS = ["day", "night", "dawn_dusk", "tidal"]
SIZE_TXT = {"insect": "insect-sized, under 5 cm", "small": "small, 5 cm to 1 kg", "medium": "medium, 1 to 30 kg", "large": "large, 30 to 300 kg", "giant": "giant, over 300 kg"}
PLAN_TXT = {"legs0": "limbless or footless (worm, fish, snail, eel-like)", "legs2": "two legs (biped or bird-like, may have wings)", "legs4": "four legs",
            "legs6": "six legs (insect-like, may fly)", "legs8plus": "eight or more legs (arachnid or crustacean-like)", "radial": "radial body", "sessile": "sessile (attached)"}
# (id, level, role, habitats, hint, allowed plans, allowed sizes, allowed activity); "wide" draws outside the allowed lists exist but are mostly rejected
SLOTS = [
 ("S01", "primary_consumer", "grazer", ["forest", "meadow"], "leaf-eating insect swarm: the missing base for insectivores", ["legs6"], ["insect"], ["day", "dawn_dusk"]),
 ("S02", "primary_consumer", "granivore", ["meadow"], "seed eater of grass and fruit pits", ["legs4", "legs2"], ["small"], ["night", "dawn_dusk"]),
 ("S03", "primary_consumer", "nectarivore", ["meadow", "spring"], "nectar feeder and pollinator of flowers such as velilla", ["legs6", "legs2"], ["insect", "small"], ["day"]),
 ("S04", "primary_consumer", "algae_scraper", ["shore"], "scrapes algae and crusts off tidal rock", ["legs0", "radial"], ["insect", "small"], ["tidal", "night"]),
 ("S05", "primary_consumer", "browser", ["forest"], "canopy leaf and fruit eater", ["legs4"], ["small", "medium"], ["dawn_dusk", "night"]),
 ("S06", "primary_consumer", "filter_feeder", ["shallows"], "zooplankton swarm grazing phytoplankton: base of the shallows food web", ["legs8plus", "legs0"], ["insect"], ["night", "dawn_dusk"]),
 ("S07", "secondary_consumer", "insectivore", ["meadow"], "hunts insects in the grass", ["legs2", "legs4"], ["small"], ["day"]),
 ("S08", "secondary_consumer", "insectivore", ["spring"], "hunts insects and larvae at the spring pools", ["legs4"], ["small"], ["night", "dawn_dusk"]),
 ("S09", "secondary_consumer", "egg_thief", ["shore"], "raids nests and tide-stranded animals", ["legs4", "legs2"], ["small", "medium"], ["night", "tidal"]),
 ("S10", "secondary_consumer", "small_predator", ["caves"], "ambush trapper of cave dwellers", ["legs8plus"], ["small"], ["night", "dawn_dusk"]),
 ("S11", "tertiary_consumer", "mid_predator", ["shallows"], "mid predator of the turbid shallows (pressure and electric sense, F20)", ["legs0"], ["medium"], ["dawn_dusk", "night"]),
 ("S12", "apex_predator", "apex_predator", ["forest", "meadow"], "land apex: rare, solitary", ["legs4"], ["large"], ["dawn_dusk", "night"]),
 ("S13", "apex_predator", "apex_predator", ["shallows", "shore"], "sea apex of the shelf", ["legs0"], ["large", "giant"], ["day", "tidal"]),
 ("S14", "apex_predator", "apex_predator", ["highlands"], "aerial apex: dense air makes big wings cheap (F4)", ["legs2"], ["large"], ["day"]),
 ("S15", "scavenger", "scavenger", ["shore"], "works the carcass and wrack line (carcasses drift ashore, F20)", ["legs8plus"], ["small"], ["tidal", "night"]),
 ("S16", "scavenger", "scavenger", ["forest", "meadow"], "buries and eats small carcasses", ["legs6"], ["insect"], ["night"]),
 ("S17", "scavenger", "scavenger", ["highlands"], "soaring carrion eater on thermals", ["legs2"], ["large"], ["day"]),
 ("S18", "decomposer", "detritivore", ["meadow"], "dung and dead-grass eater", ["legs6"], ["insect"], ["day", "dawn_dusk"]),
 ("S19", "decomposer", "detritivore", ["forest"], "rotting-wood and litter eater", ["legs6", "legs0"], ["insect"], ["night"]),
 ("S20", "decomposer", "detritivore", ["shore"], "eats rotting wrack", ["legs8plus"], ["insect", "small"], ["tidal", "night"]),
 ("S21", "decomposer", "detritivore", ["caves"], "eats dung and dead matter that falls into dark tubes", ["legs6"], ["insect"], ["night"]),
 ("S22", "parasite", "parasite", ["meadow"], "ectoparasite of herd animals", ["legs8plus"], ["insect"], ["day", "night"]),
 ("S23", "parasite", "parasitoid", ["forest"], "parasitoid of leaf insects", ["legs6"], ["insect"], ["day"]),
 ("S24", "parasite", "parasite", ["shallows"], "gill and skin parasite of fish and jellies", ["legs8plus"], ["insect", "small"], ["night"]),
 ("S25", "tertiary_consumer", "cleaner", ["shallows"], "cleaner of the sea apex and other fish: mutualist", ["legs0"], ["small"], ["day"]),
 ("S27", "decomposer", "detritivore", ["highlands"], "eats winter-killed rosette litter and frozen carcasses on cold slopes", ["legs6", "legs0"], ["insect"], ["day"]),
 ("S28", "scavenger", "scavenger", ["shallows", "caves"], "carcass-sink scavenger of the shelf floor and the sunken cave (carcasses sink or drift, F20)", ["legs8plus"], ["small"], ["night"]),
 ("S26", "secondary_consumer", "cleaner", ["meadow", "shore"], "bird that cleans parasites off big animals: mutualist", ["legs2"], ["small"], ["day"]),
]
# plant slots (producers, decomposers, one parasite)
PSLOTS = [
 ("P01", "producer", "chemosynthetic", ["shallows"], "mat on submerged vent seeps: sulfide + O2 (D22)", ["sessile"]),
 ("P02", "producer", "chemosynthetic", ["caves"], "iron and sulfur film in dark lava tubes (F9, D22)", ["sessile"]),
 ("P03", "producer", "photosynthetic", ["shallows"], "phytoplankton in turbid water, red-brown accessory pigments (D24)", ["sessile"]),
 ("P04", "producer", "photosynthetic", ["vents"], "black-red thermophile mat on hot-spring terraces below 70 C (F23)", ["sessile"]),
 ("P05", "producer", "photosynthetic", ["highlands"], "black UV-screening crust lichen above 1,750 m (F14, D23)", ["sessile"]),
 ("P06", "parasite", "parasite", ["forest"], "hemiparasitic mistletoe on fog-forest trees", ["sessile"]),
 ("P07", "decomposer", "fungal_decomposer", ["forest"], "bracket fungus rotting dead wood (D28)", ["sessile"]),
 ("P08", "decomposer", "fungal_decomposer", ["caves"], "fungus on cave dung and dead matter (D28)", ["sessile"]),
]


def justify(slot, plan, size, act):
    """Return None if the draw is justified, else the reason it is rejected."""
    sid, level, role, habs = slot[0], slot[1], slot[2], slot[3]
    arthropod = plan in ("legs6", "legs8plus")
    aquatic = any(h in ("shallows",) for h in habs)
    if arthropod and size in ("large", "giant"): return "arthropod gas exchange caps body size at medium even at pO2 0.34 bar (D10)"
    if plan == "legs0" and not aquatic and size in ("large", "giant") and level != "apex_predator": return "limbless land animal this big has no niche here"
    if plan == "sessile" and level != "producer": return "sessile animals are not consumers of mobile food here"
    if plan == "radial" and size in ("medium", "large", "giant") and not aquatic: return "radial bodies are marine or tide-pool in this lore (F27 radiations)"
    if level == "apex_predator" and size not in ("large", "giant"): return "an apex needs mass: apex of 4 transfers feeds on prey of 10x its energy (D25, D26)"
    if level == "apex_predator" and size == "giant" and "highlands" in habs: return "thin summit air and 1.05 g do not carry a giant flier"
    if level == "decomposer" and size not in ("insect", "small"): return "detritivore bodies are small: energy per item is tiny"
    if level == "parasite" and size not in ("insect", "small"): return "parasite must be much smaller than its host"
    if role == "insectivore" and size not in ("insect", "small"): return "insect prey (about 1 mg) does not repay hunting by a body above about 1 kg (prey-size scaling, D25)"
    if level in ("primary_consumer", "secondary_consumer") and size == "giant" and role not in ("browser",): return "only a browser reaches giant size on the energy this level gets (D25)"
    if level == "secondary_consumer" and size == "large": return "secondary consumers get 1% of production: too little for large bodies (D25)"
    if role == "cleaner" and (size != "small" or act != "day"): return "a cleaner is small and works in daylight, where clients can see it"
    if act == "tidal" and not any(h in ("shore", "shallows", "caves") for h in habs): return "tidal activity needs a tidal habitat (F13)"
    if act == "day" and "caves" in habs: return "no light in caves: day activity has no meaning"
    return None


def draw(seed):
    rng = random.Random(seed); out = []
    for slot in SLOTS:
        sid, level, role, habs, hint, plans, sizes, acts = slot
        rejected = []; kept = None
        for _ in range(60):
            # 70% from the slot's justified lists, 30% from the WIDE lists (these are what the rules must reject)
            wide = rng.random() < 0.3
            plan = rng.choice(PLANS if wide else plans); size = rng.choice(SIZES if wide else sizes); act = rng.choice(ACTS if wide else acts)
            why = justify(slot, plan, size, act)
            if why is None:
                kept = (plan, size, act); break
            rejected.append({"plan": plan, "size": size, "activity": act, "why": why})
        if kept is None: raise SystemExit(f"slot {sid}: no justified draw")
        out.append({"slot": sid, "level": level, "role": role, "habitats": habs, "hint": hint, "plan": kept[0], "size": kept[1], "activity": kept[2], "rejected": rejected[:6], "n_rejected": len(rejected)})
    pl = [{"slot": s[0], "level": s[1], "role": s[2], "habitats": s[3], "hint": s[4]} for s in PSLOTS]
    return {"schema": "cpore.foodweb.draw/1", "world": "primigenia", "seed": seed, "rng": "python random.Random(seed), see tools/lore/council/foodweb_draw.py", "creature_slots": out, "plant_slots": pl}


if __name__ == "__main__":
    ap = argparse.ArgumentParser(); ap.add_argument("--seed", type=int, default=SEED); a = ap.parse_args()
    d = draw(a.seed)
    p = os.path.join(ROOT, "lore", "foodweb", "primigenia.draw.json"); os.makedirs(os.path.dirname(p), exist_ok=True)
    json.dump(d, open(p, "w"), indent=1, ensure_ascii=False); open(p, "a").write("\n")
    for s in d["creature_slots"]: print(s["slot"], s["level"], s["role"], s["habitats"], s["plan"], s["size"], s["activity"], "rejected", s["n_rejected"])
