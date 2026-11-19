# HATCHLING: the starter body (S1 of motion-flight-plan, DESIGN A29)

The player starts as a ~1.2 m, ~36 kg hatchling instead of the 6 m, 6 t Merodeador. Merodeador stays as the adult form
(G78 growth), a wild species and a studio seed. Data only: `core/` and every golden are untouched.

## What changed

- `godot/game/data/hatchling.json` (new): Merodeador x 0.165 with juvenile proportions (head nodes r x 1.45, eyes x 1.9 of the
  scale, a 0.3 pico instead of fauces so the game does not append a 1.0 pico, no horn, no spines, legs keep the 0.05 m minimum width). `Game.player_genome()` falls back to it.
- Studio opens on the `Hatchling` seed (`studio.gd`, `SEEDS` in `studio/model.gd`). `Model._init` still starts on Merodeador so
  the 888 studio checks keep their meaning.
- `chase_camera.gd`: closest view floored at 1.6 m (`MIN_DISTANCE`), look-at at least `h + 0.45 m` above the ground (`EYE_RAISE`);
  `island.gd` near plane floor 0.25 -> 0.05 m. Bodies >= 0.9 m tall are unchanged (z 0 is 1.8 h).
- Tests: `test_hatchling.gd` (in M0), two camera checks, play_test checks the creator opens on the hatchling, `feel_test.gd`
  keeps measuring Merodeador (the gates were calibrated on it; pass `hatchling` after the out dir for the starter).

## Measured (adapter, `game/tests/hatchling_measure.gd`)

| | Merodeador | Hatchling |
|---|---|---|
| body length / hip height | 6.79 m / 1.69 m | 1.18 m / 0.26 m |
| mass (density 1000) | 6247 kg | 36.0 kg |
| plan | quadruped, graviportal | quadruped, light |
| C radius | 300 cm | 50 cm |
| Fr at roam 4.0 / jog 5.2 / sprint 8.84 m/s | 1.0 / 1.6 / 4.7 | 6.3 / 10.7 / 30.9 |
| gait at those speeds | amble / amble / trot | gallop / gallop / gallop |
| trot band | 2.9-5.5 m/s | 1.1-2.5 m/s (walk below 1.1) |

The hatchling trots at 1.1-2.5 m/s and gallops from 2.5 m/s, so every play speed (4.0 and up) is a gallop; there is no run
toggle yet (run-fall/S2). `docs/evidence/godot/hatchling/gait_measure.txt` is the real-rig `gait_real.gd mode=measure` output
(Fr 1.1 trot, Fr 5.5 gallop 3.7 m/s cadence 4.1 Hz stride 0.9 m, Fr 12.5 gallop 5.6 m/s).

## Winnability (native C, `game/tests/winnability_c.gd`)

`tests/stage_winnability.mjs` cannot run: `cpworld.js` expects World ABI 2 and the C world is version 3 (it already failed on
the base, see PLAN-feel). `winnability_c.gd` ports `stage_policy.mjs` to the C world through CporeWorld (flat terrain 1,
Garfio 12 m away, 50 seeds, walk up, dodge charges, guard, attack in the recovery window).

| genome | loadout | result |
|---|---|---|
| hatchling (pico: mouth 1 spit 1), starter loadout and `full` alike | default | 6/50 = 12 % |
| Merodeador, starter loadout (before this change) | default | 0/50 = 0 % |
| Merodeador, full parts (mouth 2, charge 4) | `full` | 48/50 = 96 % (out, as before: its horns) |

Sanity of the port: an earlier hatchling variant with fauces (mouth 2) scored 21/50 = 42 %, the same as the web biter fixture.

The in-game starter loadout loses to Garfio for both bodies, and the hatchling (smaller C radius, 50 cm) does better than Merodeador.
That is the intended game (grow, find parts, then fight the boss), but the 35-80 % window is not met by the pico-only starter
for either body: see open questions in the report.

## Open

- Gallop slide: `feel_test.gd hatchling` fails 20 gates (planted-sole slide 42-51 mm vs 20, "a foot always in contact" is
  false because a gallop has flight, flat planted foot frames 125). The gates assume a ground-contact gait. Belongs to loco.
- Grass blades reach 1.2-1.4 m near the nest, taller than the 0.65 m hatchling (see `after_2_meadow*.png`: it stays visible at
  the default view, the closest view is cramped by grass): the shader is art/wl1-lighting's, not touched.
- Speed is still the flat profile `speed 4.0`: a 0.26 m hip at 4 m/s is a sprint (S2 scales speed by Froude).

## Evidence

`docs/evidence/godot/hatchling/`: `before_*` (Merodeador) and `after_*` (hatchling), 1920x1080, software GL, sites nest, meadow, cliff (cave
apron) and 9 m from Garfio, plus the closest zoom at the meadow; `gait_measure.txt`. Regenerate with `game/tests/hatchling_evidence.gd`.
