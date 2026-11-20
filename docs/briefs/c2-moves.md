# Brief: C2 moves, recipes, resource meters, bone spines and rock armour (P4 §2.6, COMBAT-MOVES.md, G50–G54, G68)

Worktree `/home/diego/Desarrollo/cpore-wt/c2-moves`, branch `c2/moves-recipes` (from main `claude/v0.1-restore`). Work only here.
**Your sandbox cannot write git metadata and has no X11:** do NOT commit or take screenshots. Leave work uncommitted and write
`docs/MOVES-RECIPES-REPORT.md` (intended commit messages per slice, what you verified, golden changes, open questions, a capture
checklist for Sonnet). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.

Read: `docs/P4.md` (§2.0 contract, §2.6 recipes/resource meters/bone spines, tables, §3 acceptance, T-tests), `docs/COMBAT-MOVES.md`
(loadout of 4 slots + guard/dodge already exists; the C2 move list: claw swipe, peck, pounce, quill volley, roar with fear, stomp,
curl up, bone-spine frenzy; actuation table §7 is a PROPOSAL, do not implement actuation rules), `docs/DESIGN.md` G50–G54, G65, G68,
A25 (tiers are off behind `parts.tiers_on`), `docs/PARTS-NEST-REPORT.md` (parts/nest/eggs just merged: `parts.clues`, recipes = clues/2
placeholder: replace it with the real recipe model), `core/src/combat*`, `core/src/stage_parts.c`, `core/src/stage_world.c`, `core/src/stage_social.c`.

Other agents now: `c2/secrets-roster` (Sonnet: meteor shards, cave interior, nocturnal Acechalunas, a 6th species: spawns/placements in
`stage_world.c` and island.gd) and `c2/journal-polish` (Sonnet: Godot UI only). Keep your `stage_world.c` hooks minimal and isolated;
new logic in new files (e.g. `core/src/stage_recipes.c`, combat move rows in tables).

## Slices
S1 **C2 moves (C core, combat).** Implement the C2 moves from COMBAT-MOVES.md as data rows with their parts requirements, cooldowns,
counters and effects (fear for roar, knockdown for stomp, curl-up guard, pounce gap-closer, peck, claw swipe, quill volley projectile).
Moves are learnable by **Observe** where the spec says so (Espinodo's spine volley hint). The loadout UI already exists: make sure new
moves appear when the body supports them. `make tourney` gates must hold (report the matrix; add the new moves to the tourney).
S2 **Recipes + resource meters (C core).** P4 §2.6: recipe = ≥2 parts + 1 diet condition + resource meter; states unknown → hinted →
known → mastered; clue sources (observe, fossils, the spined fossil). **Calcium meter** (eating carcass bones fills it, firing spends it).
**Bone spines** = the first secret move inside the counter matrix and the same tourney gates (G53, G54).
S3 **Rock armour (G68).** Eating stones on the alpine slopes fills a **mineral meter** → tougher, slower (a temporary or part-like
modifier, your design within G68; document numbers as tunable). Stone nodes on alpine slopes, deterministic, reachable on foot
(use the planner's slope/water rules like the parts fossils).
S4 **Contract + Python + Godot (headless).** world-2 exposes recipes/meters; Python binding; Godot wiring minimal: meter bars in the
diegetic HUD style (docs/godot/UI-DIEGETIC.md), the new moves in the radial/loadout, whisper lines for recipe state changes. Headless
tests only.

## Rules
Determinism: integer/fixed math, `+ - * / sqrtf`, no libm trig; separate RNG streams as P4 T4 says. Goldens byte-identical unless a
slice must change them (regenerate once, document the first changed tick). Tests for every rule (`make test`), `make smoke`,
`make tourney`, Godot `--check-only` + headless suites you can run (`godot-test`, `godot-ui-test`, `godot-play-test`, `godot-parts-nest-test`).
