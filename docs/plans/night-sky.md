# Night sky plan (Fable, 2026-11-24)

Owner request: "design a realistic sky that is breathtaking and beautiful at clear nights, as well as marking the planets generated in that solar system (perhaps if you see them you can check their rings and stuff), as well as the moons. It should be really breathtaking."

This is a plan. Nothing here is built. Every number is a **starting value** unless it cites canon or a source. Owner questions with defaults are in §9.

Mock to judge the direction: `web/gaitlab/night_sky.html` (throwaway, one shader, invented constants, no seed or orbits). Captures: `docs/evidence/look/night-sky-mock/`.

## 1. What exists today

| Area | State | Where |
|---|---|---|
| Clock | C owns it: 12,000 ticks a day at 10 Hz = 20 real minutes (A27). Full night is 20:00–05:00 = 7.5 real minutes; dawn and dusk are 100 s each | `core/src/stage_secrets.c` `cp_stage_daylight` |
| World light | One node drives shader globals (`sun_dir`, `sky_*`, `ambient_color`, `moon_k`) from a keyed palette; night is a tuned blue-grey key (D-25, wl4) | `godot/game/island/day_night.gd` |
| Sky | Three-colour gradient, sun disc, clouds and cirrus. **No stars, no moon disc, no planets.** At night the "moon" is only the light direction: the sun's path mirrored | `godot/game/shaders/sky.gdshader` |
| Pipeline | Shaders write display colour and pre-invert ACES (`display_out`). Compatibility is the default renderer; Forward+ on discrete GPUs (A24). Glow is off in Compatibility | `look.gdshaderinc`, `render_choice.gd`, `environment.gd` |
| Camera | Can tilt past the horizon up to 60° (`look_pitch`), so the sky can already be on screen | `godot/game/player/chase_camera.gd` |
| Home system | **Not defined in code.** Canon fixes only: a quiet G1V star (F1), one large moon (F6), an inner cloudy super-Earth at 0.62 AU, "the evening star" (F12), orbit 1.02 AU, tilt 26.5° (F11), magnetic field 1.8× Earth (F14), rare flares with auroras (F10), dense 1.6 bar air with a milky horizon and copper sunsets (F4, F17). "No galactic position fixed" | `lore/worlds/primigenia.json` |
| Space stage | `cp7_star_seed(galaxy_seed, 0)` is the campaign seed, "so the arc's planet is literally in the sky". Stars have 2D positions around the map centre. No planets, moons or rings per system | `core/include/cpore/space.h`, `core/src/space.c` |
| Hooks already decided | Petrova line as a night-sky egg (A20); nocturnal creature and night bonus (G68, A82); tides "later" (A27) with a 3.2 m shelf tide and a causeway (F13); "glimpse of space" secret (A92); journal (G38); observe mode (G75) | `docs/DESIGN.md` |

Two findings to settle before building:

1. **The moon's canon numbers do not agree with each other.** By my calculation a 1.2-lunar-mass moon at 450,000 km around a 1.14 M⊕ planet has a sidereal month of about 32 Earth days (synodic about 35.5), not 29.7. A 29.7-day synodic month needs about 403,000 km (or about 424,000 km if the 29.7 are local 26 h days). The lore council should fix F6 one way or the other. It changes the moon's true angular size only from 0.47° to 0.52°.
2. **The strategic camera looks down.** In normal play the sky is rarely on screen. So the plan gives the sky three ways to be seen: a stargaze mode (§4), the world lit and reflected by it (moonlight, moon path on water, §3.3), and events that pull the eye up (§3.6).

## 2. The look

### 2.1 References
Real photographs first (LOOK §8 practice). The implementing agent collects them into `~/Desarrollo/cpore-refs/look/night/` with licence notes and records them in `docs/RESOURCES.md`. Never committed.

| Subject | Source to look in | What we take from it |
|---|---|---|
| Milky Way core over a dark site | ESO Paranal, La Silla, ALMA image archive (CC BY 4.0) | Band structure, dust lanes, warm core against cool arms |
| Sky above a sea of clouds | Roque de los Muchachos (La Palma), Teide, Mauna Kea | The summit view for the A92 secret: our island is the same kind of place |
| Airglow | ISS limb photos (NASA, public domain); Paranal green and red airglow | Green bands 10–20° above the horizon |
| Zodiacal light and gegenschein | ESO Paranal dusk images | The soft cone up the ecliptic after dusk |
| Moon with earthshine, total lunar eclipse | NASA, Wikimedia Commons | Thin crescent with the dark limb faintly lit; copper eclipse |
| Low-latitude aurora | Records and photos of red auroras during great storms (Carrington 1859, May 2024) | At our latitude an aurora is a rare red arc with green at its base |
| Ringed planet in a small telescope | Amateur eyepiece sketches; Galileo's 1610 "ears" of Saturn | What each eye tier resolves (§4.2) |
| Games | Breath of the Wild (Q29), Red Dead Redemption 2, Outer Wilds | Technique only: restraint in BotW and RDR2, and Outer Wilds' rule that every light in the sky is a real place |

### 2.2 What makes a night sky breathtaking
1. **Real darkness.** A blue-black zenith, a paler horizon. The mock's first version failed here: a grey sky makes every star cheap.
2. **Hierarchy.** A few brilliant stars, hundreds of medium ones, thousands at the edge of sight. Uniform brightness reads as noise. Real counts roughly triple per magnitude.
3. **Structure.** The galaxy band crosses the frame on a diagonal, with dark dust lanes and a bright core. It is a composition element, not a texture.
4. **Restrained colour.** Most stars near-white, a few orange or blue; warm galactic core, cool arms; a thin green airglow near the horizon.
5. **Foreground.** The volcano, the giant tree or a creature in silhouette gives scale. Still water doubles the sky.
6. **Slow motion.** The dome turns at 0.3° per second (one turn per 20-minute day). Stars twinkle low down; planets do not. A meteor now and then.
7. **It is earned.** The eyes adapt over a few seconds; the best sky is above the fog and clouds, on a moonless night.
8. **It is true.** The lights are a real system. They move from night to night, and later stages go there.

### 2.3 Keeping it inside the look canon
LOOK §1 says "naturalistic, slightly stylised". Allowed exaggerations, each a deliberate choice:

| Exaggeration | Value | Why |
|---|---|---|
| Moon drawn larger than true | 2× (about 1°) | Reads from the game camera; films do the same |
| Star colour saturation | about 1.5× true | True star colours are too pale to notice |
| Galaxy band after dark adaptation | Long-exposure photo look at about 60% strength | The eye sees the band grey; the photo look is the "breathtaking" one |
| Time | The whole calendar is compressed, like the day already is | Phases and planet motion must be visible within one session |

Not allowed (LOOK §7): lens flares, diffraction spikes, heavy bloom, painted nebula clip-art, outlines, a night bright enough to hide the stars. Low tier keeps the same composition with fewer stars (LOOK §6).

## 3. Content

### 3.1 The home system, generated in C
Proposal: a new pure module, `core/include/cpore/sky.h` and `core/src/sky.c`.

- `cp_sky_system(uint32_t seed, CpSkySystem *out)`: a pure function of the seed. Integer RNG on its own stream, integer outputs (milli-AU, milli-degrees, kilometres, ticks). Nothing is stored in the snapshot: seed and clock reproduce everything.
- `cp_sky_stars(seed, out, n)`: the star catalogue (direction, magnitude, colour index), brightest first.
- `cp_sky_at(system, clock, CpSkyNow *out)`: where everything is now.
- `CP_SKY_VERSION`, bumped when the bytes for a seed change (same rule as terrain, W13).
- The space stage calls the same function with `cp7_star_seed(galaxy_seed, i)` for every star, so the home system seen from the island is the system the ship later flies through.

**Canon is pinned, the seed fills the rest.** For the home system the generator takes F1, F2, F6, F11, F12 and F14 as fixed inputs. Rules for the rest, each with its real basis (A91: no stretch needed here):

| Slot | Rule | Basis |
|---|---|---|
| Star | G1V, 1.05 L☉; mass 1.05 M☉ (derived: it gives the canon 367-day year at 1.02 AU) | F1, F11, Kepler's third law |
| Hot inner planet | 60% chance, 0.25–0.40 AU, small and rocky | Common in Kepler multi-planet systems |
| Evening star | Pinned: cloudy super-Earth at 0.62 AU. Never more than 37.4° from the sun (asin(0.62/1.02)) | F12 |
| Home | Pinned: 1.02 AU, tilt 26.5°, e 0.02 | F2, F11 |
| Outer rocky world | 1.5–2.1× the previous orbit; small, rust or grey | Sol spacing ratios run 1.4–2.0 |
| Giants | First giant just past the snow line (2.7 AU × √L ≈ 2.8 AU), at 3.5–6 AU; second at 7–12 AU; an ice giant at 15–25 AU | Snow-line formation |
| Stability | Neighbours at least 8 mutual Hill radii apart; resample within a bounded loop | Standard stability criterion |
| **Showpiece rule** | In the home system one giant always has bright rings (tilt 15–28° to its orbit) and the other has four bright moons. In other systems bright rings are 25% | All four Sol giants have rings; one in four is bright |
| Moons | Home: the canon moon. Giants: 2–5 bright moons each | F6 |
| Small bodies | One or two periodic comets on eccentric orbits; one meteor stream per comet; a dust disc for the zodiacal light | — |
| Galaxy | The band's pole and the direction of the core come from the space map: the direction from star 0 to the map centre (`CP7_GW/2, CP7_GD/2`) | Q19: the win is reaching the core |
| Neighbour stars | Each space-stage star becomes a real star in the catalogue: direction from its map position (within ±15° of the band), magnitude from distance | `Cp7Star.x, y` |
| Pole star | One magnitude-2 star within 3° of the north celestial pole | Navigation (§5) |
| Observer | Latitude 27° N (starting value: a volcanic island with reefs and a snowy summit, like Hawai'i or the Canaries, which A86 cites) | A86 |

Brightness uses the standard reflected-light formula (radius, albedo, distances, phase angle), so the evening star is the brightest point, the giants are steady bright points, and the ice giant is below naked-eye sight: a hidden planet for good eyes (§4.4).

**Lore stays in step.** For the default seed, a tool renders the generated system into `lore/worlds/primigenia.json` as new facts (F28 onward) for the lore council to review and name. A C test then checks that the default seed still produces what the lore says.

**Determinism.** Anything gameplay reads (moon phase, moon altitude, night light, tide) uses integer or table maths, never libm `sin`/`cos`. Positions used only for drawing may be float; they are not hashed.

### 3.2 The compressed calendar
The day is already compressed (26 h canon → 20 min). The month and year need the same, or nobody will see a phase change: a session of 30 minutes has one or two nights.

| Cycle | Canon | Game (starting value) | Real time |
|---|---|---|---|
| Day | 26 h | 12,000 ticks | 20 min |
| Month | 29.7 d | 8 game days: the phase advances 45° per night | 2 h 40 min |
| Year | 339 local days | 48 game days (6 months) | 16 h |

Planet periods keep their true ratios to the year. The evening star then swings from one side of the sun to the other over about three weeks of game days, a few degrees per night.

**The first night is authored through the epoch, not scripted.** New moon falls just before a new game starts (08:00). At the first dusk a thin crescent with earthshine sets beside the evening star; then the sky is dark and the galactic core rises. The moon is full around night 4.

### 3.3 Moons
- **The moon.** Position from its orbit (inclined about 5° to the ecliptic). Phase from the true sun–moon angle. Dark limb lit by planet-shine (stronger than Earth's: the home planet is cloudy and bright). Maria and a few rayed craters from a small baked texture generated from the seed. Drawn at 2×.
- **A second, small moon (proposed, changes F6).** The owner said "the moons". One captured moonlet: tiny, irregular, fast, a few arcminutes across, crossing the sky in under a night. No tidal effect. An alien accent (LOOK §2) and a reward for good eyes.
- **Eclipses** come from the geometry (they need the moon near a node at full or new). The epoch guarantees one total lunar eclipse in the first eight nights: a copper moon, matching the copper sunsets of F17. A solar eclipse over the island is rarer; day creatures bed down and nocturnal ones wake.
- **Moonlight on the world.** Today's night key (wl4) becomes the **full moon, high** case, unchanged. The directional light follows the real moon (clamped to at least 12° elevation so shadows stay usable) and scales with the lit fraction. With no moon up there is no directional light, only a blue-grey ambient floor from starlight and airglow. Target: ground luminance at new moon about 0.55× full moon (real ratio is over 100:1 and unplayable). "Readable night" (LOOK §3) must pass at new moon.
- **On water.** A moon glitter path on the sea and lakes, computed in the water shader from the moon direction. This is what the top-down camera sees most.

### 3.4 Stars and the galaxy
- **Catalogue.** About 9,000 stars to magnitude 6.5 (the real naked-eye count for the whole sky), with counts roughly tripling per magnitude, denser toward the band. Dark adaptation in stargaze mode adds fainter ones (to about magnitude 7.5, high tier only).
- **Colour.** From a temperature distribution: mostly white and blue-white, some orange giants, a few red. Saturation 1.5×.
- **Size is brightness.** In a display-space pipeline with no glow, a brighter star is a larger, softer dot (as in the eye and in photographs), never a clipped pixel. Minimum core 1.5 px so nothing shimmers as the dome turns.
- **Twinkle.** Strong within 25° of the horizon, almost none overhead; stronger than on Earth because the air is 1.6 bar (F4). Planets never twinkle: that is how the player learns to spot them.
- **Extinction.** Stars fade and redden toward the "milky horizon" (F17).
- **The galaxy band.** A baked low-frequency panorama in galactic coordinates (band, bulge, dust lanes, a few emission nebulae), oriented by the seed. Stars are never baked into it.
- **Constellations.** The generator picks 8–12 figures among the bright stars by rule (compact groups, 4–8 stars). Three are fixed by purpose: **the Arrow** (points at the galactic core), **the pole figure** (holds the pole star), and **the Seed** (holds the makers' star, §4.4). Lines are never drawn on the sky in play; they appear in the journal's chart, and once as a faint trace when the player first finds a figure.

### 3.5 Planets
Bright steady points on the ecliptic, each with its own colour, moving against the stars from night to night. The evening star is only ever seen near dusk or dawn (F12). Rings, bands, phases and moons exist as data and are drawn when the player checks them (§4).

### 3.6 Events
| Event | Rule | Basis and tie-in |
|---|---|---|
| Sporadic meteors | About one every 15 s while stargazing | Real dark-sky rate, compressed with the night |
| **The shower** | A few nights a year, many meteors from one radiant | The stream of the comet. The radiant rises where the shard ray on the ground points: the crater impactor (F22) came from that stream's direction. A quiet clue for the meteor story (G65, W10) |
| Bolide | Once, on a seeded night: a fireball that lights the terrain for a second and leaves a glowing train | Spectacle; plausible |
| Comet | Visible for a stretch of nights near perihelion, tail pointing away from the sun | Panspermia: where seeds travel (G34) |
| Aurora | Only after a stellar flare (F10), a few nights a year: a red arc with a green base on the poleward horizon, brighter from the tundra and the summit | At 27° latitude with a 1.8× field (F14) auroras reach us only in great storms, and then they are red |
| Zodiacal light | After dusk and before dawn on moonless nights | The dust disc |
| Moon halo | A 22° ring around the moon on cirrus nights | Ice-crystal halo |
| Petrova wink | A faint thread from the set sun to the evening star (A20); names only in `lore/hailmary.*.json` | Already decided |

### 3.7 Clouds, fog and weather
- Clouds and cirrus already live in the sky shader; stars and planets fade behind them by sampling the same coverage function. Clouds are lit by the moon's phase, not a constant.
- Ground fog (F8: the start valley is a fog trap) hides the low sky. Climbing out of it is the reward; the summit sits above a sea of clouds.
- The first night is clear. After that, clear nights come from the weather seed; the rate is a starting value (about two in three).

## 4. Observing

### 4.1 Stargaze mode
- **Enter:** hold the look-up key while standing still, outdoors, out of a fight (key chosen from the free ones in the key legend). On the mouse-only UI, a quiet sign appears when the camera is tilted fully up.
- **Body:** the creature sits or settles and raises its head and eyes to the target (procedural, per A60's "observe" family; a simple head aim first).
- **Camera:** drops low behind the creature and tilts up 35–80°. The creature's silhouette stays at the bottom of the frame: it is your creature under its sky.
- **Dark adaptation:** over about 4 s the ground falls to silhouette, faint stars appear and the band gains contrast and colour. Looking at the moon or taking a hit resets it.
- **Checking a body:** the mouse moves a soft reticle. A body near it gets a quiet sign; hold to study it (about 1.5 s). A round lens inset opens (as in the mock) and shows the body at the creature's eye tier. First study writes a journal entry.
- **Risk:** time does not stop. Night predators can approach; a threat within range plays a sound cue and a hit ends the mode. (Owner question 6.)
- **Limits:** no stargazing under canopy, in caves or in fog; under cloud the mode works but shows what is there.

### 4.2 Eye tiers
The tier comes from the creature's best eye part and its level (parts are levelled with DNA, G37). Eye part ids today: `ojo`, `tallo`, `eye_stalk`, `eye_triad`; `eye_zoom` is in the roster (ECOLOGY, Palestrus) but not yet in `parts.json`.

| Tier | Eyes (starting mapping) | Zoom | Moon | Ringed giant | Other |
|---|---|---|---|---|---|
| 0 Naked | Any eye, level 1 | 1× | Phase, maria | A steady golden point | Planet colours, comet, the band |
| 1 Keen | Level 2, or stalk/triad eyes | 3× | Large craters; the moonlet as a moving dot | An oval with "ears" (what Galileo saw in 1610) and its two brightest moons | The other giant's four moons as dots |
| 2 Lens | Level 3, or `eye_zoom` | 10× | Crater rays | Rings clearly, bands, ring shadow | Phases of the evening star, double stars, nebula colour |
| 3 Telephoto | `eye_zoom` level 3 | 30× | The moonlet's shape | Ring gap, four moons, moon shadows | The hidden ice giant; comet jets |

- **Real basis:** raptors resolve 2–3× finer than humans; jumping spiders' main eyes are small Galilean telescopes; a few sharp-eyed people report seeing Jupiter's moons unaided. Tiers 0–2 are within that. **Tier 3 stretches it** and is marked as an A91 exception (owner question 8).
- **No eyes:** an eyeless lineage cannot stargaze. Its journal says "your kind has never seen the sky". It still gets moonlight, tides and events.

### 4.3 Journal: a Sky tab
A new tab in the field journal (G38; `godot/ui/journal_*.gd`):
- **Chart:** the dome as the creature has seen it so far, with found constellations drawn.
- **Bodies:** moon(s) and each planet, with three states (seen, disc resolved, details such as rings and moons). Unknown ones as "?".
- **Events:** eclipse, shower, comet, aurora, bolide, halo, each with the night it was seen.
- **Tonight:** moon phase, which planets are up, tide times.
Spanish and English. v1 gives journal completion only; no DNA (owner question 7).

### 4.4 Secrets
| Secret | How | Pays off |
|---|---|---|
| **Glimpse of space (A92)** | With the tun cyst and the radiotrophic organ, reach the highest summit at night. The camera lifts through the sea of clouds; the air thins (stars stop twinkling, the airglow becomes a thin line on a curved horizon); the band stands at full strength; one star in the Seed pulses once. Line: "the seed came from up there." | One sky parameter, `sky_altitude` (0 sea level, 1 space), does this and is reused for the space-stage transition (Q46) |
| The Arrow | Find the figure that points to the core | The core is the space-stage goal (Q19); the journal says only "everything turns around that light" |
| The makers' star | A star in the Seed that the second capsule came from (F22). Shard lines can hint at it | Space stage: it is a real, visitable system |
| The shower's radiant | Notice that the shard ray points at the radiant's rising point | Meteor story (G68) |
| Hidden planet | Tier 3 eyes find the ice giant | A named world waiting in space |
| Second sky | The galaxy mirrored in a still crater lake or the spring on a windless moonless night | A postcard place |
| Moonbow | A lunar rainbow in the waterfall's spray at full moon | Real (Victoria Falls, Cumberland Falls) |
| Glowing surf | Bioluminescent plankton on the reef coast, visible only on moonless nights | Real (dinoflagellate bays) |
| Catalogued stars | Stars studied in the creature stage arrive named on the galaxy map | Space stage |

## 5. Gameplay hooks
All through one C value, `night_light` (0–1000: moon lit fraction × altitude × cloud), plus the tide level. Each is a later, separate decision; the sky ships without them.

| Hook | Design | Basis |
|---|---|---|
| Sight at night | Detection radius scales with `night_light`. Dark nights favour ambushers; bright nights favour watchers | Prey reduce activity on bright nights (Prugh and Golden 2014 review) |
| Acechalunas | "Moon stalker": hunts on bright nights, hides at new moon; calm during a lunar eclipse (fits A82's night egg) | — |
| Nocturnal species | Roster night species (Sombrío, Nocturno, Sepiolis, Albino Panspermia) key their activity to `night_light` | ECOLOGY §1.7 |
| Tides | Two highs a day; range follows the moon's phase, up to 3.2 m at spring tides (F13). Spring low opens the causeway to the islet (a fourth route beside swimming, gliding and the ice bridge, A83/A85) and uncovers tide-pool food | F13, A27 "tides later" |
| Reef | Mass spawning on the nights after a full moon: a short food event on the Caribbean coast (A86) | Coral spawning follows the full moon |
| Star compass | After finding the pole figure, the minimap keeps a north tick and the nest bearing at night under a clear sky; lost under cloud | Indigo buntings learn the pole (Emlen 1967); dung beetles steer by the Milky Way (Dacke 2013) |
| Night migrants | Flying wildlife streams along the band on clear nights and lands under cloud (pairs with `world/ambient-fliers`) | Same |
| Band and Realm | The crater shrine (ARC-PLAN §2) gains a sky calendar; eclipses are morale events | Later stages |

## 6. Technical approach (Godot 4.7)

### 6.1 Layers
| Layer | Where | Notes |
|---|---|---|
| Gradient, extinction, airglow, zodiacal light, aurora | `sky.gdshader` | Analytic. Aurora and airglow use one or two noise taps |
| Galaxy band | `sky.gdshader`, one cubemap sample | Baked cube in galactic coordinates, 512² per face (1024² on high), rotated by a seed-derived matrix. Baked by a repo tool; recorded in RESOURCES.md |
| Moon disc and glow | `sky.gdshader` | Analytic sphere shading from the sun direction; a 256² albedo map; eclipse tint |
| Stars and naked-eye planets | One MultiMesh of camera-facing quads on a node that follows the camera | 9,000 high / 5,000 medium / 2,500 low. Additive, unshaded, depth-tested, no depth write. Per vertex: sidereal rotation, extinction, twinkle, cloud cover (same `cloud_cov` include), hidden behind the moon disc. Pixel-sized, so crisp at any zoom |
| Lens inset | A small SubViewport or a 2D shader in the UI layer | Planet disc, bands, phase, rings with shadow, moons at their orbital positions. Only alive while studying |
| Meteors, bolide | A few stretched quads | Pooled |
| Moon path on water | `water.gdshader` | Analytic specular lobe from `moon_dir` |
| Reflection cube pass | Unchanged | New layers skip `AT_CUBEMAP_PASS`, as clouds do today, except the moon glow |

Why a mesh for stars and not a hash grid in the sky shader (as the mock does): the catalogue must be real data (constellations, journal, space-stage stars), and a mesh costs almost nothing per pixel. The hash grid is the fallback if additive blending misbehaves in Compatibility (step NS2 checks this first).

### 6.2 Drive
`day_night.gd` stays the single source. New shader globals with today's values as defaults, so nothing changes at midday: `moon_dir`, `moon_phase`, `moon_light`, `sky_rot` (sidereal rotation), `galaxy_rot`, `night_adapt` (0–1), `sky_altitude` (0–1), `aurora_k`, `eclipse_k`. The node asks the C extension for `cp_sky_at` each frame with a fractional clock, so motion is smooth between 10 Hz ticks.

**The sun's path in v1 stays the art curve** (38° at noon). The true path at 27° N would put the noon sun near 63° and change every day shot the look scorecard has tuned. The mismatch is invisible: at sunset both set due west, and the night sky uses the true frame. Moving the sun to the true ephemeris is a later owner decision (question 9).

### 6.3 Tone and exposure
- Everything stays in the existing display-space convention (`display_out`); no new HDR path. Brightness is carried by size and softness (§3.4).
- On Forward+ with glow, only the moon and the top few bodies may cross the glow threshold. The scorecard's bloom check applies.
- Dark adaptation is a sky-only gain plus a small extra drop of ground exposure in stargaze mode. Normal night play keeps the wl4 exposure.
- Dither the gradient (the mock does) so dark skies do not band.

### 6.4 Budget
Frame targets stay as in `docs/plans/creature-loop.md` (high ≥ 60 fps, medium ≥ 45, low ≥ 30). Agents cannot measure the GPU, so:
- Software GL: night look-score shots cost at most 5% more frame time than the baseline (a relative number, never a GPU number).
- Owner's RTX: stargaze on high ≥ 60 fps; the sky adds at most 0.5 ms.
- Sky shader: at most one cubemap and two noise taps per pixel at night; no loops over stars.
- Memory: galaxy cube ≤ 6 MB compressed on high; star MultiMesh ≤ 1 MB.
- Load: catalogue and system generation ≤ 5 ms in C; no new shader variants per tier beyond a define.

### 6.5 Procedural or baked
| Thing | Choice |
|---|---|
| System, stars, orbits, constellations | Procedural in C from the seed |
| Galaxy panorama | Baked once by a tool (same image for every seed, oriented by the seed) |
| Moon albedo | Generated from the seed at load (256², cached with the world cache) |
| Planet discs and rings | Procedural shader from the system data |

## 7. Implementation steps
One agent each. Critical code (`core/`) goes to Sonnet 5.5 or Codex per AGENTS.md. Each brief must name its tracker test; proposed tests are in §8. Check `docs/STATUS.md` for free event and snapshot ids before NS5 and NS7.

| Step | Work | Agent | Gates |
|---|---|---|---|
| **NS0** Look pick | In the three.js look lab (A35), 4 variants of the night sky (star density, moon size, band strength, colour) from the mock, beside the reference board | Art-lane model, reviewed | Owner picks one in a picker page. No Godot code |
| **NS1** System in C | `sky.h`/`sky.c`: system, catalogue, ephemeris, calendar, `night_light`; lore export tool; extension binding | Sonnet or Codex | Canary hashes for 3 seeds; same bytes on gcc and clang at -O0 and -O2; canon checks (evening star ≤ 37.4° from the sun, month and year lengths, pinned bodies); phase equals sun–moon angle within 1°; default seed equals the lore JSON; generation ≤ 5 ms; C suite rc 0 |
| **NS2** Stars and galaxy | Star mesh, galaxy cube and its bake tool, night layers in the sky shader (extinction, airglow, zodiacal light), `night_adapt` | Sonnet | First a 1-day spike: additive stars correct in Compatibility under software GL. Then: 6 new night shots in the scorecard (§8); two runs at a forced clock are pixel-identical; day shots unchanged (compare to baseline: zero diff at dawn, midday, dusk); frame-time ratio ≤ 1.05 |
| **NS3** Moon, moonlight, planets | Moon disc, phase, planet-shine, eclipse; light direction and energy from the ephemeris; planets as points; moon path on water | Sonnet | Night scorecard checks at full moon equal to wl4 or better; new-moon shots pass `flat_light_night` and creature readability; phase sheet of 8 nights matches the C phase; godot-test, ui-test, play-test green |
| **NS4** Stargaze and eyes | Mode, camera, dark adaptation, reticle, study, lens inset with the 4 tiers | Sonnet | Tier sheet capture (4 tiers × ringed giant, moon, evening star) matches §4.2; enter and exit ≤ 250 ms UI motion (Emil rules); a hit ends the mode in the play test; ui-test green |
| **NS5** Journal Sky tab | Chart, bodies, events, tonight; ES and EN | Sonnet | UI suite; captures at 1280×720 and 1024×600; overflow handled |
| **NS6** Events and weather | Meteors, shower, bolide, comet, aurora, halo; clear-night schedule; clouds lit by phase | Sonnet | Each event reproducible at a forced clock; event shots in the scorecard; bloom check passes on the bolide frame |
| **NS7** Hooks in C | `night_light` → detection; tides and the causeway (after the A86 island); Acechalunas | Sonnet or Codex, Opus-planned | Separate brief and owner decisions; loop scorecard not worse |
| **NS8** Secrets | Glimpse of space (needs the A87 organs), the Arrow, moonbow, glowing surf, second sky | Sonnet | One capture per secret; secrets test |

Order: NS0 and NS1 can start now and touch nothing in flight. NS2 onward waits for the creature-loop focus (one focus at a time, and the WIP limit of 3 waiting branches).

## 8. How it is judged
New scorecard shots (stargaze cameras, software GL, medium and low): moonless with the core up; full moon; crescent with the evening star at dusk; horizon with airglow; overcast; summit above clouds.

| Check | Target (starting value) | Guards |
|---|---|---|
| Zenith sky luminance, moonless | ≤ 0.06 of display range | Real darkness |
| Detected star count, adapted | Within 20% of the catalogue count above the limiting magnitude | Hierarchy, no lost stars |
| Brightness histogram of stars | Slope within 25% of the catalogue's | Not uniform noise |
| Band-to-sky contrast | ≥ 1.6 moonless and adapted; ≤ 1.15 at full moon | The moon really washes the sky |
| Clipped pixels | < 0.2% of the frame | Bloom (LOOK §7) |
| Star saturation p95 | ≤ 0.6 | Oversaturation |
| Flicker over a 30-frame burst | No star below 1.5 px; no single-pixel pops | Shimmer |
| Tier parity | Low shows the same composition with fewer stars | LOOK §6 |
| Blind sheet | The owner ranks our shots among the reference photos | "Breathtaking" is the owner's call |

Proposed tracker tests: **N1** "The clear night sky is breathtaking" (owner, blind sheet); **N2** "I can find and check the ringed planet, and better eyes show more"; **N3** "The moon changes from night to night and lights the world"; **N4** "Same seed, same sky" (automatic).

## 9. Owner questions, with recommended defaults

1. **Compressed calendar.** Month of 8 game days (2 h 40 min), year of 48 (16 h)? *Default: yes.*
2. **A second, small moon.** Add a fast captured moonlet (changes canon F6; no effect on tides)? *Default: yes, one.*
3. **Moon size on screen.** True (0.5°), 1.5×, 2× or 3×? *Default: 2×.*
4. **How photographic.** Eye-true grey band always, or the colourful long-exposure look? *Default: eye-true in normal play, the photo look at about 60% after dark adaptation in stargaze mode.*
5. **One home system or one per seed.** *Default: canon bodies are the same for every seed; the seed fills the rest; the shipping default seed is the canonical system, and the owner or the lore council names its planets.*
6. **Stargazing is risky.** Time runs and predators can come? *Default: yes, with a sound cue; a hit ends it.*
7. **Rewards.** Journal completion only, or DNA for first discoveries (shards give 5, A27)? *Default: journal only in v1.*
8. **Telephoto eyes.** Allow tier 3 (30×) on a normal eye organ as a small A91 stretch, or reserve it for a legendary organ? *Default: allow, on `eye_zoom` level 3.*
9. **Latitude and sun path.** Island at 27° N; keep the current art sun arc in v1 and decide the true path later? *Default: yes.*
10. **Aurora.** Rare, only after flares (canon F10), or regular over the tundra? *Default: rare.*
11. **Canon fix for the moon.** Month 29.7 d and distance 450,000 km disagree (§1). Keep the month and move the moon to about 403,000 km? *Default: yes, via the lore council.*
12. **When.** Start NS0 (look pick) and NS1 (C system) now, the rest after loop tuning? *Default: yes.*
