# Owner playtest: C0 tools + C1 nav/actions (10–15 min)

One session on the GPU. Build and run first: `make godot && godot --path godot`.
Rules: tick the box when it behaves; **press F8 if not** — F8 saves a screenshot,
60 s replay, scenario, tuning and your note into `feedback/<stamp>/`, which is
exactly what the agents need. Say in the note which line failed.

## Start (1 min)

- [ ] `make godot` finishes clean, `godot --path godot` opens the main menu → no errors, Play / Creator buttons. (F8 if not)
- [ ] Click **Play** → island loads with a progress screen the first time; you spawn near the nest. (F8 if not)

## Movement + camera (2 min)

- [ ] W A S D / arrows move camera-relative; Shift sprints and drains stamina → speed feels responsive, stamina bar drains and refills. (F8 if not)
- [ ] Left click and hold on the ground → creature walks to the pointer. (F8 if not)
- [ ] Mouse wheel down/up in steps → continuous zoom from over-the-shoulder out to a strategic island view and back, no jumping. (F8 if not)
- [ ] Left drag (more than a small nudge) orbits the camera; a plain left click still moves the creature → click and drag are easy to tell apart. (F8 if not)
- [ ] Orbit while standing still, then walk → the camera stays where you put it while you stand, eases back behind you when you move. (F8 if not)
- [ ] Press **Home** (or middle click) → camera snaps back behind the creature at the default distance. (F8 if not)

## Legend F1 (1 min)

- [ ] Tap **F1** → small corner hint with the 3–4 keys that matter now. (F8 if not)
- [ ] Hold **F1** → full sheet of every key and mouse gesture, in two columns. (F8 if not)
- [ ] Find the console key on the sheet → on a Spanish keyboard it must read **º** (the physical key left of 1), not "`" or "backtick". (F8 if not)

## Console º / F12 (3 min)

- [ ] Press **º** (or F12) → console opens; `help` lists commands; arrow keys and Tab autocomplete work. (F8 if not)
- [ ] Type `tp crater` (or a site name from F2) → you teleport there. (F8 if not)
- [ ] Type `spawn garfio 3` → three Garfio appear ~12 m ahead. (F8 if not)
- [ ] Type `overlay path on`, then left-click a far target → the planned route is drawn on the ground; `overlay path off` clears it. (F8 if not)
- [ ] Type `timescale 0.2` then `timescale 1` → world visibly slows and returns. (F8 if not)

## F2 sites (1 min)

- [ ] Press **F2** → searchable site picker; pick a site → teleport there. (F8 if not)
- [ ] Stand somewhere, press **Ctrl+B** → bookmark saved; it appears in the F2 list and `tp <name>` reaches it. (F8 if not)

## F3 / F4 tuning A/B (2 min)

- [ ] Press **F3** → tuning panel with sliders grouped by area; move a movement slider → the change applies instantly, no restart. (F8 if not)
- [ ] Press **F4** → swaps A/B settings; the HUD/legend says which slot is active; toggling again returns to the first feel. (F8 if not)

## F5 / F6 scenarios and saves (2 min)

- [ ] Press **F5** → quick save written; press **F6** → scenario picker shows the saves plus `nest_start`, `garfio_close`, `far_meadow`; load one → you are in that situation. (F8 if not)
- [ ] Esc → pause menu → **Save game**, then **Load game** from the main flow → state comes back (position, hp). (F8 if not)

## F8 feedback (already used above)

- [ ] Open the newest `feedback/<stamp>/` folder → screenshot, scenario, replay log + hashes, tuning, meta, log.txt are all there. (F8 if not)

## Pause / step / [ ] (1 min)

- [ ] **P** pauses and resumes; **.** advances exactly one tick per press; **[** and **]** step the timescale ladder down and up → the HUD chip shows the current timescale. (F8 if not)

## Click-to-move across a cliff (2 min)

- [ ] Get on high ground, left-click a target on the far side of a cliff band → the creature walks *around* the cliff, never stuck jittering into it. (F8 if not)
- [ ] Click a target in the sea or in an enclosed pocket → the order is refused clearly (message or drop), no silent walk into water. (F8 if not)
- [ ] With `overlay path on`, click across a cliff → the drawn route bends through passable ground; the creature follows it to the end. (F8 if not)

## Fight vs Garfio (3 min)

- [ ] Find the wild Garfio near the nest (or load `garfio_close` from F6) and click it → card, marker, radial menu open. (F8 if not)
- [ ] Radial Attack (or A), then keys 1–4: Bite, Charge, Spit, Tail strike → each move animates and lands with the damage; the attack keeps firing until you move or the fight ends. (F8 if not)
- [ ] Watch the enemy before each hit → a readable wind-up tell under the marker; guard with **Space**, dodge with **Q/E** actually avoids damage sometimes. (F8 if not)
- [ ] Look at bite grip → the victim is held and pulled; **roar** → a held head-up cry with a pulse ring; **charge** → visible run-up and impact squash. (F8 if not)
- [ ] Take a hit → stagger reads clearly (recoil, head snap, damage scaling with size); the fight overall is winnable and readable, not chaotic. (F8 if not)
- [ ] Radial Befriend / Observe / Intimidate → the move plays on your creature and an honest "not in this build yet" message appears (no C verb yet — expected). (F8 if not)

## Features that only have unit tests (no live check yet)

Verified headless only — this session is their first live look:

- **A\* pathfinding core** (`make nav-test`, 20 far targets, determinism) — live check above.
- **Snapshot/restore, replay and golden hashes** (`test_world`, `world_cli` goldens) — no player-facing check; only the scenarios above touch it.
- **F5 quick-save write path** (`godot-devtools-test`); docs/godot/DEVTOOLS.md admits it is unverified in a real save flow — check it above.
- **Tuning A/B persistence** (`tune save/load`, `primigenia.tuning/1` files) — no owner has confirmed a diff loads across a restart.
- **F8 bundle contents** (devtools tests write it under software GL) — never inspected by the owner on the real GPU.
- **Audio** (`godot-ui-test`, bus layout, 16-voice pool) — loudness has never been listened to by ears; judge footstep/hit/ambience balance today.
- **Feel numbers** (`godot-feel-test`: 5.2/8.84 m/s, turn curves) — the roadmap gate is *your* judgement, not the numbers.
- **Camera zoom curve** (`godot-camera-evidence`, llvmpipe only) — real-GPU frame times at far zoom are unknown; watch for stutter while zoomed out.
- **Island generation + warm** (`godot-heights-test`, 3.4 s first run, 40 ms cached) — confirm the second launch is instant.
- **Combat balance** (`make tourney`, 42/58/76 % winnable) — live: does the Garfio fight *feel* fair?
- **Studio** (824 headless checks, GPU unverified) — open Creator briefly; part thumbnails, sculpt, Ctrl+S save, "Probar".
- **Agent socket** (`make godot-agent-test`) — automation only; nothing to tick by hand, listed for completeness.
