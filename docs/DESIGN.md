# cpore — design decisions

A record of the design session of 2026-11-11 (Q1–Q57). Each line is a settled
decision; later milestones may refine it but should not silently contradict it.
"Spore" below refers to the 2008 Maxis game, as the reference for mechanics
only — no assets, names, text or data are taken from it.

## 1. What this is

| # | Decision |
|---|---|
| Q1 | A **research benchmark** first. Fidelity to Spore is kept where it creates the arc, the genre shifts and the design decisions that make the benchmark unique; cosmetic fidelity is optional. |
| Q36 | Human-facing side: ship a showcase + human-baseline client through v0.4, but architect for a real open-source game (Thrive-like) afterwards. |
| Q2 | Supports **LLM agents and RL policies** on one C core with two faces: text/JSON verbs and float vectors. |
| Q4, Q28 | Public, MIT code, CC BY 4.0 art, original naming everywhere (no "Spore", no Maxis/EA terms). README states it is an independent fan tribute. The Lochner mesh port is MIT (copyright kept). Public name decided before v0.4. |
| Q3 | The base is the full environment at commit `ca08f0f` (all stages, Python/Puffer/text gym), restored and reorganised; the current SDL creature creator is merged in as the creature-stage studio. |

## 2. The arc and the score

| # | Decision |
|---|---|
| Q8 | Five stages, as in Spore: **cell → creature → tribe → civ → space**. The old aquatic stage is folded into creature as water biomes and swimming. |
| Q6 | Headline score: **stages won, then decisions used** (lexicographic). Tokens and cost are reported, not ranked. |
| Q18 | Decision caps (of ~10k per arc): cell 1,000 · creature 2,500 · tribe 1,500 · civ 2,000 · space 3,000. Hitting a cap loses the stage. Caps are re-tuned to ≈3× the scripted baseline. |
| Q7 | Besides the arc, every stage has fixed **standard start states** so later stages are scored even when an agent fails early. |
| Q5, Q13 | 3–5 seeds per run. Public dev seeds; hidden test seeds rotated each season. |
| Q21 | One difficulty (Spore's default) for the main board. |
| Q17 | Choices carry forward as **named consequence traits** with mechanical effects, listed in the observation (e.g. cell diet → creature ability → tribe start). |
| — | Each stage ends on an explicit `advance` action when its progress bar is full, never automatically. DNA (currency) and progress (bar) are separate meters. |
| Q19 | Space is scaled to ~300–500 stars and ~8 empires; the win is reaching the galactic core past a hostile guardian empire (original name). Terraforming tiers, hauled spice and missions keep the shape. |

## 3. How agents play

| # | Decision |
|---|---|
| Q9 | LLM observation: **structured JSON** (nearby entities with ids, relative bearing/distance and type; own stats; progress; traits; legal verbs) plus a short prose summary. |
| Q10 | LLM actions: **id-targeted verbs** (`approach #12`, `bite #12`, `sing #12`, `eat #4`, `go_nest`, `explore <bearing>`, `edit {genome}`, `advance`, …) resolved by the engine until done or interrupted. RL keeps the float interface. |
| Q15 | Two layers: **macro orders** (standing plans run by an autopilot, one decision each) and **micro verbs**, freely mixed. |
| Q16 | Macro orders are interrupted only by a fixed, versioned event list: damage/threat in sight, hp < 40 %, new species/tribe/empire met, progress full, editor unlocked, plan finished or impossible, periodic check-in. |
| Q11 | Editors take a **JSON genome** priced and validated in C; invalid or over-budget designs are rejected with a readable error, never silently trimmed. |
| Q47, Q26 | One genome schema everywhere (studio, sim, LLM, RL, renderer): a **parametric body** (spine, girth, legs, neck, head, colours, pattern) plus a list of **placed parts** (anchor, direction, type, level 1–5) that grant abilities. |
| Q12, Q25 | One fixed reference harness for the main board (same prompt, last ~20 turns + a model-writable notes scratchpad + current state, no tools/web), provider-default reasoning, temperature as recommended or 0.2, one OpenAI-compatible client (NAN gateway for development). Reasoning tokens reported separately. An "open harness" track is labelled as such. |
| Q48 | Model-facing text is English only; the human UI is bilingual es/en. |
| Q20 | Every board release has reference rows: idle, random, scripted, PPO, human. Agents scoring below idle/random are flagged. |

## 4. Trust

| # | Decision |
|---|---|
| Q24 | Every run writes a **replay** (seed, engine version, action log, per-turn state hash). Anyone can re-simulate and verify bit-for-bit; outside submissions need a replay. Official determinism: x86-64 Linux and the WASM build, no fast-math, RNG split per subsystem. |
| Q52 | Tests: determinism (native = WASM hash), observation schema contract, **canaries** (idle and random never win a stage; no rewarded counter is farmable without cost), bench-mode golden images. |

## 5. Calibration against Spore

| # | Decision |
|---|---|
| Q14, Q22 | The game is **not** bought. `docs/CALIBRATION.md` is compiled from wikis, guides and timestamped YouTube runs (let's plays, speedruns). Every number cites a source and a confidence: *confirmed* (2+ sources), *single-source*, or *our design*. Facts in our own words only; video observation beats wiki text on conflict. |

## 6. Look and front end

| # | Decision |
|---|---|
| Q27 | All old software renderers are removed. |
| Q29, Q39 | Art direction: **BotW-style** (cel shading, painterly sky, haze, wind-swept grass, rim light) on Spore-like content, one style across every stage. Technique only — no BotW assets, characters or UI. |
| Q41 | `art/reference/valle-primigenio.html` is the visual and rules reference ("golden" look); its code is not the base. |
| Q42 | **Web-first** front end in Three.js (current release), C core compiled to **WASM** in the browser and to a native `.so` for Python; a PC build later wraps the same front end (Tauri). |
| Q31 | The renderer only reads per-frame snapshots; the core never links graphics (`make core` needs no SDL/GL/window). |
| Q49, Q35 | Creature meshes are generated in C (`mesh/`, Lochner skinned body + parts, also WASM) and handed to Three.js as buffers; every creature, NPCs included, uses them with cheaper versions at distance. |
| Q32 | The front end is the replay viewer, the human client (same verbs as agents) and the creature studio. |
| Q44, Q33 | Every stage has two modes: **Naturalist** (humans, video) and **Bench** (low-poly, fixed 768×480, HUD burned in). Pixel observations are an *experimental* vision track from v0.1; JSON stays the main board. |
| Q45 | Shared visual kit: toon material (3-band ramp + rim), fog/haze, sky, per-vertex wind, instanced scatter, water, genome → mesh. The planet's terrain is one function: flat in creature/tribe/civ, spherical from space. |
| Q46 | Scenes: cell — a tide pool from inside the water (top-down 2.5D, caustics, rim-lit translucent cells); creature — the valley; tribe and civ — the same world from higher cameras (huts, cities, vehicles, spice geysers); space — a toon planet with atmospheric rim and a painterly galaxy map. |
| Q34 | Renderer milestones track the sim; v0.1 is judged by a "hero shot". |
| Q37, Q38 | Fable delivers `art/STYLE.md` + concept sheets with a parameter table per item (hex colours, band thresholds, outline px) and provenance notes. |
| Q40 | No audio before v0.4; procedural creature voices later. |

## 7. Stage rules settled so far

| # | Decision |
|---|---|
| Q43 | Creature v0.1 adopts the reference prototype's loop: per-species **ally (3 befriended) or dominate (3 hunted)**, an epic creature, evolution choices at DNA thresholds, respawn at the nest with a DNA penalty, temperaments. Kept from the old C stage: biomes and day/night. Dropped: the unbounded world (a bounded region instead); only ground and water media in v0.1. |
| Q56 | Tribe, civ and space verbs, events and exact rules are designed at the start of their milestones, in their own design session. |

## 8. Delivery

| # | Decision |
|---|---|
| Q23 | v0.1 creature stage → v0.2 cell + bridge → v0.3 tribe + civ → v0.4 space, full arc, first public board. |
| Q51 | v0.1 is done when: idle < random < scripted and ≥ 1 LLM beats scripted over 5 test seeds; all replays verify in Python and WASM; the Naturalist hero shot holds up next to the reference; a studio-made creature plays in the sim; creature calibration is written with sources. |
| Q50 | Layout: `core/ mesh/ bindings/{python,wasm} harness/ web/ art/ docs/`; `core/` depends on libc/libm only (CI-checked). |
| Q53 | Claude Code: core, architecture, review. NAN models: bounded parallel work, always reviewed. Fable: art. The owner: design decisions and milestone approval. One branch + PR per milestone, with board table and screenshots. |
| Q54 | The v0.1 board uses NAN-hosted models plus reference rows; paid frontier models from v0.4. |
| Q55 | Static publication on GitHub Pages from `web/`; official results versioned under `results/`; nothing public before v0.4. |
| Q57 | Order: this document → restore `ca08f0f` on a new branch and reorganise → creature-stage calibration research. |
