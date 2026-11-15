# Primigenia Easter Eggs — Brainstorm

Source: DESIGN.md §9 G49–G54 (part tiers, recipes, resource meters, fire, tourney gates, secrets), G65 (secrets are easter eggs), G23/G37 (DNA, parts), G50–G51 (recipe system: ≥ 2 parts + 1 diet + meter, hinted not random), W1–W15 (island, biomes, caves, underwater, meteor crater, volcanic/alpine terrain), docs/P4.md (recipes, bone spines, social system, raid, DNA economy), docs/COMBAT.md (moves, counter matrix, stamina/damage balance). All recipes go through the same counter matrix and tourney gates.

---

## Part I — Owner's ideas, developed in depth

### 1. Flamethrower (Fire Breath)

> Referenced by G50–G52, G54 → P8.

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_spitter` (CP4_MOUTH_O, level ≥ 2) **and** `fuel_gland` (new detail part `CP4_FUEL`, level ≥ 1) |
| Diet condition | Omnivore (has a CP4_MOUTH_O but no exclusive CP4_MOUTH_C locking diet out) |
| Resource meter | `fuel`, 0–100, no decay. Refilled by eating **volcano resin plants** (20 fuel per chew, 8 ticks, stand still) or old carcass of a volcanic creature (3 units × 20). |
| Spend | 20 fuel per breath |
| Move | `fire_breath` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| fire_breath | 8 | 4 | 5 | 5.5 | 0.50 | 14 | 18 | burn (6 ticks, 1 HP/tick) | ranged, AoE (hits all in cone), meter `fuel` 20 / CP4_FUEL + recipe |

Burn ticks refresh independently of bleed (they do not stack; the higher-duration or higher-per-tick source persists). Fire also ignites dry grass tiles in a 1.5 m radius on impact — grass stays burning for 120 ticks, damaging any creature that walks through (2 HP/tick, no counter-gate since world mutation is separate from combat).

**Discovery**

1. Wild hint: an **Ignisaur** species (volcano biome epic candidate) breathes fire at rival Garfio. The Ignisaur's fuel meter is pre-filled to ~60; the breath animation shows a glowing nozzle and a burst flame (visible via event `species_ability: fire_breath`).
2. Fossil clue: inspect a **resin fossil** near the volcano crater — the description mentions "ancient creatures that spat flame from a hidden gland."
3. Carcass clue: kill an Ignisaur and eat its carcass — quill wounds mixed with char marks; the codex adds "fire gland residue."

**Counter**

- `bite` at ≤ 2 m during wind-up or active: interrupts, 125 % damage, bleed, stagger 4 ticks.
- `guard` active: takes reduced damage (normal guard rules; fire is not special — the counter matrix already handles ranged moves).
- `dodge` from outside the 0.5 rad cone: avoids entirely.
- Water medium: standing in the shallow lake at the volcano base halves fire spread and burn damage. Intended counter-play: bait the fire user near water.

**Cost**

- `fuel_gland` discovery: 350 permille on kill / ally of Ignisaur (rare species on offshore islet near volcano).
- Fuel gland part cost: base 40 DNA.
- Tier T1 (enhanced): 60 DNA, 40 hits.

**Later-stage payoff (tribe → civ → space)**

- Tribe: fire-toting warriors. Fire-based territory denial. Tribe start bonus: "igniter" — fire spread is 20 % faster, giving early territorial advantage.
- Civ: siege engines that burn enemy fortifications. Fire resupply trains.
- Space: heat-shielded terraforming ships (the fire-breathing gene persists as a thermal regulation trait).

**Fun description**

> "You didn't breathe fire. You paid for it — with resin, calcium, and the courage to stand in the volcano's shadow."

---

### 2. Panspermia Survivor (Space-Adapted Creature)

> Inspired by the panspermia story frame (G34, W10), meteor crater, meteor shards (G65).

**Recipe**

| Field | Value |
|---|---|
| Parts | `rad_shield` (new detail `CP4_RADIATION`, level ≥ 2) **and** `insulation` (new detail `CP4_THERMAL`, level ≥ 1) |
| Diet condition | Any — requires `rad_shield` equipped; insulation is cosmetic but required by the recipe |
| Resource meter | `integrity`, 0–100. Refilled by standing near **panspermia meteor shards** (W10: five scattered shards, each grants +25 integrity on first interaction, 10 ticks, stand still). |
| Spend | 30 integrity per `pressure_burst` |
| Move | `pressure_burst` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| pressure_burst | 10 | 2 | 7 | 9.0 | 0.60 | 20 | 22 | — | ranged, line, meter `integrity` 30 / CP4_RADIATION + recipe |

A high-velocity discharge in a straight line (line-shaped cone). Pierces through all creatures in its path. No status effect, but hitscan means it cannot be dodged by lateral movement — only by leaving the line or dodging at the exact tick.

**Discovery**

1. Wild hint: a rare **Albino Panspermia** creature near the meteor crater fires a pressure burst at a scavenger. Its shell has a visible iridescent shimmer (rad_shield visual). The creature glows faintly at night.
2. Fossil clue: inspect a **meteorite fossil** (placed near the crater) — the description reads "not of this world: shell structure matches no island species. Radiation signatures detected."
3. Carcass clue: kill the albino; its carcass emits a faint glow. Inspecting it adds "exotic tissue chemistry" to the codex.

**Counter**

- Line shot: dodge by moving perpendicular (outside the line, not the cone).
- `guard` blocks but does not stagger (pressure is blunt force); takes full damage but can riposte.
- `bite` at ≤ 2 m during wind-up: interrupts (same as fire/spit interrupt rule).
- High stamina cost (20) and long wind-up (10) means the user is vulnerable for a long time.

**Cost**

- `rad_shield` discovery: 100 permille on kill or ally of the albino (single individual, spawns near the crater, temperament: timid, hard to hunt).
- Radiation shield part cost: base 60 DNA.
- Tier T1 (reinforced): 60 DNA, 25 hits (lower threshold — the part is rare, so the game rewards using it).

**Later-stage payoff (space stage)**

- Space: the Panspermia Survivor is the only species that can survive **vacuum** without a ship. In the space stage, seeding a dead world with a Panspermia Survivor is the fastest terraforming path (vacuum-hardy pioneer species). The trait carries forward: "panspermia-adapted" start bonus in space.
- Lore payoff: the creature IS a panspermia organism — life from the meteor. Finding it reveals the truth of the world's origin.

**Fun description**

> "It didn't evolve on this island. It fell here — and it remembers the stars."

---

### 3. Evolved Bomb (Detonator)

> Owner's idea: "evolved bombs." A creature that can explode itself.

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_explosive` (new detail `CP4_EXPLOSIVE`, level ≥ 3) **and** `trigger_jaw` (new mouth variant `CP4_JAW_TRIGGER`, level ≥ 1) |
| Diet condition | Carnivore (must have CP4_MOUTH_C; the jaw type is cosmetic but required by the recipe) |
| Resource meter | `pressure`, 0–100. Refilled by eating **sulfur carcasses** (volcanic creatures, +20 per meat unit, 10 ticks) or **geothermal vents** (standing still near a vent in the alpine volcano zone, +5/tick, up to 60). |
| Spend | 50 pressure per detonation |
| Move | `detonation` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| detonation | 6 | 1 | 30 | 5.0 | 6.28 (360°) | 10 | 30 (AoE) | stun (10) + self-hp 40 % | self-destruct, meter `pressure` 50 / CP4_EXPLOSIVE + recipe |

A 360° AoE blast centered on the user. Deals 30 damage to all within 5 m (including self: 40 % of current HP). Stuns everyone for 10 ticks. The user survives with at least 10 HP (floored). The long recovery (30 ticks) means the user is completely vulnerable afterward.

**Discovery**

1. Wild hint: a **Bombaclast** in the alpine crater edge charges an enemy and explodes mid-air. The kill-cam shows a creature dissolving into a cloud of particles. If the player is nearby, they survive the blast with reduced HP.
2. Fossil clue: a **fragmented fossil** in the crater — "shattered by internal pressure. The shell structure suggests a deliberate sacrifice mechanism."
3. Carcass clue: kill a Bombaclast before it detonates; its carcass has blast scarring. Inspecting it reveals "internal explosive chambers."

**Counter**

- `dodge` from > 5 m: avoids entirely. The blast is 5 m radius.
- `guard` at 0 m: takes damage but no stun (guard absorbs the kinetic shock).
- Kill it before it winds up: its wind-up is visible (it curls inward, glowing red). A charge at close range interrupts it.
- **Strategic counter**: the Bombaclast is suicidal — it has no incentive to fight a distant enemy. It only detonates when cornered or when the player orders it.

**Cost**

- `sac_explosive` discovery: 200 permille on kill of Bombaclast (single individual on the alpine ledge, temperament: aggressive, high HP 150).
- Explosive sac part cost: base 80 DNA.
- Tier T1 (stabilized): 60 DNA, 75 hits.

**Later-stage payoff (tribe → civ)**

- Tribe: living siege weapons. Bombaclast-tribe warriors use controlled detonations to breach enemy fortifications (limited — each warrior can detonate only once per battle).
- Civ: "suicide bomber" units that clear minefields.
- Social payback: befriending a Bombaclast is a high-trust feat — the tribe gains a "fearless" trait (warriors never flee).

**Fun description**

> "Some creatures fight to live. This one fights so you don't."

---

### 4. Befriend the Colossus (Giant Ally)

> Owner's idea: "befriending giants." Ties to the epic creature concept (W4).

**Recipe**

| Field | Value |
|---|---|
| Parts | `snout_trumpet` (CP4_MOUTH_G or _O, level ≥ 3) **and** `plume_great` (new detail `CP4_PLUME_GREAT`, level ≥ 2, a massive display plume) |
| Diet condition | Herbivore (must have a grazer mouth; the plume is cosmetic but required) |
| Resource meter | `devotion`, 0–100. Refilled by feeding gifts to the giant's herd (+10 per correct-diet gift, 5 ticks, 30-tick cooldown per gift). The Colossus is not the target — its herd is. You befriend the herd to gain the giant's trust. |
| Spend | 80 devotion per `summon_giant` |
| Move | `summon_giant` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| summon_giant | 15 | 10 | 15 | 0 | 0 | 25 | 0 | — | call: a giant appears and attacks your current target for 200 ticks (40 seconds), then leaves |

The giant is a separate entity (a large NPC with its own profile: mouth 4, charge 3, tail 3, HP 300, speed 2.5). It targets your current hostile target and fights autonomously using greedy AI. It does not require fuel or meter. It dies permanently (respawn in 6,000 ticks / ~10 minutes simulated). If the giant dies, the devotion meter is reset.

**Discovery**

1. Wild hint: the **Colossus** (epic creature, W4: lives on the offshore islet) walks between biomes periodically. It ignores most creatures but charges when a Garfio raid threatens a Rondo herd. The player witnesses it from a distance (too far to interact directly).
2. Fossil clue: a **giant fossil** in the alpine — "bone fragments suggest a creature five times the size of any living species. The horns were used for display, not combat."
3. Social clue: befriending the Rondo herd (temperament: timid, herd-based) triggers a unique event — "The herd points toward the sea. Something vast moves there." This unlocks the Colossus tracking system.

**Counter**

- The giant has a 10-tick wind-up — close-range bite during wind-up interrupts (interrupts the summon, no giant appears).
- The giant is dumb: it charges the first hostile it sees, even if it's not your target. Smart players lure it toward enemies; dumb players accidentally provoke it.
- If the player attacks the giant, every member of its herd turns hostile (permanent aggro).
- 25 stamina cost + 15 tick wind-up means the user cannot spam it.

**Cost**

- `snout_trumpet` discovery: from befriending Rondo (signature part, guaranteed on alliance).
- `plume_great` discovery: 150 permille on kill of the Colossus (epic, 300 HP, spawns on islet). Also 100 permille on ally (if you befriend the herd, the Colossus may gift you a plume).
- Plume great part cost: base 100 DNA (rare part, expensive).
- Tier T1 (magnified): 60 DNA, 30 hits.

**Later-stage payoff (tribe → civ)**

- Tribe: the Colossus becomes a **mount** for the tribe's chief. The tribe gains "colossus-tamed" starting bonus: +20 % HP for all warriors.
- Civ: the giant is domesticated and becomes a living siege engine. Civ "Colossus" unit (slow, massive HP, slow attack).
- Space: the Colossus gene is adapted as a heavy-world gravity adaptation (thick bones, massive frame).

**Fun description**

> "You didn't tame the giant. You befriended its family, and it decided to help you."

---

### 5. Rock Armour (Lithoskin)

> Owner's idea: "eating rocks for rock armour."

**Recipe**

| Field | Value |
|---|---|
| Parts | `carapace_stone` (new detail `CP4_LITHO`, level ≥ 2) **and** `jaw_crusher` (new mouth `CP4_JAW_CRUSHER`, level ≥ 1, a beak-like crushing mouth) |
| Diet condition | Herbivore (must have a grazer mouth; the jaw crusher is cosmetic but required) |
| Resource meter | `calcium`, 0–100. Refilled by eating **rocks** (interact with any rock on the ground, 15 calcium per rock, 5 ticks, stand still) or old carcass of a lithophagic creature (2 units × 15). |
| Spend | 25 calcium per `stone_shell` |
| Move | `stone_shell` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| stone_shell | 4 | 20 | 3 | 0 | 2.40 | 5 | 0 | — | self-buff: incoming damage reduced by 40 % for duration, meter `calcium` 25 / CP4_LITHO + recipe |

A defensive move, not an attack. While active, the creature is encased in a rock shell that reduces all incoming damage by 40 %. The shell lasts 20 active ticks (2 seconds at 10 Hz) and costs only 5 stamina — but the calcium cost is 25 per activation. The user is immobile for the duration (cannot move, cannot use other moves).

After the shell ends, the carapace_stone part provides a passive +5 % damage reduction (permanent, stacking with guard).

**Discovery**

1. Wild hint: a **Lithodon** species in the coastal rocks slowly eats stones. When threatened, it pulls its limbs inward and becomes a boulder — visually indistinguishable from a rock until attacked (then damage is visibly reduced).
2. Fossil clue: inspect a **mineral fossil** on the coast — "shell layers alternate organic and mineral. This creature ate stone."
3. Carcass clue: kill the Lithodon and eat its carcass — "the meat is dense with mineral deposits. High calcium content."

**Counter**

- The user is immobile and cannot dodge during the shell. A `charge` from the side or rear hits full damage (the shell only reduces frontal damage; the 2.40 rad guard arc still applies, and the shell does not add extra guard factor).
- `tail_strike` from behind: the shell does not cover the rear; tail hits gain 25 % side bonus and 50 % rear bonus.
- Damage-over-time (burn, bleed) still applies at reduced rate — a smart opponent will apply bleed, then guard to absorb the riposte, knowing the lithoskinned creature cannot escape.

**Cost**

- `carapace_stone` discovery: 250 permille on kill or ally of Lithodon (common species in the coastal biome, easy to find).
- Litho part cost: base 30 DNA (cheap — it's a common creature's part).
- Tier T1 (layered stone): 60 DNA, 25 hits. Reduces incoming by 50 % instead of 40 %.
- Tier T2 (fortress): 150 DNA, 75 hits. Shell lasts 30 ticks. Passive reduction becomes 10 %.

**Later-stage payoff (tribe → civ)**

- Tribe: "lithoskin" warriors start with +10 % damage resistance. Tribe "stone wall" defensive bonus.
- Civ: siege towers with stone plating. Walls that regenerate (calcium resource from quarries).
- Space: planetary crust-mining adaptation. The species can survive on asteroid surfaces (rock-feeding pioneers).

**Fun description**

> "Most creatures hide in shells. This one ate one."

---

## Part II — Original Easter eggs (12)

### 6. Ink Jet (Ink Cloud)

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_ink` (new detail `CP4_INK`, level ≥ 2) **and** `sac_spitter` (CP4_MOUTH_O, level ≥ 1) |
| Diet condition | Carnivore or Omnivore (has an oral spit mouth) |
| Resource meter | `ink`, 0–80. Refilled by eating **deep-sea fish** (underwater kills, +10 per kill, 8 ticks). |
| Spend | 20 ink per jet |
| Move | `ink_jet` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| ink_jet | 5 | 1 | 3 | 4.0 | 0.80 | 10 | 2 | blindness (8 ticks, -50 % accuracy, cannot counter) | ranged, meter `ink` 20 / CP4_INK + recipe |

Blindness prevents the target from guarding or counter-attacking for 8 ticks (the target can still dodge but not time a riposte). Low damage, but devastating in combos.

**Discovery**

1. Wild hint: an **Inknose** species in the underwater caves fires ink at predators. The cloud spreads visually; enemies within it flash "confused."
2. Fossil clue: a **cephalopod fossil** in the shallow sea — "ancient defenders that clouded their enemies' sight to escape."
3. Carcass clue: inspect an Inknose carcass — "ink sac intact. Pressure-resistant tissue."

**Counter**

- `dodge` from the edge of the arc: avoids.
- Blindness does not prevent the target from being hit; it only removes their counter options.
- `guard` still works (blind creatures can still guard instinctively — the status only disables intentional counter-play).

**Cost**

- Ink sac discovery: 300 permille on kill of Inknose (common in underwater caves, P6 content).
- Ink sac part cost: base 25 DNA.

**Later-stage payoff**

- Tribe: "smoke bomb" tactics for ambush raids.
- Civ: naval warfare — ink clouds disable enemy ship targeting systems (comedic but functional).

**Fun description**

> "Not a fighter? No worries. Just ruin their day and leave."

---

### 7. Magnetic Pulse (Bio-EMF)

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_electric` (new detail `CP4_ELECTRIC`, level ≥ 2) **and** `senses_magnetic` (new sense `CP4_MAGNETIC`, level ≥ 1) |
| Diet condition | Any (requires electric organ; diet-neutral) |
| Resource meter | `charge`, 0–100. Refilled by standing near **magnetic mineral deposits** (coastal rock outcrops, +10/tick, up to 100, 8-tick delay before refilling starts). |
| Spend | 25 charge per pulse |
| Move | `magnetic_pulse` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| magnetic_pulse | 4 | 2 | 4 | 6.0 | 1.00 | 8 | 6 | disoriented (6 ticks, random movement direction changes) | ranged, AoE cone, meter `charge` 25 / CP4_ELECTRIC + recipe |

Disoriented: the target's next movement order is randomly directed (the game picks a random bearing). In combat, this breaks approaches and charge setups.

**Discovery**

1. Wild hint: an **Electrotail** in the coastal cliffs generates a visible spark when threatened, causing nearby Garfio to stagger and turn randomly.
2. Fossil clue: a **ferromagnetic fossil** (placed near a magnetic outcrop) — "bones infused with iron. This creature generated its own field."
3. Social clue: befriending a species that already uses magnetic pulse teaches the move (social learning — unique to this recipe).

**Counter**

- Dodge from outside 1.0 rad cone.
- Disoriented creatures cannot guard, but they also cannot charge — it's a crowd-control move, not a kill move.
- `guard` from outside the cone: unaffected.

**Cost**

- Electric sac: 200 permille on kill of Electrotail (uncommon, spawns near magnetic outcrops).
- Magnetic sense: from befriending an Electrotail (signature part).
- Electric sac part cost: base 45 DNA.

**Later-stage payoff**

- Tribe: "disruptor" units that scatter enemy formations.
- Space: planetary magnetic shield generators.

**Fun description**

> "You thought you were aiming at the weak one? Your own legs disagreed."

---

### 8. Chameleon Shift (Adaptive Camouflage)

**Recipe**

| Field | Value |
|---|---|
| Parts | `skin_chroma` (new detail `CP4_CHROMA`, level ≥ 2) **and** `eye_zoom` (new sense `CP4_ZOOM`, level ≥ 1) |
| Diet condition | Any (requires the skin part; diet-neutral) |
| Resource meter | `energy`, 0–100. Drains 0.5/tick while active. Refilled by eating (normal feeding). |
| Spend | Passive drain only — no upfront cost, but the meter empties during use |
| Move | `camouflage` (passive ability, not a verb) |

**Effect**: When standing still for 5 ticks, the creature's visible range to enemies is reduced by 60 %. While in camouflage, moving even 0.1 m resets the 5-tick build-up. The effect is strongest in the biome matching the creature's base color (meadow creatures blend in the meadow, coast creatures on the beach).

Camouflage is not invisibility. At 60 % reduction, the creature is still detectable at close range (the perception radius shrinks from ~15 m to ~6 m in the matching biome). It does not stack with ink jet (the creature chooses one stealth mode).

**Discovery**

1. Wild hint: a **Palestrus** species on the coast looks exactly like the sand until it moves. The player must watch for displacement (grass bending, shadow shifting) to spot it.
2. Fossil clue: a **chromatophore fossil** (surface, meadow biome) — "pigment cells organized in layers. This creature could change its skin."
3. Carcass clue: kill the Palestrus and inspect — "the skin retains the color of its last position."

**Counter**

- Movement breaks camouflage instantly. A charging enemy forces the camouflaged creature to either flee (losing stealth) or stand and be found.
- Fire reveals camouflage (the heat signature is visible through the flame light). This is a fire-specific counter — fire-breathing creatures bypass camouflage entirely.
- The eye_zoom part required gives zoom vision, but that's the predator's tool, not the prey's.

**Cost**

- Chroma skin: 150 permille on kill of Palestrus (rare, single biome, temper: timid).
- Zoom eye: from befriending a Palestrust (signature).
- Chroma skin part cost: base 35 DNA.

**Later-stage payoff**

- Tribe: scout units that infiltrate enemy territory.
- Civ: stealth bombers, reconnaissance satellites.

**Fun description**

> "It wasn't hiding. You just stopped looking hard enough."

---

### 9. Pack Rally (Coordinated Call)

**Recipe**

| Field | Value |
|---|---|
| Parts | `snout_trumpet` (CP4_MOUTH_G, level ≥ 2) **and** `ear_scoop` (new sense `CP4_EAR_SCOOP`, level ≥ 1) |
| Diet condition | Any (requires a singing mouth) |
| Resource meter | `stamina` (uses normal stamina, no separate meter) |
| Spend | 15 stamina (same as a sing skill) |
| Move | `pack_rally` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| pack_rally | 3 | 5 | 4 | 0 | 0 | 15 | 0 | — | buff: all allies within 15 m gain +20 % damage and +10 % speed for 30 ticks |

A social move repurposed as combat. It buffs allied creatures (both wild allies and befriended species) but also has a minor effect on the user's own combat: the user's bite damage temporarily increases (the user is part of the pack).

**Discovery**

1. Wild hint: two species of different types (e.g., Rondo and Zanco) fighting a Garfio together — the Zanco makes a call, and the Rondos coordinate their flanking. The player hears a unique sound (a chord, not a single note).
2. Fossil clue: a **pack fossil** (a cluster of three different species' fossils found together, unusual) — "they hunted together. Not by chance — by agreement."
3. Social clue: befriending two different species and having them fight side-by-side triggers a unique observation: "The two species are communicating. A new pattern emerges."

**Counter**

- The buff takes 5 ticks to activate — interrupt during wind-up (bite at ≤ 2 m) prevents it.
- Kill the caller first: the rally has no range, so it must be in melee distance. A charge from behind catches the caller off-guard.
- The 15 stamina cost means you cannot spam rallies during a fight.

**Cost**

- Trumpet mouth from befriending Rondo (signature part, guaranteed on alliance).
- Ear scoop: 200 permille on kill of Zanco (medium rarity).
- Trumpet mouth cost: base 20 DNA. Ear scoop cost: base 15 DNA.

**Later-stage payoff**

- Tribe: "war cry" ability — all tribe units gain attack bonus in coordinated raids.
- Civ: military doctrine — combined-arms bonuses.
- Social payoff: this is the ultimate befeinder's reward. The creature that united species now commands them.

**Fun description**

> "Three species. One voice. The Garfio didn't stand a chance."

---

### 10. Burrow Collapse (Trap Tunnel)

**Recipe**

| Field | Value |
|---|---|
| Parts | `claw_dig` (CP4_DIGGING, level ≥ 3) **and** `tail_heavy` (new detail `CP4_TAIL_HEAVY`, level ≥ 2, a dense, club-like tail) |
| Diet condition | Any (requires digging claws; diet-neutral) |
| Resource meter | `tunnel_energy`, 0–50. Refilled by resting in any burrow (10/tick, 5-tick delay). |
| Spend | 30 tunnel_energy per collapse |
| Move | `tunnel_collapse` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|: |---:|---:|---:|---|
| tunnel_collapse | 8 | 1 | 8 | 3.0 | 0.50 | 8 | 10 | buried (12 ticks, immobilized) | underground, meter `tunnel_energy` 30 / CP4_DIGGING + recipe |

The user burrows underground and causes the ground above a target zone to collapse. Enemies in the cone are dealt damage and become **buried** (immobilized for 12 ticks; they can spend stamina to dig out early, at -1 stamina/tick). The user also goes underground and is temporarily invulnerable (cannot be targeted while buried) but is helpless for 8 ticks recovery.

**Discovery**

1. Wild hint: a **Molestrider** in the forest digs a tunnel and collapses it on a Garfio. The Garfio sinks into a pit and struggles for a moment.
2. Fossil clue: a **burrow fossil** (underground, accessible by digging — P8 content) — "a perfectly circular tunnel system. Built by something that lived below."
3. Carcass clue: kill the Molestrider — "the body is built for digging: massive forelimbs, reduced eyes, reinforced skull."

**Counter**

- The user is invulnerable while digging but also immobile. A smart opponent waits for the recovery (8 ticks) and then attacks.
- `tail_strike` from above: the user is underground but the collapse wave hits upward, so tail strikes from elevated positions (cliffs) can hit.
- The buried status can be self-applied as an escape: use tunnel_collapse on yourself to become invulnerable and reposition.

**Cost**

- Digging claws from fossils (buried fossils, P8 content).
- Tail heavy: 200 permille on kill of Molestrider (uncommon in forest).
- Digging claw cost: base 50 DNA. Tail heavy cost: base 30 DNA.

**Later-stage payoff**

- Tribe: tunnel networks for secret supply lines and surprise attacks.
- Civ: underground bunkers, tunnel warfare.

**Fun description**

> "The ground didn't open up. Someone asked it to."

---

### 11. Regeneration Surge (Tissue Rewrite)

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_regenerative` (new detail `CP4_REGEN`, level ≥ 3) **and** `mouth_vorous` (new mouth `CP4_MOUTH_VOR`, level ≥ 2, a wide, flexible mouth) |
| Diet condition | Omnivore (has a voracious mouth but not a specialized carnivore or grazer lock) |
| Resource meter | `nutrients`, 0–100. Refilled by eating (any food, +5/tick for 30 ticks after a meal, then resets). |
| Spend | 15 nutrients per surge |
| Move | `regen_surge` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| regen_surge | 2 | 15 | 4 | 0 | 0 | 3 | 0 | — | self-heal: 2 HP/tick for 15 ticks (30 HP total), meter `nutrients` 15 / CP4_REGEN + recipe |

The longest self-heal in the game. 30 HP over 15 ticks is significant — especially mid-fight. The low stamina cost (3) and short wind-up (2) make it usable in combat. However, the nutrients cost means you must have eaten recently, and the heal stops if the nutrients run dry mid-combat (they drain at 1/tick during the surge).

**Discovery**

1. Wild hint: a **Chimerae** creature that survives a charge with very low HP, then visibly knits itself back together over several ticks. The opponent is stunned by the resilience.
2. Fossil clue: a **regenerative fossil** (surface, forest) — "bone fragments show complete regrowth after trauma. This creature healed from anything."
3. Carcass clue: kill the Chimerae at low HP and inspect — "the tissue is actively repairing. Even after death, cells continue to move."

**Counter**

- The heal is gradual (2 HP/tick). Burst damage (charge, spine volley) that exceeds the heal rate overwhelms it.
- The user must be alive and conscious — if stunned or buried, the heal stops.
- Nutrient starvation: if the user has not eaten, the meter starts at 0 and the move fails (or heals 0 HP).

**Cost**

- Regenerative sac: 100 permille on kill of Chimerae (rare, spawns in forest, high HP 200).
- Vorous mouth: from befriending a Chimerae (signature, guaranteed on alliance).
- Regenerative sac cost: base 70 DNA. Vorous mouth cost: base 35 DNA.

**Later-stage payoff**

- Tribe: "survivalist" trait — tribe units start with 10 % more HP.
- Civ: advanced medical technology. Civilian units repair buildings.
- Space: rapid tissue regeneration in low-gravity environments.

**Fun description**

> "You thought you killed it? It was just reloading."

---

### 12. Bio-Luminescent Signal (Light Dance)

**Recipe**

| Field | Value |
|---|---|
| Parts | `lure_lantern` (CP4_LURE, level ≥ 2) **and** `plume_glow` (new detail `CP4_GLOW_PLUME`, level ≥ 1) |
| Diet condition | Any (requires the lure and plume) |
| Resource meter | `energy`, 0–80. Drains 2/tick while active. |
| Spend | Passive drain only |
| Move | `luminescence` (passive visual ability) |

**Effect**: The creature's lure and plume glow with a spectrum of colors. While active (passive, always available if equipped), the creature emits a visible light visible up to 30 m at night (100 m during the day in fog). The colors shift based on the creature's mood and trust level:

- Blue: peaceful, low mood (safe to approach)
- Green: neutral, moderate mood
- Red: hostile, high mood (danger)
- Rainbow: maximally bonded (unique visual — only achievable at trust 80+ with a befriended species)

The **rainbow glow** is a visual-only easter egg (no combat effect) but serves as a world signal: any creature (including wild hostile species) within 40 m that sees the rainbow glow becomes temporarily peaceful for 30 ticks (they lose aggro and flee instead of attacking). This is a unique pacification mechanic.

**Discovery**

1. Wild hint: a **Nocturne** species on the nocturnal species list glows softly at night. Its lure pulses in rhythm. The player first sees it as a distant light before spotting the creature.
2. Fossil clue: a **bioluminescent fossil** (deep cave, P6 underwater cave) — "traces of light-producing compounds. This creature was a living beacon."
3. Social clue: bonding with a Nocturne at trust 80+ triggers a unique event: "The creature's lure erupts in every color. For a moment, the whole valley is alive with light. Even the predators step back."

**Counter**

- No combat counter — it's a passive visual ability.
- The pacification effect can be exploited: a player can use a rainbow-glowing creature as a temporary safe zone in a hostile area.
- Fire is the natural counter: fire light overwhelms bioluminescence (the glow becomes invisible near flames).

**Cost**

- Lure lantern: 250 permille on kill of Nocturne (rare nocturnal species).
- Glow plume: from befriending a Nocturne (signature).
- Lure lantern cost: base 40 DNA. Glow plume cost: base 20 DNA.

**Later-stage payoff**

- Tribe: signal towers using bioluminescent plants.
- Civ: communication networks.
- Space: the bioluminescent species becomes a deep-space signal beacon (visible across star systems).

**Fun description**

> "It didn't speak. It just lit up, and the world listened."

---

### 13. Spore Cloud (Cell-Stage Callback)

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_spore` (new detail `CP4_SPORE`, level ≥ 2) **and** `wing_glide` (CP4_WING, level ≥ 1, to disperse spores by air) |
| Diet condition | Herbivore (requires a grazer mouth — spores are plant-derived) |
| Resource meter | `spores`, 0–60. Refilled by grazing on meadow grass (+2/spread tick, grazing takes 30 ticks, 10 spores restored). |
| Spend | 20 spores per cloud |
| Move | `spore_cloud` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| spore_cloud | 5 | 3 | 5 | 4.0 | 3.14 (semicircle) | 8 | 0 | infected (10 ticks, -20 % all stats, stackable to 3) | area denial, meter `spores` 20 / CP4_SPORE + recipe |

A 180° spore cloud in front of the user. Enemies caught in the cloud gain "infected" status: -20 % speed, -20 % damage, -20 % stamina regen. Stacks up to 3 times (max -60 % all stats). The infection lasts 10 ticks.

The spores linger in the area for 60 ticks after the move — enemies entering the cloud during this time also become infected. This creates a lasting area-denial zone that can be used defensively (guard behind a spore cloud, enemies walk through and get debuffed).

**Discovery**

1. Wild hint: a **Sporewing** creature (meadow, rare) releases a spore cloud at a predator. The cloud hangs visible in the air for several seconds.
2. Fossil clue: a **cell-spore fossil** (surface, meadow) — "remnants of single-celled organisms. Their spore mechanism was preserved."
3. Carcass clue: kill the Sporewing and inspect — "wings dusted with spores. Each wingbeat releases thousands."

**Counter**

- Dodge from outside the 180° arc.
- `guard` while standing behind a friendly creature (the spores hit the front layer first).
- Wind direction matters: the spores blow away from the user's facing. Smart positioning can blow them back at the attacker.

**Cost**

- Spore sac: 150 permille on kill of Sporewing (rare meadow species).
- Glide wing: 200 permille on kill of Zanco (common).
- Spore sac cost: base 35 DNA. Wing glide cost: base 25 DNA.

**Later-stage payoff**

- Tribe: biological warfare — spore-based crop rotation that weakens enemy territory.
- Civ: agricultural biotech. Spore-based pest control.
- Space: planetary bio-engineering. Terraforming with engineered spores.

**Fun description**

> "The cell stage never ended. It just grew up."

---

### 14. Sonar Pulse (Echo Location)

**Recipe**

| Field | Value |
|---|---|
| Parts | `echo_organ` (new sense `CP4_ECHO`, level ≥ 2) **and** `snout_trumpet` (CP4_MOUTH_G, level ≥ 1) |
| Diet condition | Any (requires the echo organ; diet-neutral) |
| Resource meter | `focus`, 0–50. Refilled by idle/resting (10/tick, 5-tick delay). |
| Spend | 10 focus per pulse |
| Move | `sonar_pulse` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| sonar_pulse | 3 | 1 | 2 | 15.0 | 0 (omnidirectional) | 5 | 0 | — | reveals all entities within 15 m for 5 ticks, meter `focus` 10 / CP4_ECHO + recipe |

No damage. Pure information. Reveals the exact position, facing, and type of every entity within 15 m, including hidden creatures (camouflage is bypassed), burrowed creatures (position above ground is shown), and invisible effects (spore cloud boundaries, fire edges). The reveal lasts 5 ticks.

The sonar pulse also reveals **weak points** on enemies for 3 ticks after the reveal: the next attack against a revealed enemy deals +25 % damage (the "weak point" is highlighted visually).

**Discovery**

1. Wild hint: a **Cavernaut** species in an underwater cave clicks loudly. The click visibly ripples through the water (a subtle visual effect the player notices after a few encounters).
2. Fossil clue: a **echolocation fossil** (underwater cave) — "skull structure adapted for sound reflection. This creature saw with sound."
3. Social clue: befriending a Cavernaut species and having it "sing" while you are in a dark cave (if caves had darkness — a stretch for P4, but the game's codex describes it as "saw through the dark").

**Counter**

- No damage, so no combat counter per se.
- The pulse reveals the user's position too — enemies know where the sonar user is.
- 50 focus limit means limited uses (5 pulses max on a full meter). Rest is required between pulses.

**Cost**

- Echo organ: 200 permille on kill of Cavernaut (rare underwater species, only in caves).
- Trumpet mouth: from befriending Rondo.
- Echo organ cost: base 50 DNA.

**Later-stage payoff**

- Tribe: scouts that can see through terrain. "Clairvoyant" tribe trait.
- Civ: radar technology. Early warning systems.
- Space: deep-space sonar for mapping unexplored systems.

**Fun description**

> "It didn't need eyes. It listened to the world's heartbeat."

---

### 15. Freeze Breath (Cryo Spit)

**Recipe**

| Field | Value |
|---|---|
| Parts | `sac_cryo` (new detail `CP4_CRYO`, level ≥ 2) **and** `sac_spitter` (CP4_MOUTH_O, level ≥ 2) |
| Diet condition | Omnivore (has an oral spit mouth; no carnivore lock) |
| Resource meter | `coolant`, 0–80. Refilled by standing near **glacial melt water** (alpine biome streams, +5/tick, 5-tick delay). Or eating ice crystals (found near alpine snow patches, +20 per crystal). |
| Spend | 20 coolant per breath |
| Move | `freeze_breath` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| freeze_breath | 7 | 3 | 5 | 5.0 | 0.35 | 12 | 8 | frozen (4 ticks, immobilized) | ranged, meter `coolant` 20 / CP4_CRYO + recipe |

Lower damage than fire breath (8 vs 18) but the **frozen** status is devastating: the target is completely immobilized for 4 ticks (cannot move, cannot attack, cannot guard). Frozen creatures take +50 % damage from all sources (the ice cracks under impact).

The frozen state can be broken early by taking damage (any single hit that deals > 10 HP shatters the ice). This creates a risk-reward decision: keep the enemy frozen to control them, or break the ice early for burst damage.

**Discovery**

1. Wild hint: a **Glacior** species in the alpine snow fields breathes frost at a rival. The target's legs freeze to the ground, then shatter when struck.
2. Fossil clue: an **ice-age fossil** (alpine surface) — "preserved in permafrost. This creature spat cold."
3. Carcass clue: kill the Glacior and inspect — "oral cavity lined with cryo-glands. The spit was colder than the surrounding air."

**Counter**

- The user is stationary and vulnerable during the 7-tick wind-up. A charge closes the gap before the breath fires.
- Frozen creatures can be shattered early by allies (friendly fire). Smart teams use this: freeze an enemy, then shatter it with a charged ally's hit.
- Fire breath is the natural counter: fire melts ice instantly and damages the frozen creature for extra burn on top.

**Cost**

- Cryo sac: 200 permille on kill of Glacior (uncommon, alpine biome, high HP 180).
- Spit mouth: from befriending Zanco.
- Cryo sac cost: base 50 DNA.

**Later-stage payoff**

- Tribe: frost warriors. Ice-based territory control.
- Civ: cryogenic weapons. Freezing enemy supply lines.
- Space: cryogenic storage. Preserving cargo in deep space.

**Fun description**

> "Fire burns. Ice remembers. And frozen things break the loudest."

---

### 16. Charge Rampage (Unstoppable Dash)

**Recipe**

| Field | Value |
|---|---|
| Parts | `horn_charge` (CP4_HORN, level ≥ 3) **and** `leg_power` (new leg variant `CP4_LEG_POWER`, level ≥ 2, a reinforced leg) |
| Diet condition | Omnivore (has a horn; diet-neutral for this recipe) |
| Resource meter | `adrenaline`, 0–100. Refilled by taking damage (+20 per hit received, max 100, 10-tick decay). |
| Spend | 50 adrenaline per rampage |
| Move | `charge_rampage` |

**Combat stats (level 1)**

| Move | Wind-up | Active | Recovery | Reach | Arc | Stamina | Damage | Status | Flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| charge_rampage | 2 | 12 | 2 | 8.0 | 0.70 | 0 | 34 | stun (6) | unstoppable, meter `adrenaline` 50 / CP4_HORN + recipe |

An upgraded charge: 8 m reach (vs 5 m standard), 12 active frames (vs 5), and **unstoppable** — the user cannot be stopped by obstacles, cannot be dodged (the path is pre-determined), and the charge continues through enemies (hits up to 3, dealing 34 to the first and 20 to each subsequent).

The insane reach and multi-hit make it a game-changer, but the cost is 50 adrenaline (half the meter). You need to have been hit at least 2–3 times before using it. And after the rampage, you're wide open with a 2-tick recovery and no adrenaline left.

**Discovery**

1. Wild hint: a **Berserker** species (aggressive, temper 2) charges through a group of three Rondos, hitting all three in one pass. It roars afterward — a visible animation.
2. Fossil clue: a **fractured horn fossil** (savanna biome, surface) — "the horn shows multiple impact fractures. This creature charged through walls."
3. Carcass clue: kill the Berserker and inspect — "adrenaline glands hyper-developed. The beast fought on empty."

**Counter**

- After the rampage, the user has 0 adrenaline and 2 ticks of recovery. This is the window: charge into the user during recovery, or guard and riposte.
- The charge is predictable (straight line). Enemies positioned off the trajectory survive.
- The 50 adrenaline cost means it can only be used once per encounter (unless the user takes more damage during the rampage to refill — possible but risky).

**Cost**

- Horn: from befriending Espinodo (signature on ally).
- Power leg: 250 permille on kill of Berserker (uncommon, aggressive, 150 HP).
- Horn cost: base 30 DNA. Power leg cost: base 40 DNA.

**Later-stage payoff**

- Tribe: "berserker" warriors — fearless charge attacks.
- Civ: cavalry charge units.
- Space: orbital insertion drops (high-velocity, unstoppable descent).

**Fun description**

> "It didn't slow down. It didn't stop. And it didn't care about the cost."

---

### 17. Mimicry Clone (Doppelgänger)

**Recipe**

| Field | Value |
|---|---|
| Parts | `skin_chroma` (CP4_CHROMA, level ≥ 2, the same part as camouflage) **and** `voice_fake` (new mouth variant `CP4_MOUTH_FAKE`, level ≥ 1) |
| Diet condition | Any (requires both the skin and the fake mouth; diet-neutral) |
| Resource meter | `mimic_energy`, 0–60. Drains 1/tick while mimicking. Refilled by eating (normal food, +3/tick for 20 ticks after a meal). |
| Spend | Passive drain only |
| Move | `mimic` (passive ability, activated by targeting a creature) |

**Effect**: When the user targets an enemy creature and holds still for 3 ticks, the user copies that creature's appearance, size, and sound for 60 ticks (6 seconds). During the mimic, the user is classified as the same species as the target by all AI (wild creatures treat the user as a member of that species). Bonded allies still recognize the user as their own (the mimic is not perfect).

The mimicry is perfect for social manipulation: walk into a hostile species' territory disguised as one of them, or approach an enemy pack as a "new member." The user can still attack, but doing so ends the mimic early (reduced to 10 ticks).

**Discovery**

1. Wild hint: a **Mimicula** species that follows a Rondo herd, perfectly mimicking their appearance. It only reveals itself when the herd is vulnerable — it attacks from within.
2. Fossil clue: a **mimic fossil** (coastal cliff) — "skull structure suggests a vocal adaptation. Bone texture indicates pigment control. This creature wore other faces."
3. Carcass clue: kill the Mimicula and inspect — "its skin still holds the Rondo pattern. It learned to become them."

**Counter**

- Bonded allies recognize the mimic (their trust ring doesn't change color). Smart players who have befriended the target species can spot imposters.
- The user's combat profile doesn't change — a Mimicula mimicking a tank still has the Mimicula's weak HP.
- The 60-tick duration is short. After the mimic fades, the user is exposed and likely surrounded by angry enemies.

**Cost**

- Chroma skin: from killing a Palestrus (150 permille).
- Voice fake: from befriending a Mimicula (signature, guaranteed).
- Chroma skin cost: base 35 DNA. Voice fake cost: base 20 DNA.

**Later-stage payoff**

- Tribe: infiltrators. Spy units that join enemy tribes.
- Civ: espionage. Diplomatic infiltration.
- Space: planetary impersonation protocols.

**Fun description**

> "It didn't trick you. It convinced you to let it in."

---

## Part III — Ranked Shortlist

### The 8 Best Easter Eggs

| Rank | Easter Egg | Why |
|---|---|---|
| 1 | **Panspermia Survivor** | Ties directly into the game's narrative (G34: panspermia story frame, meteor crater, W10). It's the only easter egg that bridges the creature stage and the space stage meaningfully. The albino species near the crater is a memorable visual. The space-stage payoff (vacuum-hardy pioneer) makes the creature stage feel like preparation for something bigger. |
| 2 | **Flamethrower (Fire Breath)** | G52 specifically says fire changes the world. It's not just a move — it's a world-state change (burning grass, cooking food, scaring creatures). It creates emergent gameplay: a player can burn a forest to flush out prey, cook food for bonus DNA, or create fire barriers. The volcano biome ties into the world's geography. |
| 3 | **Rock Armour (Lithoskin)** | The owner's "eating rocks" idea. It's simple, funny, and deeply satisfying to play. A creature that eats stones and becomes a walking boulder is immediately memorable. The defensive playstyle contrasts nicely with the aggressive moves, and the passive damage reduction means the part is useful even without the recipe. |
| 4 | **Evolved Bomb (Detonation)** | High risk, high reward. The self-destruct mechanic is visually spectacular and creates memorable moments. The fact that it's a 360° AoE with self-damage makes it a dramatic last-stand option. TheBombaclast's design (curling inward, glowing red) is an iconic visual. |
| 5 | **Befriend the Colossus** | Ties into the epic creature (W4) and the social mechanics (G19, G26). The idea that you befriend the giant's *herd* rather than the giant itself is clever — it rewards the social playloop. The giant as a temporary ally creates a "you won't believe your eyes" moment when it appears. |
| 6 | **Ink Jet** | Pure joy. A creature that squirts ink is inherently funny and satisfying. The blindness status is strategically interesting (prevents counters without preventing movement), creating new tactical patterns. The underwater cave discovery ties into P6 content. |
| 7 | **Pack Rally** | The ultimate social easter egg. A move that turns combat into a coordinated team effort. The discovery (watching different species fight together) is a beautiful moment of emergent gameplay. The later-stage payoff (tribe war cry, civ combined arms) makes the creature stage social investment pay off across all stages. |
| 8 | **Mimicry Clone** | Pure game design mischief. The idea of wearing another species' face and walking into enemy territory is a laugh-out-loud concept. It creates entirely new gameplay dimensions (infiltration, social manipulation) that no other move offers. The risk of being exposed after 60 seconds adds tension. |

### Top 3 for the MVP Island

The MVP island (the initial biome set from W2: meadow valley, forest, savanna/desert, alpine, coast) constrains which easter eggs can be included at launch. P4 only includes meadow and forest; P6 adds coast/underwater; P8 adds alpine/volcano.

| MVP Easter Egg | Biome | Phase | Why MVP |
|---|---|---|---|
| **Bone Spines** (already designed) | Meadow (Espinodo) | P4 | The first recipe. Grounded in the core loop. |
| **Rock Armour (Lithoskin)** | Coast (Lithodon) | P4–P6 | Coastal rocks are everywhere. The Lithodon is easy to design, easy to find, and the "eating rocks" gag is universally funny. |
| **Pack Rally** | Meadow + Forest (Rondo + Zanco) | P4 | Uses existing species (Rondo and Zanco are already in the valley). No new species needed for discovery — the hint comes from their existing social interactions. |

**Why these three?**
- **Bone Spines** is the tutorial recipe — it teaches the entire system (parts, diet, meter, observation).
- **Rock Armour** introduces the coastal biome and the concept of defensive recipes. It's discoverable early (coast is adjacent to the meadow).
- **Pack Rally** rewards the social loop without requiring any new species. It's the easter egg that makes the player feel like a genius for figuring it out ("wait, if I use the trumpet on the Zanco...").

---

## Notes

- All recipes are original. No content is copied from Spore or any other game beyond genre conventions (secret moves, hidden species, fossils as clues).
- Every recipe follows G50: at least 2 parts + 1 diet condition + 1 resource meter.
- Every recipe goes through the same counter matrix (G53). Balance data is initial — the tourney gates decide.
- Discovery always follows G51: hinted by wild species that already use the move, fossils, and carcasses. At least 2 clue sources per recipe.
- Later-stage payoffs follow G28: creature-stage habits become tribe/civ traits.
- The Panspermia Survivor is the only recipe that meaningfully affects the space stage (G34, G67). Its space payoff is unique and narrative-driving.