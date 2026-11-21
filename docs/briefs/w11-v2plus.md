# Task W11-A4: alpine as a minimal delta on top of v2 (branch w11-v2plus)
The owner likes the v2 terrain (Fable's: docs/evidence/terrain/shape-v2.png on this branch): its eroded faces and natural range. A rewrite (branch w11-alpine, v3) replaced v2's massifs and lost that look: isolated cone peaks, a grey mid-height wall with straight vertical drainage, a moat ring. Do NOT rewrite. Keep v2's massif construction, stream-power erosion, droplets and thermal passes as they are.
Read docs/DESIGN.md W11–W15, docs/TERRAIN.md (v2), core/src/terrain.c (v2). You may read branch w11-alpine for ideas (`git show w11-alpine:core/src/terrain.c`, its docs/TERRAIN.md): its one clear improvement was a smooth hypsometric remap of the lowlands (median slope of land 42–192 m above the floor from 47.7° to 26°).
Apply only these deltas to v2, each switchable by a param so its effect can be measured alone:
1. Gentle bases (W15): a smooth hypsometric remap of the lowest part of the relief (valley floor up to the base of the massifs) so lower slopes are walkable (median 15–30°), keeping the upper faces and ridgelines of v2 untouched. Port the idea from w11-alpine, not its massifs.
2. Per-seed variety: vary v2's massif count (6–8) and jitter their angular positions and sizes per seed so the layout stops reading as the same wheel, without changing how each massif is built.
3. Subtle cliff bands only on high, steep faces (above the treeline); no band at mid height.
Keep everything else: v2's look must remain recognisable in the same three views. Gates (W12 guarantees on 6 seeds 1,7,42,99,1234,31337; Rb 3–5; Hack 0.5–0.6; eroded beats base; slope check for W15) must pass with v2-like margins; do not weaken any gate. Re-record goldens deliberately (generator version 3). Evidence: docs/evidence/terrain/shape-v2plus.png (v2 vs v2+ for seed 42, three views each, plus v2+ for seeds 1 and 7). make test, make terrain-test, make wasm-test pass. Commit as you go.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
