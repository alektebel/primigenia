# Owner decisions after the sol launch (apply during integration of c2/parts-nest) — DESIGN.md A25
1. Creator at game start: only a few basic parts (pico, pata, ojo + whatever a valid starter body needs) and a small DNA budget; all other parts locked until discovered.
2. Editing only at the nest (as built).
3. Explicit "Evolve" button: in nest-edit mode, trying parts, repainting, rearranging are free and do NOT call cp_stage_evolve; pressing Evolve spends DNA (purchases/levels), calls cp_stage_evolve once (new generation + cousin + ledger diff). Repaint/rearrange-only changes apply without a new generation.
4. Zero eggs: show the end-of-lineage moment and return to the last save (no wipe, no new game).
5. Levels 1-5 active; tiers T1/T2 implemented but disabled behind a flag/setting (off) — tests may cover them with the flag on.
6. Fossils/bones also give recipe clues (2 clues unlock a recipe, Q-12) — wire to the existing recipe/clue model if present, else add the clue counter and leave recipes for the bone-spines slice.
