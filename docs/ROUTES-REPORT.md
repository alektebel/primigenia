# Route certification handoff — 2026-11-19

**Incomplete: C1 is not closed.** The strict required-route gate is implemented and deliberately remains red.
The brief's requirement that `make test` pass is **not met**. No terrain repair has been implemented to make
the failed required routes traversable. Do not interpret the separate NAV pass as curated-route acceptance.
All changes are uncommitted in this worktree; no screenshots, X11, commits or other-worktree edits were used.

| Slice | Result |
|---|---|
| S1: data, C simulation, reporting | Implemented; required round trips fail as detailed below. |
| S2: player ceiling and planner agreement | Player exemption removed; climb, holding ceiling and lateral bank clearance checked. NAV gate passes. Required outer routes still need terrain/placement repair. |
| S3: arrival / blocked feedback | Implemented and tested through C world-2 and Godot native state; visual HUD acceptance remains unverified. |

## Reviewable slices and intended commit messages

1. `test(routes): add strict curated round-trip certification for three seeds`
   — `tests/test_routes.c`, `tests/routes/`, `tools/routes/`, the `routes_test`/`routes-test` Makefile targets and `make test` gate.
   JSON fixtures contain actual StageSetup nest/Garfio/herd positions, all cave records, terrain identity, explicit required
   places and pairs. Text fixtures are generated derivatives checked against JSON. The headless placement exporter is
   `godot/game/tests/routes_fixture.gd`.
2. `fix(nav): apply the player slope ceiling and reject snapped arrivals`
   — isolated navigation/route-following hunks in `core/src/stage_world.c` and regressions in `tests/test_steer.c`.
   Full-gradient checks use the body's holding threshold capped at 1.26, plus directional climb and 1 m lateral clearance.
   The player obeys the same ceiling and capped slide rule as wildlife. Cache identity now includes stall/slide multipliers.
   Larger detours required increasing the bounded A* expansion cap from 120,000 to 500,000. No terrain bytes changed.
   Field gradients also avoid repeating the same terrain dispatch four times, with identical samples/math.
   A target with no walkable final connection is rejected instead of silently reporting arrival at a snapped nearby cell.
3. `fix(world): expose durable route outcomes to the Godot UI`
   — `path_failed` gains an additive `reason`; continuation failures set the same blocked/error feedback as ordinary replan failures.
   Godot exposes a separate `route_events` array to the UI, which displays `Arrived` / `Blocked: <reason>`.
   Events use the existing schema/types and are not hashed. A headless native-state test checks once-only delivery and
   independence from agent acknowledgement. The Python ctypes binding also needed the existing steering-v3 `legs` and
   `player_legs` fields: its old 17,604-byte setup was 100 bytes too short and `make smoke` crashed with heap corruption.
   It now matches the native 17,704-byte layout; smoke passes.
4. `docs(routes): record certification failures and measured navigation costs`
   — this report, the three route evidence tables, NAV/locomotion notes and headless heights evidence.

No lineage, evolution, cousin spawn or ledger hooks were edited. No new simulation module was needed; the core changes
are confined to existing navigation, movement-ceiling and route-result code.

## Required graph and results

Nine bodies × eight required pairs × both directions = **144 trips per seed**, each replayed to the same tick-hash digest.
The real Merodeador is four-legged, radius 3 m, speed 4; the other bodies use 2/4/6/8 legs and radii 0.5/4 m.
There are no teleport/debug moves during a trip and no combatants. Every successful trip must emit `arrived`, finish
within 0.3 m and 20,000 ticks, stay out of deep water and respect the 1.26 gradient ceiling. Failed routes return a
nonzero process status; the gate does not turn them into expected successes.

| Seed | Required trips reached | Failures |
|---|---:|---|
| 1 | **122/144** | First cave entrance: all 18 directions/bodies. River gap: both directions for the two biped sizes (4). |
| 7 | **108/144** | First cave entrance and river gap: all 36 directions/bodies. |
| 42 | **122/144** | First cave entrance: all 18 directions/bodies. River gap: both directions for the two biped sizes (4). |

The six local destinations (Garfio, three herd home ranges, start valley and lake shore/water approach) reach **108/108**
trips on each seed. Full per-route tick counts, initial planned and actual walked distance, maximum grade, shallow-ford
entries, blocked ticks, replans and first/repeated planning times are in:

- [seed 1](evidence/routes/seed1.md)
- [seed 7](evidence/routes/seed7.md)
- [seed 42](evidence/routes/seed42.md)

Cave endpoints are the actual first generated entrance, not a relocated gentle approximation. Seed 1's entrance itself
has gradient approximately 1.3044, above the ceiling. Other cave records are retained for later curation; this does not prove
that every other possible cave is unreachable. Named spring, fossils and meteor shards have no gameplay placements;
the default disables the volcano, so there is no crater rim. They are explicit TODOs with proposed coordinates and sources
in [the fixture notes](../tests/routes/README.md), not fabricated successful routes to the origin.

Diagnostic experiments (only ignored build files): disabling rivers did not make the seed-1 biped outer route pass;
a 2 m navigation grid and tested nearby approaches also did not resolve it. Consequently, a river-only carve adjustment
has not been demonstrated to be sufficient. Those experiments were not retained as gameplay changes.

## Verification and costs

- `make test`: **FAIL at the new required-route gate**. Earlier terrain, world, social, NAV, steering, native core,
  combat, tournament-unit and combat-golden checks pass. All five existing world replay goldens match unchanged.
- `make smoke`: **PASS** after correcting the pre-existing ctypes layout mismatch.
- `make tourney`: **PASS**, including the balance checks.
- `build/steer_test`: **PASS, 259 checks**. The new player-slide regression was separately linked against the original
  `stage_world.c`: it fails on `slid`, demonstrating the old exemption; it passes with these changes. Synthetic tests
  also check runtime path failure, retained reason after a later step, event acknowledgement and successful arrival.
- NAV: **20/20 seed 1; 19/20 seed 7; 19/20 seed 42**. Each test also passes replay and mid-path snapshot determinism.
- Headless Godot route UI-state events: **PASS, 0 failures**. No actual HUD rendering or owner interaction was tested.
- Headless Godot heights: **PASS, 15 checks, 0 failures**; **18/20** grid arrivals, **0** unsafe chase ticks.
  Median field time **20.1 us/step**, flat **13.6 us/step**, both timing thresholds pass. The original single sequential
  timing sample failed under variable scheduling (including one isolated attempt); timing now uses three interleaved
  identical 10,000-step trials per mode and compares medians, with the existing <2x and <50 us thresholds unchanged.
  The test now measures remaining polyline distance
  for its no-progress check: valid bank detours can initially increase distance to the destination. The 1,200-tick
  no-progress window and 12,000-tick overall budget are unchanged; the arrival gate now counts both blocked and stuck
  runs when requiring 18/20, rather than accidentally excluding stuck runs.
- `git diff --check`: PASS. No goldens regenerated: existing golden hashes remained identical; terrain version stays 4.

Planning is substantially slower than the previous documented implementation. These are measured wall-clock costs,
not deterministic outputs or dedicated hardware benchmarks; some runs overlapped other tests.

| Seed | Curated worst cold / repeated warm plan | NAV first-pass mean / worst | NAV warm worst |
|---|---:|---:|---:|
| 1 | 599.775 / 11.583 ms | 381.55 / 3280.75 ms | 176.76 ms |
| 7 | 0.319 / 0.134 ms | 155.81 / 908.21 ms | 189.99 ms |
| 42 | 583.171 / 41.012 ms | 274.83 / 1354.93 ms | 832.97 ms |

Curated cold measurements explicitly invalidate derived grid state before each trip; warm repeats the same request
with its visited edges cached. The NAV first pass shares a progressively filled cache across its 20 targets; its warm
pass repeats those targets. No full-grid prefill timing was measured here. Seed 7's cheap curated plans reflect immediate
outer-target rejections, not good far-route performance. The increase in search cap and stricter checks need optimisation
before claiming acceptable loading/command latency. Static planner storage grows by approximately 1.52 MB for the larger
path reconstruction scratch array; grid dimensions and the world/snapshot layout are unchanged.

The normal Godot build tried to regenerate shared `godot-cpp` files outside the worktree and was refused by the sandbox.
The successful build used a copy under ignored `build/godot-cpp` and `GODOT_CPP=$PWD/build/godot-cpp`; user config/cache/data
were redirected under ignored `build/godot-user` for headless runs. Existing Godot shutdown resource-leak warnings remain.
No display, screenshots, visual acceptance or WASM verification is claimed.

## Work still required

Implement and verify the minimal deterministic terrain/access repair or a reachable authored entrance/trail; certify the
river-gap round trip for both biped sizes and all required seeds; then make the strict route gate and `make test` green.
Keep the real endpoint requirement and remove no failures from the graph merely to obtain a pass. Any terrain change must
retain TERRAIN/HYDROLOGY limits, rerun the seed guarantees, and update affected terrain identities/goldens once with an
explanation. Add actual placements before certifying the TODO discoveries. Address the measured planning-latency regression.
