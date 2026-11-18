# Project Hail Mary lore catalogue

Status: **development lore, 2026-11-18.** Owner decision **A20** (`DESIGN.md`), hooks in `ARC-PLAN.md` §5.3c. Exact names live only here and in `lore/hailmary.en.json`, so a release can swap them without touching mechanics (same rule as A4 / §5.3 and A19 / §5.3b).

This file is the readable table. The JSON is the swappable lore file.

## Method

Researched from, in order:

1. **The 2021 novel** (Andy Weir, *Project Hail Mary*, Ballantine Books, 4 May 2021, ISBN 978-0-593-39556-1). Numbers below are the book's: gravity, pressure, temperatures, energy density, dimming milestones, trip times.
2. **Wikipedia** (novel and 2026 film pages) for plot checklist, publication, and naming differences.
3. **Secondary science notes** that restate book figures (Petrova wavelength, 96.415 °C, 1.5 g, 2 000 t fuel, Erid 20.48 m/s² / 29 atm / 210 °C) without quoting the prose.
4. **Fan wikis only to cross-check.** Drive counts, beetle fuel mass, and some Eridian body numbers that come from author notes rather than the novel are marked in the JSON.

The 2026 film (Amazon MGM, Lord & Miller, 20 March 2026) is used **only for naming differences**. No likeness, puppet, or poster is a source for bodies or ships.

Confidence:

| Tag | Meaning |
|---|---|
| **book** | Named and described in the 2021 novel. Extra digits that secondary notes also report from the book stay here. |
| **film** | A name or omission that appears in the 2026 film and is not how the novel is indexed. One row (`film-names`). |
| **wiki** | Fan wiki or author-note only. Unused as a whole-entry tag: wiki-only digits live inside `facts` of book rows. |

Twenty-one entries: the microbe (biology, storage, breeding, dimming), the Petrova line, Taumoeba and the nitrogen-tolerant strain, Adrian, Threeworld, Venus, Tau Ceti, 40 Eridani, Erid, the Eridians (body, senses, chords, society, xenonite, radiation blind spot, ammonia world), Rocky, the Hail Mary, the spin drive, the Blip-A, the beetles, the two-species crew, and the film name list.

## Catalogue

Full descriptions, numeric `facts`, and sources: `lore/hailmary.en.json`. Game hooks use the §5.3c menu (Cell microbe, Space fuel, star-dimming crisis, Petrova night-sky egg, Taumoeba Shape puzzle, Eridian befriend/xenonite, two-species win).

| Name | Kind | What it is | Key facts | Conf. | Game hook |
|---|---|---|---|---|---|
| **Astrophage** | microbe | Light-eating star-surface cell. Stores surplus as mass, breeds on a CO2 world, flies home on its own infrared | 10 µm; 96.415 °C; 1.5 MJ/cell; **8.99×10¹⁶ J/kg**; 0.92 c; doubles ~8 d in lab; 25.984 µm exhaust | book | **Cell** rare find; **Space fuel**; **Space crisis** that dims worlds you left |
| Petrova line | phenomenon | Faint IR streak from a dimming star to the breeding planet. Named for Irina Petrova | 25.984 µm; 0.0477 eV/photon; Earth→Venus, Tau Ceti→Adrian, Erid→Threeworld | book | **Creature egg**: nocturnal eyes see a line from the setting sun to the evening planet; one journal line |
| Astrophage crisis | crisis | Nearby stars fade; ice age inside a human lifetime unless a predator is found. Tau Ceti is the exception | 0.01% already; **1% in 9 yr**; **5% in 20 yr**; ice age ~30 yr | book | Home-star luminosity and planet health (A3) tick down every year until the cure |
| **Taumoeba** | microbe | Astrophage predator from Adrian. Why Tau Ceti stays bright. Dies in nitrogen | N₂ lethal; Venus breeding air 3.5% N₂; Threeworld 8%; 0.02 atm at the breeding height | book | **Cure expedition** + **Shape** a microbe that survives your ships' air |
| Taumoeba-82.5 | microbe | Nitrogen-tolerant strain. 35 handles Venus, 80 handles Threeworld, 82.5 is margin. Also learns to crawl through xenonite | +0.05% N₂ per tank; store in metal, not xenonite | book | Shape success with a catch: the adapted predator can eat an ally's fuel tanks |
| Adrian | planet | Tau Ceti e. CO2 nursery and Taumoeba home. Named for Rocky's mate | Tau Ceti e | book | Expedition target: the Petrova planet that still has a predator |
| Threeworld | planet | 40 Eridani's breeding world (Erid's Venus). **Film never uses this name** | 8% N₂ at breeding height | book | Second nursery: the ally's star needs a harder strain than yours |
| Venus | planet | Sol's Astrophage nursery; why the line points at the evening planet | 3.5% N₂; Taumoeba-35 is enough | book | Home-system harvest site and drop site for the predator |
| Tau Ceti | star | The nearby sun that is not going dark | 11.9 ly from Earth | book | Map marker for the cure flight and first contact |
| 40 Eridani | star | Erid's sun, also infected | 16.3 ly from Earth | book | The friendly empire's threatened home star |
| **Erid** | planet | Heavy, hot, high-pressure ammonia world. Almost no light at the surface | **20.48 m/s² (2.09 g)**; **29 atm**; **210 °C**; ammonia; ~8.5 M⊕, ~2 R⊕; ~5.1 h day; ~25× Earth's magnetic field | book | High-g / high-pressure niche (§1): live here without terraforming, or dome |
| **Eridians** | species | Five-legged, rock-shelled, eyeless engineers. Chord speech, mercury blood, steam muscles, helpless sleep (they guard each other). No word for radiation or light | 5 limbs; 5 vocal systems; ~6× speech density; 210 °C / 305 °C blood; 29 atm; fatal below ~19 atm | book | **Friendly Space species**. Diplomacy reuses **befriend** (sing, rhythm). They teach xenonite. Radiation is the friendship hook |
| Rocky | character | Eridian engineer, last of his crew, named for the shell | 46 Earth years at Tau Ceti; crew died of radiation | book | Contact face: share fuel and xenonite; you may have to turn around and save him |
| **Xenonite** | material | Two-liquid Eridian epoxy. Spectrometer reads xenon. Holds 29 atm behind 1 cm. Elevator-class tensile strength | 1 cm; 29 atm vs ~0.2; 210 °C vs ~20 °C; Taumoeba-82.5 can penetrate | book | Tech they can teach: hulls, tunnels between unmatched airs, high-g elevators |
| Eridian space elevator | technology | How a 2 g world reaches orbit without burning Astrophage at the pad | Xenonite cable; short geosync because the day is ~5 h | book | High-g lift once you have the material or the ally |
| **Hail Mary** | ship | Earth's one-way Astrophage ship to Tau Ceti. Three crew in coma, spin drum, four beetles | Dry ~100 t (wiki); fuel **2 000 t**; 1.5 g; ship time **4 yr 8 mo**; Earth time **~13 yr**; crew Yao / Ilyukhina / Grace | book | Player Astrophage ship. One-way unless a friend refuels you |
| Spin drive | technology | Engine that asks Astrophage to dump mass as a Petrova-wavelength beam | 1.5 g cruise; beetles 500 g; exhaust 25.984 µm | book | Propulsion rung next to the Bussard ramjet (§8) |
| **Blip-A** | ship | Rocky's xenonite ship, named from a radar label. Newton-only flight plan, so spare fuel for two worlds | Ammonia 29 atm / 210 °C; planned 6.64 yr; experienced ~3 yr | book | The other half of the joined ship. Xenonite hull fails first if the predator mutates |
| Beetles | probe | Four redundant darts (John, Paul, George, Ringo) that carry the answer home | 500 g; 0.93 c; **20 months** probe time; **~12 yr** Earth | book | Send the cure home even if you stay to save the ally |
| Two-species crew | event | Human biology + Eridian engineering on one ship. Neither could finish it alone | Sol confirmed restored **16 yr** after Grace lives on Erid | book | **Co-operation win** for the crisis (§5.3c) |
| 2026 film naming | names | Same title; almost the same nouns; a few extra Earth names; no Threeworld | Adds Carl, ship-computer Mary; full names Yao Li-Jie, Olesya Ilyukhina, Martin Dubois, Annie Shapiro | film | Release switch only. No likeness |

## Astrophage as a resource and as a crisis

Not flavour: three numbers a Space ruleset can use. They are the book's, rounded for play.

### Fuel per kg

Astrophage stores energy as mass, so a kilogram is an \(E = mc^{2}\) battery:

| | |
|---|---|
| Energy density | **8.99×10¹⁶ J/kg** (~25 TWh/kg) |
| vs chemical LH2/LOX | ~10⁹ times more |
| vs fission | ~10³ times more |
| Hail Mary load | 2 000 t = 2×10⁶ kg → **1.8×10²³ J** |
| Cruise | 1.5 g photon drive on a ~100 t dry hull |

**Play rule:** it is the top chemical-to-stellar fuel on the tech ladder (§8, next to the Bussard ramjet). You do not synthesise it. You **harvest at infected stars** (and their CO2 breeding worlds). A ~12 ly hop at 1.5 g costs on the order of **10³ t per 100 t of ship** if you burn all the way; less if you coast. Infected systems are therefore both a famine and a fuel depot.

### Dimming rate per year

The book is not linear. It gives milestones, which invert to a slow start and a faster middle:

| Clock | Luminosity lost | Implied mean rate |
|---|---|---|
| Now (discovery) | 0.01% | already measurable |
| +9 years | 1% | **~0.11% per year** in that window |
| +20 years | 5% | later years closer to **~0.4% per year** |
| +30 years | ice age | planet health gone if untreated |

Lab doubling is ~8 days; the star is a covering problem, not a test-tube.

**Play rule:** once a Petrova line is visible, **planet health (A3) falls a little every year** on every world of that star, including colonies you have already left. A simple tick: **−1 health / year**, lethal at year 30, with the 9-year and 20-year marks as warnings (crops fail, then ice). Finding and releasing a predator stops the tick; recovery is not instant (the book restores Sol on a ~decade clock after release).

### How long the cure expedition takes

Tau Ceti is **11.9 ly**. The Hail Mary accelerates at 1.5 g. Clocks disagree:

| Leg | Ship / probe clock | Home-star clock |
|---|---|---|
| Earth → Tau Ceti | **4 years 8 months** (coma) | **~13 years** |
| Work at Adrian (find + breed Taumoeba-82.5) | weeks | weeks |
| Beetles → Earth with the strain | **20 months** | **~12 years** |
| You stay / turn back to save the ally | extra years of food | extra years of dimming |
| Sol confirmed bright again (book ending) | — | **16 years** after Grace is living on Erid |

**Play rule:** a cure expedition is a **multi-year Space operation**, not a single jump. Budget **~5 years** of ship time one way and **~13 years** of home-star time. The beetles are how the homeworld gets the strain if the crew does not return. Two species on one ship is the win: Earth-like biology finds and breeds the predator; the Eridian-like ally supplies xenonite and the spare fuel that makes a second burn possible. Neither clock, and neither species, is enough alone.

## Legal note

*Project Hail Mary* is a **copyrighted work by a living author**, Andy Weir (Ballantine Books / Random House, 2021). It is also a **2026 film** (Amazon MGM Studios; directed by Phil Lord and Christopher Miller; screenplay by Drew Goddard). That makes it riskier than the older homages in §5.3.

This repo is public (MIT / CC BY). Therefore:

- **Names and descriptions live only** in `lore/hailmary.<lang>.json` (this document is the human index of that file). Mechanics must keep working if the file is swapped for original names.
- **No art or likeness from the film** (cast, puppet, creature shop, posters, stills). Game microbes, ships, and the tentacled-or-shelled friend stay in our own style. The JSON may list film *names*; it must not describe actors or the puppet.
- **Contacting the author or the studio is a release-time option**, not something to do from the worktree. Decision with legal advice at release (C8), same rule as A4 / A19.

Until then, development uses the 2021 names, as A20 and §5.3c already decided.

## Sources

1. Andy Weir, *Project Hail Mary*, Ballantine Books, 4 May 2021 — primary text for every book row.
2. [Project Hail Mary (English Wikipedia)](https://en.wikipedia.org/wiki/Project_Hail_Mary) — plot checklist, Tau Ceti 11.9 ly, 4 years 8 months of ship time, 46 years at Tau Ceti, 16-year coda.
3. [Project Hail Mary (film)](https://en.wikipedia.org/wiki/Project_Hail_Mary_(film)) — naming differences only (full names, Carl, Mary, Threeworld omitted).
4. Secondary restatements of book numbers: [thescience360.com, Astrophage physics](https://thescience360.com/project-hail-mary-astrophage-physics/) (8.99×10¹⁶ J/kg, 1.5 g, 2 000 t); [projecthailmary.net, Erid](https://projecthailmary.net/en/erid/) (20.48 m/s², 29 atm, 210 °C).
5. Fan wikis ([projecthailmary.fandom.com](https://projecthailmary.fandom.com/)) — **cross-check only**. Drive count 1009, beetle fuel 120 kg, and Eridian.doc body figures are called out in the JSON `facts` / `source` lines.
