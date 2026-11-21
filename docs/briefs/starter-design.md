# Brief: a better starting creature — 4 candidate designs for the owner to pick

Worktree `/home/diego/Desarrollo/cpore-wt/starter-design`, branch `art/starter-design` (from main c012d75). Work only here.
Read first: `AGENTS.md`, `docs/canon/LOOK.md`, `docs/canon/MOTION.md`, `docs/DESIGN.md` A24, A25 (creator starts with few basic parts, small budget), A29 (~1 m, ~30 kg hatchling; Merodeador is the adult form), A31, `docs/godot/CREATURE-REALISM.md`, `docs/evidence/godot/creature-fit.md`.
Tracker test: C1/C6 (creator and play with what you made) — owner, 2026-11-21: "make a better initial design".

## Goal
Find where the starter/default genome is defined (the creator's default creature and the player's hatchling; start from `godot/game/stage/stage_world.gd`, the studio defaults and the genome presets), then design **4 candidate starter genomes** using only the basic starter parts (A25) and the starter budget. Each must:
- Read as a believable young animal (look canon §1, §4): proportionate head, eyes socketed, horn on the brow if any (creature-fit proposal: horn t 0.92, ang 0.55, len 0.65), legs that carry the body, a natural palette (no neon), countershaded belly as a gradient.
- Move well: run each through the locomotion scorecard as a zoo body (`godot/devtools/zoo/zoo_genomes.gd` pattern, `make godot-loco-score` with only these bodies, or the loco_score script with a body filter) and pass head pitch, slip and leg extension at least as well as today's hero.
- Pass `make godot-creature-fit` (0 failing).
- Be distinct from each other in silhouette and temperament, e.g. (A) sturdy quadruped grazer-hunter, (B) lean fast runner, (C) low armoured sprawler, (D) upright-ish long-armed knuckle-walker (fits the gorilla reference and the arms rule D-12). Today's hero is the comparison baseline (keep it as option 0).

## Deliverables
- Genomes as data files where presets live (do not change the default yet; the owner picks).
- Renders (software GL): each candidate side, 3/4 front, close-up, at midday and dusk, plus a 4-up contact sheet `docs/evidence/godot/starter/candidates.jpg` with labels A–D and 0 (today).
- A short walk clip per candidate via `godot/devtools/zoo/loco_clip.gd` to `/home/diego/Desarrollo/cpore-wt/_agent/starter-clips/` (outside the repo).
- `docs/evidence/godot/starter/README.md`: per candidate, parts used, budget, scorecard and fit numbers, one line of what it is like to play.
- A switch to make any candidate the default in one line (so Claude can apply the owner's pick).

## Rules
Visual/data only: no C, no gameplay numbers, no genome format change (if one is needed, write the proposal). Software GL, never the GPU (the owner is playing); `timeout` + `nice -n 10`; kill only your own pids; never `pkill -f`; no installs, no push. Run `make godot` first. Other agents work in skin-v1, integrate, limp: do not touch them. Commit as you go; do not merge.
