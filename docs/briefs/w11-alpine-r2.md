# Continue W11-A3 alpine (branch w11-alpine): round 2 after review
Re-read /home/diego/Desarrollo/cpore-wt/_agent/briefs/w11-alpine.md (scope, rules). Your v3 (27e6272) is committed but not mergeable. Claude reviewed docs/evidence/terrain/shape-v3.png:
- Good: gentler, greener lower slopes; massif count and layout now vary per seed.
- Bad 1: peaks are isolated cones/spikes standing on a plateau ("teeth on a ring"); alpine ranges are connected ridgelines with arêtes, cols and side spurs, massifs merging into chains. Rebuild peaks as ridge networks, not radial cones.
- Bad 2: seen from the valley floor, a uniform grey band/plateau wall circles the valley at mid height, scored by straight vertical blue lines (drainage drawn as straight channels): it looks artificial. Break the band (varied heights, re-entrant side valleys, spurs reaching into the valley floor, benches at different levels) and make channels follow terrain curvature (no straight radial lines).
- Bad 3: the hillshade shows a "moat" ring around the start valley and radial grooves everywhere (wheel pattern): remove the ring trough and the purely radial drainage; valleys should branch dendritically.
- The drainage gates fail (Hack 0.46–0.48 below 0.5; four seeds Rb > 5). Do not weaken the gates; fix the terrain (dendritic branching from the changes above should move both).
Keep v2's strengths (the natural look of its eroded faces) and W15 (gentle walkable bases, cliff bands and cirques higher up, snow). make terrain-test, make test and make wasm-test must pass; regenerate shape-v4.png (v2 / v3 / v4 for seed 42 + v4 for seeds 1 and 7). Commit as you go.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
