# Task: inventory of the island's creatures (design data, no engine code)
Read docs/DESIGN.md (Q43, G11, G18–G37, G49–G54, G65, G68, W1–W15), docs/P4.md (species profiles, temperaments, DNA, part drops), docs/eggs/brainstorm-a.md and brainstorm-b.md, docs/CALIBRATION.md, docs/WORLD.md, web/stage/species/garfio.json and web/studio/parts.json (part ids, categories, c_type).
Write docs/ECOLOGY.md, the creature roster of the island (W2 biomes: meadow valley, forest, savanna/desert, alpine, coast and shallow sea; plus caves, night, islets):
1. Per biome 4–6 species (the valley's existing Merodeador, Garfio, Rondo, Zanco, Espinodo included), each with: name (original, Spanish-flavoured like the existing ones), role in the food web (grazer, browser, predator, scavenger, filter feeder…), diet, size class, temperament (P4 Q-20), day/night activity, social structure (solitary, pair, herd, pack), the parts it carries (ids from parts.json) and which it can drop (G37), which recipe clue it carries or demonstrates (G51, G68: rock armour, bone spines, meteor shards, nocturnal), a one-line behaviour the player will remember, and which real animals inspire it.
2. A food-web diagram (mermaid) per biome and for the whole island.
3. Population numbers per biome for the MVP island and the full island, checked against docs/CALIBRATION.md where it has data.
4. web/stage/species/roster.json: the machine-readable version (id, name, biome, diet, temperament, size, activity, social, parts, drops, clue) that the C world and the art agents can consume. Validate it with a small script (unique ids, existing part ids, every biome covered).
Original creatures only. Commit.
## Rules for this task (read first)
- Project: "Primigenia" (codename cpore), a Spore-like game + LLM/RL benchmark. Decisions live in docs/DESIGN.md (§9 G1–G62 and §10 W1–W13 are the newest; G and W win over Q). Do not contradict them. P4 spec of record: docs/P4.md.
- Never modify anything under art/reference/ (byte-identical references).
- Browser screenshots: headless Chromium with SOFTWARE WebGL only: args ['--use-angle=swiftshader','--enable-unsafe-swiftshader'], executablePath ~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome. Playwright: NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules . Never use GPU flags. Run every browser/heavy process with `nice -n 10` and always close the browser. Keep renders to the minimum you need (the owner's laptop fans matter).
- Emscripten: `source ~/emsdk/emsdk_env.sh`.
- Do not install system packages, do not download SDKs, do not push, do not touch other git worktrees or branches.
- Commit your work on the current branch in small, clear commits as you go (the session may be killed; uncommitted work is lost). Imperative subject, body says what and why.
- Report honestly: if something is not done or not verified, say so. Do not fabricate measurements.
- Finish with a short report: what you built, files changed, commands run and their results, open issues.
