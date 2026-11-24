# Ambient fliers (DESIGN A59, first step)

Visual-only flying wildlife over the valley. No C entities, no snapshot change (main stays at snapshot 16); the real C flying species come once the T9 roster has room (roster v9 reserves the slots). Advances A59 "flying wildlife"; reuses the flight picks A56/A57 (flap-glide, wingover, flare, running landing) as behaviour, not as code.

## Files
| File | What |
|---|---|
| `godot/game/island/fliers/flier_species.gd` | four species and their starting numbers (span, mass, cruise, stall, beat Hz, altitude, flee radius, flock size) |
| `godot/game/island/fliers/flier_flock.gd` | habitat planner (`plan`, pure from terrain + seed), the 60 Hz simulation (`step`), one MultiMesh per species |
| `godot/game/island/fliers/flier_mesh.gd` | procedural bodies (lofted torso, beak, tail, wing strips with a span weight in COLOR.a) |
| `godot/game/shaders/flier.gdshader` | wingbeat in the vertex shader (INSTANCE_CUSTOM: phase, amplitude, fold, legs) so the CPU writes one transform per bird |
| `godot/game/tests/test_fliers.gd` | planner, determinism, ground clearance, takeoff / landing, flee |
| `godot/game/tests/fliers_clip.gd` | xvfb clip recorder (fly, land, takeoff, flee, flock) |

## Species
| Species | Lore | Habitat | Flight |
|---|---|---|---|
| Alariz | 2.4 m, 85 kg scavenger | ridges (ground above half the island's high point), flock of 1-2, 2 flocks | soars: slow 1.6 Hz beat, long glides (LD 14), thermals over the home ridge, spirals on a drifting circle |
| Bello-pico | 25 cm, 150 g | flat meadow and shore ground near water, flocks of 4-8, 3 flocks | flap-glide (0.9 s beats, 1.6 s glides), tight banked turns |
| Zancuilla | 25 cm, 280 g | flat ground near water, 2-4, 2 flocks | fast straight flap bursts, stilt legs hang when perched and tuck when cruising |
| Alasucena | 12 cm | flat ground away from the shore, 2-5, 3 flocks | the only hoverer: flits between hover points, upright pitch on the perch |

Numbers are starting values; speeds follow the flight lab polar (docs/evidence/loco/flight.md). The test checks that nobody exceeds `vmax` or flies under the stall speed in cruise.

## Behaviour
- Flock states: perched, flying, landing. A flock flies for `fly_wait` s then picks a roost spot (not within 1.6 x the flee radius of the player) and every member takes a free spot near it; it perches for `perch_wait` s. Day fliers (all but the zancuilla) roost when `moon_k` > 0.65.
- Flight: each bird rides a ring round the flock's moving centre. Altitude target = flock altitude above ground, raised to the terrain 0.6 s / 1.5 s / 3 s ahead plus the species clearance; the position is clamped above the visual ground every step. Flapping climbs (to `climb` x speed), a glide sinks at speed / LD (less the thermal), so flap-glide comes out of the altitude controller and the timers. A burst is forced when low or near the stall speed. Turn rate from the bank limit, `w = g tan(bank) / v`; roll follows the real yaw rate.
- Landing: approach point on the bearing the bird comes from, then a straight glide (slope 0.12-0.16), speed bleeds to walking pace, flare with legs down and a nose-up pitch, touchdown on the perch with the wings folding. A hoverer pivots on the spot and settles. A landing that has not made it in 60 s gives up and climbs out.
- Takeoff: a staggered wing-up hop (0.5 s), climb out at the species pitch, wings unfold, legs tuck.
- Flee: a perched bird whose distance to the player (vertical halved) is under `flee` x (1 + 0.6 x player speed / 10 m/s, capped) launches the whole flock, away from the player, for 3.5 s. Flying birds sheer away and climb when the player passes within 0.3 x `flee`.
- Determinism: fixed 60 Hz step, every random draw from `hash([world_seed, "fliers", ...])` generators, player position the only outside input.

## Budget
About 30-45 birds per island, one draw call per species, wings animated in the shader, culled beyond 700 m (alariz), 260 m (pico, zancuilla), 90 m (alasucena). Sim cost is a few microseconds per bird per step.

## Not yet
- No C simulation: fliers cannot be hunted, eaten, befriended or seen by the C steering. That is the next step (real flying species in C once T9 has room).
- The dusk insect swarm shader (`flier_motes.gdshader`, from the WIP) is not wired in.
- Fliers ignore wild creatures and rain/wind; time of day is only the roosting rule.
