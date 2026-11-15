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

### Creator direction, 2026-11-12

The owner's new direction expands the creature creator toward freely authored,
more realistic creatures with geometry generated while parts are manipulated.
`art/reference/taller-de-criaturas.html` (identical to the supplied latest
`taller-de-criaturas(1).html`) is the creature appearance reference. Its physically
lit skin takes precedence over a toon-only interpretation of Q29/Q45 for
creature materials. The valley remains the environment reference.

The [functional creator design](CREATURE_VISUAL_PLAN.md) defines direct part
placement, generated anatomy and detail, artist control, and latency targets.
Art authoring must be able to exceed the simulation's current fixed part limits;
entering the game requires an explicit compatible projection and validation.
This does not change the benchmark's authority over game mechanics. The full
document, C/WASM integration, generalized rig, and AI generation remain future
implementation gates. The current web prototype exports `cpore.creature/3`
with independently editable seeded regions on the torso, neck, and tail, and
imports legacy `/1` and `/2` documents.

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

## 9. Game direction, 2026-11-14 (G1–G41)

A second design session. Its questions are numbered G1–G41 so they do not
collide with Q1–Q57. Where a G decision changes an earlier one, the earlier
line is named and the G decision wins.

### Direction and platform

| # | Decision |
|---|---|
| G1, G8 | **Game and benchmark together, game-first** ("Spore on steroids"). Supersedes Q1's benchmark-first. Both run on **one deterministic C sim**; there is no separate game sim. |
| G9, G10 | Develop in the browser (C core → WASM). The desktop app is **Electron** wrapping the same web build (supersedes Q42's Tauri: identical Chromium rendering everywhere). Desktop build comes after the first playable stage. |
| G33 | A public **creature-stage demo** ships after P7 (browser link + desktop build). Supersedes Q55's "nothing public before v0.4" for the game; the benchmark board stays private until ready. |
| G34, G39, G41 | Public name **Primigenia** (pending a trademark check on EUIPO/USPTO before P7). "cpore" stays the internal codename and file-format prefix. **Panspermia** is the story frame: life arrives on a meteor (cell-stage opening) and in space you seed other worlds (ties into terraforming). |
| G7 | Unreal and the Blender genome→mesh factory are parked. Blender is used for authoring parts only. |

### Look

| # | Decision |
|---|---|
| G2 | Creatures keep physically lit skin (the taller look) inside the toon BotW world (Q29/Q45), adapted with toon-compatible rim light and haze. Proven first with a **hero shot**: a studio creature in the valley reference. |

### Creator and parts

| # | Decision |
|---|---|
| G3, G15 | The Blender GLBs (`art/generated/parts/`) enter the studio as **rigid parts** that take the creature's palette and skin by material region (skin, keratin, membrane, eye; tagged in `sample_parts.py`). Parts that must deform (feet, arms, wings) are later rebuilt as procedural `growth.js` families. |
| G4 | The C genome is the authority. The web document is a superset that projects onto it, with game entry validated in C. Every part id is either a C part type or flagged cosmetic (grants nothing). |
| G5 | Meshes are generated in JS (`growth.js`, moved to a worker), not in C. Supersedes Q49. C/WASM is mandatory for the sim and the validator only; meshes are cosmetic. |
| G14, G20 | Part categories: mouth · eyes · arms/graspers · feet/legs · weapons (horns, spikes, clubs) · wings · fins · digging claws · details (frill, lure, shell, sacs). Each category grants its own kind of ability. **Parts decide movement modes**: legs → ground, fins → swim, wings → glide → fly, digging claws → burrow. Gills (underwater breathing) are scoped but not implemented. |
| G37, G40 | Parts are **discovered**, then **bought and levelled with DNA**. Sources: killing (a chance to drop one of the victim's parts, higher for rare kills and the epic creature), befriending (the species' signature part, guaranteed but slower), carcasses and fossils (random by biome and depth). Each medium hides its own finds: cliff fossils by gliding or flying, sunken bones by swimming, buried fossils, roots and water by digging. Part cost rises steeply with level. |

### Creature stage

| # | Decision |
|---|---|
| G16 | **Tactical real-time combat** on a fixed C tick (~10 Hz). Moves have wind-up, range, cooldown, stamina and a target zone. Depth comes from flanking, height, medium (air, water, ground, underground), counters (charge breaks guard, guard beats bite, spit beats charge) and status effects (stun, bleed, slow), not from reflexes. Humans control the creature directly through the same moves agents call by verb. |
| G19, G26 | Social play is as deep as combat. Species have **preferences** (song, dance, food gifts, displays) and a drifting mood; moves have timing and combos; rivals can interrupt; trust decays if you ignore a species. Gifts must respect diet (meat to a herbivore is an insult). **Defending a species from a raid** or feeding it builds trust. The Q43 ally (3) / dominate (3) loop stays as the progress rule. |
| G18 | Strategy layers: a **pack** with orders, **nest raids** against you, **your raids** on others, and **territory** (species defend home ranges). |
| G23 | **DNA only goes up** (complexity never decreases). Raids take **eggs** (future pack members plus a DNA bonus when they hatch), the **food store** (heals, stamina, gifts) and damage the nest. **Dying costs an egg** (you respawn as a hatchling); with no eggs left the stage is lost. Supersedes Q43's DNA penalty on respawn. |
| G24 | The **nest site** trades safety for access: open plain (close to food, easy to raid), mountain ledge (chokepoint, far, needs climbing or gliding), dug burrow (hidden, narrow entrance, needs claws), underwater cave (safe from land, needs swimming). Defence = site + guards + time away. |
| G29, G35 | **Expand and explore.** You bring food to the nest, and the nest hatches young. More burrows mean more eggs, but each one costs digging time, food upkeep and guards. Over-expanding spreads you thin. There is no hard cap. Hatchlings and allies take **roles that run on their own** (forager, guard, nurse, digger), and you can build **defences** (thorn walls, hidden entrances, alarm calls). The skill is a colony that survives while you explore, with defences built early. |
| G30, G31, G36 | A **Cognition** track bought with DNA competes with body parts. Tiers: 1 follow, attack my target, guard; 2 split the pack into groups from first person ("3 scout there, 2 attack that one"); 3 ambush, flank, waypoints, command befriended species; 4 a sketch of a tactical map. Interaction with developed species stays simple in the creature stage. **Every creature reaches tribe**: progress milestones grow the brain automatically, and DNA spent on Cognition unlocks tiers sooner and more technology later. Skipping Cognition gives stronger individuals with stronger movement abilities and leads to a "brawny" tribe start; investing gives a "cunning" one. |
| G27, G32 | Digging uses a **network of chambers and tunnels** in the normal terrain, with roots and water as resource nodes along it. Stretch goal (P8): small **soft zones** (sand, soil, snow) that deform for real, Bananza-style, only after performance and determinism are measured. |
| G17, G22 | Media arrive in phases, each verified on its own: ground, then swim + glide with dive-attacks, then full flight + digging. Supersedes Q43's ground+water-only and Q13's deferral. |

### Later stages and players

| # | Decision |
|---|---|
| G21 | **Tribe and civ are one RTS** in C (units, pathfinding, fog of war, economy, buildings, orders), differing only in units, technology, strategy and scale, on the creature stage's terrain. Creature movement, pathfinding, combat and pack orders are built as its base. Detailed rules still get their own session (Q56). |
| G28 | Creature-stage habits become tribe traits (burrowers → underground dwellings, swimmers → fishing and canoes, raiders → warriors, befrienders → domesticated allies). Starting choices carry through every stage, including terraforming. |
| G38 | For other kinds of players: **sandbox mode** (no raids or hunger), a **field journal** (species, parts, fossils, completion), and **creature sharing** (links exist now; a public gallery whose creatures appear as wildlife in other worlds comes after the demo). |
| G11 | The "steroids": creator freedom, LLM-driven rivals (through the benchmark verbs), BotW-grade visuals; then a living ecosystem and real depth per stage. |

### Phases (G25)

Each phase ends with automated tests, a playable browser demo, and a screenshot
or video the owner approves.

| Phase | Content |
|---|---|
| P0 | Commit current work; hero shot (a creator creature, physically lit, in the toon valley) |
| P1 | The owner's creator becomes the studio (G42) and the GLB parts fill its palette (G43) |
| P2 | C core on a fixed tick: movement, combat moves, stamina, determinism tests, canaries |
| P3 | WASM build + web stage: walk the valley as your studio creature, fight one species |
| P4 | Social depth, Q43 loop, part discovery and DNA, editing mid-game |
| P5 | Nest, eggs, food runs, roles, defences, pack orders, raids in both directions |
| P6 | Swimming (water food, underwater caves), glide with dive-attacks |
| P7 | Electron desktop build; public creature demo (name checked) |
| P8 | Digging and tunnels, full flight, territory, epic creature; stretch: soft zones |
| P9 | LLM rivals and the benchmark board |

Creature-stage calibration research (Q22) runs in the background with NAN
models and review, without blocking phases.

### The owner's creator becomes the studio (G42–G45)

| # | Decision |
|---|---|
| G42 | `art/reference/creador-de-criaturas.html` (the owner's demo, byte-identical to `~/Descargas/Creador de criaturas.html` of 2026-11-14) becomes the base of `web/studio/`, replacing the slider studio. It has direct spine sculpting, drag-and-drop parts with 3D thumbnails, IK legs, a gait derived from the parts, and Build / Paint / Test modes. Ported onto it from the old studio: redo, the `cpore.creature` JSON (new version with migrations), share links, es/en, the growth regions as an extra tool, and the tests. |
| G43 | Palette categories: mouths · senses · legs · arms · weapons · wings · fins · digging claws · details. The demo's animated procedural parts (IK legs, jawed mouths, blinking eyes) stay; the Blender GLBs fill the gaps (arms, wings, sacs, lure, tail club…). |
| G44 | Until after P1 the spine bends only in its vertical plane, with mirrored symmetry. Sideways bends, branching (extra heads or tails) and asymmetry follow CREATURE_VISUAL_PLAN later. |
| G45 | The P0 hero shot uses a creature from the new creator. |

### Acceptance criteria for P0–P2 (deepened)

Browser captures use software WebGL (SwiftShader); frame-rate claims are
measured by the owner in a normal browser. Every measurement names the browser
and settings.

**P0, hero shot.** Extract the actual renderer, light, tone-mapping and ramp
settings from `valle-primigenio.html` and `creador-de-criaturas.html`, and
define one shared lighting pipeline (colour space, tone mapping, exposure, sun)
for the toon world and the physically lit creature. Ground the creature with
contact shadow and grass occlusion. Render a fixed-seed grid (golden hour,
noon, overcast, night × close, mid, far). Accept when the creature's
luminance and saturation sit inside the environment's measured range, golden
images are stored, and a same-camera side-by-side with the reference has owner
approval plus a blind "does it belong?" check.

**P1, creator and parts.** A versioned part manifest (units, Blender→glTF axis
conversion verified through the exporter, attachment frame, named material
slots, polygon budget, LOD). All GLBs pass `gltf-validator` with zero errors and
match orientation in the Khronos Sample Viewer. Slot materials are replaced by
the creature's skin, keratin, membrane or eye material. An automated test
places every part on every preset with no floating or buried roots; the JSON
round-trips hash-identically; every projected genome passes the C validator or
is flagged cosmetic.

**P2, combat core.** Move data (wind-up, active and recovery ticks, reach,
stamina) and a counter matrix are tables, not code. Fixed 10 Hz tick,
per-tick state hash, per-subsystem RNG, no fast-math, `-ffp-contract=off`.
Accept when native and WASM hashes match over 10,000 ticks on every dev seed,
the payoff matrix has no dominant move, no build exceeds the agreed win-rate
ceiling in a scripted-bot tournament (random, greedy, counter-picker) with
Elo, idle and random canaries never win, and a short human playtest clip is
recorded.

### Lighting for the hero shot (G46–G47)

| # | Decision |
|---|---|
| G46 | One lighting pipeline for everything: **ACES Filmic** tone mapping. The valley's toon world is retuned for ACES (light about 2.5×, the 3-band ramp recomputed so the bands survive the curve) rather than giving materials separate tone mapping. Measured references: valley = no tone mapping, sun `#fff0d2` 1.2, hemi 0.72, blue fog 110–760; creator = ACES 1.05, sun `#ffcf9a` 3.1 low, hemi 0.35 + PMREM environment, amber fog 35–560. |
| G47 | The look is judged at **golden hour**; noon, overcast and night stay in the test grid. |
| G48 | Imported Blender parts that fit badly on creator creatures (wrong scale, floating, flat dark or thin; e.g. beak, wings, sacs, arms, tail paddle, frill) are **rebuilt as procedural parts** in the creator's own style (shared skin, keratin, membrane and glow materials; sized and attached to the spine surface like the creator's parts). Each GLB stays in the repo as the shape reference; part ids stay the same so saved creatures still load. (2026-11-14) |
| G49 | **Parts evolve in tiers** (e.g. claw → hooked → serrated). A tier is bought with DNA but unlocks only after a usage milestone with that part (fights won with it, tunnels dug, distance glided): you evolve what you use. (2026-11-15) |
| G50 | **Secret moves are recipes**: at least two parts plus one diet condition, never a single part. Each one spends a resource meter that the diet refills (calcium from carcasses, fuel from resin plants). Examples: bone spines (back spines + carnivore jaw + carcasses → piercing projectiles), thrown claws (digging claws + spring arm; the claw regrows), fire breath (spit sac + volcano resin plant → fuel). (2026-11-15) |
| G51 | Recipes are **hinted, not random**: some wild species already use the move, and fossils/carcasses of creatures that had it carry clues. Once discovered, a recipe is recorded in the codex. Finding a recipe by observation is also a benchmark task for agents. (2026-11-15) |
| G52 | **Fire changes the world**: it burns grass, scares creatures and cooks food, so fire spread is simulated deterministically in C. It arrives with the volcano biome. (2026-11-15) |
| G53 | Secret moves enter the same counter matrix and must pass the same tourney gates as every move: none may dominate; they win by surprise and are limited by their resource cost. (2026-11-15) |
| G54 | Schedule: P4 brings part tiers, the recipe system and the first secret move (bone spines); P6 the aquatic ones (e.g. ink jet); P8 fire breath and thrown claws. (2026-11-15) |

## 10. The world (W1–W10, 2026-11-14)

| # | Decision |
|---|---|
| W1 | The creature stage is **one large island, ~2–3 km across**. The sea is its natural edge (Q43's bounded region), and the start valley lies at its heart. |
| W2 | First island: **5 biomes** done well: meadow valley (start), forest, savanna/desert, alpine (rock and snow), coast and shallow sea. Each has its own species, food, parts and fossils. Jungle, taiga and tundra/ice (already in `cp4_biome`) come later. |
| W3 | **Mountains are vertical gameplay**: climbable faces gated by climbing parts, ledge nest sites (G24), glide launch points, summit fossils, passes as chokepoints between territories. |
| W4 | **2–4 offshore islets**, reachable only by swimming or gliding, with endemic species and parts. One is home to the epic creature. |
| W5 | **Natural caves** (cliff and underwater entrances) use the same chamber-and-tunnel network as dug burrows (G27). They are dark, which makes light-producing parts useful, and have their own fauna and fossils. |
| W6 | The island is **procedural in C from a seed** (deterministic), with guarantees checked automatically: start valley, mountain range, coast, N islets, M caves, every biome present, every place reachable with some combination of parts. Plus one **curated seed** for the demo and the hero shot. |
| W7 | Water by depth: rivers, lakes and sea now. **Shallow** needs fins (food, underwater caves); **deep** needs gills (reefs, trenches, rare fossils; scoped for later, G20). **Waterfalls** are obstacles or shortcuts. |
| W8 | Day/night now (Q43), with nocturnal predators and raids. Weather later (fog limits sight, rain hides scent). Seasons (migration, scarcity) arrive with the living ecosystem (G11). |
| W9 | **One planet for every stage**: the island is a region of it; tribe starts there, civ spreads over the continent, space sees the sphere (Q45), and terraforming changes these biomes. |
| W10 | **Landmarks** visible from far away in every biome (rock spire, giant tree, smoking volcano, sea arch), for navigation without a map. The start valley's landmark is the **panspermia meteor crater**. |
| W11 | **Mountains come from erosion**: terrain is generated in C (`core/src/terrain.c`) as a ridged, domain-warped base with a mountain mask, then particle (droplet) hydraulic erosion and thermal erosion, deterministic from the seed (CpRng, fixed droplet and iteration counts, native == WASM parity). Besides height it outputs flow and sediment maps that drive ground materials (rock ridges, scree fans, wet gullies, snow by height/slope/aspect). Natural-structure checks: Horton–Strahler bifurcation ratio of the drainage network ≈ 3–5 and Hack's law, plus vista renders. Distant terrain gets a level-of-detail mesh. (2026-11-15) |
| W12 | First slice now, between P3 and P4: the start valley and its mountain ring, replacing the analytic valley height; trees, rocks and nest are re-placed on the eroded terrain with W6's guarantees checked (flat start valley, reachable lake, dry nest). The same generator later builds the whole island. (2026-11-15) |
| W13 | **World creation may take up to ~10 s** (WASM, mid-range laptop): it runs in a Web Worker behind a loading screen told as the panspermia story, the result is cached in IndexedDB by seed + generator version, and the curated seed ships pre-baked so first play is instant. The work is fixed, not the time: a slow machine waits longer for the same world. (2026-11-15) |
