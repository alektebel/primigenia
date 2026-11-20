# Minor task: art inventory and gap list (documentation only, no code changes)
Read docs/DESIGN.md (G, W decisions; especially G14/G20/G37/G43/G48/G49–G54, W1–W15, Q43, Q46), docs/BACKLOG.md, docs/P4.md, docs/WORLD.md, and look at what art exists: web/studio (parts.json, parts/*.glb, procedural parts in studio.js and web/creature/rig.js), web/stage (species/*.json, props), tools/hero/build_hero.py (trees, grass, rocks, flowers, nest, eggs, water, sky), web/terrain-lab, assets/audio, art/ (do not modify art/reference).
Write docs/ART_GAPS.md:
1. Inventory table: every visual asset type that exists today, where it is made (file/function), procedural or file-based, and its state.
2. Gap table: every visual asset the MVP (BACKLOG section 1, P4.md) and the near tail (underwater biome per W7, secrets: fossils, caves, meteor/panspermia landmark W10, recipe clues G51) need but does not exist yet. For each: what it is, where it would be used, decision reference, suggested approach (procedural in JS like the existing parts/trees, or shader), size (S/M/L), and dependencies.
3. A suggested order to build them.
Facts only from the repo; mark anything uncertain. Commit the file.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
