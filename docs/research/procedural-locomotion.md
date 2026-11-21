# Procedural locomotion for arbitrary creatures: research and plan

Researcher: Opus, 2026-11-20. Planning only: no project code changed. Base: `claude/v0.1-restore` at c306c40, plus the
`gaitopt` worktree (M1 pilot results, uncommitted to main). Inputs read: `docs/godot/LOCOMOTION.md`, `PLAN-locomotion.md`,
`RUN-GAIT.md`, `WINGS-FLIGHT.md`, `_agent/briefs/motion-flight-plan.md` and its council, `godot/locomotion/*.gd`,
`godot/actions/` (action layer), `godot/devtools/zoo/`, `godot/devtools/tools/_loco_review_tmp.gd`, `core/src/steer.c`,
`cpore-wt/gaitopt/tools/gaitopt/{README.md,results/pilot/*.json}`.

Numbers marked **(tuning)** are starting values for the game that I chose. They are not measurements. Every other number has a
source in §6.

---

## 1. Executive summary

**Recommendation.** Keep the runtime **procedural and kinematic**: the Spore approach of gait tables, a foot planner, IK and
passive secondary motion, which `godot/locomotion/` already implements and in places improves on. Spend the next effort on three
things that the literature and our own evidence say matter most for "looks alive". (1) A **motion grammar** of biomechanical
rules for each behaviour, written into the controller and the action layer. It covers the parts that are missing today: head
carriage and gaze stabilisation, posture that depends on size, turns that lead with the head and bend the spine, choosing
footholds on steps, digging, eating and idle. (2) A **yardstick** that scores every change against animal data, plus a blind
A/B protocol. (3) Tuning anchored to **real animal references** (dynamic-similarity tables, Muybridge plates, optionally the
Truebones Zoo clips), not to a physics optimiser.

**Why.** Only this family meets every hard constraint. The C sim owns the root and nothing may feed back into it. The layer runs
in GDScript for dozens of creatures. Bodies are generated at runtime with no clips. It must be deterministic and cheap. Spore
shipped exactly this design for player-made bodies at 0.2 ms per 25-body creature
([Hecker et al. 2008](https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies)).

The other families fail at least one constraint:
- Data-driven and neural controllers (motion matching, PFNN, MANN, DeepPhase) need motion capture of each skeleton.
- RL and physics controllers (DeepMimic, AMP, MetaMorph) need GPU-days, add their own root motion, and remain jittery on
  bodies outside their training set.

**Revision to the plan of record.** The M1 pilot already ran in the `gaitopt` worktree, and **6 of 10 bodies are infeasible at
every speed**: their best candidates all cost about 10,000, which is the fall penalty. These are the biped, the horizontal
biped, the wader, the heavy quadruped, Merodeador and Garfio. Only the hatchling, the light quadruped, the hexapod and the
octopod produced usable fits. The light quadruped chose **trot at Fr 0.3**, so the walk→trot transition the plan relied on as
its external check did **not** emerge. The cause is structural. Open-loop PD tracking of a kinematic reference has no balance
feedback, so bipeds and heavy bodies fall. The controllers that do balance arbitrary bodies add foot-placement feedback
([SIMBICON](https://www.cs.ubc.ca/~van/papers/2007-siggraph-simbicon.pdf)) or virtual forces with a spine model
([Coros et al. 2011](https://www.cs.ubc.ca/~van/papers/2011-TOG-quadruped/index.html)). Building one is a research project.

I recommend:
- **Pause M2/M3** (a predictor fitted to falls is meaningless).
- Run a **time-boxed M1b spike** that adds balance feedback, limited to quadrupeds and many-legged bodies, with a hard gate.
- **Re-point the "learned parameters" goal to reference-anchored fitting** (Wampler et al. 2014 is the published version of
  that idea, [project](https://grail.cs.washington.edu/projects/inverse_locomotion)).
- Start the **behaviour slices L1–L4 now**. They fix the visible weaknesses (stiff head, sprawled legs, pivot turns, no dig
  motion), and none of them depends on the optimiser.

---

## 2. Survey of technique families

### 2.1 Pure procedural / IK (what we have)

**What it is.** A clock per leg with footfall offsets and duty factor. A foot planner lifts each foot at the end of stance and
plants it at a predicted home. Swing follows a parametric arc. The body height and attitude follow the feet through springs.
IK solves the limbs. Passive springs move the neck, tail and other appendages.

**Precedents.**
- Spore (below).
- Rain World: point-mass bodies with procedurally placed limbs; Jakobsson and Therrien at the
  [GDC 2016 Animation Bootcamp](https://gamedeveloper.com/art/video-animating-i-rain-world-i-and-its-many-squishy-stretchy-creatures).
- Overgrowth: a handful of key poses plus procedural interpolation, physics springs and IK. David Rosen,
  [GDC 2014, "An Indie Approach to Procedural Animation"](https://gdcvault.com/play/1020049/Animation-Bootcamp-An-Indie-Approach).
  The code is Apache-2.0 ([announcement](https://gamingonlinux.com/2022/04/overgrowth-from-wolfire-games-goes-open-source)).
- Creature Creator, a Spore-like Unity game, reportedly open-sourced under GPL-3.0
  ([repo index](https://awesome.ecosyste.ms/projects/github.com%2Fdaniellochner%2Fcreature-creator)). Unverified, and GPL
  means read it only; never copy code.

**What it achieves.** Zero foot skate by construction. Any leg count. Terrain following. Deterministic. Cheap.

**Weaknesses.** Everything that is not written as a rule is missing. A rig that is correct but "dead" is the normal failure
mode, and it is the one our contact-sheet review is seeing.

**Runtime cost.** O(legs + spine bones) per frame. GDScript is the main risk; see §2.7.

**Fit.** Excellent. It is the only family that consumes the C root trajectory as-is.

### 2.2 Spore-style semantic retargeting

[Hecker et al. 2008](https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies)
([PDF mirror](https://www.cse.chalmers.se/edu/year/2011/course/TDA361/Advanced%20Computer%20Graphics/027-hecker%20copy.pdf)).

Details that matter for us, from the paper's §4:
1. **Leg groups.** Legs are clustered into groups of roughly equal length. The groups' length ratios are approximated by small
   rationals, which set the **relative gait frequencies** per group, so short and long legs stay harmonised.
2. **Gait parameters.** Each foot has a duty factor and a "step trigger" (phase offset). Animators authored speed → parameter
   tables for 1–6 feet. For 7 or more feet the tables were generated procedurally. Several gait styles can be layered
   (limping, a lumbering gait for big bodies). Different leg groups can use different gaits at the same time ("two short legs
   running while four long legs trot").
3. **Swing paths.** These are authored in a normalised space and scaled by leg length.
4. **Two-phase particle IK.** The spine is solved first, then the limbs. Particles exist only at IK branch points, so a long
   spine becomes one smooth constraint, not a kinked chain.
5. **"Jiggles".** A heavily damped, *passive* secondary simulation on the bodies the animation does not select. It never feeds
   back. Their earlier system did feed back into the IK goals, and it "negatively impacted" quality.
6. **Body capabilities ("caps").** Semantic tags such as grasper, mouth, spine and foot let one authored action bind to any body
   (`UprightSpine`-style predicates branch animations).
7. **Cost and quality.** 0.2 ms per frame for a 25-body creature on a 1.7 GHz Pentium-M, with 35 % of that in IK. A test grid
   over hundreds of uploaded creatures reached a ~90 % pass rate.
8. **Self-reported limitations.** No self-collision. IK singularities. **"believable locomotion with anticipation in the face of
   discontinuous player and code inputs"** was their biggest open problem. That is exactly our pivot-turn complaint.

**Fit.** We already have points 2–5. Our `godot/actions/` layer with `action_body_map.gd` is our version of point 6.
Points 1 and 8 are the useful lessons we have not yet adopted.

### 2.3 Data-driven: motion matching

Every frame, search a mocap database for the pose whose future trajectory best matches the desired one, then blend to it.
- Clavet, [GDC 2016](https://www.gdcvault.com/play/1022985/Motion-Matching-and-The-Road), *For Honor*.
- [Learned Motion Matching](https://www.theorangeduck.com/media/uploads/other_stuff/Learned_Motion_Matching.pdf) (Holden et al.
  2020) replaces the database with small networks for constant memory and CPU cost.

**What it achieves.** AAA quality on *one fixed skeleton per dataset*.

**Needs.** Hours of mocap per skeleton. Nothing exists for a creature generated at runtime.

**Retargeting to new bodies.** [ReConForM](https://arxiv.org/abs/2502.21207) (2025) retargets in real time across varied
morphologies, but it still needs source motion and a mapping between similar bodies.

**Fit.** Poor for the runtime. The one useful idea is the **trajectory-feature query**: use the *future* path to pick posture,
which is the anticipation Spore lacked. We can read the future path from C (pure pursuit look-ahead, A* polyline) without
any database.

### 2.4 Neural, phase-based (PFNN, MANN, local phases, DeepPhase)

- [PFNN](https://www.ipab.inf.ed.ac.uk/cgvu/phasefunction.pdf) (Holden, Komura, Saito 2017): the network weights are a cyclic
  function of a gait phase.
- [MANN](https://github.com/cghezhang/MANN) (Zhang, Starke et al. 2018): a gating network blends expert weights. Trained on dog
  mocap, it covers walk, pace, trot, canter, jump, sit and idle.
- [Local Motion Phases](https://www.ipab.inf.ed.ac.uk/cgvu/basketball.pdf) (Starke et al. 2020): one phase per body part and
  contact.
- [DeepPhase](https://i.cs.hku.hk/~taku/deepphase.pdf) (Starke, Mason, Komura 2022): a periodic autoencoder learns multi-channel
  phase manifolds without supervision.
- Code: [AI4Animation](https://github.com/sebastianstarke/AI4Animation).

**What they achieve.** The best data-driven quadruped quality published (MANN). Each runs in milliseconds on a CPU.

**Needs.** Mocap of the target skeleton, and a network trained per skeleton.

**Licences.** MANN's code and learned data are for research and education only, with commercial use by licence
([repo](https://github.com/cghezhang/MANN)). PFNN is academic and non-commercial
([licence](https://www.github.com/PapyKent/PFNN/blob/master/LICENSE.md)).

**Fit to the runtime.** None. These methods have no answer for an 8-legged long-necked alien.

**What we can take.** The representation, procedurally. Local phases are already present as per-leg oscillators. We should
**drive secondary channels (head nod, neck, tail, spine, ears) from the phase of the relevant limb group**, not from a global
spring. That is the lesson of local phases and DeepPhase: each body part has its own periodic channel, and its amplitude and
phase are what make motion read as coordinated.

**Topology-agnostic generation.** [AnyTop](https://arxiv.org/abs/2502.17327) (2025) is a diffusion model over arbitrary
skeleton graphs, trained on the Truebones Zoo. It generalises to unseen skeletons from a few examples. It is offline,
stochastic, GPU-bound and unproven on aliens. At most it is a source of reference clips (§2.6), and never a runtime
component.

### 2.5 Physics-based control and RL

**Hand-designed controllers.**
- [SIMBICON](https://www.cs.ubc.ca/~van/papers/2007-siggraph-simbicon.pdf) (2007): a pose finite state machine plus linear
  foot-placement feedback on centre-of-mass position and velocity.
- [Coros et al. 2011](https://www.cs.ubc.ca/~van/papers/2011-TOG-quadruped/index.html): a simulated dog with gait graphs, a dual
  leg frame, a **flexible spine model** and virtual forces through the Jacobian transpose, optimised for style and compared
  with filmed dog data. Walk, trot, pace, canter, transverse and rotary gallop.
- [Geijtenbeek et al. 2013](https://www.cs.ubc.ca/~van/papers/2013-TOG-MuscleBasedBipeds/index.html): muscle routing and control
  parameters co-optimised (CMA-ES) for many biped creatures. Gaits emerge from the target speed. Each body is optimised for
  hours.

**Imitation and adversarial RL.**
- [DeepMimic](https://xbpeng.github.io/projects/DeepMimic/), [AMP](https://xbpeng.github.io/projects/AMP/) and
  [ASE](https://xbpeng.github.io/projects/ASE/) (Peng et al. 2018–2022): high quality, but they need reference motion of the
  same body.
- [DReCon](https://theorangeduck.com/media/uploads/other_stuff/DReCon.pdf) (Bergamin et al. 2019) runs physics on top of
  motion matching.

**Morphology-agnostic policies.**
- [One Policy to Control Them All](https://arxiv.org/abs/2007.04976) (Huang, Mordatch, Pathak 2020): shared modular policies
  with message passing ([code](https://github.com/huangwl18/modular-rl/)).
- [MetaMorph](https://openreview.net/pdf/7ef00fd81bdb696532e182f6073e6e6d9cb15e98.pdf) (Gupta et al. 2022): a transformer
  conditioned on morphology, with zero-shot transfer within the UNIMAL design space.
- Both produce functional but **unstylised, often jittery** gaits, with no motion prior for alien bodies.

**Fit.**
- Runtime physics conflicts with "C owns the root". The body would have to be dragged along the sim path, which is the
  "hand of god" force that the M1 cost penalises.
- Training is GPU-days per family of bodies.
- Determinism across machines is not guaranteed.
- Offline use, as an optimiser of our procedural parameters, is the only fit, and the M1 pilot shows it is hard to make well
  posed.

### 2.6 Offline optimisation or learning plus a procedural runtime

**Physics optimisation.**
- [Wampler & Popović 2009](https://grail.cs.washington.edu/projects/animal-morphology/s2009/) optimises gait (and form) for
  arbitrary legged bodies, including a five-legged creature, with no starting motion.
- [Geijtenbeek 2013](https://www.cs.ubc.ca/~van/papers/2013-TOG-MuscleBasedBipeds/index.html) is the muscle-based biped
  version.
- Our M1 (MuJoCo + CMA-ES over 14 controller parameters) is in this family.

**Style learned from data.** [Wampler, Popović & Popović 2014](https://grail.cs.washington.edu/projects/inverse_locomotion)
uses **inverse optimal regression**. It recovers physically motivated style parameters from side-view *video* of real animals,
interpolates them over body shape, and synthesises gaits for new animals, including extinct ones. This is the closest
published match to "predict good movement from the body", and it is anchored to real animals, not to whatever a simulator
rewards.

**Fit.** Good, if the offline stage produces *parameters for our existing controller* and is validated against animal data.
That was M1's intent. Two lessons apply:
1. A physics cost alone invites simulator exploitation, which the M1 pilot hit with non-foot support.
2. Without balance feedback in the proxy, most bodies cannot be evaluated at all.

### 2.7 What Godot 4.6/4.7 gives us natively

Godot 4.4–4.6 added `SkeletonModifier3D` and, in 4.6, a full IK family
([Godot blog](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)):
- `TwoBoneIK3D` (deterministic).
- `ChainIK3D`, with `SplineIK3D` (deterministic) and the iterative `FABRIK3D`, `CCDIK3D` and `JacobianIK3D`.
- `BoneTwistDisperser3D`, `LimitAngularVelocityModifier3D` (smooths deterministic IK), `SpringBoneSimulator3D` (passive
  spring chains, as in VRM), `LookAtModifier3D`, and `BoneConstraint3D` (aim, copy, convert).

Godot 4.7's release page lists no new IK or skeleton features, only animation-editor and Tween items
([4.7 release](https://godotengine.org/releases/4.7/)).

**Uses for us.** All of these run in C++. Where the creature mesh is skinned to a `Skeleton3D`, `TwoBoneIK3D` per leg,
`SplineIK3D` for necks and tails, and `SpringBoneSimulator3D` for passive appendages (our "jiggles") would remove the GDScript
IK cost. **To verify first:** `creature_leg_chain.gd` currently solves the legs in GDScript (`creature.solve_legs()`), and I
did not confirm whether the creature rig is a `Skeleton3D`. That is the first task of slice L6.

### 2.8 Comparison

| Family | Arbitrary runtime bodies | Respects C-owned root | Runtime cost (per creature) | Data / training needed | Quality ceiling | Fit |
|---|---|---|---|---|---|---|
| Procedural / IK (ours) | yes | yes | low (O(limbs)); GDScript is the risk | none | high if rules are rich (Spore, Rain World) | **runtime of choice** |
| Spore semantic retargeting | yes (90 % pass rate over hundreds) | yes | 0.2 ms C++ | authored actions per *semantic*, not per body | high | **adopt the remaining ideas** (leg groups, anticipation, caps) |
| Motion matching / LMM | no (one skeleton per dataset) | yes (kinematic) | low–medium; database memory | hours of mocap per skeleton | AAA | idea only (future-trajectory features) |
| PFNN / MANN / DeepPhase | no | yes | ~1 ms CPU | mocap per skeleton; GPU training; non-commercial licences | best data-driven quadruped | idea only (local phases for secondary channels) |
| AnyTop (diffusion, any topology) | partly (offline) | n/a | offline, GPU | Truebones Zoo | promising, unproven on aliens | optional offline reference generator |
| Physics + RL (DeepMimic, AMP, ASE, DReCon) | no (reference per body) | conflicts | physics sim + network | GPU-days, reference motion | very high on humanoids | no |
| Morphology-agnostic RL (SMP, MetaMorph) | yes (within a design space) | conflicts | sim + network | 10^8+ samples, GPU-weeks | functional, unstylised | no |
| Offline physics optimisation (M1, Wampler 2009, Geijtenbeek 2013) | yes, offline | yes (outputs parameters) | none at runtime | CPU hours per body; needs balance feedback | plausible; exploitation risk | **spike only (M1b)** |
| Inverse-optimal style from animal video (Wampler 2014) | yes (interpolated over shape) | yes (outputs parameters) | none at runtime | side-view video of real animals | anchored to real animals | **adopt the idea** (R1) |

---

## 3. Behaviour by behaviour: technique and rules

Conventions follow `docs/godot/LOCOMOTION.md`:
- Fr = v²/(g h), where h is hip height.
- Phase 0..1 per stride.
- Duty β is the stance fraction.

Rules already implemented are marked ✓, so slices touch only what is missing.

### 3.1 Walk

**Gait clock and footfalls ✓.**
- Lateral-sequence walk LH 0, LF 0.25, RH 0.5, RF 0.75 (Hildebrand's gait diagrams:
  [1965](https://scilit.com/publications/b17c0ed7f2f640b4c7f51bccf81a27e5); support-polygon rationale in
  [Cartmill et al. 2002](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf)).
- β > 0.5 means walk; β ≤ 0.5 means run ([Hildebrand 1965/1989 via later use](https://pmc.ncbi.nlm.nih.gov/articles/PMC2658658)).
- Stride 2.3 Fr^0.3 h and duty factor as functions of Fr: dynamic similarity,
  [Alexander & Jayes 1983](https://scilit.com/publications/dc3ca3a8889beee2adc0bfd2c6593882). These are already the ladders
  in `loco_gait.gd`.
- Small mammals run more crouched, with relatively longer strides at equal Fr (same source). Use this as the size-dependent
  correction for posture and stride.

**Missing rule 1: posture scales with size.** Our weakness is "crouched/sprawled legs".
- Large mammals stand more upright. Effective mechanical advantage rises with mass (about M^0.26), so peak muscle stress stays
  roughly constant ([Biewener 1989, *Science*](https://doi.org/10.1126/science.2740914)).
- Rule: standing knee and ankle flexion fall with body mass. Set a target stance-leg straightness
  `s = clamp(0.80 + 0.06 log10(M/1 kg), 0.80, 0.97)` (tuning), as a share of leg length from hip to foot at mid-stance.
  This gives a 30 kg hatchling about 0.89, Merodeador at 6 t about 1.0, clamped to 0.97.
- Sprawl (lateral offset of the foot) applies only to `multi` and sprawled plans. Mammal-like quadrupeds keep feet under the
  hips, with track width ≈ hip width.
- The pendulum cap ✓ already lifts hips; this rule sets what the cap aims at.

**Missing rule 2: head carriage and head nod.** This is the "stiff head up" weakness.
- **Carriage.** Horses keep the head, neck and trunk stable in space in all gaits, and the neck decouples the head from the
  trunk ([Dunbar et al., JEB 211:3889](https://cob.silverchair.com/jeb/article-split/211/24/3889/18018/Stabilization-and-mobility-of-the-head-neck-and);
  [PMC2768006](https://pmc.ncbi.nlm.nih.gov/articles/PMC2768006)).
- Quadruped heads move with the stride rather than fixating a point, unlike bipeds
  ([PMC4986613](https://pmc.ncbi.nlm.nih.gov/articles/PMC4986613)).
- Rule: define the head's goal in **world space**, not as a neck angle.
  - Gaze point on the ground at `d = clamp(1.5 + 0.5 v/√(g h), 1.5, 4)` body lengths ahead along the *future path from C*
    (tuning).
  - Head height `y_head = lerp(y_withers, y_rest_head, carriage)`, with carriage 0.55 at walk, falling to 0.35 at gallop
    for long necks (tuning). The head goes forward and down at speed, as in horses and dogs.
  - Solve the neck as a spline chain (Spore's spine-spline idea: particles only at the ends) toward that head position, with
    the head's pitch levelled toward the gaze point.
  - The current neck-angle spring becomes the *lag* on that world goal.
- **Nod.** Two head cycles per stride, phase-locked to forelimb loading: the head is lowest shortly after each forelimb
  touchdown in walk, and at diagonal stance in trot. Gait-analysis work on horses uses the head and withers vertical minima at
  each forelimb stance as the symmetry signal, so a sound horse has two equal head minima per stride
  ([Rhodin et al. 2018](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6175082/)).
  - Amplitude `A = k_n · neck_length · min(1, Fr/0.3)`, with k_n = 0.04 at walk, 0.02 at trot (tuning).
  - The nod is a *local phase* channel driven by the forelimb group's oscillator, not by the bounce spring.
- **Birds and upright bipeds** with a long neck (the wader): use head-bobbing with a **hold phase** (the head is fixed in
  world space while the body moves under it) and a **thrust phase** (the head moves forward quickly), one cycle per step
  ([Necker 2007](https://www.reinhold-necker.de/Head%20bobbing%20print.pdf)).
  - Implement as a world-anchored head target that jumps forward by one step length over the first ~25–30 % of each step
    (tuning), then holds.
  - Only a minority of bird families bob, so make it a genome trait (on for wader-like bodies, off otherwise).

**Missing rule 3: spine and pelvis in walk.**
- Lateral spine flexion in walk.
- Pelvic roll toward the swing side for bipeds.
- Girdle yaw ✓ exists at gain 0.085.
- Add pelvic list `±(2–4°)` for bipeds (tuning), minimum at contralateral mid-swing.

**Missing rule 4: slow many-legged gaits.** Insects use a continuum: a wave gait (slow, metachronal back-to-front), then
tetrapod, then tripod as speed rises. Duty and inter-leg phase vary continuously with speed
([Wilson 1966](https://doi.org/10.1146/annurev.en.11.010166.000535); continuum confirmed in flies,
[JEB 221:jeb189142](https://cob.silverchair.com/jeb/article-pdf/221/22/jeb189142/1904837/jeb189142.pdf)).
- Rule for n stations per side:
  - The ipsilateral phase lag between adjacent legs, front to back, is `φ = (1 − β)` at slow speed, so a single wave runs
    from rear to front.
  - The contralateral pair is offset by 0.5.
  - As β falls toward 0.5, the pattern reaches the tripod.
  - This replaces the hard switch between `tripod` and `ripple`.
- Centipedes: the leg wave and the lateral body undulation are separate waves, and their phase lag matters. A mismatch makes
  locomotion robust ([APS 2022 robot study](https://archive.aps.org/mar/2022/k03/11)). Axial stiffness must rise with speed
  ([Dionne et al. 2026 preprint](https://arxiv.org/html/2603.08409v2)).
  - Rule: body wave amplitude `0.04–0.08 L_body` (tuning), with wave speed tied to, but lagging, the leg wave by about π/4
    (tuning).

**Missing rule 5: leg groups (from Spore).** When legs differ in length (2 short + 4 long), cluster them into groups. Give
each group a frequency ratio approximated by small rationals (1:1, 2:1, 3:2), so short legs take 2 steps per long-leg step
and stride × cadence still equals speed for each group
([Hecker 2008 §4.2](https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies)).
Today every leg shares one stride, so short legs over-reach or the body crouches.

### 3.2 Trot, canter, gallop

**Implemented ✓.**
- Trot diagonal pairs.
- Gallop with spine flexion up to 0.11 rad.
- Heavy trot for graviportal bodies.
- Ladder walk|trot at Fr 0.5 and trot|gallop at 2.5 (Alexander;
  [Heglund & Taylor 1988](https://cob.silverchair.com/jeb/article-split/138/1/301/5532/Speed-Stride-Frequency-and-Energy-Cost-Per-Stride):
  trot–gallop transition speed scales as M^0.22, and a 30 g mouse takes ~6× the strides per second of a 300 kg horse at the
  transition).

**Missing.**
1. **Spine flexion amplitude and timing.** The cheetah's "measuring-worm" spine adds about 15 in (0.38 m) per flexion and
   again per extension, at a 0.28 s stride
   ([Hildebrand 1961](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1961_Further-Studies-on-Locomotion-of-the-Cheetah.pdf);
   [1959](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1959_motions-of-running-cheetah-and-horse.pdf)).
   - Timing: the spine **flexes after forelimb lift-off (gathered flight)** and **extends after hindlimb lift-off (extended
     flight)** ([Frontiers 2022 model](https://www.frontiersin.org/articles/10.3389/fbioe.2022.825638/full);
     [cheetah model 2026](https://arxiv.org/html/2604.00329v1)). The horse spine is stiff and the cheetah's flexible
     (Hildebrand 1959).
   - Rule: flexion amplitude scales with a genome "spine flexibility" (endoskeleton, slender, low mass ⇒ high).
     `θ_flex = 0.05–0.35 rad` (tuning; horse-like at the low end, cheetah-like at the high end), phased to the lift-offs as
     above, not to a global sine.
   - The stride gain from the spine is added to λ, so stride × cadence still equals speed.
2. **Transverse versus rotary gallop and leads.**
   - Transverse gallop (horse): hind pair then fore pair, with the same side leading in each.
   - Rotary gallop (dog, cheetah): the fore lead is on the opposite side
     ([Hildebrand 1977](https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1977_Analysis-of-Asymmetrical-Gaits.pdf)).
   - Choose rotary for flexible-spine, light bodies, and transverse for stiff and heavy ones.
   - Add the **canter** (three-beat) between trot and gallop for horse-like bodies, at Fr about 1.2–2.5 (tuning).
3. **Head in a run.** The head stays relatively steady while the trunk moves in gallop
   ([Dunbar, JEB 207:4427](https://cob.silverchair.com/jeb/article/207/25/4427/15113/Stabilization-and-mobility-of-the-head-and-trunk)).
   The world-space head goal of §3.1 delivers this if the neck lag is soft enough.
4. **Tail as counterbalance ✓.** Raise the tail with Fr (already `+0.15 min(1,Fr)`) and swing it opposite the yaw rate in turns.

### 3.3 Turning

Our weakness: "turns look like pivots". `steer.c` pivots on the spot only below `pivot_r` = 3.2 m and beyond 120° at low speed.
Otherwise it arcs with yaw inertia. Most of the pivot look is therefore an animation problem: the whole body rotates rigidly
about the root.

**Biomechanics.**
- Animals **slow before and during a turn** to reach a higher angular velocity. Tight turns are limited by grip (friction),
  wide ones by limb force ([Tan & Wilson 2011](https://pmc.ncbi.nlm.nih.gov/articles/PMC3107634)). C already brakes into
  corners.
- In hexapods, **legs on the outside of the turn supply most of the turning force and torque**, with only minor changes to
  straight-line forces ([Jindrich & Full 1999](https://cob.silverchair.com/jeb/article-pdf/202/12/1603/2603781/jexbio_202_12_1603.pdf)).
- Galloping horses and dogs **lead with the inside limbs**. The inside lead leg has a higher duty factor on curves, and limb
  lean increases as predicted ([Thoroughbred curve study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7771664/);
  [review](https://pmc.ncbi.nlm.nih.gov/articles/PMC9197309)).
- The outside limb produces more vertical and lateral impulse ([SICB abstract](https://sicb.org/?p=28264)).

**Technique.**
1. **Anticipation from the future path.** Spore's open problem; the motion-matching idea.
   - Read C's look-ahead target (pure pursuit point) or `intent_yaw` ✓ (exists).
   - Head and neck turn toward it first: neck yaw up to 0.6 rad, leading by ~0.2–0.3 s (tuning).
   - The front girdle follows; the hind girdle lags.
   - The visible spine bends to the path curvature κ: per-station yaw `ψ(z) = κ · (z − z_com)`, clamped by spine
     flexibility. On an arc the body then lies *along* the arc, not tangent to it.
   - This is visual only; the root still follows C.
2. **Lean (bank).** `roll = −atan(v ω / g) · k_bank` ✓ exists. Keep it, but make it **limb lean**: legs tilt inward with the
   body. Feet are placed on a wider track on the outside of the curve (`+0.15 track · |κ| · body_length`, tuning).
3. **Stepping turn at low speed** (replaces the rigid pivot).
   - Below 0.15 √(g h) with |ω| > 0: a **turn on the forehand** for quadrupeds with heavy fronts (hind legs step around,
     front legs step in place), or a **turn on the haunches** for others and for bipeds (front swings around, hind step in
     place).
   - Pick by whether the centre of mass is nearer the front or the hind station.
   - Steps follow the normal walk sequence, with step targets on the arc around the pivot station.
   - The pivot station's feet lift and replant within a 0.1 h radius, so they never slide. This is the existing `pivoting`
     flag, made asymmetric.
4. **Inside lead in canter and gallop.** Pick the lead from the sign of the smoothed yaw rate. Do a **lead change**
   (swap the left/right offsets over one stride in the gathered flight) when the curvature sign has persisted for more than
   0.5 s (tuning).
5. **Multi-legged bodies.** Turn by differential stride: inside legs get shorter strides, outside legs longer
   (`λ_i = λ (1 ± κ x_i)`). Use no bank (`BANK_K` multi 0.2 is fine).

### 3.4 Slopes, steps and climbing

**Already ✓.**
- Hip plane fitted to feet.
- Pitch and roll follow terrain (k_p 1 for quadrupeds, 0.25–0.5 for bipeds).
- Uphill stride shortening `1/(1+1.6 grade)`.
- Swing height from five ground samples.
- C stalls and slides by leg count.

**Biomechanics.**
- Dogs trotting on a 15° grade: **downhill, hindlimb duty factor falls and the hindlimb is set down later**, which reduces
  nose-down pitching from braking. Uphill impulses depart more from level, with limbs acting more like levers
  ([JEB 2006, dogs on 15° grade](https://cob.silverchair.com/jeb/article-pdf/209/20/4154/1257276/4154.pdf);
  [Lee, SICB](https://sicb.org/?p=33929)).
- Opossums move more slowly on slopes with a higher required friction coefficient
  ([JEB 2006](https://pmc.ncbi.nlm.nih.gov/articles/PMC4776376)).
- Rats switch to a quasi-static in-phase gait, with more trunk use, on steep inclines
  ([Birn-Jeffery & Higham 2016](https://biomechanics.ucr.edu/Birn-Jeffery&Higham_2016_FZ.pdf)).

**Rules.**
1. **Trunk pitch.** The trunk follows the slope through the feet. The **head pitch stays nearer level** through the
   world-space gaze goal of §3.1: head pitch = 0.3 × slope pitch (tuning).
2. **Uphill.**
   - Lower the body (crouch +0.05 h per 0.2 grade) and shift weight forward (balance shift toward the front station).
   - Shorten strides ✓ and raise duty (+0.05 per 0.2 grade).
   - Forelimbs reach higher and land closer.
   - Steep (grade > 0.6): a quasi-static gait that keeps three feet down, with the trunk pulled close to the slope.
3. **Downhill.**
   - Raise the front and push the hips back (the centre of mass moves back over the hind feet).
   - Hind duty −0.05 and later hind touchdown (Fr-scaled, per the dog data).
   - Shorter, more frequent strides when braking.
   - Tail up for counterbalance.
4. **Steps (the "steps" zoo course).**
   - **Foothold selection.** Score candidate touchdown points in a small disc (radius 0.25 foot length + 0.1 h) around the
     planned home.
   - Score = flatness (height variance in a foot-sized patch) + distance from edges (|∇h| spikes) + reach margin.
   - Pick the best. This removes "toes on the lip" and hanging feet.
   - **Step-up sequence.** Front feet lift high (swing height = obstacle + 0.15 h, ✓ partly). The body pitches nose-up while
     the front station is on the higher level. The hind station follows with a push (bounce impulse).
   - **Step-down.** Front feet reach down (extend), the trunk pitches nose-down and is caught by the springs.
5. **Too steep (C `stalled`, `slide`).**
   - Stall: feet scrabble in place (forced swing with short strides at high cadence), the body lowered and leaning into the
     slope.
   - Slide: feet plant and drag. This is the one case where visible foot slip is *correct*; the slip metric must exclude it.

### 3.5 Digging (no body motion today)

There is a part `excavadora` (category `dig` in `creature_bio.gd`), and digging currently emits only soil FX. Make digging an
**action** in the existing action layer (`godot/actions/`, JSON tracks + body map + springs), driven `cosmetic`. C remains the
authority on when digging happens and where the creature is.

**Biomechanics.** The nine-banded armadillo, a scratch-digger, has well-described acts
([Redalyc ethogram](https://www.redalyc.org/journal/457/45760865003/html/)):

| Act | Description |
|---|---|
| Nose push (PEH) | Nose half on the ground to loosen soil; precedes digging in all subjects. |
| One-forelimb scratch (DOL) | Brief, preparatory. |
| Alternating forelimbs (DATL) | The most common opening act. |
| Simultaneous forelimbs (DSTL) | Frequent continuation (DATL→DSTL 52 %). |
| Hind push of soil under the abdomen, both limbs (PETLS) | While the forelimbs support. |
| Fast alternating back-pedal (PETLA) | Hindlimbs. |
| Body stretch (PESB) | The body arches and pushes the head forward; always after forelimb digging. |
| Tail tripod | The tail forms a tripod with the hindlimbs during forelimb digging. |

- Moles scratch-dig with mainly **long-axis rotation** of the humerus
  ([SICB XROMM abstract](https://sicb.org/?p=15333);
  [Lin et al. 2019, mole walking](https://pmc.ncbi.nlm.nih.gov/articles/PMC6832175): walking stride 6.4 Hz in a ~95 g mole).
- I found no published scratch-cycle frequency. The cycle period below therefore uses pendulum scaling, which is what Froude
  similarity implies for limb cycles: `T_scratch = k √(l_forelimb / g)` with k ≈ 1.6 (tuning). That gives about 4 Hz for a
  dog-sized forelimb of 0.25 m and about 2 Hz for 1 m. Calibrate against reference video (§4.3).

**Technique (`dig.json` plus a small procedural limb driver).**
1. **Approach.** Stop. Lower the head with the nose to the dig point (neck goal at the ground; sniff fidget ✓ exists). Do 2–3
   nose pushes (head pitch pulses of 0.1–0.2 rad, tuning).
2. **Stance.** Widen the hind track by 20 %. Crouch the hind legs (hip height −15 %). Pitch the trunk nose-down 10–25°
   (tuning, more for short forelimbs). If there is a tail, its tip goes to the ground as a third support (tripod).
3. **Scratch cycle** for the **digging limbs**: the `excavadora` part's limbs if present, else the front station's legs, else
   the head (nose push only, for legless or armless bodies).
   - Each stroke runs: reach forward-down to the dig point → rake back under the chest → flick out between or beside the
     hind legs.
   - Use a closed path in the sagittal plane, 0.35 × forelimb length long, with a minimum-jerk power stroke over 45 % of the
     cycle (tuning).
   - Alternate (DATL) for the first 1–2 s, then simultaneous (DSTL) bursts. The pattern follows the armadillo sequence
     statistics.
4. **Soil removal.** Every 3–5 forelimb cycles (tuning), do 2–4 fast alternating hind kicks (PETLA), with the forelimbs
   planted.
5. **Body stretch.** Occasionally (after a burst) arch and push the head forward into the hole (PESB).
6. **FX sync.** Emit soil particles at the end of each power stroke (the flick) and at each hind kick, not on a timer.
   Particle count scales with stroke length × foot width.
7. **Many-legged bodies.** The front pair digs, the second pair braces, and the others hold.
8. **Exit.** Shake (the `fidget_shake` ✓ exists) and resume the gait through the action-layer fade.

### 3.6 Eating and idle (brief)

**Eating.**
- `eat.json` ✓ exists: head pitch and jaw.
- Missing:
  - The **neck chain solves toward the food position** (spline IK, world target).
  - **Long-neck short-leg bodies** splay the forelimbs (track +30–50 %, tuning) when the target is below their reach.
  - **Graze-walk:** step forward 1 step every few bites. The C root does not move, so these are visual "shuffle" steps
    within the 0.12 h home tolerance.

**Idle.**
- **Breathing.** Trunk scale and chest rise with period from respiratory allometry, f = 53.5 M^−0.26 breaths/min
  ([Stahl 1967](https://doi.org/10.1152/jappl.1967.22.3.453)). That is about 22/min at 30 kg and about 5/min at 6 t.
- **Weight shifts** every 3–8 s (tuning): unload one leg (hip drop 2–4 % h).
- **Head scan saccades:** yaw jumps of 0.2–0.6 rad with hold times of 0.5–2 s, then return. The world-space gaze goal makes
  these cheap.
- **Ear and tail flicks** as passive springs with noise impulses.
- Fidgets ✓ exist (shake, sniff, stretch, yawn, tail swish). Make them phase-safe: start only when all feet are planted.

---

## 4. How to evaluate "looks good"

### 4.1 Objective metrics

Extend `make godot-loco-test` and build M0's planned `godot-loco-realism` (not yet built; no `realism.gd` exists). Run on the
zoo morphs × courses (figure8, zigzag, steps, uturn, ramps) × speeds. Each gate is computed on the IK-solved rig, not on the
controller targets.

| Metric | Definition | Gate |
|---|---|---|
| Foot skate | Horizontal speed of the contact point while loaded; per stance, integrated mm. Literature thresholds: contact when toe height < 0.05–0.08 m, skating if speed > 0.1 m/s ([survey 2025](https://arxiv.org/pdf/2507.05419); [CleanMDM 2026](https://arxiv.org/pdf/2610.05411)). Scale thresholds by h. | < 20 mm per stance (now 0); slide state excluded |
| Ground penetration | Share of frames with a sole or any non-foot body part > 0.02 h below terrain; mean depth | < 1 % frames |
| Floating feet | Planted foot > 0.03 h above terrain | < 1 % frames |
| Phase consistency | Measured Hildebrand diagram (duty per foot, fore–hind lag) vs target per plan; circular s.d. of touchdown phase per foot | duty within ±0.05; lag within ±0.05 |
| Dynamic similarity | Duty and relative stride vs Fr within the Alexander & Jayes bands (as in the M0 brief) | ±0.08 duty, ±20 % stride |
| Static stability | Centre of mass inside the support polygon at statically stable walks ✓ | > 95 % frames |
| Root and head jerk | RMS third derivative of root and head position, normalised by √(h/g)/g ([kimodo metrics](https://research.nvidia.com/labs/sil/projects/kimodo/docs/benchmark/metrics.html)) | head jerk ≤ trunk jerk at walk and trot |
| Head stability | Head world pitch-rate RMS vs trunk pitch-rate RMS (Dunbar: head steadier than trunk) | ratio < 0.6 at walk and gallop |
| Head nod phase | Lag from forelimb touchdown to head minimum, as a fraction of the step | 0.05–0.25 |
| Turn coherence | Correlation between visual spine curvature and path curvature on figure8 and zigzag; front-girdle lead time | r > 0.8; lead 0.1–0.35 s |
| Pivot slip | Feet of the pivot station: max horizontal displacement during a stepping turn | < 0.1 h |
| Joint plausibility | Knee flexion at mid-stance per plan; hyperextension; self-intersection (capsule test) | no hyperextension; 0 self-hits |
| Vertical acceleration | Peak root vertical acceleration at walk ✓ (known 1.5–4.8 g) | < 1.5 g at walk |
| Perf | ms per creature per frame (controller + IK + action layer), at high and low tier | §5, L6 |

Note: Fréchet-style distribution metrics do not detect foot skating well
([Maiorca et al. 2023](https://orbi.umons.ac.be/bitstream/20.500.12907/46735/1/imx23-56_access.pdf)). Keep explicit contact
metrics.

### 4.2 Blind A/B protocol

1. **Clips.** For each change, render baseline and candidate on the *same* morph, course, seed and camera. Use
   `_loco_review_tmp.gd` (close-up contact sheets, 12 frames) plus a 6–8 s 30 fps clip under xvfb with software GL (per the
   browser-capture memory: SwiftShader, never GPU flags).
2. **Pairs.** At least 12 pairs per decision, spanning ≥ 4 morphs (one biped, one light quadruped, one giant, one many-legged)
   and ≥ 3 scenarios (walk, turn, climb or dig).
3. **Blinding.** Randomise left/right per pair with a seeded shuffle, hide labels, and store the key separately.
4. **Raters.**
   - The owner.
   - The vision critic (`tools/art/critic.py`), asked a fixed question: "Which creature moves more like a real animal of this
     shape? Consider feet, head, spine, weight."
   - A second model family as a third rater.
   - Report agreement (Cohen's κ) between the critic and the owner. If κ < 0.4, the critic is not trusted for this
     dimension.
5. **Decision.** Two-alternative forced choice; candidate wins if preferred in ≥ 65 % of pairs *and* a one-sided binomial
   p < 0.1 (≥ 11 of 15, or ≥ 10 of 12 for p < 0.05). With more than 2 variants, rank with Bradley–Terry.
6. **Veto.** No metric gate in §4.1 may regress by more than 10 %.

### 4.3 Reference material (with licences)

| Source | Content | Licence | Use |
|---|---|---|---|
| Muybridge, *Animal Locomotion* (1887), 781 plates, 95 of them horses and 124 other animals ([Wellcome](https://wellcomecollection.org/works/uczu6r4y); [Commons plates](https://download.osmand.net/wiki/File:Eadweard_Muybridge_-_Animal_Locomotion,_Plate_686_-_Google_Art_Project.jpg)) | Calibrated sequential photos: horse, dog, cat, birds and more | Public domain (US; verify per file on Commons) | Side-by-side contact sheets; manual footfall timing; can be shipped in docs |
| [SuperAnimal-Quadruped](https://pmc.ncbi.nlm.nih.gov/articles/PMC11192880) ([DeepLabCut Model Zoo](https://deeplabcut.github.io/DeepLabCut/docs/ModelZoo.html)) | 39-keypoint zero-shot pose estimator for quadrupeds, horses to elephants | Weights licence unverified; check the repo | Extract footfall phases, head-nod amplitude and spine angle from reference videos |
| [AcinoSet](https://github.com/African-Robotics-Unit/Acinoset) | Multi-view high-speed cheetah video, 119,490 frames, 3D poses | Not verified; check the repo LICENSE | Gallop spine and head reference |
| MANN dog mocap ([repo](https://github.com/cghezhang/MANN)) | Dog walk, trot, canter, turns, sit, idle | Research and education only; commercial use by licence | Internal evaluation only, if at all; owner decision |
| Truebones Zoo ([terms](https://truebones.gumroad.com/l/vlvPq); [listing](https://truebones.gumroad.com/l/skZMC)) | 75+ animated animals, FBX/BVH: quadrupeds, birds, reptiles, insects, spiders | Commercial use allowed; no redistribution or resale of the files; credit requested; paid ($45–100) | Reference clips for comparison and for R1 style fitting; the source data for AnyTop |
| Our own phone video of dogs, cats, birds, insects (owner) | Any gait, digging dogs | Ours | The best digging reference; also tests the critic |

---

## 5. Staged plan

Pipeline roles: Opus/Fable plan, Sonnet 5.5 implements Godot slices with screenshots, Codex implements headless C, tools and
Python, Claude reviews. Rules: `_agent/briefs/_rules-godot.md` (timeout, xvfb software GL, nice, tests green). Every slice
ends with the §4 gates, evidence that has actually been looked at, and Claude review. At most 3 Claude agents run at once.

### Revision of M1–M3

| Item | Status | New decision |
|---|---|---|
| M0 realism yardstick | not built | **Becomes L0**, extended with the §4.1 metrics |
| M1 optimiser pilot | ran; 6/10 bodies infeasible at all speeds; no emergent walk→trot (light quadruped trots at Fr 0.3); hexapod, octopod, hatchling and light quadruped feasible | Keep the code. Report the result in `docs/GAITOPT-REPORT.md` (now 288 words; it omits the failure table). **M1b spike** below. |
| M2 predictor | not started | **Paused** until M1b passes. Replaced for now by R1. |
| M3 predicted gait A/B | not started | Paused; the A/B harness moves to L0 |
| S2 Froude speed, W1/W2 wings | unchanged | unchanged |

### L0. Yardstick and review harness (S–M; Sonnet for Godot, Codex for the analysis script)

**Deliverable.**
- `godot/locomotion/test/realism.gd` and `make godot-loco-realism`, computing all of §4.1 for the 7 zoo morphs × 5 courses
  × 3 speeds.
- `_loco_review_tmp.gd` promoted to `devtools/tools/loco_review.gd`, with a `--ab` mode that renders blinded pairs and a key
  file.
- `docs/evidence/godot/locomotion/realism.json` (baseline).
- A Muybridge reference sheet (horse walk, trot and gallop; dog trot) placed beside our hero, giant and trotter sheets.

**Gate.**
- Runs in under 120 s headless.
- Reproducible to 1e-6.
- Baseline numbers committed.
- The known weaknesses show up as failing or reported metrics: head stability ratio, turn coherence, knee flexion.

### L1. Posture and head (M; Sonnet)

**Deliverable** (§3.1 rules 1–3, §3.2.3):
- Size-dependent stance straightness.
- World-space head goal (gaze point from C's future path) with neck spline solve.
- Phase-locked head nod (local phase channel).
- Bird-style hold/thrust bob as a genome trait.
- Pelvic list for bipeds.

**Files.** `loco_controller.gd` (neck section 15, posture), `loco_rig_adapter.gd` (neck chain from a goal), and
`loco_morphology.gd` (mass → straightness).

**Gate.**
- §4.1 head stability < 0.6 and nod phase in band.
- Knee flexion at mid-stance down ≥ 25 % for the hero and giant.
- No other gate regresses.
- Blind A/B ≥ 65 % over 12 pairs (hero, giant, longneck, mite).

### L2. Turning (M; Sonnet, with one optional C change by Codex)

**Deliverable** (§3.3):
- Path anticipation from the C look-ahead (expose the pure-pursuit point to Godot if not already readable; read-only).
- Spine bend to path curvature.
- Limb lean and outside-wide track.
- Asymmetric stepping turn (forehand or haunches).
- Inside lead and lead change.
- Differential stride for multi-legged bodies.

**Gate.**
- Turn coherence r > 0.8.
- Pivot slip < 0.1 h.
- Foot skate stays 0.
- Blind A/B on the uturn and figure8 courses.

**Owner decision D-L3.** Whether to also change C (smaller `pivot_r`, or a short forward creep before a pivot, so big bodies
arc). This changes goldens. Recommendation: first see L2's visual-only fix.

### L3. Terrain: footholds, steps, slopes (M; Sonnet)

**Deliverable** (§3.4):
- Foothold scoring in the planner.
- Step-up and step-down sequences.
- Uphill and downhill posture and duty changes.
- Stall scrabble.
- Slide exclusion in the skate metric.

**Gate.**
- Zero planted feet on edges (a new metric: foot patch height variance < 0.02 h).
- Penetration < 1 %.
- Floating < 1 %.
- Blind A/B on the steps and ramps courses.

### L4. Dig, eat, idle (M; Sonnet)

**Deliverable** (§3.5–3.6):
- `godot/actions/data/dig.json` with a rhythmic procedural limb driver: a new track type or a small driver in
  `action_solver.gd` for closed-path limb cycles. It handles the nose push, stance, scratch (alternating then simultaneous),
  hind kicks, body stretch, and FX synced to strokes.
- Body-map rules for `excavadora`, front legs, many-legged bodies and legless bodies.
- Neck-target eating with forelimb splay.
- Breathing by allometry, weight shifts and head saccades.

**Gate.**
- Strips for 5 morphs digging.
- FX events coincide with stroke ends (± 1 frame).
- Planted feet slip 0 during the dig.
- The owner looks at a 10 s clip per morph next to a dog-digging reference video.

**Owner decision D-L4.** Is digging a C state (the sim stops the creature and knows the duration), or only a cosmetic action
on an existing C event? Recommendation: cosmetic on the C event that already triggers the soil FX.

### L5. Gait richness (M; Sonnet)

**Deliverable**:
- Leg groups with rational frequency ratios (Spore).
- Wilson continuum wave → tetrapod → tripod for multi-legged bodies.
- Centipede body wave with a lag to the leg wave.
- Canter.
- Rotary vs transverse gallop by spine flexibility.
- Spine flexion timed to the lift-offs, with amplitude from the genome.

**Gate.**
- Hildebrand diagrams match the targets per plan.
- Stride × cadence = speed per leg group.
- Blind A/B (centipede, hexapod, trotter at gallop).

### L6. Performance and LOD (S–M; Sonnet, Codex for profiling)

**Deliverable.**
- A measured cost per creature (controller, IK, action layer) at the high and low tiers.
- Check whether creatures are skinned to `Skeleton3D`. If so, move the leg IK to `TwoBoneIK3D` and necks and tails to
  `SplineIK3D` / `SpringBoneSimulator3D` (C++).
- LOD tiers:
  - Near: full controller at 60 Hz.
  - Mid: controller at 30 Hz with pose interpolation, and no foothold scoring.
  - Far: action layer `light` ✓ plus a phase-only leg cycle with no IK.

**Gate.** The low tier holds 30 fps with 30 creatures on screen on the reference iGPU scene.

**Owner decision D-L6.** If GDScript is still too slow, allow porting the controller's hot loop to C++ GDExtension. This would
be visual-only code outside the deterministic core.

### R1. Reference-anchored parameter fitting (M; Codex) — replaces M2 for now

**Deliverable.** `tools/gaitfit/`:
- Extract per-gait targets (duty, fore–hind lag, relative stride, head-nod amplitude, spine angle, body pitch) from Muybridge
  plates (manual timing) and, if D-R1 = yes, Truebones Zoo clips (BVH, parsed directly).
- Fit allometric curves of each target against body features (Fr, mass, leg length ratio, spine flexibility, plan).
- Export `godot/locomotion/data/gait_reference.json`, read by `loco_gait.gd` in place of the hand constants.

This is Wampler 2014's idea in its simplest form: regression from body features to style parameters measured on real
animals. No physics is involved.

**Gate.**
- Held-out animals predicted within the §4.1 bands.
- The L0 metrics improve or hold.
- Blind A/B ≥ 65 %.

### M1b. Balance-feedback spike (time-boxed 2 days of Codex; optional)

**Deliverable.**
- Add SIMBICON-style foot-placement feedback (`x_foot += c_d d + c_v v` on centre-of-mass offset and velocity) and a trunk
  virtual-force PD (Coros 2011) to `tools/gaitopt/gait_ref.py`.
- Rerun only the light and heavy quadrupeds, Merodeador, Garfio, the hexapod and the octopod.

**Gate (all must hold, or physics optimisation is dropped for this project phase).**
- ≥ 5 of 6 bodies feasible at ≥ 4 of 5 speeds.
- Guide-force work < 10 %.
- The light quadruped's best gait at Fr 0.3 is a walk.
- Merodeador never leaves the ground.

**If it passes,** M2/M3 resume, with R1's reference targets added to the cost as a style term (that is exactly inverse-optimal
style).

### Order

- **Now:** L0 (Sonnet) ∥ R1 extraction tooling (Codex).
- **Then:** L1 → L2 (Sonnet, sequential: both touch neck and spine) ∥ L4 (Sonnet; it touches only the action layer) ∥ M1b
  (Codex, if D-M1b = yes).
- **Then:** L3, L5, L6.
- W2/F1 (wings) and S1/S2 continue independently.

### Owner decisions

| ID | Question | Recommendation |
|---|---|---|
| D-M1 | Accept that M1 failed its gates; pause M2/M3; allow a 2-day M1b spike | **Yes** |
| D-R1 | Buy Truebones Zoo ($45–100; commercial use OK, files never redistributed; kept outside the repo) as reference data | **Yes**, if a budget exists. Muybridge alone covers horse, dog and cat. |
| D-MANN | Use MANN dog mocap for internal evaluation only | **No** (licence ambiguity; Muybridge suffices) |
| D-L3 | Change C turning (smaller pivot radius or creep-then-pivot) | Decide after L2's visual-only fix |
| D-L4 | Digging as a cosmetic action on the existing C event | **Yes** |
| D-L6 | Allow a C++ GDExtension for the visual locomotion loop if GDScript misses the low-tier budget | Decide after L6 measurements |
| D-bob | Bird-style head bob as a genome trait, shown in the creator | **Yes**, default off except for wader-like bodies |

---

## 6. Bibliography

**Games and engines**
- Hecker, Raabe, Enslow, DeWeese, Maynard, van Prooijen. Real-time motion retargeting to highly varied user-created morphologies. SIGGRAPH 2008. https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies · DOI https://doi.org/10.1145/1360612.1360626
- Rosen. An Indie Approach to Procedural Animation. GDC 2014. https://gdcvault.com/play/1020049/Animation-Bootcamp-An-Indie-Approach · Overgrowth source (Apache-2.0) https://gamingonlinux.com/2022/04/overgrowth-from-wolfire-games-goes-open-source
- Jakobsson, Therrien. Animating Rain World. GDC 2016. https://gamedeveloper.com/art/video-animating-i-rain-world-i-and-its-many-squishy-stretchy-creatures
- Clavet. Motion Matching and the Road to Next-Gen Animation. GDC 2016. https://www.gdcvault.com/play/1022985/Motion-Matching-and-The-Road
- Godot: Inverse kinematics returns to Godot 4.6. https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/ · Godot 4.7 release https://godotengine.org/releases/4.7/
- Creature Creator (Lochner), reportedly GPL-3.0. https://awesome.ecosyste.ms/projects/github.com%2Fdaniellochner%2Fcreature-creator

**Data-driven and neural animation**
- Holden, Komura, Saito. Phase-functioned neural networks for character control. SIGGRAPH 2017. https://www.ipab.inf.ed.ac.uk/cgvu/phasefunction.pdf
- Zhang, Starke, Komura, Saito. Mode-adaptive neural networks for quadruped motion control. SIGGRAPH 2018. https://github.com/cghezhang/MANN
- Starke, Zhao, Komura, Zaman. Local motion phases for learning multi-contact character movements. SIGGRAPH 2020. https://www.ipab.inf.ed.ac.uk/cgvu/basketball.pdf
- Starke, Mason, Komura. DeepPhase: periodic autoencoders for learning motion phase manifolds. SIGGRAPH 2022. https://i.cs.hku.hk/~taku/deepphase.pdf · https://github.com/sebastianstarke/AI4Animation
- Holden, Kanoun, Perepichka, Popa. Learned Motion Matching. SIGGRAPH 2020. https://www.theorangeduck.com/media/uploads/other_stuff/Learned_Motion_Matching.pdf
- Gat et al. AnyTop: character animation diffusion with any topology. 2025. https://arxiv.org/abs/2502.17327
- ReConForM: real-time contact-aware motion retargeting for more diverse character morphologies. 2025. https://arxiv.org/abs/2502.21207

**Physics, RL and optimisation**
- Yin, Loken, van de Panne. SIMBICON. SIGGRAPH 2007. https://www.cs.ubc.ca/~van/papers/2007-siggraph-simbicon.pdf
- Coros, Karpathy, Jones, Reveret, van de Panne. Locomotion skills for simulated quadrupeds. SIGGRAPH 2011. https://www.cs.ubc.ca/~van/papers/2011-TOG-quadruped/index.html
- Geijtenbeek, van de Panne, van der Stappen. Flexible muscle-based locomotion for bipedal creatures. SIGGRAPH Asia 2013. https://www.cs.ubc.ca/~van/papers/2013-TOG-MuscleBasedBipeds/index.html
- Wampler, Popović. Optimal gait and form for animal locomotion. SIGGRAPH 2009. https://grail.cs.washington.edu/projects/animal-morphology/s2009/
- Wampler, Popović, Popović. Generalizing locomotion style to new animals with inverse optimal regression. SIGGRAPH 2014. https://grail.cs.washington.edu/projects/inverse_locomotion · https://grail.cs.washington.edu/wp-content/uploads/2015/08/wampler2014gls.pdf
- Peng et al. DeepMimic (2018) https://xbpeng.github.io/projects/DeepMimic/ · AMP (2021) https://xbpeng.github.io/projects/AMP/ · ASE (2022) https://xbpeng.github.io/projects/ASE/
- Bergamin, Clavet, Holden, Forbes. DReCon. SIGGRAPH Asia 2019. https://theorangeduck.com/media/uploads/other_stuff/DReCon.pdf
- Huang, Mordatch, Pathak. One policy to control them all. ICML 2020. https://arxiv.org/abs/2007.04976 · https://github.com/huangwl18/modular-rl/
- Gupta, Fan, Ganguli, Fei-Fei. MetaMorph: learning universal controllers with transformers. ICLR 2022. https://openreview.net/pdf/7ef00fd81bdb696532e182f6073e6e6d9cb15e98.pdf
- Ijspeert. Central pattern generators for locomotion control in animals and robots: a review. Neural Networks 2008. https://pubmed.ncbi.nlm.nih.gov/18555958/

**Biomechanics**
- Alexander & Jayes. A dynamic similarity hypothesis for the gaits of quadrupedal mammals. J Zool 1983. https://scilit.com/publications/dc3ca3a8889beee2adc0bfd2c6593882
- Alexander. The gaits of bipedal and quadrupedal animals. 1984. https://scilit.com/publications/37ce238ee99e5a42ecd9ff1e3025610f
- Heglund & Taylor. Speed, stride frequency and energy cost per stride. JEB 1988. https://cob.silverchair.com/jeb/article-split/138/1/301/5532/Speed-Stride-Frequency-and-Energy-Cost-Per-Stride
- Hildebrand. Symmetrical gaits of horses. Science 1965. https://scilit.com/publications/b17c0ed7f2f640b4c7f51bccf81a27e5 · Analysis of asymmetrical gaits 1977 https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1977_Analysis-of-Asymmetrical-Gaits.pdf
- Hildebrand. Motions of the running cheetah and horse 1959 https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1959_motions-of-running-cheetah-and-horse.pdf · Further studies on locomotion of the cheetah 1961 https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/04/Hildebrand_1961_Further-Studies-on-Locomotion-of-the-Cheetah.pdf
- Cartmill, Lemelin, Schmitt. Support polygons and symmetrical gaits in mammals. 2002. https://www.originalwisdom.com/wp-content/uploads/bsk-pdf-manager/2019/10/Cartmill-et-al_2002_Support-polygons-and-symmetrical-gaits-in-mammals.pdf
- Biewener. Scaling body support in mammals: limb posture and muscle mechanics. Science 1989. https://doi.org/10.1126/science.2740914
- Stahl. Scaling of respiratory variables in mammals. J Appl Physiol 1967. https://doi.org/10.1152/jappl.1967.22.3.453
- Wilson. Insect walking. Annu Rev Entomol 1966. https://doi.org/10.1146/annurev.en.11.010166.000535 · fly continuum, JEB 2018 https://cob.silverchair.com/jeb/article-pdf/221/22/jeb189142/1904837/jeb189142.pdf
- Centipede body–leg waves: Anderson, Full & Garcia (SICB) https://sicb.org/?p=37551 · robot, APS 2022 https://archive.aps.org/mar/2022/k03/11 · Dionne, Giardina, Mahadevan 2026 (preprint) https://arxiv.org/html/2603.08409v2
- Jindrich & Full. Many-legged maneuverability: dynamics of turning in hexapods. JEB 1999. https://cob.silverchair.com/jeb/article-pdf/202/12/1603/2603781/jexbio_202_12_1603.pdf
- Tan & Wilson. Grip and limb force limits to turning performance in competition horses. Proc R Soc B 2011. https://pmc.ncbi.nlm.nih.gov/articles/PMC3107634
- Curve running in Thoroughbreds (PLoS ONE 2020). https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7771664/ · turning review https://pmc.ncbi.nlm.nih.gov/articles/PMC9197309 · quadrupedal turning (SICB) https://sicb.org/?p=28264
- Dunbar et al. Stabilization and mobility of the head, neck and trunk in horses. JEB 2008. https://cob.silverchair.com/jeb/article-split/211/24/3889/18018/Stabilization-and-mobility-of-the-head-neck-and · https://pmc.ncbi.nlm.nih.gov/articles/PMC2768006 · monkeys, JEB 2004 https://cob.silverchair.com/jeb/article/207/25/4427/15113/Stabilization-and-mobility-of-the-head-and-trunk · review https://pmc.ncbi.nlm.nih.gov/articles/PMC4986613
- Rhodin et al. Vertical movement symmetry of the withers in horses with induced lameness. 2018. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6175082/
- Necker. Head-bobbing of walking birds. J Comp Physiol A 2007. https://www.reinhold-necker.de/Head%20bobbing%20print.pdf
- Dogs trotting on a 15° grade, JEB 2006. https://cob.silverchair.com/jeb/article-pdf/209/20/4154/1257276/4154.pdf · Lee, uphill and downhill running in a quadruped (SICB) https://sicb.org/?p=33929 · opossum slopes https://pmc.ncbi.nlm.nih.gov/articles/PMC4776376 · Birn-Jeffery & Higham 2016 https://biomechanics.ucr.edu/Birn-Jeffery&Higham_2016_FZ.pdf
- Cheetah spine models: https://www.frontiersin.org/articles/10.3389/fbioe.2022.825638/full · https://arxiv.org/html/2604.00329v1
- Nine-banded armadillo digging behaviour (ethogram). https://www.redalyc.org/journal/457/45760865003/html/
- Mole forelimb kinematics: XROMM scratching (SICB) https://sicb.org/?p=15333 · Lin et al. 2019, How moles walk https://pmc.ncbi.nlm.nih.gov/articles/PMC6832175 · gopher digging forces (JEB 2019) https://cob.silverchair.com/jeb/article-pdf/222/23/jeb213553/1979666/jeb213553.pdf

**Evaluation and data**
- Motion generation survey (metrics). 2025. https://arxiv.org/pdf/2507.05419 · CleanMDM thresholds https://arxiv.org/pdf/2610.05411 · NVIDIA kimodo metrics https://research.nvidia.com/labs/sil/projects/kimodo/docs/benchmark/metrics.html · Maiorca et al. 2023 (FMD vs skating) https://orbi.umons.ac.be/bitstream/20.500.12907/46735/1/imx23-56_access.pdf
- Ye et al. SuperAnimal pretrained pose estimation models. Nat Commun 2024. https://pmc.ncbi.nlm.nih.gov/articles/PMC11192880 · https://deeplabcut.github.io/DeepLabCut/docs/ModelZoo.html
- AcinoSet. https://arxiv.org/abs/2103.13282 · https://github.com/African-Robotics-Unit/Acinoset
- Truebones Zoo, terms https://truebones.gumroad.com/l/vlvPq · listing https://truebones.gumroad.com/l/skZMC
- Muybridge, Animal Locomotion (1887): Wellcome https://wellcomecollection.org/works/uczu6r4y · Commons plate example https://download.osmand.net/wiki/File:Eadweard_Muybridge_-_Animal_Locomotion,_Plate_686_-_Google_Art_Project.jpg

**Internal**
- M1 pilot: `/home/diego/Desarrollo/cpore-wt/gaitopt/tools/gaitopt/README.md`, `.../results/pilot/*.json`, `docs/GAITOPT-REPORT.md` in that worktree.
- Plan of record: `/home/diego/Desarrollo/cpore-wt/_agent/briefs/motion-flight-plan.md`.
