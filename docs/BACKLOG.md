# Backlog

> **2026-11-17: the creature stage's plan of record is now `docs/CREATURE-ROADMAP.md` (phases C0–C9).** This file keeps per-item state only. Electron, P7-as-web and web-first lines below are superseded by G76 (Godot desktop). Risks: `docs/RISKS-CREATURE.md`.

Order of work as of 2026-11-15. Decisions live in `docs/DESIGN.md` (G, W, Q
numbers); `docs/P4.md` is the P4 spec of record. Every item ends with tests,
evidence and the owner's approval, as in G25.

## 0. Engine migration to Godot 4, desktop (G76)

Process (owner rule, 2026-11-16): Opus or Fable write a plan (`docs/godot/PLAN-*.md`), Sonnet implements it, Claude verifies tests and evidence before merging. Each module documents its interface in `docs/godot/<MODULE>.md` and its evidence in `docs/evidence/godot/<module>/`.

| # | Step | Docs | State |
|---|---|---|---|
| M0 | Foundation: GDExtension over the C core, island with on-disk cache, terrain LOD, sky, sea, grass, chase camera, controls | PLAN-m0.md, M0.md | done (merged) |
| M1a | Creature builder port (body, 46 parts, materials, growth, IK rig) | PLAN-creature.md, CREATURE.md | done (merged) |
| M1b | Locomotion from morphology (G73) | PLAN-locomotion.md, LOCOMOTION.md | done (merged) |
| M2 | Studio (creator) in Godot | STUDIO.md | done (merged); parity pass merged (9b1abb7), honest gaps in STUDIO-PARITY.md |
| M3 | HUD, G75 card and radial, audio | UI.md | done (merged) |
| W | Wiring into one playable game, main menu, play test | WIRE.md | done (merged, e9710aa) |
| F1 | Feel: faster creatures, curved turns, pivots, camera (owner playtest) | PLAN-feel.md | done (2f5cf70) |
| F2 | Mountain rock material: biplanar mapping, detail, relief, quality tiers | PLAN-rock.md | done (ea0e31e, through step 10); baked sun shadows off by default, owner approval pending |
| F3 | Procedural action animations (G77): combat, social, intimidate, observe | PLAN-actions.md | done (0e35914, b232e19, aaa35f2) |
| F4 | C world uses the generated island heights (FIELD mode, `docs/godot/NAV.md`) | item 6 below | done (98cb49a) |

## 1. First MVP: a creature-stage slice you can play and enjoy

The MVP is done when the owner plays the valley for ~10 minutes (G58) and
approves the look, movement, fights and the P4 loop.

| # | Item | Decisions | State |
|---|---|---|---|
| 1 | Stage fixes: distinct enemy (Garfio), per-creature body radius in C, a winnable fight (35–80 %) | P3 | done (7e34932) |
| 2 | Grass anchored to the world; soft overcast shadows; deeper noon sky | P0 | done (d611d9f) |
| 3 | Palette: owner picked C "Current+"; A kept for a side-by-side at the end of the round | G63 | done (a1d9a8f) |
| 4 | Stage polish: Spore-like pointer movement, continuous heading in C, natural locomotion, CC0 audio | G57, G59 | done (8cc987f); owner playtest pending |
| 5 | Eroded terrain generator in C, v2 shape (island, massifs, stream-power erosion) | W11, W13, W14 | done (3757e28) |
| 5b | Alpine style (gentle bases, cliff bands, cirques, fans, varied layouts, hummocky floor) | W15 | in progress (codex) |
| 5c | **Core-loop feel first (G72)**: a lower, closer third-person camera with the horizon visible; fight readability (enemy wind-up, hits, dodges); fix the Firefox "valley could not open" error | G70, G72 | next |
| 6 | Terrain into the valley and stage (phase B): props re-placed, W12 guarantees, LOD far mountains, Worker + IndexedDB cache, pre-baked curated seed, C world height from the generator | W11–W13, G56 | next after 5b |
| 7 | P2 move-level tourney gates pass (prerequisite for P4) | G55 | in progress (codex) |
| 8a | P4 foundation: world simulation in C, agent observation and verbs | G56 | done (77ef7f5) |
| 8b | P4 social: befriending skills (sing, dance, charm, pose, gifts by diet), trust and bonds, defending a creature from a raid | P4.md, Q-3/4/17 | queued |
| 8c | P4 DNA: two meters (total only rises, balance is spent), awards for befriending, kills, carcasses, exploration; progress = species resolved / 4 | P4.md, G23, Q-1/8 | queued |
| 8d | P4 parts: discovery (drops with pity, carcasses, fossils), start inventory, tiers by DNA plus usage, mid-game editing at a minimal nest | P4.md, G37, G49, Q-2/5/6/10/11/19 | queued |
| 8e | P4 recipes and the first secret move, bone spines (new `espinas_dorsales` part, calcium meter, clues), through the same tourney gates | P4.md, G50–G53, Q-12/13/15/16 | queued (needs 7) |
| 9 | Minor tasks on free models: `make check` + README, Python world binding, calibration research, vista grass-disc fix | Q22, Q9/Q10 | in progress |
| 9b | Underwater biome art (G64) and the MVP batch of easter eggs (G65), art by parallel qwen3.6 agents (G66) | G64–G66 | in progress |
| 10 | MVP review: owner plays ~10 minutes, side-by-side palette C vs A, final fixes | G58 | last |

Discovery budget (G71): ~80 % core loop, ~20 % discovery; something new every 10–15 min; a deep secret move every 45–60 min; 6–8 deep secret moves for the whole creature stage (MVP: bone spines + rock armour, plus 5 shards and the nocturnal creature).

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
- **Simulated island genesis** (W19, future feature): lava-flow volcano construction, crumbling (landslides, flank collapses, caldera), then the v2 erosion; the material map comes from that history.
- The full island: 2–3 km, five biomes, offshore islets, caves sharing the tunnel network, landmarks including the meteor crater (W1–W5, W10), generated from a seed by the W11 generator with W6 guarantees.
- Fire simulation and a volcano biome (G52; W2 lists no volcano biome yet, only a landmark: decide when fire is designed).
- Weather (fog, rain) and seasons with migration (W8); living ecosystem (G11).
- One planet for every stage (W9); terraforming that depends on starting choices.

### Later stages and versions
- Civ/space: capture ancient ruins of an earlier civilization; ruined planets (G67).
- Cell stage and the bridge (v0.2), tribe + civ as one RTS in C (v0.3), space (v0.4) (Q8, Q23, G21, G28, Q56), each with its own design session.
- Procedural creature voices (Q40, G59).

### Benchmark, tooling and release
- Creature-stage calibration research from public sources (Q14, Q22, `docs/CALIBRATION.md`).
- A vectorised CPU batch mode for RL; a GPU port (CUDA with `-fmad=false`, or JAX) after P9, if RL needs millions of episodes.
- Formal trademark search for "Primigenia" in EUIPO/TMview and USPTO before P7 (G62).
- Local saves and creature export/import (G61), when P4/P5 need persistence.
- Rust only for new modules behind the C interface, if ever (G56).
