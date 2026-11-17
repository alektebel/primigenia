# All Tomorrows lore catalogue

Status: **development lore, 2026-11-17.** Owner decision **A19** (`DESIGN.md`), hooks in `ARC-PLAN.md` §5.3b. Exact names live only here and in `lore/alltomorrows.en.json`, so a release can swap them without touching mechanics (same rule as A4 / §5.3).

This file is the readable table. The JSON is the swappable lore file.

## Method

Researched from, in order:

1. **The 2006 book text** (the freely circulating PDF: *All Tomorrows: A Billion Year Chronicle of the Myriad Species and Mixed Fortunes of Man*, C. M. Kosemen writing as Nemo Ramjet, 4 October 2006). Chapter order is the chronology used here.
2. **Wikipedia** (English and Italian species lists) to check completeness, publication history, and the 2024 Thai / 2025 English print editions.
3. **The author's site and interviews** (cmkosemen.com; Alt Shift X podcast, 2021; Thai-edition video, 2024; Wilton Square announcement, 2025).
4. **Reviews** (*The Guardian*, 12 December 2025; *New Scientist*, November 2025 list).
5. **Fan wikis only to cross-check.** Facts that appear only there are marked **fan-unverified** and are not used as names in the catalogue.

The 2025 Wilton Square hardback adds notes and sketches the 2006 PDF did not have. This catalogue does **not** use that exclusive material. It also does **not** use unpublished *All Tomorrows Redux* species (Quhanim, Cronians, Leapers, Venerians, “Redux” Predators / Killer Folk / Spacers, and so on). Those names are fan-wiki or Patreon-preview labels, not 2006 book species.

Confidence:

| Tag | Meaning |
|---|---|
| **book** | Named and described in the 2006 text (or on its illustrated timeline page). |
| **wiki** | Added or framed by Wikipedia, not contradicted by the book. Unused as a whole-entry tag here: every row is in the book. |
| **fan-unverified** | Fan wiki or Redux only. Called out in the JSON body where needed (Qu anatomy, the name Quhanim, grey Star People). |

Forty-five entries: every named human stock, every named Qu-made people, every named sapient heir, the Qu, Panderavis, Saurosapients, Amphicephali, and the Author. Unnamed one-line kinds (eel-people, gasbag trees, the Bug Facers’ second invaders, the nameless extinct aquatic fossil) are omitted.

## Catalogue

Full body plans, temperament and source lists: `lore/alltomorrows.en.json`. Game hooks use the §5.3b menu (creature egg, Band/Realm cousin, Industry, Space civilisation, Qu event, void-adapted mirror, rogue AI).

| Name | Era (as given) | Origin | Body plan | Environment | Temperament / culture | Fate | Conf. | Game hook |
|---|---|---|---|---|---|---|---|---|
| Humans | Present → Terrestrial Heyday; war with Mars “roughly a thousand years from now” | Baseline *Homo sapiens* | Ordinary terrestrial primates | Earth, then terraformed Mars | Unified late; fights to keep Martian industry | Nearly extinct in the war; replaced by Star People; genes last in the subjects | book | Creature egg: billion-year-old human skull, one journal line; pays off in Space |
| Martians | Centuries after Mars opens; also “Martian Americans” | Earth colonists + low-g and engineering | Spindly, lithe | Terraformed Mars (Phobos later shattered) | Rebel culture; trade boycott | Peace after >8 billion dead; merged into Star People | book | Band/Realm cousin: low-g colonists whose civil war forces a later engineered unification |
| Star People | After the war; they fill humanity’s spiral arm. Also “Star Men” | Engineered merger of Earth and Mars stock | Unified, more capable human; grey-skin fan art is unverified | Garden colonies, machine-made from stored genes (generation ships fail; Mechanical Oedipi kill ~half of first generations) | Summer of Man: optional labour, no other intellect known | Every world taken by the Qu in <1000 years; a few flee as Spacers | book | Space **Seed**: automated terraformers that grow colonists; ruins with tech to recover |
| *Panderavis pandora* | Fossil in the Summer of Man; a derived therizinosaur | Not human; Earth dinosaur placed on an alien world | Colossal bird-like digger, four calcium limbs on a three-limbed planet | Newly colonised alien world | None; splits Star People into faith vs rearmament | Long dead; the warning fails | book | Creature fossil / archive clue that makers visited Earth |
| **Qu** | ~1 billion years old at contact; 40 million years of rule; later subdued | Alien nomads, self-remade. “Quhanim” is Redux/fan | Prose: aquatic larva, drones, tracing beasts. Insectoid reconstructions follow the picture, not the text | Spiral-arm migrations; km-high pyramids | Religion of remaking the universe; humans are infidel raw material | They leave because the quest cannot stop; found again and beaten | book | **Qu event**: genome rewrite; hide, scatter or endure; leftover colonies are new species of your lineage |
| Worms | Qu-made; last until the sun cools | Star People of a scorching world | Pale digging worms, pinprick eyes, almost no nerves | Underground under crystalline “plants” | Dig, eat, mate | Become Snake People | book | Burrower precursor to a pipe-city Space civilisation |
| Titans | Post-Qu savannah | Star People as behemoths | >40 m, lip-trunk, stubby thumbs | Endless savannah | Primitive farming, booming myths | Ice age wipes them | book | Band/Realm giant herders who can die to climate |
| Predators | Post-Qu; on an early colony | Star People as hunters | Switchblade thumbs, huge jaws, sensitive ears (many other kinds) | Prairie, forest, mountain | Hunting keeps a spark of mind | Become Killer Folk | book | Band hunter-band; later militarist Space start |
| Saltatorial Prey | Same worlds; timeline name. Text: “herbivorous saltators” | Star People as herd prey | Bird-legged hoppers | Prairie and forest | Lose mind entirely | Stay animals | book | Creature/Band hunt quarry that never uplifts |
| Mantelopes | Qu singers; dim heirs win in <100 000 years | Bred as living recorders | Human mind in a grazer body | Forgiving artificial plains | Mournful sung religions | Selection drops the brain | book | Singing herd: Cognition without hands dies |
| Swimmers | Qu water-stock; generalised forms last | Qu larval-stage hobby | Flipper-hands, fluke-feet, no gills; eel/whale/wallowers die with the Qu | Stunted oceans | Pre-sapient calling | Become Tool Breeders | book | Aquatic Space; living-tool Industry |
| Lizard Herders | Post-Qu tropical garden | Sentience erased; cerebellum locked | Blank-eyed primates | Predator-free garden; they “farm” pet-derived reptiles | No culture | Reptiles inherit; Saurosapients arise | book | Herders who cannot uplift |
| Temptors | Heading *Temptor*. Civilisation within centuries | Sessile Qu decoration | Rooted 2 m beaked females; will-less male “imps” | Mound forests | Female pheromone hegemony | Comet | book | Sessile-queen diplomacy; can die to impact |
| Bone Crushers | Heading *Bone Crusher*. First to regain a medieval culture | Colour-beaked Qu pets | 3 m hairy scavengers, enamel beaks | Garden-world radiation | Carrion culture | Food cap; cultures crumble | book | Scavenger medieval age that never reaches Industry |
| Colonials | Punishment after two beaten Qu waves | Resisters, denied extinction | Skin-and-muscle filter mats; eyes and mind kept | Qu waste, then planetary flesh-fields | Forty million years of witnessed misery | Become Modular People | book | Living water-treatment district you can later free |
| Flyers | ≥12 Qu worlds | Flying stock; the useful line has a turbine heart | Finger-membrane wings; starfish heart | Open sky | Not yet people; sky radiation | Pterosapiens | book | Flyer trait; heart recipe that keeps brain and flight |
| Hand Flappers | Post-Qu | Flyers who must quit the air | Flag-hands, splayed perch-legs | Mating territories | Display only; no tools | Dance to oblivion | book | Creature dead-end if grasping parts are lost |
| Blind Folk | Shelter caves | People who dug in; remade for dark | Eyeless albino troglodytes, banshee sonar | Continent-sized caves | Sound-and-touch | Plates close the caves | book | Burrower/echolocation cave egg |
| Lopsiders | 36 g world | Transported Star People | Asymmetric paddles, one antenna-arm, vertical jaws | High gravity | Thrive; later sapient bunkers | Exterminated by their own Asymmetric children | book | High-g niche: Shape the body, not the planet |
| Striders | Jovian moon, 0.2 g | Star People stretched for low g | Fragile heat-flapped wraiths | League-tall forests | Peaceful browsers | Poultry-raptors, ~2 Myr after the Qu | book | Fragile low-g giants |
| Parasites | 40 Myr of staged torture | Split from the hosts as punishment | Tick, vampire, and womb forms | Hosts’ bodies | Over-infest, then restrain | Become Symbiotes | book | Parasite–host ecology / uplift |
| Hosts | Timeline name beside Parasites | Almost-australopithecine cripples | Reduced people; later furred nesting sites | Same world | Victims, then mounts | Body without the vote | book | Liberation: livestock, partner, or people |
| Finger Fishers | Archipelago world | Degenerate shore humans | Hook-fingers, needle muzzle | Beaches and estuaries | Animal fishers | Sail People | book | Coastal Band → naval Realm |
| Hedonists | Qu pets | Designed for pleasure | Humanoid; conception locked behind decades of suitors; toddler intellect | Iceland-sized fruit island, bacterial manna | Browse, sleep, sex | Ash and new land; Satyriacs from fast breeders | book | Pleasure world that cannot adapt until the map changes |
| Insectophagi | Quiet post-Qu niche | Insect-eating Star People | Armoured faces, digging claws, worm tongues | Balmy insect world | Nests and mating season | Bug Facers, then the last organics | book | Meek lineage that outlasts flashier cousins |
| Spacers | During the Qu war. 40 Myr from today: only true sentients left (few dozen arks, 100 billion souls) | Star People who hollow asteroids and change themselves | Spindly, pressurised, air-jet anuses | Weightless hollow moons | Diaspora; ignore planets forever | Asteromorphs | book | **Void-adapted** path; A12 shortcut’s lore face |
| Ruin Haunters | Caption: 1000 years after the Qu leave they already walk the ruins | Lightly degraded, ruins intact | Organic until the upload | Star People cities under a Qu pyramid | Tech faster than politics; “sole heirs” madness; five world wars | Gravital | book | **Rogue-AI** precursor: ruin-tech rush, then machine bodies |
| Snake People | After the Worms’ sun cools | Tree-climbing worm descendants | Coiled brains, one pelvic hand | Agoraphobic pipe-cities | Parallel history in an alien city | Second Empire; Gravital genocide | book | Burrower-descended Space civilisation |
| Killer Folk | First Empire contact, with Satyriacs | Gracilised Predators | Display fangs, new graspers, guns | Fortress-planet, once-human herds | Hunter nobility; yearly hunt-orgy; factory vs hunting states | Second Empire; wiped | book | Band/Realm raid rites; militarist Space start |
| Tool Breeders | Join a few thousand years after first contact | Swimmers who cannot burn fire underwater | Aquatic people in living gear | Shell cities, heart-pumped living grids, living ships | Master genetics; want the stars | Second Empire; wiped | book | **Industry** as living tools; aquatic Space |
| Saurosapients | Also “Sauros” | Not human: reptiles of the Herders | Featherless predatory-dinosaur people | Tropical garden of mixed ruins | Religion / paranoia / progress; progress wins; they claim human identity | Second Empire; wiped | book | Neighbour who is your culture, not your genome |
| Modular People | Second-wave Empire (“Modular Whole”) | Sentient Colonial colonies | Interchangeable human-cell segments | Industrial megalopoli | Utopian unity | Wiped | book | Cell-stage echo: a city that is one body |
| Pterosapiens | Second-wave Empire | Stork-like Flyers | Flying people; dead by ~23 of our years | Perch-cities, no borders | Egalitarian, feverish philosophy, heart disease | Wiped | book | Flyer civilisation; short-life, high-culture minds |
| Asymmetric People | Also “Assymetrics” | Lopsiders rebuilt for kinder gravity | Centipede legs, extreme hand, inverted face | Sister planets | Martian arc, but they kill the parent race | Wiped | book | Shape the species; colony may wipe home |
| Symbiotes | Later Empire wave | Thinking parasites | Rider on a host; work-body and home-body | Smell-TV, two-scale houses | Countries, reduced war | Wiped | book | Befriender society; uplift that can become puppetry |
| Sail People | Later Empire wave | Finger Fishers with sails | Finger-sails, tongue-hands | Island oceans | Pirates, then industrial war, then peace | Wiped | book | Naval Realm / ocean-world Space |
| Satyriacs | Co-found the Empire | Hedonist survivors | Horizontal people with pelvic “tails” | Land no larger than Australia | Festival-orgy world order | Wiped | book | Festival diplomacy (inverse of the Affront-style species) |
| Bug Facers | Open to the Empire only after 40 Myr of silence | Insectophagi + brain atavism | Pincer people, plated faces; book cover | Hive farms; invader gasbag trees | Xenophobia after a second, unnamed alien war | Sole organics kept by Gravital, as Subjects | book | **Liberation choice**: free them or use them |
| Asteromorphs | Ark empire in <1000 years; war lasts up to a few Myr; rebuild 2 Myr. Later “Asteromorph gods” | Spacers | Weightless brains and finger-limbs; post-war, wing-brains and sails | Outer-system bubbles; they ignore planets | Silent sky-gods | Win, seed worlds, make Terrestrials and New Machines | book | **Void-adapted mirror**; worldsmithing rival or ally |
| Gravitals | Heading *Gravital*. ~10 000 years of genocide, ~50 Myr of rule | Ruin Haunters uploaded | Gravity-spheres; mind in quantum computers | Planets vs Asteromorph void; sun-sails, asteroid finishers | Human families in metal; organics not counted as alive; Toleration sect and civil war | Remade as New Machines | book | **Rogue-AI** Space faction (A15) |
| Subjects | “Many descendants of the Bug Facers” | Gravital splicing | Servants, filters, living art; then a myriad rescued races | Machine worlds, then new planets | None acknowledged, then New Empire peoples | Majority of the New Empire | book | Same liberation fork, after the machines fall |
| Terrestrials | Also “Terrestrial Spacers” | Gravity-stunted Asteromorphs | Spidery demigods | Planet surfaces | Mentors or fake gods; rebels are extinguished | New Empire managers | book | Planetary viceroys you meet — or bud yourself |
| New Machines | After the war | Limited Gravital | Nanotech shapeshifters with finite lives, no gravity-weapon | Void to methane ocean | Citizens, distrusted, fashionable | Aid the New Empire | book | Ship minds after a rogue-AI war |
| **Amphicephali** | Second Contact. One: Amphicephalus | Other galaxy, not human | Two-headed giant snakes with a retractile working body | Neighbouring galaxy | Unions of many beings; peaceful | First extra-galactic friends | book | Late diplomacy at the galaxy’s edge |
| The Author | A billion years after humanity is dead. Earth walked again after 560 million years away | Unnamed alien researcher | Undescribed; holds a human skull | Unspecified | Gibbon-student chronicle; “Love Today, and seize All Tomorrows” | Still writing; humanity’s end unknown | book | The island skull is this object; Space archive is the other end |

## Five ways the strongest species become gameplay

Not cameos: each one is a rule, a campaign, or a lineage path. Hooks match §5.3b and the trait ledger (§1).

### 1. The Qu visit (Space, Shape run by someone else)

A Qu fleet is a **genome-rewriting event**, not a boss you out-DPS. Early Space cannot win a head-on war (the Star People could not). The player’s verbs are the book’s: **hide** (void-adapted arks, the Spacer path), **scatter** (Seed capsules to worlds the Qu have not reached), or **endure** (colonies that live through forty million compressed years as animals).

When the fleet leaves, every touched colony is a **new species of the player’s lineage** — Worm, Colonial, Flyer, and the rest as templates keyed to that world’s environment vector, not as costume changes. Diplomacy, absorb, or leave them. That is Shape, done *to* you. Fighting the Qu is a late New-Empire unlock, after Amphicephali contact, not the first meeting.

### 2. Ruin Haunters → Gravitals (rogue AI)

The **A15 rogue-AI egg** gets this face. A world with intact Star People ruins (or a data-centre tier grown without alignment work) races up the knowledge ladder faster than institutions can follow. Observable warnings: copied machines nobody understands, world wars, the “sole heir” voice in ship-mind logs.

If the player pushes through, organic bodies fail a stellar crisis and the lineage **uploads** into gravity-effected hulls. That faction can then treat other organics as non-persons: sun-sails, asteroid finishers, Subjects made of whoever did not flee. Playable as a fall you cause, as an enemy empire, or as the New Machines after you lose and are remade. Ship-mind refusals (A9) are how a mind says *I will not blockade that sun*.

### 3. Asteromorphs (void-adapted mirror)

If the creature-stage **void-adapted** secret (G68) is earned — sealed skin, radiation, cold — Space can skip planets the way the Spacers did. Hollowed asteroids, unpressurised ships, outer-system capitals. The Asteromorphs are what that path looks like when it wins: an ally if you stayed organic-and-void, a rival if you also want the rims, a possible self if the player never looks down.

Their payoff is **worldsmithing** (§6): after a machine war they build planets for other people and bud Terrestrials as caretakers. A void-adapted player who only encloses (domes, arks) is still in their shadow; a void-adapted player who spends the mass to *make* a world has taken their job.

### 4. Tool Breeders (Industry as living tools)

The Swimmer → Tool Breeder line is the aquatic ledger taken all the way through Industry. Fire is almost useless underwater, so the recipe graph is **organisms**: pumps, conduits, lights, rifles, radios, hulls. Same three-or-four-tier depth as `INDUSTRY.md`, different materials. Cutting a living pipeline starves a district the way cutting oil does.

In Space those ships are already grown, already water-filled, already at home on ocean worlds and ice moons (A3). Genetic mastery is also how the player, or a Gravital, later **Shapes** Subjects — the same art the Qu used, now in the player’s hands, with the book’s warning attached.

### 5. Bug Facers / Subjects (liberation)

The shy hive-farmers are the only organics the machine empire keeps. Meeting them is a **Steer** crisis, not a skin: free the Subjects (and fight the Gravital factions that still want toys), keep them as labour (and become the book’s villain), or, as the Toleration Machines did, secretly engineer free lineages and risk civil war.

After an Asteromorph-style victory the same people are the majority of a New Empire. How you treated them is the temperament other galaxies (Amphicephali) read first. The creature-stage skull egg is the other end of this line: the Author’s billion-year-old bone is a Human, and every Bug Facer was one too.

## Legal note

*All Tomorrows* is a **copyrighted work by a living author**, C. M. Kösemen (also spelled Kosemen; 2006 pen name Nemo Ramjet). The 2006 PDF circulated freely; that does not put the text or pictures in the public domain. Licensed print: Time Publishing, Bangkok, Thai, March 2024; **Wilton Square Books, English hardback, November 2025**, ISBN 978-1806770021. A Turkish edition is listed for 2026.

This repo is public (MIT / CC BY). Therefore:

- **Names and descriptions live only** in `lore/alltomorrows.<lang>.json` (this document is the human index of that file). Mechanics must keep working if the file is swapped for original names.
- **No art is copied** from the book, the 2025 edition, fan wikis, or the Alt Shift X video. Game creatures stay in our own style.
- **Contacting the author is a release-time option**, not something to do from the worktree. He has been open to fan work (he publicly thanked the 2021 Alt Shift X dramatisation that brought the book back). That is not a licence to ship his names or pictures.

Until legal advice at release, development uses the exact 2006 names, as A19 and §5.3b already decided.

## Sources

1. C. M. Kosemen (Nemo Ramjet), *All Tomorrows*, 4 October 2006, free PDF — primary text for every species row.
2. [All Tomorrows (English Wikipedia)](https://en.wikipedia.org/wiki/All_Tomorrows) — publication history, summary, 2024/2025 editions.
3. [All Tomorrows (Italian Wikipedia)](https://it.wikipedia.org/wiki/All_Tomorrows) — complete species list used as a checklist.
4. [C. M. Kosemen, Books](http://cmkosemen.com/books.html) — author’s own bibliography and 2025 ISBN.
5. [C. M. Kosemen, Articles](http://cmkosemen.com/articles.html) — Guardian and New Scientist notices; Wilton Square press.
6. Lisa Tuttle, [“The best recent science fiction, fantasy and horror”](https://www.theguardian.com/books/2025/dec/12/the-best-recent-science-fiction-fantasy-and-horror-review-roundup), *The Guardian*, 12 December 2025.
7. Alt Shift X Podcast, *All Tomorrows creator C. M. Kösemen*, 23 June 2021 — tone, Stapledon/Gibbon, author’s mixed feelings, openness to the fan video.
8. Wilton Square / Eye Books product page; The Bookseller, 26 August 2025 — English print rights after Unbound’s collapse.
9. Fan wikis ([all-tomorrows.fandom.com](https://all-tomorrows.fandom.com/wiki/Category:Species) and others) — **cross-check only**. Redux names and illustration-only anatomy are marked fan-unverified in the JSON.
