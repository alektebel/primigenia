# Art task: the valley species (G66)
Read docs/ART_GAPS.md (gap list), docs/DESIGN.md (G63 palette C "Current+", G64–G66, W2/W10/W15, Q43), and study the existing art style before writing anything: tools/hero/build_hero.py (toon world: toon() materials with the ramp, leafCanopy() leaf-card trees, rocks, flowers, nest, eggs; ACES tone mapping; palette data PAL.C) and web/creature/rig.js (physically lit creature skin, keratin, membranes). Your art must look like it belongs in that valley: same toon ramp and palette C for world props, physical materials only for creature-like things.

Build: genomes for the valley's other species as cpore.creature/4 JSON (see web/stage/species/garfio.json and web/studio/genome.js; render them with web/creature/rig.js): Rondo (round herbivore grazer), Zanco (tall long-legged wader), Espinodo (spiny defensive omnivore), a nocturnal variant of Espinodo (G65: dark, bioluminescent spots) and an albino crater variant; each with a clearly different silhouette and palette from Merodeador and Garfio. Put them in web/props/species/*.json; the module renders them all in a lineup
Deliver it as a self-contained ES module web/props/species.js (three r128 like the hero; export builder functions that take a THREE instance, a seed and parameters and return Object3D/InstancedMesh; deterministic from the seed; low draw-call count) plus web/props/species.html, a preview page that shows every variant on a small patch of the valley ground under golden light, with an orbit camera. Do NOT edit tools/hero, web/hero, web/stage, web/creature or core (integration is a later task).

Iterate on your own renders until it is beautiful and convincing:
- Write docs/evidence/props/species/RUBRIC.md first (silhouette readability at 5 m and 30 m, fit with the valley's toon style and palette C, variety between variants, no artefacts, triangle budget).
- Render with headless Chromium, SOFTWARE WebGL only (--use-angle=swiftshader --enable-unsafe-swiftshader, executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome, NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules; python3 -m http.server on a free port). Open each PNG you render and critique it against the rubric in docs/evidence/props/species/ITERATIONS.md, then change one thing. At least 5 iterations.
- Final evidence: docs/evidence/props/species/sheet.png (all variants, close and far) and README.md (how to view, triangle counts, what is not done).
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
