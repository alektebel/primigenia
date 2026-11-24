# Brief (lore council): 40 real exoplanets, renamed, life derived forward from their physics

Owner request 2026-11-21: "put in the list some 40 different exoplanets discovered to date, named after the real name a bit modified, and reverse-engineer how creatures should be on that planet to exist, using the council, Codex and Opus to manage it." Tracker test: L-EXO40. **Method: `lore/rules/derivation.md` (Weir): derive forward from the measured data; biosphere before creatures; derivation sheet per world; at most one declared violation.** Feeds the Space stage (A22: the player must be able to predict life from physics) and the tech trees (A30, A37 technosphere, D-28 oxygen and flame).

## Roles (AGENTS.md)
- **Opus** plans and manages: picks the planets and their real data, writes the seeds, reviews the council's output. No project code.
- **Codex** writes the pipeline changes (code): the `exoplanet` world kind in the seed, frame and validator.
- **Council** (`tools/lore/council/autoloop.py`, free models plus the astrobio referee) writes the worlds and creatures.
- **Claude** reviews and merges.

## Step 1 — Opus: choose 40 and fetch real data
- Source: NASA Exoplanet Archive (Planetary Systems Composite table), fetched live, plus discovery papers where needed. Record the retrieval date. Never invent a value: unknown means `null` plus a note, and estimates are marked `estimated` with the method used (for example, mass from radius via Chen & Kipping 2017).
- Spread across kinds, with no more than 8 of any one kind:
  - temperate rocky worlds in the habitable zone (TRAPPIST-1 d/e/f, Proxima Cen b, Teegarden b, LHS 1140 b, Kepler-186f, Kepler-442b, TOI-700 d, K2-18 b, …)
  - super-Earths and sub-Neptunes, including Hycean candidates
  - tidally locked M-dwarf worlds (eyeball, terminator life)
  - lava and ultra-hot worlds (55 Cnc e, K2-141 b, CoRoT-7b): first candidates for hot silicon life
- very cold worlds with possible liquid nitrogen or methane, candidates for silane life
  - cold or icy worlds (OGLE-2005-BLG-390Lb), with subsurface oceans
  - gas and ice giants with cloud-layer life (WASP-107 b, a temperate Jupiter-mass planet)
  - eccentric orbits (HD 80606 b)
  - circumbinary (Kepler-16b)
  - rogue planets, pulsar planets (PSR B1257+12 c)
  - the youngest or most recent discoveries
- Per planet record: real name, host star (spectral type, Teff, age, activity), mass, radius, density, gravity, orbit period and semi-major axis, eccentricity, insolation, equilibrium temperature, tidal locking (likely or no), measured atmosphere (JWST/HST detections, with citation) or `null`, distance in light years, discovery year and method.
- **Game name:** the real name slightly modified so it's recognisable but ours. Examples: TRAPPIST-1e → "Trapista-1e", Proxima b → "Próxima Bruma", Kepler-186f → "Keplera 186f", K2-18 b → "Kadosbe". Keep the real name in the data for the in-game encyclopedia.
- Output: `lore/worlds/exoplanets-40.json` (data with citations) and 40 entries appended to `tools/lore/council/worlds_seed.json` with `kind: "exoplanet"`, `stage: "space"`, `batch: 2`.

## Step 2 — Codex: exoplanet kind in the pipeline
- The seed accepts a `real` block (the measured fields above), and the planet stage must start from these values: it may fill gaps but never contradict them.
- New frame section for `exoplanet`, the forward derivation chain (`lore/rules/derivation.md`). The planet stage writes `lore/worlds/<id>.derivation.json` first; the validator recomputes gravity, equilibrium temperature, scale height, water boiling point at pressure, Jeans escape and the O₂ thresholds, and fails on mismatch. For each world, derive in this order:
  0. **the biochemistry: solvent and backbone derived from temperature, pressure and elements; not water by default. Silicon-based life included** (quota: no more than about 40% water-carbon worlds, at least 20% silicon worlds, both cold silanes and hot silicones/silicates; `lore/rules/derivation.md`)
  1. the energy source (light spectrum at the surface, tidal heat, chemistry, radiolysis)
  2. the solvent and temperature window
  3. pressure and gravity, and from them body size, posture and limb count
  4. the light at the surface: what eyes or other senses evolve
  5. day length and locking: rhythms and migrations
  6. oxygen and oxidisers, which gate flame and metal (A37, D-28)
  7. the hazards (flares, radiation, storms)

  The creatures follow from that chain. Every creature trait must cite a sheet key (`because:`); producers and the food web come before the playable creatures.
- The validator flags any creature trait without a parameter link, and any value that contradicts the `real` block.
- Tests for the new kind; existing worlds must not change.

## Step 3 — Council: run the batch
- Per world: a planet stage, then 3–5 species covering at least two trophic levels (the same food-web logic as `docs/briefs/trophic-web.md`), 1 "strangest species this physics could force", flora or producers, and a technosphere fact. If a world is probably lifeless (an ultra-hot lava world, say), the council says so honestly and proposes only extremophile or speculative life, marked `speculative`.
- Run with `tools/agents/agents.sh restart lore` (the autoloop is resumable). Then run validate, render and refcheck.

## Step 4 — Opus: review
- Read each world. Check the chains against the real data, check the science is honest (`speculative` where needed, no invented citations), check names are original (creatures) or modified (planets), and check that no two worlds feel the same.
- Output `docs/lore/EXOPLANETS.md`: a table with game name, real name, kind, key physics, the 1-line "why life looks like this", species count, and the verdict per world (kept, redo, merged).

## Acceptance
- Biochemistry mix meets the quota (at most about 40% water-carbon, at least 8 silicon worlds) and is reported in `EXOPLANETS.md`.
- 40 worlds with real data cited (retrieval date) and the validator passing.
- At least 120 species, each trait linked to a planet parameter; zero invented citations (refcheck).
- `EXOPLANETS.md` written. You review a contact sheet of the 40 worlds plus one creature card per world.
