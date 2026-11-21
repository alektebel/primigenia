# Task: brainstorm easter eggs for Primigenia (documentation only)
Read docs/DESIGN.md G49–G54 (part tiers, recipes = at least 2 parts + 1 diet condition + a resource meter refilled by that diet, hinted by wild species and fossils, balanced through the same tourney gates, fire simulated), G65 (secrets are easter eggs), G23/G37 (DNA, parts), W1–W15 (island, biomes, caves, underwater, meteor crater), docs/P4.md (recipes, bone spines), docs/COMBAT.md (moves, counter matrix).
The owner wants easter eggs that are genuinely interesting. Owner ideas to develop in depth: a flamethrower; a creature adapted to space (vacuum/cold/radiation adaptations that later matter in the space stage); evolved bombs; befriending giants; eating rocks for rock armour.
Write docs/eggs/brainstorm-b.md with:
1. Each owner idea developed: exact recipe (parts + diet + meter), how it is discovered (which clue, where, which wild species shows it), what it does in the world and in combat, its counter (how it is beaten), its cost, which later stage it pays off in, and a short fun description a player would remember.
2. At least 10 more original easter eggs in the same format, from your angle (naturalist and storyteller: plausible biology (real animals that do similar things), the panspermia story, wonder and humour). Mix: secret moves, hidden places, rare creatures, lore (panspermia meteor shards), cross-stage payoffs, and a few pure-joy jokes.
3. A ranked shortlist of the 8 best, with why, and which 3 fit the MVP island.
Original ideas only (no copying of Spore or other games content beyond genre conventions). Commit the file.

## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
