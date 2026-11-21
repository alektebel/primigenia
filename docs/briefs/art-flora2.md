# Brief: flora quality pass 2 — from low-poly cards to naturalistic (DESIGN A24)

Worktree `/home/diego/Desarrollo/cpore-wt/art-flora2`, branch `art/flora-quality` (from main). Work only here.
**Your sandbox cannot write git metadata and has no X11:** do NOT commit or take screenshots; leave work uncommitted and write
`docs/FLORA-ART2-REPORT.md` (intended commits, what you changed, perf impact estimate, a capture checklist for Sonnet). Never touch
`.codex/`, `.kimi-code/`, other worktrees or the main checkout. No edits to `core/` or C goldens.

Flora v1 is merged (your earlier work + Sonnet's fixes): read `docs/FLORA-ART-REPORT.md` (honest assessment + open questions) and look at
the evidence images in `docs/evidence/godot/flora/` (you can read JPGs as files). The owner wants the island to look natural, made "con
cariño", not low-poly. Problems seen: trunks are faceted dark prisms with flat orange stripes (forest_edge.jpg), buttresses are flat
triangular fins, crowns are stacked cutout cards that read dark/black, everything flat-lit; sulfur/ember crusts are faceted flakes and the
sulfur is too saturated; moss is blocky; Perlilla berries invisible at distance; low/high tiers look the same near the camera; one oversized
flat plank on the nest rim; white ellipses in the meadow (find out what they are: not flora); `snow_slope` and `soga_de_dosel` evidence
cameras badly framed.

Do: smooth/rounder trunks with more radial segments near the camera (LOD), tapering and bark normal/albedo from the photographic atlas or a
procedural bark shader (vertical fissures, lichen patches), buttress roots as curved flares; foliage as clustered leaf cards with proper
normals (spherical/bent normals toward crown centre), translucency, AO darkening inside crowns, hue variation per instance, softer alpha
edges (alpha-to-coverage where gl_compatibility allows); crusts and moss as ground decals/blended shader layers instead of flakes; berries
larger clusters with contrast; per-tier near detail (high: more leaf cards and segments). Keep it deterministic, gl_compatibility working,
and the low tier budget no worse than v1 (report batches/instance counts per tier). Update tests for any new parameters; run `--check-only`
and the headless suites (`godot-test`, `godot-ui-test`, flora tests). Fix the nest plank and the meadow ellipses if they are flora/nest code;
if not, report what they are.
