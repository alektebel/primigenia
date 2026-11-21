# Task: real elevation data to calibrate the terrain generator (W21) — tools and report only
Read docs/DESIGN.md W11–W21, docs/TERRAIN.md, tools/terrain/metrics.py (drainage, Strahler Rb, Hack h, slope stats).
1. Download free open DEM tiles of Copernicus GLO-30 (open licence; public AWS bucket s3://copernicus-dem-30m, HTTPS https://copernicus-dem-30m.s3.amazonaws.com/ , no account) for: a central Alps window, Picos de Europa, Madeira, Tenerife (Canaries). Keep downloads in /home/diego/Desarrollo/cpore-wt/_agent/dem/ (not in the repo). Python standard library or already-installed packages only; if GeoTIFF reading needs a library that is not installed, write a minimal reader for the needed TIFF subset or use numpy if present.
2. Resample each to the game's scale (3.6 km square windows at the generator's N=1024 equivalent spacing, several windows per region) and compute the same statistics the generator reports: slope distribution (median, share above 30/40/45/60°), hypsometric integral, valley depth, ridge sharpness on divides, Strahler Rb, Hack h, drainage density.
3. Compare with the generator v2 (main branch, default params: build/terrain_cli) on seeds 1, 7, 42, 99, 1234, 31337: a table and plots (histograms) in docs/evidence/terrain/dem/, and docs/TERRAIN_CALIBRATION.md with which v2 stats are inside real ranges and which are not, and 3 concrete suggested parameter directions (no code changes to the generator in this task).
Attribution: "Contains modified Copernicus DEM data" with the licence link in the report.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
