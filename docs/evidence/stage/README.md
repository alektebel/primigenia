# Primigenia: walkable valley (P3b)

From the repository root:

```sh
make wasm && python3 -m http.server
# Open http://localhost:8000/web/stage/
```

The checked-in stage is generated with `make stage`. Its builder imports the
hero's complete valley patch sequence, then adds play mode. Hero output and
terrain functions are unchanged. Golden hour is the default; `?t=noon`,
`?t=overcast` and `?t=night` use the hero's other presets.

The stage reads `cpore.creature.v4`, the studio's local-storage key. Alternatively
open `?creature=/tests/fixtures/combat/biter.json` (fixture wrappers and bare
`cpore.creature/4` documents are accepted). With no saved creature, Merodeador
is the seed. Both the stage and studio import `web/creature/rig.js`: materials,
G48 anatomy, growth regions, attachment frames, IK and gait have one source.
The studio link returns to the editor; reload the stage after editing.

WASD/arrows move relative to the orbit camera; drag the scene or use the right
gamepad stick to orbit. Shift sprints using stamina. Move keys 1–4 follow the
available profile moves, Space guards when armour is equipped, Q/E or a double
tap dodges. On touch, use the left stick, Sprint and the action buttons. Escape,
P or the pause button pauses. To flee, run past the arena's gold boundary and
separate from the enemy; Sprint uses C's stamina-paying flee verb in combat.

The wild Merodeador roams around its home, notices within 15 m and engages at
5.5 m. Its orders come from the C greedy bot. A kill leaves a grounded carcass
and displays **DNA +12** as a placeholder: no currency is stored or awarded.
Death fades out and respawns at the nest with restored health/stamina and no
penalty. Fleeing sends the enemy home. Free roaming uses radius collision,
slope-adjusted speed and a deep-water cutoff; the fight uses the unchanged
40×40 m C arena contract, with visual height sampled from valley `groundY`.

## Verification

Use the existing Emscripten SDK and preinstalled Playwright; no installation is
performed. For browser tests, serve the repository on port 8765:

```sh
nice -n 10 python3 -m http.server 8765
# In another terminal, with NODE_PATH pointing to the existing Playwright module:
nice -n 10 make stage-test
nice -n 10 make studio-test
nice -n 10 make test
nice -n 10 make wasm-test
```

`stage_play.cjs` uses the required cached Chromium (exact version in `results.json`), exclusively SwiftShader:
`--use-angle=swiftshader --enable-unsafe-swiftshader`. Each combat fixture walks
into an encounter, takes and deals damage, and reaches death within 90 simulated
seconds. The same fixed timeline runs at **30 and 73 forced rAF Hz**; complete
encounter logs and final hashes match. Each exported log is replayed by native
`build/combat_parity --replay`. The ranged timeline initially waits for contact,
then attacks; this deliberately exercises damage to both sides rather than an
unhit ranged win. These rates are test inputs, **not measured rendering FPS**.

The desktop victory sequence is another real duel: dodge the first charge,
then charge back. Enemy stats and health are never edited for captures. The
mobile check loads a saved /4 creature containing the G48 parts and drives a
real touch stick and action button at 390×844. Keyboard movement, pause and
viewport overflow are checked. Unit tests cover sprint, water, obstacles,
death/respawn, boundary escape/return and frame independence. Native and WASM
suites, studio document/growth/interaction/touch/G48 tests, and byte-identical
hero regeneration are separate gates. The unchanged hero grid is retained;
its full image grid is not rerendered for this task.

- `explore.png`: golden valley and the default studio seed.
- `fight-windup.png`: a C windup and its terrain-following preview cone.
- `fight-hit.png`: a real HP loss, hit flash and damage numbers.
- `victory.png`: real enemy death, carcass and DNA placeholder toast.
- `mobile-touch.png`: 390×844 touch controls and a saved G48 creature.
- `results.json`, `*.log`: browser settings, outcomes, final hashes and replays.

Not verified: real-GPU frame rate, controller hardware or human combat/camera
feel. Roaming collision is intentionally simple; the C encounter still uses
its local flat arena, not imported valley hills or obstacles. Full C genome
admission, DNA economy, eggs, ecosystem, other biomes and swimming remain later
work. The existing P2 balance acceptance failures are unchanged; `make test`
checks correctness and does not claim that the tournament is balanced.
