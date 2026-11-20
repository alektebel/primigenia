# Task stage-polish: Spore-like movement, natural locomotion, basic audio (MVP item 4)

Read docs/DESIGN.md G56–G59, docs/BACKLOG.md, docs/evidence/stage/README.md, docs/COMBAT.md, web/stage/*, web/creature/rig.js, web/engine/*. The owner played the stage and said: "movement feels clunky. would it make more sense to move towards pointer? ... make the movement just like the original spore", "movement of the creature is not so natural".

## 1. Movement like Spore's creature stage (G57)
- Click on the ground: the creature walks there (a small ground marker shows the target). Hold the left button: it keeps walking toward the point under the pointer (re-raycast every frame). Click on a creature: select it (ring + name); then the move keys/buttons make yours approach it and act (attack now; befriend/sing come in P4).
- WASD / arrows / left stick also work, relative to the camera. Any direction, never octants.
- Camera: right-drag (or middle-drag) orbits, wheel zooms within limits, the camera eases behind the creature when it walks, with collision against terrain. Touch: tap to walk, hold to follow, drag with two fingers to orbit, pinch to zoom; the virtual stick stays as an option.
- In fights the heading goes to C: replace the 8-octant CB_V_MOVE with a continuous heading: a quantised direction vector (integer components, e.g. int16 per axis) normalised in C with sqrtf, deterministic, added to the canonical hash only when used, so the 5 golden logs and their 50,000 hashes stay bit-identical. Update apps/wasm_api.c, web/engine (cpcombat, encounter: intents carry a vector), the log format and combat_parity --replay, docs/COMBAT.md. Tests: random headings native == WASM, replay equality, frame-rate independence still hold.

## 2. Natural locomotion (render side, plus the JS free-roam controller)
- Acceleration and braking curves (no instant speed changes), turning with a limited angular speed so the creature walks in curves instead of rotating on the spot; small heading changes turn while walking, large ones (> ~120°) do a quick pivot.
- Gait phase driven by distance travelled, so feet do not slide (verify: foot world positions during stance stay within a few cm per step in a test).
- Body leans into turns and pitches with slope and acceleration; subtle bob from the gait; head and neck look toward the movement target or the selected creature (clamped); tail follows with lag.
- Idle: breathing, occasional look-around.

## 3. Basic audio (G59)
- Sources: only files with CC0 (preferred) or CC BY licences from public repositories (Kenney.nl audio packs, OpenGameArt.org CC0, other clearly CC0 sources). Download only those audio files into assets/audio/ (ogg, small; total ≤ 6 MB). For every file: source URL, author, licence, any edits in assets/audio/CREDITS.md. No other downloads.
- Sounds: footsteps on grass (several variants, timed to the gait's foot contacts, volume by speed and creature size), grass rustle while moving through it, wind ambience (louder on high ground), an ambient meadow loop (birds/insects), creature cries (idle calls, aggro roar, hurt, death) pitched by body size, hit/block/dodge/spit sounds from combat events, UI clicks. WebAudio with a master/music/sfx volume and mute in the pause menu; positional (panner) for world sounds; starts after the first user gesture.

## Acceptance
- make test, make wasm-test (goldens bit-identical; new heading parity), make stage-test, make studio-test pass; web/hero regenerates byte-identical.
- Playwright (SwiftShader) checks: click-to-move reaches the target; hold-to-follow follows a moving pointer path; selecting the enemy and pressing a move makes the creature approach and attack; no foot sliding beyond the threshold; audio graph created after a gesture with no errors (no need to hear it).
- Evidence: docs/evidence/stage/polish/: a short frame strip of a curved walk (6 frames), click marker, selection ring, and a README with controls and what is verified vs not (feel and sound are judged by the owner).
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
