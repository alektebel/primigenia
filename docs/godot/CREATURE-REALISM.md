# Creature realism pilot

Branch `creature/realism-pilot`. Visual only: the C sim, the goldens and every gameplay number are untouched. Everything is
generated in real time from the genome (cpore.creature/4): procedural body, 46 fixed part GLBs, shaders. No hand-made
per-creature asset and no external texture (so nothing to credit in `godot/creature/assets/CREDITS.md`). The studio uses the
same `Creature` class, so it shows the same look live while editing.

**Owner rule: the player's colours are authoritative.** The realism layer never shifts hue. Countershading only mixes towards
the player's belly colour and changes value; patterns use the player's pattern colour; detail, roughness, wetness, subsurface and
keratin sit on top. Switch the whole layer off with `CPORE_REALISM=0` (before/after, escape hatch).

## 1. Renderer tier (S1)
Default stays GL Compatibility (`project.godot`, all tests). Forward+ is opt-in: `make godot-play-hq` (`--rendering-method
forward_plus --rendering-driver vulkan`). `godot/creature/render_tier.gd` is called from the shared Environment, sun and viewport
factories (`game/island/environment.gd`, `island.gd`, `studio/studio_env.gd`) and is a no-op in Compatibility. HQ turns on SSAO,
SSIL, 4-split PSSM with an 8k atlas and PCSS-like penumbra (`light_angular_distance`), TAA + FXAA instead of MSAA, and the
skin shader writes `SSS_STRENGTH` (real screen-space scatter, Forward+ only; Compatibility uses the wrap-light fake). SDFGI
(`CPORE_HQ_SDFGI=1`) and volumetric fog (`CPORE_HQ_FOG=1`) are opt-in because they cost on a big island and could not be measured.
**Not verified in Forward+:** this machine has no software Vulkan (no lavapipe; installing it was refused), so
`--rendering-method forward_plus` under xvfb falls back to OpenGL 3 ("drivers seem not to support the required Vulkan
version"). Compatibility verified (tests + renders). Shaders use only builtins common to both renderers (`SSS_STRENGTH` sits
under `#ifdef RENDERER_FORWARD_PLUS`); no incompatibility known, but unconfirmed. Owner: run `make godot-play-hq` on the RTX.

## 2. Skin (S2) - `shaders/skin_common.gdshaderinc`, `shaders/keratin.gdshader`
- Object-space detail (CUSTOM0 = body-rest position), no UV needed for parts: Worley scales as plates, pores, wrinkles
  (amount per actuation class). Frequency scales with `body_r / 0.7`, so a mite and a giant have proportionate scales; the
  detail fades by screen derivative before it aliases.
- Roughness: dry back, damper belly, wet snout/mouth (radius around the head tip), clearcoat follows wetness.
- Fake subsurface: wrap light at the terminator tinted blood-red, strength from tube thickness (UV2 = ring radius on the body,
  default for parts). Real SSS in Forward+.
- Keratin (claws, teeth, horns, spines, beaks, plates, dark chitin): dark stained root to pale translucent tip, growth ridges
  and fibres, translucent glow. The along-axis comes from `CreatureGeo.compute_along()` (power iteration, no asset). Replaces
  the flat white spikes. Applies to the GLB parts through the region -> material table.
- Eyes: darker iris with less glow, cream sclera, sharp clearcoat glint.

## 3. Colour from the genome (S3)
- `creature_turing.gd`: tileable 48x48 activator-inhibitor field (Young 1984: short-range activation, long-range inhibition,
  16 iterations of wrapped box blurs). Stripes use an elongated inhibitor (rings around the body), spots a drift term, blotches
  larger radii. Deterministic per seed, cached per (seed, kind). Measured 15 ms cold under load (under the 50 ms budget).
  This is a CPU discrete model, not a GPU PDE solver.
- Seed = hash of the creature name, so editing parts or colours never re-rolls the pattern.
- Body: tube UVs in metres (arc along spine, arc from the dorsal midline mirrored, so the pattern is bilaterally symmetric);
  parts and legs: triplanar in object space. Wavelength = body radius x kind factor x creator scale, so patterns scale with the animal.
- Creator options, optional genome keys under `skin` (absent = default; validated by both parsers; the web genome.js does not
  know them): `cs` countershading 0..1 (default .5), `ps` pattern scale .5..2, `pc` pattern contrast 0..1, `ros` rosettes
  0/1, `act` actuation choice. Existing genomes keep their colours.
- Honest warning colours: `CreatureBio.derive` computes `toxic` from venom parts (aguijon, sac_spitter, tail_spike) and `diet`
  from the mouth class. Today they are informational (readout / future sim); colours are not touched. Proposed wild-creature
  rule for the generator that makes AI genomes (not changed here): earth palette, green ancestry, red/purple only if toxic.
  The canon file F25 was not in this tree, owner wording used.

## 4. Skeleton per body, actuation per limb (A24, round 2) - `creature_bio.gd`
The body has a skeleton class, derived from the parts: **exo** (2+ plates, or plate + pincers/mandibles, or 8+ thin legs),
**hydro** (no legs), else **endo**. Each limb part (legs, `arm_*`, `tail_*`, `tongue_spring`, `trompa`/`snout_trumpet`,
`excavadora`) has its own actuation among what the skeleton allows, derived from the part's form. The creator shows, for the body and
for every group of identical limbs, "Actuacion: <class> - <why>", an OptionButton only where the form is ambiguous (more than one
candidate), and "N tipos de actuacion: +N-1 metabolismo" (informational only; the cost is a later sim rule). Stored per limb as the
optional part key `act`, body choice as `skin.sk` (auto | endo | exo | hydro); absent keys are derived, so old genomes load unchanged.

| Skeleton | Allowed limb actuations |
|---|---|
| endo | muscle, tendon (elastic), spring (latch), hydrostat |
| exo | muscle (in exo), hydraulic, spring |
| hydro | peristaltic, hydrostat, tube feet, cilia |

Derivation of a leg: hydro -> tube feet; `foot_spring` -> spring; exo with 8+ legs -> hydraulic; endo with long thin legs
(w/L < .075 and L > 2.4 body radii) -> elastic tendon; exo -> muscle in exo; else muscle. Arms: `arm_smasher` -> spring, `arm_grasper` ->
muscle (hydro: hydrostat). Tail: muscle (hydro: peristaltic). Tongue: hydrostat or spring. Trunk: hydrostat (exo: hydraulic).

Visuals (`skin_common.gdshaderinc`, per leg segment material, `leg_mode`; verified in `limb_*_legs_limbs.jpg`):
muscle = belly swelling with knee flexion; elastic tendon = thin sinewy limb with a pale raised cord down the back; spring-latch =
coiled flared joint with a faint ember glow of stored energy and a thin rod; hydrostat = smooth boneless taper with a slow wave;
hydraulic = slim rigid tube with knuckles; muscle in exo = three rigid sclerites with deep dark grooves (the body rings are
deeper too); tube feet = stubby taper with sucker dots (code only: only reachable on legged hydrostatic bodies, not shown). Arms, tails, tongue
and trunk get the readout and the stored choice but no per-limb shader yet (their meshes have no common axis); deferred.
The previous per-creature class survives only as the body shader class (`bio["actuation"]`: muscle / exo / hydrostatic).

Real actuation systems and status (gameplay is a later C-sim design, see COMBAT-MOVES.md section 7 and DESIGN.md A24):

| System | Real examples | Visual | Note |
|---|---|---|---|
| muscle + endoskeleton | vertebrates | now | |
| muscle + exoskeleton | insects, crabs | now (grooves) | |
| hydraulic (blood pressure) | spiders, jumping spiders | now (slim tubes); curl on death deferred | |
| hydrostatic skeleton | worms, anemones | now (body wave) | |
| muscular hydrostat | octopus arm, tongue, trunk | now on legs only, readout elsewhere | |
| spring-latch (resilin) | flea, click beetle, mantis shrimp | now (coiled joint) | |
| elastic tendons | kangaroo, ostrich, cheetah | now (cord) | |
| water-vascular tube feet | starfish, urchins | code only | |
| jet propulsion | squid, scallop | later | |
| cilia | ctenophores | readout only | |
| turgor / snap-buckling | Venus flytrap, Mimosa | later | |

## 4b. Single parts, eyes, renderer choice
- **Single parts**: part key `single` (-1 left, 1 right, absent = pair). Creator: "Pareja / Solo derecha / Solo izquierda" on any mirrored
  non-leg part. Visual only now; which side matters later in the sim. Legs stay paired (walking needs them).
- **Eyes** (`_eyeball` in `creature_parts.gd`, `shaders/eye_iris.gdshader`): veined cream sclera, a glossy transparent cornea dome
  bulging over a radial iris (fibres, collarette, limbal ring, tint from the creature seed), upper and lower lids of skin, pupil drawn in
  the shader: vertical slit for carnivores and night hunters (big eyes, lure), horizontal bar for grazers, round otherwise; part key `pupil`
  (auto | round | slit | bar) overrides it in the creator. Used by `ojo`, `tallo`, `eye_triad`; the `eye_stalk` GLB gets the radial iris but keeps its own pupil mesh.
- **Renderer choice** (`game/render_choice.gd`, called by the Game autoload): auto-Forward+ on discrete GPUs, Compatibility elsewhere, setting
  `[game] renderer = auto | forward_plus | compatibility` in `user://settings.cfg` (also env `CPORE_RENDERER`), `make godot-play-hq` unchanged. The
  renderer cannot switch in a running Godot, so the game relaunches itself once with `--rendering-method forward_plus` and quits; the
  child never relaunches (`--cpore-relaunched`), and where Vulkan is absent Godot's own OpenGL 3 fallback starts it, so nothing
  crashes. It never relaunches in headless, script, import or explicit-method runs, nor on software rasterisers. Detection: adapter type
  DISCRETE_GPU or an NVIDIA / GeForce / RTX / GTX / Radeon RX / Radeon PRO / Arc name from the running GL context; a hybrid laptop whose GL
  context is the iGPU stays Compatibility until forced. No UI row was added (the settings screen is `godot/ui`, owned by another branch):
  the key exists and the screen only needs to write it. Unverified on a GPU here.

## 5. Secondary motion (S5)
Breathing only (torso radius pulse in the vertex shader). Hydraulic leg curl on death, footfall jiggle and tail inertia are not done (need locomotion / IK hooks); deferred.

## 6. Evidence and numbers (S6)
`docs/evidence/godot/creature-realism/`: `<id>_<chase|close|side>_<before|after>.jpg` for hero, giant (heavy quadruped),
spider (hydraulic), beetle (exo), slug (hydrostatic); `studio_*_{before,after}.jpg`: studio with a player-painted creature
(blue/yellow stripes survive), paint panel with the new controls, rosettes + countershading, 6 added legs with the
actuation readout and choice. Not captured: Forward+ (no Vulkan here). Regenerate: `make godot-creature-realism-shots TAG=after`,
`creature/tools/studio_live.gd`, `creature/tools/realism_bench.gd`.

Numbers (software GL, machine loaded, noisy; ratios only). Build per creature, warm (pattern cached), before -> after:
hero 21.7 -> 23.6 ms, giant 19.4 -> 25.2, spider 56.5 -> 48.8 (noise), beetle 24.2 -> 23.8. Cold (first build of a seed, adds the
Turing field and shader compile): hero 75 -> 109 ms, giant 45 -> 110. Software frame time +5..15 % (hero 77 -> 82 ms, giant 64 -> 75,
spider 126 -> 132, beetle 106 -> 115). Studio edit of pattern scale or colours: texture is cached per seed, so only the uniform
changes; a rebuild per edit costs the warm build.

## 7. Not done / known
Forward+ unverified; no `exo` grooves visible under big plates; curl-on-death for hydraulic legs; jiggle/tail inertia; eye shape is
still the original sphere; web studio ignores the new skin keys; muscle bulge normals are not recomputed (small displacement).
