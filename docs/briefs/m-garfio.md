# Scoped task: retune Garfio so every fixture is winnable 35–80% on the C-world stage
After merging the P2 rebalance (combat rules changed) on top of the C world (docs/WORLD.md), `node tests/stage_winnability.mjs` gives: biter 42% OK, spitter 76% OK, guard 100% OUT OF RANGE (target 35–80% per fixture, 50 seeds each).
Change ONLY the Garfio species data (web/stage/species/garfio.json and web/stage/species/garfio-combat.json: part levels, hp, stamina, speed, radius). Do not touch core/, apps/, web/engine/, the move tables, the tests' policy, or the other fixtures.
Aim for every fixture well inside the band (e.g. 45–70%) so it is not fragile. Then run: `make test`, `make wasm-test`, and `make stage-test` with `python3 -m http.server 8765 --bind 127.0.0.1` running from the repo root and NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules. If stage tests record world logs or evidence that change, regenerate them with the commands the tests document. Report the final win rates. Commit.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
