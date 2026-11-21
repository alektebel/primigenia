# Planning brief (Opus): make the island look natural and alive
You PLAN; you do not write project code. Output: `/home/diego/Desarrollo/cpore-wt/_agent/briefs/world-look-plan.md`, a
plan split into self-contained implementation slices (each: goal, files, method, acceptance with evidence, size, which
implementer: Sonnet subagent for Godot/visual work with screenshots, Codex for headless C/terrain work), ordered by impact on
how the game looks in the first 10 minutes. You may run read-only commands and render xvfb captures of the current game
(software GL only: `LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a godot --rendering-driver opengl3 ...`; see Makefile evidence targets,
`timeout`, `nice -n 10`; the owner is using the GPU, never use it) to diagnose. Repo: /home/diego/Desarrollo/cpore (main).
The owner's words after playing on the RTX (Forward+):
- "Grass still looks weird."
- "The environment looks like a playground where we have popped their plants and trees as such. What can we do to fix it?"
  (diagnose: uniform scatter, no ecological clustering/succession, no ground blending at trunk bases, no undergrowth/litter,
  same scale/tilt, plants not following moisture/slope/light, abrupt biome edges, no wind coherence, lighting/AO…)
- "Rivers don't look good. Do we really need them?" (what rivers give the design: water secrets C4, drinking, the spring,
  routes/fords, goldens and routes 288/288. Give options with cost: improve, reduce to one stream from the spring, or remove;
  recommend one.)
- "Texture on the rock makes it look like Garry's Mod (not good)." "Rocks have the same texture repeated, how can we change it?"
  (stochastic/hex tiling, macro variation, triplanar + world noise, multiple rock materials by geology, per-instance variation,
  moss/dirt by normal and AO, Idol-made or procedural boulder meshes…)
- "The caves look like pipes instead of real caves." (real cave forms: chambers, irregular cross sections, collapse blocks,
  stalactites, wet floors, light falloff; the C cave data and the walkable chamber must stay consistent)
- "Make something like the Zelda false wall, where you can see that perhaps you should dig there." (a readable cue: cracked
  wall, different stone, draft/particles, sound; and the minimum mechanic to break it now, since digging proper is C5)
- "What about cliffs, do we have cliffs?" (check what exists: W20 v2 plus cliffs and caves; why they may not read as cliffs)
- "Can we make the initial manantial (spring) realistic?"
- "Make cool predators that roam the place." (2–3 roaming predators with patrol ranges and readable silhouettes/behaviours;
  how they fit ECOLOGY.md and the C species system; who implements)
- "Just to put it over the table: we would wish in the future to extend the creature stage potentially to a continent."
  (architecture note only: what in terrain/C world/fixed math/caches/streaming would have to change, and what to avoid now so
  it stays possible)
Read first: docs/CREATURE-ROADMAP.md, docs/TERRAIN.md, docs/godot/*.md (NAV, island, flora, rock material F2), docs/ECOLOGY.md,
docs/FLORA-ART*-REPORT.md, docs/SECRETS-REPORT.md, godot/game/island/*, godot/game/shaders/*. Keep the plan concrete and short
(≤ 300 lines), with a list of owner decisions at the end (each with your recommendation).
