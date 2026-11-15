# Backlog

Order of work as of 2026-11-15. Decisions live in `docs/DESIGN.md` (G, W, Q
numbers); `docs/P4.md` is the P4 spec of record. Every item ends with tests,
evidence and the owner's approval, as in G25.

## 1. First MVP: a creature-stage slice you can play and enjoy

The MVP is done when the owner plays the valley for ~10 minutes (G58) and
approves the look, movement, fights and the P4 loop.

| # | Item | Decisions | State |
|---|---|---|---|
| 1 | Stage fixes: distinct enemy (Garfio), per-creature body radius in C, a winnable fight (35–80 %) | P3 | in progress |
| 2 | Grass anchored to the world (it slid with the camera); overcast shadows; noon sky | P0 | in progress |
| 3 | Palette: the owner picks A (BotW) / B (Spore) / C (current+), then it is applied to hero, stage and terrain | owner playtest | variants in progress |
| 4 | Stage polish: Spore-like movement (click/hold to follow the pointer, WASD, any direction, continuous heading in C), natural locomotion (acceleration, curved turns, stride locked to distance, lean, head look), basic CC0 audio with credits | G57, G59 | implemented; automated checks pass, owner playtest pending |
| 5 | Eroded terrain generator in C (phase A: generator, parity, Horton/Hack checks, terrain lab) | W11, W13 | in progress |
| 6 | Eroded terrain in the valley and stage (phase B): props re-placed, W12 guarantees, LOD for far mountains, Worker + IndexedDB cache, pre-baked curated seed | W11–W13 | queued |
| 7 | P2 move-level tourney gates pass (prerequisite for P4) | G55, P2 | queued |
| 8 | P4: world simulation in C (movement, perception, species, social), social depth, DNA (two meters), part discovery, tiers, recipes, bone spines, mid-game editing at a minimal nest | P4.md, G49–G56 | queued |

## 2. After the MVP (the tail)

Prepared once the MVP is approved, roughly in this order.

### Creature stage, later phases
- **P5**: full nest, eggs and hatching, food runs, pack roles and defences, raids in both directions, burrows and the egg cost of dying (G18, G23, G24, G29, G35).
- **Cognition track** and pack orders by tier (G30, G31, G36).
- **P6**: swimming (shallow water food, underwater caves), gliding with dive attacks; aquatic secret moves such as an ink jet (G17, G22, G54, W7).
- **P7**: Electron desktop build; public demo on itch.io (web + Windows/Linux/macOS) (G9, G60); minimal demo audio done by then (G59).
- **P8**: digging with chambers and tunnels (roots, water, fossils), full flight, territory, the epic creature (Coloso), fire breath and thrown claws (G27, G32, G52, G54); stretch: soft zones.
- **P9**: LLM rivals and the benchmark board (Q2, Q9–Q12, Q16, Q18, Q20, Q51, Q54).
- Gills and deep water (G20, W7). Beak crusher redone as a P4/P5 tier (G62).
- Sandbox mode, field journal, photo mode for other kinds of players (G38).

### The world
- The full island: 2–3 km, five biomes, offshore islets, caves sharing the tunnel network, landmarks including the meteor crater (W1–W5, W10), generated from a seed by the W11 generator with W6 guarantees.
- Fire simulation and a volcano biome (G52; W2 lists no volcano biome yet, only a landmark: decide when fire is designed).
- Weather (fog, rain) and seasons with migration (W8); living ecosystem (G11).
- One planet for every stage (W9); terraforming that depends on starting choices.

### Later stages and versions
- Cell stage and the bridge (v0.2), tribe + civ as one RTS in C (v0.3), space (v0.4) (Q8, Q23, G21, G28, Q56), each with its own design session.
- Procedural creature voices (Q40, G59).

### Benchmark, tooling and release
- Creature-stage calibration research from public sources (Q14, Q22, `docs/CALIBRATION.md`).
- A vectorised CPU batch mode for RL; a GPU port (CUDA with `-fmad=false`, or JAX) after P9, if RL needs millions of episodes.
- Formal trademark search for "Primigenia" in EUIPO/TMview and USPTO before P7 (G62).
- Local saves and creature export/import (G61), when P4/P5 need persistence.
- Rust only for new modules behind the C interface, if ever (G56).
