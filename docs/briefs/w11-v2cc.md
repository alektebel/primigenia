# Task: make the default terrain = v2 + cliffs + caves (branch w11-v2plus, continue on it)
Owner decision (W20 in docs/DESIGN.md on claude/v0.1-restore): the owner prefers Fable's v2 exactly. Change only the defaults in cp_terrain_params_default(): gentle_bases = 0, layout_variety = 0, volcano = 0; keep cliff_bands = 1, sea_cliffs = 1, hard_rock = 1, caves = 1 (and the material map output). Do not change any algorithm.
Then:
1. Tests: drop the W15 gentle-slope gate from the default acceptance (keep it available for a gentle_bases > 0 configuration). Keep W12 guarantees on 6 seeds, Rb 3–5, Hack 0.5–0.6 with the unchanged tolerance, eroded beats base, native == WASM. If a gate fails with the new defaults, report which and why; do not weaken it.
2. Verify that with cliffs/strata/caves off the output still equals v2 bit-for-bit (your existing regression), and measure how much the cliffs/strata change v2 (fraction of cells changed, max height change), so we know v2's look is intact.
3. Terrain lab: the defaults follow the new params; keep the switches.
4. Re-record goldens deliberately. Evidence: docs/evidence/terrain/shape-v2cc.png: v2 vs v2+cliffs+caves for seed 42 (three views each, same cameras as shape-v2plus.png) plus seeds 1 and 7; and a close view of a sea cliff and of a cave entrance.
make test, make terrain-test, make wasm-test pass. Commit.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
