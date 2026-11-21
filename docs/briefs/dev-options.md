# Brief: option cycling in the debug tools (F10 option mode)

Worktree `/home/diego/Desarrollo/cpore-wt/dev-options`, branch `devtools/options` (from main). Work only here.
Owner request 2026-11-21: "for the debugging game tool, I want to change potential options by pressing some special key, and be able to iterate between different options with different keys." Tracker test: DT-OPT (new). It lets the owner compare variants live (gait, skin, light, starter…) instead of waiting for clips, so the motion and art lanes get his verdicts faster.

Read first:
- `AGENTS.md`
- `docs/godot/DEVTOOLS.md` (keys F1–F12, formats, the agent socket)
- `godot/devtools/tuning/registry.gd` and `panel.gd` (D4 live tuning plus A/B: numeric entries, `sim` entries via PARAM debug ops)
- `godot/devtools/dev.gd`, `legend.gd`, `legend.json`, `feedback.gd`
- Emil UI skills (`emil-design-eng`): no animation on keyboard actions, ease-out ≤ 250 ms elsewhere.

## Design (defaults chosen by Claude; record them as starting choices)
1. **Choice entries in the registry.** Next to the numeric entries, add `add_choice(key, group, values: Array[String], default, getter, setter, sim := false)`. Choices go into the same tuning diff (`primigenia.tuning/1`, `values[key] = "name"`) and the A/B slots, so F4 swaps whole variant sets. Sim choices go through PARAM debug ops, logged and replayable. Presentation choices never reach C.
2. **F10 option mode** (F10 was reserved for overlays, which become one option group). F10 toggles a small corner HUD (Alegreya, no panel, same style as the F1 sheet), live while playing:
   - `1`–`9`: pick a group. The groups are Movement, Creature, Look, Light, Camera, World, Overlays, Tuning (all numeric entries) and Presets.
   - `↑` `↓`: pick an option in the group.
   - `←` `→`: cycle its value. It applies instantly, with no animation, and the HUD shows `Gait: froude ▸ 2/3`. For numeric entries: one step, Shift for ×10.
   - `Backspace`: reset that option to its default. `Ctrl+Backspace`: reset all.
   - `Ctrl+1`–`4`: save the whole set to a preset slot. `Alt+1`–`4`: recall it. Presets are tuning diffs in `user://tuning/preset_N.json`.
   - The keys bound in this mode are suspended in the game while the HUD is open, so `1`–`9` and the arrows don't also move the creature or fire moves. Esc closes the HUD.
   - Mouse is optional: hovering an option shows its description.
3. **Visible and recorded:**
   - The active non-default choices show as one short line in the corner (`gait froude · skin v1 · light day`) while option mode is closed, and in every screenshot from the capture tools.
   - The F8 feedback bundle and scenarios save the full set, so the owner's feedback says which variant he was looking at.
4. **Console and agent socket:** `opt list`, `opt <key> <value>`, `opt preset <n>`, so agents and scorecards can set variants (e.g. `make godot-look-score` with `OPTS="light=day skin=v1"`).
5. **First options to register:** only those that exist today. Leave a TODO list for the rest.
   - Creature: **starter** (`hatchling`, `a_grazer`, `b_runner`, `c_sprawler`, `d_knuckle`; `godot/game/game.gd` STARTER, data in the starter candidates). It respawns the player body with that genome. This is a dev-only path through the existing debug ops; if it needs a C change, stop and say so.
   - Look: **skin variant** (current v1 vs pre-v1 if the shader still allows it; otherwise skip).
   - Light: **time of day** jump (dawn 6.8, midday 12.5, dusk 18.2, night 0) through the existing clock debug op.
   - World: **quality tier** (low/medium/high).
   - Camera: the existing presets or values.
   - Overlays: path overlay, footfall markers if they exist, nav grid, the creature legend.
   - Movement: the existing LOCO tuning plus a **gait selection** choice stub (`today`; `froude` greyed out with "after the gait port" until `loco_gait.gd` has it).
   - Tuning: every existing numeric entry.

## Acceptance
- Tests in `godot/devtools/tests/` cover:
  - choice add, cycle and wrap; reset; the diff round trip with choices
  - A/B swap with choices
  - preset save and recall
  - input suspension while the HUD is open
  - the `opt` console commands
  - a sim choice being logged and replayable
- `make godot-devtools-test`, `make godot-test`, `make godot-ui-test`, `make godot-play-test` all green. The feel numbers are unchanged with option mode closed.
- Evidence: software-GL screenshots (xvfb, `LIBGL_ALWAYS_SOFTWARE=1`, `timeout`, `nice -n 10`; never the GPU) of the HUD open on two groups, plus the corner line, in `docs/evidence/godot/dev-options/`. Update `docs/godot/DEVTOOLS.md` (keys, formats) and `legend.json` (F10).
- Commit on `devtools/options`; do not merge. Before stopping for any reason, commit WIP. Report: keys, options registered, tests, screenshots, TODO options.

## Phase 2: in-game notes (owner request 2026-11-21, after F10 option mode is committed and green)
The owner wants to flag things in the game and leave notes on them. Tracker test: DT-NOTE (new). Defaults chosen by Claude; record as starting choices.
- **Flag mode.** F8 stays the general feedback bundle. Shift+F8, or the F8 dialog's "Flag something", enters flag mode:
  - the cursor shows what is under the mouse, ray-picked: creature (species, individual id, body part if a part collider exists), plant or flora, prop or artifact (meteor shard, fossil bed, nest, food, remains), or a terrain or water point;
  - a click opens a small note box: one text line, optional tags (bug, look, motion, idea, lore) cycled with Tab, severity 1-3;
  - Enter saves, Esc cancels; game input is suspended while typing, with the same mechanism as the F10 HUD (`Game.options_open`).
- **Storage.** `feedback/notes/<stamp>-<id>/` (git-ignored, falling back to `user://feedback/notes/`):
  - `note.json` (`primigenia.note/1`): text, tags, severity, target {kind, id, species, part, name}, world position, C tick and clock hour, camera pose, active F10 options, build hash, status "open";
  - a full screenshot and a crop around the target;
  - a scenario snapshot so an agent can reload that exact moment;
  - `feedback/notes/index.jsonl`, one line per note.
- **Pins in the world.** Small pins above the target; they follow a creature that moves, otherwise stay at the position. Visible only in flag mode, or toggled from the F10 Overlays group. Hovering a pin shows its text; clicking it edits the note or marks it done.
- **For agents:** `tools/feedback/notes.py` with `list` (open, newest first), `show <id>`, `done <id> "<fix commit>"`, `export-md` (a Markdown table for STATUS and the tracker); console `notes` and `note done <id>`; the agent socket gets the same.
- **Tests:** pick on each kind, note round trip, input suspension, pins attached to moving creatures, the index line, `notes.py` list/done/export.
- **Evidence:** software-GL screenshots of flag mode hovering a creature, the note box and pins, in `docs/evidence/godot/dev-options/`. Update `docs/godot/DEVTOOLS.md` and `legend.json`.
- Commit each phase separately.
