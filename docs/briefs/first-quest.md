# Brief: the first end-to-end playthrough as a task chain (kill → befriend → dig → wings → flamethrower)

Worktree `/home/diego/Desarrollo/cpore-wt/first-quest`, branch `c2/first-quest` (from main). Commit per slice; do not merge.
The owner: "Let's try making the whole e2e gameplay: kill a creature, befriend another one, dig a hole, get wings by digging and
lastly, editing the creature to get the flamethrower, as in tasks." Read first: docs/CREATURE-ROADMAP.md, docs/P4.md, DESIGN.md
A25–A31, docs/PARTS-NEST-REPORT.md, docs/SECRETS-REPORT.md, docs/godot/WINGS-FLIGHT.md, docs/godot/RUN-FALL docs,
docs/godot/UI-DIEGETIC.md, docs/godot/DEVTOOLS.md (agent socket, scenarios, console), core/src/stage_world.c, stage_social.c,
combat*, godot/game/stage/*, godot/ui/* (journal, whispers, onboarding). The start is the hatchling (1.2 m, pico).

## S1 Tasks (UI + data)
A data-driven task chain `godot/game/data/quests/first.json` (ES/EN): each step has id, title, hint, a completion condition
read from C events/state (kill of species X, ally formed, `dug` event, part unlocked, part equipped, move used), an optional
marker (a soft diegetic ping toward the target, not a quest arrow), and a reward (DNA). Steps:
1. "Caza" — defeat a creature (any prey species; recommend Rondo/Zanco, beatable by the hatchling).
2. "Haz un amigo" — befriend a different species to ally.
3. "Excava" — dig a hole at a soft-soil spot.
4. "Alas del pasado" — digging at the marked fossil bed reveals a winged ancestor's fossil → unlocks a wing part (wing_vane).
5. "Fuego" — open the editor (edit anywhere is on), add the new fire gland part (unlocked by the chain) and use the flamethrower once.
A task card in the diegetic UI (top-left journal-style note, collapsible with a key, shown in the legend), a whisper on each
completion, the J journal gets a "Tareas" section. Saved with the game. Steps advance in order but conditions are checked live.

## S2 Dig (C core, minimal; digging proper is C5)
A `dig` verb (radial entry + key): only on soft-soil cells (meadow/riverbank/fossil bed; not rock), takes ~2 s (ticks), costs
stamina, leaves a hole (C state: a short list of holes per world, saved; Godot: a crater decal/mesh with soil piles), event
`dug {x,z,find}`. Deterministic buried finds at world creation: a few fossil beds (one guaranteed near the start valley,
reachable on foot), each with a cue the player can read before digging (cracked dry soil, bone fragments sticking out, a
different grass colour, a faint dust puff; observe gives a clue line). Digging a bed yields a fossil item → `part_found` for
`wing_vane` (source "fossil bed"). Normal soft soil yields small finds (grubs = food, a pebble) at low rates.
## S3 Flamethrower (C core + Godot)
A new part `fire_gland` (throat organ; tier/cost per P4 tables) and a move "Lanzallamas" (role Poke/Signature per
docs/COMBAT-MOVES.md): a short cone in front, damage over time with a burn status, stamina cost, cooldown; deterministic.
The part is unlocked as the reward of step 4 → 5 (lore: the fossil bed's chemistry; keep the lore plausible, see lore/). Equipping
the part adds the move to the loadout. Godot: a fire cone effect (particles, heat shimmer, light), burn ticks on targets,
the creature's mouth opens; grass in the cone does NOT burn yet (C5). NOTE: branch `c2/moves-recipes` (8 moves as data rows)
is about to merge into main: implement the move the same way as the existing move rows; if it merges while you work, merge
main in and adapt.

## S4 The e2e bot
`godot/game/tests/first_quest_e2e.gd` (+ `make godot-first-quest-e2e`): starts a new game and plays the whole chain only
through the real player verbs (walk orders, attack, befriend skills, dig, editor API calls equivalent to the UI, move use) —
no teleports, no debug ops except time scale — and asserts each task completes, within a tick budget. Deterministic by seed;
replays to the same world hash. Evidence: a frame per task completion + a contact sheet at
`docs/evidence/godot/first-quest/` (xvfb, software GL). Also a console command `quest skip|reset|status` for testing.

## Rules
Snapshot: main uses format 8; another task (species v8, Codex) will also bump it. Bump to the next number with a migration and
put your new fields at the end; the integrator renumbers at merge. Goldens: regenerate once if they must change, documented.
`make test`, `make smoke`, `make tourney`, routes 288/288; Godot suites (godot-test, ui, play, flight, devtools) with exact counts.
Write `docs/godot/FIRST-QUEST.md`.
## Shared rules (all tracks)
- Work and commit only in your worktree (small commits; end messages with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`).
  Never touch `.codex/`, `.kimi-code/`, other worktrees or the main checkout. Do not merge; Claude reviews and merges.
- Setup in a fresh worktree: `make godot` (or symlink `godot/bin/libcpore.linux.template_debug.x86_64.so` from
  /home/diego/Desarrollo/cpore/godot/bin), `make build/terrain_cli build/world_cli`, then `godot --headless --path godot --import`.
- Godot runs: always `timeout`, `--check-only` first, headless or `xvfb-run -a` with software GL (LIBGL_ALWAYS_SOFTWARE=1,
  `--rendering-driver opengl3`), `nice -n 10`, kill only your own pids, never `pkill -f`. Never use the GPU, the owner is playing on it.
- Determinism: C core uses integer/fixed math, `+ - * / sqrtf`, no libm trig; goldens byte-identical unless the brief says otherwise.
- UI motion follows Emil Kowalski's skills (`~/.claude/skills/emil-design-eng/SKILL.md`): ease-out for entering, never ease-in,
  UI motion ≤ 250 ms, press = scale 0.97, no animation on keyboard-triggered actions, nothing appears from scale 0.
- Before handing back: `make godot-test`, `make godot-ui-test`, `make godot-play-test` and the suites you touched green (exact counts),
  xvfb evidence under `docs/evidence/godot/<track>/` that you have looked at yourself, a short report `docs/godot/<TRACK>.md`.
