# Route certification (C1): closed 2026-11-19

The strict required-route gate (`tests/test_routes.c`, `make routes-test`, part of `make test`) passes on seeds 1, 7 and 42:
**144/144 trips per seed**, every trajectory replayed to the same tick-hash digest. The first Codex pass (commits
`test(routes)`, `fix(nav)`, `fix(world)`, `docs(routes)`) built the gate and found the failures; the terrain curation that fixes
them is `fix(terrain): graded gap trail, cave approach and fords ...` plus the re-pinned fixtures.

## Gate

Nine bodies x eight required pairs (nest to Garfio, three herd home ranges, start valley, lake shore/water approach, river gap,
cave mouth) x both directions = 144 trips per seed. Real steering, one GO per trip, no teleport or debug move, no combatants.
A trip must emit `arrived`, finish within 0.3 m and 20,000 ticks, stay out of deep water and respect the 1.26 gradient ceiling.
Bodies: the real Merodeador (4 legs, 3 m) and 2/4/6/8 legs at 0.5 m and 4 m. The player obeys the same slope ceiling as wildlife.

| Seed | Before curation (first pass) | After curation |
|---|---|---|
| 1 | 122/144: cave entrance 0/18, river gap failed for both biped sizes | **144/144** |
| 7 | 108/144: cave entrance and river gap 0/36 | **144/144** |
| 42 | 122/144: cave entrance 0/18, river gap failed for both biped sizes | **144/144** |

The six local destinations were 108/108 before and are 108/108 after. Full per-route tables: `docs/evidence/routes/seed{1,7,42}.md`.

## Why they failed, and the curation (docs/TERRAIN.md item 9)

* **Cave entrance.** Every cave site is chosen on a steep rock face (gradient > 0.9) at 50-250 m, inside massifs whose slope is above
  1.26 for hundreds of metres around (seed 1: 1.30 at the entrance, 400 m of ground above 1.26 around it). No body could stand
  there. Fix: the first (gameplay) entrance is ranked by the cost of a graded trail to the already-carved network, still preferring
  the waterfall site (it moved on all three seeds and is still a waterfall), and a 0.30-slope corridor is cut to its floor. The rock
  behind the entrance is never graded (the terrain guarantee entrance slope > 0.8 still holds), so the certified endpoint is the
  apron 6 m in front of the entrance record, not the steep notch cell itself. This is a deliberate change from the first pass
  ("do not certify an apron"): a body cannot stand on a 1.3 face, and the owner brief asks for an apron.
* **River gap.** Two findings. (1) The checkpoint `(800,120)` was only on the gap on seeds 1 and 42; on seed 7 it lies on a 114 m
  massif, which is why every body failed there. The gap checkpoint is now the lowest dry cell on the 809 m circle around the start
  (`(796.3,138.9)` seeds 1 and 42, `(768.2,258.4)` seed 7). (2) On seeds 1 and 42 the lake-outflow river is a deep (1.2 m) channel
  across the way out, and the gap floor is rugged at gradient 0.7-1.0, above the biped holding limits (0.85 / 0.70) and directional
  climb (0.55 / 0.457). Disabling rivers did not help because the rugged floor alone stops bipeds. Fix: a graded 0.30 corridor from
  the start through the checkpoint to the river mouth, with a ford (deep class becomes shallow, pits become a shoal 0.55 m below the
  surface) where it meets deep or standing water. Real rivers and the lake bowl are never graded.
* Cost: terrain generation at n=1024 goes from about 3.5 s to about 5 s (three cost fields by raster sweeps, no allocation).

## Terrain limits retained

`terrain_test --heavy` passes on the six evidence seeds (1, 7, 42, 99, 1234, 31337): flat start, lake holds >= 10 m, river gap
<= start + 5 m, col between 100 and 300 m, waterfall caves (area >= 8000 m2, drop > 1 m, entrance slope > 0.8, not in a standing
lake), reachable-land and river rules. Trails only run at n >= 512 and are skipped without rivers (gap) or caves (cave approach),
so the n=32 goldens are unchanged.

## Goldens

Changed once, for the reason above: the n=1024 terrain hashes of seeds 1, 7 and 42, pinned in `tests/routes/seed*.json/.txt`,
`docs/evidence/routes/seed*.md` and `docs/evidence/godot/heights/heights.json`. Fixture places: only `river-gap` and
`hidden-cave-entrance` moved (nest, herds, player unchanged; re-exported with `godot/game/tests/routes_fixture.gd`). Unchanged: the
five world replay goldens, `tests/golden/terrain-{1,7,42}.hash` (n=32), combat goldens.

## Measured costs (wall clock, not deterministic)

* Curated trips, worst cold / worst warm plan: seed 1 27.1 / 2.7 ms, seed 7 59.2 / 4.8 ms, seed 42 46.5 / 3.9 ms.
* NAV gate (random far targets, 500k expansion cap): 20/20 seed 1 (mean 69.7 ms, worst 476 ms, warm worst 57 ms),
  19/20 seed 7 (39.4 / 311 / 76 ms), 19/20 seed 42 (86.0 / 477 / 43 ms). The single rejection per seed is unchanged from the first pass.

## Open items (not gate failures)

* Named spring, fossils, meteor shards and the crater rim have no gameplay placements; they remain TODOs with proposed
  coordinates in `tests/routes/README.md`, not fabricated trips.
* Only the first (gameplay) cave is guaranteed reachable. The other 2-5 entrances stay secret rock faces.
* The ctypes `legs`/`player_legs` fix of the first pass is also on main; the merge kept one copy.
