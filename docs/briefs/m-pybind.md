# Minor task: Python binding for the C world agent API
Read docs/WORLD.md (the C world, its observation JSON and id-targeted verbs, the CLI), core/include/cpore/ for the world header, bindings/python/ (existing ctypes binding + smoke_test.py, run by `make smoke`).
Add to bindings/python a small ctypes wrapper for the world: create/reset from a seed, step with a verb string or structured action, get the observation as a Python dict, get the state hash, replay from a log. Add bindings/python/world_smoke.py that plays a short scripted episode (walk, approach the wild creature, attack, go to nest) and checks: deterministic (same seed + same actions → same hash sequence twice), hash equals the native CLI's for the same script. Add an example bindings/python/random_agent.py (random valid verbs for N steps, prints the outcome). Hook world_smoke into `make smoke`. No new dependencies beyond the Python standard library. Report what ran and its output.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
