# Brief: C2 lineage ledger (L0), ancestors as cousins (A13), the family tree and the 16 creature types

Worktree `/home/diego/Desarrollo/cpore-wt/c2-lineage`, branch `c2/lineage-cousins`. Work only here. Never touch the
main checkout or other worktrees; never commit `.codex/`, `.kimi-code/` or anything from `~/Desarrollo/cpore-refs/`.
Commit per slice (clear messages); do not merge — Claude (Opus) reviews and merges.

Read first: `docs/ARC-PLAN.md` §7.1 (L0) and §9b, `docs/DESIGN.md` A13 and G-rows on lineage/DNA, `docs/CREATURE-ROADMAP.md`
C2, `docs/P4.md` §2.3 (DNA), `docs/godot/CAMERA-ZOOM.md` §3 (the "History screen" row: Spore's history screen is a
*mechanics and layout reference only*, Q4: copy no assets, names, icons or UI art), `core/src/lineage.c`, `core/src/stage_world.c`,
`bindings/python`, `godot/game/stage/*`, `godot/game/island/island.gd` (saves via `devtools/scenario.gd`).

## Other agents running now (avoid their files)
- `c2/social-loop` (Sonnet): befriend/observe/intimidate/eat, DNA meters, Q43 — edits `stage_world.c`, radial, card, HUD.
- `c1/movement-feel` (Sonnet): steering (new `steer.c`), slopes, camera, creature zoo — edits `walk()` in `stage_world.c`.
- `terrain/look-hydro` (Sonnet): terrain shaders, `terrain.c`, rivers, clouds.
Put your logic in your own files (`lineage.c` + new files, new Godot scripts). Hooks into `stage_world.c` must be minimal and
isolated (an "evolved" event, a cousin spawn, ledger calls at award points); list every hook in your report. Where you need
data the social agent is creating (befriend counts, DNA awards, eat), read it through a small interface/event you define, and
note it so the merge can wire it; do not implement their features.

## S1 — Trait ledger L0 (C core)
- Append-only ledger in `lineage.c`: entries `{tick, kind (trait_earned | part_gained | part_lost | evolved | deed), id, value,
  x, z, cause}`. Never edited or removed. Bounded capacity with a documented overflow rule (e.g. deeds aggregate into counters).
- Earned traits with explicit, tested rules (initial numbers, documented as tunable): hunter, social, nocturnal, burrower,
  aquatic, flyer, void-adapted (rules for media not yet built are defined but cannot fire yet; say so).
- Deed counters the type system needs (S4): kills, befriends, intimidations, carcasses eaten (meat), plants/fruit eaten,
  observations, distance travelled, time at/near the nest, digging/building actions, fights started vs fled, night activity.
- Saved in the save file (scenario format), restored on load, reproduced bit-exact by replay. Observation world-2 gets a
  compact `lineage` block; Python binding exposes it; export function writing the format Band will read (JSON, documented
  schema `cpore.lineage/1` in docs).
- Determinism: integer/fixed math, no libm trig; existing goldens byte-identical when no ledger-affecting event happens
  (if a hash must change because state grew, explain and regenerate once).

## S2 — Evolution step + ancestors as cousins (A13)
- `evolve` event: the nest editor is a later slice, so add a console/test trigger `evolve <creature-file>` (and a C entry point)
  that records `evolved` + part diffs in the ledger and bumps the generation.
- The previous form spawns as a wild **cousin species**: its body (genome/profile), a home range near where that generation
  lived most, behaviour/temperament/diet derived from its parts and the ledger, a trust bonus toward the player (initial value
  documented), species name auto-generated ("<player species> gen 2" by default, renamable later).
- Card shows "cousin · generation N". Cousins count as species for the Q43 loop only if the spec says so — check P4/A13 and
  report; default: they do not count toward progress.

## S3 — Family tree screen (Godot), Spore-like layout, our own art
- A timeline/tree: generations left→right (or bottom→top), each node a live-rendered portrait of that generation's body
  (render the creature mesh to a SubViewport; no captured images), with: parts gained/lost (+/−), traits earned, its
  **creature type** (S4) as a badge and short name, generation number, and where its cousins live now (click → strategic map
  pin). Branches for cousin species. Opened from a key (pick a free one, add to the key legend D13) and the pause menu.
- Clean, readable, our own visual style (fits the existing UI theme). Evidence: xvfb captures with 3+ generations.

## S4 — The 16 creature types (owner request: "like the 16 personality types")
Four behaviour axes measured from the ledger's deed counters (not chosen in a menu: you become what you do). Each axis is a
continuous score −100..+100 with a dead zone; the letter is its sign. 2⁴ = 16 types.

| Axis | − pole | + pole | measured from |
|---|---|---|---|
| Approach | **A**ggressive | **S**ocial | kills + intimidations vs befriends + gifts |
| Diet | **H**unter | **G**atherer | meat eaten + hunts vs plants/fruit eaten + foraging |
| Way of life | **R**oamer | **I**ndustrious | distance + new places vs nest time + building/digging/hoarding |
| Temper | **B**old | **W**ary | fights started, approaching bigger creatures, deep dives vs observing, stealth, fleeing early |

- A type code like `S-G-I-W` maps to a type name and a one-line description. Draft the 16 names and descriptions in
  `docs/CREATURE-TYPES.md` (our own names, evocative, no Spore or MBTI names or trademarks; e.g. Spanish-flavoured or plain
  English — offer both columns) and mark them **draft, owner approves**.
- The type is computed per generation at the moment it evolves (and shown live for the current one); the family tree shows
  how the lineage drifted (e.g. Aggressive→Social).
- Each type grants ONE small, documented perk (initial values, tunable, e.g. Social: +10 trust on first meeting; Hunter:
  +10% carcass food; Industrious: nest actions 15% faster; Wary: observe 20% faster) and the type is recorded in the ledger
  and exported (later stages read it). Perks must not break the combat tourney (`make tourney` must still pass; report).
- Tests: axis scoring, dead zone, type code from fixed deed vectors (all 16 reachable), perks applied once, determinism.

## Rules
- Tests in `make test` for every rule; Python smoke; Godot tests per repo convention.
- Godot: always `timeout`, `--check-only` first, headless/xvfb software rendering, `nice -n 10`. Kill only processes you started,
  by pid (never `pkill -f`). The owner is playing the game from the main checkout: leave it alone.
- Docs: `docs/LINEAGE.md` (ledger, schema, trait rules, cousins), `docs/CREATURE-TYPES.md`, CREATURE-ROADMAP "Where we are",
  BACKLOG states, key legend.
- Report per slice: what's in, commits, test output, goldens status, tourney status, the `stage_world.c` hooks, deferred items.
