# Rule: the road to a technosphere needs a way to make things hot

Owner, 2026-11-21: a civilisation cannot progress past the Band/Realm stages without a sustained source of high temperature to work materials (smelting, glass, ceramics, steel), or another path the lore council invents and justifies. This is a hard gate on every world, decided by its own physics.

## The default path: open fire
Balbi & Frank, "The oxygen bottleneck for technospheres", *Nature Astronomy* (2023), DOI 10.1038/s41550-023-02112-8 (`lore/references.json` id `balbi_frank_2023_oxygen_bottleneck`): open-air combustion needs a minimum oxygen level (they argue roughly ≥ 18 % O₂ by partial-pressure context for sustained fire and metallurgy; below it, fire does not keep burning, so no smelting). Too much oxygen makes fire uncontrollable instead. Each world's oxygen partial pressure (its atmosphere facts) decides whether this path is open, hard, or closed. Use the paper's numbers, not invented ones; when a world sits near the threshold, say so.

## Other paths (the council proposes and the astrobiology referee judges)
Worlds without usable fire must either stall (a legitimate, interesting outcome: a brilliant species stuck before metal) or find another route, each with a causal chain like every other lore fact (A22). Examples to start from, not a closed list:
- **Geothermal / volcanic heat** used directly (lava, vents) for smelting near hot spots: tech tied to geography.
- **Concentrated sunlight** (mirrors, lenses from natural crystals or polished shells) on bright worlds.
- **Electrochemistry**: bio-electric organs (an electric lineage trait carried from the creature stage) or lightning capture, reducing metals by electrolysis instead of fire.
- **Other oxidisers** in the atmosphere or ocean (chlorine, fluorine compounds, peroxides) giving a different "fire" chemistry.
- **Biological metallurgy**: organisms that concentrate or reduce metals (biomineralisation, bacterial ore reduction) farmed instead of smelted.
- **No metals at all**: a materials path through ceramics, glass, silk-like composites, bone or engineered wood, with its own ceiling.

## How the game uses it
- Primigenia (F5: O₂ 21 %, pO₂ ≈ 0.34 bar, fuels wet, fire a drought-year event): the fire path is open but fire is rare and seasonal — discovering and keeping fire is a real milestone of the Band stage.
- Every world file gets a **technosphere fact**: which path(s) are open, the gate value (e.g. O₂ partial pressure vs the threshold), and what that means for its tech tree.
- The tech-tree council (A30) builds Band → Realm → Industry → Space on top of these facts; a lineage's traits (e.g. bio-electric organs) can open an alternative path.
- In Space, other species' worlds follow the same rule, which explains why some never left their planet.

## Extension: oxygen sets every flame, not only metal (proposal 2026-11-21, owner asked; D-28, 48 h auto-accept)
One fact, `atmosphere.o2_pct` plus fuel moisture, drives every combustion in every stage. Thresholds are starting values (Balbi & Frank 2023; fire-ecology work on flammability limits). They are checked by the lore validator and, once O₂ is in C, by the game tests.

| Stage | What burns | Rule |
|---|---|---|
| Creature | **Flame breath / flamethrower** (fire gland + resin fuel, G50/A38) | Works only where O₂ is about 16% or more and outside water. Below that, or underwater, the same organ evolves into a **hot-steam or acid jet** (a different move with the same recipe slot). On Primigenia (21%) the flame works, but wet fuel shortens its range in rain and at the shore. |
| Creature | **Wildfire** (C5: the grass does not burn yet) | Spreads only above about 18% O₂ and with dry fuel. Above about 25%, even wet plants burn, and the world needs fire-adapted flora (bark, serotinous seeds) in its lore. |
| Band / Realm | Cooking, fire-hardened tools, pottery, smelting | As in the A37 table above: oxygen gates open fire, and the alternatives (geothermal, sunlight, electrochemistry) open other routes. |
| Industry | Furnaces, steam engines, combustion vehicles (A10: units run on fuel) | Combustion efficiency scales with O₂. On low-O₂ worlds, industry runs on **electric, geothermal or bio-electric** power: the units run on **charge** (A10 already allows it), with no fuel trucks. On high-O₂ worlds, fire risk becomes a factory hazard. |
| Space | Rockets | Oxidiser carried onboard, so this does not depend on the world, but a low-O₂ civilisation reaches space later unless it found an electric route. |

**For the council and the food web (`docs/briefs/trophic-web.md`):** creatures that use fire, smoke or heat must state the O₂ and fuel they depend on. Fire-adapted flora must exist wherever wildfire can.
**For C (later, milestone 7):** add `o2_pct` to the world parameters (an exact snapshot bump, next free 12). Flame and wildfire read it; Primigenia stays at 21.
