# Task W11-A: eroded terrain generator in C (branch w11-terrain; a previous agent left an uncommitted draft)

Read docs/DESIGN.md §10 W1–W13 (W11–W13 are this task) and docs/COMBAT.md (determinism contract and the WASM build/parity pattern: Makefile targets wasm / wasm-test, apps/wasm_api.c, tests/combat_parity.c). A previous session drafted core/include/cpore/terrain.h, core/src/terrain.c, apps/terrain_cli.c and tools/terrain/metrics.py, uncommitted and unverified: review them critically, keep what is sound, fix or rewrite the rest, and commit early.

Scope (phase A): the generator, its parity, its natural-structure checks, a standalone preview. Do NOT touch web/hero, tools/hero, web/stage, tools/stage, web/creature (other branches change them; integration is phase B).

## Generator: core/include/cpore/terrain.h, core/src/terrain.c (libc/libm only)
1. API: cp_terrain_params_default(&p); cp_terrain_generate(params, out, workspace) with caller-provided buffers (no malloc inside, or one documented arena) and a progress/stage counter usable from a Web Worker. Outputs float32 N×N maps (default N=1024 over ~2 km around the valley): height (m), flow accumulation (normalised), sediment deposited; slope helper. Params: seed, size, octaves, warp strength, ridge weight, mountain mask (start valley basin at centre, ring of mountains, a lake basin, a pass/gap), droplet count and droplet params (inertia, capacity, deposition, erosion, evaporation, gravity, brush radius, lifetime), thermal iterations and talus angle.
2. Pipeline: domain-warped fbm + ridged multifractal (Musgrave) weighted by the mask → hydraulic droplet erosion (Beyer 2015: brush erosion, bilinear deposition; RNG = a CpRng stream from the seed) → thermal erosion to the talus angle → flow accumulation (D8 or MFD) on the final map.
3. Determinism: only + - * / sqrtf in anything feeding the output (hash-based value/gradient noise with polynomial fades, no sin/cos/exp/pow), fixed work counts, the same flags as combat. cp_terrain_hash = FNV-1a 64 over the canonical little-endian output.

## Tests and checks (make test stays fast; heavy ones under make terrain-test)
4. tests/test_terrain.c: determinism (same seed twice → same hash; different seed → different), param validation, small-N golden hashes for 3 seeds (tests/golden/terrain-*.hash); W12 guarantees on the default seed: flat-ish start valley (area with slope < 10° within radius R of centre ≥ threshold), a lake basin that holds water, a pass in the ring, peaks above a height.
5. Natural-structure metrics (tools/terrain): drainage network from flow accumulation, Strahler orders, bifurcation ratio Rb (natural ≈ 3–5), Hack's law exponent h in L ∝ A^h (natural ≈ 0.5–0.6), hypsometric integral. docs/evidence/terrain/metrics.md: base-only vs eroded for 3 seeds. Eroded must be closer to natural ranges than base-only; if not, tune and say so honestly.
6. WASM: build/wasm/cpore_terrain.mjs(+.wasm); parity: native and WASM give the same cp_terrain_hash for 3 seeds at N=256 and the default seed at N=1024. Time native and WASM (node) at N=1024 with the default work: WASM ≤ ~10 s on this machine (W13); if over, reduce work or optimise; report numbers.

## Preview
7. web/terrain-lab/index.html (+js): WASM in a Web Worker, seed field + a few sliders, progress, three r128 render with slope/altitude/flow/sediment shading (rock ridges, scree fans, wet gullies, snow by height/slope/aspect), a 2D hillshade and a drainage overlay. Evidence (SwiftShader): docs/evidence/terrain/{base,eroded}-<seed>.png from one camera, plus a hillshade+drainage image per seed.
8. docs/TERRAIN.md: algorithm, params, determinism, metrics, timings, how to run.
Erosion is CPU-heavy: nice -n 10 always; run the 1024 timings only a few times.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
