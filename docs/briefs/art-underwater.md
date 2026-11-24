# Art task: the underwater biome look (G64)
Read docs/DESIGN.md G64, W7, W15, G63 (palette C "Current+"), docs/ART_GAPS.md if present, and how the valley is rendered in tools/hero/build_hero.py (three r128, ACES, toon ramp for the world, physical creature skin, lake water shader, fog/aerial perspective, palette data). Do not edit tools/hero or web/hero or web/stage in this task (other agents edit them): build a self-contained module.

Build web/biome/underwater.js (ES module, three r128 from the same vendored/cdn source the hero uses) that, given a scene, a water level, a heightmap sampler and a palette, adds an underwater look visible when the camera is below the surface: animated caustics on the floor and on creatures, underwater fog with depth-based absorption (blue-green), light shafts from the surface, a wavy surface seen from below with total internal reflection, kelp forests (instanced, swaying), coral and rock clusters, sea grass, rippled sand, a few small fish schools (boids, instanced), floating particles, and one shipwreck-like or meteor-shard landmark on the sea floor. Plus web/biome/underwater.html: a standalone preview with an orbit/swim camera, shallow (2–5 m) and deeper (10–20 m) presets.

Iterate on your own renders until it looks realistic and beautiful (stylised to match the valley's toon world + physical creatures):
- Render with headless Chromium, SOFTWARE WebGL only (--use-angle=swiftshader --enable-unsafe-swiftshader, executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome, NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules), serve with python3 -m http.server on a free port.
- After each render, open the PNG and critique it against docs/evidence/underwater/RUBRIC.md that you write first (readability, depth layering, colour harmony with palette C, light shafts, caustics, life and motion, no artefacts, performance). Write the critique and the next change in docs/evidence/underwater/ITERATIONS.md. At least 5 iterations; keep the best.
- Final evidence: docs/evidence/underwater/{shallow,deep,surface-from-below}.png and a short README with how to view and what is not done.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
