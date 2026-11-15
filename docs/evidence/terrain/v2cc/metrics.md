# v2 + cliffs + caves: W20 default evidence

Measured 2026-11-15 on branch `w11-v2plus`, generator version 3, N=1024, 3,600 m square. Only the three requested C defaults changed: `gentle_bases=0`, `layout_variety=0`, `volcano=0`. Bands, sea cliffs, resistant strata and caves stay enabled. No generator algorithm, work count or acceptance threshold changed. Native/JS/lab defaults agree; all switches remain available.

## Acceptance result

**`make test` and `make wasm-test` pass. `make terrain-test` fails the unchanged Rb gate on seed 31337.** The requested defaults and the requirement that all three commands pass cannot both be satisfied without changing an algorithm or weakening that gate. Neither was done.

| Command (all run with `nice -n 10`) | Result |
|---|---|
| `make test` | PASS; native terrain/core/world/combat and committed replays |
| `make terrain-test` | FAIL (make exit 2): seed 31337 Rb 5.97127655 exceeds 5.5 |
| `make wasm-test` | PASS; terrain/world/combat parity, original-v2 map bytes, W13 time |
| `build/terrain_test --heavy` | PASS; W12 and cliffs/material/cave guarantees on all six seeds |
| `build/terrain_test --heavy --gentle` | PASS; optional gentle_bases=1 including W15 on all six seeds |
| `node tools/terrain/compare_v2.mjs …` | PASS; original-v2/current-WASM/native maps byte-identical with all switches off |
| `python3 tools/terrain/ablations.py --v2cc …` | PASS; paired measurements below |
| `node tools/terrain/capture.cjs … --details` | PASS; SwiftShader, lab smoke, all requested captures |

Full outputs are [make-test.txt](make-test.txt), [make-terrain-test.txt](make-terrain-test.txt), [make-wasm-test.txt](make-wasm-test.txt), [guarantees.txt](guarantees.txt), and [gentle-guarantees.txt](gentle-guarantees.txt). Emscripten was loaded with `source ~/emsdk/emsdk_env.sh`. The terrain target fails in its metrics prerequisite, so the full-resolution C guarantees were also run explicitly.

## Unchanged gates and diagnosis

Rb targets 3–5 with the inherited interval-gap tolerance 0.5 (allowed 2.5–5.5). Hack targets 0.5–0.6 with the inherited tolerance 0.05 (allowed 0.45–0.65). Eroded valley depth and ridge sharpness must each exceed the paired un-eroded base on every seed.

| Seed | Eroded Rb | Hack h | Valley depth base → eroded m | Ridge sharpness base → eroded |
|---|---:|---:|---:|---:|
| 1 | 4.1367 | 0.5056 | 8.02 → 26.48 | 0.3726 → 0.4955 |
| 7 | 4.0391 | 0.4951 | 8.90 → 28.09 | 0.3838 → 0.4908 |
| 42 | 4.8168 | 0.5055 | 8.83 → 26.02 | 0.4612 → 0.4921 |
| 99 | 4.6444 | 0.5037 | 9.26 → 26.27 | 0.4146 → 0.5111 |
| 1234 | 3.8708 | 0.4767 | 8.92 → 25.86 | 0.4185 → 0.5014 |
| 31337 | 5.9713 | 0.5142 | 8.64 → 26.13 | 0.4281 → 0.5101 |

Only seed 31337 fails. The paired [diagnostic ablations](drainage-failure.json) show the failure already exists in **eroded original v2**, with Rb **5.8540**. High bands alone leave its segment counts unchanged; sea cliffs alone give 5.8637; strata alone give 5.9418; together they give 5.9713. Adding caves leaves both Rb and Hack unchanged. Thus this is an inherited v2 drainage branching failure, modestly increased by coastal/strata changes, rather than a cave-placement failure. A separate [full-resolution original-module comparison](v2-disabled-31337.json) confirms all 3,145,728 height/flow/sediment samples match v2 exactly for this seed with switches off. Original v2 has Strahler segment counts **219/45/10/1**; the new default has **232/60/13/1**. With only one fourth-order segment, the fitted Horton slope remains too high. No seed override, gate exemption or threshold change was introduced.

W12 passes all six seeds: 100% of cells within 90 m of the start have slope below 10°; lake bottom <30 m and retains ≥10 m; connected river route ≤start+5 m; with the gap blocked, the col lies between 100 and 300 m; peak >400 m. Cliff and beach checks pass, every nonvolcanic material class is present, volcanic material is absent, and 3–6 dry cave entrances include one qualifying waterfall site on each seed. W15 remains conditional on gentle_bases>0; the explicit gentle configuration passes all six 15–30° median tests.

## Original v2 bytes and size of the change

With all seven switches off, **196,608 height/flow/sediment float samples (786,432 bytes)** match original v2 WASM and current native/current WASM exactly at seed 42, N=256. Original scratch sources were checked byte-for-byte against commit `0386bb8`. [Comparison record](v2-disabled.json). The map SHA-256 fixtures in `tests/golden/terrain-v2-maps.json` are now enforced by the normal terrain parity test independently of v3’s expanded hash schema. The material map remains mandatory output.

At seed 42, N=1024, with identical default erosion work and every unlisted switch off:

| Enabled versus v2 | Changed cells / 1,048,576 | Fraction | Maximum absolute height change m |
|---|---:|---:|---:|
| v2 | 0 | 0.000000% | 0.0000 |
| cliff-bands | 21,305 | 2.031803% | 0.9000 |
| sea-cliffs | 449,614 | 42.878532% | 120.7928 |
| hard-rock | 497,659 | 47.460461% | 33.3505 |
| cliffs-strata | 635,717 | 60.626698% | 120.7986 |
| cliffs-strata-caves | 635,717 | 60.626698% | 120.7986 |

The combined changes are **not byte-local or sub-metre overall**: the sea-cliff mask changes the pre-erosion coast, and resistant strata change erosion, so their effects propagate through drainage and multiscale erosion. The cosmetic high band alone is bounded to 0.9 m. Caves lower 34 already-changed samples by up to 2.5023 m relative to cliffs+strata alone ([paired measurement](cave-delta.json)); they do not increase the combined changed-cell count or maximum. The comparison sheet retains the seven-massif v2 arrangement, but owner visual approval of the look remains unclaimed. [Raw ablations](ablations.json).

## Determinism and deliberate goldens

The three N=32, droplets=300, thermal=3 goldens were deliberately replaced for the new default configuration; [old/new hashes and reason](goldens.json). Original-v2 map fixtures were recorded separately from the original module. Native/WASM parity passes all six seeds at N=256 and seeds 1/42 at N=1024, plus independent switch settings and half-strength combinations; materials and cave records also match.

| Seed | N | Native s | WASM s | Shared hash |
|---|---:|---:|---:|---|
| 1 | 256 | 0.2751 | 0.3304 | `b255c92a5b85e43d` |
| 7 | 256 | 0.2800 | 0.3327 | `adc7c973cbc3dcdf` |
| 42 | 256 | 0.2803 | 0.3308 | `572d8a0f9a1fd889` |
| 99 | 256 | 0.2733 | 0.3186 | `e03a1d647ecc4c58` |
| 1234 | 256 | 0.2855 | 0.3243 | `ea0bcd4c82538aa2` |
| 31337 | 256 | 0.2828 | 0.3302 | `c71b16838d4d02ee` |
| 1 | 1024 | 3.3097 | 4.3179 | `281193d8ad044e09` |
| 42 | 1024 | 3.3858 | 4.3347 | `e74f19ff5262a9eb` |

These are single generation timings under laptop load, not a performance distribution. W13’s existing ≤10 s assertion passes.

## Visual evidence and reproduction

- [shape-v2cc.png](../shape-v2cc.png): original v2 seed 42 versus the new default seed 42, each with the fixed oblique, valley-floor and hillshade cameras used by shape-v2plus.png; new defaults on seeds 1 and 7; a sea-cliff close view and a marked cave-entrance floor-notch close view.
- [Sea cliff](sea-cliff-42-close.png), [cave entrance site](cave-42-close.png), [material/cave lab view](lab-material-caves.png), [full-resolution material map](material-caves-42.png), [desktop](lab-desktop.png), [mobile](lab-mobile.png).
- [Browser record](browser.json): Chromium 158.0.8127.18; ANGLE (Google, Vulkan 1.3.0 (SwiftShader Device (Subzero) (0x0000C0DE)), SwiftShader driver). No page errors. Only `--use-angle=swiftshader --enable-unsafe-swiftshader`; explicit Chromium 1254 executable; Playwright from the required NODE_PATH. Every browser is closed in `finally`.
- The close cave view shows the generated floor notch at cave marker 2; **there is no visible tunnel opening/overhang mesh**. Those meshes are outside this default-only task, and no cave geometry was invented for the screenshot.
- Lab smoke covers the default feature states, six surface modes, both regular cameras, keyboard orbit/zoom, reset, drainage, invalid seed, regeneration with volcano enabled/caves disabled, and no horizontal mobile overflow.

```sh
source ~/emsdk/emsdk_env.sh
nice -n 10 make test
nice -n 10 make terrain-test  # known Rb failure; threshold unchanged
nice -n 10 make wasm-test
nice -n 10 ./build/terrain_test --heavy
nice -n 10 ./build/terrain_test --heavy --gentle
nice -n 10 node tools/terrain/compare_v2.mjs build/terrain/v2-disabled.json
nice -n 10 python3 tools/terrain/ablations.py --v2cc --out build/terrain/ablations.json
nice -n 10 node tools/terrain/compare_v2.mjs build/terrain/v2-disabled-31337.json 31337 1024
nice -n 10 python3 tools/terrain/ablations.py --v2cc --seed 31337 --workdir build/terrain/v2cc31337 --out build/terrain/v2cc31337/ablations.json
nice -n 10 python3 tools/terrain/metrics.py build/terrain/v2cc31337/ablation-*.bin --json build/terrain/drainage-failure.json
nice -n 10 python3 -m http.server 8032 --bind 127.0.0.1
TERRAIN_URL=http://127.0.0.1:8032/web/terrain-lab/ \
NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules \
  nice -n 10 node tools/terrain/capture.cjs --out docs/evidence/terrain/v2cc --no-base --details
nice -n 10 python3 tools/terrain/sheet.py docs/evidence/terrain/v2cc docs/evidence/terrain/shape-v2cc.png 'v2 + cliffs + caves'
```

Original v2 must be built into build/wasm-v2 as described in [TERRAIN.md](../../../TERRAIN.md). The detail helper is injected only by the capture runner; regular lab cameras/rendering are unchanged. Historical shape-v2.png/shape-v2plus.png evidence and art/reference/ were not modified. No branches/worktrees were switched, no packages/SDKs installed, and no changes pushed.

Open issues: seed 31337 Rb failure; owner approval of the measured visual change; actual tunnel/overhang rendering remains future work.
