# Task P3b-finish: finish the walkable stage fixes (branch p3b-stage, continue on it)

Read docs/evidence/stage/README.md, docs/COMBAT.md, web/stage/{stage.js,simulation.js}, web/engine/*.js, and `git log -5` / `git status` first.

Already done and verified by Claude (keep them): per-creature combat body radius in C (radius_cm, default literal CB_RADIUS; goldens bit-identical; make test + make wasm-test pass), commit 35f1636; distinct enemy species Garfio (web/stage/species/garfio.json) instead of a second Merodeador, commit 7ff113f. Uncommitted in the worktree: Makefile, tests/stage_play.cjs edits and tests/stage_winnability.mjs (inspect, keep what is right).

Remaining:
1. Winnability: tests/stage_winnability.mjs (headless, simulation.js + WASM, no browser) pits a scripted competent player policy against Garfio over 50 seeds per fixture (tests/fixtures/combat/{biter,guard,spitter}.json). Last measured: player wins 100% for all three, target 35–80% per fixture. Tune the ENEMY only (garfio genome/profile: part levels, hp, radius), never the core move table. Report final win rates per fixture. Wire it into `make stage-test`.
2. tests/stage_play.cjs (Playwright, SwiftShader, needs `python3 -m http.server 8765 --bind 127.0.0.1` from the repo root): update expectations; keep asserting an outcome, hp change on both sides, 30/73 forced-rAF log equality and native `build/combat_parity --replay` hash equality. Make `make stage-test` pass end to end.
3. Re-capture docs/evidence/stage/{explore,fight-windup,fight-hit,victory}.png and mobile-touch.png showing Garfio, and the two bodies in contact without interpenetration.
4. README: enemy, body radius rule, win rates, how to run. Report `make tourney` build-balance numbers for default-radius profiles (must be unchanged from before the radius change: compare with the merge-base build).
All of make test, make wasm-test, make stage-test, studio tests pass; web/hero regenerates byte-identical.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
