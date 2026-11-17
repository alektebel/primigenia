# Industry stage: design sketch

Status: **draft, 2026-11-17.** It expands `ARC-PLAN.md` §4 into a concrete
shape, following the owner's direction: simple logistics (5–10 resources and
their combinations) plus a full military RTS in the style of Total Annihilation
and Planetary Annihilation, with nukes and satellites. Exact numbers come
in the stage's own design session (Q56).

## 1. The core idea: a flow economy feeding a war machine

TA and PA show that a **flow economy** can drive huge battles: you don't stockpile,
you manage *rates* (metal/s, energy/s), and every factory takes from the flow.
Factorio's depth comes from the spatial puzzle of belts, and that would compete
with the war for the player's attention. So:

- **Keep from Factorio:** a small **recipe graph**. Raw resources combine into
  materials, materials into components, components into machines and units.
  Bottlenecks and ratios matter.
- **Keep from TA/PA:** flow rates, building with construction units, huge
  armies, land/sea/air/orbit, artillery, nukes and anti-nukes, globe maps.
- **Leave out:** belts item by item, and inserters. Logistics happens at
  the **map** scale: districts connected by rail, ships and pipelines that you
  can build, defend and **cut**.

The result is supply chains you can see and that make strategic sense: bomb the
refinery and the enemy's tanks run dry in two minutes.

## 2. Resources and recipes (about 30 items, 3–4 levels deep)

| Tier | Items |
|---|---|
| **Raw (8)** | wood, stone, iron ore, copper ore, coal, oil, uranium, rare earths |
| **Materials (8)** | steel (iron + coal), concrete (stone + energy), copper wire (copper), fuel (oil), plastics (oil + energy), explosives (coal + energy, coal-tar chemistry), alloys (steel + rare earths), enriched uranium (uranium + lots of energy) |
| **Components (6)** | engines (steel + fuel), electronics (copper wire + plastics + rare earths), armour plate (alloys), munitions (steel + explosives), reactor cores (enriched uranium + alloys), rocket stages (alloys + engines + electronics) |
| **Products** | units, buildings, satellites, nukes, the launch vehicle |

Energy (MW) is a separate flow, as in TA. Coal plant → oil → hydro/geothermal →
nuclear → fusion (via the Knowledge system, A6). Each source has a planet health
cost (§6).

Each factory has one recipe at a time and a fixed throughput. A district gets
its **input from the logistics network** and its **output goes back** into it.
The UI shows flow per item (produced, consumed, and what's starved), as in
Factorio's production graph.

## 3. Logistics: the network

| Link | Capacity | Speed | Vulnerability |
|---|---|---|---|
| Road / truck | low | slow | partisans, air |
| Rail | high | medium | artillery, bombers, sabotage at bridges |
| Ship lane | very high | slow | submarines, naval blockades |
| Pipeline (oil, fuel) | high, one item | fast | anything that hits it |
| Air freight (later) | low | fast | anti-air |

Districts are nodes, links are edges. The C sim solves flows each tick
(deterministic, capacity-limited). Cutting a link reroutes or starves the
flow, and the UI shows it on the globe. That's where the logistics strategy lives.

## 4. War: TA/PA scale on a globe

| Domain | Units (tiers ≈ eras: steam → diesel → atomic → space) |
|---|---|
| Land | infantry, artillery, tanks, mobile anti-air, missile launchers, engineers (construction) |
| Sea | destroyers, battleships, carriers, submarines, transports |
| Air | fighters, bombers, scouts, transport planes |
| **Orbit** | **satellites**: recon (reveals the map), comms (bigger command radius, precision), early warning (spots launches), anti-satellite missiles; late: **orbital laser platforms** (deadly, precise, slow to recharge; they draw huge power and can be shot down by anti-satellite missiles) |
| **Strategic** | **nukes** (ICBMs), anti-nuke interceptors, silos; fallout |

- **Scale target:** 2,000–5,000 units in play, simulated in C at the fixed tick
  (flow-field pathfinding over the globe, spatial hashing, a fixed cost per unit).
  Rendered with MultiMesh instancing and imposters at distance.
- **Commands:** TA-style queues, waypoints, rally points, area commands, factory
  repeat orders, plus PA-style **strategic zoom** (from a unit up to the whole globe)
  with icons. The benchmark uses the same macro orders (Q15).
- **Fog and radar:** radar towers, scouts, recon satellites. Information is a resource.

## 4b. Every unit runs on energy (owner idea, A10)

Every unit carries **fuel or charge**: combustion units use fuel, later electric
units use batteries, nuclear units almost never need refilling. Out of energy,
a unit slows down and then stops.

To keep this strategic and not tedious:
- **Refuelling is automatic** inside a **supply area**: depots, fuel trucks,
  charging stations, tankers at sea, air refuelling. You build the network; units
  top themselves up.
- **The supply area is the front line.** An offensive that outruns its depots
  stalls. Cutting the enemy's fuel trains or pipelines stops their armies.
- **Auxiliary units:** fuel trucks, mobile chargers, field repair, forward bases.
  They're cheap and soft, so protecting them matters.
- **The UI shows it** as a supply overlay and as a small energy bar on each unit,
  with warnings before units run dry.

This links the economy (§2) and the logistics network (§3) straight to the battlefield.

## 4c. Data centres and your AI (owner idea, A11)

You can invest in **data centres** (electronics + energy + Knowledge) to build
your own AI. A better AI takes more work off you: instead of ordering every unit,
you **delegate with simple prompts** ("defend the northern rail line", "keep
steel above 40/s", "take that island").

| AI tier (in-game) | Model size it stands for | What it can be given |
|---|---|---|
| 1 | 0.5B | one district or one army group, simple standing orders |
| 2 | 1B | several groups, economy targets, reacts to attacks |
| 3 | 1.5B | a whole front or the whole economy, multi-step plans |
| 4 | 2B | several fronts at once, anticipates, reports and proposes |

- **The gameplay effect comes from the tier, not the player's GPU.** The tier
  decides how many tasks, how many units and how far ahead the C AI plans.
  The language model only understands your prompt and writes the reports
  (ARC-PLAN §10). Where the hardware allows, higher tiers also load a bigger
  local model; elsewhere they fall back to a smaller one with the same gameplay.
- Data centres use a lot of energy (planet health) and are targets.
- In Space this grows into the ship minds (ARC-PLAN §5.2): your AI becomes the
  first mind.

## 5. The globe

A **stylised small planet** (PA-like readability, not Earth scale): a cube-sphere
assembled from generated islands and continents (the W generator gives the
regions). Oceans matter, since aquatic and naval lineages have an edge. You can
always see the curve of the horizon, so artillery and missiles arc visibly.
The home island from the earlier stages stays recognisable on the globe.

## 6. Planet health and nukes

One meter, 0–100, that feeds into Space (A3):
- coal and oil pollute; deforestation, strip mining and dams all cost a bit;
- **every nuke costs a lot**, with fallout zones (no farming, radiation) and a
  nuclear-winter threshold where the whole planet's farming collapses;
- clean energy and reforestation restore it slowly;
- the globe shows it visibly: smog, dead forests, higher seas, scarred craters.

Nuking wins wars and hurts the arc. That's the trade-off the stage is about.

## 7. Winning and the bridge to Space

Industry ends with the **first orbital launch**: rocket stages + a launch
complex + enough Knowledge. Rivals race toward the same goal. Rivals can also be
defeated outright (conquest) or out-produced (economic dominance), as in
Realm. Satellites are the first step: they're already in orbit when Space begins.

## 8. Fit with the lineage

Some traits change the stage (ARC-PLAN §1.2): aquatic → undersea districts and
naval doctrine; burrower → buried factories (nuke-resistant); flyer → early air power;
silk-spinner → cables and an early space elevator; void-adapted → cheaper launches;
fire-breather → better munitions.

## 9. MVP (I1–I6 in ARC-PLAN §7)

8 raw resources, ~15 recipes, rail + ship, 3 energy sources, land + air +
satellites + nukes, 2 rival nations, planet health, the launch. Sea war, the
full roster and fusion come after the MVP.
