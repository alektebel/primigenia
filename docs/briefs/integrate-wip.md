# Brief: integrate all WIP branches (owner: "merge all the WIP", 2026-11-21)

Worktree `/home/diego/Desarrollo/cpore-wt/integrate`, branch `integrate/wip-2026-11-21` (from main 6644d86). You merge other branches **into this integration branch**, never into `claude/v0.1-restore` (Claude reviews and fast-forwards main at the end).
Read first: `AGENTS.md` (rules, incl. the new "make agent work count" section), `docs/STATUS.md` (branch table, next free ids), `docs/DESIGN.md` (A27–A36), each branch's brief in `docs/briefs/` and its report files.

## Step 0: commit stranded work (you may write in these worktrees only for this)
These worktrees have uncommitted work: species-v8 (34 files, Codex: read `docs/SPECIES-V8-REPORT.md` for intended commit messages), wl6-cave (8, Codex C++ cave mesher: read its brief `docs/briefs/wl6-mesher-codex.md`), art-underwater (78), feel-camera (10), loco (5), gaitopt (2), lore-autoloop2 (2), dem (1). In each: inspect `git status`/`git diff`, drop only generated junk (build output, stray caches; keep `.uid` files that belong to new scripts), commit the rest as `WIP: <what> (committed by integrator)`. Never commit `.codex/`, `.kimi-code/`, secrets, Spore captures.
**Do not touch** worktrees skin-v1, creature-fit, limp (agents working there) or the main checkout.

## Step 1: merge in dependency order, testing after each
1. `c2/moves-recipes` (snapshot 9; events FELL=27, RECIPE=28, VOLLEY=29). Its pending checks: godot play, flight, devtools, bridge, menu, moves-recipes, studio suites; finish its MOVES-RECIPES-REPORT table.
2. `c2/first-quest`: renumber its events (DUG, MOVE_USED) to 30+ and its snapshot to 10 with the previous-version handling the project uses (exact-version POD; follow what moves did); regenerate goldens once, documented.
3. `c2/species-v8`: species 7–8 (brujula, corona), Garfio grace minute + non-hunting until first evolve, Acechalunas day wake. Bump snapshot to the next free number after first-quest; events after first-quest's.
4. `art/wl6-cave-mesher`: cave mesher + art integration as its brief says (if the art/integration half is missing, merge the mesher behind its flag and list what is left).
5. Older branches (5+ days): art-food, art-meteor, art-nest, art-remains, art-species, art-underwater, dem, feel-camera, idol, loco, m-e2e, m-ecology, m-garfio, m-vista, w11-alpine, tools/gaitopt, lore/autoloop-2. For each: read its brief and log, merge main-state conflicts sensibly (main's newer behaviour wins where they overlap: e.g. A31 tuning beats m-garfio's older retune unless the brief says otherwise), test.
**Default is merge.** Skip a branch only if (a) it fails tests and the fix is not small, (b) it is fully superseded by newer main work, or (c) it would need an owner decision (gameplay numbers, gates). Write each skip with its reason.

After every merge run the suites it touches (C changes: `make test smoke tourney`; Godot: `make godot-test godot-ui-test godot-play-test` plus the branch's own suites; studio: `make godot-studio-test`; loco: `make godot-loco-test` and `make godot-loco-score` compare). If a merge breaks something you cannot fix quickly: `git merge --abort` or revert it, record it, continue with the next.

## Rules
Software GL only, never the GPU (the owner plays on it); `timeout` + `nice -n 10` on every Godot run; kill only your own pids; never `pkill -f`; no installs, no push. One commit per merge (merge commit) plus fix-up commits; end messages with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Report (also written to docs/INTEGRATION-2026-11-21.md)
Table: branch, merged / skipped (why), conflicts resolved, suites after the merge with counts, ids/snapshot numbers assigned. Final state of all suites on the integration branch. Anything that needs the owner.
