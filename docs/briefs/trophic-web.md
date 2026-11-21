# Brief (lore council): Primigenia's first full food web — a random batch covering every trophic level

Owner request 2026-11-21: "design a first batch of random creatures occupying all the levels of the trophic line: flora that photosynthesises, animals that eat the flora, animals that eat those animals, super-carnivores, scavengers, etc." Tracker test: L-TROPHIC (new). Feeds roadmap milestone 6 (species variety: ~8 simulated → ~20).

## Starting point
Primigenia has 19 creatures (`lore/creatures/*.json`, world `primigenia`) and 21 flora (`lore/flora/`). Diets are free text (`niche.diet`, `prey`, `predators`), with no trophic level field, so the gaps are unknown.

Method: `lore/rules/derivation.md`. Primigenia's derivation sheet comes first (F5: volcanic island, 21% O₂), then producers, then each level up.

## Steps (council: chair + astrobio referee + ecologist seat; A22 first principles, A37 technosphere untouched)
1. **Classify what exists.** Give every Primigenia creature and plant one level plus a role:
   - producers: photosynthetic, chemosynthetic at the vents/sulphur crusts
   - primary consumers: grazer, browser, frugivore/granivore, nectarivore/pollinator, filter feeder, algae scraper
   - secondary consumers: insectivore, small predator, egg thief
   - tertiary consumers: mid predator
   - apex / super-carnivore
   - scavenger
   - decomposer / detritivore: fungi, worms, litter eaters
   - parasite / parasitoid
   - omnivore (spans levels)
   - mutualist (cleaner, seed disperser, pollinator)

   Output: `docs/lore/primigenia-food-web.md`, a table plus the gaps per habitat (meadow, forest, shore, shallows, caves, spring, highlands).
2. **Random batch to fill the gaps.** Draw candidates with a fixed seed (recorded) across body plan (legs 0/2/4/6/8+, radial, sessile), size (insect → large), habitat and activity (day/night). The council keeps only draws a niche can justify from Primigenia's physics (F5: O₂ 21%, wet fuels, volcanic island). Target **at least one species per level per main habitat, and at least 2 apex, 3 scavengers, 3 decomposers**, plus producers including non-green (chemosynthetic, red or black pigments per the light spectrum).
3. **Energy pyramid.** Each level carries a relative abundance (≈10% transfer per level: Lindeman 1942, starting value). Record it as the spawn weight the game will use (A27 ecology), so apex animals are rare and grazers common.
4. **A consistent web.** Every `prey` and `predators` id must exist. Every plant names its eaters (`food_for`). Every consumer must have a food source in its habitat. No level may end in a dead end with nothing eating it, except apex animals, whose bodies go to scavengers and then decomposers.
5. **Playable hooks**, as for every creature (A22): what the player can do with or against each one (befriend preference, threat, food, secret).

## Schema
Propose `niche.trophic` (enum of the levels above) and `niche.role` in `lore/schema/creature.schema.json` and the plant schema, as optional fields. `tools/lore/validate` must pass. No snapshot or event changes; game import is milestone 6.

## Evidence and acceptance
- `docs/lore/primigenia-food-web.md`: classification table, gaps before and after, the seed, the pyramid numbers, and a food-web diagram (SVG/JPG).
- New creatures and flora as JSON with the validator passing, rendered cards (`render`), and a refcheck where any science is cited.
- At least one species per level per main habitat; zero dangling ids; pyramid weights add up.
- Owner reviews the batch as a contact sheet (names, sizes, role).
