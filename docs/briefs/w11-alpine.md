# Task W11-A3: alpine style for the terrain generator (W15)

Read docs/DESIGN.md W1–W15 (W14: 3.2 km island accepted; W15: alpine, not volcanic, no visible simulation artefacts), docs/TERRAIN.md, docs/evidence/terrain/metrics.md and the last report's weaknesses below. Generator: core/src/terrain.c (version 2), lab web/terrain-lab/, tests tests/test_terrain.c, tools/terrain/metrics.py. Do NOT touch web/hero, web/stage, tools/hero, tools/stage, core/src/combat.c, or any world-simulation files (other branches are changing them).

Weaknesses of version 2 (from the previous agent and the reviewer):
- Slopes are too steep: ~80% of ground above 100 m is steeper than 40°, ~1/5 above 60°. It reads as a fluted volcanic island, not alpine.
- Massif faces seen from the valley floor are smooth: no cliff bands, no cirque headwalls, ribs only faint at eye level.
- Few fans: scree aprons but no clear alluvial fans at valley mouths.
- The seven-slot "wheel of massifs with radial valleys" is recognisable from above across seeds.
- The start valley floor is nearly featureless.
- Thin margins: seed 1's peak only clears 400 m by 34 m; seed 7's Hack h is 0.0014 under the bound; only three seeds are checked.

Target (alpine): gentler lower slopes (typical 15–30°) with meadows, benches and terraces; steepening to cliff bands and cirque headwalls (glacial-looking bowls with a flat-ish floor below a steep back wall) higher up; sharp arêtes and horns at the tops with snow; U-shaped main valleys feeding the start valley; alluvial fans and gentle debris cones at valley mouths; a start floor with gentle relief (low moraine-like hummocks, a meandering stream to the lake, a few boulders' worth of bumps), still within the W12 flatness guarantee. Break the wheel pattern: vary massif count (5–9), placement (jittered, sometimes clustered, sometimes merged into a longer chain), and valley directions per seed. No visible simulation artefacts: no uniform parallel rills, no identical gully spacing.

Methods to consider: slope-dependent erodibility and a hypsometric remap (stretch lows, compress highs) to get gentle bases and steep tops; terraced/benched remap by a noise-varied step function with smooth risers for cliff bands; cirques as carved bowls at high valley heads (a deterministic glacial-erosion approximation, e.g. a U-shaped profile carve along the top segments of the main channels); fan deposition where channel slope drops; varied droplet/stream parameters by a low-frequency field so gullies differ.

Keep: determinism (only + - * / sqrtf), native == WASM parity, WASM ≤ ~10 s at N=1024, W12 guarantees (test them on 6 seeds now: 1, 7, 42, 99, 1234, 31337), Rb 3–5 and Hack h 0.5–0.6 with margins, the new discriminating metrics (valley depth, divide sharpness) eroded > base. Add a slope-distribution check that encodes W15 (e.g. median slope of land between 0 and 150 m above the valley floor in 12–30°; share of land steeper than 45° between 8% and 25%, concentrated above some height). Re-record golden hashes deliberately (generator version 3).
Evidence (SwiftShader, few renders): docs/evidence/terrain/shape-v3.png — v2 vs v3 for seed 42 (oblique, valley-floor view, top hillshade), plus v3 for two other seeds; a slope histogram before/after. Update docs/TERRAIN.md and metrics.md. make test, make terrain-test, make wasm-test pass.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
