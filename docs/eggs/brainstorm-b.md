# Easter egg brainstorm for Primigenia (creature stage)

Inspired by DESIGN.md §9 G49–G54 (tiers, recipes, secrets), G65 (secrets are easter eggs), G23/G37 (DNA, parts), W1–W15 (island, biomes, caves), P4.md (recipes, bone spines), COMBAT.md (moves, counter matrix). All ideas are original — no copying of Spore or other games beyond genre conventions.

Format per egg: recipe (parts + diet + meter), discovery (clue, location, wild species), in-world effect, combat effect & counter, cost, later-stage payoff, short fun description.

---

## Part A — Owner ideas, developed

### 1. Flamethrower (fire breath)

**Recipe (`fire_breath`)**
| Field | Value |
|---|---|
| Parts | spit sac (`CP4_MOUTH_O`, level >= 2) **and** volanic vent (`CP4_DETAILS_SAC`, level >= 1) |
| Diet condition | omnivore or carnivore (body has `CP4_MOUTH_O` or `CP4_MOUTH_C`) |
| Meter | `fuel`, 0–100, starts 0, no decay |
| Refill | eating resin plant fragments from the volcano biome (8 fuel each, 5 units max per carcass/node); volcanic soil near fumaroles (1 fuel per visit, once per day) |
| Spend | 25 fuel per breath |
| Move | `fire_breath` (see table below) |
| Unlock | recipe state `known` (>= 2 clues) |

**Combat move** (level 1, table row):

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| fire_breath | 8 | 6 | 8 | 5.5 | 0.80 | 15 | 8 | burn (5/tick, max 6 ticks = 48) | cone, meter `fuel`, requires `CP4_MOUTH_O` + `CP4_DETAILS_SAC` |

Counter rows added to counter matrix:

| Incoming | Defender | Result |
|---|---|---|
| fire_breath | guard / active | Block normally; fire continues past block, deals half damage to anyone behind (splash). No riposte stagger. |
| charge | fire_breath / wind-up | Interrupt charge; flame damages charge attacker for 15 HP on contact (panic reaction). |
| any attack | dodge / active | Standard dodge. Fire does not auto-track dodging. |
| fire_breath | bite / gap <= 1.5 m | Charge through flame, deal 150 % bite damage (ignites attacker's mouth). |

Burn: 8 initial + 5/tick for 6 ticks = 38 max. A second burn refreshes the timer (stacks at 2 max).

**Discovery**:
1. **Wild specimen**: A juvenile `Volcantis` (unique wild species in the volcano biome) fires fire breath at a Garfio raiding party. The player witnesses it from a cliff at 30 m.
2. **Fossil clue**: Inspect a `carbonised_carcass` fossil node in the volcano biome. The inspection reveals: "The creature's throat bore a bulbous sac. Fossilised plant matter in its gut — volcanic resin, highly flammable."
3. **Volcanic observation**: The volcano biome's grass burns in strips. A dead herbivore nearby has a charred corpse. Inspect it to learn: "The grass still smoulders. Something burned it from the inside."

**In-world effect**: Fire burns grass patches on contact, creating a deterministically simulated fire spread (G52). Creatures in flames flee or take damage. Cooked meat from carcasses in fire restores 2× food value (new in P5 food store). Fire scares most species (except fire-adapted ones).

**Cost**: Fuel part (sac) = 40 DNA base. Mouth O tier 2 (acid → corrosive) = 150 DNA. Fuel meter cap at 100 means 4 breaths per full refill — real resource management.

**Later-stage payoff**: In the civ stage, fire breeding lets you cook, smelt basic metals, and forge weapons. In space, the same sac+resin combo becomes a thruster (propulsion).

**Fun description**: "Your creature opens its maw and the world turns orange. Animals scatter. The grass remembers."

---

### 2. Astrofauna — creature adapted to the void

**Recipe (`void_resist`)**
| Field | Value |
|---|---|
| Parts | radiation shield (`CP4_DETAILS_PLATE`, level >= 3, tier 2 `ridged`) **and** vacuum bladder (`CP4_DETAILS_SAC`, level >= 2) **and** thermal fur detail (`CP4_DETAILS_FRILL`, level >= 2) |
| Diet condition | any (no diet restriction) |
| Meter | `energy_shield`, 0–100, drains 5 per tick when exposed, refills in sunlight (30 tick/day near a landmark that faces the sky — summit, spire) |
| Spend | The "move" is passive: grants survival outside the atmosphere and resistance to radiation. No active fire cost. |
| Unlock | recipe state `known` (>= 3 clues) |

**In-world effect**: A creature that has all three parts equipped can leave the island (hypothetically — the stage is bounded, but the trait is flagged). In the space stage, this creature type starts with +20% survival on airless planets and +1 radiation resistance. The `energy_shield` meter also provides passive damage reduction (10 %) against radiation-like damage in the civ stage's asteroid zone.

**Combat effect**: Not a combat move per se. The ridged plate tier gives guard factor +0.15 (already in G49 tier table). The vacuum bladder adds a cosmetic "glow" in dark caves. Thermal frill adds +1 HP on cold-nights (nocturnal raids are harder in alpine).

**Discovery**:
1. **Meteor shard**: A panspermia meteor shard (W10, G67) found in the crater biome, when inspected, reveals: "This stone hums. Embedded in it — microscopic organic structures. Life from another world. Adaptations that defy this planet."
2. **Panspermia fossil**: A fossil with an unusual body plan: a shell-plate creature with a floating bladder and thick fur, found in the deepest crater layer. Inspection text: "Born in the void, it walked the crater floor before the air thickened."
3. **Wild specimen**: An albino creature of a known species, but with an unusual iridescent sheen on its plates. It is inactive during the day, only moves at night. It ignores most threats. Befriend it to learn: "Its hide drinks starlight."

**In-world effect**: The creature's eyes glow faintly in the dark (cosmetic). On clear nights, creatures with the thermal frill recover stamina 20 % faster (cosmic radiation → metabolic boost — handwaved biology).

**Cost**: Three parts, all late-game tiers. Plate tier 2 = 150 DNA, sac level 2 = ~80 DNA (base 40 × 2), frill level 2 = ~60 DNA. Total ~290 DNA. Very rare.

**Later-stage payoff**: Space stage — this is the **key** creature type for airless planet exploration. Without it, you cannot survive on meteor-crater worlds. With it, you can harvest panspermia shards from other planets, telling the panspermia story across the galaxy.

**Fun description**: "You didn't evolve for this world. You evolved for the space between worlds. The stars recognise you."

---

### 3. Grenadier — evolved bombs

**Recipe (`detonation`)**
| Field | Value |
|---|---|
| Parts | chemical sac (`CP4_DETAILS_SAC`, level >= 3) **and** ignition horn (`CP4_HORN`, level >= 2, tier 1 `reinforced`) |
| Diet condition | carnivore (body has `CP4_MOUTH_C`) |
| Meter | `blast_chemical`, 0–100, starts 0 |
| Refill | eating toxic carcasses (from the savanna/death-zone biome where animals die from ingesting poisonous plants) — each carcass gives 30 blast chemical |
| Spend | 50 blast chemical per detonation (self-destructs the creature, deals damage in a cone) |
| Move | `detonation` — an active move: creature accelerates toward target, explodes at 3 m on contact, deals 40 damage + slow (10 ticks) to all in a 2.5 m radius |
| Unlock | recipe state `known` (>= 2 clues) |

**Combat move** (level 1):

| Move | Wind-up | Active | Recovery | Reach m | Arc rad | Stamina | Damage | Status (ticks) | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| detonation | 4 | 3 | 0 | 4.0 | 1.20 | 20 | 40 | slow (10) | suicide move, meter `blast_chemical` 50, self-removes on use |

Counter rows:

| Incoming | Defender | Result |
|---|---|---|
| detonation | guard / active | Guard absorbs the blast: 40 % damage taken (16 HP), no slow. Detonator is still removed (the explosion happened). |
| spit / charge | detonation / wind-up | Detonator interrupts and explodes prematurely at current position (2 m radius). No chemical cost (emergency release). |
| bite | detonation / active | If gap <= 1 m, the biter can eat the detonator mid-explosion, taking half damage but gaining 5 food (scavenger bonus). |

**Discovery**:
1. **Wild specimen**: A `Bombillo` (unique wild species in the savanna) is cornered by a Garfio. It rushes the Garfio, explodes, and kills itself and the Garfio. If the player is near, a carcass is left (toxic, but inspectable).
2. **Carcass clue**: The toxic carcass from the detonation reads: "The creature's sac ruptured on impact. A pungent gas filled the air. The carcass of its prey is intact — it chose death over retreat."
3. **Fossil**: A `swollen_sac` fossil found near the savanna. Inspection: "This creature carried a volatile sac. Perhaps a last-resort defence."

**In-world effect**: On death by `detonation`, the area burns briefly (same fire simulation as fire breath, but smaller). Other creatures flee the area for 60 ticks.

**Cost**: Sac level 3 = ~120 DNA. Horn tier 1 = 60 DNA. Blast chemical refill is limited (toxic carcasses are rare, 30 per kill). 50 per detonation = at most 1.5 detos per carcass.

**Later-stage payoff**: In the tribe stage, bombiller genes allow your warriors to carry explosive charges (crafted from the gene). In the civ stage, this becomes artillery. In space, it becomes a suicide drone — a controversial but effective strategy against guardian outposts.

**Fun description**: "Sometimes the best move is the last one. Your creature becomes the joke, and the punchline is an explosion."

---

### 4. Titan-tamer — befriending giants

**Recipe (`call_giant`)**
| Field | Value |
|---|---|
| Parts | resonant horn (`CP4_HORN`, level >= 4, tier 2 `ram`) **and** deep voice mouth (`CP4_MOUTH_C`, level >= 3) **and** ear detail (`CP4_DETAILS_FRILL`, level >= 3, placed near head) |
| Diet condition | any |
| Meter | `resonance`, 0–50, refills 5 per tick while singing (costs 3 stamina/tick); costs 10 per giant call |
| Spend | 10 resonance per call (summons a giant from off-screen) |
| Move | `call_giant` — a 15-tick wind-up ritual move. A giant appears at a random edge, charges the nearest hostile creature (or the threat to your allied species), and fights for 60 ticks. The giant cannot be directly controlled. After 60 ticks or the giant's death, it returns off-screen. |
| Unlock | recipe state `known` (>= 2 clues) |

**The Giant** (a unique NPC species, `Titanus`, appears only via `call_giant`):
| Stat | Value |
|---|---|
| HP | 300 |
| Speed | 2.5 m/s |
| Move | `ground_pound` (wind-up 6, active 4, recovery 8, reach 3 m, arc 2.0 rad, damage 50, stun 10 ticks) |
| Temperament | loyal (follows the player's last target, attacks what the player attacks) |

The giant is not a controllable creature. It appears, fights, and leaves. It can be killed (by an epic creature or a swarm). If it dies, you lose resonance permanently (50 → 0) and must rest (300 ticks) before calling again.

**Discovery**:
1. **Landmark clue**: The island's highest summit has a carved stone circle. When the player reaches the summit (requires climbing parts or gliding), a resonant horn fossil lies at the center. Inspection: "Ancient carvings depict small creatures calling to a walking mountain. The mountain answered."
2. **Wild specimen**: A `Titanus` is visible far across the sea on the offshore islet (W4). It cannot be reached without swimming or gliding. From a distance, you can see it fighting off a large predator. The carcass it leaves (inspected from the shore after it leaves) contains: "A resonant horn fossil embedded in its chest. It was singing when it died."
3. **Rondo observation**: The timid Rondo species stops fleeing when the ground shakes. They emit a low call in response. If befriended, a bonded Rondo will sometimes play this call when threatened (trust +5, mood +10). This is an automatic behaviour, not a player action — the first clue is observational.

**In-world effect**: The giant's presence changes the battlefield entirely. Smaller creatures flee from it. It can one-shot most wild species (50 damage > most HP pools). It also scatters carcasses on its ground pound (bonus loot drops).

**Cost**: Horn level 4 = base × 8 = 80 × 8 = 640 DNA (expensive!). Horn tier 2 = 150 DNA. Mouth C level 3 = 40 × 4 = 160 DNA. Frill level 3 = ~90 DNA. Total ~940 DNA — a massive investment. This is a late-game, high-risk, high-reward discovery.

**Later-stage payoff**: In the tribe stage, the giant becomes a shaman-summoned earth spirit. In the civ stage, it becomes siege weaponry. In space, the resonance frequency unlocks communication with giant alien species — diplomatic bonus.

**Fun description**: "You spent hundreds of DNA on a horn that summons a giant. You spent more on a mouth that makes it listen. The giant shows up, one-shots a Garfio, and leaves. Best investment you ever made."

---

### 5. Lithosuit — eating rocks for rock armour

**Recipe (`stone_plate`)**
| Field | Value |
|---|---|
| Parts | grinding mouth (`CP4_MOUTH_G`, level >= 3, tier 2 `corrosive`) **and** mineral shell (`CP4_DETAILS_PLATE`, level >= 2, tier 2 `ridged`) **and** gut lining detail (`CP4_DETAILS_SAC`, level >= 1) |
| Diet condition | herbivore (body has `CP4_MOUTH_G` or `CP4_MOUTH_O`, and **no** `CP4_MOUTH_C`) |
| Meter | `mineral_density`, 0–100, starts 0 |
| Refill | eating stones from rocky biomes (alpine rocks, cliff faces) — 10 mineral density per stone; old carcasses near cliffs give 15 |
| Spend | Passive: the `mineral_density` meter passively improves the mineral shell's guard factor. Every 20 points = +0.05 guard factor (max 4 charges = +0.20 total, capping at the ridged tier's existing +0.15 plus a bonus +0.05 from density). |
| Move | No new move. This is a passive defence enhancement. The shell part gains bonus guard: `guard_factor = base_guard * (1 + mineral_density * 0.0025)`, clamped to 1.35. |
| Unlock | recipe state `known` (>= 2 clues) |

**Discovery**:
1. **Wild specimen**: A `Lapidon` (unique herbivore species in the alpine biome) has an unmistakable rocky, stony appearance. It stands motionless when threatened, acting as a living boulder. When attacked, it blocks strikes effectively. Its slow movement (2 m/s) and high HP (150) make it a walking tank.
2. **Carcass clue**: If the player kills the Lapidon (brutal but informative), its carcass inspection reads: "Its bones contained mineral deposits. The shell was not bone — it was rock, fused to the body by an unknown process. It ate stones."
3. **Fossil**: A `stomach_stones` fossil found in the alpine biome. Inspection: "Gastroliths — stones used for grinding. This creature swallowed rocks whole to crush its food. The rocks stayed with it."

**In-world effect**: Stone-eating creatures in the alpine are common (the Lapidon species). The mineral shell part, once discovered, can be worn by any herbivore. The more stones the player has eaten (tracked via the meter), the harder the shell becomes. A full meter gives guard factor 1.35 — effectively reducing all frontal damage by ~26 %.

The `gut lining` detail is cosmetic (makes the creature's belly appear darker, stone-textured). The grinding mouth level 3 also gives a passive +2 damage to bite moves (from crushing tough alpine flora).

**Cost**: Mouth G level 3 = base × 4 = 32 × 4 = 128 DNA. Plate tier 2 = 150 DNA. Sac level 1 = ~40 DNA. Total ~318 DNA. Stones are free to collect (walk near alpine rocks and press `pick`). The meter fills naturally through exploration.

**Later-stage payoff**: In the tribe stage, stone armour becomes tribal war-plates. In the civ stage, it becomes early siege defence. In space, mineral density translates to radiation-hardened hulls.

**Fun description**: "Your creature sits on a rocky outcrop and eats the mountain. Other creatures stare. When the Garfio charges, the Garfio bounces off. Your creature didn't win the fight. The fight gave up."

---

## Part B — 12 Original Easter Eggs

### 6. Ink Jet (aquatic camouflage)

**Recipe (`ink_jet`)**
| Field | Value |
|---|---|
| Parts | ink sac (`CP4_DETAILS_SAC`, level >= 2) **and** gill detail (`CP4_DETAILS_FRILL`, level >= 2, placed on sides) |
| Diet condition | any (no diet restriction) |
| Meter | `ink`, 0–50, refills in water (10 ink per minute in water) |
| Spend | 20 ink per jet (creates a 4 m dark cloud that lasts 30 ticks, reducing enemy sight range by 60 % within the cloud) |
| Move | `ink_jet` — 3-tick wind-up, 2 active, 5 recovery, range 3 m, damage 0, status: `blind` (3 ticks, target cannot target the ink-user) |

**Discovery**: Found by swimming to underwater caves (P6) and inspecting the carcass of a `Sepiolis` (aquatic species that uses ink). The surface fossil equivalent in P4 would be a bone fragment near the lake shore.

**Combat**: The ultimate evasion tool. Lets you escape any encounter. In a tournament context, it's a pure survival move with no offensive value — low win-rate against smart bots that just wait out the cloud, high utility in exploration.

**Fun description**: "Like a squid with commitment issues."

---

### 7. Echo-location — seeing in total darkness

**Passive trait (no recipe — a part combination that simply works)**

| Field | Value |
|---|---|
| Parts | `CP4_EYE` (any eye) **and** `CP4_DETAILS_PLUME` (display plume) placed facing forward |
| Diet condition | any |

Any creature with an eye and a forward-facing plume automatically gains `echo_location` — a passive ability that reveals all creatures in a 15 m radius regardless of darkness. In dark caves (W5), this is the only way to navigate and fight.

**Discovery**: Find a cave-dwelling species `Noctulisk` that has both. Its eye is white (albino cave variant). The plume is pale and translucent. Inspection: "It has no pigment. The darkness stripped it. But it still... hears shapes."

**In-world**: Cosmetic — the plume pulses faintly when echo-location is active. In dark caves, the plume emits a soft blue glow (cosmetic).

**Fun description**: "It doesn't see in the dark. It hears it. And it hates you for it."

---

### 8. Panspermia Shard — lore collectibles

**5 meteor shards scattered across the island**, each with a unique lore fragment and a small DNA bonus (5 DNA each).

| Shard | Location | Lore text (short) |
|---|---|---|
| 1. `Origin` | The crater (W10 landmark) | "The first stone. Life fell here. It woke up." |
| 2. `Spread` | Alpine summit | "It spread through the wind. It found the mountain." |
| 3. `Water` | Lake bottom (requires swimming, P6) | "It learned to swim. The water held it." |
| 4. `Flight` | Offshore islet cliff (W4) | "It grew wings. The sky called." |
| 5. `Mind` | Deepest cave chamber (W5) | "It thought. And remembered. And waited for the next stone." |

Collecting all 5 triggers a unique codex entry, a visual effect (the island's sky shifts to show stars even during day), and an achievement: "Children of the Sky" (+10 DNA, unique topper on the creature model).

**Fun description**: "Five stones. Five sentences. The story of every creature on this planet — and every creature that will ever be."

---

### 9. Nocturnal — the night hunter

**Recipe (`nocturnal_adapt`)**
| Field | Value |
|---|---|
| Parts | large eye (`CP4_EYE`, level >= 3) **and** thermal snout (`CP4_DETAILS_FRILL`, level >= 1 on the snout) |
| Diet condition | carnivore |
| Meter | none — pure passive |
| Effect | Night vision (sight range × 2 from dusk to dawn) and nocturnal stamina bonus (+20 % stamina regen at night) |

**Discovery**: A nocturnal Espinodo variant, active only at night. It is rarer than daytime Espinodo (spawn rate 1/8). Its eyes glow faintly. If befriended, it teaches the player that night is not safe — but it is yours.

**In-world**: Nocturnal raids (W8) happen at night. A nocturnal-adapted creature is the only one that can effectively fight back. A nocturnal Espinodo bonded by night gives a permanent +5 trust bonus during dark hours.

**Fun description**: "The sun is for cowards. Your creature wakes when the world sleeps."

---

### 10. Mirror Move — copying what you see

**Recipe (`mimicry`)**
| Field | Value |
|---|---|
| Parts | adaptive eye (`CP4_EYE`, level >= 4) **and** plating (`CP4_DETAILS_PLATE`, level >= 2, tier 1 `layered`) |
| Diet condition | any |
| Meter | `pattern_memory`, 0–3, refills 1 per tick (max 3) |
| Spend | 1 pattern to copy a move the player has witnessed an enemy use. The copied move lasts for 30 ticks (3 seconds at 10 Hz). |
| Move | `mimic` — a special verb that opens a submenu of witnessed moves (any move the player's creature has seen an enemy use in combat). Consumes 1 pattern. The copied move is available for 30 ticks. |

**Discovery**:
1. **Wild specimen**: A `Mirrorus` species that visually resembles other creatures in its vicinity (its colours shift subtly based on what's near it). It has never been seen fighting — it only watches.
2. **Fossil clue**: A fossilized creature with an unusually large brain cavity. Inspection: "The skull shows expanded regions for visual processing. This creature didn't just see. It... copied."
3. **Observation**: Watch two creatures fight. After witnessing at least 3 different moves from enemies, the mimicry recipe unlocks (automatic — no fossil needed).

**In-world**: The creature's skin pattern shifts to match its last-mimicked move's aesthetic (cosmetic). If you copied charge, your creature's horns glow slightly. If you copied spit, your mouth sags with a wet look.

**Combat**: Incredibly flexible but temporary. A single pattern = 3 seconds of a random enemy move. In tournament context, it can be used to surprise-counter an informed enemy (copy their best move), but the 3-tick window is tight.

**Fun description**: "Your creature watches the fight, takes notes, and then joins the fight — armed with everyone else's moves. It's like stealing homework and writing it as your own."

---

### 11. Symbiosis — mutualism

**Recipe (`symbiont`)**
| Field | Value |
|---|---|
| Parts | nutrient sac (`CP4_DETAILS_SAC`, level >= 2) **and** cleaning frill (`CP4_DETAILS_FRILL`, level >= 2) |
| Diet condition | any |
| Meter | `symbiosis_points`, 0–50, refills by healing allies (+5 per ally healed within 5 m over 60 ticks) |
| Spend | 20 points to activate `symbiosis_bond`: for 60 ticks, the player's creature and all allied creatures within 20 m gain +10 % damage and +10 % damage resistance |
| Effect | A support/healing passive. The creature can also passively regenerate 2 HP/tick while standing near a bonded species (trust >= 60). |

**Discovery**:
1. **Wild observation**: In the meadow, Rondo and Zanco species sometimes stand near each other. When a predator approaches, both flee together. The Zanco (herbivore with eyes) stands slightly ahead, scanning. The Rondo (herbivore with grasper mouths) stays behind, ready to bite. This is real mutualism in nature.
2. **Carcass**: A `symbiont_nodule` found on a creature carcass. Inspection: "Small organisms lived in its sac. They cleaned parasites. The creature gave them shelter. Both survived longer."
3. **Befriending test**: Befriend two different species and stand them near each other for 100+ ticks. A bond event fires: "The two species seem to... cooperate."

**In-world**: The creature's sac glows faintly when near allies (cosmetic, colour matches nearest ally's species colour).

**Combat**: Support-oriented. In the P4 tournament, a pure symbiosis build has low damage but high survivability through passive healing and ally buffs. Against scripted bots that coordinate, the buff is significant.

**Fun description**: "Your creature makes friends, and its friends make it stronger. The universe rewards social butterflies."

---

### 12. Sonic Boom — concussive shout

**Recipe (`sonic_boom`)**
| Field | Value |
|---|---|
| Parts | resonating mouth (`CP4_MOUTH_C`, level >= 4, tier 2 `serrated`) **and** throat sac (`CP4_DETAILS_SAC`, level >= 3) **and** horn (`CP4_HORN`, level >= 3) |
| Diet condition | carnivore |
| Meter | `vocal_stress`, 0–100, starts 0, decays 5/tick when idle |
| Spend | 40 vocal stress per boom (deals 12 damage to all in 3 m cone, 25 m range, stun 3 ticks). Requires the horn for amplification. |
| Move | `sonic_boom` — 5-tick wind-up, 2 active, 8 recovery, range 25 m (ranged!), arc 1.5 rad, stamina 8, damage 12, status: stun (3 ticks) |

**Discovery**:
1. **Wild specimen**: A massive carnivore in the savanna, `Bassillo`, roars at a distance. The roar is visible as a distortion wave. Nearby prey stumbles. The player's screen shakes briefly.
2. **Fossil**: A `hollow_bone` fossil in the savanna. The bones are thin and hollow — bird-like but in a terrestrial predator. Inspection: "The skeleton is remarkably lightweight. This creature didn't run. It... shouted."
3. **Observation**: The Bassillo's horn is unusually large. If the player approaches it while it's roaring, a clue pops up: "The horn resonated with the roar. It was an instrument, not just a weapon."

**In-world**: The sonic boom is visible as a ripple in the air. Grass bends away from the source. Creatures within range jump (a small vertical bounce animation).

**Combat**: Extreme range (25 m) but short stun (3 ticks) and moderate damage (12). Useful for disrupting enemies at a distance, setting up a follow-up charge, or scattering a group. Counter: dodge (easy — 3 ticks stun is short), guard (takes the hit normally), charge through (ignores the stun if already committed).

**Fun description**: "Your creature opens its mouth and the air itself flinches."

---

### 13. Camouflage — becoming invisible

**Passive trait (part combination)**

| Field | Value |
|---|---|
| Parts | adaptive skin (`CP4_DETAILS_PLATE`, tier 2 `ridged`) **and** pattern sac (`CP4_DETAILS_SAC`, level >= 1) |
| Diet condition | any |
| Effect | When standing still for 20+ ticks, the creature's colours shift to match the ground material (grass = green, rock = grey, sand = tan). Movement breaks camouflage immediately. |

Camouflage gives a 50 % chance for an enemy to fail to target the creature visually (only triggers when the creature is stationary). When combined with nocturnal adaptation, the creature is nearly invisible at night.

**Discovery**:
1. **Wild specimen**: A `Crypton` species found in the forest biome. When it stands still, it becomes nearly indistinguishable from the ground. Move and it snaps to full colour. It only moves when absolutely necessary.
2. **Fossil**: No fossil — camouflage leaves no trace. The clue is purely observational. The first time a player targets a `Crypton` and it disappears mid-targeting (the reticle can't lock on), the recipe unlocks.
3. **Carcass**: If you kill a `Crypton` while it's active (not camouflaged), its carcass reveals: "Its skin held a palette. It could wear the ground. This is not magic. This is biology pushed to its limit."

**In-world**: When camouflaged, the creature model desaturates and shifts hue. A small indicator shows camouflage status (a fading eye icon).

**Combat**: Stealth-oriented. A camouflaged creature in tall grass can approach enemies undetected (sight range reduced to 5 m). In the tournament meta, this is a high-skill, high-reward strategy — one misstep and you're exposed.

**Fun description**: "It doesn't turn invisible. It turns into the floor. And the floor doesn't fight back — until it does."

---

### 14. Magnetic Navigation — compass in the bones

**Passive trait (part combination)**

| Field | Value |
|---|---|
| Parts | magnetised horn (`CP4_HORN`, level >= 2) **and** iron-rich gut (`CP4_DETAILS_SAC`, level >= 1, tier 1 `layered`) |
| Diet condition | herbivore |
| Effect | The creature's HUD shows a faint magnetic compass arrow. More importantly, the creature never gets lost — roam decisions are 30 % more efficient (shorter paths home, faster nest returns). |

**Discovery**:
1. **Landmark**: The panspermia crater has a strong magnetic anomaly. When the player enters the crater and has a horn part, the compass arrow spins and locks onto true north. A clue: "The crater hums. The horn vibrates. North is not a direction here. It is a frequency."
2. **Wild specimen**: `Magnetos` — a herbivore species in the savanna that always faces the same direction when resting (magnetic north). They migrate in perfectly straight lines.
3. **Fossil**: An `iron_nodule` fossil found in the crater. Inspection: "Magnetite deposits. This stone remembers the planet's magnetic field. Creatures that carried it... always knew where home was."

**In-world**: The compass arrow is always visible on the HUD when the trait is equipped. On clear nights, the horn glows faintly blue (cosmetic, references Earth's magnetic field affecting magnetite).

**Combat**: Not directly a combat move. But in the space stage, magnetic navigation lets you navigate without stars — crucial for dark-space exploration. In the civ stage, it becomes a trade-route advantage.

**Fun description**: "Your creature carries a compass in its bones. You could put it down in the middle of a storm, and it would still find home."

---

### 15. Regeneration — the healer

**Recipe (`regen`)**
| Field | Value |
|---|---|
| Parts | stem sac (`CP4_DETAILS_SAC`, level >= 4) **and** bone-marrow detail (`CP4_DETAILS_FRILL`, level >= 3, placed on torso) |
| Diet condition | any |
| Meter | `regen_energy`, 0–100, starts 50 (regenerates 1/tick when idle) |
| Spend | Passive: at 20+ `regen_energy`, heals 2 HP/tick. At 50+, heals 4 HP/tick. At 100, heals 8 HP/tick. |
| Move | `self_mend` — a 10-tick wind-up channel. Consumes 30 `regen_energy` to heal 40 HP instantly (even in combat). |

**Discovery**:
1. **Wild specimen**: A `Sanguis` species with a milky-white body. It has visible injuries but they heal as you watch. If you attack it, the wounds close faster than you can damage it.
2. **Fossil**: A `healing_stone` — actually a calcified sac — found near a nesting area. Inspection: "This creature's sacs produced a regenerative fluid. It could heal in days what would kill another in hours."
3. **Carcass**: If you manage to kill the `Sanguis` (it's very hard), its carcass holds: "The fluid was still active. It heals. Even now, after death."

**In-world**: The creature emits a soft green glow when regen_energy is above 50 (cosmetic). Regenerating creatures leave a faint trail of green particles (cosmetic, like Pokemon's Rest move).

**Combat**: A creature with max regen (level 4 sac + level 3 frill) is extremely tough. 8 HP/tick at 100 energy = 80 HP every 10 ticks. Combined with a guard build, it becomes a walking fortress. The `self_mend` instant heal is clutch in tournaments.

**Fun description**: "You can't kill it. You can try. But it heals faster than you hit. Eventually you just sit down and ask it to let you live."

---

### 16. Paradox Shell — the turtle that fights back

**Recipe (`counter_shell`)**
| Field | Value |
|---|---|
| Parts | turtle shell (`CP4_DETAILS_PLATE`, level >= 4, tier 2 `ridged`) **and** spring arm (`CP4_ARM_GRASPER`, level >= 3) |
| Diet condition | any |
| Meter | none — a counter mechanic |
| Effect | When the creature is struck while in guard, the spring arm fires backward, dealing 8 damage to the attacker (counter-attack). This triggers once per guard cycle. The ridged shell gives +0.15 guard factor (from G49 tier table). |

**Discovery**:
1. **Wild specimen**: A `Testudo` species found near the coast. When attacked, it retreats into its shell. After a moment, a hidden arm lashes out from beneath the shell, striking the attacker. The creature then re-emerges.
2. **Fossil**: A `curled_fossil` — the creature is preserved in a curled position. Inspection: "The shell enclosed the body completely. But the arms... the arms were wired to spring. Defence that bites back."
3. **Observation**: The Testudo is often found near cliffs, where predators cannot easily flip it. Its shell is thick and ridged. The spring mechanism is visible as a slight bulge on the shell's underside.

**In-world**: When the counter fires, a small spring sound plays (cosmetic audio). The attacker is briefly knocked back (1 m) — not a full stun, just a displacement.

**Combat**: A pure counter-shell build has almost zero offensive capability (no attack moves beyond the spring). But against aggressive bots (Garfio-style counter), the counter is devastating. Every charge or bite that hits guard gets punished. The counter only fires once per guard cycle, so it's not infinite — but the spring arm can be placed to fire on every guard.

**Fun description**: "The shell is not a wall. The shell is a trap. And you walked right into it."

---

## Part C — Ranked Shortlist: Top 8 Easter Eggs

| Rank | Easter Egg | Why it's great | MVP island fit? |
|---|---|---|---|
| 1 | **Flamethrower** | Core game-changer: fire modifies the world (G52). It's the most visceral, memorable ability. The fuel meter creates genuine tension. Fire breeds a rich meta (cook food, scare enemies, burn grass for hunting). Deeply tied to the panspermia story (volcano = meteor impact site). | **YES** — volcano is on the MVP island. The three clues (wild Volcantis, fossil, grass-burn observation) are all achievable in the MVP island. |
| 2 | **Panspermia Shards** | The lore backbone of the game. Collecting 5 shards across the island tells the panspermia story (G34) without a single cutscene. Each shard is a one-liner that hits hard. The "Children of the Sky" achievement gives a permanent bonus and a visible topper. Drives exploration across all MVP biomes. | **YES** — all 5 shard locations are on the MVP island (crater, summit, lake, islet, cave). |
| 3 | **Lithosuit** | Simple, satisfying, intuitive. "Eat rocks to get tough" is a concept a 6-year-old understands and a 40-year-old appreciates. The mineral density meter is a slow-burn progression that rewards exploration. The Lapidon species (alpine) is easy to place on the MVP island. | **YES** — alpine biome is on the MVP island (W2). Stones are free to collect. |
| 4 | **Nocturnal** | Ties directly into W8 (day/night, nocturnal predators). Changes the entire feel of night gameplay. The nocturnal Espinodo variant is a cool visual twist on an existing species. The trust bonus for night-befriending adds social depth. | **YES** — day/night is already in the MVP (W8). No new biomes needed. MVP batch includes 1 nocturnal creature (per G65). |
| 5 | **Mirror Move** | The most unique and surprising ability in the entire list. Watching an enemy, copying their move, and using it against them is an unforgettable "aha" moment. It rewards observation (G51's design principle). The 3-tick window makes it strategic, not dominant. | **NO** — requires witnessing 3+ enemy moves, which needs a diverse species roster. MVP only has 4 species. Possible but lower priority. |
| 6 | **Magnetic Navigation** | A quiet but deeply satisfying utility. The compass arrow is a UI delight. The habitat (crater) is a natural fit. The later-stage payoffs (space navigation, trade routes) make it feel like a long-game investment. | **YES** — the crater is the MVP island's landmark (W10). The magnetos can be a 5th species on the MVP island. |
| 7 | **Regeneration** | The most fun to fight against. Nothing beats the frustration of a creature that heals faster than you can damage it. The `self_mend` clutch heal adds dramatic moments. The Sanguis species is a great "epic" candidate (even if not in P4, it can appear later). | **NO** — requires a level 4 sac and level 3 frill (~400+ DNA), which is a very late-game build. The MVP island can host the species, but discovering this recipe requires extensive play. |
| 8 | **Camouflage** | Beautiful concept. The visual desaturation effect would look stunning in BotW style. Stealth gameplay is under-explored in Spore-like games. The "turn into the floor" joke is meme-worthy. | **NO** — requires the forest biome (not on MVP island, W2 says forest comes later). The MVP island only has meadow valley, alpine, and coast. |

---

## Appendix: MVP Island Batch (per G65)

G65 specifies an MVP batch: bone spines, 3 fossils, 1 hidden cave, 5 meteor shards, 1 nocturnal creature.

**MVP-feasible eggs (from this brainstorm)**:
- **Bone spines** (P4 spec, section 2.6) — in scope for MVP
- **5 Panspermia Shards** (egg #8) — locations on MVP island
- **Nocturnal Espinodo** (egg #9) — 1 nocturnal creature, MVP spec
- **Magnetic Navigation** (egg #14) — crater is MVP's landmark
- **Lithosuit** (egg #5) — alpine rocks are MVP island

**Near-MVP eggs** (need P6/P8 content but species can be placed):
- **Ink Jet** (egg #6) — needs swimming (P6)
- **Echo-location** (egg #7) — needs caves (P8)
- **Mirror Move** (egg #10) — needs more species variety
- **Camouflage** (egg #13) — needs forest biome (later)
- **Symbiosis** (egg #11) — needs bonded species co-location
- **Sonic Boom** (egg #12) — needs savanna biome (later)
- **Grenadier** (egg #3) — needs toxic carcasses (later biome)
- **Flamethrower** (egg #1) — needs volcano biome (P8)
- **Astrofauna** (egg #2) — late-game, but lore ties to MVP crater
- **Titan-tamer** (egg #4) — too expensive for MVP, but giant can appear on islet (P8)
- **Regeneration** (egg #15) — late-game build
- **Paradox Shell** (egg #16) — coast biome, possible with P6