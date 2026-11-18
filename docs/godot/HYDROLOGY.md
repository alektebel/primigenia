# Hydrology (terrain generator v4, branch terrain/look-hydro)

Rivers come from the D8 flow the generator already computed. v4 carves them into the heights, publishes a class map, raises the
water level the C world reads on river cells, and Godot draws flowing ribbons along the same channels.

## C generator (`core/src/terrain.c`, section "rivers")

After the final `flow_accum` (and before the cave pass) `carve_rivers` runs when `rivers > 0` and `n >= 64`, then the flow is routed again,
so caves, materials and water levels all see the carved surface.

| class | drainage area | bed to water | the sim |
|---|---|---|---|
| stream (1) | >= 30,000 m2 (about 2,400 cells at n=1024) | +0.35 m | under the 0.5 m a pond needs: dry, walkable, no cost |
| shallow river (2) | >= 150,000 m2 | +0.6 m | `cp_stage_water_depth` = 0.6: reported as water but under the 0.7 m block, so it is a ford |
| deep river (3) | >= 1,500,000 m2 | +1.2 m | blocked (depth > 0.7) until swimming exists (C4) |

* Channel: half width `0.5 (0.8 + 0.01 sqrt(A))` m, incision `0.25 + 0.0008 sqrt(A)` m (stream 0.4, trunk about 1.5 m), smoothstep bank over
  about a cell. The cut is the maximum over the river cells nearby, in 16.16 integers (`ws->ups` is reused), so it is exact and order independent.
  Depth grows with area, so the bed stays downhill. Mouths keep 0.3 m of land so no cell turns into sea.
* The lake bowl and its rim (radius x1.25 .. x1.9) fade the cut to zero at the cell being cut, so the physical lake, its spill and
  "lake holds >= 10 m" are unchanged (tested: lake zone identical with rivers on and off).
* `CpTerrain.river` (optional n*n bytes, hashed when present): bits 0..1 class, bits 2..5 the D8 receiver direction + 1 (0 = outlet), so
  renderers follow the real channel. Cells already under standing water (lake) are not marked.
* `ws->scratch` (the exported `water_level`) is raised to bed + 0.35 / 0.6 / 1.2 m on river cells. It is therefore no longer strictly
  decreasing along `recv` there; the old epsilon-fill test now skips river cells.
* Seed 1 at n=1024: 4,254 stream, 721 shallow, 343 deep cells: one trunk through the east gap, the lake inlets and streams in the gullies.
  The deep reach is only the lower trunk. `tests/test_terrain.c` `rivers_test` (seeds 1, 7, 42, n=256): deterministic, carves only
  downward (max cut under 3 m, seen 1.5 m), lake zone untouched, levels exactly bed + 0.35/0.6/1.2, receiver bits match `recv`, and the
  dry land the start can walk to (4-connected, deep water blocked) loses at most 1.5% (seen under 0.2%).
* The six guarantee seeds (1, 7, 42, 99, 1234, 31337) still hold: `terrain_test --heavy` PASS (lake, river gap, col). The only red gate of
  `make terrain-test` is the pre-existing seed 31337 Rb (5.9713 before, 5.9936 after).
* Determinism: + - * / sqrtf only. WASM and native hash identically (`make terrain-parity`).

Goldens regenerated once for v4 (generator output changed, CP_TERRAIN_VERSION 3 -> 4): `tests/golden/terrain-{1,7,42}.hash` (n=32 skips rivers, so only the version
word changed) and `world-field-1.{log,hashes}` (the field now carries the river map and water levels). The Makefile's edited-hash check follows the new hash.

## Godot

* `rivers.gd` builds one triangle strip per channel from the river map (`chains()`: sources by descending drainage, a tributary stops on the trunk).
  Positions get two 1-2-1 smoothing passes against the 8-neighbour zigzag; width `max(2.6, 1 + 0.012 sqrt(A))` m.
* `river.gdshader`: ripples scrolling along the flow, speed from the bed drop, foam on rapids and a white sheet where the bed drops
  steeply (waterfall), soft edges, shallow/deep tint from the real depth over the ground, the same aerial haze as the sea. The strip is draped on
  the terrain (`min(level, ground + 0.2)`) so it never hangs in the air on a slope.
* Wet banks: `surface_maps` raises the wetness channel (surface_tex.A) to 1 on the channel fading over 3.5 cells; rock shows it darker, meadow greener.
* `water.gd` skips river cells so the lake mesh does not draw blocks along rivers. `TerrainData.river`, `river_class(k)`, `is_river(k)`.

## Not done / deferred

* Shallow water does not slow movement: that needs a hook in `stage_world.c` (owned by other branches). The 0.5..0.7 m band is reserved for it.
* The strategic-zoom icon layer does not draw rivers; the ribbons are visible from the strategic camera (evidence `look/s4/river.png`).
* Waterfalls are the steep-drop foam sheet on the draped ribbon; there is no spray particle effect.
