# Creature-stage calibration: Spore (2008) → Primigenia

> **Purpose (DESIGN.md Q14, Q22).** The game is not bought. This document
> compiles what public sources say about how Spore's Creature Stage plays, so
> Primigenia's numbers are calibrated against something real. Every number below
> names its source URL and a confidence. §10 maps each finding to the Primigenia
> parameter it calibrates (P4.md, G23, G37, Q43) with a recommended value and the
> reason. §11 lists what could not be found; nothing there is invented.

## 0. Method, confidence and access notes

**Confidence scale** (Q14): *confirmed* = two or more independent sources agree;
*single-source* = one credible source; *derived* = arithmetic over cited numbers
(shown); *our design* = no public number exists and Primigenia chooses one;
*conflict* = sources disagree, both values are given.

**How the sources were read (2026-11-15).** Recorded because several sites block
automated fetches, and a citation is only honest if the access path is stated:

| Site | HTML page | What worked |
|---|---|---|
| spore.fandom.com | **403** | `api.php?action=parse&prop=wikitext` returns 200; all wiki text below is the raw article wikitext. |
| strategywiki.org | **403** | `w/api.php?action=parse` returns 200. |
| en.wikipedia.org | 200 | Direct. |
| speeddemosarchive.com | 200 | Direct (written run comments). |
| gamefaqs.gamespot.com guide pages | 200 | Direct. |
| gamefaqs.gamespot.com **board** threads | **403** | Read only through search-result excerpts; quoted text and URLs are given, full thread not re-read. |
| ign.com/wikis | **403** | Read only through search-result excerpts. |
| steamcommunity.com | 200 | Direct. |
| youtube.com | 200 but no transcript in the fetched HTML | Timestamps below are from caption excerpts returned by web search. **The videos were not watched end to end**; each such row says so. |
| reddit.com | not fetched | One search-result excerpt, marked as such. |

Two consequences: (a) video timestamps are *reported*, not independently
verified frame by frame, and are marked single-source unless two videos agree;
(b) where a wiki page and a video disagree (Q14 says video wins), I say so but do
not pretend to have measured the game.

**Revision note (2026-11-15).** An earlier revision of this file carried numbers
that its cited pages do not contain: 6 DNA per kill and 8 per befriend attributed
to SporeWiki, a health-per-part-level table of +10/+15/+25/+40/+100, a charge stun
of 1.5–2.5 s, an epic aggro range of 28 m, and 15–20 nests attributed to a Steam
post. Those values are either from the reference prototype (`art/reference/`)
or invention. This revision was rebuilt from the fetched pages; every value that
could not be reproduced was removed or relabelled *our design*. The prototype's
numbers are cited as prototype numbers, never as Spore's.

---

## 1. Stage length

| Metric | Spore value | Source | Confidence |
|---|---|---|---|
| Creature stage, typical first playthrough | **~1–2 h**; self-reports: "creature phase over about 2 hours" (first species), "creature goes on for about an hour", "creature 2 hours" | GameFAQs board 45325852 and 45382090 (Aug–Sep 2008), read via search excerpts: <https://gamefaqs.gamespot.com/boards/926714-spore/45325852>, <https://gamefaqs.gamespot.com/boards/926714-spore/45382090> | confirmed (several independent players, same range) but **anecdotal** — forum posts, no measurement |
| Creature stage, completionist (all parts) | "2.5 hours (if you're getting all the body parts)" | GameFAQs 45382090, same | single-source |
| Creature stage, experienced player with allies | "you can end up blowing through it in half an hour" | GameFAQs 45325852, same | single-source |
| Creature stage, speedrun (individual level, Easy, 2018) | **10:58**; the written route says the stage fills the bar in "three nests and one additional alpha" per level and "two scripted events" | Speed Demos Archive, run comments: <https://speeddemosarchive.com/Spore.html> | single-source (timed run) |
| Creature stage, segment of a full-game speedrun | 1:26 → 5:11 in the chapter list, ≈ **3:45** | <https://www.youtube.com/watch?v=ot59JXaaopY> chapters (excerpt via search; not watched) | single-source |
| Whole game, first four stages | "will take up to 15 hours… but can take as little as one or two hours" | Wikipedia: <https://en.wikipedia.org/wiki/Spore_(2008_video_game)> | confirmed (encyclopedic, but unsourced on this line) |
| Whole game, all stages | main story 12 h 57 m (156 polls); completionist 106 h | HowLongToBeat: <https://howlongtobeat.com/game/8985> | confirmed (self-reported poll) |

**Notes.** There is **no official or measured figure for the creature stage**
anywhere I could reach; the 1–2 h band is convergent player testimony. Speedruns
(11 min) and completionist runs (2.5 h) bound the distribution. The stage has no
timer and the player advances when they choose (Wikipedia, above).

---

## 2. DNA points and progression thresholds

### 2.1 The progress bar

| Metric | Spore value | Source | Confidence |
|---|---|---|---|
| DNA to fill the creature progress bar | **1,000 DNA** | Two independent videos: "Creature Stage requires 1,000 DNA points to fill the Progress Bar" (<https://www.youtube.com/watch?v=tFE_gfM-sqA>, 2:13); "the Creature Stage Progress Bar completes after collecting only 1,000 DNA points" (<https://www.youtube.com/watch?v=taqyDGYgXz8>, 9:42–9:53). Excerpts via search; not watched. | confirmed (2 videos), but both are speedrun commentary, not official |
| Brain levels in the stage | **5 levels**, entered at level 1, advance at level 5 ("level up to level 5 and move onto tribal stage") | GameFAQs guide by Xenogenesis2000, updated 2008-09-27: <https://gamefaqs.gamespot.com/pc/926714-spore/faqs/54223> §3.4 and §3.5 | single-source (explicit); consistent with "4 Brains on the Timeline" (<https://www.youtube.com/watch?v=tFE_gfM-sqA>, 3:30) → 4 growth events |
| What a level gives | more max HP, a bigger body, one more pack slot, and the next part column | SporeWiki Creature Stage: <https://spore.fandom.com/wiki/Creature_Stage>; Creature Creator (Will Wright quote): <https://spore.fandom.com/wiki/Creature_Creator> | confirmed |
| DNA after the bar is full | awards from tasks/kills drop "substantially"; eggs are unaffected | SporeWiki DNA Points: <https://spore.fandom.com/wiki/DNA_Points>; Creature Stage (Strategy) | confirmed |
| Is there a hard DNA cap? | No: "there is no limit on the amount of DNA that can be earned as long as there are tasks" (Creature Stage; the Cell Stage does cap at 125) | SporeWiki DNA Points | single-source |
| Missions per level (speedrun route) | ~3 nests + 1 alpha per level-up, then a migration | SDA run comments (above) | single-source |

### 2.2 Awards

| Award | Amount | Conditions / anti-farm | Source | Confidence |
|---|---|---|---|---|
| Kill or impress an individual | **No fixed number published.** "a small DNA reward" that **scales with the victim's combat/social scores relative to yours**: tougher = more, weaker = less | once per individual; babies yield less; alphas yield more; all awards except rogues/epics are reduced once the bar is full | SporeWiki DNA Points; Creature Stage | confirmed (qualitative) |
| Resolve a species (alliance **or** extinction) | **20–40 DNA bonus**, scaling with the species' level and its starting relationship: ~20 at low level (observed: "I got 20 DNA points and we extincted them", <https://www.youtube.com/watch?v=xE7bIBJPhFs> 5:31); 25 neutral; 30 "orange angry"; 40 angry at higher level | once per species; the objective box shows the two rewards and you pick one | <https://www.youtube.com/watch?v=ctYcS1V1jC4> 8:07, 10:54, 15:45; <https://www.youtube.com/watch?v=xE7bIBJPhFs> 5:23–5:31 (excerpts via search; not watched) | confirmed as a range (3 videos); exact per-level formula not published |
| Rogue: kill or befriend | **100 DNA** | once per rogue; 250 HP; befriending takes a single socialization | SporeWiki DNA Points, Creature Stage, Rogue creature | confirmed (wiki + SDA + video: "worth a hundred points, 100 DNA", <https://www.youtube.com/watch?v=ESW2imoSllg> 8:19) |
| Epic: kill | **100 DNA** + "Epic Killer" achievement | once; 1,000 HP; no part drop | SporeWiki DNA Points, Epic creature; IGN part 4 ("usually 100 DNA points") | confirmed |
| Egg: eat/break | **25 DNA**, angering the species into hostility | once per egg; eggs keep being laid, so this is the one repeatable source after the bar is full | SporeWiki Egg: <https://spore.fandom.com/wiki/Egg> | single-source (25) / **conflict**: DNA Points says 25–50 |
| Migration: reach the new nest | **25–50 DNA**; the Nest page says it "will expand the nest size and award 50 DNA points" | twice per stage | SporeWiki DNA Points, Migration, Nest | confirmed that it pays; **conflict** on 25–50 vs 50 |
| Eating food (meat, fruit, carcasses) | **No DNA.** Food restores health and hunger only | — | SporeWiki DNA Points (complete source list); StrategyWiki Creature Stage ("Food") | confirmed (absence is explicit) |
| Finding a part (skeleton, alpha) | **No DNA.** The part is the reward | — | SporeWiki Skeletons, Alpha Creature | confirmed |
| Duplicate part | No duplicate case exists: if a skeleton's tier is exhausted it gives a part from a lower tier | — | SporeWiki Skeletons (Notes) | single-source |

**Progression arithmetic (derived, not invented).** 1,000 DNA over 4 level-ups
= 250 DNA per level. The SDA route resolves ~3 nests + 1 alpha per level. A
species resolution pays 20–40, so three resolutions cover only 60–120 of the
250; the remaining 130–190 must come from individual awards, eggs, migrations,
rogues and tasks, none of which publishes a per-action value. If all of it came
from ~9–12 kills (3–4 per nest), that would be 11–21 per kill; but eggs (25,
repeatable) and two migrations (25–50 each) are also inside the total, so the
split cannot be recovered. A video's "30 DNA for killing four creatures" is
equally consistent with a single 20–40 resolution bonus. **Conclusion: no
per-kill value is derivable from public numbers.** P4's 6 and 8 are chosen to be
small relative to a 20–40 resolution bonus, which is the only published
direction.

---

## 3. Species, nests and how many to resolve

| Metric | Spore value | Source | Confidence |
|---|---|---|---|
| Creatures on the continent | **80–100** | Steam post by Dutchgamer1982, 2016-12-12: <https://steamcommunity.com/app/17390/discussions/0/1843493219428946531> | single-source (player count) |
| of which epics | "always 3–5 epics" (plus "5–7 small epics", probably half-epics) | same Steam post; SporeWiki lists a 500 HP Half-Epic as "extremely rare" | single-source |
| of which rogues | "at least 3" | GameFAQs guide §3.4.7 | single-source; consistent with wiki "rare, solitary" |
| Everything else | "the rest of them will be nests" | Steam post | single-source |
| Nests on the map | **not published**; derived: (80–100 − 3–5 epics − 3+ rogues) ÷ nest size (3–7) ≈ **12–25 nests** | derived from the rows above | derived |
| Individuals per nest | **3–7**, equal to the extinction requirement (the mission counter is the nest population) | SporeWiki Extinction: "varies between 3 to 7 on how high the opposing species' level is"; SDA: "extinct the first nest by killing four creatures from it" | confirmed |
| Species visible from a small area | 6 in "a very small area of the map" | E3 Spore presentation, creature stage: <https://www.youtube.com/watch?v=DeMhBUsnswA> 4:51 (excerpt; not watched) | single-source (official demo) |
| Species in one played map | "currently I've found 80 species. All dead." | <https://www.reddit.com/r/Spore/comments/1eeqke7/how_many_creatures_are_in_the_creature_stage> (excerpt only) | single-source, contradicts the 80–100 *creatures* figure unless "species" was meant loosely — treat as unreliable |
| Ally a species | **befriend 3** individuals → friends at 2, allies at 3 | SporeWiki Creature Stage; GameFAQs guide §3.4.3; E3 demo: "befriend three creatures in order to become allies" (4:02–4:10) | confirmed (3 independent) |
| Make a species extinct | **kill 3–7**, by species level | SporeWiki Extinction; E3 demo says "kill off three" (4:02); SDA says 4 for the first nest; video says 4 for a 30 DNA bonus | confirmed range (3 at the low end, 3–7 by level) |
| Nests needed to finish the stage | ~12 resolutions (3 per level × 4 levels) out of ~12–25 on the map | derived from SDA route + counts above | derived |

**Notes.** Nests are the unit of progress, not species globally: each nest has
its own species, level and temperament, and the same species can appear in more
than one nest (SporeWiki Creature Stage; Steam post). Primigenia's P4 valley has
**4 species with one home range each**, which is a deliberate compression of this
map, not a copy of it.

---

## 4. Part unlocks

| Metric | Spore value | Source | Confidence |
|---|---|---|---|
| Total functional creature parts | **228** in the base game | StrategyWiki: "There are 228 parts to collect in the creature stage" (<https://strategywiki.org/wiki/Spore/Creature_Stage>, via API); SporeWiki Creature Creator: "any of 228 functional parts" | confirmed (2 sources) |
| Count check against the wiki's part database | 228 = 40 mouths + 40 details + 40 senses + 32 feet + 28 hands + 24 limbs + 24 weapons | derived from `Module:CreatureParts/data` (<https://spore.fandom.com/wiki/Module:CreatureParts/data>), counting `source=CORE` non-cell entries | derived (exact) |
| Structure | 7 categories × **4 columns**; "As your brain level increases, you unlock more columns" (Will Wright) | SporeWiki Creature Creator (quote, from an interview) | confirmed (quote + the 4-price structure below) |
| Parts per column | **41**: 10 mouths, 10 details, 8 feet, 7 hands, 6 weapons at each of 25 / 75 / 150 / 250 DNA. The 40 senses (all 10 DNA) and 24 limbs (50/65 DNA) sit outside the columns | derived from the same data table (exact arithmetic) | derived (exact) |
| Skeleton / bone pile | **1 part per pile**, from a pool of **4 pile sizes** → part level 1–4; bigger piles = higher-level parts; level 4 piles cluster in epic territory, high-level nests and migration nests; an exhausted tier falls back to a lower one; when every part is found, skeletons disappear | SporeWiki Skeletons: <https://spore.fandom.com/wiki/Skeletons>; StrategyWiki ("Fossil piles"); IGN part 4 ("bigger skeleton pieces generally give you better parts") | confirmed |
| Alpha | **1 part**, its level shown as a **star 1–5**; kill *or* befriend | SporeWiki Alpha Creature, Creature Stage (Strategy); StrategyWiki ("interact with an 'alpha' creature"); GameFAQs guide §3.4.3–3.4.4 | confirmed |
| Crashed spaceship | "usually strong parts nearby" | SporeWiki Creature Stage (Strategy) | single-source, no count |
| Befriending a normal species | **no part** (the species reward is DNA + a pack slot) | SporeWiki Creature Stage; DNA Points | confirmed (by absence) |
| Egg | **no part** (food + DNA only) | SporeWiki Egg | confirmed |
| Epic | **no part** (100 DNA + achievement) | SporeWiki Epic creature | confirmed |
| Unlock bias | newly found parts are more likely to be upgrades of the parts you already wear; each part has 3–4 progressively better versions | SporeWiki Creature Stage (Strategy); StrategyWiki; GameFAQs guide §3.7 | confirmed |
| How many parts each source yields across a stage | **not published.** There are 228 parts and 4 columns, but no source states how many come from skeletons vs alphas vs the ship | — | **not found** |

**Notes.** Spore's "tier" is a *column* (a whole generation of parts bought with
DNA, unlocked by brain level). Primigenia's G49 "tier" is a form variant of one
part. They are different axes; §10 maps them accordingly. P4/G37's
"befriending unlocks the species' signature part, guaranteed" is **our design**:
Spore gives parts for alphas only, and gives a pack slot for a normal ally.

---

## 5. Stats per part level

All part abilities are **levels 1–5**, and the level is displayed in the editor;
Spore publishes the level, not a stat per level, for most abilities.

### 5.1 Attack damage (the only published per-level values)

| Ability | L1 | L2 | L3 | L4 | L5 | Source | Confidence |
|---|---:|---:|---:|---:|---:|---|---|
| Bite | 1 | 1.5 | 2 | 2.5 | 3 | SporeWiki Bite: <https://spore.fandom.com/wiki/Bite> | confirmed (explicit table; also in Bite's article text) |
| Charge | 1 | 1.5 | 2 | 2.5 | 3 | SporeWiki Charge: <https://spore.fandom.com/wiki/Charge> | confirmed |
| Strike (primary target) | 3 | 4.5 | 6 | **8** | 9 | SporeWiki Strike: <https://spore.fandom.com/wiki/Strike> | confirmed (note L4 = 8, not a linear 7.5) |
| Strike (secondary targets) | 1–2 (all levels; the cone grows with level) | | | | | SporeWiki Strike | single-source |
| Spit (impact) | 0.5 | 1 | 1.5 | 2 | 2.5 | SporeWiki Spit: <https://spore.fandom.com/wiki/Spit> | confirmed |
| Spit (poison, total over 6 s) | 1.3 | 1.6 | 2.1 | 2.4 | 3.1 | SporeWiki Spit | confirmed |
| Charge stun | **3 s at every level** | | | | | SporeWiki Charge | confirmed |

### 5.2 Social abilities

| Ability | Published values | Source | Confidence |
|---|---|---|---|
| Sing / Dance / Charm / Pose | level 1–5 only. The effect is **relative**: your level against the target's level decides how much of the semicircle fills; matching the target's move fills your side faster; pack members with the same ability "double your socializing power"; a higher social level "weakens the lower socializing abilities of the opponent". **No numeric fill rates are published.** | SporeWiki Creature Stage (Socialization); StrategyWiki (Socializing); GameFAQs guide §3.5.1 | confirmed (qualitative) |
| Part sources for each | Sing ← mouths (carnivore 1–3, herbivore 1–5, omnivore 1–5); Dance ← feet; Charm ← details; Pose ← graspers/hands | SporeWiki Sing, Dance, Charm, Pose | confirmed |
| Stat caps | combat 20, social 20, abilities 23 (4 combat moves × 5, 4 social × 5) | SporeWiki Creature Stage ability table (template) | confirmed |

### 5.3 Health, speed and per-part bonuses

| Metric | Spore value | Source | Confidence |
|---|---|---|---|
| Player HP by brain level | **10 / 15 / 25 / 40 / 100** (levels 1–5) | GameFAQs guide §3.4.4 ("HP progression is as follows: level 1: 10, level 2: 15, level 3: 25, level 4: 40, level 5: 100") | single-source (explicit), endpoints agree with the wiki |
| Player HP at max, with health parts | **100–110** | SporeWiki Health: "starts out with 10 points of health, whereas a creature with a bigger brain will have 100 to 110 points depending on what parts with health bonus it has" | confirmed |
| NPC HP | 6–50 by level (Health page); "6 to 63" (Epic article); level-2 creatures seen at 15 and 19 HP, the next band at 32 | SporeWiki Health, Epic creature; SDA run comments | confirmed (wiki + a dated run guide agree on the bands) |
| HP per part *health level* | **not published** — only that health parts add HP, and the +10 ceiling at max brain | — | **not found** |
| Alpha HP | +25% over its species | SporeWiki Alpha Creature, Creature Stage (Strategy) | confirmed (wiki, 2 pages) / **conflict**: guide says "about 20% more hp" |
| Baby HP | half of an adult | SporeWiki Health, Creature | confirmed / **conflict**: guide says "40% less" |
| Speed | level 1–5, no m/s value anywhere | SporeWiki (speed is a 0–5 stat only) | **not found** (value); level scale confirmed |
| NPC level from stats | L1: ≤1 social and ≤2 combat; L2: ≥2 social; L3: ≥7 both or 5 in one; L4: 18 total or one stat >11 | SporeWiki Creature Stage | confirmed |
| NPC level from ability sets | L1: sing 1 only; L2: 2–3 social abilities, one superior; L3: all 4; L4: ≥4 in at least one; combat: L1 bite 1 only, L3 all moves, L4 hits harder | GameFAQs guide §3.5.1–3.5.2 | single-source (consistent with the stat thresholds) |

---

## 6. Cooldowns

| Ability | Cooldown | Source | Confidence |
|---|---|---|---|
| Bite | **1 s** | SporeWiki Cooldown: <https://spore.fandom.com/wiki/Cooldown>; SporeWiki Bite ("1-second cooldown") | confirmed (2 pages) |
| Spit | **3 s** (Cooldown page) / **4 s** (Spit page: "All levels of spit attacks have a 4-second cooldown") | SporeWiki Cooldown, Spit | **conflict** |
| Strike | **4 s** (Cooldown page) / **5 s** (Strike page: "All strike attacks, regardless of level, have a 5 second cooldown") | SporeWiki Cooldown, Strike | **conflict** |
| Charge | **12 / 11.5 / 10 / 9 / 7 s** by level (Charge page) or "10 / 12 / 10 / 8 / 6 s" (Cooldown page) | SporeWiki Charge, Cooldown | **conflict** (both non-monotonic in one source) |
| Sing / Dance / Charm / Pose | **no cooldown** — "all non-social abilities have cooldown timers" | SporeWiki Cooldown | confirmed |
| Jump | none; usable again as soon as the creature lands | SporeWiki Cooldown | single-source |
| Sprint | **25 s** after the sprint meter empties or is cancelled | SporeWiki Cooldown | single-source |
| Sneak | **25 s** after detection or cancellation | SporeWiki Cooldown | single-source |
| Glide | 1 s per flap while airborne | SporeWiki Cooldown | single-source |
| Consequence abilities | Siren Song 5 min, Raging Roar 4 min, Summon Flock 6 min | SporeWiki Cooldown | single-source |

**Ordering (all sources agree):** bite < spit < strike < charge. The absolute
values disagree between SporeWiki pages; per Q14 a video would settle it, and none
of the videos I could reach states a cooldown. Treat the *ordering and the ~1–12 s
range* as the finding, not the exact seconds.

---

## 7. Epic creature behaviour

| Behaviour | Spore value | Source | Confidence |
|---|---|---|---|
| HP | **1,000** (creature and tribal), 3,000 (civ/space), 4,000 (space per the Epic page) | SporeWiki Health, Epic creature, Creature Levels | confirmed |
| One-hit kill | Yes. **Stomp kills any creature instantly** except another epic; its **bite deals 100 damage**, survivable only at max brain + at least one health upgrade; **bite-and-throw deals 10 and stuns** | SporeWiki Epic creature | confirmed |
| Social | **Cannot be socialized at all**; immune to Raging Roar and Siren Song | SporeWiki Epic creature, Creature Stage; Wikipedia ("cannot use social interactions with an Epic") | confirmed (3 sources) |
| Ally condition | Instantly allied if the player has already allied the epic's smaller equivalent species; very rare because the same species must appear both ways | SporeWiki Creature Stage, Epic creature | confirmed |
| Part drop | **None**; 100 DNA + achievement | SporeWiki Epic creature, DNA Points | confirmed |
| Guards parts | Epic nests are dirt depressions "surrounded by a large number of skeletons"; epic territories hold level-4 skeletons | SporeWiki Epic creature, Skeletons; StrategyWiki ("often be guarding some bone piles with valuable body parts") | confirmed |
| Sneak | **Epics cannot detect sneaking creatures**, however close; looting a pile does not break Sneak | SporeWiki Creature Stage (Strategy) | single-source (explicit) |
| Movement/pathing | Can fail to move through trees; IGN's tactic is to stand behind trees and shoot it | IGN part 4 (excerpt via search; page returns 403) | single-source |
| Count per continent | "always 3–5"; at least 1 (guide); 1 per islet in Primigenia's world (W4) is our design | Steam post; guide §3.4.7 | single-source |
| Half-epic | 500 HP, "extremely rare", creature stage only | SporeWiki Creature Levels | single-source |
| Spawn diet bias | carnivores most likely, omnivores rarer, herbivores never | SporeWiki Epic creature | single-source |
| Aggro radius | **not published** | — | **not found** |
| Damage numbers besides the 100-damage bite and 10-damage throw | not published | — | **not found** |

---

## 8. Pack and ally limits

| Limit | Spore value | Source | Confidence |
|---|---|---|---|
| Max pack size | **3** | SporeWiki Pack: "It can hold up to 3 pack members"; Creature: "from 0 pack members to 3 then to Tribal Stage" | confirmed |
| Slots by level | 0 at level 1, one more per level after that ("you gain one additional pack slot for every level beyond the first") | GameFAQs guide §3.4.6 | single-source / **conflict** with the hard cap of 3 (the phrasing would allow 4 at level 5) |
| Who can join | only an **allied species** member or **your own species**; rogues qualify once befriended | SporeWiki Pack; StrategyWiki ("Other species, your species, rogue creatures") | confirmed |
| How to recruit | socialize with an allied creature while a slot is free | SporeWiki Pack, Creature Stage | confirmed |
| Pack effect in social play | a member with the same social ability **doubles** your socializing power | SporeWiki Creature Stage | confirmed |
| Pack effect in combat | members "do whatever action you are performing"; they fight on their own, have no hunger bar, and keep their own HP | GameFAQs guide §3.4.6, §3.7 | confirmed (guide + wiki) |
| Pack on death | you respawn with your whole pack; dead members must be re-recruited | GameFAQs guide §3.5.2, §3.7 | single-source |
| Nest healing | allied or extinct nests heal you and your pack | SporeWiki Creature Stage, Extinction | confirmed |
| Recruit limit per species | none published beyond the 3 slots | — | **not found** |

---

## 9. Conflicts, resolved or flagged

| Item | Values | Reading used here |
|---|---|---|
| Spit cooldown | 3 s (Cooldown page) vs 4 s (Spit page) | Report the range 3–4 s; Primigenia's spit recovery is independent (see §10) |
| Strike cooldown | 4 s vs 5 s | As above |
| Charge cooldown by level | 12/11.5/10/9/7 vs 10/12/10/8/6 | Ordering is monotone in the first set; use that shape, not the numbers |
| Alpha HP | +25% (wiki, 2 pages) vs ~20% (guide) | 25% (majority of sources) |
| Baby HP | half (wiki, 2 pages) vs 40% less (guide) | 50% (majority) |
| Egg DNA | 25 (Egg page) vs 25–50 (DNA Points) | 25 as the concrete value; 25–50 if it scales with species level (unsupported) |
| Migration DNA | 25–50 (DNA Points) vs 50 (Nest) | 50 for a completed migration; 25–50 if partial credit exists |
| Parts per species reward | wiki: no part for a normal ally; G37: guaranteed signature part | G37 is a design decision; Spore gives parts from alphas only |
| Pack slots at level 5 | guide implies 4; Pack page caps at 3 | 3 |

---

## 10. Mapping: Spore finding → Primigenia parameter

Primigenia values come from `docs/P4.md` (spec of record), `docs/COMBAT.md` (P2
move table) and `docs/DESIGN.md` (G23, G37, Q43). "Keep" means the current value is
inside the documented Spore band and needs no change. **None of the
recommendations below overrides G or W decisions.**

### 10.1 Stage shape and progression

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 1 | Typical creature stage 1–2 h; 1,000 DNA; 5 brain levels; no stage timer (§1, §2.1; confirmed/2 videos) | Q18 creature decision cap; P4 §2.2 progress bar (Q-8) | 2,500 decisions; progress = species resolved / 4 | **Keep 2,500.** Do not add a minutes target. Treat ~90 min as the *human* session target for the demo, not a scored bound. | Spore's 1–2 h at ~1 action every 2–4 s is 900–3,600 actions, so 2,500 sits inside the observed band. A time parameter would be invented; the cap is the measurable quantity. |
| 2 | 5 brain levels, 4 growth events, 1,000 DNA total (§2.1; confirmed) | P4 §2.2 progress bar (Q-8) | 4 species → 1.0 | **Keep.** No brain-level bar in P4. | Q43/Q-8 deliberately replace Spore's DNA bar with species resolution; a 1,000-point bar with 4 species would make each species worth 250 DNA, unrelated to Spore's per-nest ~65. Record that P4's bar is a *compression*, not a rescale. |
| 3 | A level-up needs ~3 nests + 1 alpha; ~12 resolutions per stage (§2.1, §3; derived) | valley species count | 4 species, 4–5 each | **Keep 4.** | Four species is one third of a Spore map's ~12 required resolutions — acceptable for a 90-minute slice, and P4's per-species DNA is correspondingly richer. |
| 4 | Nests hold 3–7 and the extinction counter equals the nest population (§3; confirmed) | P4 §2.2 `n` per species | 5 / 4 / 5 / 4 | **Keep** (inside 3–7). | Killing 3 of a nest of 4–5 leaves survivors, exactly Spore's behaviour; a nest of exactly 3 would leave none, which reads as "all dead" before the bonus fires. |

### 10.2 DNA awards (P4 §2.3)

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 5 | Kill/impress pays an unpublished small amount scaled by the victim's relative score; no per-kill value is recoverable (§2.2) | kill, regular species | 6 | **Keep 6.** | It is small against the 20–40 resolution bonus, which is the only published direction; the exact value is our design. |
| 6 | Befriending a neutral creature pays at least as much as killing it; "allying creatures that are neutral yields more DNA" (SDA) | first bond of an individual | 8 | **Keep 8.** | Slightly above kill, matching the source's direction; the value itself is our design. |
| 7 | Species resolution bonus 20–40, rising with level and hostility (§2.2; 3 videos) | alliance completed / dominated | +20 | **Keep 20**, or 25 if a single value is wanted. | 20 is the observed low-level value and keeps Q43's symmetry; P4's four species are levels 1–2 in Spore terms, where 20–25 is the documented band. |
| 8 | Egg = 25 DNA, repeatable, angers the species (§2.2; single-source) | — (G23 makes eggs pack members, not food) | no egg award | **Do not add DNA for eggs.** If P5 needs a number, 25 is the cited one. | G23 supersedes Spore's egg-as-food loop; eating your own future pack would contradict it. |
| 9 | Migration = 25–50 DNA, twice per stage (§2.2; confirmed that it pays) | — (valley slice, no migrations) | none | **No parameter.** | P4 has no migration; adding `dna_migration` would be inventing a system, and the earlier draft's 35 had no home in the spec. |
| 10 | Eating food gives **no** DNA; only health and hunger (§2.2; confirmed) | carcass first bite 3; fruit 1 (cap 30) | 3 / 1 | **Keep, labelled *our design*.** | Spore's absence of food DNA is the reason these need an explicit anti-farm cap; 3 per carcass and 30 total from fruit keep them below one kill each. |
| 11 | Finding a part gives no DNA (§2.2) | fossil/carcass inspect 8; new species 3; landmark 10; exploration 1 | as listed | **Keep, labelled *our design*.** | Spore has no exploration DNA at all; these exist to reward the benchmark's observation task (Q9/Q10), which Spore's design does not have. |
| 12 | No duplicate-part case exists; a spent tier falls back (§2.2) | duplicate part → cost/4 | cost/4 | **Keep, labelled *our design*.** | Spore cannot roll a duplicate; the conversion exists because P4 rolls per kill (Q-10). |
| 13 | Awards drop "substantially" after the bar is full, except rogues/epics; eggs unaffected (§2.1) | G23 two meters (`dna_total` never falls) | total never reduced | **Keep G23.** | G23 wins over Spore's decay; the anti-farm job Spore does with decay is done here by per-individual limits and the caps in §10.2. |
| 14 | Rogue 100 DNA, 250 HP; epic 100 DNA, 1,000 HP (§2.2; confirmed) | `dna_rogue`, `dna_epic` (P6/P8) | not in P4 | **100 / 100 when they land (P6/P8).** | Directly documented; no reason to rescale. |

### 10.3 The arithmetic check (derived, our tables)

From P4's own numbers, a full valley clear:

* dominate path: 4 × (3 kills × 6 + 20) = **152** DNA, plus carcasses (3 each),
  fruit (≤30), raids (10), exploration (≤40), landmarks (20), fossils (8 each),
  new species (3 each) → the cited 350–500 target is reachable only if the
  non-combat sources contribute ~200–350, i.e. most of the map's fossils and cells
  must be visited;
* ally path: 4 × (3 bonds × 8 + 20) = **176** DNA, ~24 more than dominate.

Spore's per-nest award is **at least** the 20–40 resolution bonus plus an
unpublished per-kill component. P4's 38–44 per species (one resolution plus
three individuals) is the comparable unit, so **the per-species economy is in
the right order of magnitude**; the difference is that Spore's stage needs ~12
resolutions and P4's needs 4, which is why P4 adds the non-combat sources to
reach 350–500.

### 10.4 Parts and prices (G37, G49, P4 §2.4–2.5)

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 15 | 228 base parts; 7 categories; 4 columns of ~41; column unlocked by brain level (§4; confirmed/derived) | `parts.json` catalogue | 46 parts | **Keep 46 for P4**; use 228 as the long-term codex target. | P4 needs a functional subset, not Spore's catalogue; 228 remains the number to quote for "complete". |
| 16 | Part prices 25 / 75 / 150 / 250 per column; senses 10; limbs 50–65 (§4; exact from the data table) | `parts.json` `dna_cost` 5–25 | 5–25 | **Keep the low P4 prices**; if the shop is retuned, the Spore ladder is 25/75/150/250 with senses at 10. | P4's whole valley earns 350–500 DNA, one tenth of Spore's 1,000; Spore's absolute prices would buy almost nothing. The *shape* (×3, ×2, ×1.67) is the transferable part. |
| 17 | Level 5 part costs 250 flat (§4) | level price multiples {2,4,8,16} × part cost (P4 §2.5, Q-19) | 16× (e.g. 400 for a 25-cost part) | **Keep for P4, flag**: a level-5 part costs ~1.6× Spore's most expensive part, against a valley that earns half of Spore's bar. If T10/T11 show the shop is too thin, cut the top multiple to 12 before touching part prices. | Spore sells a whole level-5 part for 250; P4's ladder is deliberately steeper ("rises steeply", G37) but the ratio to income is the thing to watch. |
| 18 | Spore has no tier/level split: the column *is* the generation; the ability level is the power | G49 tier (form) vs Q47 level (power) | tier 0–2, level 1–5 | **Keep the split**; record that Spore's 4 columns map to P4's **level**, not to P4's tier. | Prevents a future reader from "calibrating" tiers to Spore's columns and double-charging the same axis. |
| 19 | Alpha: kill or befriend always yields **1 part**, at the star level 1–5 (§4; confirmed) | kill drop 200‰ / 350‰ Garfio + pity on 4th dry kill (Q-10); ally signature part 100% (G37) | 20% / 35%, pity 4 | **Keep Q-10/G37**; if fidelity is wanted later, guarantee the part on an **alpha** kill (Spore's rule) while keeping 20% for normal kills. | G37 says "a chance… higher for rare kills"; Spore's alpha is a guaranteed drop. The pity already approximates the guarantee without the seed variance Q-10 is trying to bound. |
| 20 | A found part is biased toward upgrades of parts already worn; an exhausted tier falls back one tier (§4; confirmed) | drop table weighting (P4 §2.4) | uniform weighted pick among the victim's undiscovered parts | **Keep**; optional refinement: weight the pick toward the c_type the player already wears, as Spore does. | It makes "evolve what you use" (G49) emerge from loot as well as from milestones, without new rules. |
| 21 | Skeletons: 4 pile sizes → part level 1–4; level-4 piles cluster near epic nests and migration nests; skeletons vanish when all parts are found (§4; confirmed) | fossil nodes, surface only in P4 (§2.4) | surface fossils, one roll each | **Keep**; place the highest-tier surface fossil set away from the start valley, and use the epic islet for tier 4 in P8 (W4). | Spore ties the best fossils to risk; P4 has no epic yet, so distance from the nest is the only risk dial available. |
| 22 | 3 legs + cell parts enter the Early Creature Creator (§4; confirmed) | starting inventory `pico`, `pata`, `ojo` (Q-11) | 3 parts | **Keep.** | Matches "cell parts plus three legs" and Spore's forced-legs tutorial. |

### 10.5 Stats, HP and combat (P2 / profile.js)

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 23 | Player HP 10 at level 1, 100–110 at level 5 (§5.3; confirmed) | `profile.js` base HP; combat baseline | 100 | **Keep 100.** | P4's creature is a level-5-equivalent animal; 100 is exactly Spore's max. |
| 24 | NPC HP 6–50 by level (L2 = 15–19, next band 32) (§5.3; confirmed) | species HP (P4 §2.2) | 60 / 70 / 100 / 80 | **Keep for P4** (tourney-gated), but note the ratio: Spore's level-4 NPC has 40–50 HP against a 100 HP player; P4's weakest species has 60% of the player's HP. If fights feel long in the P4 gate, lower **species HP** first (e.g. 35/45/70/55), not damage. | Damage tuning would move the P2 counter matrix; HP is the isolated dial. Current values are 1.2–2.5× Spore's relative toughness. |
| 25 | Bite 1→3, strike 3→9, spit impact 0.5→2.5 (all ≈3–5× from L1 to L5) (§5.1; confirmed) | `damage * (1 + 0.20 (L−1))` (COMBAT.md) | 1.8× at L5 | **Keep 1.8× for P4**; if the level curve is ever widened, 3× at L5 is the documented Spore shape. | P4's flat +20% is gentler than Spore's; changing it now would invalidate B1–B8. Record the gap. |
| 26 | Charge stuns 3 s at every level (§5.1; confirmed) | charge stun 6 ticks (COMBAT.md) | 0.6 s | **Keep**; note that Spore's stun is *long* (3 s) because it is a 10–12 s cooldown move, while P4's charge is a 1.7 s commitment. Relative to its own cooldown, P4's stun is longer than Spore's. | The ratio stun/cooldown is 0.25 in Spore, 0.35 in P4; P4 already leans harder on the stun. |
| 27 | Health parts add HP; the ceiling with parts is +10 (100→110); **no per-level formula is published** (§5.3) | `profile.js` `hp += guard * 5` | +5/level, +25 max | **Keep, labelled *our design*.** Spore's only anchor is a +10 ceiling at max brain, so +5/level is the closest integer fit. | Do not import the old draft's +10/+15/+25/+40/+100 table; it does not exist in any source. |
| 28 | Speed is a 0–5 level with no published m/s (§5.3) | speed 4 m/s base; P4 species 4.0–5.8 | as is | **Keep.** Any m/s figure is our design. | Spore publishes no speed value to calibrate against. |
| 29 | Social levels 1–5 with no numeric fill formula; result is relative level, matching, and pack doubling (§5.2) | trust deltas +12/+8/…, beat ±2 ticks, combo 1.5/2.0, habituation 50/25% (P4 §2.1) | prototype values | **Keep, labelled *our design*.** Two confirmed qualitative anchors: matching the target's move is what fills the bar fastest, and pack members with the ability double it — P4 has both (preferences + combo; pack mimics). | Spore has no trust number; P4's +12/cap-60 gives 4–5 good performances per bond, inside the prototype's 2–5 songs. |
| 30 | Ally = 3 befriended; extinct = 3–7 by level (§3; confirmed) | `ally_befriend_count`; extinction count | 3 / 3 flat | **Keep 3 / 3.** | Q43 requires symmetry; Spore's 3 is the confirmed floor and the E3 demo itself used 3. Level-scaling 4/5/7 is the fidelity option, but it breaks the "3 hunted" rule, so it is an owner decision, not a calibration default. |

### 10.6 Cooldowns (COMBAT.md move table)

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 31 | Bite 1 s, spit 3–4 s, strike 4–5 s, charge 7–12 s; ordering strict (§6; confirmed ordering, conflicting values) | move wind-up/active/recovery at 10 Hz | bite 6 ticks total, spit 11, tail 9, charge 17 | **Keep**; preserve the ordering (bite < tail/spit < charge) in any retune. | P4 turns Spore's 1–12 s into 0.6–1.7 s (1.7× faster for bite, ~7× for a 12 s charge), which is the right scale for a 2,500-decision stage (Spore's single-button loop pays ~1 action per 2 s). A literal 10–12 s charge would be 100–120 ticks, i.e. 5–6 % of a 2,000-tick fight per use. |
| 32 | Social moves have **no** cooldown (§6; confirmed) | skills are committed moves with recovery (§2.1) | wind-up/active/recovery per skill | **Keep**; the anti-spam job is done by habituation, not cooldown. | Spore's social game is turn-like without cooldown; P4 keeps the move shape so it can be interrupted (G16), with habituation replacing the missing cooldown. |
| 33 | Sprint 25 s lockout; sneak 25 s; jump free on landing; glide 1 s/flap (§6; single-source) | sprint/stamina (COMBAT.md §macro `flee`) | 0.5 stamina/tick | **Keep**; no 25 s lockout for P4. | A 25 s lockout at 10 Hz is 250 ticks, longer than most P4 fights; the stamina cost is the equivalent dial. Record the source for P6's swim/glide work. |

### 10.7 Epic and pack (P8 / P5)

| # | Spore finding (source, confidence) | Primigenia parameter | Current | Recommend | Why |
|---|---|---|---|---|---|
| 34 | Epic 1,000 HP, 10× the player at 100; stomp = instant kill; bite 100; throw 10 + stun (§7; confirmed) | epic on the islet (P8, W4/G54) | not implemented | **1,000 HP; stomp/instakill; bite 100; throw 10 + stun.** | All four are directly documented and scale against the same 100 HP player baseline Primigenia uses, so no conversion is needed. |
| 35 | Cannot be socialized; immune to Siren Song and Raging Roar; allies instantly if its smaller species is allied; drops no part (§7; confirmed) | `epic_can_socialize`, `epic_ally_via_species`, drops | — | **false / true / no part**, as documented. | Unambiguous, three sources, and it is exactly the surprise the islet is for. |
| 36 | 3–5 epics per continent, 1+ minimum; epics guard level-4 skeletons; sneaking is invisible to them; can be blocked by trees (§7; single-source each) | `epic_count`, `epic_guards_fossil_tier4`, `epic_sneak_immune`, pathing | — | **1 per islet (W4); guards the islet's tier-4 fossil; sneak-immune; pathing limited by trees.** | W4 already fixes the count; the other three are behaviour that makes the islet a heist rather than a boss. |
| 37 | Pack max 3, allies/own species only, doubles social power if it shares the ability, no hunger, respawns with you, nests heal (§8; confirmed) | P5 pack (G18, G29) | not implemented | **3 slots; ally-or-own only; social double; no hunger; nest heal.** | All confirmed, and none conflicts with G29's roles (roles are for hatchlings/allies at the nest, not the 3-slot travelling pack). |
| 38 | Ally/dominate is per species and closes the other path (§3; confirmed by E3 + wiki) | Q43 loop | 3/3, latched | **Keep.** | Spore's own demo showed the same two mutually exclusive bars; P4's latch is a benchmark determinism choice, not a fidelity claim. |

---

## 11. Not found / could not verify

| Missing metric | Where looked | Status |
|---|---|---|
| DNA per individual kill/impress, exact formula | SporeWiki DNA Points, Creature Stage, Bite/Charge/Strike/Spit, game guides, 4 videos | **Not published.** Only "small, scaled by relative scores". Primigenia's 6/8 are *our design*. |
| DNA thresholds per brain level (the 5 waypoints) | SporeWiki, StrategyWiki, guide, videos | **Not published.** Only the 1,000 total and 5 levels. |
| HP added per part *health level* | SporeWiki Health, Creature Creator, part data | **Not published.** Only the +10 ceiling at max brain. |
| Speed in m/s per speed level | all of the above | **Not published.** |
| Social fill rate / trust equivalent | SporeWiki Creature Stage, StrategyWiki, guide | **Not published.** Only relative-level behaviour. |
| Number of skeletons per continent, and how many parts come from each source | SporeWiki Skeletons, Migration, guides | **Not published.** |
| Epic aggro radius, epic move damage other than bite 100 / throw 10 | SporeWiki Epic creature, IGN | **Not published.** The 28 m figure in the earlier draft came from P4's temperament table, not from Spore. |
| Nest count per continent | Steam post, Reddit, E3 | **Only inferred** (~12–25) from 80–100 creatures and 3–7 per nest. |
| Official stage length | Wikipedia, HowLongToBeat, SDA | **No official figure.** 1–2 h is convergent player testimony; 11 min is the speedrun. |
| Exact cooldown seconds (spit, strike, charge) | SporeWiki Cooldown vs each ability page | **Conflicting within SporeWiki**; no video with a stated number. |
| Full text of GameFAQs board threads and IGN pages | direct fetch | **403**; cited only through search excerpts. |
| YouTube transcripts | direct fetch | **No transcript in HTML**; timestamps are from search excerpts, not watched. |

---

## 12. Sources

**Wikis and reference**

1. SporeWiki (spore.fandom.com), read via `api.php` because the HTML returns 403.
   Pages: `Creature_Stage`, `DNA_Points` (redirects from `DNA`), `Creature_Levels`,
   `Creature`, `Creature_Creator`, `Health`, `Cooldown`, `Skeletons`, `Extinction`,
   `Migration`, `Pack`, `Alpha_Creature`, `Baby_Creature`, `Egg`, `Nest`,
   `Epic_creature`, `Rogue_creature`, `Bite`, `Charge`, `Strike`, `Spit`, `Sing`,
   `Dance`, `Charm`, `Pose`, `Module:CreatureParts/data` (the part database used
   for the 228 count and the 25/75/150/250 columns). Accessed 2026-11-15.
2. StrategyWiki, `Spore/Creature_Stage` (<https://strategywiki.org/wiki/Spore/Creature_Stage>),
   read via the MediaWiki API (HTML 403). 228 parts; bone piles; alpha; pack;
   social matching; capabilities per category.
3. Wikipedia, *Spore (2008 video game)*
   (<https://en.wikipedia.org/wiki/Spore_(2008_video_game)>): stage descriptions,
   epic social immunity, four-stage length range.

**Dated written guides**

4. Xenogenesis2000, *Spore — Guide and Walkthrough* (GameFAQs, v. Final,
   2008-09-27): <https://gamefaqs.gamespot.com/pc/926714-spore/faqs/54223>.
   HP by level, alpha/baby HP, pack slots, ally = 3, NPC level ability sets,
   rogue/epic counts, part-drop bias.
5. Speed Demos Archive, *Spore* run comments (KinglyValence, 2018; rowrow_,
   2015): <https://speeddemosarchive.com/Spore.html>. Timed creature stage
   (10:58), 4 kills for the first nest, 15/19/32 HP creature bands, 3 nests +
   1 alpha per level, 35 DNA for a 3-kill pack, rogue 100.

**Timestamped video (caption excerpts via search; not watched)**

6. E3 Spore presentation, part 1 of 4 — creature stage:
   <https://www.youtube.com/watch?v=DeMhBUsnswA>. 4:02–4:10 "kill off three…
   or befriend three"; 4:51 "six different species… a very small area".
7. *Spore Speedrun Any% Normal 45:46 (Commentary)*:
   <https://www.youtube.com/watch?v=ctYcS1V1jC4>. 8:07 and 15:45 resolution
   bonus 25/30/40; 10:54 "30 DNA for killing four creatures".
8. *Spore Creature Stage Normal 12:00 (Commentary)*:
   <https://www.youtube.com/watch?v=ESW2imoSllg>. 3:25 alpha parts and bonus;
   8:19 rogue 100; 10:29 bonus scales with level.
9. *How I Beat Spore with the Shortest Timeline*:
   <https://www.youtube.com/watch?v=tFE_gfM-sqA>. 2:13 "1,000 DNA points";
   3:30 "4 Brains on the Timeline".
10. *Unlocking Every CUT Achievement in Spore*:
    <https://www.youtube.com/watch?v=taqyDGYgXz8>. 9:42–9:53 "1,000 DNA
    points"; 10:02 awards reduced at higher level.
11. *Spore HD Creature Stage Overview Part 1*:
    <https://www.youtube.com/watch?v=xE7bIBJPhFs>. 5:23–5:31 "got a new part and
    I got 20 DNA points and we extincted them".
12. *How I Beat Spore in LESS Than 30 Minutes*:
    <https://www.youtube.com/watch?v=ot59JXaaopY>. Chapters: creature 1:26,
    tribal 5:11.

**Player data**

13. Steam Community, "I think Creature Stage runs out of nests after a while"
    (2016-12-12, Dutchgamer1982):
    <https://steamcommunity.com/app/17390/discussions/0/1843493219428946531>.
    80–100 creatures, 3–5 epics, 5–7 small epics, the rest nests.
14. GameFAQs board threads on stage length (2008), read via search excerpts:
    <https://gamefaqs.gamespot.com/boards/926714-spore/45325852>,
    <https://gamefaqs.gamespot.com/boards/926714-spore/45382090>.
15. HowLongToBeat, *Spore*: <https://howlongtobeat.com/game/8985> (whole-game
    lengths only).
16. IGN, *Evolution Walkthrough part 4*
    (<https://www.ign.com/wikis/spore/Evolution_Walkthrough_part_4>), read via
    search excerpts (HTML 403): epic 100 DNA and tree-blocking, bigger skeletons
    give better parts, the objective box shows both rewards.

**Primigenia documents**

17. `docs/DESIGN.md` — Q14/Q22 (this calibration), Q18 (decision caps), Q43
    (ally 3 / dominate 3 loop), G16 (combat), G23 (DNA never down, eggs), G37
    (part discovery and prices), G49 (tiers), W4 (the epic's islet), G54
    (the epic's phase, P8).
18. `docs/P4.md` — §2.1 social, §2.2 loop and species table, §2.3 DNA awards,
    §2.4 part discovery, §2.5 tiers, §3 gates.
19. `docs/COMBAT.md` — move table, counter matrix, 10 Hz tick.
20. `web/engine/profile.js`, `web/studio/parts.json` — current HP and part prices.

---

## 13. What this means for Primigenia (short version)

1. **The loop is well calibrated.** Ally = 3 is confirmed by three independent
   sources, including Maxis's own E3 demo; extinction = 3 at the low end;
   per-species resolution bonus 20–40 against P4's 20. No change is needed to
   the Q43 loop or the §2.3 awards.
2. **Four values are ours, not Spore's, and should be labelled so**: the 6/8 per
   individual (Spore publishes no number), food/exploration/fossil DNA (Spore
   awards DNA only for kills, impressions, eggs and migration), the entire
   social numeric model (Spore publishes only relative levels), and the species
   part tables (Spore's drops are skeleton- and alpha-based).
3. **Two ratios are worth watching in the P4 gates**, both HP/shop rather than
   combat:
   * species HP: Spore's level-4 NPC is 40–50 % of the player's HP; P4's weakest
     species is 60 %, the strongest 100 %;
   * a level-5 part costs 250 in Spore against a 1,000 DNA bar; P4 charges 400 for
     a 25-cost part against a 350–500 DNA valley. If T10/T11 show the shop is
     thin, fix the top price multiple before part prices.
4. **The epic is directly portable**: 1,000 HP, stomp instant kill, 100-damage
   bite, immune to social, insta-ally via its smaller species, guards tier-4
   bones, cannot see a sneaking creature. Nothing needs converting because both
   games use a 100 HP player baseline.
5. **Do not import Spore's absolute cooldowns.** The ordering (bite < spit/strike
   < charge) and the 1–12 s range are the finding; P4's 0.6–1.7 s cycles are a
   deliberate 1.7–7× compression so that 2,500 decisions cover a 1–2 hour stage.

---

*Compiled 2026-11-15 from the sources in §12. If a number is not in §1–§8 with a
URL, it is not calibrated — it is our design, and it says so.*
