# Terrain structure and performance evidence

Measured 2026-11-15 on the phase-A generator, version 1. Default work: N=1024,
2,000 m square, 70,000 droplets, lifetime 32, brush radius 4, 5 thermal passes.
Base-only disables both erosion stages, retaining the identical noise/mask and
final drainage analysis. Seeds are 1, 7 and 42. All heavy processes ran with
`nice -n 10` (inherited niceness may further lower priority).

## Drainage measurements

The fixed channel threshold is **8,000 m²** of contributing area (about 2,097
cells at N=1024). Both versions use the same priority-flood routing on their
final map. Each cell begins with one rainfall unit. The output flow multiplied
by 4,000,000 m² gives contributing area; directions in the dump are exactly the
generator's routed receivers.

Strahler order starts at 1 on channel headwaters. At a junction the maximum
upstream order increases only if at least two maximal upstream orders match.
Count one stream segment at each downstream end of a maximal run with constant
order. Fit `log(N_order) = a − order * log(Rb)` when at least three orders exist,
otherwise use the arithmetic mean of adjacent order-count ratios. All six
final maps support the Horton regression.

For Hack's law, compute the longest upstream D8 path **from the divide**, with
cardinal/diagonal distances in metres, including cells below the channel
threshold. Fit `log(L) = a + h * log(A)` at independent basin outlets above the
channel threshold. At least eight basins are required. Using only the length
above the channel threshold while keeping total area gave a biased exponent;
the draft's implementation was corrected before recording these results.
The [drainage study's definition](https://essd.copernicus.org/articles/16/1151/2024/index.html#section3)
also measures longest river length from divide to mouth. This supports the
quantity being measured, not the acceptance of this synthetic terrain.

Hypsometric integral is `(mean(height) − min(height)) / (max(height) − min(height))`.
No HI acceptance range is imposed by the brief.

| Seed | Stage | Channel cells | Strahler segment counts | Rb | Outlet h | Fit R² | Basins | HI |
|---|---|---:|---|---:|---:|---:|---:|---:|
| 1 | base | 9784 | 2:21, 3:5, 1:96 | 4.3818 | 0.5346 | 0.9067 | 18 | 0.2931 |
| 1 | eroded | 14097 | 2:33, 3:9, 1:164, 4:3 | 3.7822 | 0.5112 | 0.8902 | 24 | 0.2948 |
| 7 | base | 10235 | 1:111, 2:32, 3:8, 4:1 | 4.7185 | 0.4719 | 0.8544 | 23 | 0.3001 |
| 7 | eroded | 16483 | 1:160, 2:39, 3:12, 4:3 | 3.7093 | 0.5258 | 0.9345 | 23 | 0.3023 |
| 42 | base | 10426 | 2:27, 1:109, 3:6, 4:1 | 4.7484 | 0.4709 | 0.9121 | 20 | 0.3129 |
| 42 | eroded | 16388 | 2:42, 1:170, 3:12, 4:2 | 4.2977 | 0.4985 | 0.9063 | 23 | 0.3156 |

The brief's target intervals are Rb=[3,5] and h=[0.5,0.6]. To compare paired
results, define `gap = distance(Rb,[3,5])/2 + distance(h,[0.5,0.6])/0.1`.
This measures distance from the ranges, not distance from an arbitrarily
preferred point within them. The heavy gate requires no seed's gap to worsen,
and a strictly better sum across the three seeds.

| Seed | Base gap | Eroded gap | Result |
|---|---:|---:|---|
| 1 | 0.000000 | 0.000000 | Tie: both in range |
| 7 | 0.280782 | 0.000000 | Improved |
| 42 | 0.291429 | 0.014892 | Improved |

Mean normalized gap: **0.190737 → 0.004964**.
All eroded Rb values lie in 3–5. Eroded h is in range for seeds 1 and 7;
seed 42 is 0.4985, 0.0015 below the strict lower bound. Seed 1's base already
passes both intervals, so erosion cannot make its interval gap strictly smaller.
**This is a non-worse paired / improved aggregate result, not strict improvement
on all three seeds or proof that every eroded metric is inside its interval.**

## Sensitivity and tuning

The earlier draft fitted Hack using nested junctions plus outlets. Keeping that
estimator, with the corrected divide-to-outlet length, gives:

| Seed | Stage | Pooled h | Fit R² | Samples |
|---|---|---:|---:|---:|
| 1 | base | 0.4334 | 0.8540 | 91 |
| 1 | eroded | 0.4332 | 0.8618 | 160 |
| 7 | base | 0.4105 | 0.8133 | 105 |
| 7 | eroded | 0.4235 | 0.8759 | 153 |
| 42 | base | 0.4053 | 0.8298 | 105 |
| 42 | eroded | 0.4051 | 0.8290 | 161 |

Those pooled exponents remain below the requested 0.5–0.6 range. Erosion improves
seed 7 and is nearly unchanged/slightly worse on seeds 1 and 42 under that fit.
These correlated nested samples measure a different sampling regime; they are
kept in `metrics-pooled.json` and are not discarded to imply stronger agreement.
Only 18–24 independent outlets support each primary fit. Finite grid size,
artificial square boundaries and the deliberate ring/lake/pass strongly constrain
the catchments. No confidence interval or real-world validation is claimed.

Tuning was real: the raw-surface D8 first pass fragmented after erosion and
could not even fit Rb for the full-size eroded maps. Priority-flood routing fixed
the graph. A small N=512 sweep on the earlier mask compared radius 2/4,
lower erosion, longer lifetime and lower capacity; it gave mixed Hack results.
The retained radius-4 brush spreads incision and reduces pits. Broader,
noise-offset foothills and removal of the 12 m valley-rim discontinuity improved
the visual structure and retained all default-seed guarantees. The final table
above uses the resulting parameters on all three full-size maps. Thresholds
were not changed per seed, and the pooled failure is reported explicitly.

Flat spill-level routing creates conspicuously straight drainage lines across
the lake/start valley. These are saturated-basin diagnostic paths, not visible
riverbeds or a water-volume simulation. Thermal erosion relaxes towards the
angle with a finite count; it does not enforce an everywhere-below-talus bound.

## Parity and timings

Machine: x86-64 Linux, **AMD Ryzen AI 7 350**, GCC 16.2.1, Emscripten 7.0.0,
Node v26.13.0. Native and WASM use `-O2 -std=c99 -fno-fast-math -ffp-contract=off`.
Timings surround generation only, excluding hashing, copies and rendering;
they are individual observations under normal machine load, not a benchmark
mean. Exact measurements are in [parity.json](parity.json).

| Seed | N | Native seconds | Node/WASM seconds | Exact hash (both) |
|---|---:|---:|---:|---|
| 1 | 256 | 0.6732 | 0.7498 | `89d99b8f14645e6a` |
| 7 | 256 | 0.6472 | 0.6975 | `18f87d9ed2efd473` |
| 42 | 256 | 0.6821 | 0.7762 | `3b32a5fd7c3c59aa` |
| 1 | 1024 | 1.2976 | 1.3564 | `d4e9acd0acb8f70c` |

All four required parity cases match, as do the three committed small-N goldens
through the WASM ABI. The default 1024 map is under W13's ~10 s limit.
`wasm-test` also passes the pre-existing combat goldens, bot-duel parity and JS
wrapper/encounter regressions.

## Vista evidence

Chromium 1254 uses only `--use-angle=swiftshader` and
`--enable-unsafe-swiftshader`. [browser.json](browser.json) records the actual
Chromium version and asserted renderer. Screenshots share the camera, sun,
size and default surface shading. They are 1024 maps on a sampled display mesh;
the lab desktop/mobile smoke images show a subsequent N=256 control interaction.
An independent source/screenshot review shipped the scoped preview; no owner
approval or normal-browser FPS measurement is claimed.

| Seed | Before | After | Hillshade + drainage |
|---|---|---|---|
| 1 | [Base](base-1.png) | [Eroded](eroded-1.png) | [Drainage](hillshade-drainage-1.png) |
| 7 | [Base](base-7.png) | [Eroded](eroded-7.png) | [Drainage](hillshade-drainage-7.png) |
| 42 | [Base](base-42.png) | [Eroded](eroded-42.png) | [Drainage](hillshade-drainage-42.png) |

The capture smoke tested five material modes, keyboard orbit/zoom, reset,
drainage toggling, invalid seed rejection, regeneration and mobile overflow.
It always closes the software browser. The Worker forwards all five progress
stages, and the core tests validate monotonic progress within stages.

## Reproduce

```sh
nice -n 10 make terrain-test
# The heavy target creates paired dumps, fits the primary metrics and checks gaps.
# Recompute the sensitivity fit on those same maps without generating again:
nice -n 10 python3 tools/terrain/metrics.py \
  build/terrain/terrain-{base,eroded}-{1,7,42}.bin --pooled \
  --json build/terrain/metrics-pooled.json
# Serve the repository root, then capture with the existing agent dependencies:
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/terrain/capture.cjs
```

The compact raw metrics are committed as [metrics.json](metrics.json) and
[metrics-pooled.json](metrics-pooled.json); large maps and generated WASM stay
under ignored `build/`. Natural-structure regressions use the primary outlet
estimator; a stricter pooled-fit acceptance remains open. Phase B integration,
full-island guarantees and the game's W13 cache/pre-bake/story remain outside
this standalone phase-A deliverable.
