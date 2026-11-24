# Brief (Codex sol): brujula and corona as real species, Garfio's grace minute, Acechalunas wakes by day
Worktree `/home/diego/Desarrollo/cpore-wt/species-v8`, branch `c2/species-v8`. **Your sandbox cannot write git metadata and has
no X11: do NOT commit or take screenshots.** Leave work uncommitted; write `docs/SPECIES-V8-REPORT.md` (intended commit messages
per slice, what you verified, open questions). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.
Owner decisions (DESIGN.md A27). Read `/home/diego/Desarrollo/cpore-wt/_agent/briefs/radial-bodies-plan.md` (brujula, corona,
owner questions and the proposed numbers), `docs/godot/CREATURE-RADIAL.md`, `docs/SECRETS-REPORT.md` (how Acechalunas and Babosa
were added as species 5–6: the pattern to follow), `core/src/stage_world.c`, `stage_social.c`, species tables, the snapshot code,
`godot/game/island/radial_fauna.gd` (today brujula/cuarteta/corona are visual only), `lore/worlds/primigenia.json` (their lore).
S1 **brujula and corona become C species 7 and 8** (radial bodies via the `plan` key): home ranges where radial_fauna places them
now (corona on its tide-pool flat), temperaments and diets from lore, speeds brujula 2.0 fleeing / 0.3 roaming, corona 1.4;
befriend/observe/intimidate/eat work like the other species; observe clues; journal entries; snapshot version 7 → 8 with
migration of v7 saves. Tides later (not now). Reword brujula's lore weakness "frontal impact" to something its radial body
makes plausible (lore/ JSON + journal string, ES and EN). Godot: radial_fauna stops spawning visual-only copies of species now
simulated in C (cuarteta stays visual-only).
S2 **Garfio's grace minute**: Garfio does not hunt or charge the player during the first 60 s of game time (3000 ticks at the
current rate: verify) after a new game or a hatchling respawn; it still patrols and can be provoked by attacking it.
S3 **Acechalunas wakes by day when approached**: asleep and hidden by day, but if the player comes within its wake radius
(propose ~6 m) it wakes, reacts by temperament, and goes back to sleep after a while.
Goldens: regenerate once, documented (what changed and why). Tests in `make test` for every rule (species present, ranges,
speeds, social verbs on both, snapshot v7→v8 migration, grace minute both ways, day-wake radius). `make smoke`, `make tourney`,
routes 288/288 per seed. Godot headless `--check-only` and the headless suites you can run (`timeout`, `nice -n 10`).
Another agent is integrating `c2/run-fall` (player running/falls in stage_world.c): keep your stage_world.c edits confined to
species/AI functions.

S2b (owner, DESIGN.md A31): besides the grace minute, Garfio stays non-hunting (patrols, can be provoked) until the player has
evolved at least once (first `cp_stage_edit`/evolve in the ledger); test both conditions.

NOTE (after run-fall merged): main now uses snapshot format **8** (run/fall state). Before you continue, merge nothing yourself,
but write your code so it bumps the format from whatever `main` has to the next number (9) with a v8→v9 migration; the
integrator will rebase. Read the current snapshot code on claude/v0.1-restore (`git show claude/v0.1-restore:core/src/...`).
