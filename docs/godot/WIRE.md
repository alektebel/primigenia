# Wiring the modules into one game (branch godot-wire)

The five Godot modules (M0 foundation, creature, locomotion, UI and audio, studio) were built and tested apart. This
step connects them following their own documents and changes them as little as possible. How to play and the known
limits are in `godot/README.md`; tests: `make godot-play-test` plus the five module targets.

## Connections

| From | To | Where |
|---|---|---|
| `Game.player_genome()` (newest studio save, else Merodeador) and `garfio.json` | `Creature` (godot/creature) | `game/actors/actor_host.gd`; the placeholder is only a fallback when the module is missing |
| world tick: `StageWorld.sample()` (interpolated position, yaw, tick velocity) | `LocoController.step`, then `loco_rig_adapter.loco_apply` | `game/actors/actor_driver.gd`; feet use `Game.ground` through the controller's ground function |
| controller `footfall` signal | `Audio.footstep` | `ActorHost.footfall` -> `StageUI.on_footfall` |
| world state and `combat_events` | `GameUI` vitals, card, wind-up tell, damage numbers, flashes, `Audio.combat_event` | `game/stage/stage_ui.gd` |
| click on a creature (`Game.creature_clicked`) | `GameUI.select` + radial | `stage_ui.gd` (radial opens at the click position) |
| radial mode / keys 1-4 / Space / Q / E | C orders: `attack`, guard, dodge | `stage_ui.provide()` replaces `PlayerInput.sample` as the stage input provider |
| player height above the valley floor, slope, speed | `Audio.update_ambience` | `stage_ui.gd`, every frame |
| `Audio` autoload (`audio/audio_manager.gd`), bus layout | kept in `project.godot` | |
| studio (`studio/ui/studio.tscn`) | `creature_view_real.gd` (godot/creature) satisfying `creature_view.gd` | `studio.gd` calls `make_default()`, the placeholder view is the fallback when `res://creature` is absent (the studio's own test project) |
| menu | Play = island, Creator = studio, studio saves `Game.studio_dir`, `Game.player_genome()` reads it | `game/menu/main_menu.gd` |

Input frame (PLAN-feel): `PlayerInput` latches `view_yaw` when the pressed key combination changes (`frame_yaw`), so a
held direction is a straight run; `island.gd` sets `strafe_latch`, `tank`, the creature's heading and position each frame,
re-latches after a mouse orbit, and passes `intent_yaw()` for the player's `sample.intent` (the controller turns head
and shoulders toward it). `StageWorld.sample()` is a Hermite interpolation (`speed` is `|vel|`, the C speed is `speed_c`).

Orders follow `web/stage/simulation.js action()`: an attack stays pending and is re-issued every tick (the C verb only
lasts while re-issued) until movement keys, a click-to-walk, the target's death or the end of the fight; guard and dodge
last one tick. Choosing Attack in the radial starts the attack with the first move (Bite).

## The rig adapter against the real rig (six contract points)

Checked in `play_test.gd` on Merodeador, Zancuda, Babosa, Garfio and Merodeador with each of the 8 leg types:

1. Units: unit 1 (the web stage drew the rig at scale 1); hip heights 1.7 m (Merodeador), 2.5 m (Zancuda) are inside 0.02-5 m.
2. Axes: head ahead along +Z, side +1 legs have hip x > 0; no mirrored rig. **Bone signs verified on the real skeleton**
   (they were only assumed): neck pitch + lifts the head, neck yaw + turns toward +X, tail pitch + lifts the tip, tail yaw + swings it to -X.
3. Soles: the rig IK reaches every planted foot target. **Mismatch found and fixed in the adapter:** the rig's hips ride the
   spine bones and sit up to 27 mm from the controller's girdle model, and the rig IK stops 1 cm short of straight, so at full
   extension the foot missed by up to 9 mm (Zancuda). The adapter now takes 4 cm (`REACH_MARGIN`) off every described leg;
   the planted sole error is below 0.002 mm and flat-footed soles are within 2 mm of the ground. Heel-off raises the sole point
   by design, so planted soles are only compared flat-footed.
4. Hanging legs are left out: the count of driven legs equals the count of legs with `hang <= 1 mm`.
5. Part masses are still the provisional table (positive for every part; not measured).
6. Foot names of every leg type are in the controller's FOOT table.

Also found and fixed in the adapter: a legless body (Babosa) floated 7.5 cm above the ground because the rig's `ground_offset`
uses the ring circles while the built tube is an ellipse. `belly_drop()` measures the lowest body vertex and
`loco_apply` lowers the creature so it is 3 cm above the ground; this is where "Babosa floats above its shadow" came from.
The sun shadow bias is also set to the creature preview's values.

## Look

* **Sky seam.** The sea plane stops at the camera far plane (12 km) and the sky below the horizon was a flat colour, so the far
  view had a hard line. The far sea now fades into the sky's horizon colour (`horizon_color()` in `look.gdshaderinc`, shared by
  `water.gdshader` and `sky.gdshader`) and the sky below the horizon is that colour with the sun glow flattened: no seam
  (`docs/evidence/godot/wire/far.png`).
* **Rivers.** The channel blend is 0.1 instead of 0.55 and the strip is a faint dark-green trace, not blue.
* **Creature exposure.** Only creatures use the scene's light and ambient (terrain, water, grass and sky are unshaded shaders
  with the hero numbers baked in), so the sun and ambient were retuned instead of the tone map: sun `#ffcf9a` energy 4.4,
  ambient (0.62, 0.75, 0.92) energy 1.5 (`look.gd`, `CREATURE_*`). g-creature's preview used exposure 1.4 with white 1.0; the
  world's calibrated 0.926 / white 15.4 divides the highlights by 1.28 less, so mid tones need about twice the light.
  Comparison: `docs/evidence/godot/wire/exposure.png` (top the creature preview, bottom the same seeds in the island).

## Verified

`make godot-play-test`: 178 checks, 0 failures, headless, about 7 s, including "no engine errors" through an `OS.add_logger`
hook. It runs the real flow with synthetic input events (clicks through `Viewport.push_input`, key events). The studio part
saves into `user://play-test`, never into the real studio folder. The module targets still pass: M0 301, UI 132,
studio 800, creature 1456, locomotion 192.

## Not verified / open

* Performance and feel on a real GPU; everything was run under llvmpipe. The grass in the play test is 3000 blades.
* Garfio's ranged spit usually beats the Merodeador (C balance), so a fight is short; no retreat/flee key is wired
  (the C `flee` verb exists but has no key).
* Befriend / Observe / Intimidate have no C verbs; they only show a message.
* The wild creature's idle audio (`cry idle`) and the DNA reward number are placeholders; the respawn fade is not drawn.
* Studio Test mode walks in a circle of about 3 m radius; very large creatures leave the frame.
* Studio hit-testing uses the built meshes (`TriangleMesh`), the mirrored copies count as the same part; the vertebra
  handles are spheres of 0.2 radius as in the placeholder.
