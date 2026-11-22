# Creator flow — C1/C2 handoff, 2026-11-22

Advances the owner's **creature editor flow** acceptance test in
`docs/briefs/creator-flow.md`: large creature on a clear stage and ≤15% closed HUD.
No tracker id was supplied; no test is marked Passed. Owner capture vote is pending.

All work is **uncommitted**, as requested. No merge, push, install, C change, new part,
paint technology or nest-entry change. The pre-existing edit to the brief is preserved.

## Logical steps for commits

1. **C1 — stage and camera.** Replace near grass/rocks with a three-level round
   plinth, matte ground, distant hills and nine trees outside the camera orbit.
   Use a quiet sky, warm key and cool rim light. Frame the complete rest bounds
   (including parts and limbs) toward 55% height, subject to horizontal fit.
   Reframe after size edits and window resize, preserving the existing right-drag
   orbit and empty-space wheel zoom. Smooth size changes; never recenter a live
   drag. Test mode hides the plinth and retains the existing locomotion path.
   Reduce the old fixed-world spine-arrow offset to a pixel-derived offset so the
   hatchling's arrows remain reachable at close range.
2. **C2 — HUD.** Mode/file/help/play/history icons at top left; DNA budget and
   Details toggle at top right. Details starts closed; the old stats, name,
   language and unchanged nest actions share its scroll area. Parts start as a
   slim category strip and expand on hover, focus or click. Collapse after a
   palette placement. Keep all existing part buttons, discovery locks and model
   transactions. Help carries the permanent instructions; the bottom line only
   shows contextual feedback. Mouse press scale .97, 120 ms exponential ease-out;
   Details slides in 200 ms. Keyboard activation opens immediately without motion.
3. **Evidence/regressions.** `flow_evidence.gd` drives start, part addition, spine
   stretch and final palette, writing JPGs with a display and geometry/timing JSON
   headlessly. Update interaction checks for the new HUD, three resolutions,
   both languages, framing and scrolling nest controls into view at 1024×600.

The C1-only patch from the intermediate state is available for the committing
agent at `/tmp/creator-flow-c1.patch`; it predates the arrow-offset correction,
which belongs with C1. Current final files are authoritative. C2 follows C1 in
the same studio script. Evidence/notes can accompany the relevant commits.

**C3–C6 were not implemented.** Existing part movement/mirroring, rotation, scaling,
drop pulse/click and locomotion are retained; these are not claimed as the new
blue spheres, green rotation rings, duplication, cost feedback or alive-creature work.

## Results and limits

| Check | Result |
|---|---|
| Studio suite | 942 checks, 0 failures |
| Studio interaction | 202 checks, 0 failures |
| UI suite | 992 checks, 0 failures |
| Nest parts/apply/evolve | PASS |
| Web validator cross-check | 45 checks, 0 failures |
| Check-only and `git diff --check` | PASS |
| First-quest e2e | **24/29 on baseline and after**; not green |
| Four moment framing, 1280×720 | projected rest AABB height 55.00–55.05% after settling |
| Closed HUD, 1280×720 | 8.15% area; <15% also checked at 1024×600 and 1920×1080 |
| Rendered screenshots, side-by-sides and owner vote | **Pending: Xvfb cannot open a display in this sandbox** |
| Rendered frame time | **Pending; no performance pass claimed** |

`before-headless.json` / `after-headless.json` contain the raw measurements.
The bounds metric projects the eight rest-AABB corners, **not the creature's pixel
silhouette**. Height was 26.5% at baseline start. UI area sums visible top-level
panels: the baseline's old top HBox is excluded, so its 34.8% is a lower bound.
The new top bar is a panel and is included. Rendering must confirm the visual ≥50% gate.

After a 360-frame warm-up, headless `TIME_PROCESS` mean was **0.294 → 0.595 ms**,
p95 **0.372 → 1.034 ms**. Wall time is capped near 6.9 ms/frame and is not a useful
performance comparison. The process increase needs investigation alongside the
software-GL render benchmark. These samples do not satisfy the no-regression gate.

The unchanged studio baseline was reconstructed from **aa48631** into
`/tmp/creator-flow-baseline-godot`, using the same existing main-worktree imported
assets and extension binary copied locally (no install/build changes). Both e2e
runs reach editor open, gland placement and evolution, then report the same five
failures: missing flame loadout slot, flame task/counter not completing, chain not
complete, and three `look_at()` errors. See `first-quest-before.txt` and
`first-quest-after.txt`. Both end at tick 4437, hash `f2e73a3b039e206b`.
The UI suite also emits its existing detached-menu warning; shutdown resource
warnings occur in full-project scripts. Do not call these runs error-free.

## Reproduce checks

Use an isolated writable user directory for every run. All Godot commands need
`LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout`, headless or Xvfb, and OpenGL 3.
New scripts were checked with `--check-only` before execution.

```bash
export XDG_DATA_HOME=/tmp/creator-flow-user
export XDG_CONFIG_HOME=/tmp/creator-flow-config
export LIBGL_ALWAYS_SOFTWARE=1
nice -n 10 timeout 60 godot --headless --rendering-driver opengl3 --path godot --check-only --script res://studio/tests/flow_evidence.gd
nice -n 10 timeout 600 godot --headless --rendering-driver opengl3 --path godot/studio --script res://tests/test_studio.gd
node godot/studio/tests/node_check.js
nice -n 10 timeout 600 godot --headless --rendering-driver opengl3 --path godot --script res://studio/tests/test_interaction.gd
nice -n 10 timeout 600 godot --headless --rendering-driver opengl3 --path godot --script res://tests/ui_test.gd
nice -n 10 timeout 120 godot --headless --rendering-driver opengl3 --path godot --script res://game/tests/parts_nest_test.gd
nice -n 10 timeout 1500 godot --headless --rendering-driver opengl3 --fixed-fps 60 --path godot --script res://game/tests/first_quest_e2e.gd
nice -n 10 timeout 120 godot --headless --rendering-driver opengl3 --path godot --script res://studio/tests/flow_evidence.gd -- /tmp/creator-flow-check
```

## Capture outside the sandbox

Run the same evidence driver on aa48631, C1 and C2, at 1280×720. Copy the new
`studio/tests/flow_evidence.gd` into the baseline's untracked test folder to drive
identical moments. Our JPGs may go in this evidence directory; **comparisons
containing reference footage and extracted reference frames must stay outside git**.

```bash
LIBGL_ALWAYS_SOFTWARE=1 nice -n 10 timeout 180 xvfb-run -a -s '-screen 0 1280x720x24' godot --rendering-driver opengl3 --max-fps 60 --resolution 1280x720 --path godot --script res://studio/tests/flow_evidence.gd -- /tmp/creator-flow-ours
```

Reference was inspected via FFmpeg sheets. Chosen reference moments are 12, 28,
44 and 75 seconds (start build, part editing, spine editing, final). Fresh crops
are in `/tmp/creator-flow-reference/01-start.jpg` through `04-final.jpg`; crop
`576:576:0:300` removes the phone's top and bottom chrome, retaining the game view.
Re-extract from the original video if `/tmp` is gone:

```bash
ffmpeg -v error -y -ss 12 -i ~/Desarrollo/cpore-refs/videos/creator-flow-2026-11-22.mp4 -vf 'crop=576:576:0:300' -frames:v 1 /tmp/creator-ref-start.jpg
ffmpeg -v error -y -i /tmp/creator-ref-start.jpg -i /tmp/creator-flow-ours/01-start.jpg -filter_complex '[0:v]scale=720:720[a];[a][1:v]hstack' -frames:v 1 /tmp/creator-flow-start-side-by-side.jpg
```

Repeat for all four moments and C1/C2, visually inspect lighting, framing, hover,
drawer motion and the nest controls, measure rendered frame time with the same
settings, then request the owner's tracker vote. Work is not accepted until that vote.
