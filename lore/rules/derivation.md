# Rule: derive forward from a few fixed constraints (the Weir method)

Owner, 2026-11-21. Applies to every world the lore council writes (Primigenia, the food web, the 40 exoplanets, all autoloop worlds). Source: Andy Weir's account of building Erid, Rocky and Astrophage (*Project Hail Mary*), in `docs/RESOURCES.md` X5. Our Erid world (`worlds_seed.json` id `erid`, A20) already comes from this book.

## The method
1. **Fix only a few constraints**, the measured data (for a real exoplanet) or the chosen premise (for a fictional world). Everything else is **derived, not decided**: "I didn't decide that, I derived it".
2. **Follow the causal chain in order**, and **design the biosphere before the characters.** The playable creatures come out at the end of the chain, after the producers and the food web. They are never the starting point.
   The chain for Erid (worked example):
   - premise: liquid water is needed
   - close to the star, so high pressure keeps the water liquid: about 200 °C and about 29 atm
   - solar wind strips light gases, so the atmosphere is heavy ammonia, held by strong gravity
   - liquid core plus fast rotation give a strong magnetic field and a flattened planet
   - the air is too thick for light, so echolocation replaces eyes
   - about 2 g, so very strong bodies
   - no free oxygen, so each animal carries its own gas cycle (a "hive that walks")
3. **Make every number auditable.** Each world has a **derivation sheet** (`lore/worlds/<id>.derivation.json`): every derived quantity with its formula or source, the inputs it used, and a confidence level (`measured`, `derived`, `estimated`, `speculative`). The validator recomputes what it can:
   - surface gravity from mass and radius
   - equilibrium temperature from the star's luminosity and the orbit
   - atmospheric scale height
   - water's boiling point at the stated pressure
   - Jeans escape for the light gases
   - the A37 / D-28 oxygen thresholds

   Any mismatch beyond tolerance fails the world. Explicit numbers expose errors, and that is the point: Weir's own 29 atm slip shows how.
4. **One declared violation at most.** A world may break known physics in **one** named place (Weir: only at the quantum level, in Astrophage), written in the sheet as `violation: {what, why, where it shows in play}`. Everything else is consistent.
5. **Internal coherence beats the source data.** If a real measurement is later revised (Weir's starting planet turned out not to exist), the world stays valid as long as the chain is coherent. Record the data's retrieval date; never quietly change a measured input. A revision is a new world version.
6. **Spreadsheet first, prose second.** The council writes the derivation sheet before any creature text. The prose (journal lines, cards) may only state what the sheet supports.

## How agents use this
- **Planet stage:** produce the derivation sheet, chain items in order, each item tagged with its confidence level.
- **Creature stage:** every trait cites a sheet item (`because: <sheet key>`). The validator rejects traits with no `because`.
- **Astrobio referee:** audits the sheet (formulas, units, order of the chain) before reading any creature.
- **Caveat on the Erid figures:** 6 h rotation, ×25 magnetic field, 2.1 g and 96.415 °C (Astrophage) come from interview summaries. Medium confidence; check them against the Cleo Abram transcript before using them as data.
- Not this method's source: *Why World Build* (Stephen Gillett) is another author and tradition. It can be a separate reference, never attributed to Weir.
