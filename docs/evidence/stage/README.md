# Primigenia: walkable valley (P3b)

From the repository root:

```sh
source ~/emsdk/emsdk_env.sh
nice -n 10 make wasm stage
nice -n 10 python3 -m http.server 8765 --bind 127.0.0.1
# Open http://127.0.0.1:8765/web/stage/
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

The wild **Garfio** is a separate red, crested, hooked-arm species, authored in
`web/stage/species/garfio.json`. It roams around its home, notices within 15 m
and engages at 5.5 m. Its orders come from the C greedy bot. Its shared
`garfio-combat.json` profile gives it 195 HP, level-3 charge and level-1 tail;
bite is disabled, so its jaw remains anatomical while it fights with horn and
tail. Other stats come from the normal studio projection (100 stamina, 4 m/s).
Only this enemy profile was tuned; player projection and core moves are unchanged.
A kill leaves a grounded carcass and displays **DNA +12** as a placeholder:
no currency is stored or awarded.
Death fades out and respawns at the nest with restored health/stamina and no
penalty. Fleeing sends the enemy home. Free roaming uses radius collision,
slope-adjusted speed and a deep-water cutoff; the fight uses the unchanged
40×40 m C arena contract, with visual height sampled from valley `groundY`.

Body radius is half the greater of the spine's horizontal span and widest
diameter, rounded to centimetres and clamped to 40–400 cm. Garfio is 120 cm;
the default Merodeador is 300 cm; the three combat fixtures are 150 cm.
C separates centres by the sum of the two radii, clamps each body by its own
radius and uses the target radius for attack reach. Profile values 0 and 60
use the literal 0.6 m default and preserve the existing default-radius hashes.
This is a conservative circular body envelope, not per-limb mesh collision.

## Verification

Use the existing Emscripten SDK and preinstalled Playwright; no installation is
performed. For browser tests, serve the repository on port 8765:

```sh
nice -n 10 python3 -m http.server 8765 --bind 127.0.0.1
# In another terminal, with NODE_PATH pointing to the existing Playwright module:
export NODE_PATH=/home/diego/Desarrollo/cpore-wt/_agent/node_modules
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

`stage_winnability.mjs` runs **without a browser**, using `simulation.js` and
WASM with the shared `stage_policy.mjs` competent player: approach, dodge charge
windups, guard other windups when equipped, and choose a damage-per-duration
attack during recovery. The original policy is unchanged by calibration.
Seeds 0–49, flat ground and a 90-second cap give:

| Player fixture | Wins / 50 | Win rate | Deaths | Timeouts / escapes |
|---|---:|---:|---:|---:|
| biter | 39 | 78% | 11 | 0 / 0 |
| guard | 21 | 42% | 29 | 0 / 0 |
| spitter | 30 | 60% | 20 | 0 / 0 |

Every fixture must stay within **35–80%** player wins. Run it alone with
`nice -n 10 node tests/stage_winnability.mjs` after `make wasm`, or as part of
`make stage-test`. These are scripted-policy rates, not human difficulty measurements.

The desktop victory sequence uses that same competent policy in another real
duel. Enemy stats and health are never edited for captures. The impact capture
asserts that the interpolated body envelopes touch within 5 cm; browser runs
also reject C body penetration. Contact radii, gap, HP and tick are recorded
in `results.json`. The mobile check loads a saved /4 creature containing the
G48 parts and drives a real touch stick, action buttons and camera orbit at
390×844. Keyboard movement, pause and
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
- `tourney.log`, `tourney-comparison.json`: full default-radius tournament and baseline comparison.

## Default-radius balance regression

`nice -n 10 make tourney` has **byte-identical complete application stdout**
against a separately compiled merge-base build (`git merge-base HEAD p3a-wasm`,
`12722e33bbfaf49e05d48e8a6ef78e81fc394010`, before the radius change).
The baseline sources were extracted under this worktree's ignored `build/`
directory; no other branch or worktree was changed. The output SHA-256 and
compiler are recorded in `tourney-comparison.json`.

| Default-radius build | Field mean |
|---|---:|
| brawler | 50.9% |
| spitter | 62.4% |
| tank | 43.6% |
| skirmisher | 45.7% |
| allrounder | 47.4% |

The worst field mean is 62.4% (65% ceiling), and the worst pooled build pair
is 73.5% (90% ceiling), unchanged. Tournament acceptance still fails its four
existing gates: raw/resource dominance and raw/resource equilibrium support
(three substantial moves each). The application exits 1; `make tourney` exits 2.
Native correctness and WASM parity pass independently of these balance gates.

Not verified: real-GPU frame rate, controller hardware or human combat/camera
feel. Roaming collision is intentionally simple; the C encounter still uses
its local flat arena, not imported valley hills or obstacles. Full C genome
admission, DNA economy, eggs, ecosystem, other biomes and swimming remain later
work. The existing P2 balance acceptance failures are unchanged; `make test`
checks correctness and does not claim that the tournament is balanced.
