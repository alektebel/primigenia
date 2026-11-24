# Brief: field journal + UI polish (Godot UI only)

Worktree `/home/diego/Desarrollo/cpore-wt/c2-journal`, branch `c2/journal-polish` (from main `claude/v0.1-restore`). Work only here.
Commit per slice (ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`); do not merge. Never touch the main checkout,
other worktrees, `.codex/`, `.kimi-code/` or ~/Desarrollo/cpore-refs/.

Read: `docs/godot/UI-DIEGETIC.md` (the approved minimal diegetic UI: mouse-only, Alegreya fonts, quiet signs, round minimap, numbers off
by default), `docs/DESIGN.md` G38 (journal), A25, `docs/P4.md` (codex page: silhouettes and unlocked parts, recipes unknown→hinted→known),
`docs/PARTS-NEST-REPORT.md` (journal stub, open UI items), `godot/ui/*`, `godot/game/stage/*`, `godot/studio/`.

Other agents now: `c2/secrets-roster` (Sonnet: will expose `state().shards` and new species; until merged, render those sections from
whatever exists and hide empty ones gracefully) and `c2/moves-recipes` (Codex: recipes/meters in `state()`; same rule). Do not edit `core/`.

## Slices
S1 **Field journal (G38).** Replace the id-list stub with a designed journal in the game's visual language (paper/field-notebook feel,
our own art, no Spore assets): tabs or pages for **Species** (seen/befriended/hunted, Q43 state, live-rendered portrait or silhouette
via SubViewport of the species body, home-range note), **Parts** (discovered/owned, silhouettes for undiscovered, level), **Secrets**
(shards found with their story line, fossils, the cave; unknowns as "?"), **Recipes** (unknown/hinted/known). Opened from the menu
icon and a key (add to the key legend). Pagination/overflow handled. Spanish + English.
S2 **Polish from the parts/nest capture:** the nest editor panel covers the creator's stats column (fix the layout at 1280×720 and
1024×600); the "lineage ends" overlay uses the engine default font and is English-only (game font + i18n); check keyboard focus and
cancel in the nest overlay.
S3 Tests in the UI suite (`godot-ui-test`) and evidence: xvfb JPG in `docs/evidence/godot/journal/` (each page ES and EN, small laptop
size, overflow). Look at every image and fix what is off. Run `godot-test`, `godot-ui-test`, `godot-play-test`, `godot-parts-nest-test`.

Godot: always `timeout`, `--check-only` first, headless/xvfb software rendering, `nice -n 10`. Kill only processes you started, by pid;
never `pkill -f`.
