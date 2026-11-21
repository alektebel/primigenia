# Plan: motion learned from morphology, starter size, wings and flight

Planner: Opus, 2026-11-19. Base: `claude/v0.1-restore` at c98dbd2 (the repo's main line). Planning only: no project code was changed.
Running tracks this builds on and does not duplicate: **loco-run-gait** (Sonnet: Froude gait ladder to run/gallop, run posture,
clumsiness fixes, dev run toggle) and **c2/run-fall** (Codex: `set_run`, stamina 0-1000, deterministic fall state with vertical
velocity, `fell {drop_cm, damage}`). Both worktrees are still at c98dbd2 (nothing committed yet).
Raw council answers: `_agent/briefs/motion-flight-council/` (`sol.md`, `astra.md`, `qwen.md`, `rl_sol.md`, the prompts).

## 0. What I measured

- **Merodeador is the biggest creature in the roster.** `game/data/merodeador.json` spine is 6.0 m long, 3.3 m tall, radius
  0.78 m; `actor_driver.gd` draws rigs at `UNIT = 1.0` m. Frusta volume is ~6.2 m^3, so the locomotion mass (density 1000) is
  **about 6 t**, an elephant. C radius = 300 cm (`profile.gd`), next to `pivot_r = 3.2 m`. Garfio (the boss) is 1.0 m long,
  Rondo 1.8 m, Zanco 1.7 m, Babosa 1.6 m, Acechalunas 2.0 m.
- Every profile has `speed 4.0` (jog 5.2, sprint 8.8 m/s) whatever the size, so size changes only turning (steer.c).
- The camera already scales with body height (`chase_camera.gd` `KEY_DIST_H = [1.8, 4, 12]` body heights).
- Wings today: `wing_glider` and `wing_insect` are rigid sails in one `wing` group (`creature_parts.gd:646`); the only motion is
  a whole-group rotation in `actions/action_rig.gd:28`. The C stage world is 2D (x, z, ground height derived) and has no flight;
  the legacy `land_genome.c` has a `fly` stat (lift 0.95 per wing vs mass 0.62), unused by the stage.
- No MuJoCo or CMA-ES on the machine (`pip` install needed, CPU only). 16 threads.
- Idol (`cpore-wt/idol`, `_agent/models/idol-sdk`): the pipeline needs two encoders: DINOv3 (gated, Meta licence) and the
  FLUX.2 **autoencoder only** (`AutoencoderKLFlux2`, `vae/`). The SDK README allows a local FLUX.2-klein-4B folder for the VAE,
  which avoids the gated FLUX.2-dev repo (a klein config is already in `_agent/models/`). **DINOv3 remains the blocker.**

## 1. "Should we train an RL policy?" Recommendation: no RL now; offline optimisation distilled into a predictor

The clumsiness has known causes that learning would not fix: run crouch (biped 7.9 %), straight-legged walk cusps (1.5-4.8 g
vertical acceleration), knees at 29-34 degrees, size-blind speed (a 6 t body jogging like a dog), turning (LOCOMOTION.md §4).
loco-run-gait attacks several of these now. What a learning step adds is **the tuning**: today stride, duty, bounce, posture and
spine gains are literature curves plus hand constants shared by every body. "For a morphology, predict its optimal movement"
maps exactly onto: optimise those parameters per body in physics, then learn the map body -> parameters.

| Option | Fit | Cost on this laptop | Verdict |
|---|---|---|---|
| (a) RL per morphology (PPO) | needs training per player creation; can't run in-game | 10^7-10^8 transitions each, hours-days per body (Sol, citing Rudin et al. 2022) | no |
| (b) one morphology-conditioned RL policy | research-grade (Wang et al. 2020, Gupta 2022); jittery without motion priors, and AMP-style priors need mocap we don't have for aliens | 10^8-10^10 transitions, days-weeks of GPU, which the owner uses to play | no, revisit after C6 |
| (c) **offline optimisation of our controller's parameters in MuJoCo (CMA-ES), then a small regressor** | keeps the procedural rig, the 0 mm foot lock and the C sim's ownership of the root; runtime cost = one tiny evaluation per gait change | CPU only: pilot 10 bodies in ~1 h; full set 200 bodies x 5 speeds overnight to 2 nights at `nice -n 10` | **yes** |

Both Opus and gpt-6.1-sol (asked separately) chose (c). Sol's main risk, adopted as a gate: **simulator exploitation**
(efficient-looking nonsense), so the root guide force is penalised and 10 hard bodies go through the whole pipeline first.

**Determinism:** nothing changes in C. The predictor is a pure function of the genome evaluated in GDScript at build time;
animation stays visual. The C speed law may later read the same predictor's top speed (owner decision D2b), as a data table.

**What is optimised (per body, per speed):** ~14 parameters with the meanings already in `loco_gait.gd`/`loco_controller.gd`:
duty factor, relative stride, swing height, bounce share (pendulum vs spring), standing hip height ratio (crouch), body pitch
and lean gains, spine flexion amplitude (gallop/bound), girdle yaw gain, neck/tail spring gains, quadruped phase offsets
(lateral vs diagonal sequence, gallop lead lag), and the gait choice. **Not imposed:** the walk/trot/gallop transition Froude
numbers; they must emerge (that is the external correctness check).

**Cost function** (normalised): positive mechanical work per m g d (cost of transport) + w1 x work of the root guide force (the
"hand of god" that keeps the commanded speed; must stay small) + w2 x foot slip + w3 x torque^2 over limits + w4 x impact peaks +
w5 x head jerk + hard penalties for falls, reach violations, self-collision.

**How "realistic" is judged** (`make godot-loco-realism`, slice M0), each against animal data:
1. foot slip < 20 mm per stance (stays 0);
2. duty factor vs Fr within +-0.08 of Alexander & Jayes 1983 for legged plans;
3. relative stride vs Fr within +-20 % of 2.3 Fr^0.3 (walk/trot) and 1.9 Fr^0.4 (gallop);
4. emergent gait changes: walk->run/trot at Fr 0.3-0.7, trot->gallop at Fr 2-3 (Alexander 1984; Heglund & Taylor 1988);
5. minimum cost of transport within 0.5-2x of Taylor et al. 1982 (`CoT = 10.7 M^-0.316 J/(kg m)`);
6. vertical acceleration < 1.5 g at walk, head vertical excursion below the trunk's;
7. Hildebrand diagram class per plan (lateral-sequence walk for quadrupeds, tripod for hexapods);
8. blind A/B clips (baseline vs predicted): the owner plus the vision critic (`tools/art/critic.py`, free NVIDIA VL), target
   >= 65 % preference for predicted over 12 pairs.

## 2. "Is Merodeador too big for an initial game?" Yes

A 6 m, ~6 t starter is bigger than every species you meet, including the boss, which removes the Spore arc (start small,
everything is a threat, grow by choice; G78 makes size a DNA purchase). Recommendation: **a ~1 m hatchling** (spine 1.0-1.2 m,
hip ~0.35-0.45 m, ~25-40 kg at density 1000; Merodeador scaled by 0.17-0.2), smaller than Rondo/Zanco/Acechalunas, Garfio-sized.
Merodeador stays as the adult form reachable through G78 growth and as a wild species.

| Effect | What happens at ~1 m | Action |
|---|---|---|
| Camera | distances follow height: closest 1.8 x 0.7 m = 1.3 m, near grass | floor min distance 1.6 m, near plane 0.05 m, raise look-at to eye height + 0.3 m in grass |
| Speed | jog 5.2 m/s at hip 0.4 m is Fr 6.9 (gallop cadence ~3 Hz, dog-like, fine); run x1.8 = 9.4 m/s, Fr ~22 (cheetah-class) | after run-fall, speed per body by Froude with a global game multiplier (G78); cap run Fr ~12 for starters |
| Island scale | 3.2 km at 5 m/s = ~11 min across; trees and rocks look big (good) | no prop rescale; check grass blade height vs eye height (blades taller than ~0.5 m hide the hatchling) |
| Combat | C radius 300 -> ~55 cm (clamped >= 40); reach and hit shapes shrink; Garfio becomes a peer | rerun winnability (target band 35-80 %) and tourney; retune wild_k if out of band |
| Flight | wing loading scales with length: a 30 kg body can glide and flap with ~3.5-4 m^2 of wing (§3c); a 6 t one never can | starter size is what makes flight testable |
| Nav/steer | `pivot_r`, `grip_mass` were tuned near r = 0.6 m: the hatchling is in range | none |

## 3. Wings and flight

### 3a. Council (prompt: `motion-flight-council/q.md`)

- **gpt-6.1-sol (OpenAI):** four families sharing one aerodynamic interface: finger membrane (replaces forelimbs, t 0.65-0.85,
  endo, muscle + tendon), keratin vanes (same mount, overlapping vanes, per-vane pitch), veined sails (extra 1-2 pairs on
  reinforced thorax, exo preferred, direct vs indirect drive; indirect is not automatically asynchronous), deployable patagium
  (glide only; Draco rib fans t 0.35-0.75 or colugo limb-to-limb). Genome stores roots, consumed limbs, girdle, span b, area S,
  taper, sweep, camber, struts, anchors, fold; derive chord and AR; **check pitching moment about the CoM** (t alone can't
  guarantee balance). f = 4 (m/1 kg)^-1/6 Hz (Pennycuick 1996); stroke 60-120 deg, downstroke 55-65 %, span retraction 15-35 %
  on the upstroke; L/D membrane 6-12, vanes 8-18, sails 3-6, patagium 2-4. Loading decides speed, **not** flight eligibility:
  that needs sustained power > aerodynamic + inertial power. Keep forces and flight state in C. Creator: family, area,
  broad-slender, attachment, flight-muscle investment; show launch speed, glide ratio, capability.
- **gpt-6.2-astra (OpenAI, second model):** same four families; wing_glider becomes an articulated forelimb reusing the two-bone
  arm solver with jointed spars to a flank/ankle anchor (one dominant spar = pterosaur, several = bat); wing_insect becomes two
  independently hinged pairs (t ~0.55 and 0.68) with separate phase and pitch reversal; flap membranes compute slack from anchor
  separation. f = 5 Hz at 1 kg x m^-1/6; sails f ~ sqrt(w/rho)/b. L/D bands 5-9 / 7-13 / 3-6 / 1.5-3. At CLmax 1.4 a 10 m/s
  launch supports ~86 N/m^2. Creator: family, socket, span, breadth; preview folded clearance, min flight speed, glide ratio.
- **qwen3.6 (Alibaba, third family):** same four types; genome `wing_type, anchor_node, limb_node, span_ratio, chord, camber,
  struts, fold_angles, stiffness_k, wing_mass`; f ~ 10 M^-0.15 Hz; pitfalls: root clipping on the upstroke (clamp by spine
  radius), jelly wings on hydrostatic bodies (stiffness floor), plastic-sheet membranes (buckle with strut length). Its
  L/D ~ 0.5 AR + 2 and "sails AR 10" are rough, and "powered flight required above 250 N/m^2" inverts the logic: not adopted.
- **Agreement:** four families; forelimb-wing vs extra pair; membranes must deform with their anchors; rigid sails need pitch
  reversal; m^-1/6 frequency; flight eligibility from power, speed from loading; state in C. **Disagreement:** frequency constant
  (4 vs 5 Hz at 1 kg; adopted 4.5), vane L/D ceiling (18 vs 13; adopted 12 for game readability).

**Synthesis (the design):**

| Family (part id) | Mount | Skeleton / actuation | Ground pose | Flight | L/D target | e |
|---|---|---|---|---|---|---|
| Finger membrane (`wing_glider`, kept) | replaces forelimbs (t 0.6-0.8) or extra pair | endo, muscle + tendon | folded along flank, walks on wrists (quad launch like pterosaurs) | flap + glide | 8 | 0.7 |
| Keratin vanes (`wing_vane`, new) | same | endo, muscle | elbow folded, vanes stacked back | flap + glide | 11 | 0.8 |
| Veined sails (`wing_insect`, kept) | extra 1-2 pairs, t 0.55/0.68 | exo preferred; direct (independent pairs) or indirect | parked spread or folded flat over back | flap (high f), weak glide | 5 | 0.6 |
| Patagium flap (`wing_flap`, new) | rib fan t 0.35-0.7, or wrist-to-ankle | any; ribs or limbs spread it | folded ribs / slack skin | glide only | 2.5 | 0.5 |

Genome (optional fields on the existing part entry, defaults reproduce today's look, schema stays `cpore.creature/5`):
`wing: {span (m per side at size 1), breadth (chord ratio), spars 1-5, anchor: "flank"|"hind"|"none", mode: "forelimb"|"extra",
fold: "flank"|"back"|"spread", muscle 0.08-0.25 (flight muscle share of mass)}`. Derived (shown in the creator): area S,
AR = b^2/S, wing loading q = m g / S, stall speed, best glide ratio, capability ground / glide / flap. Creator controls (five):
family, span, breadth, attachment (forelimb vs extra), flight-muscle investment. Mass of wings and muscle feeds
`loco_rig_adapter.gd` (replacing the provisional `wings 0.01`).

### 3b. Idol: honest fit

Idol turns one photo into a Gaussian splat (a static cloud with baked lighting), then our tool meshes it. Wings need the
opposite: articulated spars, a membrane that folds and stretches, any span the genome asks for, palette regions and A24
materials. A splat has no joints, can't fold, carries the photo's light and colours, and CC0 photos of real wings would make
copies of bats or birds, not our species. **Not a good fit for wings.** It remains reasonable for G74's static props (rocks,
trunks, fossils, carcass bones), and at most as a reference for membrane vein or feather textures baked into detail maps.
**To unblock Idol** the owner must: log into Hugging Face with the account of the configured token and accept the DINOv3
licence (`facebook/dinov3-vith16plus-pretrain-lvd1689m`); download FLUX.2-klein-4B (Apache-2.0, has the same `vae/`) instead of
gated FLUX.2-dev and pass it as `image_encoders["flux2_vae"]`; then rerun the `idol-go` brief (Codex). VRAM on 8 GB is
unmeasured. **Wings: procedural mesh from the genome** (slice W1), in the creator's own style (G48).

### 3c. Flight test mode, then C

**Model (shared by the Godot test and later C; sqrt only, no trig, so it ports to C as is):** point mass with velocity v,
airspeed V = |v|, rho = 1.225. Lift L = 1/2 rho V^2 S CL (perpendicular to v, banked), drag D = 1/2 rho V^2 S (CD0 + k CL^2),
k = 1/(pi e AR), CD0 per family set so that L/D_max = 1/(2 sqrt(k CD0)) hits the table. CL: auto best glide sqrt(CD0/k);
pitch input moves it in [0.2, CLmax 1.5]; dive folds S to 40 % with CL 0.2; auto flare (CLmax, full S) below 1.5 body lengths.
Bank: input sets t = tan(bank) in [-1, 1], cos = 1/sqrt(1+t^2), turn rate g t / V. Flap thrust T = eta P / max(V, Vmin), P =
muscle x m x 150 W/kg sustained, x2 burst while stamina lasts. Flap-capable if P > min over V of D(V) V; else flapping only
slows the descent. Beat f = 4.5 (m/1 kg)^-1/6 Hz, stroke 70-110 deg (sails 90-150), downstroke 58 %, span retraction 25 %.
Worked example, 30 kg hatchling, vanes, S 3.7 m^2, AR 7: q = 80 N/m^2, stall 9.3 m/s (run speed 9.4: a run takeoff just works),
level power ~300 W vs 900 W available at 20 % muscle: it flies. Merodeador (6 t): never.

**States:** ground -> (run >= 1.1 stall and Space, or burst flap if P_burst > 1.5 P_req(Vmin), or falling with vy < -2 m/s from a
drop > 2 body lengths: wings deploy) -> glide <-> flap, dive, flare -> land. **Controls:** WASD/pointer steer heading as on the
ground (bank follows the turn), Space tap = one beat, hold = flap, release = glide, Ctrl = dive (fold), S/W = pitch (slower,
floatier / faster). **Stamina** (run-fall's 0-1000): flapping drains in ~12 s at full power, gliding ~0, regenerates on ground;
0 = glide only. **Camera:** airborne distance x1.6, follows the flight path with 0.3 s lag, roll at most 1/3 of bank, FOV +8 deg in
a dive, back to the chase curve 0.5 s after landing. **Fall damage:** landing converts vertical impact speed to an equivalent drop
h = vy^2 / (2 g) and feeds run-fall's curve (damage = max(0, h - safe_drop) x k), so a flare saves you and a stall over a cliff
hurts. *Coordination note for c2/run-fall: compute fall damage from vertical impact speed (equivalent drop), not from start
height minus end height.*

**Where it lives:** first a **Godot-side test mode behind the dev flag** (the owner can fly this week); while airborne the island
sends the debug teleport op every tick with the flyer's ground point, so wild AI still sees the player and the session replays
(debug ops are logged). Then the model moves into **C**, extending run-fall's fall state (y, vy) into an airborne state with
airspeed and the inputs `flap`, `dive`, `pitch`; goldens unchanged for bodies without wings. **C4** (P6): gliding with dive attacks
(damage from impact speed, a move in the 4-slot loadout), updrafts at cliff faces (W3 launch points), cliff fossils reachable
only by air, a wild glider species. **C5** (P8): sustained powered flight, perching, aerial AI (no A* in the air: straight
lines with terrain look-ahead), flight in the lineage ledger.

## 4. Slices

Each: goal; files; method; acceptance + evidence; size; implementer. Shared rules: `_agent/briefs/_rules-godot.md` (timeout,
xvfb software GL, nice, no GPU, tests green, report). Sonnet = Sonnet subagent with screenshots; Codex = headless C/tools.

**M0 Realism yardstick.** Goal: one command that scores locomotion against animal data (§1, checks 1-7) for the zoo bodies.
Files: `godot/locomotion/test/realism.gd`, `Makefile` target `godot-loco-realism`, `docs/evidence/godot/locomotion/realism.json`.
Method: drive the controller headless on 8 zoo morphologies x 5 Froude numbers; log contacts, COM, head, joint angles; compute
the metrics; CoT from a rigid-body work estimate (positive joint power via inverse kinematics, a proxy, labelled as such).
Acceptance: runs < 60 s; numbers for baseline committed; reproducible to 1e-6; run on loco-run-gait's branch too so the two
tracks share the yardstick. Size S. Sonnet. Depends on nothing; start now.

**M1 Optimiser pilot (MuJoCo + CMA-ES).** Goal: per body and speed, the parameter set of §1 that minimises the cost.
Files: `tools/gaitopt/{export_bodies.gd, proxy.py, gait_ref.py, cost.py, optimise.py, README.md}`, venv in `_agent/gaitopt-venv`
(`mujoco`, `cma`, `numpy`; owner D1). Method: `export_bodies.gd` (headless) writes `loco_describe` JSON for the zoo plus 200
sampled genomes (legs 2/4/6/8, size 0.3-6 m, proportions); `proxy.py` builds an MJCF of capsules (spine frusta, two-bone legs,
feet, masses from the morphology); `gait_ref.py` mirrors the meaning of `loco_gait.gd` (stride, duty, offsets, swing, body
height) to produce joint targets tracked by PD actuators with torque limits scaled by M^0.67; root guided toward the commanded
velocity by a penalised force; CMA-ES pop 24, <= 150 generations, 4 s rollouts, 14 processes at `nice -n 10`. Acceptance: the
**10-body pilot** (biped, horizontal biped, light and heavy quadruped, hexapod, octopod, wader, hatchling, Merodeador, Garfio)
completes; guide-force work < 10 % of total; emergent quadruped walk->trot at Fr 0.3-0.7; CoT within 0.5-2x Taylor; videos of
the MuJoCo proxy (offscreen, software) per pilot body. Size M. Codex.

**M2 Full run + predictor.** Goal: map morphology features -> parameters. Files: `tools/gaitopt/{features.py, fit.py}`,
`godot/locomotion/data/gait_predictor.json`, `godot/locomotion/loco_predict.gd`. Method: full run (200 bodies x 5 speeds,
overnight); features = plan, leg count, hip height, leg segment ratio, COM offset/length, mass, robustness, track width, foot
type; fit per plan a ridge regression and a 2x32 MLP, keep the smaller with held-out error within 10 % of the larger; export
weights; `loco_predict.gd` is a pure function (parse once, evaluate in < 0.1 ms). Acceptance: held-out R^2 >= 0.8 for duty,
stride, hip ratio; GDScript and Python outputs agree to 1e-4 on 50 bodies. Size M. Codex (Godot part `--check-only` only).

**M3 Predicted gait in the game, A/B.** Goal: the controller uses predicted parameters, with a setting to compare. Files:
`loco_gait.gd`, `loco_controller.gd`, `loco_rig_adapter.gd`, `devtools/tuning` entry `loco/predicted` (A/B), docs/godot/LOCOMOTION.md.
Method: after loco-run-gait merges; replace the hand constants by `loco_predict` outputs where present, fall back to the current
curves for legless/radial or out-of-range bodies. Acceptance: `make godot-loco-test` gates hold (slide 0, CoM, transitions),
M0 realism improves on >= 5 of 7 metrics and worsens none by > 10 %; blind A/B (§1.8) >= 65 %; clips of Merodeador, hatchling,
Garfio, hexapod at walk/trot/run side by side. Size M. Sonnet.

**S1 Starter hatchling.** Goal: a ~1 m starter (D2). Files: `godot/game/data/hatchling.json` (new; Merodeador x ~0.18 with
juvenile proportions: bigger head and eyes), `game/game.gd` default genome, studio default, `chase_camera.gd` minimums, grass
height near the player if needed. Method: build, measure hip height and mass with the adapter, pick scale so length 1.0-1.2 m;
camera floor 1.6 m; look-at raise in tall grass. Acceptance: winnability in 35-80 % for all seeds, tourney unchanged in C
(goldens untouched: only data), screenshots at 4 sites (nest, meadow, cliff, near Garfio) before/after at 1920x1080. Size S. Sonnet.

**S2 Size-aware speed (after run-fall).** Goal: walk/run speed from the body (G78) instead of a flat 4.0. Files: `profile.gd`
(speed from the locomotion proposal or M2's predictor, with a global multiplier), no C rule change. Acceptance: hatchling jog
4-5.5 m/s, Merodeador 6-8 m/s; winnability band holds; feel test gates. Size S. Sonnet.

**W1 Articulated procedural wings.** Goal: the four families of §3a as jointed parts that fold, spread and deform. Files:
`creature/creature_parts.gd` (wing builders), `creature/creature_wing.gd` (new: shoulder-elbow-wrist chain reusing the two-bone
solver, spars, membrane ArrayMesh rebuilt per frame from spar and anchor points, <= 300 vertices, slack from anchor distance),
`creature_genome.gd` (optional `wing` keys), `studio/data/parts.json` (`wing_vane`, `wing_flap`), studio UI (five controls +
derived stats panel), `loco_rig_adapter.gd` (wing + muscle mass). Acceptance: saved creatures with old wings load and render
spread like today (thumbnail diff reviewed); fold/spread/three flap phases strip for 4 families x 3 bodies (hatchling, Merodeador,
hexapod); no root clipping on the upstroke (clearance check by spine radius); creature + studio test suites green. Size L. Sonnet.

**W2 Wing kinematics.** Goal: procedural flap, glide, dive, flare, fold driven by a flight state. Files:
`godot/locomotion/loco_wing.gd` (new, pure maths like the controller), hook in `actor_driver.gd`. Method: §3c beat law, stroke
and downstroke share per family, span retraction on the upstroke (membrane/vanes), pitch reversal and fore/hind phase for sails,
glide pose with incidence and bank, dive tuck, flare at touchdown, legs tucked in the air. Acceptance: unit tests (frequency
law, phase continuity, no pops on state change); strips at 30 fps; works on today's rigid wings (hinge only) so F1 needn't
wait for W1. Size M. Sonnet.

**F1 Flight test mode (Godot, dev flag).** Goal: the owner flies this week. Files: `godot/game/player/flight_test.gd` (model and
states of §3c), `player_input.gd` (Space/Ctrl/W/S when airborne), `chase_camera.gd` (air mode), `island.gd` (per-tick debug
teleport while airborne; landing damage shown as a toast and console line), `devtools/tuning` (lift_mul, power, CD0 per family),
a scenario `flight_cliff` (hatchling with vanes on a cliff top) and a console `fly` toggle. Acceptance: scripted run in xvfb:
cliff takeoff -> glide >= 8:1 for vanes -> 10 s flap -> flare landing with no damage; stall over a 40 m drop gives damage;
frame strips + a 20 s clip; replay of the session matches (teleports logged); play/feel/devtools suites green. Size M. Sonnet.
Depends on W2 (can start in parallel, first with a hinge flap).

**F2 Flight in C.** Goal: the sim owns flight. Files: `core/src/stage_world.c` (airborne state on top of run-fall's fall),
`core/include/cpore/world.h` (`CpStageInput.flap, dive, pitch`; creature `y, vy, air, wing_s, wing_k, cd0, power`), Godot binding,
Python binding, `tests/`. Method: port F1's model in float with sqrtf only, fixed tick; profile gets wing area and power from the
genome via `profile.gd`; snapshot version bump. Acceptance: goldens byte-identical for wingless bodies and never-flapping runs;
tests for glide ratio, stall, flap power gate, stamina, landing damage via equivalent drop, determinism and snapshot; routes
288/288; F1 switches to reading C. Size L. Codex. Depends on run-fall merged.

**F3 / F4** (C4 / C5): planning placeholders (§3c); not to start before the owner's flight test feedback.

**I1 Idol (optional).** Only after D7: owner accepts DINOv3, Codex reruns `idol-go` with klein's VAE, props only. Size S.

## 5. Order (≤ 3 Claude agents at once)

Now: M0 (Sonnet), W2 + F1 (one Sonnet, W2 first), S1 (Sonnet, if D2 = yes). Codex: M1 pilot once D1 is approved (no conflict
with run-fall's C files). After loco-run-gait merges: M3 waits for M2. After run-fall merges: S2, F2. W1 after F1 has given the
owner a feel for what wings must do. Every slice ends with Claude review and evidence looked at before merge.

## 6. Owner decisions (with my recommendation)

- **D1 Learning approach:** offline optimisation (CMA-ES in MuJoCo, CPU only, overnight) distilled into a predictor; no RL now.
  Approve `pip install mujoco cma` in `_agent/gaitopt-venv` (~60 MB). **Recommend: yes.**
- **D2 Starter size:** a ~1 m, ~30 kg hatchling; Merodeador becomes the adult form via G78 growth and a wild species.
  **Recommend: yes.** D2b: speed per body by Froude with a global game multiplier (S2). **Recommend: yes.**
- **D3 Wing mount:** allow both forelimb-wings and an extra pair (dragon-like), the extra pair costing more DNA and mass.
  **Recommend: both** (A24, the creator rules), forelimb-wings as the default for membrane and vanes.
- **D4 Flight honesty:** eligibility from physics (loading and power), so heavy bodies can't fly, with a global lift multiplier
  (start 1.0, live in tuning) for fun. **Recommend: physics with the multiplier,** never per-creature cheats.
- **D5 Where flight lives:** Godot dev-flag test mode now, C after run-fall merges. **Recommend: yes.**
- **D6 Controls:** Space flap (tap/hold), release glide, Ctrl dive, W/S pitch, auto flare. **Recommend: yes,** revisit after F1.
- **D7 Idol:** not for wings (procedural instead). If you still want it for rocks/fossils, accept the DINOv3 licence on Hugging
  Face; we use FLUX.2-klein's VAE to avoid FLUX.2-dev. **Recommend: procedural wings; Idol optional for props.**
- **D8 Fall damage from vertical impact speed** (equivalent drop) so flaring and gliding interplay correctly; tell run-fall now.
  **Recommend: yes.**
