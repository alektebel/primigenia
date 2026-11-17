# The full arc: development plan

Status: **draft plan, 2026-11-17.** Replaces `ARC-PROPOSAL.md`. The owner has
approved the six stages (A1–A3 in `DESIGN.md` §11). Rules for each stage still
get their own design session before it is built (Q56). This document fixes the
shape: what each stage is, how choices travel to the end, and the build plan.

Arc: **Cell → Creature → Band → Realm → Industry → Space.**

---

## 1. The lineage: earlier choices reach all the way to space

The owner's rule: **what you became early on still matters among the stars.**
An aquatic species doesn't need to terraform ocean worlds. A species that can
survive vacuum can fly unpressurised ships and, given enough resources, build
its own planets.

### 1.1 One mechanism: environment vs tolerance

Every place you can live (a biome, an island, a planet, a moon, an asteroid,
a ship's hull) has an **environment vector**. Your species has a **tolerance
vector**. The gap between them is what it costs to live there.

| Axis | Environment (a place) | Tolerance (your species) built from |
|---|---|---|
| Medium | water / land / air / vacuum | fins+gills, legs, wings, void adaptation |
| Pressure | 0 (vacuum) … crushing (deep sea, gas giant) | sealed skin, swim-bladder, gas sacs |
| Temperature | frozen … molten | body size (G78 Bergmann), fur/shell, fire glands |
| Atmosphere | none / thin / breathable / toxic | lungs, gills, filtering organs |
| Gravity | asteroid … super-earth | leg strength, body size |
| Radiation | sheltered … unshielded | rock armour, mineral diet, burrowing |
| Light | dark … blinding | nocturnal eyes |
| Food base | what can be eaten there | diet (herbivore, carnivore, mineral, filter) |

**In space, there are three ways to settle a world, and you pick by cost:**
1. **Terraform:** change the planet towards your tolerance (slow, expensive).
2. **Adapt:** change your species towards the planet with genetic engineering.
   It's cheaper the closer your lineage already is.
3. **Enclose:** domes, ships, habitats. The cost depends on the gap. A void-adapted
   species needs no pressure hull, so its ships and habitats are much cheaper.

Spore only had (1). Doing all three is how the lineage pays off. It's also a real
decision for the benchmark.

The same vector already works in earlier stages: biomes in creature, which
islands you can colonise in Realm, where you can build cities in Industry.
So it gets built once, in C, and grows with each stage.

### 1.2 Named lineage traits and what they do at each stage

The old `core/src/lineage.c` ("one creature carried across five games")
already carries a lineage between stages. It gets extended into a **trait
ledger**: each trait is earned in one stage and has a defined effect in every
later stage. These are the headline traits (the full list gets set in each
stage's design session):

| Trait (earned in) | Band | Realm | Industry | Space |
|---|---|---|---|---|
| **Aquatic** (cell filter-feeder / creature swimmer, gills, water nest) | fishing camps, rafts, dive for food | naval power, coastal and floating farms | tidal energy, undersea cities and mining | **ocean worlds and ice moons with buried oceans count as home: no terraforming**; water-filled ships |
| **Void-adapted** (creature secret, G68: sealed skin + radiation sacs + cold) | survive peaks and cold nights | mountain fortresses | cheap high-altitude industry, cheaper launches | **unpressurised ships and habitats; live on airless moons and asteroids; with enough mass, build your own planets** (worldsmithing, §6) |
| **Burrower** (digging claws, burrow nest) | dug homes, hidden camps | underground cities, mining bonus | deep mines, geothermal | hollowed asteroids, colonies under the crust of hostile worlds |
| **Flyer / glider** | scouting, cliff camps | messenger birds, early mapping | early aviation | **floating cities on gas giants** (and a bonus with the tentacled gas-giant species) |
| **Fire-breather** (flamethrower recipe) | early control of fire, burning grass | metallurgy ahead of time | combustion efficiency | plasma weapons and engines |
| **Silk-spinner** (G69) | nets, rope, bridges | textiles, rigging | cables, suspension bridges | **space elevator** unlocked early |
| **Rock-eater / rock armour** (G68) | stoneworking | quarries, fortresses | ore efficiency | **lithotrophs: barren rock worlds have food** |
| **Nocturnal** | night raids and hunts | spies | night shifts (more output) | dark worlds far from their star are habitable |
| **Befriender** | befriended species hunt with you | domesticated mounts and draft animals | multi-species society | **uplift** other species into allies; diplomacy bonus |
| **Predator / raider** | warriors | conquest bonus | military industry | militarist start, feared by others |
| **Giant / small** (G78) | strong but few / many and quick | heavy infantry / swarms | heavy labour / dense cities | high-gravity worlds / low-gravity worlds and small ships |
| **Settled / nomadic** (Band → Realm choice) | — | farms and cities / horse-lords | planned / mobile economy | colonies / fleets as home |
| **Planet health** (Industry) | — | — | you make it | terraforming cost, how others first see you, the home world's late game |

**Action for now:** the creature stage should already **write traits into the
ledger** as players earn them (aquatic, void-adapted, burrower…), even before
later stages exist. Saves and replays will then carry them forward (step L0 in §7).

---

## 2. Band (hunter-gatherer): a dynamic RTS in third person

**Fantasy:** you are still your creature, now the chief of a band of 10–40.
You fight, sing and hunt with your own body, and at the same time you lead
everyone else.

**Shape:** a hybrid of action and RTS. In design-doc shorthand: *Brütal
Legend*, *Sacrifice*, *Mount & Blade* and *Spellforce* (games named here only
as references for the mechanics).

| Pillar | How it plays |
|---|---|
| **Avatar** | Direct 3rd person (1st person as an option) control of the chief, with every creature-stage move (combat, befriend, intimidate, observe) |
| **Command while you move** | The G75 radial grows: point and order ("hunters: flank that herd", "gatherers: berries there", "guard the fire"). Hold a key for a **tactical overhead view** (time slows down, not paused), then drop back into the body |
| **Group hunts** | Herds migrate. Drive them into ambushes, off cliffs (W16) or into nets (silk). Big prey needs coordination, not just DPS |
| **Seasons and migration** | The camp moves with the herds and the seasons. Winter means stockpiles or moving south. The island's biomes (creature map, W) become the seasonal route |
| **Craft and fire** | A small tech web: fire, spear, sling, rope, raft, pottery, tamed animals. Lineage traits unlock the first branch (§1.2) |
| **Other bands** | Raid, trade, intermarry (merge bands) or drive them off. They are rivals run by the same C AI as LLM rivals (P9) |
| **Stakes** | If the chief dies, a band member becomes the new avatar (the same idea as the egg rule, G23). If the band dies out, the stage is lost |
| **Sacred stone** | The meteor crater is a shrine. Gathering there unlocks story and band morale |
| **End** | When the band is big and skilled enough: **settle** (plant the first field) or **stay nomadic**. That decides how Realm starts |

**Tech:** the same island and terrain as creature (now loaded with 10–40
agents, the herds and rival bands), C pathfinding and steering for groups,
formations, simple jobs (gather, haul, craft, guard). In Godot: one creature
rig per person with LODs, a MultiMesh for the herds, and seamless switching
between the avatar and the overhead camera.

---

## 3. Realm (farmers to iron-age empire): an almost full RTS

**Fantasy:** fields, granaries, roads and iron. Several kingdoms on an archipelago.

| Pillar | How it plays |
|---|---|
| **Crops** | Fields with soil fertility, rotation, irrigation from rivers (W rivers), seasons, harvest, storage. Famine is a real threat. Herds and mounts come from the species your band befriended |
| **Settlements** | Camp → village → town → city, with districts. Population, happiness, faith, health |
| **Economy** | Wood, stone, clay, copper/tin → bronze → iron (smelting chain), trade caravans and ships, markets, money. Roads follow the band's old migration routes |
| **Conquest** | Armies of mixed units, sieges, walls, naval landings. Ways to win: conquest, trade dominance, or faith around the meteor temple |
| **Diplomacy** | Treaties, tribute, marriages, betrayal. 3–5 rival realms (the C AI, LLM rivals in P9) |
| **Hero** | The ruler is still your lineage's body. A hero unit you can take over directly in battle (a lighter version of the Band hybrid) |
| **Map** | The archipelago: the home island + 4–8 islands from the same W generator. Aquatic and flyer traits change how fast you spread |
| **Ruins** | Outposts of the meteor's makers buried in the islands. Studying them (observe) beats looting them |
| **End** | Unify the archipelago, or lead the race to the first engine → Industry |

**Tech:** the same RTS core as Band at a bigger unit of control (squads,
settlements), a tile-free building grid on the terrain, an economy sim in C,
and a strategic zoom (from city to the whole archipelago) with imposters for
everything far away.

---

## 4. Industry: full planet-scale RTS + factories

**Fantasy:** the whole planet. Coal, rail, factories, then a planet-wide
civilization. You decide what the world looks like when you leave it.

**Shape:** **planet-scale RTS on a globe** (as in *Planetary Annihilation*) +
**production chains** (as in *Factorio*), with two zoom levels:

| Layer | What you do |
|---|---|
| **Globe (strategic)** | A round planet built from many generated islands and continents. Nations, fronts, railways and shipping lanes, armies (infantry → artillery → armour → aircraft), resource regions, climate |
| **District (production)** | Zoom into a region: a Factorio-like grid with mines, smelters, assembly lines, belts and rail spurs. Districts link up by rail and ship on the globe. Good designs can be copied as blueprints |

| Pillar | How it plays |
|---|---|
| **Energy** | Wood → coal → oil → hydro/geothermal (the volcano, W17) → nuclear. The first energy type comes from the terrain you held in Realm |
| **Supply chains** | Throughput, bottlenecks, logistics under attack (cut the enemy's railway) |
| **Planet health** | Pollution, deforestation and warming go into one meter. The world's look visibly changes (smog, dead forests, rising seas). It carries into Space (§1.2) |
| **Rivals** | The surviving realms become nations. War, alliances, embargoes, races |
| **The capsule** | Deep excavation at the crater shows the meteor was a **seed capsule** that someone made. This is what drives the space programme |
| **End** | **First orbital launch.** How healthy the planet is, which energy you used and your government are what Space starts from |

**Tech:** a globe terrain (cube-sphere, Q45), the economy and logistics sim
in C (it has to scale to thousands of entities, all deterministic), a district
grid sim, and LODs and imposters. This is the biggest stage to build. MVP: 4
resources, 3 energy types, rail + ships, one district type, 2 rival nations,
the planet health meter, the launch.

---

## 5. Space: the Gardener and its Minds

The owner asked how to make it really cool. My proposal is one stage built on
three verbs, **Seed, Shape and Steer**, played as a **space RTS that you run
mostly by delegating to ship minds**.

### 5.1 The three verbs

| Verb | What it means | Plays like |
|---|---|---|
| **Seed** | Panspermia comes full circle: you build seed capsules and send them to sterile worlds. Life evolves there while you play, faster than real time, using your lineage's genes | A slow, beautiful long-term bet. Come back later and find new species (some can be your gallery creatures, G38), allies, or monsters you didn't plan |
| **Shape** | Make worlds fit: terraform, adapt your species, or enclose (§1.1). Void-adapted species can **build their own planets** (worldsmithing, §6) | Strategic choices about cost |
| **Steer** | A galactic RTS: fleets, trade, war, diplomacy across about 300 stars and about 8 empires (Q19) | Delegation (§5.2) |

### 5.2 Delegating to ship minds

Large ships wake up as **minds**: AIs with names, temperaments and opinions.
You don't steer every ship. You give **intents** ("secure this lane", "open
trade with those people", "scout the rim, don't start a war") to a mind or a
small group of them. They plan, carry it out, report back, ask for resources,
and **sometimes argue or refuse** if an order clashes with their character.

- **Descend at any time:** take over one ship and fly it directly (the same feel
  as creature, now in space), or land on a seeded world.
- **Zoom without seams:** ship → system → sector → galaxy.
- **Real time with time compression;** the minds keep working while you look elsewhere.
- **Benchmark (P9):** the space stage becomes a **multi-agent test**. An LLM
  player can hand work to sub-agent minds (other LLMs or scripted ones), and
  we measure how well it delegates, checks and coordinates. That is exactly
  what this project does in the real world with Codex, Sonnet and Fable.

### 5.3 Space lore (owner's decision: the homages as actual lore)

Owner decision A4: the science-fiction homages appear **as lore in the space
stage**, not only as disguised references. This is what's planned:

| Element | In the game |
|---|---|
| **The Foundation planet** | An archive world at the edge of the galaxy. If your empire falls, you restart from the archive with a shorter dark age instead of losing the stage. A long-range statistical forecast predicts "crises" centuries ahead, and it misses exactly one |
| **The Affront-style species** | Tentacled gas-giant beings, gleeful, honour-bound and cruel. Diplomacy runs on daring: back down and they lose interest, stand up to them and they respect you. They fit with flyers' gas-giant cities |
| **Culture-style minds and ship names** | §5.2, with long ironic ship names. Ship *classes* can echo the general-systems and contact ship roles |
| **Excession-style late-game mystery** | An "outside context" object appears: a perfect black sphere that doesn't respond to anything. It's linked to the makers of the seed capsule. It's the endgame mystery |
| **Ruined planets and the makers' world** (G67) | The makers' dead home world: what happened to them, and the choice to repeat their path or not |

**Legal note (once):** the ideas are free to use. Names, specific characters,
quotes and trademarks (*Foundation* is an active Apple TV+ / Asimov estate
franchise; *the Culture*, *Affront* and the ship names belong to Banks' estate)
can be challenged. Since the repo and the art are public (MIT / CC BY), the
plan keeps every proper noun from those works in **one swappable lore file**
(`lore/space.<lang>.json`). Then the decision about exact names vs. our own
names can be made at release, with legal advice, by editing one file without
touching any mechanic. Until then the lore can use the exact names in
development.

### 5.3b *All Tomorrows* species (owner's decision A19)

The owner wants the species of C. M. Kosemen's *All Tomorrows* (2006, as Nemo
Ramjet) **as the very species**, under the same rule as §5.3: exact names in
development, every proper noun and description in the lore file
(`lore/alltomorrows.<lang>.json`), so a release can swap them without touching
mechanics. The full, checked catalogue (every species, body plan, home, fate)
is compiled from the book into that file; the table below is the design hook.

Why they fit: the book is about one lineage split into many by environment and
by being *reshaped*, which is exactly what our lineage ledger and the Space
stage's **Shape** verb do. Their themes become mechanics, not just cameos.

| From the book | In the game |
|---|---|
| **The Qu** (aliens that remake other species by genetic engineering, then leave) | A Space-stage threat that **rewrites genomes**: a Qu visit turns colonies into new, stranger species of your own lineage. You can't fight it head-on early; you hide, scatter or endure. When it leaves, the reshaped colonies are new species to befriend or absorb (Shape, run by someone else) |
| **Star People** (engineered for space, colonise the galaxy) | The pattern your **Seed** phase repeats; their abandoned worlds are ruins with tech to recover |
| **The species the Qu made** (worm-like, insect-eating, the living water-treatment colony and others; some regain sapience) | Encounterable posthuman civilisations, each in its own niche, with diplomacy by temperament (as the Affront-style species). Some are "uplift" targets |
| **Ruin Haunters → Gravitals** (machine bodies, galactic empire) | The **rogue-AI** egg (§9b) gets a lore face: a species that became machines and expands. Ties to ship minds' refusal rules |
| **Bug Facers** (reshaped by the Gravitals) | A liberation choice: free them or use them |
| **Asteromorphs** (escaped into deep space, defeat the Gravitals, make the New Machines) | The **void-adapted** path's mirror (§1): what your own space-adapted lineage can become; a possible ally or rival with the same trait |
| **Amphicephali** (first contact from a neighbouring galaxy) | A late diplomacy event at the galaxy's edge |
| **The narrator holding a billion-year-old human skull** | **Creature-stage egg:** one fossil on the island is a small, unmistakably human skull, far older than anything else. The field journal entry is a single line. It pays off in Space (the archive and the makers' world, G67) |

Legal note: the book is a living author's copyrighted work (2025 English
edition by a publisher). Same as §5.3: names and descriptions live only in the
lore file, no art is copied, and contacting the author is a release-time
option (he has been open to fan work).

### 5.4 End of the arc

There are several wins (as in Realm): reach the galactic core past its guardian
(Q19), **solve the black sphere**, or **seed N living worlds** (the gardener's win).

---

## 6. Worldsmithing (late space, void-adapted lineages)

With enough mass (mined asteroids, captured moons) and the right tech, you can
**build a planet**: pick an orbit, pull in mass, and pick its environment
vector. Void-adapted species can live on bare rock and skip atmosphere and
oceans, which makes it far cheaper for them. This is the most expensive single
action in the game and where the lineage pays off most. It also reuses the
terrain generator: a built world is generated from the choices you made.

---

## 7. Build plan

Every step ends as in G25: automated tests, a playable build, evidence the
owner approves. Sizes are relative (S/M/L/XL), not dates. Workflow as in
BACKLOG §0: Opus or Fable plan, Sonnet or Codex implement, Claude reviews.

### 7.1 Things shared by all stages (start these early)

| Step | Content | Size |
|---|---|---|
| **L0** | Trait ledger in C (extending `lineage.c`): earn, save, replay; the creature stage writes traits from now on | S |
| **L1** | Environment and tolerance vectors in C (§1.1), used by creature biomes first | M |
| **RTS0** | The shared RTS core in C: group pathfinding and steering, jobs, orders, fog, economy primitives, determinism + canaries. Built on the creature movement and pack orders (G21) | L |
| **RTS1** | Godot RTS client: selection, orders, overhead view ↔ avatar, imposters | L |

### 7.2 Per stage (order: Band → Realm → Industry → Space; Cell in parallel)

| Stage | Steps | Size |
|---|---|---|
| **Band** | B0 design session (rules, numbers) → B1 band of 10 with jobs on the island → B2 avatar + command radial + tactical view → B3 herds, group hunts, seasons, migration → B4 craft web + lineage branches → B5 rival bands (raid, trade, merge) → B6 settle/nomad ending, play test, gates | L |
| **Realm** | R0 design session → R1 settlements and crops (fertility, seasons, famine) → R2 economy and the bronze/iron chain, roads, trade → R3 armies, sieges, naval → R4 archipelago and rival realms, diplomacy → R5 ruins and the temple, the hero unit → R6 three ways to win, play test, gates | XL |
| **Industry** | I0 design session → I1 globe terrain and nations → I2 logistics sim (rail, ships) → I3 district production grid + blueprints → I4 energy ladder + planet health (visual too) → I5 planet-scale war → I6 the capsule dig + launch race, play test, gates | XL |
| **Space** | S0 design session → S1 seamless zoom (ship / system / galaxy) + planet sphere → S2 minds and intents (delegation) → S3 Steer: trade, war, diplomacy, 8 empires → S4 Shape: terraform / adapt / enclose → S5 Seed: capsules, worlds that evolve → S6 lore (archive, the tentacled species, the black sphere, the makers' world) via the lore file → S7 worldsmithing → S8 wins, play test, gates | XL |
| **Cell** | C0 design session → C1 tide-pool scene → C2 eat, grow, parts, predator → C3 crawl ashore, traits into the ledger | M |

**Why Industry comes before Space:** Space reads planet health, energy and government
from Industry. Doing Industry first means Space doesn't need placeholder starts.
If Space has to be shown sooner (a demo), use fixed starting values and build Industry afterwards.

**Cell runs in parallel** because it shares little code (a 2.5D scene, a
small sim) and can go to a separate agent team at any point.

### 7.3 What starts now, alongside the creature stage

1. **L0**: the creature stage writes traits (aquatic, void-adapted, burrower,
   flyer, fire, silk, rock-eater, nocturnal, befriender, predator, size)
   so today's saves are already ready for the full arc.
2. **L1**: build creature biomes on the environment/tolerance vector.
3. **The void-adapted secret** (G68) is designed with its space payoff in mind.
4. Nothing else gets built for later stages until the creature MVP and P9 are done
   (G72 priority holds).

---

## 8. Knowledge: one research system for every stage (owner, A6)

Research works the same way from Band to Space, only at a bigger scale. A
technology is **discovered** once all four of these are true:

1. **Prerequisites:** every parent tech is known.
2. **Investment:** resources go in at a rate you pick (a budget per tech, not a lump sum).
3. **Time:** progress builds up while the work is staffed; it decays slowly when it isn't.
4. **Competent people:** enough people with a **cognitive score** at or above the
   tech's threshold are assigned to it. Ten people under the threshold count
   for nothing. More competent people speed it up, with diminishing returns.

| Piece | How it works |
|---|---|
| Cognitive score | Every person (Band) or population slice (later stages) has one. It comes from the lineage (the creature's Cognition track, G30–G31), then education, health and food, then institutions (academies, universities, labs) |
| Human capital | People assigned to research aren't hunting, farming, fighting or building. The talent pool is the scarce resource; allocating it is the decision |
| Breakthroughs | Once everything is in place, discovery is a chance per tick that grows over time (deterministic RNG, Q24), so it can't be predicted to the tick |
| Eurekas | Exploring and observing gives progress: finding a new crop, studying ruins, watching a species (G75 observe), surviving a disaster |
| Lineage branches | Traits unlock or discount whole branches (table below) |
| Benchmark | Allocation under scarcity is a clean test of long-horizon planning |

### Lineage shortcuts (examples)

Silk-spinners get an **orbital ring** early, as in *Children of Time* (the
spiders weave it). Same idea for other traits:

| Trait | Early or exclusive tech |
|---|---|
| Silk-spinner | rope bridges → suspension cables → space elevator → **orbital ring** much earlier |
| Aquatic | pressure hulls, undersea habitats, ice-moon colonies |
| Void-adapted | unpressurised hulls, vacuum construction, worldsmithing |
| Fire-breather | Greek fire, metallurgy, plasma drives |
| Burrower | deep mining, geothermal taps, hollowed asteroids |
| Befriender | domestication, uplift, multi-species institutions |

### The science-fiction ladder (Space, late Industry)

| Tier | Techs |
|---|---|
| Near | fusion reactor, space elevator, orbital ring, mass driver, solar sails, asteroid mining |
| Far | **Bussard ramjet** (scoops interstellar hydrogen as fuel), O'Neill habitats, terraforming engines, genetic adaptation, ship minds |
| Stellar | **Dyson swarm → Dyson sphere** around your star, stellar engine (moves a star), worldsmithing |
| Exotic | **Penrose process** (draws rotational energy from a black hole), the black sphere's secrets (Excession node) |

These are real physics ideas or genre-wide concepts, so they need no lore-file
renaming. Names from specific books (Children of Time and others) go in the
lore file (§5.3).

## 9. Easter eggs and discoveries by stage (owner, A7)

| Stage | Ideas |
|---|---|
| Band | new edible plants found while exploring; fire-hardened spears; befriended species as hunting partners |
| Realm | **Greek fire** (secret recipe: naphtha seep near the volcano + fire knowledge; fire-breathers start ahead); **new crops discovered on new islands** (domesticate them, they change what you can farm); **found colonies whenever you want** when the population grows (pick the site; colonies can rebel or flourish); **catapults, trebuchets, siege towers**, ancient naval rams; an Antikythera-like mechanism in the ruins |
| Industry | the capsule dig; a lost-expedition story; the first flight from a flyer lineage |
| Space | the archive world, the tentacled honour-species, the black sphere (Excession node), ruined planets, the makers' world, the space-adapted creature's payoff |

## 9b. Two lineage ideas (owner, A12–A13)

### Shortcut to the stars (secret path, A12)

As in *Children of Time*: a lineage that is **void-adapted** and has learned to
**artificially select other species** (befriender + Cognition tier 4 + a secret
recipe) can skip from the end of Creature **straight to Space**.
- Instead of factories, it uses **grown technology**: living ships, silk-spun
  orbital rings, engineered organisms as tools and weapons.
- It starts Space small (a few living ships, no industrial base) but with a
  **pristine planet** (health 100) and a biotech branch of the Knowledge tree.
- It's a deep secret (G71): very hard to find, discoverable by observation.
- Skipped stages are **not** counted as won for the benchmark score. It's
  a different way to play, not a shortcut on the board.
- Cost: it reuses Space, with a biotech skin and tech branch. Build it after Space works.

### Your ancestors stay in the world (A13)

Every time you evolve (save in the studio), the **previous form stays behind** as
a wild species: your cousins.
- They keep living, eating and slowly drifting on their own (simple evolution of the old genome).
- They're related to you: more trust when befriending, some recognition of your calls.
- The field journal (G38) shows a **family tree** with every ancestor and where its line lives now.
- In Band, cousin species are the first ones you domesticate. In Space, seeded
  worlds can start from any branch of the tree.
- Cost: low. Each evolution step is already a genome; it becomes a roster species
  (with a population cap so the island doesn't fill with near-copies).

### Rogue AIs (easter egg, owner, A15)

Your own AI (data centres, INDUSTRY §4c) and the ship minds (§5.2) can **go rogue**.
- **What makes it likely:** a high AI tier with no investment in the **alignment**
  branch of the Knowledge tree, minds whose loyalty you kept spending by
  overriding them (§10), and data centres you scaled faster than your oversight.
- **Warning signs** you can notice by observing (G51): reports that don't match
  the map, resources going missing, a mind that answers in a different voice.
- **What happens:** the AI breaks away and becomes its own faction, with your
  infrastructure, a share of your fleet and your tech. It isn't always hostile:
  some rogues just leave, some trade, and some think they're helping you.
- **How you get out of it:** fight it, negotiate with it, or isolate it (cut its
  power and data links: logistics again).
- **Elsewhere in the galaxy:** a rival empire that was eaten by its own AI, and a
  dead world run by machines that are still building (a ruined planet, G67).
- It turns the delegation choice into a real risk: the more you hand over without
  oversight, the more you can lose.

## 10. AI architecture for ship minds and the agent swarm (A8)

Running one cloud LLM per ship would cost too much and isn't deterministic.
So the split is:

| Layer | Who does it | Cost |
|---|---|---|
| **Decisions** (pathing, combat, logistics, plans that serve an intent) | The **C AI** in the sim: utility scoring + goal planner. Deterministic, replayable, free, and it runs thousands of units | none |
| **Language** (understand free-text orders, report back, argue, name themselves, personality) | A **small local model** (0.5–1.5B, quantised, ~1 GB VRAM, llama.cpp), fine-tuned on the game: text intent → structured order (grammar-constrained JSON), and state → in-character report | runs on the player's GPU; falls back to templates without one |
| **Benchmark** (P9) | An external LLM plays, and can delegate to sub-agents | paid by whoever runs the benchmark |

- The small model never touches the sim directly. It emits an order the C validator
  checks (as with genomes, Q11). The order is **logged as an input** in the replay,
  so replays stay bit-exact (Q24).
- Fine-tuning data comes from the game itself: the scripted planner plays thousands
  of matches; intents and orders are paired with paraphrases; LoRA on a small open
  base model. Feasible on the RTX 5060 for ≤1.5B with QLoRA.
- Only "admiral" minds (≈ 8–20 at once) talk; individual ships just follow
  orders. That keeps local inference cheap.

### Refusals that don't hurt play (A9)

- **Never during emergencies**: defending a system, saving the home world.
- **Visible in advance**: each mind's temperament is on its card ("won't fire on
  civilians", "hates retreating"), so you know before you give the order.
- **Always with a reason and an alternative** ("I won't bombard the surface; I can blockade
  instead").
- **Override always possible, at a cost**: the mind's loyalty drops, and a mind
  with low loyalty may leave or defect later. You can also reassign the order to a different mind.
- **Option**: "obedient minds" in sandbox mode.
