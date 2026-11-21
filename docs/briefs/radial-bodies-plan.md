# Radial body plans: implementation plan (A24 symmetry)

Owner approved ("sí a todo") symmetry choices beyond bilateral, per DESIGN.md A24 (6): bilateral, radial 4/5/6/8,
bilateral asymmetric for the player; biradial and asymmetric for wild creatures or colonies only. Radial is a lineage
body plan chosen at the start, changeable mid-game only through a rare, costly "radialisation" event. Wild species come
first: **brujula** (pentaradial tide-pool star), **cuarteta** (4-arm jellyfish), **corona** (6-arm cave disc), from
`lore/creatures/{brujula,cuarteta,corona}.json` (`body_plan.symmetry=radial`, `arms` 5/4/6). The player's creator comes later (S6).

Hard rule for every slice: **bilateral genomes stay byte-identical** (same JSON, same C form/profile/body, same mesh,
same world/combat goldens). Each slice lists the guard test that proves it.

## Current state (what the plan builds on)
- Genome `cpore.creature/5` (`/4` migrates on read). Four validators that must agree: `core/src/stage_genome.c`
  (`cp_stage_genome_form`, strict `keys()` whitelists, so an unknown key is rejected), `godot/creature/creature_genome.gd`,
  `godot/studio/genome.gd`, `web/studio/genome.js` (studio `node_check.js` cross-checks the Godot output).
  Optional keys were added before without a schema bump (`act`, `single`, `pupil`, `skin.cs/ps/pc/ros/sk/act`).
- Body = one tube along a spine from `nodes` (y,z,r; 4..32 nodes, consecutive distance >= .05): `Creature._sample_spine`
  (NSP 60 + 2x NC 6 = NS 72 rings, RN 22 verts per ring), `CreatureGeo.fill_tube`, `anchor(t, ang)` (ang around the spine,
  0 dorsal). Parts mirror by `ang -> -ang` (`_build_parts`, `sides=[1,-1]`, `_centered` when |sin ang| < .14, `single`
  -1/1 keeps one side). Legs are 2-segment IK chains (`CreatureLegChain`). Skeleton = one spine bone chain (stride 4 rings).
- Turing UVs: (arc along spine, arc from the dorsal midline mirrored) so the pattern is bilaterally symmetric.
- `CreatureBio.derive`: no legs -> skeleton `hydro`; hydro limbs allow peristaltic/hydrostat/tubefeet/cilia; shader
  `ACT_MODE` already has tube feet = 7 (sucker dots, "code only" today).
- Locomotion: `actor_driver.gd` builds `loco_controller` from `loco_rig_adapter.loco_describe` +
  `LocoMorphology` (plans upright_biped/horizontal_biped/quadruped/multi/legless/monopod; `loco_gait.gd` Hildebrand offsets).
  The host basis is set to the C yaw every frame.
- Sim: the combat profile comes from part *entries* (`f.parts[id]++`, one per entry, mirror pairs count once).
  `radius_cm` from nodes: diameter = max(maxz-minz, 2 maxr) (C, `game/stage/profile.gd`, `web/engine/profile.js`,
  fixture `game/tests/fixtures/profile_expected.json`). Steering uses `legs` from the **setup** (`player_legs`,
  `wild[i].legs`, 0 = 4, GDExtension accepts 0..8, `cp_steer_body` clamps 1..8, the world log writes a `legs` line only
  when one is non-zero). C never reads legs from the genome. Wild species bodies are Godot data
  (`island.gd SPECIES_BODY/SPECIES_SCALE`, `game/data/<id>.json`); their sim stats are `CP_STAGE_SPECIES[]` in `stage_world.c`.
- The precedent for adding species is 292c52d (Acechalunas, Babosa: `CP_SOC_SPECIES` 6, snapshot v7, "hash unchanged
  for worlds that do not use them").

---

## S1. Genome representation (no visuals)

**Decision (recommended, owner Q1): an optional top-level `plan` object in `cpore.creature/5`; no schema bump.**
Absent = bilateral. Writers never emit a bilateral plan (canonical form: the studio model deletes the key when
bilateral), so every existing genome is untouched and no migration is needed.

```json
"plan": {
  "sym": "radial",          // "radial" now; "biradial" | "asym" reserved (wild only, later); "bilateral" accepted but never written
  "fold": 5,                // integer 3..8 (creator offers 4/5/6/8; 3..8 for wild)
  "star": 0.3,              // 0..1 lobing of the disc margin toward the arms (0 round disc/bell, 1 deep star)
  "gel": 0,                 // 0..1 translucency/subsurface for jellies (owner Q9); absent = 0
  "arm": {
    "len": 3.0,             // 0..6, in disc radii (0 = no arms: a plain disc or bell)
    "w": 0.42,              // .1..1, base width as a fraction of the disc radius
    "taper": 0.85,          // 0..1
    "curl": 0.1,            // -1..1: + tips curl up (aboral), - curl down (oral)
    "droop": 0,             // 0..1: arms hang beneath the body (jellyfish oral arms)
    "frill": 0,             // 0..1: ruffled arm margins
    "tip": "point",         // point | frill | bulb
    "eye": 1,               // 0/1: optic cushion at each arm tip (starfish eyespots)
    "act": "tubefeet"       // optional, hydro set: peristaltic | hydrostat | tubefeet | cilia (absent = derived)
  }
}
```

Meaning of the existing fields when `sym == "radial"`:
- `nodes` = the **axial profile**, oral pole first (bottom) to aboral pole last (top). Every node must have `z == 0`
  and `y` strictly increasing (error `plan.nodes`); `r` is the ring radius. Existing distance rule (>= .05) still applies.
  With z = 0 the existing radius rule gives diameter = 2 maxr (the disc), so C/GD/JS radius stay unchanged (arms do not
  count in v1, owner Q5).
- `parts[].t` = position along the axial profile (0 oral, 1 aboral), `ang` = bearing around the axis from arm 0.
  A part with `t <= .04` or `t >= .96` is **axial** (one centred copy: mouth on the oral pole, a madreporite on top).
  Every other part is **replicated `fold` times** at `ang + 2 pi k / fold`. `single: 1` = exactly one copy at `ang`
  (asymmetry: one giant pincer); `single: -1` is invalid in radial (error `parts.single`).
- Leg parts are forbidden in radial (error `plan.legs`): the arms are the locomotors. List (C has no categories, so use
  ids): `pata zanca pezuna leg_sprinter leg_sucker foot_spring foot_hoof foot_gecko`.
- `regions[].surface` must be `torso` (aboral surface); `mirror` is ignored (replicated `fold` times).
- Combat rule (document in CREATURE-REALISM.md §4b): **a radial replica is like a mirror pair: one entry, one stat.**
  `plan` adds nothing to the profile in v1 (A24: actuation/symmetry sim rules are designed later with the owner).

Files and work:
1. `core/src/stage_genome.c` `cp_stage_genome_form`: add `|plan|` to the top-level whitelist; new static
   `plan_ok(j, plan, nodes, parts, regions)` with `keys(plan,"|sym||fold||star||gel||arm|")`,
   `keys(arm,"|len||w||taper||curl||droop||frill||tip||eye||act|")`, `oneof(sym,"|bilateral||radial|")`,
   `integer(fold,3,8)` (required when radial), `optional()` ranges above, `oneof(tip,"|point||frill||bulb|")`,
   `integer(eye,0,1)`, `oneof(act,"|peristaltic||hydrostat||tubefeet||cilia|")`, and the node/leg/single/region rules.
   Body string is copied verbatim (the /4 rewrite path already copies unknown bytes), so determinism is unchanged.
   Profile and `radius_cm` code untouched.
2. Same rules in `godot/creature/creature_genome.gd` `_validate` (new `_plan(g)`), `godot/studio/genome.gd`, and
   `web/studio/genome.js` `validate` (error paths identical strings: `plan`, `plan.fold`, `plan.arm.len`, `plan.nodes`,
   `plan.legs`, `parts.single`, `regions.surface`).
3. `CreatureGenome.plan_of(g) -> Dictionary` helper: returns `{sym:"bilateral"}` when absent, fills defaults
   (star .3, gel 0, arm {len 2.5, w .4, taper .8, curl 0, droop 0, frill 0, tip "point", eye 0}).

Tests (S1):
- C `tests/test_world.c` (or new `tests/test_plan.c` in `make test`): valid radial genome accepted, profile equal to the
  same genome without `plan` minus the replication; each invalid case rejected (fold 2/9/2.5, z != 0, y not increasing,
  a `pata` part, `single:-1`, region surface `neck`, unknown plan key, unknown arm key, `sym:"biradial"`).
- Parity table: one fixture list `godot/creature/tests/parity/plan_cases.json` (genome + expected error path or ok),
  run by `test_creature.gd`, `studio/tests/test_studio.gd`, `node_check.js` and the C test. All four agree.
- Guard: every existing `godot/game/data/*.json` and seed genome parses to the identical dictionary/form (existing
  parity tests) and `make test` world/combat golden replays pass untouched.

## S2. Mesh for a radial body (`godot/creature/creature_radial.gd`, new)

Keep `creature.gd` bilateral path unchanged; branch once in `Creature.build()`: `if plan.sym == "radial": _radial.build(self)`.
Refactor needed: `RN` becomes an instance var `rn` (22 for bilateral, unchanged meshes), 14 uses in `creature.gd`.

1. **Core (disc/dome/bell)**: reuse `_sample_spine` on the vertical profile (Catmull-Rom over (r, y, 0)). Vertical
   tangent gives a non-degenerate frame in `fill_tube` (u = t x X = -Z, s = +X), so `anchor(t, ang)` already walks
   around the axis; pass `shape=false` (no dorsal/belly ovality). `rn = fold * 12` (36/48/60/72/96) so every arm owns an
   exact sector. Star lobing per vertex j: `r_ij = r_i * (1 + star * w_i * ((1 + cos(fold * theta_j)) / 2)^3)`,
   `w_i = (r_i / max_r)^4` (poles stay round, margin lobes toward arms). Normals from the modulated ring (finite diff).
   Ground: radial bodies rest on the oral surface: `ground_offset = .02 - rest[NC].y` (lowest ring centre, not `y - r`).
2. **Arms** (`_arm_geo(k)`): a swept tube per arm (`CreatureGeo.alloc_tube(18, 12)` + `fill_tube`), base on the margin
   ring (widest ring) at `ang_k = 2 pi k / fold`, centreline
   `p(u) = base + dir_k * u * L + up * (curl * .5 * L * u^2 - droop * L * u)`, L = len * max_r,
   radius `w * max_r * (1 - taper * u)^.85`, cross-section flattened (y * .7) for starfish arms; frill = lateral radius
   ripple `1 + frill * .25 * sin(u * 40)` on the two side vertices groups; tip `bulb` = sphere cap 1.4 x tip radius,
   `frill` = fan of the last 15 % (ripple x 2); `eye` = small `_eyeball` (from `creature_parts.gd`) tinted red-orange at the tip.
   The base ring is welded inside the disc margin lobe (sink .3 x base radius) so no seam shows.
3. **Parts**: same `maker.make()`/`orient()`; sides loop becomes the replica loop (`fold` copies, or 1 when axial or
   `single`). Names `"%s_%d_r%d"`. Axial oral parts (mouth) face -Y and sit on the oral pole: visible only from below,
   which is correct (oral underside); `snout` wet radius goes to the oral pole.
4. **Skin / Turing**: same seed and field. Disc UV = (arc along the profile from the oral pole, sector-mirrored angle
   `phi = abs(fposmod(theta + pi/fold, 2 pi/fold) - pi/fold)` times r), so the pattern has dihedral D_fold symmetry
   (the radial analogue of the bilateral mirror). Arm UV = (arc along the arm, mirrored angle around the arm) so stripes
   band the arms and every arm matches. Countershading: "belly" = oral surface (normal.y < 0) for the disc and the arm
   underside. Arm material = `materials.limb_material(..., mode)` with mode from bio (7 tube feet = sucker dots on the
   underside; hydrostat 4 = boneless taper + slow wave). `gel > 0`: alpha blend + strong wrap SSS + rim on the body
   material (new uniform `gel`, Compatibility-safe), used by cuarteta.
5. **Bio** (`creature_bio.gd`): radial bodies get one synthetic limb group `{"kind": "arm", "index": "plan.arm",
   count: fold}` with candidates from the skeleton (hydro default: tubefeet if `tip != frill` and droop < .5,
   hydrostat for droop >= .5, cilia for frill >= .5); `plan.arm.act` overrides. `legs` = 0, `arms` = fold.
6. **Stats/mass**: `body_volume()` adds arm frusta; `mass_data()` adds `arms:[{base, dir, length, radius}]`.

Budgets: body <= 72 x 96 verts; arms 18 x 12 x fold (<= 1 728 verts); warm build <= 1.3 x the hero's 23.6 ms
(`creature/tools/realism_bench.gd` gets the three radial genomes).

Tests (S2), `godot/creature/tests/test_radial.gd` (added to `make godot-creature-test`):
- **Guard**: `tests/fixtures/bilateral_mesh_hashes.json` recorded *before* the `rn` refactor (hash of body vertex,
  normal, UV, UV2 arrays + part transforms for the 3 seeds and the 6 species); must match after every S2+ commit.
- fold copies: a non-axial part yields `fold` nodes at bearings 2 pi k/fold (+-1e-4); axial and `single` yield 1.
- Rotating the genome by 2 pi/fold (ang + 2 pi/fold on every part) gives the same mesh up to vertex permutation.
- Lowest vertex within 1..4 cm above ground; arm tips touch the ground plane within 3 cm for curl <= .2, droop 0.
- Turing UV sector symmetry: uv(theta) == uv(2 pi/fold - theta).
- Every part type on a radial body builds without error (mirror of `_test_every_part`, leg types excluded).

## S3. Skeleton and locomotion

**Skeleton** (in `creature_radial.gd`): root bone `disc` at the disc centre; `axis_0..2` up the profile (bell pulse,
disc collapse); per arm `arm{k}_0..5` chained from the root (6 bones along the arm). Disc weights: by y between the axis
bones; margin lobe vertices within the arm sector blend up to 0.35 to `arm{k}_0` (lifting an arm bends the web).
Arm weights: linear between consecutive arm bones. Exposes `arm_bones: Array[PackedInt32Array]`, `plan_kind`, `fold`.

**Gait generator**: new `godot/locomotion/loco_radial.gd` with the same interface as `loco_controller`
(`reset(pos,yaw)`, `set_intent`, `step(dt,pos,yaw,vel)`, `pose`, signal `footfall(leg,pos)`), chosen in
`actor_driver._try_loco()` when `body.plan_kind == "radial"`; `loco_rig_adapter` gets `radial_describe`/`radial_apply`;
`LocoMorphology` gets plan `&"radial"` (mass/inertia from disc + arms, `hip_height` = disc thickness, ladder empty,
`base_gait` from the arm actuation). Modes:

| Mode | Who | Motion | Numbers |
|---|---|---|---|
| `glide` (tube feet) | brujula slow | body translates smoothly, no bob; lead arm (closest to heading) lifts its tip 4 cm and sweeps +-12 deg at .5 Hz (probing); a travelling wave of the tube-feet shader phase runs base to tip | v < .5 m/s |
| `row` (brittle-star rowing, Astley 2012 J Exp Biol 215:1923) | brujula fast, any hydrostat arms | lead arm points forward; the two arms next to it row in synchrony (power stroke 40 % of the cycle, sweep 35 deg backwards in the ground plane, tip planted), the rear arms trail/drag; body surges per stroke | f = v / (.6 L_arm), clamp .4..2 Hz; footfall at each power-stroke start |
| `jet` (bell pulse) | cuarteta | contraction 30 % of the cycle: bell margin radius x .82, height x 1.1, then slow refill; arms follow with a damped spring chain lag (k 30, damping .6 per bone) | f = .5 Hz x (0.8 m / D)^.5; forward drift v = .25 m/s per pulse average |
| `cilia` (glide + metachronal margin) | corona | smooth glide, margin frill ripple `sin(3 theta - 2.0 t)`, arms stay flat | v .1..0.6 m/s; "slack-tide collapse" = axis bones scale y x .55 over 2 s while hunkered/idle |

No rolling for corona (the lore is benthic crawling); a rolling wheel body is owner Q6.

**No fixed front**: C still steers a yaw. `loco_radial` keeps a visual `body_yaw` and applies
`body_root.rotation.y = body_yaw - yaw` (counter-rotation against the host basis). The lead arm is
`argmin_k |wrap(yaw - body_yaw - 2 pi k/fold)|`; `body_yaw` only drifts toward the lead arm's bearing at .5 rad/s, so the
animal never visibly spins more than pi/fold; it just switches lead arm. **Terrain**: disc pitch/roll from a plane fit
through the ground heights under the arm tips; each arm distributes pitch over its 6 bones so the tip sits on
`ground(tip)` (CCD, 2 iterations).

**Actions** (`godot/actions/action_body_map.gd from_rig`): radial map: mouth = oral pole, "head" = lead arm tip. Minimal
radial set in v1: attack = lead arm rears 50 deg then slaps (0.4 s); guard/hunker = all arms curl up 30 deg (doming);
hurt = disc flatten x .85 for .2 s; death = arms limp (droop 1, no tone); idle = slow arm sway. Actions needing a
neck/jaw fall back to these; unknown actions are skipped, never crash. Autotomy visual is later (owner Q10).

Tests (S3): `godot/locomotion/test/run_tests.gd` gets `bodies.gd` radial fakes (fold 4/5/6):
- the rig contract holds (`problems` empty); no NaN over 600 steps at 0.2/0.8/1.5 m/s and in-place yaw spins;
- in `row`, the two neighbours of the lead arm are in phase and the rear arms do not plant during the power stroke;
- yaw sweep 0..2 pi: visual body rotation stays within +-pi/fold + 2 deg; lead arm switches at the sector midpoints;
- arm tips within 3 cm of a sloped ground (20 deg) in glide; footfall count per metre matches `row` frequency +-10 %;
- `footfall_diagram.gd` produces an arm-phase strip per mode (evidence).
- Guard: all existing locomotion tests and `test_actors.gd` unchanged.

## S4. Sim mapping (bilateral byte-identical)

- **No C change for wild radial creatures.** Steering reads the setup's legs: `stage_setup.gd` writes
  `"legs": min(fold, 8)` for radial spawns (brujula 5, corona 6). In `cp_steer_body` that gives grip x (.7 + .1 n)
  and climb `climb_base + climb_legs (n - 2)/6`, i.e. more grip/climb than a 4-legged default, which fits Adhesion
  (brujula.c2). The world log already records a non-zero `legs` line, so replay stays exact.
- Combat profile: wild = `CP_STAGE_SPECIES[]` row (S5b); genome-derived = per entry, replicas free (S1 rule).
- `radius_cm`: unchanged rule (disc only) in C, `profile.gd`, `profile.js`; species rows use radius 0 (60 cm) like the
  others, and `SPECIES_SCALE` fits the visual span.
- Player radial (`player_legs` from the genome at reset and after evolve) is S6.

Tests (S4): world goldens (`tests/golden/world-*.log` replays), `combat_golden`, `profile_expected.json`,
`test_world.c` unchanged; new `tests/test_world.c` case: same world with one wild at legs 5 vs 0 differs only in that
creature's `a_lat/climb` (sanity) and replays from its own log.

## S5. The three wild species, placement and evidence

### Bodies (`godot/game/data/{brujula,cuarteta,corona}.json`, `cpore.creature/5`, authored large then scaled)
| id | nodes (y, r), z = 0, oral -> aboral | plan | parts | skin | scale |
|---|---|---|---|---|---|
| brujula | (.03,.12) (.09,.30) (.15,.26) (.21,.08) | fold 5, star .3, arm {len 3.0, w .42, taper .85, curl .1, tip point, eye 1, act tubefeet} | `romo` t 0 size .6 (oral mouth); `pua` t .6 ang 0 size .5 len .3 and t .75 ang .63 len .25 (aboral spines, x5 each) | pat 2 spots, cA #8a5a32, cB #d8b27a, cC #cdb08a, wet .7, sk hydro | .6 (span ~1.3 m) |
| cuarteta | (.00,.30) (.08,.40) (.20,.36) (.30,.22) (.36,.06) | fold 4, star 0, gel .7, arm {len 2.6, w .35, taper .6, droop 1, frill .6, tip frill, act hydrostat} | `bulbo` t .05 ang .785 size .3 (rhopalia between arms, x4); `lure_lantern` t .1 ang 0 size .3 (cnidocyte glow, x4) | pat 2, cA #c9d6d2, cB #7fb3c4, cC #e8efe9, wet 1, sk hydro | .8 (bell .8 m, lore) |
| corona | (.02,.20) (.08,.38) (.14,.34) (.20,.10) | fold 6, star .65, arm {len .9, w .5, taper .3, curl .3, frill .8, tip frill, act cilia} | `romo` t 0 size .5; `antena` t .55 ang .52 size .6 len .4 (sensory cirri, x6) | pat 3 marbled, cA #5d5a4c, cB #8f8a6e, cC #b9b49a, wet .95 (mucus), sk hydro | .55 |

Earth palette, no red/purple (none is venomous; cuarteta cnidocytes are lore "bioluminescent", glow only).
`island.gd SPECIES_BODY/SPECIES_SCALE` gain the entries once they are C species (S5b); a lore test checks
`body_plan.arms == plan.fold` for every `game/data` genome whose name matches a lore id (`tools/lore` test).

### S5a: visual placement without touching C (all goldens identical)
New `godot/game/island/radial_fauna.gd` (like `flora_placement.gd`: deterministic from world seed + terrain data,
no C entity, local wander driven by `loco_radial` with a tiny seeded random walk around its home, LOD/culled at 80 m):
- **brujula** (F13/F21: intertidal shelf behind arches/islets): coastal cells with .15 <= ground <= 1.8 m, within
  30 m of a sea cell (ground < -.2), normal.y >= .9; pick the stretch nearest the islet/causeway if the terrain exposes
  one, else the first such stretch scanning bearings from the nest every 5 deg; 4 animals 3..6 m apart round a pool point.
- **cuarteta** (coastal shallows 0..15 m): 5 bells in sea cells with ground -6..-1 m, 15..60 m off the brujula shelf,
  bell top at y = -.4 (raise to -.15 if the sea shader hides it in evidence); drift with `jet` along a seeded loop.
  Stays ambient until swimming (P6, G64).
- **corona** (sunken lava tube, tidal): the terrain cave record with the lowest entrance floor, excluding the secrets
  cave (caves[0], Acechalunas); 2 animals 3..6 m inside the entrance on the floor; if no floor < 25 m, the cave nearest
  the coast; if no cave, none (logged).
### S5b: brujula and corona as C species (owner gate, Q2)
Following 292c52d: `CP_STAGE_SPECIES_COUNT`/`CP_SOC_SPECIES` 6 -> 8 (the `tested`/`liked` 64-bit mask is exactly full
at 8 x 8; a 9th species needs a wider mask, another reason cuarteta stays ambient), snapshot v8, rows in
`CP_STAGE_SPECIES`: Brujula `{2.0 speed, 14 sight, 10 roam, 0 hostile, TERRITORIAL, {0,0,0,0,2, hp 70, st 100, 2.0}, DIURNAL}`,
Corona `{1.4, 10, 8, 0, TIMID, {0,0,1,0,1, hp 50, st 100, 1.4}, CREPUSCULAR}` (speeds are game speeds, owner Q3);
chains from the lore chains (`CP_STAGE_CHAINS`), victim tables and signatures in `stage_parts.c`
(brujula `{"leg_sucker","leg_sucker","pua","romo","placa","bulbo"}` sig `leg_sucker`; corona `{"frill_fan","frill_fan","antena","romo","bulbo","ojo"}` sig `frill_fan`),
GDExtension/Python bindings, `stage_setup.gd` spawns them at the S5a spots with `legs` = fold (S5a hosts for these
two are then replaced by real `ActorHost`s). Requirement: world/combat golden hashes unchanged for worlds without
them (`make test`), new `tests/test_radial_species.c` for their rules. Lore skills (Radial Stance, Adhesion, Autotomy,
Chemical Sweep...) stay lore until the A24 sim rules are designed.

### Evidence (`docs/evidence/godot/radial/`, target `make godot-radial-evidence`, software GL, SwiftShader rule)
Per species: `<id>_{top,side,close,under}.jpg` (studio light), `<id>_gait_<mode>.png` (arm-phase strip),
`<id>_island.jpg` (shelf / sea / cave context, reusing `species_island_evidence.gd`), a 3 s frame strip of each gait,
and `bilateral_unchanged.txt` (hash fixture diff = empty). Vision critic (`tools/art/critic.py`) on the close shots.

## S6. Creator option (later slice)
- `studio.gd` body panel: "Simetría: Bilateral | Radial 4 | 5 | 6 | 8" (3, biradial, asymmetric hidden: wild only).
  Picking radial at lineage start is free; it opens a confirm dialog that converts the body: legs removed; mouths -> t 0;
  head parts (t > .8) -> t .9; other parts keep type/size, t remapped to .3..8, ang kept; nodes replaced by a 4-node
  disc profile. Back to bilateral = the reverse (re-adds 2 leg pairs from `default_part`).
- Node editor becomes a vertical profile editor; new "Brazos" panel (len, w, taper, curl, droop, frill, tip, eye) and
  the A24 actuation readout for the arm group (hydro set). `single` control becomes "En todos los brazos / Solo uno".
- `model.gd`: `set_plan(key, value)`, removes `plan` when bilateral (canonical form).
- Constraints: fold in {4,5,6,8}; no leg parts; regions torso only; arm len >= .5 for a mobile creature (else warn
  "Sin brazos se arrastra"), stats `vel` from arm length and actuation (visual readout only).
- Cost / sim: `cp_stage_apply` must reject a change of `plan.sym` or `plan.fold` (form change; today it compares only
  parts/profile, so add a plan compare); `plan.arm` shape is cosmetic. `cp_stage_edit` rejects a sym/fold change unless
  a radialisation event is pending (`CP_STAGE_ERR_NEEDS_RADIALISATION`; price owner Q8, proposal 150 DNA + one
  generation). Player legs: at reset `player_legs` = fold from the starting genome; after an evolve,
  `w->player.legs` = fold, stored in the form only when non-zero so bilateral hashes stay identical.
- Tests: studio round-trip (radial genome -> model -> genome byte-identical), web `node_check.js` accepts it,
  `cp_stage_apply` rejects fold change, `cp_stage_edit` rejects without the event, bilateral studio fixtures unchanged.

## S7. Test summary per slice
| Slice | New tests | Guards that must not move |
|---|---|---|
| S1 | `plan_cases.json` in C/GD creature/GD studio/JS, invalid-case list | genome parity, `make test` goldens |
| S2 | `test_radial.gd` (copies, rotation invariance, ground contact, UV symmetry, every part) | `bilateral_mesh_hashes.json`, `test_creature.gd`, `test_realism.gd` |
| S3 | locomotion radial fakes, lead-arm switching, terrain tips, footfall rate | existing loco tests, `test_actors.gd` |
| S4 | legs 5 vs 0 sanity + replay | world/combat goldens, `profile_expected.json` |
| S5 | placement determinism (same seed -> same spots; 3 seeds have >= 1 shelf and the corona fallback logs), lore fold test, S5b C species tests | goldens for worlds without the species |
| S6 | studio round trip, apply/edit rejections | studio fixtures |

Order: S1 -> S2 -> S3 -> S5a (evidence, owner look) -> S4 + S5b (after owner Q2/Q3) -> S6. S2 and S3 can be one
Sonnet run each; S1 is small (one run with the four validators).

## Open questions for the owner
1. Schema: optional `plan` in `/5` (recommended, zero migration) or a `/6` bump?
2. Brujula and corona as real C species (snapshot v8, 8 species fills the 64-bit preference mask), or visual-only fauna
   for now? Cuarteta stays ambient until swimming (P6): OK?
3. Game speeds: real sea stars crawl ~.003 m/s; proposed brujula 2.0 m/s fleeing (row) / .3 roaming, corona 1.4.
4. Tides: all three are tidal in the lore (F13 3.2 m). No tide in the sim: map to day/crepuscular now, or add a C tide
   clock later (brujula sealed at low tide, corona disc collapse at slack)?
5. Should arms count in the collision radius (player radial bodies), in C + both profile ports?
6. Rolling: not for corona (lore says crawling). Want a rolling "wheel" radial plan later as its own species?
7. Lore conflict: brujula's weakness "flank and deliver frontal impact" contradicts "no front"; reword?
8. Radialisation event: price and trigger (proposal 150 DNA + one generation, only at the nest).
9. `plan.gel` translucency for jellies: OK as a plan key, or a skin key?
10. Autotomy (drop/regrow an arm, brujula.c3): visual in S5b or with the sim rule?
11. Wild folds 3 and 7 allowed by the validator (3..8): OK, or only 4/5/6/8 everywhere?
