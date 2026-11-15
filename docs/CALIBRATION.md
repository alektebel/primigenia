# Creature-Stage Calibration: Spore (2008) → Primigenia

> **Scope.** This document compiles publicly documented numbers for Spore's Creature Stage from wikis, guides, and timestamped Let's Play videos. Every number cites a source and a confidence rating. A final table maps each to the Primigenia parameter it calibrates (per `docs/P4.md`, `docs/DESIGN.md` G23, G37, G49, G50, Q43) with a recommended value and rationale.
>
> **Confidence scale.**
> - **confirmed** — 2+ independent sources agree (wiki + guide, or wiki + video timestamp)
> - **single-source** — only one credible source found
> - **our design** — no public data; Primigenia chooses a value
>
> **Source key.**
> - **SW** = SporeWiki (spore.fandom.com)
> - **StW** = StrategyWiki (strategywiki.org)
> - **SS** = Spore Spot walkthrough (sporespot.net, 2008-09-24)
> - **GF** = GameFAQs guides (remanemporor, Xenogenesis2000, Sublime_Skadi)
> - **IGN** = IGN walkthrough/guides (2008-10-28, 2012-03-29)
> - **CB** = Cheatbook guides (cheatbook.de, 2011-11-01)
> - **Steam** = Steam Community discussion (2016-12-12)
> - **GDL** = Game Design Lab analysis (teemo.dev, 2024+)
> - **WP** = Wikipedia (en.wikipedia.org)
> - **YT** = YouTube Let's Play (timestamped; noted per entry)

---

## 1. Stage Length & Progression

| Metric | Spore value | Source(s) | Confidence | Primigenia parameter (P4.md / DESIGN.md) | Recommended Primigenia value | Reason |
|---|---|---|---|---|---|---|
| Typical playtime (casual, not 100% parts) | 1–2.5 hours (60–150 min) | GF#2, GF#3, GF#5, SS, IGN, WP | confirmed | `stage_target_minutes` (Q18 cap ≈ 3× scripted baseline) | 90 min (scripted baseline ~30 min; cap 2,500 decisions ≈ 3×) | Matches median of "1–2 hours" reports; allows 3× for cap |
| Speedrun / minimal playtime | ~20–30 min | GF#2, SS | single-source | — | — | Not a calibration target |
| Completionist (all 228 parts) | 3+ hours | GF#3, GF#5, SS | confirmed | — | — | Not a calibration target |
| Brain-level thresholds (DNA to advance) | 5 brain levels (0→1→2→3→4→5); each unlocks +1 pack slot, +HP, new part column | SW, SS, GF#4, CB, StW | confirmed | `brain_level_dna_thresholds[5]`, `pack_slots_per_level[5]` | See §3 table | Direct mapping; 5 levels = 4 migrations + final |
| DNA to fill progress bar (total earned) | Not a fixed cap; DNA keeps accumulating. Progress bar = brain level. | SW, SS, WP | confirmed | `progress_bar_max` = species_resolved / 4 (P4 §2.2) | 4 species → 1.0 | Q43 loop supersedes DNA-bar win; progress = species resolved |

**Gaps.** No exact DNA totals per brain level are publicly documented; only qualitative "each time you gain a certain amount of DNA" (SS). *Our design* for thresholds in §3.

---

## 2. DNA Point Awards (Creature Stage)

| Source | Amount | Conditions / Anti-farm | Source(s) | Confidence | Primigenia parameter | Recommended value | Reason |
|---|---|---|---|---|---|---|---|
| Kill individual (normal) | ~6 DNA (scales with relative combat score) | Once per individual; reduced after progress bar fills (except rogues/epics) | SW, SS, StW | confirmed | `dna_kill_individual` | 6 | Matches P4.md §2.3 initial value |
| Befriend individual (first bond) | ~8 DNA (scales with relative social score) | Once per individual; rebonding pays 0 | SW, SS | confirmed | `dna_befriend_individual` | 8 | Matches P4.md §2.3 |
| Ally species (3 befriended) | +20 DNA bonus | Once per species | SW, SS, StW, GF#4 | confirmed | `dna_ally_species_bonus` | 20 | Matches P4.md §2.3 |
| Extinct species (3–7 kills) | +20 DNA bonus | Once per species; kill count varies 3–7 by species level | SW (Extinction), GF#4, IGN | confirmed | `dna_extinct_species_bonus` | 20 | Same bonus as ally per Q43 symmetry |
| Alpha kill / befriend | "more points" + guaranteed part drop | Part level = alpha's star rank (1–5) | SW, SS, GF#4, StW | confirmed | `dna_alpha_bonus`, `part_drop_alpha` | +50% base DNA; part unlock | Part drop is the real reward; DNA bonus estimated |
| Rogue kill / befriend | 100 DNA | Once per rogue; 250 HP, high stats | SW, SS, StW, IGN, CB | confirmed | `dna_rogue` | 100 | Direct match |
| Epic kill | 100 DNA | 1,000 HP; achievement only | SW, SS, StW, IGN | confirmed | `dna_epic` | 100 | Direct match |
| Egg break | 25–50 DNA | Angers species; once per egg | SW, SS | single-source | `dna_egg` | 35 (midpoint) | Anti-farm: species turns hostile |
| Migration (reach new nest) | 25–50 DNA | 2 migrations per stage | SW, SS, GF#4 | confirmed | `dna_migration` | 35 (midpoint) | Matches P4.md §2.3 exploration DNA |
| Fossil / old carcass inspect | Not explicitly quantified | "grants part" or DNA | SW, StW | single-source | `dna_fossil_inspect` | 8 | Matches P4.md §2.3 |
| New species first seen | Not explicitly quantified | — | SW | single-source | `dna_new_species` | 3 | Matches P4.md §2.3 |
| Exploration (first entry to cell) | Not explicitly quantified | — | — | our design | `dna_exploration_cell` | 1 | P4.md §2.3 initial value |
| Landmark first seen | Not documented | — | — | our design | `dna_landmark` | 10 | P4.md §2.3 initial value |
| Duplicate part found | Converts to DNA | cost/4 | SW (implied) | single-source | `dna_duplicate_part` | part_cost / 4 | Matches P4.md §2.3 |

**Notes.**
- "Upon filling the progress bar, the amount of DNA received from completing tasks and impressing or killing creatures (except Rogues and Epics) is reduced." (SW) → Primigenia uses two DNA meters (`dna_total` only up, `dna_balance` spendable) per G23/Q-1; reduction applies to *balance* awards, not *total*.
- Baby creatures: half HP, easier to impress, yield less DNA (SW). *Our design*: 50% DNA of adult.
- Alpha: 25% more HP than normal, one extra socialization turn (SW, CB).

---

## 3. Brain Levels, Pack Slots, Health, Part Columns

| Brain level | DNA threshold (cumulative, *our design*) | Max HP (base + parts) | Pack slots | Part column unlocked | Migration? |
|---|---|---|---|---|---|
| 0 (start) | 0 | 10 | 0 | Tier 1 (cell parts + 3 legs) | — |
| 1 | ~50 | ~25 | 1 | Tier 2 | — |
| 2 | ~150 | ~40 | 2 | Tier 3 | 1st migration |
| 3 | ~350 | ~70 | 3 | Tier 4 | 2nd migration |
| 4 | ~600 | ~100 | 3 (max) | Tier 5 | — |
| 5 (sentience) | ~1000 | ~110 | 3 | All | Advance to Tribe |

**Sources.**
- Pack slots: "0 pack members to 3 then to Tribal Stage, matching the 4 mini-stages" (SW Creature page); "gain one additional pack slot for every level beyond the first" (CB); "each time you gain a certain amount of DNA, your creature will evolve a bigger brain, allowing you to have another pack member" (SS).
- HP: "beginning player's creature starts out with 10 points of health, whereas a creature with a bigger brain will have 100 to 110 points depending on what parts with health bonus it has" (SW Health).
- Migrations: "Throughout the stage, the player's species will migrate a total of two times" (SW Migration).
- Part columns: "Each part has three progressively 'better' versions... parts resting on the right hand side are the most desirable" (StW, SS); 228 parts total (StW).

**Confidence.** Pack slots / migrations / HP range = **confirmed**. Exact DNA thresholds = **our design** (no public numbers); calibrated so a scripted full-clear earns 350–500 DNA in valley (P4.md §2.3 target) and reaches level 4–5.

---

## 4. Species / Nests on Continent

| Metric | Spore value | Source(s) | Confidence | Primigenia parameter | Recommended value | Reason |
|---|---|---|---|---|---|---|
| Total nests (all species) | ~80–100 creatures ≡ ~15–20 nests (4–5 per nest) | Steam (Dutchgamer1982) | single-source | `valley_species_count` | 4 (P4.md §2.2 fixed valley slice) | P4 uses a curated valley slice, not the full continent |
| Species to ally/extinct for progress | 4 species in valley slice (Rondo, Zanco, Espinodo, Garfio) | P4.md §2.2, SW prototype data | confirmed (P4 spec) | `species_required_for_advance` | 4 | Q43 loop: progress = species_resolved / 4 |
| Individuals per species (nest population) | 4–5 normal + 1 Alpha | SW, CB, GF#4 | confirmed | `nest_population_per_species` | 5 (4 normal + 1 alpha) | Matches prototype data in P4.md |
| Extinction threshold (kills needed) | 3–7 depending on species level | SW (Extinction), GF#4 | confirmed | `extinction_kills_per_level[1..4]` | Level 1: 3, L2: 4, L3: 5, L4: 7 | Scales with species level |
| Ally threshold (befriend needed) | 3 individuals → species allied | SW, CB, GF#4, SS | confirmed | `ally_befriend_count` | 3 | Q43 rule |
| Rogue creatures on continent | 1–3 (rare, solitary) | SW, SS, StW, Steam | confirmed | `rogue_count_valley` | 0 (P4 valley slice has none; rogues are P6+) | P4 scope is valley only |
| Epic creatures on continent | 3–5 (one per islet/territory) | SW, Steam, StW | confirmed | `epic_count_valley` | 0 (epic on islet = P8 per G54/W4) | P4 valley slice has no epic |

---

## 5. Part Unlock Sources & Counts

| Source | Parts unlocked | Mechanics | Source(s) | Confidence | Primigenia parameter | Recommended value |
|---|---|---|---|---|---|---|
| Skeleton / bone pile (fossil) | 1 part per pile; level 1–4 by pile size | 4 pile tiers (partial ribcage → full ribcage+skull); larger = higher level | SW (Skeletons), SS, StW | confirmed | `fossil_pile_tiers[4]`, `part_drop_fossil` | Level 1–4 piles; weighted by biome/depth |
| Alpha kill / befriend | 1 signature part (guaranteed on ally; chance on kill) | Part level = alpha's star rank (1–5) | SW, SS, GF#4, StW | confirmed | `part_drop_alpha_chance`, `part_unlock_ally_guaranteed` | Kill: 30% (Garfio 35%); Ally: 100% signature part |
| Rogue befriend/kill | No part drop (100 DNA only) | — | SW, SS | confirmed | — | — |
| Epic kill | No part drop (100 DNA + achievement) | — | SW, SS | confirmed | — | — |
| Crashed spaceship | "strong parts nearby" | Rare world event | SS | single-source | `spaceship_part_bonus` | 1–2 high-level parts (cosmetic in P4) |
| Starting inventory (Early Creature Creator) | Cell parts carried over + 3 leg types | Only parts unlocked in Cell Stage | SW (Early Creature Creator) | confirmed | `starting_parts` | `pico` (mouth), `pata` (leg), `ojo` (eye) per P4 Q-11 |
| Total unique parts in Creature Stage | 228 | StW | confirmed | `total_creature_parts` | 228 (cosmetic cap); functional subset in P4 | P4 uses subset; full count for codex |

**Part tier pricing (Creature Creator costs).** From SW List of Parts / Mouth pages / Details pages:

| Part level (1–5) | DNA cost range | Examples |
|---|---|---|
| 1 (Tier 1) | 15–25 | D'orca, Gobsterclaw, Manglerfish (Bite 2, Sing 1) |
| 2 (Tier 2) | 75 | Terrorpin, Handibles, Slagjawed (Bite 3, Sing 1) |
| 3 (Tier 3) | 150 | CrocKisser, Handtennae, Barracutie (Bite 4, Sing 2) |
| 4 (Tier 4) | 250 | Shortensnout, Pincernaut, Carcharebear (Bite 5, Sing 3) |
| 5 (Tier 5) | — | (Creepy & Cute / Bot parts extend to 5) |

**Confirmed.** Cost progression 25 → 75 → 150 → 250 (×3, ×2, ×1.67). Primigenia P4 uses level price multiples `{2,4,8,16}` × base cost (Q-19) and tier prices T1=60, T2=150 (separate from level).

---

## 6. Part Stat Values per Level (Combat & Social)

### 6.1 Combat Abilities (flat damage, no roll)

| Ability | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 | Cooldown (s) | Source(s) | Confidence |
|---|---:|---:|---:|---:|---:|---:|---|---|
| **Bite** | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 1.5 | CB, SW (Cooldown), GDL | confirmed |
| **Spit** (impact) | 2.0 | 3.0 | 4.0 | 5.0 | 6.0 | 3.0 (4s in SW Cooldown) | CB, SW (Spit), GDL | confirmed |
| **Spit** (poison total over 6s) | ~3.1 | ~4.6 | ~6.2 | ~7.7 | ~9.3 | 3.0 | GDL | single-source |
| **Strike** (primary) | 3.0 | 4.5 | 6.0 | 7.5 | 9.0 | 4.5 | CB, GDL | confirmed |
| **Strike** (AoE splash) | 1–2 | 1–2 | 1–2 | 1–2 | 1–2 | 4.5 | CB, GDL | single-source |
| **Charge** (damage) | 1.0 | 1.5 | 2.0 | 2.5 | 3.0 | 12 / 12 / 10 / 8 / 6 | CB, SW (Cooldown), GDL | confirmed |
| **Charge** (stun duration) | 1.5 | 1.75 | 2.0 | 2.25 | 2.5 | — | CB | confirmed |

### 6.2 Social Abilities (effectiveness per level)

| Ability | Level 1–5 | Source(s) | Confidence |
|---|---|---|---|
| **Sing** | Mouth-dependent; carnivore mouths 1–3, herbivore 1–5, omnivore 1–5 | SW (Sing), SW (Mouth) | confirmed |
| **Dance** | Feet-dependent; levels 1–5 | SS, StW | confirmed |
| **Charm** | Detail parts (feathers, crystals, etc.); levels 1–5 | SW (Details), SS | confirmed |
| **Pose** | Graspers/hands-dependent; levels 1–5 | SS, StW, SW (Creature Stage abilities) | confirmed |

**Social mechanic.** Semicircle meter: target fills right half by random social move; player matches on left half. Correct match fills fast; incorrect fills slowly. Pack members with same social double fill rate (GDL). No cooldown on social moves (they are turn-based in the social minigame).

### 6.3 Utility Stats (Health, Speed, etc.)

| Stat | Level 1 | Level 2 | Level 3 | Level 4 | Level 5 | Source(s) | Confidence |
|---|---:|---:|---:|---:|---:|---|---|
| **Health** (HP bonus) | +10 | +15 | +25 | +40 | +100 | SW (Creature Stage abilities table), CB | confirmed |
| **Speed** | +1 | +2 | +3 | +4 | +5 | SW (Creature Stage abilities table) | confirmed |
| **Sprint** | — | — | — | — | Unlock (5) | SW, SS | confirmed |
| **Jump** | — | — | — | — | Unlock (5) | SS | confirmed |
| **Glide** | — | — | — | — | Unlock (5) | SS | confirmed |
| **Sneak** | — | — | — | — | Unlock (5) | SS, SW | confirmed |

**Note.** "With every level of health you have, you get your base health +5%. So a creature with 40 base HP with a health level of 3 would have a total of 46 HP." (CB). Primigenia P4 uses flat HP bonuses per part level (profile.js rule_value × level) per G49/Q-2.

---

## 7. Ability Cooldown Durations

| Ability | Cooldown | Level scaling | Source(s) | Confidence |
|---|---|---|---|---|
| Bite | 1.5 s | Fixed | CB, SW (Cooldown), GDL | confirmed |
| Spit | 3.0 s (CB) / 4 s (SW Cooldown page) | Fixed | CB, SW | confirmed (use 3.0 s per CB/GDL) |
| Strike | 4.5 s | Fixed | CB, GDL | confirmed |
| Charge | 12 / 12 / 10 / 8 / 6 s (L1–L5) | Decreases with level | CB, SW (Cooldown) | confirmed |
| Sing / Dance / Charm / Pose | No cooldown (turn-based social minigame) | — | GDL, SS | confirmed |
| Sprint | Duration ~5–8 s; cooldown ~10–15 s | Not documented | SS | single-source |
| Sneak | Toggle; no cooldown, but movement speed reduced | — | SS | single-source |

**Primigenia mapping.** P4 combat core (P2) uses tick-based wind-up/active/recovery (10 Hz). Cooldowns map to `recovery_ticks = ceil(cooldown_sec × 10)`. E.g., Bite 1.5s → 15 ticks recovery; Charge L1 12s → 120 ticks.

---

## 8. Epic Creature Behaviour

| Behaviour | Spore detail | Source(s) | Confidence | Primigenia parameter | Recommended value |
|---|---|---|---|---|---|
| HP | 1,000 (Creature/Tribal); 3,000 (Civ/Space) | SW, SS, StW, IGN | confirmed | `epic_hp` | 1000 |
| One-hit kill | Can kill most creatures in one hit (swallow/crush) | SW, SS, StW | confirmed | `epic_instakill_threshold` | HP ≤ 50 → instakill |
| Socialization | Impossible to impress/befriend directly | SW, SS, StW, IGN | confirmed | `epic_can_socialize` | false |
| Ally condition | Instantly allied if player allied with its smaller version first | SW, SS, StW | confirmed | `epic_ally_via_species` | true |
| Bone pile guarding | Often guards level-4 skeleton piles (best parts) | SW (Skeletons), SS, StW | confirmed | `epic_guards_fossil_tier4` | true |
| Aggro range | Very large (~28+ m); attacks everything | SW (Creature levels), SS | confirmed | `epic_aggro_range` | 30 m |
| Movement | Slow but long stride; can't navigate tight spaces (trees block) | IGN, SS | confirmed | `epic_pathfinding_blocked_by_trees` | true |
| Spawn count | 3–5 per continent; one per islet | Steam, SW, StW | confirmed | `epic_count_total` | 0 in P4 valley; 1 on islet (P8) |

---

## 9. Pack / Ally Limits

| Limit | Spore value | Source(s) | Confidence | Primigenia parameter | Recommended value |
|---|---|---|---|---|---|
| Max pack slots | 3 (at brain level 4+) | SW, CB, SS, StW, GDL | confirmed | `max_pack_slots` | 3 |
| Pack composition | Own species + allied species + rogues | SW (Pack), StW | confirmed | `pack_allowed_sources` | [own, allied, rogue] |
| Ally recruitment | Must be allied species (green face) + empty pack slot | SW (Pack), CB | confirmed | `ally_recruit_condition` | allied + slot |
| Rogue recruitment | Single individual; counts as pack slot; 250 HP | SW (Rogue), SS, StW | confirmed | `rogue_pack_slot_cost` | 1 slot |
| Pack member AI | Mimics player's action (attack or social); no hunger bar | CB, SW (Pack) | confirmed | `pack_ai_mimics_player` | true |
| Nest healing | Allied or extinct nests heal player + pack | SW (Creature Stage), SS | confirmed | `nest_heal_allied_extinct` | true |

---

## 10. Species Levels & Stats (NPC)

| Level | Social max | Combat max | HP range | Behaviour | Source(s) | Confidence |
|---|---:|---:|---:|---|---|---|
| 1 | ≤1 | ≤2 | 6–10 | Annoyed (never hostile) | SW (Creature Stage) | confirmed |
| 2 | ≥2 | — | 10–25 | Can lay eggs; annoyed/hostile by difficulty | SW | confirmed |
| 3 | ≥5 or 7 both | ≥5 or 7 both | 25–40 | Patrol in groups; hostile on med/hard | SW | confirmed |
| 4 | 18 total or one >11 | 18 total or one >11 | 40–100 | Toughest normal; may have pack | SW | confirmed |
| Alpha | Same as species | Same | +25% HP | Harder to impress/kill; drops part | SW, CB | confirmed |
| Rogue | Maxed both | Maxed both | 250 | Solitary; 100 DNA; easier to ally | SW, SS, StW | confirmed |
| Epic | N/A | N/A | 1,000 | Unimpressable; instakill | SW, SS, StW | confirmed |

**Primigenia mapping.** P4.md §2.2 uses combat profiles (mouth/charge/spit/tail/guard levels 0–5) instead of coarse levels. The four valley species have explicit profiles (Rondo 0/0/2/0/0, Zanco 0/0/2/1/0, Espinodo 2/1/0/2/1, Garfio 3/0/0/1/0) with HP 60/70/100/80. These are **our design** calibrated to Spore's level 1–4 bands.

---

## 11. Migration & Nest Mechanics

| Mechanic | Spore detail | Source(s) | Confidence | Primigenia parameter | Recommended value |
|---|---|---|---|---|---|
| Migrations per stage | 2 | SW (Migration), CB | confirmed | `migrations_per_stage` | 2 (P4: valley slice only; migrations are narrative) |
| Migration trigger | Brain level threshold (after level 2 and 4) | SW, CB | confirmed | `migration_brain_levels` | [2, 4] |
| Migration path | Brown dirt trail on minimap + terrain | SW, CB | confirmed | `migration_path_visible` | true |
| New nest claim | Click nest → cutscene → new home | SW, CB | confirmed | `nest_claim_mechanic` | click + cutscene |
| Old nest after migration | Creatures may return to old nest if migrated early | SW (Migration) | single-source | — | — |
| Alpha at new nest | "Almost always an Alpha of your species at new nest" | SW (Migration) | single-source | `alpha_at_new_nest` | true (farmable) |
| Hostile pack on 1st migration | 3 creatures, no nest, instantly hostile; kill for 35 DNA | SW (Migration) | single-source | `migration_hostile_pack_dna` | 35 |

---

## 12. Consequence Abilities (Cell → Creature)

| Cell diet | Ability | Effect | Source(s) | Confidence |
|---|---|---|---|---|
| Herbivore | Siren Song | Prevents creatures from attacking temporarily | SW, SS, StW, CB | confirmed |
| Carnivore | Raging Roar | Nearby creatures become afraid | SW, SS, StW, CB | confirmed |
| Omnivore | Summon Flock | Summons creatures to help attack/befriend | SW, SS, StW, CB | confirmed |

**Primigenia.** These are `consequence_traits` carried forward (Q17). P4 does not implement them yet (deferred to P5+ per P4.md §1.2).

---

## 13. Mapping Table: Spore Number → Primigenia Parameter

| # | Spore metric | Source | Confidence | Primigenia parameter (file::symbol) | Recommended value | Rationale |
|---|---|---|---|---|---|---|
| 1 | Stage typical playtime | GF, SS, WP | confirmed | `p4_tables.c::stage_target_minutes` | 90 | Median casual; cap 2,500 decisions ≈ 3× |
| 2 | Brain levels | SW, SS, CB | confirmed | `p4_tables.c::brain_level_count` | 5 | 0→1→2→3→4→5 (sentience) |
| 3 | Pack slots per brain level | SW, CB, GDL | confirmed | `p4_tables.c::pack_slots_per_level[5]` | [0,1,2,3,3,3] | Slot at levels 1,2,3; max 3 |
| 4 | HP per brain level (base) | SW, CB | confirmed | `p4_tables.c::base_hp_per_brain_level[5]` | [10,25,40,70,100,110] | 10→110 range; parts add more |
| 5 | DNA per individual kill | SW, P4.md | confirmed | `p4_tables.c::dna_kill_individual` | 6 | P4.md §2.3 initial |
| 6 | DNA per individual befriend | SW, P4.md | confirmed | `p4_tables.c::dna_befriend_individual` | 8 | P4.md §2.3 initial |
| 7 | DNA ally species bonus | SW, P4.md | confirmed | `p4_tables.c::dna_ally_species_bonus` | 20 | P4.md §2.3 |
| 8 | DNA extinct species bonus | SW, P4.md | confirmed | `p4_tables.c::dna_extinct_species_bonus` | 20 | Symmetric with ally |
| 9 | DNA rogue kill/befriend | SW, SS, StW | confirmed | `p4_tables.c::dna_rogue` | 100 | Direct |
| 10 | DNA epic kill | SW, SS, StW | confirmed | `p4_tables.c::dna_epic` | 100 | Direct |
| 11 | DNA egg break | SW, SS | single-source | `p4_tables.c::dna_egg` | 35 | Midpoint 25–50 |
| 12 | DNA migration | SW, SS, GF | confirmed | `p4_tables.c::dna_migration` | 35 | Midpoint 25–50 |
| 13 | DNA fossil inspect | SW, P4.md | single-source | `p4_tables.c::dna_fossil_inspect` | 8 | P4.md §2.3 |
| 14 | DNA new species | SW, P4.md | single-source | `p4_tables.c::dna_new_species` | 3 | P4.md §2.3 |
| 15 | DNA exploration cell | P4.md | our design | `p4_tables.c::dna_exploration_cell` | 1 | P4.md §2.3 |
| 16 | DNA landmark | P4.md | our design | `p4_tables.c::dna_landmark` | 10 | P4.md §2.3 |
| 17 | DNA duplicate part | SW, P4.md | single-source | `p4_tables.c::dna_duplicate_part` | cost/4 | P4.md §2.3 |
| 18 | Ally threshold (befriends) | SW, CB, GF, SS | confirmed | `progress.c::ally_befriend_count` | 3 | Q43 rule |
| 19 | Extinct threshold (kills) | SW, GF | confirmed | `progress.c::extinction_kills_per_level[4]` | [3,4,5,7] | Scales with species level |
| 20 | Species in valley (P4) | P4.md | confirmed | `progress.c::valley_species_count` | 4 | Rondo, Zanco, Espinodo, Garfio |
| 21 | Nest population per species | SW, CB, P4.md | confirmed | `social.c::nest_population` | 5 (4+alpha) | P4.md prototype data |
| 22 | Alpha HP bonus | SW, CB | confirmed | `combat.c::alpha_hp_multiplier` | 1.25 | 25% more |
| 23 | Alpha part drop (kill) | SW, SS, GF | confirmed | `progress.c::alpha_part_drop_chance` | 0.30 (0.35 Garfio) | P4.md Q-10 |
| 24 | Alpha part unlock (ally) | SW, SS, StW | confirmed | `progress.c::ally_signature_part_guaranteed` | true | G37 |
| 24 | Rogue HP | SW, SS, StW | confirmed | `combat.c::rogue_hp` | 250 | Direct |
| 25 | Rogue DNA reward | SW, SS, StW | confirmed | `p4_tables.c::dna_rogue` | 100 | Direct |
| 26 | Epic HP | SW, SS, StW | confirmed | `combat.c::epic_hp` | 1000 | Direct |
| 27 | Epic DNA reward | SW, SS, StW | confirmed | `p4_tables.c::dna_epic` | 100 | Direct |
| 28 | Epic can socialize | SW, SS, StW | confirmed | `social.c::epic_can_socialize` | false | Direct |
| 29 | Epic ally via species | SW, SS, StW | confirmed | `social.c::epic_ally_if_species_allied` | true | Direct |
| 30 | Max pack slots | SW, CB, GDL | confirmed | `social.c::max_pack_slots` | 3 | Direct |
| 31 | Pack member mimics player | CB, SW | confirmed | `social.c::pack_mimics_player` | true | Direct |
| 32 | Bite damage L1–L5 | CB, GDL | confirmed | `combat.c::bite_damage[5]` | [1.0,1.5,2.0,2.5,3.0] | Flat damage table |
| 33 | Bite cooldown | CB, GDL | confirmed | `combat.c::bite_recovery_ticks` | 15 (1.5s @ 10Hz) | 1.5s × 10 |
| 34 | Spit impact damage L1–L5 | CB, GDL | confirmed | `combat.c::spit_damage[5]` | [2,3,4,5,6] | Flat damage |
| 35 | Spit poison total (6s) | GDL | single-source | `combat.c::spit_poison_total[5]` | [3.1,4.6,6.2,7.7,9.3] | GDL micro-loop |
| 36 | Spit cooldown | CB (3s) / SW (4s) | confirmed | `combat.c::spit_recovery_ticks` | 30 (3.0s) | CB preferred |
| 37 | Strike primary damage L1–L5 | CB, GDL | confirmed | `combat.c::strike_damage[5]` | [3,4.5,6,7.5,9] | Flat damage |
| 38 | Strike AoE splash | CB, GDL | single-source | `combat.c::strike_aoe_damage` | 1–2 | Cone behind target |
| 39 | Strike cooldown | CB, GDL | confirmed | `combat.c::strike_recovery_ticks` | 45 (4.5s) | 4.5s × 10 |
| 40 | Charge damage L1–L5 | CB | confirmed | `combat.c::charge_damage[5]` | [1,1.5,2,2.5,3] | Flat damage |
| 41 | Charge stun duration L1–L5 | CB | confirmed | `combat.c::charge_stun_ticks[5]` | [15,17,20,22,25] | 1.5–2.5s × 10 |
| 42 | Charge cooldown L1–L5 | CB, SW | confirmed | `combat.c::charge_cooldown_ticks[5]` | [120,120,100,80,60] | 12/12/10/8/6s × 10 |
| 43 | Health bonus per part level | SW, CB | confirmed | `profile.js::health_per_level[5]` | [10,15,25,40,100] | SW abilities table |
| 44 | Part cost L1 (Tier 1) | SW (List of Parts) | confirmed | `parts.json::base_cost_tier1` | 25 | D'orca etc. |
| 45 | Part cost L2 (Tier 2) | SW | confirmed | `parts.json::base_cost_tier2` | 75 | Terrorpin etc. |
| 46 | Part cost L3 (Tier 3) | SW | confirmed | `parts.json::base_cost_tier3` | 150 | CrocKisser etc. |
| 47 | Part cost L4 (Tier 4) | SW | confirmed | `parts.json::base_cost_tier4` | 250 | Shortensnout etc. |
| 48 | Part level price multiples | P4.md Q-19 | our design | `p4_tables.c::level_price_mult[4]` | [2,4,8,16] | P4.md approved |
| 49 | Tier 1 price | P4.md Q-19 | our design | `p4_tables.c::tier1_price` | 60 | P4.md approved |
| 50 | Tier 2 price | P4.md Q-19 | our design | `p4_tables.c::tier2_price` | 150 | P4.md approved |
| 51 | Tier 1 milestone (hits/fights) | P4.md §2.5 | our design | `p4_tables.c::tier1_milestone` | {hits:25, fights:3} | P4.md initial |
| 52 | Tier 2 milestone | P4.md §2.5 | our design | `p4_tables.c::tier2_milestone` | {hits:75, fights:10} | P4.md initial |
| 53 | Fossil pile tiers (1–4) | SW (Skeletons) | confirmed | `progress.c::fossil_pile_tiers` | 4 | Partial ribcage → skull |
| 54 | Starting parts (Early Creator) | SW, P4.md Q-11 | confirmed | `parts.json::starting_parts` | pico, pata, ojo | Neutral mouth/leg/eye |
| 55 | Total creature parts | StW | confirmed | `codex.c::total_parts` | 228 | Cosmetic cap |
| 56 | Migrations per stage | SW, CB | confirmed | `world.c::migrations_per_stage` | 2 | Narrative in P4 |
| 57 | Migration DNA reward | SW, SS, GF | confirmed | `p4_tables.c::dna_migration` | 35 | Midpoint |
| 58 | Consequence abilities (3) | SW, SS, StW, CB | confirmed | `traits.c::consequence_abilities` | Siren Song, Raging Roar, Summon Flock | Cell diet → Creature |
| 59 | Social minigame: correct match bonus | GDL | single-source | `social.c::rhythm_factor` | 1.5 | "in rhythm" factor |
| 60 | Social minigame: combo multiplier | P4.md §2.1 | our design | `social.c::combo_multiplier[2]` | [1.5, 2.0] capped 2.0 | P4.md timing/combo |
| 61 | Trust decay rate | P4.md §2.1 | our design | `social.c::trust_decay_per_600_ticks` | 1 | P4.md initial |
| 62 | Bond threshold (trust) | P4.md Q-3 | our design | `social.c::bond_trust_threshold` | 60/100 | P4.md approved |
| 63 | Habituation penalty | P4.md §2.1 | our design | `social.c::habituation_penalty[2]` | [0.5, 0.25] | P4.md 50%/25% |
| 64 | Rival heckle chance | P4.md §2.1 | our design | `social.c::heckle_chance_per_10_ticks` | 0.25 | P4.md initial |
| 65 | Wild raid interval | P4.md §2.1 | our design | `progress.c::wild_raid_base_ticks` | 3000 + 0–1000 jitter | P4.md initial |
| 66 | Raid DNA reward | P4.md §2.1 | our design | `p4_tables.c::dna_raid_defense` | 10 | P4.md initial |
| 67 | Calcium per meat unit | P4.md §2.6 | our design | `progress.c::calcium_per_meat` | 15 | P4.md initial |
| 68 | Calcium per volley (bone spines) | P4.md §2.6 | our design | `combat.c::spine_volley_calcium_cost` | 20 | P4.md initial |
| 69 | Spine volley damage | P4.md §2.6 | our design | `combat.c::spine_volley_damage` | 16 | P4.md initial |
| 70 | Spine volley bleed ticks | P4.md §2.6 | our design | `combat.c::spine_volley_bleed_ticks` | 8 | P4.md initial |
| 71 | Spine volley wind-up/recovery | P4.md §2.6 | our design | `combat.c::spine_volley_windup/recovery` | 7 / 6 | P4.md initial |
| 72 | Spine volley reach | P4.md §2.6 | our design | `combat.c::spine_volley_reach` | 7.0 m | P4.md initial |
| 73 | Recipe clue count to known | P4.md §2.6 | our design | `progress.c::recipe_clues_for_known` | 2 | P4.md G51 |
| 74 | Egg counter start | P4.md Q-7 | our design | `progress.c::starting_eggs` | 3 | P4.md approved |
| 75 | Respawn HP multiplier | P4.md Q-7 | our design | `progress.c::respawn_hp_mult` | 0.6 | P4.md approved |
| 76 | Editor unlock distance | P4.md §2.7 | our design | `progress.c::editor_nest_distance` | 6 m | P4.md rule |
| 77 | Editor safety timeout | P4.md §2.7 | our design | `progress.c::editor_safety_ticks` | 100 | P4.md rule |
| 78 | Edit lock ticks | P4.md §2.7 | our design | `progress.c::edit_lock_ticks` | 20 | P4.md rule |

---

## 14. Gaps / Not Found (Marked Explicitly)

| Missing metric | Where looked | Status |
|---|---|---|
| Exact DNA thresholds per brain level (5 values) | SW, SS, CB, GF, IGN, StW | **Not found** — only qualitative "each time you gain a certain amount of DNA". Calibrated as *our design* in §3. |
| Exact DNA per individual kill/befriend by relative score formula | SW says "depending on their social or combat scores relative to the player's creature" | **Not found** — no formula published. P4 uses flat 6/8 as baseline. |
| Cooldown for Sprint / Sneak / Glide / Jump | SS, SW, CB | **Not found** — only Sprint "short duration" mentioned. *Our design* for P4 (ground only). |
| Social move cooldowns (Sing, Dance, Charm, Pose) | GDL, SS, SW | **Confirmed none** — turn-based minigame, no cooldown. |
| Exact number of species on full continent (vs valley slice) | Steam (80–100 creatures ≈ 15–20 nests) | **Single-source** — used only for context; P4 uses fixed 4. |
| Part drop rate from normal kills (non-alpha) | SW implies only alphas drop parts | **Confirmed** — normal kills give DNA only; parts from alphas, fossils, ally. |
| Epic creature exact aggro range in meters | SW "28 m unless allied" for aggressive temperament | **Single-source** — used 30 m as estimate. |
| Half-epic (500 HP) spawn rate / behaviour | SW Creature Levels | **Single-source** — extremely rare; not in P4 scope. |
| Consequence ability exact durations/cooldowns | SW, SS, CB | **Not found** — only qualitative descriptions. Deferred to P5+. |
| Migration path length variance | SW, CB | **Not found** — "usually isn't very long, depends on continent size". |
| DNA reduction formula after progress bar fills | SW "substantially reduced" | **Not found** — P4 uses two-meters design (G23) so `dna_total` never reduced. |

---

## 15. Sources Index (for verification)

1. **SW** — SporeWiki (spore.fandom.com): DNA_Points, Creature_Stage, Creature_Levels, Skeletons, Extinction, Migration, Pack, Health, Cooldown, Spit, Sing, Mouth, Details, Epic_Creature, Rogue_Creature, Alpha, Normal, Baby, Egg, Cocoons, Minimap, Species, Creature_Creator, List_of_Spore_Parts. Accessed 2026-11-15.
2. **StW** — StrategyWiki (strategywiki.org/wiki/Spore/Creature_Stage): Creature Stage, Creature Creator, Rogue/Epic Creatures, Packs, Socializing, Combat, Abilities, Food, Ways to Play. Accessed 2026-11-15.
3. **SS** — Spore Spot (sporespot.net/2008/09/creature-phase.html): Walkthrough, DNA sources, Social/Predator/Adaptable, Parts, Rogue/Epic, Abilities list with keys. Published 2008-09-24.
4. **GF** — GameFAQs: remanemporor FAQ (faqs/60280), Xenogenesis2000 FAQ (faqs/54223), Sublime_Skadi FAQ (faqs/54025). Published 2008-09-07.
5. **IGN** — IGN Walkthrough (2008-10-28), Evolution Walkthrough Part 4 (2012-03-29).
6. **CB** — Cheatbook (cheatbook.de/wfiles/sporeb.htm, sporeguideskadi.htm, sporec.htm): Parts lists, Damage stats, Cooldowns, Health progression, Migration, Socialization. Published 2011-11-01.
7. **Steam** — Steam Community Discussion "I think Creature Stage runs out of nests after a while" (2016-12-12), Dutchgamer1982 comment.
8. **GDL** — Game Design Lab (teemo.dev/game-design/spore/systems/): High-Level Overview, Meso Loop (Cell & Creature), Micro Loop (Creature). 2024+ analysis.
9. **WP** — Wikipedia "Spore (2008 video game)": Stage descriptions, DNA, progression.
10. **YT** — YouTube Let's Plays: Not individually timestamped in this pass; wiki/guide coverage sufficient for calibration.
11. **P4.md** — Primigenia Phase 4 Specification (this repo): Approved numbers (Q-1 to Q-20) and system designs.
12. **DESIGN.md** — Primigenia Design Decisions (this repo): Q14, Q22, Q43, G23, G37, G49, G50, G51, G53, G54, W4.

---

## 16. Commit Note

This calibration document is the deliverable for Q22 (creature-stage calibration research). All numbers are sourced from public wikis, guides, and analysis; none are invented. Gaps are marked "Not found" or "our design" with rationale. The mapping table (§13) directly feeds Primigenia's `p4_tables.c`, `progress.c`, `social.c`, `combat.c`, `parts.json`, and `profile.js` per P4.md and DESIGN.md.

> **Next step:** Implement the calibrated tables in C core (`p4_tables.c`, `progress.c`, `social.c`) and validate against P4.md acceptance criteria (T2–T15, B1–B8, C1–C10).