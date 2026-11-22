# Brief: creature editor scorecard against the owner's reference video

Owner approved 2026-11-22: "okey, yeah, do that". The goal is to auto-iterate the creature editor toward the feel and flow of the reference video. It is a scorecard like the movement and look scorecards (`make godot-loco-score`, `make godot-look-score`, `tools/loco/compare.py`, `tools/look/compare.py`); copy their structure.
- **Reference:** `~/Desarrollo/cpore-refs/videos/creator-flow-2026-11-22.mp4`. It is a 576×1280 portrait phone capture of a 2008-era creature editor, cropped by an app UI. The game view is roughly y 240–680. Never commit the video or frames from it. Derived numbers and your own annotations are fine to commit.
- **Target feel:** see `docs/briefs/creator-flow.md`. It is the flow and feel, not the art. Never score pixel similarity to the other game's art.

## Deliverables
1. **Reference target sheet**, `docs/evidence/godot/creator-score/reference.json` plus a `.md`.
   - About 6 key moments: start, part picked, part dropped, spine stretched, part rotated or scaled, final.
   - For each moment, measure from the video frames (ffmpeg, plus python and numpy or PIL where it helps; hand annotation where measuring is not robust):
     - the creature's bounding-box height as a fraction of the game-view height
     - creature centre x/y
     - UI coverage %
     - handles visible (vertebra spheres, part ring)
     - camera elevation, estimated
     - background clutter between camera and creature (yes/no)
   - Timing, from frame differencing:
     - drop → puff delay
     - "+N" cost popup lifetime
     - delay before the creature reacts (head turn or pose)
     - handle fade-in time
   - Give each target a tolerance. Write down how each number was measured.
2. **Scripted replay in our editor**, `godot/studio/tests/creator_replay.gd` or similar.
   - It is deterministic, with a fixed starter and seed. It performs the same action sequence: open, pick a part, drop it on the body, drag a vertebra, rotate/scale a part, finish.
   - It captures frames at the matching moments under xvfb with software GL, `timeout` and `nice -n 10`.
   - It also renders:
     - a creature-only mask pass (creature on a flat key colour, UI hidden), for the bounding box
     - a UI-only pass, for UI coverage
   - It logs events with timestamps: part placed, puff spawned, cost popup shown or hidden, head target changed, handle shown.
   - Some of these events don't exist yet, because the editor work (`ui/creator-flow`, Codex) adds them. Report missing events as "absent" and score them as failing; don't crash.
3. **Scorer**, `tools/creator/score.py` and `tools/creator/compare.py <baseline> <label>`. It mirrors the loco and look compare tools: per-target value, target, pass/fail, and a delta against the baseline. It also includes:
   - frame time in the editor
   - studio, ui and first-quest e2e suite status, as gates
4. **Blind judge (optional, phase 2)**, `tools/creator/judge.py`.
   - It builds side-by-side pairs, ours against the reference moment, in random left/right order.
   - It asks a vision model to score a short rubric per moment: framing, clarity of handles, feedback visible, uncluttered, and alive.
   - Judges come from two model families. Use the existing agent CLIs (`tools/agents/`, `docs/RESOURCES.md`; codex can read images). Average the scores.
   - Store owner votes in `docs/evidence/godot/creator-score/votes.jsonl` for calibration, with a judge-to-owner agreement figure (A33: a judge replaces the owner only at ≥ 80% agreement).
   - It is only a soft signal; the hard metrics gate.
5. **`make godot-creator-score`**, a baseline run on current main (`claude/v0.1-restore`), and a contact sheet of the baseline next to the reference moments, at `docs/evidence/godot/creator-score/baseline.jpg`. The reference half of the sheet stays local and is git-ignored. Commit only our half plus the numbers.
6. **Iteration protocol**, `docs/evidence/godot/creator-score/LOOP.md`. Steps:
   - change one thing
   - run the score
   - keep the change only if the score improves and no gate regresses
   - log a row to `iterations.csv`
   - show the owner a contact sheet only at milestones

## Rules
- Software GL only, never the GPU.
- Godot runs:
  - `timeout`
  - `--check-only` first
  - `nice -n 10`
  - kill only your own pids, and never use `pkill -f`
- Use test isolation, as in `godot/devtools/test_isolation.gd`.
- Don't change studio behaviour except for test hooks: event signals or a capture mode. Behaviour changes belong to `ui/creator-flow`.
- Foreground commands under 9 minutes; run longer ones detached and poll.
- Commit on the branch and don't merge. End commit messages with: Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
- **Final report:**
  - the reference targets table
  - the baseline score
  - which events are absent
  - the judge status
  - the commit hash
