# Lore worlds: where every creature lives (A23)

Status: **plan, 2026-11-18** (owner request). Every creature belongs to a **world** (`lore/worlds/<id>.json`, see LORE-FORMAT.md).
The lore council (tools/lore/council: 5 qwen voices + DeepSeek skeptic + GLM senses, Composer as plausibility referee) builds each
world from first principles (A22): planet canon first, then creatures by Graph-of-Thoughts, then new species for empty niches.

## 1. Humans are real, where they really are (A23)

The galaxy of the Space stage contains **the real Sun at its real position** (Orion Arm, ~8.2 kpc from the galactic centre, ~20 pc
above the plane) with **Earth and humans**. The nearby real stars keep their real positions and distances (from a public-domain star
catalogue, e.g. HYG), which lines up the easter eggs for free:

| Real system | Distance from Sol | Who lives there in our lore |
|---|---|---|
| **Sol / Earth** | 0 | **Humans** (kind: real). Their chains use real biology with real references (bipedalism, endurance running and sweating, the voice, the hands, cooperation) |
| **40 Eridani A** | ~16.3 ly | **Erid and the Eridians** (A20, kind: third_party) |
| **Tau Ceti** | ~11.9 ly | **Adrian** and **Taumoeba** (A20) |
| Sol's planets and nearby stars | — | **Astrophage** as a star-surface microbe that can reach any of them (A20) |

Open questions for the owner (not decided):
1. **When** do you meet humans? The Space stage's era decides whether they are today's humans, *All Tomorrows*' Star People and
   their descendants (A19), or gone (only a billion-year-old skull, as the creature-stage egg already hints).
2. **Are humans cousins?** Option: the makers' capsules seeded Earth too, so humans and your lineage share a biochemistry (F24).
   That would make the skull fossil and the makers' dead world one story.
3. Where is **your** home world relative to Sol (distance, direction)? It sets how soon you meet them.

## 2. Worlds the council builds

| World | Kind | Planet canon | Creatures |
|---|---|---|---|
| **primigenia** (the island) | fictional | done (27 facts) | Rondo, Zanco, Espinodo, Garfio, Coloso, Merodeador, Zancuda, Babosa, the player's lineage and cousins, the nocturnal creature, albinos, Ecolumbre, + new species for empty niches |
| **earth** | real | real facts with references | humans (+ a few real animals as reference points) |
| **erid** | third_party (A20) | from the book's facts | Eridians and Erid's ecosystem |
| **adrian** | third_party (A20) | from the book's facts | Taumoeba; Astrophage lives on stars, filed under its host |
| **gas giant of the honour-bound tentacled species** | third_party (A4, Banks) | atmosphere layers, winds, chemistry | the Affront-like species |
| ***All Tomorrows* worlds** | third_party (A19) | one world per group (Earth, Mars, the Qu-shaped worlds, Gravital space…) | all 45 catalogued species as `easter_egg` creatures with 1–3 chains each, linked to `lore/alltomorrows.en.json` |
| **the deep sky** (a gas giant) | fictional | atmosphere layers, winds, chemistry | **sinkers, floaters, hunters** (Sagan & Salpeter 1976), **air whales** (giant hydrogen-buoyed floaters), **jet hunters**, cloud-plankton grazers; home of the honour-bound tentacled species (A4) |
| **silicon worlds** (hot and cryogenic) | fictional | silicone/silicate chemistry where it can work; silanes in liquid nitrogen/methane | slow, crystalline, glass-shelled life, graded honestly by the referee (Bains 2004; Petkowski, Bains & Seager 2020) |
| **the star world** | fictional + A20 | a star's photosphere and corona; a neutron-star crust | Astrophage (A20), plasma / magnetic-flux-tube organisms, a nuclear-chemistry ecology on a neutron star (very fast time); marked "highly speculative" where true |
| **bizarre but plausible** | fictional | new worlds with extreme physics: a tidally locked red-dwarf world, an ice-moon ocean, a high-pressure super-Earth, a rogue planet, a ring-world of a gas giant's moon | species derived from those physics, checked by the referee (for the Space stage's alien bestiary) |

## 3. Integration in the game

- **Creature stage (now):** only the island's creatures play. Easter eggs appear as winks: the skull fossil (A19), the Petrova line (A20).
- **Space stage:** each world becomes a visitable planet; its species file drives the alien's look, temperament, diplomacy and the
  journal; the first-principles chains are how the player predicts what an alien world's life will be like.
- Third-party names and descriptions stay only in their lore files (A4/A19/A20 rule); our own creature files reference them by id.

## 4. How it runs (autoiteration)

For each world, unattended: council planet drafts → peer review + referee → planet canon (a chair model drafts, Opus approves)
→ Graph-of-Thoughts creatures (generate, aggregate, score with 4 judges, refine, cross-link) → `species` for empty niches and bizarre
variants → import into `lore/creatures/*.json` → validate → render → reference check. Opus reviews every world before it is merged;
the owner promotes creatures to `canon`.
