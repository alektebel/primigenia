# Creature stage: roadmap to done

Status: **plan of record, 2026-11-17.** The owner's rule (A17): **finish one stage
completely, and build the others on top of it.** This roadmap takes the creature
stage from where it is today to finished: every system, every secret, polished and
released. It replaces the ordering in `BACKLOG.md` §1–2 for the creature stage;
BACKLOG keeps the per-item state.

Each phase ends as in G25: automated tests, a playable build, evidence, and
**an owner play session that closes the phase** (the "gate"). Sizes are relative.
At the speed the agents have been working, S ≈ days, M ≈ 1–2 weeks,
L ≈ 2–4 weeks; usage limits are the real clock.

---

## Where we are (2026-11-18)

| Area | State |
|---|---|
| Engine | Godot 4.7 desktop + C core over GDExtension (G76). One playable game: `make godot && godot --path godot` |
| World | Fable v2 island (3.6 km) + cliffs + caves; **the C world uses the island heights** (FIELD mode, `docs/godot/NAV.md`) |
| Creature | Studio port, 46 parts, IK rig, locomotion from morphology (G73), feel pass F1 merged (2f5cf70) |
| Combat | C tactical combat on a tick, Garfio beatable by all three seeds (42/58/76 %) |
| Lineage | C2 L0 ledger, saved deed counters, evolution console trigger, cousin bodies, family tree (T / pause), and 16 draft behavioural types implemented on `c2/lineage-cousins`; review pending. Social awards/trust/perk consumers need merge wiring. See LINEAGE.md and CREATURE-TYPES.md. |
| UI | HUD, G75 card and radial: attack, **befriend, observe, intimidate and eat work** (C2 social slices, branch `c2/social-loop`, pending review); select first, then choose; DNA/species/food meters, beat ring, trust and DNA popups; audio |
| In flight | Nothing. Studio parity (`9b1abb7`, gaps in STUDIO-PARITY.md), rock material F2 (`ea0e31e`/`3eb3ece`, through step 10) and action animations F3 (`0e35914`, `b232e19`, `aaa35f2`) are merged; the only open F-item is owner approval of the baked sun shadows (off by default) |
| In review | **C2 social loop** (`c2/social-loop`): befriend skills, gifts, trust and bonds, observe chains that teach moves, intimidate, eat, ally/dominate per species, DNA meters, agent face and Godot UI. Deferred inside it: egg counter and hatchling respawn, raids, body-part skill requirements (see P4.md) |
| In review | **C2 secrets** (`c2/secrets-roster`, `docs/SECRETS-REPORT.md`): 5 meteor shards along one bent ray (certified on foot), the hidden cave as a real walkable chamber with a fossil, day and night (500 ticks an hour, the game starts at 08:00), the nocturnal Acechalunas (asleep and hidden by day, +50% trust in the dark) and a sixth species, Babosa (hunkers at noon). Roster is now 6 species |
| Missing | parts discovery polish, tiers, recipes, journal; water, air, digging, the deep secrets |

---

## The phases

### C0 · Iteration tools and loose ends (M)

Make the owner's play loop fast before anything else (DEVTOOLS.md).
- **DT0:** key legend (D13), console, site picker + bookmarks, scenarios, live tuning + A/B, feedback key, time control.
- **F4:** the C world uses the generated island heights (the sim and the visuals agree everywhere).
- Finish **F2** rock material and **studio parity** (the creator feels like the original).
- **Saves:** save and load a game (needed from C2 on).

**Gate:** the owner jumps to any site, tunes speed live, swaps A/B, files feedback with F8.

### C1 · The core loop feels great: the MVP (M)

G70 second-to-second loop, G72 priority.
- **F3 action animations** (G77): bite, charge, spit, tail, all timed with the C phases.
- **Fight readability:** wind-up tells, hit feedback (stagger, sound, camera), dodges, enemy intent.
- Camera and movement final tuning with the C0 tools.
- Island props on the real C terrain (trees, rocks, grass), a curated seed.
- Minimal audio pass (footsteps, hits, ambience).

**Gate (MVP, BACKLOG item 10):** the owner plays 10 minutes and enjoys moving and fighting.

### C2 · Choices with consequences: P4 (L)

G70 minute-to-minute loop. Spec: `P4.md`.
- **Befriend** for real: sing, dance, charm, pose, gifts by diet, rhythm and combos, trust and bonds, defending a species.
- **Observe** (learning behaviour, recipe clues) and **Intimidate** (driving off without killing).
- **DNA**: total only rises, balance is spent; rewards for befriending, kills, carcasses, exploration.
- **Parts**: discovery (drops, carcasses, fossils), tiers by DNA + usage (G49), **editing at the nest**.
- **Moves and loadout** (A21, COMBAT-MOVES.md): 4 slots + guard/dodge, cooldowns, the C2 moves (claw swipe, peck, pounce, quill volley, roar with fear, stomp, curl up, bone-spine frenzy), learning by Observe.
- **Species roster** (ECOLOGY.md): 6–8 species with temperaments, diets, home ranges; ally/dominate per species (Q43); progress = species resolved.
- **Ancestors become cousins** (A13): each evolution leaves the old form in the world.
- **Lineage ledger L0** (ARC-PLAN §7.1): traits are recorded from now on.
- First secrets: **bone spines** (deep), **rock armour** (deep), **5 meteor shards**, **nocturnal creature**, 3 fossils, 1 hidden cave (G68).
- Minimal **field journal** (species, parts, shards).

**Gate:** a 45-minute session from hatching to a creature visibly changed by your choices, with at least one secret found unaided.

### C3 · Stakes: nest, eggs and pack, P5 (L)

- Nest site choice (G24), eggs and hatching, food runs, the **egg cost of dying** (G23).
- **Pack** with roles (forager, guard, nurse, digger) and the **Cognition track** tiers 1–3 (G30–G31).
- **Raids** in both directions, territory defence, defences (thorn walls, hidden entrances, alarm calls).
- Secret: **webs / silk sac** (G69) as a nest defence and climbing lines.

**Gate:** the owner defends a raid on their nest and leads a raid of their own.

### C4 · New media: water and air, P6 (L)

- **Swimming** (shallow then deep water, underwater food, sunken caves), the underwater art (G64).
- **Gliding** with dive attacks.
- Secret: **ink jet** (aquatic deep secret); sunken bones and cliff fossils found only through the new media.
- Trait **aquatic** and **flyer** recorded in the ledger.

**Gate:** the owner reaches a secret that's only reachable by water and one only by air.

### C5 · The deep game: P8 (L)

- **Digging**: chambers and tunnels, roots and water nodes, buried fossils (G27).
- **Full flight**, **territory**, the **epic creature** (Coloso) and **befriending giants** (owner egg).
- **Size growth** costs DNA, with its trade-offs (G78).
- **Volcano biome and fire**: **flamethrower** (fire breath, G52), lava, burning grass.
- Secrets: **thrown claws**, **evolved bombs** (owner egg), **void-adapted creature** (space-adapted, G68; pays off in space and in the secret shortcut A12).
- **Cognition tier 4** (tactical map); weather, day/night tuned, seasons with migration (W8).
- The full island: five biomes, islets, landmarks, **the meteor crater** and its story ending.

**Gate:** all 8 deep secrets exist (bone spines, rock armour, webs, ink, flamethrower, thrown claws, bombs, void-adapted). The owner finds 3 of them unaided.

### C6 · Content and polish (L)

- **Discovery density** (G71): something new every 10–15 minutes over a full play-through; rare creatures (albino), viewpoints, more fossils and caves, more species.
- **Field journal complete** (family tree, completion), **sandbox mode**, **photo mode**, creature sharing by file (G38, G61).
- **Onboarding**: the first 10 minutes teach movement, the radial, befriend, DNA and the nest without text walls.
- **Audio**: procedural creature voices (Q40), music, mix.
- Settings, accessibility, **es/en**, performance tiers (low-end PC, the RTX 5060), crash-free soak (D12).

**Gate:** a full run from hatching to the end of the stage (target 6–10 hours) with no blockers. **3–5 outside players** try the first hour and get through it.

### C7 · The ending and the bridge (M)

- The stage's **advance** (Q8): Cognition tier 4 + tools at the nest; an ending scene at the crater.
- The ledger exports the lineage (traits, ancestors, genome) in the format Band will read.
- **"The creature stage is complete":** it's playable as a game on its own, with an epilogue that teases the next stage.

**Gate:** the owner plays the ending and approves it.

### C8 · Release (M)

- Desktop exports (Linux, Windows, macOS) from Godot (G76 supersedes the Electron plan of P7).
- **Trademark check** for "Primigenia" (EUIPO, USPTO).
- Store page / itch.io, trailer from photo mode and replays, credits (CC0 audio, the inspirations).
- A public demo: the first hour.

### C9 · Benchmark track (M, can run alongside C6–C8)

- P9: LLM rivals through the same verbs, the board, reference rows (idle, random, scripted, PPO, human), decision caps, replays verified (Q51).

---

## The secret catalogue (creature stage)

| Secret | Kind | Phase |
|---|---|---|
| Bone spines | deep (recipe) | C2 |
| Rock armour | deep | C2 |
| 5 meteor shards → the crater's story | cheap chain | C2 (shards), C5 (crater ending) |
| Nocturnal creature | cheap | C2 |
| 3 fossils, 1 hidden cave | cheap | C2 |
| Cousins (your ancestors) | system | C2 |
| The billion-year-old human skull (*All Tomorrows*, A19) | cheap (one fossil) | C2 |
| The Petrova line in the night sky (*Project Hail Mary*, A20) | cheap (seen with the nocturnal creature) | C5 (with day/night and the nocturnal secret) |
| Webs / silk | deep | C3 |
| Ink jet | deep | C4 |
| Sunken bones, cliff fossils, waterfall cave | cheap | C4 |
| Flamethrower | deep | C5 |
| Thrown claws | deep | C5 |
| Evolved bombs | deep | C5 |
| Void-adapted creature | deep (pays off in space) | C5 |
| Befriending giants, the epic creature | system / climax | C5 |
| Albino and other rare creatures, viewpoints, more fossils | cheap | C6 |

---

## Definition of done for the creature stage

1. A 6–10 hour play-through from hatching to the ending with no blockers.
2. All four radial modes work and matter; ally and dominate both win the stage.
3. Nest, pack, raids, water, air and digging all play.
4. 8 deep secrets and enough cheap ones to hit the G71 rhythm.
5. Saves, journal, sandbox, photo mode, onboarding, es/en, settings.
6. Runs well on a mid-range PC; replays verify bit-exact.
7. The owner and 3–5 outside players want to keep playing.
8. The lineage exports cleanly for Band.
