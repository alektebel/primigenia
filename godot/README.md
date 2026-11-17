# Primigenia, Godot 4 desktop frontend (G76)

One playable game: main menu, the island stage with real creatures, and the creature studio. `docs/godot/WIRE.md`
says how the modules are connected and what was verified.

Godot 4.7.2, GL Compatibility renderer, GDScript for game code, C++ GDExtension over the C core.
Desktop only (Linux built and tested; the Windows/macOS lines of `cpore.gdextension` are
placeholders and are not built in M0).

## Build and run

```sh
make godot && godot --path godot
```

`make godot` compiles `build/libcpore.a` (the C99 core, unchanged flags), builds the extension
`godot/bin/libcpore.linux.template_debug.x86_64.so` with SCons, seeds `godot/.godot/extension_list.cfg`
(without it the first import aborts) and imports the project.

Dependencies live outside the repository (nothing is downloaded by the build):

| What | Where | Pin |
|---|---|---|
| godot-cpp | `/home/diego/Desarrollo/cpore-wt/_agent/godot-cpp` (`GODOT_CPP=`) | master at `2a4c066e1e8c121046e9d35fe91cc8e726861c48`, built with `api_version=4.7` |
| SCons 4.11.1 | `/home/diego/Desarrollo/cpore-wt/_agent/godot-venv/bin/scons` (`SCONS=`) | |
| Godot | `godot` on `PATH` (`GODOT=`) | 4.7.2 stable |

If godot-cpp is missing: `git clone https://github.com/godotengine/godot-cpp.git`, check out the pinned commit,
`python3 -m venv` + `pip install scons==4.11.1`.

First run generates the island (about 3.4 s, loading screen with progress) and caches it in
`~/.local/share/primigenia/terrain/` (about 8.7 MB, zstd); later runs load it in about 40 ms.

## How to play

```sh
make godot && godot --path godot
```

The main menu has **Play** (the island stage) and **Creator** (the studio). Play uses the creature you saved last
in the studio (`user://studio/*.json`, newest file; `~/.local/share/primigenia/studio/`) and the bundled Merodeador
if there is none. `--genome=<path>` after `--` overrides it, `--play` after `--` skips the menu.
The wild Garfio lives about 60 m from your nest; it is territorial and may come to you.

### Controls (stage)

| Input | Action |
|---|---|
| W A S D / arrows | move, camera-relative |
| Shift | sprint |
| Left click, hold | walk to the pointer |
| Left click on a creature | select it: card, marker and the radial menu (Attack, Befriend, Observe, Intimidate) |
| Radial: click a sector, or A / B / O / I | choose the mode; it sets what keys 1-4 do. Choosing Attack starts an attack on the selection (the first move, Bite) |
| 1-4 | the four moves of the current mode (Attack: Bite, Charge, Spit, Tail strike). Each keeps being re-issued until you move, click the ground or the fight ends |
| Space / Q / E | guard / dodge left / dodge right (one tick each) |
| Tab | reopen the radial for the selection |
| Right or middle drag, wheel | orbit, zoom |
| Esc | close the radial, or pause (volumes, mute, back to the main menu) |

### Controls (studio)

Mouse: drag a part from the palette onto the body (or click it, then click the body); click a part to select it; drag
it to move, outside the body to delete; the green handle rotates, the blue one tilts; drag a vertebra (amber ball)
to sculpt, wheel over it to thicken; drag empty space, or right/middle button, to orbit; wheel to zoom.
Keys: Ctrl+Z / Ctrl+Y, Delete, arrows (move the selected part), Esc, **Ctrl+S save**, Ctrl+O import. "Probar" > play
walks the creature in a circle with the locomotion module. "Menu" returns to the main menu.

## How it feels

Jog 5.2 m/s, sprint 8.84 m/s (Shift, about 7 s of stamina), 90 % of top speed in 0.4 s (0.6 s sprinting). Turns are curves:
a 1.6 m circle at jog, 2.7 m at sprint; a reversal at jog takes 1 s (it brakes, pivots, runs again). WASD keeps the camera
frame of the moment the keys changed, so a held S or A runs straight and the camera does not whirl; the camera follows at
most 100 deg/s and never swings while you run toward it. Settings (`Game.settings`, `user://settings.cfg`):
`controls/strafe_latch` (true), `controls/tank` (false: A/D turn, W forward, S reverse), `camera/kick` (false).
Measurements and the before and after table: [docs/godot/FEEL.md](../docs/godot/FEEL.md); `make godot-feel-test`, `make godot-feel-evidence`.

## Make targets

| Target | What |
|---|---|
| `make godot` | build the extension and import the project |
| `make godot-test` | M0 headless tests (`godot/game/tests/run_m0_tests.gd`), 301 checks |
| `make godot-ui-test`, `godot-studio-test`, `godot-creature-test`, `godot-loco-test` | the module tests (132, 800, 1456, 192 checks) |
| `make godot-play-test` | the whole game headless: menu, Play, 10 s walk, click Garfio, radial, encounter, HUD, audio, rig contract on the real rig, studio add part + save, Play uses it, no engine errors (`godot/game/tests/play_test.gd`) |
| `make godot-render-test` | software-GL render tests (tone-map calibration gate, sky, contact shadow, LOD cracks) |
| `make godot-evidence`, `make godot-wire-evidence` | screenshots into `docs/evidence/godot/m0/` and `docs/evidence/godot/wire/` (xvfb + llvmpipe, never the GPU) |

`make test` (core tests) is independent and unchanged.

## Layout

`extension/` C++ glue over the C core; `game/` foundation, island, stage bridge, `stage/stage_ui.gd` (HUD and audio glue),
`actors/` (creature hosts), `menu/`; `creature/` the creature builder; `locomotion/` gait, IK and the rig adapter;
`ui/`, `audio/` HUD, radial menu, sounds; `studio/` the editor (`creature_view_real.gd` backs it with `creature/`).
Interfaces and what is verified: `docs/godot/M0.md`, `CREATURE.md`, `LOCOMOTION.md`, `UI.md`, `STUDIO.md`, `WIRE.md`.

## Procedural actions (G77)

Every combat action, reaction, stagger, death, and the cosmetic Befriend / Intimidate / Observe moves are built at runtime
from each creature's own bones and synced to the C combat phases (`godot/actions/`, docs/godot/ACTIONS.md). Attack from the
radial (or keys 1-4) and watch the bite, charge, spit and tail strike on both creatures; Guard (Space), Dodge (Q/E), hits,
stagger, stun and death are drawn too. Befriend (Sing, Dance, Charm, Pose) and Intimidate (Roar, Display) play on the
player's creature when chosen from the radial's keys (nothing is sent to C). `make godot-actions-test` (322 checks) and
`make godot-actions-evidence` need no GDExtension.

## Known limits

* **The C world is flat.** Its heights are analytic and it only knows a +-195 m square around the start valley (valley
  floor 42 m); the rest of the island is visual. Creatures are drawn at `Game.ground(x, z)` and the player cannot walk
  out of the square (C clamps it; there is no wall or message yet).
* **Only combat exists in the world.** Befriend, Observe and Intimidate show their moves but only tell you they are not
  in this build; the C stage has verbs for attack, guard and dodge only. Species card fields other than name and
  temperament (diet, relationship, likes) are placeholders.
* **Balance is the C core's:** in the scripted play test Garfio's ranged spit hurt the Merodeador first and a Charge then won; there is no flee key yet.
* One wild creature (Garfio); no trees, rocks, flowers or clouds (hero extras); no pre-baked island in the repository
  (the first run generates it in about 3.4 s and caches it in `~/.local/share/primigenia/terrain/`).
* Studio: the creature view rebuilds the whole creature after each edit (about 15 ms); the part thumbnails are
  procedural stand-ins; sound has not been reviewed by ears; gamepad and touch are not supported.
* Linux built and tested only; Windows and macOS libraries are not built. Everything was checked under software GL
  (llvmpipe): frame rate and the feel of the controls on a real GPU are for the owner to judge.
