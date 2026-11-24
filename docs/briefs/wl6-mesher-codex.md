# Brief (Codex Astra): WL6 cave mesher (the deterministic C++ part)
Worktree `/home/diego/Desarrollo/cpore-wt/wl6-cave`, branch `art/wl6-cave-mesher`. **Your sandbox cannot write git metadata
and has no X11: do NOT commit or take screenshots.** Leave work uncommitted; write `docs/CAVE-MESHER-REPORT.md` (intended
commit messages, what you verified, open questions). Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout.
Read `/home/diego/Desarrollo/cpore-wt/_agent/briefs/world-look-plan.md` §0 (caves diagnosis) and §1 WL6 (the slice). Your part:
- `godot/extension/cave_mesher.cpp/.h` + binding `CporeTerrain.cave_mesh(params) -> Dictionary` (vertices, normals, indices,
  plus dressing anchor lists: stalactite points with down-normals, floor wet patches, wall flowstone points), registered in the
  GDExtension build (see how the existing extension sources/bindings are built in the Makefile/SConstruct).
- The SDF exactly as the plan says: walkable volume (passage box + chamber cylinder from the C rule in `core/` / `cave_site.gd`,
  floor at floor_h) unioned with non-walkable volume (ceilings 3–9 m, alcoves, dome with a collapse chimney), 3D value/gradient
  noise displacement only outward/upward beyond footprint + 0.6 m; marching cubes on a 0.4 m grid, smooth normals, deterministic
  (seeded, integer hash noise, no libm trig), 20–60k triangles; the mouth opening as a parameterised hole.
- A headless GDScript test (`godot/game/tests/test_cave_mesh.gd` + make target `godot-cave-mesh-test`) implementing the plan's
  acceptance: 500 samples, floor = `cave_site.adjust()` ± 2 cm inside the footprint, no triangle inside the walkable volume below
  2.5 m clearance, same params → identical mesh hash, triangle count logged.
- Do NOT change `cave_site.gd`'s visuals or the C walkable rule; a Sonnet will do the art/integration afterwards. Build the
  extension and run the test headless (`godot --headless`, `timeout`, `nice -n 10`); `make test` must stay green.
