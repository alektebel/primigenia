# C2 lineage handoff — 2026-11-19

Worktree: `c2-lineage`; branch: `c2/lineage-cousins`. Implementation is available
for review. No merge was attempted. **No commits could be created:** Git cannot
create `/home/diego/Desarrollo/cpore/.git/worktrees/c2-lineage/index.lock`
(`Read-only file system`). The failed `git add` left the index unchanged.

**S1 — ledger.** Append-only integer ledger in `lineage.c`, explicit trait rules,
saturating lifetime/generation counters, aggregation at 384 deed records, 1,536
entry capacity with enough reserved capacity for all 16 generations. Opt-in
tracking preserves old replay hashes. The Godot game enables it when installing
its founding body. C scenario snapshots own the state; readable scenarios embed
the full JSON export. world-2 has a compact block, Python has full export/award
and perk helpers. Snapshot clients/tests now size buffers from the payload.
Intended commit: `feat(lineage): add append-only trait ledger and saved deed counters`.

S1 verification: native ledger tests, full `make test`, Python `make smoke` pass.
Existing world and combat golden hashes match; none regenerated. The larger POD
changes the snapshot layout fingerprint, so old snapshots need their scenario
recipes rebuilt. Tournament passes. New-world histories replay from their saved
start snapshots; evolution starts a fresh snapshot-backed segment.

**S2 — evolution and cousins.** `cp_stage_evolve` and console
`evolve <creature-file>` preserve bodies/profiles, record part diffs, finalize a
generation, and create one wild cousin per old generation. Homes derive from
the generation's most occupied 64m cell. Spawn candidates rotate between two
rings around the home; old-body obstacle radius is checked. Bodies are dressed
on spawn and restore. Matching actors survive restore, preserving existing UI
and animation references. Cousins have a distinct logical species identity,
auto-generated name, a documented +20 trust bonus and **no Q43 progress credit**.
Intended commit: `feat(lineage): preserve evolved forms as wild cousin species`.

S2 verification: native evolution tests cover part diffs, home residency,
invalid/full evolution rejection, 16 generations, cousin identity/progress,
profiles and saved replay. Godot tests cover three real studio bodies, scenario
save/read/load, hash restoration and segment replay. Existing goldens unchanged;
tournament passes. Trust awards await social merge wiring. Independent cousin
breeding/genome drift and renaming remain later A13 work.

**S3 — family tree.** T and the pause menu open a horizontal generation timeline
using the existing palette. Each body renders live into its own SubViewport.
Nodes show part diffs, new traits, type badge/name, generation and drift from the
previous type. Cousin branch buttons center the strategic map and replace its
selected home pin without teleporting the player. D13 legend includes T.
Intended commit: `feat(ui): add live lineage portraits and cousin map pins`.

S3 verification: check-only parsing and headless lineage tests pass with three
live portraits, two cousin buttons, scenario persistence, pause/menu behaviour,
map zoom/centering and pin replacement. Screenshot capture was attempted using
xvfb/software GL but **X11 display creation is blocked in this sandbox**; no PNG
was fabricated. Run `make godot-lineage-evidence` in a display-capable session
before visual approval. The shared project reports Dev-console shutdown leaks even with an empty
script; integrated tests also report cleanup leaks after their checks finish.
The full existing play test passes **208 checks, 0 failures**, including loading
and then selecting/fighting the retained actor. A real-island lineage test passes
the console evolution, founding cousin body, three-node tree and earlier-save
restore checks. A cold terrain cache must be warmed first for the existing play
test: its frame-budget wait can expire before asynchronous terrain preparation.

**S4 — sixteen types.** Four integer axes, documented dead zone/inheritance,
16 reachable vectors, frozen generation type entries and live current type.
English and Spanish names/descriptions are **draft, owner approves** in
`CREATURE-TYPES.md`. Exactly one small perk per type, with monotonically numbered
award/action events preventing duplicate application; no combat stat changes.
Intended commit: `feat(lineage): derive sixteen creature types and idempotent perks`.

S4 verification: all 16 codes, all perks, dead zone, uint32 saturation and repeated
event suppression pass. `make tourney` passes (worst field mean 62.3%, worst
pooled pair 72.2%). Existing combat goldens all match 10,000 hashes per seed.
Perk calculation is implemented and tested; social/nest producers must call it
at their own award/action-start points. Those other agents' mechanics were not
implemented here.

**Every `stage_world.c` hook:**

- `start`: one successful player-started-fight deed.
- `finish`: kill deed (including double KO) and completed-flee deed.
- `cp_stage_step`: capture old centimetre position and call the separate lineage
  tick adapter after movement; it owns distance, nest/night activity and residence.
- `cp_stage_hash`: include canonical ledger/ancestry hashes only when tracking is enabled.
- `cp_stage_observe_v`: compact lineage/type block and cousin generation/logical
  species id/progress exclusion on nearby cousins.
- `cp_stage_layout`: fingerprint the new POD members.

Cousin spawning and evolution live entirely in `lineage_world.c`; spawning reuses
`cp_stage_debug(SPAWN)`. No `walk()` or social simulation rules were rewritten.
The small `stage_ui.gd` edit adds the cousin name/generation and derived diet and
temperament to the existing card information.

**Merge wiring:**

- Call `cp_stage_lineage_award` once on successful befriend, intimidation, eating,
  observation, gift and other deed awards. Counter ids are in `ledger.h`.
- Read `cp_stage_cousin_generation` / `cp_stage_species_counts_progress`, or the
  equivalent observation/entity metadata. Never credit a cousin to its AI
  template's Q43 species. Apply its +20 trust bonus once at first meeting.
- Call `cp_stage_lineage_perk` at reward/action start using increasing serials
  per kind/generation. Trust/meat are rewards; nest/observe are durations.
- Unsupported swimming/flight/void award kinds reject until their mechanics exist.
- Keep each exported log's starting `.cpstate`; body changes create segment
  boundaries rather than embedding external files in numeric input logs.

**Remaining before the brief can be called fully delivered:** writable Git
metadata and four slice commits; xvfb visual capture/review; social/nest consumer
wiring at merge; owner approval of draft names and balance values. The public
limits and interchange schema are in `LINEAGE.md`.

New-code line coverage: ledger additions 100%, lineage world adapter 97.06%,
creature types 100% (gcov; legacy genome converters excluded from these figures).
