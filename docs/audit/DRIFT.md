# Doc drift audit (2026-11-17)

What the docs say that is no longer (or never was) true. Ranked by how much it
would mislead someone. Evidence: `git log --oneline -80`, the Makefile,
`godot/project.godot` InputMap, `godot/devtools/console/commands_creature.gd`,
`docs/godot/NAV.md`, and the code under `godot/` and `core/`. One-line fixes
inline. Nothing here was changed except this file.

## 1. The C world is flat — the biggest lie still in print

- `godot/README.md:114-117` ("Known limits"): "The C world is flat… only knows a
  ±195 m square… the player cannot walk out of the square."
- False since H1–H6 (commits `2ef29d2`, `98cb49a`, merged in C0 `89a4bbb`): the
  C world runs in FIELD mode on the generated island heights; NAV.md says the
  FIELD walkable bound is `half - 2*cell` of the 3600 m island, and `make
  godot-heights-test` exists. The game walks the whole island.
- Fix: replace the bullet with "the C world walks the island field; the walkable
  bound is the island minus a 2-cell coast margin (docs/godot/NAV.md)."

## 2. CREATURE-ROADMAP "Where we are" table is one merge cycle behind

- `docs/CREATURE-ROADMAP.md:21` World row: "the C world is flat beyond ±195 m
  (F4)". F4 is done (same evidence as item 1).
- Fix: "the C world uses the island heights (FIELD mode, NAV.md)".
- `docs/CREATURE-ROADMAP.md:25` In-flight row: "studio parity (paused WIP), rock
  material F2 (step 1 of plan), action animations F3 (plan only)". Reality: the
  parity pass is merged (`9b1abb7`, honest gaps in STUDIO-PARITY.md), rock is
  done through step 10 (`ea0e31e`, `3eb3ece`; only baked sun shadows await owner
  approval, off by default), and action animations shipped in two rounds
  (`0e35914`, `b232e19`, `aaa35f2`).
- Fix: move all three to "done"; the only open F-item is owner approval of the
  baked sun shadows.
- `docs/CREATURE-ROADMAP.md:26` Missing row lists "saves, dev tools". Both
  shipped in C0 (`89a4bbb`: pause-menu Save/Load, console, sites, scenarios,
  tuning A/B, F8, agent socket).
- Fix: drop both from Missing.
- This table is the entry point every agent reads, so stale rows mislead the
  next worker into redoing finished work. Fix: refresh the table in place.

## 3. BACKLOG's F-table is older than the roadmap

- `docs/BACKLOG.md:21-24`: F1 feel "in progress" (merged `2f5cf70`), F2 rock
  "in progress" (merged `ea0e31e`), F3 actions "planned, implementer queued"
  (done), F4 island heights "next" (done, `98cb49a`).
- Fix: mark F1–F4 done, with the commit hash, as the table does for M0–W.

## 4. "GO is blocked by cliffs, no path-finding" — superseded by C1-nav

- `docs/godot/DEVTOOLS.md:39` (Known limits): "A straight GO order is blocked by
  cliffs on about half of 20 far targets (no path-finding)."
- False since C1-nav (`36cb23c`, `f4de6f4`): A* over the walk grid plans around
  cliffs; NAV.md's own number is 20/20 far targets reached.
- Fix: delete the line; point at docs/godot/NAV.md.

## 5. README.md never mentions the playable Godot build

- `README.md:22-41` "How to play" is only the web pages (`make serve` +
  `http://127.0.0.1:8090/web/stage/`). The plan of record calls the Godot
  desktop build "one playable game: `make godot && godot --path godot`"
  (CREATURE-ROADMAP.md:15), the Makefile has the target, and godot/README.md
  documents its controls — the root README says none of this.
- `README.md:36-38` "Stage controls" links to `docs/evidence/stage/polish/`,
  i.e. the *web* stage's controls, not the desktop ones a new player needs.
- Fix: add a "Desktop build" block (`make godot && godot --path godot`) at the
  top of How to play and link godot/README.md for the controls.

## 6. Console key and command list drift in docs/DEVTOOLS.md

- `docs/DEVTOOLS.md:29` D1: console key "` (backtick)" and example commands
  `weather storm`, `stage band`, `trait add aquatic`. Reality: the binding is
  the *physical* key left of 1 (º on a Spanish keyboard) plus F12
  (`godot/project.godot` `dev_console`, and docs/godot/DEVTOOLS.md:17 already
  says this right). `weather` is not registered anywhere
  (`commands_creature.gd`); `stage` and `trait` are registered stubs that fail
  with "DT2"/"L0".
- Fix: key = "physical key left of 1 (º) / F12"; drop `weather`, mark `stage`
  and `trait` as not-yet stubs.
- `docs/DEVTOOLS.md:36` D8: "F10 cycles" overlays; `docs/DEVTOOLS.md:38,41`
  D9 F7, D6 F9, D12 `make soak` / `autoplay`. Reality: F7/F9/F10 are "reserved,
  not bound" (docs/godot/DEVTOOLS.md:18); the only overlay is console
  `overlay path` (`commands_creature.gd:77`); there is no `soak` Makefile
  target and no `autoplay` command.
- Fix: label D6/D9/F10/D12 rows "planned (DT1/DT2)", not with keys.

## 7. README.md stale and duplicated

- `README.md:70`: `studio-sdl/` "transitional… moving to `web/`". Superseded by
  G76: the studio now lives in `godot/studio/` (BACKLOG.md:4 already notes the
  web-first lines are superseded).
- `README.md:93`: a second "## Build" section repeating "How to build" (line 8).
- `README.md:56`: calls docs/BACKLOG.md "Current order of work" while BACKLOG's
  own header says it is per-item state only and CREATURE-ROADMAP is the plan of
  record. The docs table also lists no Godot docs at all.
- Fix: one Build section; studio-sdl → "legacy SDL studio (superseded by
  godot/studio, G76)"; point "order of work" at CREATURE-ROADMAP.md; add a
  `docs/godot/` row.

## 8. Smaller items

- `docs/DEVTOOLS.md:3`: "Status: draft, 2026-11-17" — DT0 shipped two days of
  merges ago; the status line should say which parts exist.
- `docs/CREATURE-ROADMAP.md` "UI" row "befriend/observe/intimidate are
  placeholders" is still true (godot/game/stage/stage_ui.gd:81 shows the
  "not in this build yet" message), so no drift — recorded here only to say it
  was checked.
- `docs/DEVTOOLS.md` D5 says feedback goes to `feedback/<time>/`; the code uses
  a `<stamp>` folder name (godot/devtools/dev.gd:23, "feedback"). Cosmetic.
- Fix for the whole file: mark built vs planned tools with a state column.
