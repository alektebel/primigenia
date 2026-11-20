# Task: scenario library for the creature stage (data + one GDScript tool file; own branch, reviewed before merge)

Worktree /home/diego/Desarrollo/cpore-wt/scen-lib, branch scen-lib. Read first: /home/diego/Desarrollo/cpore-wt/_agent/briefs/godot-common.md
(MANDATORY: wrap every godot run in `timeout 300`, `--check-only` first, never open a window, software rendering only, nice -n 10),
docs/DEVTOOLS.md (D1 console, D3 scenarios), docs/godot/DEVTOOLS.md, docs/godot/NAV.md, godot/devtools/tools/make_scenarios.gd
and the three existing scenarios in godot/scenarios/creature/ (nest_start, garfio_close, far_meadow).

Add 6 scenarios, built ONLY through the existing recipe mechanism in make_scenarios.gd (console commands / debug ops that go through C).
Do NOT edit core/, godot/extension/, the console implementation, or any other code file.
1. `cliff_crossing`: the player stands below a cliff with a GO target on top that needs a detour (pathfinding test).
2. `water_edge`: at the shore, a target across shallow water (snap / unreachable test).
3. `garfio_low_hp`: Garfio at ~20 % hp, player full (finisher / kill events).
4. `player_low_hp`: player at ~15 % hp next to a hostile (flee / death / respawn).
5. `dusk_meadow`: far meadow at 19:30 (lighting, time of day).
6. `crowd`: 4–6 creatures around the player (readability, camera, icons).
If a scenario needs a console command that doesn't exist, skip it and write down which command is missing.
Regenerate with the existing make target or script (check the Makefile), make sure `make godot-devtools-test` stays green, and add each
scenario to the scenario list in docs/godot/DEVTOOLS.md with one line of "what to test here". Commit; no pushes, no installs.
