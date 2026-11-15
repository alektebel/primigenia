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
| G55 | `docs/P4.md` open questions Q-1 to Q-20 approved as recommended (2026-11-15), including: two DNA meters (total only rises, balance is spent), tier = form and level = power, part drops 20% (35% Garfio) with pity on the 4th dry kill, start inventory pico/pata/ojo, recipes locked until 2 clues, a new `espinas_dorsales` part (`CP4_BACKSPINE`) for the spine volley, and **P2's move-level tourney gates must pass before P4 merges**. P4.md is the spec of record for P4. |
| G56 | From P4 the **whole world simulation runs in the C core** at 10 Hz (movement, perception, species, social, raids); JS only renders and sends inputs. The core stays C99 (no Rust rewrite: the determinism contract and native == WASM parity already hold in C). (2026-11-15) |
| G57 | **Movement like Spore's creature stage**: any direction, not octants. WASD/stick relative to the camera plus click-and-hold to walk toward the cursor, smooth turning toward the heading, the camera following behind. In C the heading is a quantised vector (integer components, normalised with sqrtf), so it stays deterministic. Replaces the 8-octant CB_V_MOVE. (2026-11-15) |
| G58 | P3 acceptance includes the owner playing ~10 minutes in a normal browser and reporting the feel (camera, speed, fight responsiveness). (2026-11-15) |
| G59 | **Basic audio now**, from public repositories with free licences (CC0 preferred, CC BY with credits): footsteps, grass, wind, creature cries and calls, hits, an ambient loop. Every file listed with source URL, author and licence in `assets/audio/CREDITS.md`. Supersedes Q40 for these basics; the procedural voice system stays later. (2026-11-15) |
| G60 | The public demo ships on **itch.io**: a playable web build plus Electron downloads (Windows, Linux, macOS). Steam later if it works. (2026-11-15) |
| G61 | Saves are **local only** (IndexedDB in the browser, a file in Electron) in the versioned `cpore` format, with creature export/import as a file. No accounts or cloud for now. (2026-11-15) |
| G62 | Trademark check, first pass 2026-11-15 (web search only): no video game or registered mark named "Primigenia" found; a similar name exists in tabletop games (the Argentine RPG *Pampa Primigenia*, label Primigenia Austral, 2024). A formal search in EUIPO/TMview and USPTO is still required before P7. The beak_crusher is accepted for now and redone when P4 tiers arrive. (2026-11-15) |
| G63 | Palette: the owner picked **C "Current+"** (current hues, stronger value contrast, less lime, warm light / cool shade) as the default golden look (2026-11-15). A "BotW" stays available as `pal=A` for a side-by-side review when the MVP round is finished; `pal=current` gives the previous look. |
| G64 | **Underwater biome art now, swimming later**: the lake and shallow coastal sea get a real underwater look before the MVP closes (caustics, kelp, coral, small fish, underwater fog, rippled sand, wrecks); swimming mechanics stay in P6, moved to right after the MVP. (2026-11-15) |
| G65 | **Secrets are easter eggs** and must be interesting: secret moves (recipes, G50–G53), hidden places (waterfall cave, cirque ledge, sunken cave), fossils (DNA, parts, recipe clues), panspermia meteor shards that tell the story and lead to the crater (W10), rare creatures (albino, nocturnal). Owner's easter-egg ideas: **flamethrower**, a creature **adapted to space**, **evolved bombs**, **befriending giants**, **eating rocks for rock armour**. Agents brainstorm more; the owner picks. MVP batch: bone spines, 3 fossils, 1 hidden cave, 5 meteor shards, 1 nocturnal creature. (2026-11-15) |
| G66 | **Game art is generated by parallel qwen3.6 agents**, procedural in JS like the existing parts and trees, each one iterating on its own renders (SwiftShader) toward realistic and beautiful, and every family reviewed by Claude before merging. (2026-11-15) |
| G67 | Civ and space idea (for their design sessions): **capture ancient ruins of an earlier civilization**, and **ruined planets**. (2026-11-15) |
| G68 | MVP easter eggs approved (2026-11-15): **rock armour** (eat stones on the alpine slopes → mineral meter → tougher, slower), **5 panspermia meteor shards** with one line of story each, leading to the crater, a **nocturnal creature** (a night variant with a befriending bonus in the dark), and **bone spines** (P4). The rest of the brainstorm (docs/eggs/) is spread over later phases: ink jet P6, flamethrower with the volcano P8, the space-adapted creature paying off in space. |
| G69 | Easter egg idea (owner, 2026-11-15): **evolve an arachnid silk sac to make webs**. Silk glands (a sac part + spinnerets) fed by an insect/protein diet fill a silk meter; webs trap and slow prey, string climbing lines and bridges across gorges, and reinforce the nest as a defence. Phase to be decided with the P5 nest defences and P8 climbing. |
| G70 | **What makes it engaging (design compass)**: three loops that each feel good on their own: second-to-second (moving and fighting feel good in themselves: responsive, weighty, clear feedback), minute-to-minute (choices with consequences: hunt or befriend, push on or return, spend DNA or save), and session (visible self-made progress: the creature physically changes because of your choices, the map fills, species resolve); plus self-expression (the creator, where parts change how you play), mystery (a goal always in sight; landscapes that call you), and stakes (nest and eggs, G23). Autonomy, competence and connection; no manipulative tricks. (2026-11-15) |
| G71 | **Discovery ratio**: about 80 % of play time is the core loop and about 20 % discovery. Something new every 10–15 minutes of play (mostly cheap secrets: shards, fossils, views, rare creatures, new species) and one deep secret move every 45–60 minutes. The whole creature stage gets **6–8 deep secret moves** (bone spines, rock armour, webs, ink, flamethrower, space-adapted, plus one or two more), each one changing how you play and discoverable by observation (G51); cheap secrets can be many. (2026-11-15) |
| G72 | **Priority order**: the feel of the core loop first (third-person camera, movement, fight readability), then P4 (decisions and progress), then the new island (mystery and landscape), then easter eggs. (2026-11-15) |
| G73 | **Realistic locomotion from morphology** (owner, 2026-11-15): movement is not a generic procedural walk; it is derived from the body: leg count, lengths and placement, mass distribution (centre of mass from spine radii, parts and their masses), support polygon and balance. Gaits are chosen by speed and size (Froude number), with phase patterns per leg count (biped, quadruped walk/trot/gallop, hexapod tripod), stride and cadence from leg length, the body's vertical motion as an inverted pendulum or spring-mass, counterbalancing neck and tail, slope and turn adaptation. Reference: Spore's own procedural animation (Hecker et al., SIGGRAPH 2008). Critical code: Codex or Opus. |
| G74 | **Photo-to-3D with Idol** (Speridlabs, Apache 2.0, local GPU): photos (owner's or CC0) of rocks, trunks, fossils and animal body parts become 3D assets (Gaussian splats converted to meshes and to the game's styles: toon for props, physical for creature parts). Owner approved the downloads (PyTorch, model weights) and GPU use for this pipeline. (2026-11-15) |
| G75 | **Selecting a creature** (owner, 2026-11-15): Spore's attack/befriend choice stays, improved. Clicking a creature opens a rich card (species, temperament, diet, relationship stranger → ally, how many of that species you have resolved, a hint of what it likes) and a radial menu with four modes: **Attack**, **Befriend** (rhythm and timing with combos and habituation, gifts matching its diet, trust earned by defending it), **Observe** (stay near unseen to learn behaviour; this is how recipe clues are found, G51) and **Intimidate** (drive it off from food or territory without killing: no kill DNA, no relationship damage). Each mode puts its abilities on keys 1–4. Consequences: hunting one member lowers the trust of its whole herd; aggressive creatures must be calmed (gift, submission) before they accept social play. **Built to scale** to the later stages: the same select → card → radial-mode model and the same id-targeted verbs (`attack #id`, `befriend #id`, `observe #id`, `intimidate #id`) carry over to tribe, civ and space units and to the LLM/RL benchmark (Q10). |

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
| W14 | The island is **~3.2 km across inside a 3.6 km square** (supersedes W1's "~2–3 km"): a real range needs the room. (2026-11-15) |
| W15 | Mountain style is **alpine, not volcanic**: gentler lower slopes with meadows, benches and terraces, cliff bands and cirques higher up, rock and snow on the tops; walkable approaches for climbing and ledge nests (W3, G24). Erosion must not leave visible "simulation" artefacts (uniform parallel rills, identical gullies). (2026-11-15) |
| W16 | **Cliffs now**, added to the v2 generator: sea cliffs along part of the coast (instead of beach everywhere) and hard-rock bands that erode less on the massifs; they feed climbing and ledge nests (W3, G24). (2026-11-15) |
| W17 | **One volcano on the island now, as a landmark shape**: a stratovolcano replaces one massif (cone, summit crater, dark rock, old solidified lava flows, smoke). Active lava and fire come in P8 with G52 and the flamethrower, whose clues live there. It is the island's volcanic biome, which W2 did not list. (2026-11-15) |
| W18 | **Caves stay simple**: no tunnel network. The generator places a few cave entrances in cliffs and slopes; each cave is a short, simple mesh (one entrance passage and one or two chambers), including the MVP's hidden cave behind a waterfall (G65). The full chamber-and-tunnel network (W5, G27) is no longer planned. (2026-11-15) |
| W19 | **Simulated island genesis** (future feature, after the MVP; not scheduled): the generator becomes a three-stage geological history, deterministic and inside the W13 budget. (1) **Volcanic construction**: vents erupt over simulated epochs and a lava-flow cellular automaton (flows follow the steepest descent, cool and solidify, stack in layers) builds the volcano and leaves old flows, lava tubes and benches, replacing W17's shape-only cone. (2) **Crumbling**: slope failure by material strength (fresh lava, old rock, scree), with landslides, flank collapses that leave amphitheatre scarps and debris fans, and possibly a summit caldera collapse. (3) **Erosion**: the existing v2 stream power, droplets and thermal passes carve the result. The material map (rock age and type) comes from this history. (2026-11-15) |
| W20 | **Terrain for the MVP = Fable's v2 + cliffs + caves** (owner, 2026-11-15): v2's massifs, erosion and look stay exactly as they are; on top only sea cliffs, high cliff bands with resistant strata, cave entrances (W18) and the material map. The volcano shape (W17), the gentle-lowland remap and the extra layout variety from W15 are switched off by default (kept as parameters for later); W15's gentle-slope gate is dropped. |
| W21 | **Real elevation data for calibration**: free open DEMs (Copernicus GLO-30) of real ranges (Alps, Picos de Europa, Madeira, Canary Islands) are used to measure slope distributions, valley profiles and drainage statistics and compare them with the generator; optionally as a base for parts of the island. (2026-11-15) |
