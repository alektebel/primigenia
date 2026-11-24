# Brief: procedural flora, rocks and the nest for the Godot island (from the approved-draft flora canon)

Worktree `/home/diego/Desarrollo/cpore-wt/art-flora`, branch `art/flora-generators` (from main `claude/v0.1-restore`). Work only here.
**Your sandbox cannot write git metadata and has no X11:** do NOT commit or take screenshots. Leave work uncommitted and write
`docs/FLORA-ART-REPORT.md` (intended commits per slice, what you verified, perf numbers, open questions, and a capture checklist
for Sonnet, who will commit, capture xvfb evidence and integrate). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.

Today the Godot island (`godot/game/island/`) has terrain (v5 visual heightfield, photographic rock/soil Texture2DArray atlases in
`look.gd`/`terrain_chunks.gd`), grass (`grass.gd`), rivers, water, clouds — but **no trees, no shrubs, no rocks as props and no nest
model**. Build them.

Read: `docs/lore/FLORA.md` and `lore/flora/*.json` (16 plants, schema cpore.plant/1: growth form, heights, habitats, zonation coast→summit,
succession on lava; every plant has its shape facts and causal chains — the art must follow them, e.g. Nieblón 12–22 m fog-drip
buttressed trees with small leathery leaves under 1.6 bar air and 1.6× wind; Madre de agua 28–32 m at the spring; Rodela de nieve
1.5–3 m giant rosettes at the snowline; Paja dulce in the start valley; red-purple pigment = UV/alkaloid honest signal), `docs/DESIGN.md`
A24 (naturalistic look, not cartoon), `docs/TERRAIN.md` (biomes, heights, slope, rivers, start valley, crater), `godot/game/island/*`
(how terrain/grass are placed, chunked and LOD'd; `Game.visual_ground` for heights), `docs/godot/` perf notes and `make godot-terrain-bench`.
More plants for the start valley (a fruiting shrub, a visible flower, a mid-size tree, a red-veined poison plant) are being designed by the
lore council right now: make the system data-driven so adding a plant = adding a data row/recipe, not code.

## Slices
S1 **Generator core.** A deterministic procedural plant generator in GDScript (or a small C++ addition to the existing GDExtension if a
hot loop needs it; never in `core/`): L-system/space-colonisation or parametric branching for trees and shrubs, rosettes, grass tufts,
ferns, vines, moss/lichen/crust decals, algae ribbons, fungus clusters; species parameters read from a data file you derive from
`lore/flora/*.json` (`godot/game/data/flora.json`). Seeded per instance (world seed + cell), bit-stable. Naturalistic materials: bark,
leaves with alpha cards + subsurface-ish transmission, wind sway in the vertex shader (stronger with 1.6× wind), per-species colour
from the canon. gl_compatibility must work; Forward+ may add quality.
S2 **Placement by zonation.** Place instances by biome/height/slope/moisture/river distance per FLORA.md zonation and habitats; succession
stages on lava fields; Madre de agua at the spring; nothing on the certified route corridors' steep facets or in rivers; keep clear the
nest area and creature spawn points. MultiMesh + LOD/impostors for distance; chunked like the terrain. Visual only: the sim does not
see plants yet (no collision changes; keep all C goldens untouched).
S3 **Rocks as props.** Boulders, scree, outcrops using the existing photographic rock atlas (triplanar), placed by slope/geology.
S4 **The nest.** A nest model at the setup nest position (start valley, Paja dulce straw, twigs, a scraped hollow), visible from afar
as a landmark, readable in the diegetic UI's sense (no glowing marker).
S5 **Perf + tests.** Budgets for the AMD iGPU tier (low) and the RTX (high) via settings (density, LOD distances); headless tests for
determinism (same seed → same instance list hash), data validation against lore ids, placement rules (none in deep water, none on
>1.26 grade for trees). `--check-only` and headless suites: `godot-test`, `godot-ui-test`. Report frame-time estimates headless and
what Sonnet must measure on xvfb.
