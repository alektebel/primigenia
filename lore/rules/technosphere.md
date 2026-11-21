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
