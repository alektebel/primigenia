# Where we are, and the stages to the MVP

Status: **2026-11-20**, plan of record. It refines `CREATURE-ROADMAP.md` (C0–C9) for the next weeks. The MVP is now
**two stages, played one after the other**: the cell (a small metabolic factory) and the first hour of the creature on the
island. Each stage below ends with a deliverable and an **owner gate** (you play it and say yes, or what to change).

## The MVP, in one sentence
From the menu you play the cell from first enzyme to colony, carry its legacy into a 1 m hatchling, and spend the first
hour on a natural-looking, living island: hunt, befriend, dig, find wings, fly, evolve at will and get the flamethrower,
guided by a short task chain, with no blockers, in Spanish and English, running well on the RTX 5060 and a mid-range PC.

### MVP checklist (all must be true)
1. Menu → Célula: phases 1–6 playable, the carry-over sheet saved.
2. Menu → Criatura: the hatchling starts with the cell's diet, part and size.
3. The first task chain (kill → befriend → dig → wings → flamethrower) completes by hand and by the e2e bot.
4. Movement feels good: run, falls, bird-like flight, gaits that look natural for any body.
5. The island looks natural (light, grass, plants, rocks, water, spring, caves, cliffs) and has roaming predators.
6. The creator: direct manipulation (scale, joints, spine, actuator ring, wings), edit anywhere, play with what you make.
7. Saves, settings, ES/EN, onboarding for the first 10 minutes, a minimal audio pass.
8. Performance: ≥ 60 fps on the RTX (high tier), ≥ 30 fps low tier on a mid-range iGPU; all suites green; replays bit-exact.

---

## Stage 0 · Done (merged in main, 2026-11-19/20)
- **Stage picker menu** (Célula / Criatura cards with the arc art, later stages "próximamente"), menu-first boot.
- **Cell stage**: the owner's prototype ported (Energía, Residuos, Membrana, Crecer → Agregación), phase 5 Threats
  (phage/CRISPR, antibiotic/efflux pump, oxidation/catalase, amoeba/size+spines), phase 6 Colony, the carry-over sheet.
- **Creature**: 1.2 m hatchling starter; run with Shift + stamina; falls and landing damage from impact speed;
  run gait (trot/gallop by Froude, spine arch, metachronal ripple); flight test mode with procedural wings
  (`make godot-fly`), ground takeoff fixed; health bars; LMB never moves the camera; round clouds; edit anywhere;
  plant observation journal; island kept in memory (re-entry 3–5 s instead of 11–13 s).
- **Creator**: wheel scales parts, live joint drag, spine end arrows, actuator ring on click, wing panel, "Jugar con esta criatura".
- **Earlier C2 work**: parts discovery + nest + eggs, secrets (shards, cave, day/night, Acechalunas, Babosa), journal, flora,
  radial bodies, lineage and cousins.
- **Plans of record**: `world-look-plan.md` (WL1–WL10), `motion-flight-plan.md`, decisions DESIGN.md A26–A31.

## Stage 1 · The first playable hour (in progress) — deliverable: the task chain, end to end
| Work | State |
|---|---|
| 8 C2 moves + recipes, B3 gate redefined (bone-spine volley) | branch ready to merge after its main merge + tourney |
| First task chain: tasks UI, dig verb + fossil beds, wings from a fossil, fire gland + flamethrower, e2e bot | building |
| Owner tweaks: fall damage 10/m capped, input log v4, ES legend, dev-only lift_mul, keep parts in dev, ring reasons, spine generates vertebrae + neighbours follow | building |
| Bird-like turning (roll leads, pull-up, asymmetric wings, partial camera roll, mouse steering) | building |
| Species 7–8 (brujula, corona), Garfio passive until first evolution + grace minute, Acechalunas wakes by day | Codex, resumes after the quota reset |
| Cell legacy consumed by the creature (diet, starting part, size class) | next |
**Gate 1:** you play the chain from a new game: hunt, befriend, dig, fossil wings, fly, flamethrower, in about 20–30 minutes.

## Stage 2 · The island looks natural — deliverable: a screenshot session on the RTX
WL1 one lighting model (building) → WL2 meadow and grass → WL3 ecological placement → WL4 rocks without repeated
textures → WL5 rivers cut down on screen, irregular lake shore, the real spring → WL6 caves meshed from a distance field
(the C++ mesher is done, art next) → WL8 cliffs that read as cliffs → WL10 wind, fog, small life.
**Gate 2:** you walk nest → meadow → spring → cave → cliff on the RTX and nothing looks "popped in"; frame times measured
on the RTX and the AMD iGPU.

## Stage 3 · A living island — deliverable: a predator encounter you remember
WL9 roaming predators (Garfio pack on the valley rim, Acechador in tall grass, Glacior on the high pass) with patrols on the
walk grid; WL7 the false wall in the cave (cue + break + side room); ECOLOGY.md species list merged; day/night and the
nocturnal secret tuned; the cell's legacy shapes the start.
**Gate 3:** you are hunted once, escape or win, and find the false wall without being told.

## Stage 4 · Motion that looks real — deliverable: a blind A/B you prefer
M1 gait optimiser pilot (MuJoCo + CMA-ES, Codex) → M2 predictor from body features → M3 predicted gaits in the game with
an A/B toggle; S2 speed from body size (Froude); W1 articulated wings that fold and bend; F2 flight moved into the C sim
(replays, wild creatures see you fly).
**Gate 4:** blind A/B ≥ 65 % for the new gaits; flight feels right to you.

## Stage 5 · MVP polish — deliverable: the MVP build
Onboarding for the first 10 minutes (no text walls); a minimal audio pass (steps, wings, fire, ambience, music sting);
settings and ES/EN complete; save/load across both stages; the 3D pull-back scene at aggregation (cell → hatchling);
performance tiers; a bug bash with the e2e bots on several seeds.
**Gate MVP:** you play cell → creature first hour without blockers; then 3–5 outside players try it.

## After the MVP (unchanged order from CREATURE-ROADMAP.md)
C3 nest, eggs, pack and raids · C4 water and air (swimming, gliding dive attacks) · C5 the deep game (digging proper,
volcano and fire, the 8 deep secrets, the crater) · C6 content and polish · C7 the ending · C8 release · the lore council's
tech trees for Band, Realm, Industry and Space (A30) · the continent as the creature stage's second act.

## Running right now
Sonnet: WL1 lighting, B3 + moves merge prep, owner tweaks, first task chain, bird-like turning. Codex (after 02:31):
species v8, gait optimiser pilot. Lore council: worlds 6 of 13 (spectrum).
