# The sixteen creature types

**Draft — owner approves names, descriptions, initial thresholds and perks.**
English and Spanish names below are alternatives, not established lore.
Types describe what a creature does; the player never chooses one in a menu.

Four integer scores range from −100 to +100. For each axis, score =
`100 * (positive - negative) / (positive + negative)`, truncating toward zero;
a zero denominator gives 0. A score inside **[−10,+10]** leaves the
axis **undetermined**, shown as "?" (a creature with no deeds is "?-?-?-?", name
"Undetermined" / "Sin definir"): you become what you do. Once an axis has left the dead
zone it keeps its letter through later dead-zone scores and later generations, until a
score crosses to the other pole. The exported type index holds the letters in bits 0-3 and
the determined axes in bits 4-7.
All arithmetic uses uint64/int64 intermediates; UINT32_MAX deed vectors are safe.

| Axis | Negative contribution | Positive contribution |
|---|---|---|
| A ↔ S | 3 × kills + intimidations | 3 × befriends + gifts |
| H ↔ G | meat eaten + hunts | plants/fruit eaten + foraging |
| R ↔ I | distance_cm / 1000 + 10 × new places | nest_ticks / 100 + 10 × (building + digging + hoarding) |
| B ↔ W | 3 × fights started + 2 × (bigger approaches + deep dives) | 2 × observations + stealth + 3 × early flights from fights |

Division inside a contribution happens before normalization. At 10Hz, ten seconds
at the nest has the weight of ten metres of travel. These are initial, tunable
numbers. “Fights fled” currently comes from the completed flee outcome; an early
flee discriminator can replace that award producer when social/stealth arrives.
Unbuilt actions contribute zero until their mechanics award deeds.

The type is live for the current generation and frozen into its generation and
a `type` ledger entry during evolution. Letter bit order in the exported type index is
Approach, Diet, Way of life, Temper; positive bits are S, G, I, W. Codes and
names are exported to later stages and shown in the family tree.

A type, its name and its perk exist only when **all four axes are determined**; before that there is no perk (the base amount is returned unchanged). Each of the sixteen types grants **exactly one** perk. Priority is Wary → observe, otherwise
Industrious → nest, otherwise Social → first-meeting trust, otherwise meat.
No combat damage, movement, health, cooldown or stamina stat changes.

| Code | English draft | Spanish draft | Description | One perk (initial) |
|---|---|---|---|---|
| A-H-R-B | Flint Stalker | Acechador de sílex | Ranges far and meets danger head on. | Carcass food +10% |
| S-H-R-B | Hearth Fang | Colmillo del hogar | Shares the hunt and stands beside companions. | First-meeting trust +10 |
| A-G-R-B | Bramble Runner | Corredor de zarzas | Forages boldly and defends each find. | Carcass food +10% |
| S-G-R-B | Orchard Sentinel | Centinela del huerto | Gathers a circle and guards its harvest. | First-meeting trust +10 |
| A-H-I-B | Den Forger | Forjador de guaridas | Builds a strong den with a hunter's resolve. | Nest action duration −15% |
| S-H-I-B | Hearth Keeper | Guardián del hogar | Welcomes companions into a well-stocked den. | Nest action duration −15% |
| A-G-I-B | Root Mason | Albañil de raíces | Shapes the land and keeps intruders at bay. | Nest action duration −15% |
| S-G-I-B | Grove Tender | Cuidador del soto | Builds a home around shared abundance. | Nest action duration −15% |
| A-H-R-W | Dusk Tracker | Rastreador del ocaso | Tracks prey across the land with patient caution. | Observe duration −20% |
| S-H-R-W | Quiet Companion | Compañero discreto | Travels with companions and watches before acting. | Observe duration −20% |
| A-G-R-W | Seed Wanderer | Viajero de semillas | Carries seeds between safe paths. | Observe duration −20% |
| S-G-R-W | Meadow Listener | Oyente del prado | Finds company by listening at the meadow's edge. | Observe duration −20% |
| A-H-I-W | Burrow Warden | Vigía de la madriguera | Guards the den through watchful hunting. | Observe duration −20% |
| S-H-I-W | Lantern Host | Anfitrión del farol | Keeps a warm home and a careful welcome. | Observe duration −20% |
| A-G-I-W | Moss Architect | Arquitecto de musgo | Builds shelter quietly and guards the stores. | Observe duration −20% |
| S-G-I-W | Patient Gardener | Jardinero paciente | Tends a shared home with patient attention. | Observe duration −20% |

`cp_stage_lineage_perk(world, kind, event_serial, base_amount)` applies the current
type's sole perk. For trust/meat, amount is a reward; for nest/observe, amount is
an action duration in ticks. Durations round up, food rounds down. Each producer
must issue strictly increasing, nonzero serials **per kind per generation**.
Repeated or older serials return 0 (duplicate: do not apply the event again).
Other kinds return the unchanged base once. Deduplication cursors are hashed,
saved and reset at evolution. `cp_type_adjust` is the pure, non-idempotent helper;
producers should use the world entry point rather than re-adjusting a result.

Wired into the social loop (`stage_social.c`, tick + 1 as serial): Social, +10 trust at
the first meeting (`contact`; a cousin adds its +20 first, through the same trust model);
Hunter-line, +10% food per carcass bite; Wary, a clue takes 40 instead of 50 ticks
(`obs_need`, hashed only when set). The nest perk waits for the nest-building action,
which does not exist yet. Deeds from the loop: bond made (befriend, once per creature),
each gift, won intimidation, each carcass bite (meat) and each clue (observation);
kills, fights, fled, night, nest time and distance come from `stage_world.c`.
`tests/test_lineage_social.c` covers all of it.
