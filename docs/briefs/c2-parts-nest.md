# Brief: C2 closes the loop: part discovery, nest, editing with DNA, eggs (P4 §2.4, 2.5, 2.7, Q-6, Q-7)

Worktree `/home/diego/Desarrollo/cpore-wt/c2-parts-nest`, branch `c2/parts-nest` (from main). Work only here.
**Your sandbox cannot write git metadata and has no X11:** do NOT commit or take screenshots. Leave all work uncommitted
and write `docs/PARTS-NEST-REPORT.md` (intended commit messages per slice, what you verified, open questions, what is left).
Claude/Sonnet will commit, integrate and capture evidence. Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.

## Why
Today the player hunts, befriends and eats and earns DNA, but **nothing spends DNA**: the loop does not close. This brief
closes it. Spec of record: `docs/P4.md` §2.0 (contract), §2.3 (DNA), §2.4 (part discovery), §2.5 (tiers/levels), §2.7 (editing
mid-game at the nest), §3 (acceptance), §4 Q-1..Q-20 — all approved as recommended (DESIGN.md G55). Read also
`docs/DESIGN.md` A13 (cousins), A24 (skeleton per body, actuation per limb, single parts), `docs/LINEAGE.md` (evolve, ledger,
cousins: `cp_stage_evolve` already exists and is called by a console `evolve` command), `docs/CREATURE-TYPES.md`,
`docs/COMBAT-MOVES.md` (loadout: `loadout` only within 12 m of the nest; there is a nest position in setup), `core/src/stage_world.c`,
`core/src/stage_social.c`, `core/src/lineage.c`, `core/src/lineage_world.c`, `core/src/combat*`, `godot/studio/` (the creator),
`godot/game/stage/*`, `godot/ui/*` (new diegetic UI: `docs/godot/UI-DIEGETIC.md`).

## Slices
S1 **Discovery (C core).** Unlocked-part set + codex; kill drops with the P4 tables (200/350 permille, pity on the 4th dry
kill, deterministic `loot` stream), ally signature part, carcass bone item, old-carcass and surface fossil nodes placed at
world creation (deterministic, reachable on foot: use the walk grid / route rules), `inspect #id` verb (20 ticks), `part_found`
event with source, duplicates convert to cost/4 DNA (Q-10). Observation world-2 lists discovered parts. Python binding.
S2 **Nest (C core).** One fixed nest marker in the start valley (Q-6) using the existing setup nest; respawn point; editing
and loadout allowed only within 12 m. Leave a clean hook for the later C3 nest-site choice (G24).
S3 **Shop and editing (C core + contract).** `dna_balance` spending (exists: `cp_stage_social_spend`): buy a discovered part
(its cost), part **levels** 1–5 (price multiples 2/4/8/16, Q-19) and **tiers** T1/T2 (forms, 60/150 DNA after usage
milestones 25 hits + 3 fights won / 75 + 10, Q-19); genome `cpore.creature/5` with `level` and `tier` per part, v4 migrates
to level 1 (Q-2); the profile uses rule × level. Editing at the nest validates the genome in C (G4) and applies it via
**`cp_stage_evolve`** so the ledger records part diffs and the previous form becomes a cousin (A13). Q-5: rearranging is
free, no refunds; levels/tiers belong to the part id. `dna_total` never decreases.
S4 **Eggs and death (Q-7).** Egg counter starts at 3; on death respawn at the nest as a hatchling (max HP ×0.6 for 1,200
ticks); zero eggs loses the stage. This changes every golden that contains a death: regenerate once, documented.
S5 **Godot wiring (minimal, headless-testable).** Open the creator (godot/studio) in an in-game "nest edit" mode only at the
nest: parts list shows only discovered/owned parts, prices and DNA balance, level/tier purchase, confirm = evolve. Keep the
A24 realism layer and the player's paint. A `part_found` whisper line through the diegetic UI's existing whisper API.
Journal stub: discovered parts list. (No screenshots: list what Sonnet must capture.)

## Rules
Determinism (integer/fixed math, `+ - * / sqrtf`, no libm trig); existing goldens byte-identical except where S4 must change
them (document). `make test` (add tests for every rule: drop rates over N seeds, pity, signature on ally, inspect, nest-only
editing, prices, level/tier milestones, migration v4→v5, evolve via edit creates a cousin and ledger diff, eggs and loss),
`make smoke`, `make tourney` (levels must not break the gates; report). Godot: headless `--check-only` and headless tests
only (no display in your sandbox). Report everything in `docs/PARTS-NEST-REPORT.md`.
