# Species v8 report

Worktree: `/home/diego/Desarrollo/cpore-wt/species-v8`, branch `c2/species-v8`.
Base: `7530253a9bf29ab49d992b552dd514eba4353c7e`. Work is **uncommitted**. No screenshots, X11, commits, git metadata writes, or edits to `.codex/`, `.kimi-code/`, other worktrees, or the main checkout.

## S1 — Brujula and Corona

Intended commit: `feat(species): simulate Brujula and Corona and migrate v7 saves`

* Species 7 and 8 (zero-based C ids **6 and 7**) extend both species tables and the social/parts arrays. Brujula is territorial and omnivorous (filter feeding, mollusks, detritus and carrion); Corona is timid, carnivorous (plankton, benthic invertebrates and carrion), and crepuscular. Sight/home roam radii are 14/10 m and 10/8 m respectively.
* Brujula probes at **0.3 m/s** and escapes/returns at **2.0 m/s**. Corona's speed is **1.4 m/s**. The two new species use those requested speeds directly; the old species retain their existing wild-motion multiplier. Steering, slopes and turning still affect achieved speed. Corona hunkers in bright daylight.
* Existing `plan` genomes build their radial ActorHosts. `StageSetup.add_radial` reuses `RadialFauna.plan` exactly: four Brujula at the shelf and two Corona on the tide-pool flat (existing cave fallback retained). Legs are 5/6 for C steering. Only Cuarteta is ambient; the land species have no visual-only duplicates.
* Babosa's group is reduced from four to **three** so the full roster fits the existing 24-actor limit (1 Garfio + 11 original herd animals + 3 Acechalunas + 3 Babosa + 6 radial animals). Three still suffice for species alliance resolution.
* Normal befriend, gift, observe, intimidate, eat, combat, loot, ally signatures and journal paths handle both species. New observe chains use existing combat moves (Brujula `guard`, Corona `tail_strike`); the lore abilities and tides remain deferred. Preferences reach bit **63** without widening the existing masks.
* Brujula's frontal-impact weakness becomes a strike against its soft underside between raised arms when the tube feet release. The source JSON and generated lore page carry the correction; the lore journal and the in-game observed clue have English and Spanish text. The field journal has eight species pages and 24 translated clues. Diet presentation also uses the species table instead of treating every id >= 2 as carnivorous.
* Snapshot **v8 reads v7 and v8**. A frozen v7 ABI fingerprint rejects incompatible layouts; migration copies the unchanged prefix and expands each six-species social/parts array, zeroing new slots and AI clocks. It verifies the original v7 state hash before accepting the result. The compressed fixture was captured with the actual v7 core before implementation, not produced by changing a v8 header. Its generator is guarded against use with a v8 core. Existing entities and progress are preserved; migration does not insert new animals into an already saved roster.

## S2 — Garfio's grace minute

Intended commit: `feat(ai): give Garfio a grace minute after starting and respawning`

The rate is **10 Hz**, verified in `CP_STAGE_DT = .1f`, `StageWorld.DT = 0.1`, and the bridge accumulator. Thus **60 seconds = 600 ticks**; the brief's 3000 ticks would be five minutes. The 12000-tick day is likewise 20 minutes.

Garfio patrols during the first 600 ticks and for 600 ticks from hatchling respawn. Autonomous hostility is suppressed; a player attack can still start a fight and provoke aggression. The respawn deadline is captured by the AI from the respawn event, persisted in snapshots and hashed. Player movement/fall integration was not edited.

## S3 — Acechalunas wakes by day

Intended commit: `feat(ai): wake daytime Acechalunas within six metres`

Daylight sleepers stay hidden and unavailable outside **6 m**. The boundary is inclusive: approach to 6 m wakes them immediately, and their territorial AI reacts normally. They stay awake for **150 ticks / 15 seconds** from the last nearby-player tick, then hide again if the player has left. An active fight keeps them awake. Per-animal wake deadlines persist and participate in hashes. Night activity and the existing dark trust bonus remain in place.

## Goldens

Regenerated **once**, after implementing all three rules, by replaying the five existing `.log` recipes with `build/world_cli --replay` and writing their `.hashes`. Recipes were not changed. Counts are zero-based tick indices:

| Golden | Hashes | Changed | First changed |
|---|---:|---:|---:|
| world-1 | 3000 | 3000 | 0 |
| world-42 | 3000 | 3000 | 0 |
| world-987654321 | 3000 | 3000 | 0 |
| world-debug-42 | 3000 | 3000 | 0 |
| world-field-1 | 300 | 201 | 99 |

Garfio's initial patrol decisions replace hunting, changing subsequent movement, RNG consumption and fights; respawns also carry the new grace deadline. Combat goldens, terrain hashes, route fixtures and bilateral mesh fixtures were **not regenerated**. Existing encounter/cliff/god-mode tests now start after the grace minute so they still exercise their original fight rules. The Python CLI smoke follows the CLI's rejected-order handling when the scripted `flee` has no remaining threat.

## Verification

The new `radial-species-test` is part of `make test`. It was run red before implementation and now passes:

* Both species accepted by reset; home roam bounds, legs, temperaments, speeds and Corona's daylight hunker.
* Befriend, gift, observe (all three clues), intimidate and eat on **each** species, including the last preference bit.
* Genuine v7 migration preserves clock, RNG-backed simulation, social progress and masks, parts and secrets; new slots start empty. Hash/layout/size/field failures leave the destination unchanged. A migrated v8 snapshot replays identically.
* Garfio patrol during grace, exact expiry, explicit provocation, actual hatchling death/respawn, renewed expiry and saved grace clock.
* Acechalunas outside/at the 6 m boundary, normal territorial reaction, sleep delay and saved wake clock.

Godot tests additionally verify all three seeds' deterministic habitat placements, every land radial spot becoming a C spawn with the right legs, a real field reset accepting those spawns, the 24-animal cap, four Brujula/two Corona in the game setup, ambient-only Cuarteta, journal pagination and every clue translation.

Final gate results are recorded below once the running full suites finish.

### Reproduction and environment

Commands use `nice -n 10` and `timeout` for Godot. `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `XDG_CACHE_HOME` point into `/tmp/species-v8-*`, keeping caches/settings inside writable paths. The GDExtension was compiled directly into this worktree's ignored `build/godot-extension/` and `godot/bin/`, with the existing `_agent/godot-cpp` headers and archive read-only; SCons was avoided because its dependency build can write into that shared directory. The extension links this worktree's `build/libcpore.a`. No dependency checkout was changed.

A direct `--check-only --script game/stage/stage_ui.gd` cannot resolve the project's `Game` singleton in isolation. Its actual runtime compilation was separately verified with a headless SceneTree after autoload registration (`StageUI compiles with the Game autoload`). The independent setup/fauna/string/test scripts pass `--check-only`.

## Open questions and limits

* The chosen day-wake delay is 15 s; the owner approved waking on approach but did not prescribe this duration. Radius and delay are named constants in `world.h`.
* The 64-bit preference mask is full at eight species; adding a ninth requires a format/data-model change. Cuarteta remains ambient pending swimming.
* Restored v7 games retain their saved roster; start a new game to get the newly placed radial animals. Old v7 saves have no historical wake/grace deadline; new clocks start empty and subsequent respawns establish grace normally.
* The certified route graph remains the requested 288 trips per seed. New coastal habitat coordinates are checked by the bridge/placement tests; this change does not expand that route graph.
* Tides, the player's radialisation purchase, lore-only radial skills and visual evidence remain outside this brief.

## Integration (2026-11-21)

Merged on top of moves-recipes and first-quest. Snapshot is now **11** (v8 in the branch). The v7 migration (`stage_snapshot_v7.inc`, `species-v7.snap.gz`) was dropped: it copied a frozen v7 prefix into a layout that now has recipes, run/fall and dig state in the middle, and the project rule is exact-version snapshots. World goldens world-42, -987654321 and -debug-42 regenerated once (changed from tick 0: new roster); world-1 and world-field-1 unchanged. Evolving needs a free wild slot for the cousin, so the radial roster is capped at 23 (a Brujula is trimmed, 4 -> 3; both Corona stay): owner to decide how many free slots to keep for cousins. Play test starts its fight by attacking Garfio (grace minute).
