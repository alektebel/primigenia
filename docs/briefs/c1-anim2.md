# Task C1-anim2: key legend polish + action animations round 2 (GDScript only)

Worktree /home/diego/Desarrollo/cpore-wt/c1-anim2, branch c1-anim2 (from main 89a4bbb). Read first:
/home/diego/Desarrollo/cpore-wt/_agent/briefs/godot-common.md (MANDATORY: timeout on every Godot run, --check-only
first, software rendering only via xvfb-run + LIBGL_ALWAYS_SOFTWARE=1 + --rendering-driver opengl3, nice -n 10),
docs/godot/ACTIONS.md + PLAN-actions.md, docs/godot/DEVTOOLS.md, godot/devtools/legend.gd, godot/actions/,
docs/godot/CAMERA-ZOOM.md §1. Do NOT touch core/ (C) or the C combat timings; animations follow the C phases.
No installs, no pushes. Small commits ending with `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.

## Part A: legend (D13)
1. Show readable key labels, not Godot enum names: QuoteLeft/the console key shows the label of the user's layout
   (Spanish keyboard: "º"; use DisplayServer.keyboard_get_label_from_physical / OS.get_keycode_string on the label),
   BracketLeft → "[", BracketRight → "]", Period → ".", Escape → "Esc", mouse buttons → "Left click", "Right drag",
   "Wheel". One mapping function, unit-tested.
2. Add the mouse gestures, which are not InputMap actions: left click = move, left drag = orbit, right/middle drag =
   orbit, wheel = zoom near/far, middle click / Home = reset camera, double-click on an icon = zoom to it (if it exists;
   if not, don't list it).
3. Evidence: a legend.png before/after in docs/evidence/devtools/.

## Part B: action animations round 2 (owner feedback from the evidence strips)
- Stagger is barely visible: make a clear hit reaction (body recoil away from the hit, head snap, 2–3 frame squash,
  brief stumble step), scaled by damage.
- Roar's active phase looks like a bite: roar = head UP and back, jaw wide and held, chest/neck expanded, a slight rear
  back, no forward lunge, plus a visible pulse (a small shockwave ring or dust) if cheap.
- Bite has no grip: on a connecting bite, the jaw closes on the target and holds for the C hold/active window, head
  tugs (small shake), the target is pulled a little visually (visual only; C owns positions), then releases.
- Charge only shows the crouch: show the full run-up: crouch → explosive dash with stretched body, head low, legs at
  full gallop → impact (squash + the target's stagger) → recovery; the visual dash must match the C displacement.
Keep timings tied to the C phases (windup/active/recover). Update tests in the actions suite; regenerate the evidence
strips (6 frames per action) and look at them yourself before claiming done; if something still reads wrong, say so.

## Done means
make godot-test godot-play-test godot-devtools-test and the actions suite green; evidence images committed;
a short "round 2" section in docs/godot/ACTIONS.md with what changed and what still looks weak.
