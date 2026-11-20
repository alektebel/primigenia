# Task: doc-drift + test-gap audit and the owner's playtest checklist (report only, no code)

Worktree /home/diego/Desarrollo/cpore-wt/audit-drift, branch audit-drift. Write exactly two files, commit them, touch nothing else.
Do not run Godot, builds, or installs. Read-only analysis with grep/cat/git.

1. `docs/audit/DRIFT.md`: where docs disagree with each other or with the code. Check docs/CREATURE-ROADMAP.md ("Where we are"
   table), docs/BACKLOG.md, docs/DESIGN.md §11, docs/DEVTOOLS.md, docs/godot/*.md, README.md against `git log --oneline -80`, the Makefile
   targets and the actual files under godot/ and core/. For each item: file:line, what it says, what is actually true (with evidence), and a
   suggested one-line fix. Rank by how much it would mislead someone. Max ~120 lines.
2. `docs/PLAYTEST-C0C1.md`: a checklist for the owner's 10–15 minute play session on the GPU (`make godot && godot --path godot`).
   Group by feature: movement + camera (scroll zoom, left-drag orbit, Home), legend F1 (check the console key shows as "º" on a Spanish
   keyboard), console º/F12 (`tp`, `spawn`, `overlay path`), F2 sites, F3/F4 tuning A/B, F5/F6 scenarios, F8 feedback, pause/step/[ ],
   click-to-move across a cliff (pathfinding), fight vs Garfio (bite grip, roar, charge, stagger readability). Each line: what to do, what
   should happen, a box to tick, and "press F8 if not". Also list the features that only have unit tests and no live check (find them in
   the test files and docs). Max ~100 lines. Plain English, short sentences.
