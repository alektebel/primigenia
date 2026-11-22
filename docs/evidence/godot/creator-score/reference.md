# Creator reference targets (from the owner's reference video)

Source: `~/Desarrollo/cpore-refs/videos/creator-flow-2026-11-22.mp4` (never committed; frames are extracted locally by `tools/creator/ref_frames.py` into the git-ignored `ref_frames/`). 576x1280 portrait, 24.17 fps, 77 s. The editor part runs from about t=6 s to t=68 s. Numbers live in `reference.json`; this page says how each was measured.

The game view is **y 299..872** (573 px, found by the row-brightness edges), not the brief's rough 240-680. The TikTok icon column on the right and the caption word are not editor UI and are ignored. Boxes are in view pixels (576x573).

## Moments

| moment | frame (t s) | height / view | centre x, y | elev deg | spheres | part ring | UI cover | clutter | note |
|---|---|---|---|---|---|---|---|---|---|
| start | f147 (6.1) | 0.61 | 0.59, 0.43 | 12 | 0 | no | 0.13 | no | editor first frame, dashed spine outline, 53/255 |
| spine_hover | f183 (7.6) | 0.61 | 0.59, 0.42 | 12 | 4 | no | 0.13 | no | 4 blue/yellow spheres appear on the spine in one frame |
| part_picked | f289 (12.0) | 0.62 | 0.59, 0.42 | 12 | 0 | yes | 0.13 | no | part dragged to the body: small pale rings on the target, pink floor marker |
| part_dropped | f296 (12.2) | 0.62 | 0.59, 0.42 | 12 | 0 | yes | 0.13 | no | part attached 2 frames earlier, 'Sell For' tooltip, counter 55/255 |
| spine_drag | f254 (10.5) | 0.61 | 0.59, 0.41 | 12 | 3 | no | 0.13 | no | one yellow (active) and two blue spheres, creature posture changed |
| part_rotate | f351 (14.5) | 0.62 | 0.59, 0.43 | 15 | 0 | yes | 0.13 | no | big blue/white rotate gizmo ring around the part |
| final | f1620 (67.0) | 0.50 | 0.58, 0.37 | 13 | 2 | no | 0.13 | no | last editor frame, 118/255, creature smaller after many adds |

Extra, not scored: `finish_painted` f1815: box [147, 41, 388, 518], height 0.83 of the view; no pedestal and no UI after the paint step (our editor has no equivalent yet).

## Timing (frame stepping at 24.17 fps, 1 frame = 41 ms)

| quantity | target | tolerance / bound | frames | how |
|---|---|---|---|---|
| drop_to_puff_s | 0.0 | tol 0.1 | attach f294, white ring + sparks visible f294-f296 | frame stepping f286-f300 at 1 frame; attach = the frame the part is on the body (f294), puff = first frame of the white ring flash on the attach point (f294) |
| cost_popup_delay_s | 0.29 | tol 0.2 | +75 appears f301 | first frame with the green '+75' text near the part (f301-f302) minus attach f294 |
| cost_popup_life_s | 0.455 | lo 0.3, hi 0.8 | f301 to f312 (11 frames) | popup text rises ~180 px from the paw to the head and is gone by f312; brief C4 asks 600 ms |
| head_react_delay_s | 0.33 | tol 0.25 | jaw opens / head turns f302-f306 | first frame the head pose differs from the idle pose (f301-f302) minus attach f294; roar peak f304 |
| handle_fade_in_s | 0.04 | max 0.15 | f179 none, f180 full spheres | spheres go from absent to opaque in one frame (no fade); fade-out takes f187-f190 (0.14 s). brief C3 asks ~120 ms |
| counter_tick_vs_attach_s | -0.17 | info only |  | 53/255 -> 55/255 at f290, 4 frames before the part lands (it ticks when the part is picked up over the body); info only |

## Tolerances and how the rest was measured

- **Height, centre**: hand-annotated boxes on a 50 px grid overlay (green creature on a green forest: colour keying is not robust). Checked by drawing the boxes back on the frames (`*_boxed.jpg`, local). Accuracy about +-3% of the view. Pass: height within 0.10 of the target and at least 0.50 (brief acceptance); centre x within 0.12, y within 0.10. The target centre is inside the free area of a phone-shaped view, ours has side panels, hence the generous tolerance.
- **UI coverage** (about 13% of the view with the bezel rail, 4% without): rectangles measured on f147: left rail 50x573 px, top-left cluster ~210x35, counter 55x12, bottom bar 300x18. Pass: <= 15% (brief acceptance, drawer closed).
- **Camera elevation**: pedestal top ellipse height / width = sin(elevation), e.g. 90/440 on f147 gives 12 deg, +-4 deg. Ours is the editor's real camera pitch. Pass within 8 deg.
- **Clutter**: looked at all 7 frames: nothing but the pedestal between camera and creature. Ours fails while grass or rocks are drawn.
- **Handles**: spheres counted on f183, f254; the rotate gizmo ring on f351; the faint rings on the part in f289-f296. Pass: >=3 spheres at spine_hover, >=2 at spine_drag, a ring at part_rotate.
- **Counter**: 53/255 at the start, 55/255 after the part (it ticks 4 frames before the part lands, f290), 118/255 at the end.

## Reading the timing in the video

f289 the dragged part is next to the body with a pink floor marker and pale rings on the target; f294 the part is on the body with a white ring flash and sparks; f294-f299 a 'Sell For' tooltip; f301 a green '+75' appears at the part and rises about 180 px to the head by f310, gone at f312; the head turns and the jaw opens f302-f306 (roar peak f304). Spheres: f179 none, f180 four spheres at full opacity (one frame, no fade), gone f187-f190.
