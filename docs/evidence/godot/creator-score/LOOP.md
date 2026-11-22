# Creator score iteration loop

Goal: move the creature editor toward the feel and flow of the reference video (`docs/briefs/creator-flow.md`) with numbers, not taste. One change at a time.

## Steps (per change)
1. **Change one thing** (one commit-sized step of `ui/creator-flow`: C1 stage, C2 HUD diet, C3 handles, ...). Do not mix.
2. **Run the score**: `make godot-creator-score CREATOR_LABEL=<short-name>` (about 2 min; `CREATOR_GATES=quick` skips the first-quest e2e while experimenting, run it before the final keep). Software GL only; never the GPU.
3. **Compare**: `python3 tools/creator/compare.py baseline <short-name>` (or against the last kept label). It prints improved / regressed per check, the gates and the frame time, and ends with KEEP or REVERT.
4. **Keep only if** the score improves AND no gate regresses (studio, ui, first-quest: pass must stay pass) AND the editor frame time is not more than 30% slower. Otherwise revert the change.
5. **Log a row** in `iterations.csv` (date, label, change, score, gates, frame ms, decision, note). Kept or reverted, both get a row.
6. **Owner sees a contact sheet only at milestones** (after C1, C2, C3 ... not every iteration): `<label>/contact.jpg` (ours) and the local `contact_with_ref.jpg` (ours over the reference; the reference half is never committed). Owner votes go to `votes.jsonl` via `tools/creator/judge.py vote`.

## What the replay exposes (contract for the editor work)
The replay (`godot/studio/tests/creator_replay.gd`) drives the real input path with a fixed starter (Merodeador), part (`placa`) and pointer path. It listens to `Studio.creator_event(name, data)` and, optionally, calls `Studio.creator_probe()`. Emit these and the checks turn on:

| event | when | data |
|---|---|---|
| `part_placed` | a dragged part lands (already emitted) | `idx` |
| `puff_spawned` | the landing puff starts | |
| `cost_popup_shown` / `cost_popup_hidden` | the floating "+N" appears / is gone | `cost` |
| `head_target_changed` | the creature's head starts turning to the new part or cursor | |
| `handle_shown` | a handle becomes visible | `kind` = `vertebra_sphere` or `part_ring`, `fade_ms` (time to full opacity) |

`creator_probe()` returns `{vertebra_spheres: int, part_ring: bool, popup: bool}` for the current frame. Without it the scorer reads spheres 0 and ring false. Emit through `creator_ev(name, data)` in `studio.gd`. An event that is never emitted is reported ABSENT and fails its check; the run never crashes.

## Pitfalls
- Frame time is software GL on a shared CPU: only a change over 30% means anything.
- The mask pass hides scenery and UI and shows the creature on magenta. If a new effect should count as part of the creature (puff, ring), keep it out of the mask: the bounding box is the body.
- If a new UI element is a separate node outside `Studio.hud`, add it to `_mask_on` in the replay so it is hidden in the mask pass; the UI-only pass hides only the stage.
- The first-quest gate fails on main today (5 of 29 checks, all about the flamethrower task and two canvas errors, unrelated to the editor). Do not let it block, but never make it worse.
