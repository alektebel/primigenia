# Diegetic UI: marks on the ground, signs in the air

Status: **design, 2026-11-19; implemented on branch `ui/diegetic-redesign`, see section 13** (what exists is described in [UI.md](UI.md); the interaction model of G75 and the
"select first" addendum of `docs/P4.md` stay). Implementation plan: [PLAN-ui-diegetic.md](PLAN-ui-diegetic.md).
Mockups: [`ui-mockups/`](ui-mockups/) (static HTML/SVG, rendered to `ui-mockups/render/*.jpg`).

The owner's verdict on the current HUD: "too AI-ish" (dark rounded panels, text everywhere, a permanent key legend
and ability bar). The new direction is **minimal and diegetic**: almost no HUD; the world tells you (rings on the
ground, the creature's body, light, sound), and a sign appears only while it is needed.

| Mockup | State |
|---|---|
| `render/01-idle.jpg` | no selection: four quiet corner signs and the white circle of the last click |
| `render/02-selected-radial.jpg` | a wild creature selected: ground ring, field note, mode ring (pointer on Befriend) |
| `render/02b-selected-radial-es.jpg` | the same in Spanish with every name shown (onboarding) and one onboarding hint |
| `render/03-befriend-rhythm.jpg` | befriending: trust ring, beat ring, skill petals 1-4, gift, dawn fog |
| `render/04-combat.jpg` | fight: toothed health ring, wind-up disc, move petals with cooldown, guard and dodge at the player's feet |
| `render/05-carcass-eat.jpg` | carcass: ring cut into bites, eat petal, hunger gain, DNA mote |
| `render/06-low-health.jpg` | low health: ember health line, closing edges, threat ring on the hunter |
| `render/07-menu.jpg` | menu open from the seed, with Settings |
| `render/08-loadout.jpg` | loadout at the nest (key L) |
| `render/glyphs.jpg` | the glyph sheet (`ui-mockups/glyphs/*.svg`) |

The scenes in the mockups are placeholders (flat hills, side-view creatures). Only the marks are the design.
All sizes below are **design units (u)** on a 1280 x 720 reference; on screen 1 u = `viewport_height / 720 x ui_scale` pixels.

---

## 1. Principles

1. **The world speaks first.** Before drawing a sign, ask whether the ground, the body, the light or a sound can say
   it. A number is the last resort.
2. **Nothing without a reason to be there.** Each mark has a trigger that shows it and a rule that hides it. Only four
   signs are always present (menu seed, vitals, DNA and species, compass) and they rest at low contrast.
3. **Lines, not boxes.** No panels, no rounded rectangles, no drop-shadow cards. Everything is a thin line, a small
   glyph or a short line of text sitting directly on the picture, with a soft dark halo for legibility.
4. **Shape carries the meaning; colour only repeats it.** Social is a smooth line, aggressive is a toothed line,
   observing is a dotted line, intimidating is a double line. The same four shapes are used in the mode ring, on the
   ground ring and on the compass. A player who cannot tell red from green loses nothing.
5. **Marks belong to someone.** Signs about the other creature sit on or around it; signs about your creature sit at
   your feet; signs about the journey (DNA, compass) sit at the top edge. Nothing floats in the middle of the screen.
6. **Calm motion.** Marks ease in and out, never pop or bounce. One thing moves at a time. Pulsing is reserved for
   danger (low health, an incoming hit) and for the beat of a befriending.
7. **Text is for names and for the menu.** In play, text is a species name, a key, or one short line that goes away.
   Sentences live in the journal and the menu. Every string exists in Spanish and English.

## 2. Palette

The planet has thick air: fog-trap mornings, a milky horizon, copper sunsets (the island lore canon, facts
F3, F8, F17). The marks are bone-white lines, like chalk or frost on the ground, with one warm metal accent.

| Token | Hex | Used for |
|---|---|---|
| `BONE` | `#F4EDE0` | every neutral mark: move marker, selection ring, text, health, keys |
| `FOG` | `#C9D3D4` | secondary text (key names, sub-lines), disabled marks at 40 % |
| `INK` | `#0E1715` | the halo behind marks and the smoke disc behind a petal; never a panel |
| `LICHEN` | `#86D9B0` | social: befriend arc, trust, "liked" dot |
| `EMBER` | `#F0704A` | aggressive: attack arc, hostile and health-of-enemy rings, low health |
| `OCHRE` | `#EBCB7A` | observe, hunger, eating |
| `DUSK` | `#CDBDF2` | intimidate |
| `COPPER` | `#E09A5F` | DNA, progress, the selection tick in menus; the one accent |
| `MIST` | `#9CC4DD` | stamina, guard and dodge marks |

Rules:

- `LICHEN` and `EMBER` differ strongly in lightness (relative luminance about 0.58 against 0.30) and in the blue
  channel, so they stay apart for red-green colour blindness; shape still does the real work (principle 4).
- Resting opacity of the four permanent signs: 0.74. Active: 1.0. Disabled: 0.40. Tracks (the empty part of a line): 0.24.
- **Halo**: every mark and text is drawn over a blurred copy of itself in `INK` at 0.70 (blur radius 2.6 u). This is
  what keeps bone-white readable on dawn fog (see `03-befriend-rhythm.jpg`). In Godot: font outline (size 4,
  `INK` at 0.55) for text, a wider dark under-stroke for drawn lines, an outer dark edge in the ground shader.
- Veil (menu, loadout only): a full-screen `#18221F` at 0.62 (menu) or 0.42 (loadout). It is the fog closing in, not a
  panel: no border, no rounded shape.
- Move roles (`Palette.ROLE_COLORS`) are no longer shown as six border colours. A role is an **outline shape**
  (section 7.14). The role colours stay in `palette.gd` for the journal only.
- Deleted tokens: `PANEL`, `PANEL_SOLID`, `PANEL_HOVER`, `PANEL_ACTIVE`, `BORDER`, `BORDER_BTN`, `BACKDROP`,
  `Palette.box()`, the Button and slider style boxes.

## 3. Typography

Two faces from one family, both SIL Open Font License 1.1, by Huerta Tipográfica:

- **Alegreya Sans** (Regular 400, Medium 500): keys, numbers, menu items, hints.
  Source: <https://github.com/huertatipografica/Alegreya-Sans> or Google Fonts "Alegreya Sans".
- **Alegreya Italic** (variable weight; use 400): species names, section titles in the menu, the rare "moment" line.
  Source: <https://github.com/huertatipografica/Alegreya> or Google Fonts "Alegreya".

The files used by the mockups, with both licences, are in `docs/godot/ui-mockups/fonts/` (copy to `godot/ui/fonts/`).
A humanist sans with a calligraphic italic reads like a naturalist's field notes, which is the voice of the journal.
Both cover Spanish (á é í ó ú ñ ü ¿ ¡).

| Role | Face | Size (u) | Notes |
|---|---|---|---|
| Species name (field note) | Alegreya Italic 400 | 23 | bone, no caps change |
| Moment line ("Learned: Pounce") | Alegreya Italic 400 | 28 | centred, lower third |
| Menu item | Alegreya Sans 400, selected 500 | 22 | |
| Mode name on the ring | Alegreya Sans 500 | 17 | |
| Setting row, hint line | Alegreya Sans 400 | 16.5 | |
| Number (DNA) | Alegreya Sans 500 | 19 | lining figures |
| Key under a petal | Alegreya Sans 500 | 14.5 | |
| Key name beside a label, sub-line | Alegreya Sans 400 | 13.5 | `FOG`, letter spacing 0.6 |

Minimum text size on screen: 13 px after scaling (raise `ui_scale` rather than shrink). No all-caps, no bold above 500.

## 4. Glyphs

One vector language, drawn by us; no emoji, no icon pack, no letters used as icons.

- 24 x 24 unit box, **one stroke weight** (1.7 at 24 u), round caps and joins, no fill except a solid dot for an "eye"
  or a source (the dot in `observe`, `sing`, `seed`) and a 30 % fill on `attack`.
- Round shapes for peaceful things (befriend, charm, fruit, nest), points and straight strokes for force (attack,
  charge, quill, display).
- A glyph must read at 17 u (the smallest use). If it does not, simplify it; do not add detail.
- Sources: `docs/godot/ui-mockups/kit.js` (table `G`), exported one SVG per glyph to `ui-mockups/glyphs/` by
  `node export-glyphs.js`. Sheet: `render/glyphs.jpg`.

| Group | Glyphs |
|---|---|
| Modes | `befriend` (two rings overlapping), `attack` (a fang), `observe` (an eye), `intimidate` (a raised crest), `eat` (a bitten round) |
| Attack moves | `bite`, `charge`, `spit`, `tail`, `pounce`, `quill`, `stomp` |
| Social skills | `sing`, `dance`, `charm`, `pose`, `roar`, `display` |
| Defence | `guard`, `dodgeL`, `dodgeR` |
| Items and diet | `fruit`, `leaf` (plant, herbivore), `fang` (meat, carnivore), `bone` |
| Permanent signs | `seed` (menu), `health`, `hunger`, `stamina`, `dna`, `nest` |
| Menu and journal | `journal`, `tree` (family tree) |

A new move needs a new glyph in the same language before it ships (add it to `kit.js`, export, check the sheet).
`stomp` and `hunger` are the weakest of this first pass and are the first to redraw.

The four line styles (principle 4), used for arcs on the mode ring and for ground rings:

| Style | Meaning | Drawing |
|---|---|---|
| smooth | social, neutral | one line, round caps |
| teeth | aggressive, hostile | one line with small triangles pointing outwards, one every 18 to 27 degrees |
| dots | observing | dots along the arc, one every 10 degrees |
| double | intimidating | the line plus a thinner one 5 to 6 u outside it |
| cut | a count (bites left) | N equal arcs with gaps of 14 degrees |

## 5. Motion

| Name | Time | Curve | Used for |
|---|---|---|---|
| `IN` | 0.18 s | ease-out cubic | a mark appears (alpha 0 to 1, scale 1.08 to 1) |
| `OUT` | 0.35 s | ease-in cubic | a mark leaves (alpha to 0, scale to 1.04) |
| `SWAP` | 0.16 s | ease-in-out | hover, focus, a petal press, a line thickening |
| `GROW` | 0.6 s | ease-out cubic | a value changes: an arc or a line grows or shrinks to its new length |
| `REST` | 2.5 s after the last change, then 0.8 s | linear | a permanent sign goes back to resting opacity |
| `MOTE` | 0.7 s | ease-in-out, on a curved path | a mote of DNA or a journal note flies to its sign |
| `BEAT` | the C beat (12 ticks = 1.2 s) | linear | the beat ring closing in |
| `PULSE` | 1.2 s period | sine | low health only (opacity 0.6 to 1) |
| `BREATH` | 2.4 s period | sine, +-5 % alpha | the move marker while you travel |

Rules: never animate position and colour of the same mark at the same time; no overshoot, no bounce, no spin.
With **Less motion** on: `IN`/`OUT`/`SWAP` become 0.08 s fades, `GROW` is instant, `PULSE` and `BREATH` are replaced by a
steady thicker line, motes are replaced by a 0.3 s brightening of the target sign, the beat ring stays (it is gameplay).

Sound is half of each mark (principle 1): every `IN` of a world mark has a soft sound on the SFX bus (click on ground:
a low tap; select: a short breath; beat in window: a wooden tick; trust gained: a rising two-note; DNA mote arriving: a
small chime; low health: a slow heartbeat under a low-pass on Music and Ambience). Low calls carry on this planet (F4):
keep UI sounds low and short, under 300 ms, no high bleeps.

## 6. What is on screen, by state

`o` resting (0.74), `O` bright, `-` absent.

| Element | No selection | Selected wild (choosing) | Befriending | Fight | Carcass | Low health | Menu |
|---|---|---|---|---|---|---|---|
| Menu seed (bottom-left) | o | o | o | o | o | o | O |
| Health, hunger (bottom-left) | o | o | o | O health | O hunger | O health, pulsing | o |
| Stamina line | - (shown only below full) | - | - | O | - | O | - |
| DNA + species pips (top-left) | o | o | o | o | O on gain | o | o |
| Compass (top centre) | o | O (target mark) | o | o | o | o | o |
| Move marker | on click | - | - | - | - | on click | - |
| Ground ring on the target | - | bone | lichen = trust | ember teeth = health | ochre, cut = bites | - | - |
| Mode ring | - | O | - (Tab reopens) | - (Tab reopens) | O until chosen | - | - |
| Petals 1-4 | - | - | O | O | O (one) | - | - |
| Guard and dodge at your feet | - | - | - | O | - | only in a fight | - |
| Field note (name) | - | O | name only | name only | O | - | - |
| Threat ring on a hunter | if hunted | if hunted | if hunted | on other attackers | if hunted | O | - |
| Key legend | F1 or onboarding | F1 or onboarding | F1 | F1 | F1 | F1 | "Keys" |

Layout (1280 x 720): seed centre (40, 680); vitals x 80 to 204, y 662 / 674 / 686; DNA glyph centre (40, 38);
compass x 500 to 780, y 34; hint lines centred at y 676; menu list x 64, last item y 636. Safe margin 24 u on every edge.

## 7. Elements

Each element: **shows** (trigger), **where**, **looks**, **animates**, **hides**.

### 7.1 Move marker (the white circle)

- **Shows**: on a left click on walkable ground (`player_input.set_destination`).
- **Where**: on the ground at the destination, following the terrain (a ground mark, section 8).
- **Looks**: a bone ring, radius `max(0.45 x player footprint radius, 0.35 m)`, line 5 % of the radius (never under
  1.5 px on screen), a centre dot of 14 % of the radius, a 10 % bone wash inside. Grass may cover parts of it; that is wanted.
- **Animates**: ring contracts from 1.6x to 1x radius while fading in (`IN`); then `BREATH` at alpha 0.85.
  On arrival (within the C stop radius) it expands to 1.3x and fades (`OUT`).
- **Hides**: on arrival, on a WASD press, on a new click (the old one fades in 0.12 s), on selecting a creature.
- **Hold to follow** (`follow_to`): a softer mark, four short arcs of 30 degrees with gaps (drawn as 12 dots in the
  mockup kit), alpha 0.6, no dot, no contraction. It glides to the pointer's ground point with a 0.08 s smoothing. On
  release it becomes the solid marker with the `IN` contraction.
- **Cannot go there** (deep water, a cliff: the click is rejected or the path fails): the ring is drawn **cut** in four
  with a small cross in place of the dot, shakes 3 u sideways twice in 0.2 s, fades in 0.5 s. No text.

### 7.2 Selection ring (ground) and field note

- **Shows**: on a click on a creature or a carcass (`Game.creature_clicked`).
- **Where**: the ring on the ground under the target, radius `max(1.25 x its footprint radius, 0.6 m)`. The field
  note beside the mode ring, on the side with more free screen (default: upper right at 50 degrees, 130 u from the
  ring centre); after a mode is chosen it sits to the right of the creature, at the height of its body.
- **Looks**: ring in the style of the current mode (table below). Field note: the species name in Alegreya Italic 23 u
  and one row of signs under it: the diet glyph (`leaf`, `fang`, or both for an omnivore) and four short dashes for the
  relationship (stranger, neutral, trusted, ally: filled in `LICHEN` up to the current one). A carcass shows the name
  and the word "remains" / "restos". No box, no other rows. Everything else of the old card (temperament note, likes
  and dislikes, resolved count, mood number) moves to the **journal page** of that species (section 7.13).
- **Animates**: ring `IN`; when the mode changes the ring cross-fades style in `SWAP`. The note fades in 0.1 s after the ring.
- **Hides**: on deselect (Esc, a click on empty ground, the target dies or is more than 60 m away): `OUT`.
  After a mode is chosen the note's sign row fades after 4 s and only the name stays.

| Mode | Ground ring | What its length means |
|---|---|---|
| none yet (choosing) | bone, smooth, full circle | nothing |
| befriend | lichen, smooth, over a faint bone track | **trust** 0 to 100, clockwise from the creature's front; bonded = full ring doubled |
| attack | ember, teeth, over a faint track | **the target's health**, emptying anticlockwise |
| observe | ochre, dots | **observe progress** to the next clue: dots light one by one |
| intimidate | dusk, double | full; it flickers when the contest is being decided (7.8) |
| eat (carcass) | ochre, cut into the carcass's bites | **bites left** (lit) and eaten (faint) |

### 7.3 Mode ring (the radial)

- **Shows**: with the selection, centred on the target's body centre on screen (screen space, so it is a true circle and
  easy to hit from any camera pitch). Also on Tab (`radial_reopen`) while something is selected.
  It does **not** show when the selection was made by the game because a fight started (7.6): that goes straight to attack.
- **Looks**: one hairline circle (bone, 0.16) of radius `R = clamp(1.6 x the target's on-screen half-height, 84, 150) u`
  and four arcs on it. Angles clockwise from north:

  | Arc | From, to | Style, colour | Glyph at | Meaning |
  |---|---|---|---|---|
  | Befriend | 215 to 325 (west, the whole left side) | smooth, `LICHEN`, 2.6 u | 270 | social half |
  | Attack | 35 to 145 (east, the whole right side) | teeth x 6, `EMBER`, 2.6 u | 90 | aggressive half |
  | Observe | 335 to 25 (north) | dots, `OCHRE` | 0 | belongs with the peaceful side |
  | Intimidate | 155 to 205 (south) | double, `DUSK` | 180 | force without a kill |

  Glyphs 28 u, centred `R + 30` from the centre, in the arc's colour. **No text at rest.**
  A carcass shows only two arcs: **Eat** in the east (smooth, `OCHRE`, glyph `eat`) and **Observe** in the north.
  Befriend and Intimidate are absent, not dimmed. A creature that refuses social play (aggressive and not calmed, or in a
  fight) shows the Befriend arc at 0.40 with a small bar across its glyph; choosing it plays the refusal (7.10).
- **Hover or keyboard focus**: the arc thickens to 4 u, its glyph grows to 32 u, the other three drop to 0.70, and the
  mode's name appears beside the glyph (17 u, Medium) with its key under it (13.5 u, `FOG`). With **Names on signs:
  Always**, and during onboarding, all four names show (`02b-selected-radial-es.jpg`).
- **Choosing**: click an arc or its glyph (hit zone: the ring band from `R - 30` to `R + 60` inside the arc's angles
  plus 5 degrees each side, so always at least 44 u wide), or press the direction: **W** observe, **A** befriend,
  **D** attack (or eat), **S** intimidate. While the ring is open the four move keys choose and do not walk (they are
  the ring's own keys; this replaces the letters A / B / O / I, which meant nothing in Spanish and clashed with A = left).
- **Animates**: `IN` (arcs draw from their middle outwards in 0.18 s). On a choice: the chosen arc brightens for 0.1 s,
  then all four arcs fade (`OUT`) while the ground ring takes the chosen style and the petals rise (7.4).
- **Hides**: after a choice; on Esc (the selection stays, no mode, petals hidden); on deselect.
  The ring is **not modal**: no dark backdrop, the world keeps running, a click outside its hit zones is a normal world click.
- **No default mode.** After a selection keys 1-4 do nothing until a mode is chosen. This is what makes "nothing social
  or aggressive is visible without a selection" true and prevents an accidental bite.

### 7.4 Ability petals (keys 1-4, gift)

- **Shows**: when a mode is chosen for the current selection.
- **Where**: on an arc above the target: centre = the target's body centre, radius `R_p = clamp(on-screen half-height
  + 62, 84, 150) u`, one petal every 28 degrees, centred on north (four petals: -42, -14, 14, 42 degrees). Left to right is 1 to 4.
  If the arc would leave the safe margin it slides along the edge; if the target is off screen the petals sit at the
  screen edge nearest to it with a small bone triangle pointing to it.
- **Looks**: a petal is a circle of radius 20 u: an `INK` smoke disc at 0.24, a 1.4 u outline in the mode colour at
  0.8, the glyph in bone at 24 u, the key under it (14.5 u Medium). No name; the name shows on hover or with "Names on
  signs: Always" (above the petal, 14.5 u).
  - **Pressed / in use**: outline 2.6 u at 1.0, disc 0.42, for the length of the C action.
  - **Cooling down**: the outline is drawn only for the recharged part, clockwise from north (a ring that closes),
    over a faint full track; the glyph at 0.45. When it completes: one `SWAP` flash to bone.
  - **Not enough stamina / refused by C** (`unavailable`, `not_equipped`): outline dashed at 0.35, glyph at 0.38.
    Pressing it shakes the petal (3 u, 0.2 s) and flashes the stamina line; no toast.
  - **Empty loadout slot**: a dashed circle with no glyph at 0.3.
  - **Liked / disliked skill** (befriend, once the player has seen the reaction): a `LICHEN` dot above the petal for
    liked, a short bone bar for disliked. Unknown: nothing. (Dot against bar: shape, not colour.)
  - **Signature slot**: a double outline.
- **Gift** (befriend mode only): a fifth, smaller petal (radius 15 u) at the right end of the arc (74 degrees), with the
  glyph of the chosen item (`leaf`, `fruit`, `fang`, `bone`), the count as a small number at its upper right and the key
  **G** under it. **H** cycles the item: the glyph cross-fades (`SWAP`). Count 0: dashed and dim.
- **Observe** has one petal (`observe`, key 1), **Intimidate** two (`roar`, `display`), **Eat** one (`eat`).
- **Animates**: petals rise 8 u and fade in, 0.04 s apart from left to right (`IN`). `OUT` together.
- **Hides**: on deselect, on Esc, when the ring is reopened (Tab), when the target dies.

### 7.5 Befriending rhythm

The C core gives `beat_in` (ticks to the creature's next beat, 12 per beat) and a window of +-2 ticks.

- **Beat ring**: a second ground ring in bone, 1.4 u, that closes in from 1.75x to 1.0x of the trust ring's radius
  during each beat (`BEAT`, linear), with a fainter echo ring one step behind it at 0.3.
- **In the window**: the trust ring itself thickens from 2.4 u to 4.5 u and a second thin ring appears just inside it
  (a doubled line) for the 4 ticks of the window; the wooden tick sounds on the beat. So "now" is read by thickness
  and a doubled line and a sound, not by colour.
- **A skill in rhythm** (`in rhythm` event): a ripple leaves the ring outwards (1x to 1.5x, `OUT`) and a **pearl**
  (a bone dot, 3.2 u) is added on the ring at the creature's front-left: one pearl per step of the combo, up to 5.
  The combo multiplier is the number of pearls; no "Combo x1.5" text.
- **Off rhythm**: the beat ring wobbles (its radius jitters +-4 % for 0.2 s); the pearls fall off (fade down 6 u).
- **Trust gained**: the lichen arc grows to the new value (`GROW`); the new part is drawn 2 u thicker and almost white
  for 0.8 s, then settles. With **Numbers: On** a small "+18" (16 u, `LICHEN`) rises 14 u beside the arc's end.
- **Trust lost / habituation**: the arc shrinks (`GROW`), the lost part flashes bone then fades. A skill it is tired of
  shows the bone bar over that petal for 2 s.
- **Your creature** shows what it does: sing draws three thin sound arcs from its mouth towards the target (bone,
  fading with distance, 0.6 s each, one per beat); dance, charm and pose are the existing action animations.
- **Bond made**: the ring closes to a full doubled lichen ring, one slow ripple, the two-note sound, the relationship
  dashes of the field note fill; a moment line (7.10) only for the first bond with a species.

### 7.6 Fight

- **Start**: when C starts a fight and nothing is selected, the UI selects the attacker **in attack mode directly**
  (no mode ring): ground ring ember with teeth, petals with the four loadout moves. If something else was selected,
  the selection moves to the attacker.
- **Target's health** is the length of the toothed ring (7.2). Each hit removes its part with `GROW`; the removed part
  flashes bone and drifts outwards 6 u while fading. The creature's body flashes with a 0.08 s white rim (shader on
  the creature, later slice) and plays its hurt cry.
- **Wind-up tell** (`set_windup`): an ember disc on the ground inside the ring grows from the centre to the ring during
  the wind-up (alpha 0.30, with a 1.4 u ember edge), and snaps to a 0.1 s bone flash at the hit. No move name, no bar.
  The tell is a growing shape, so it does not depend on colour.
- **Other attackers** (hostile and aware of you, not selected): a thin toothed ember ring at 0.5 under each, so you see
  who is in the fight without selecting them.
- **Guard and dodge** sit at **your** creature's feet, only during a fight or while attack mode is chosen: a faint bone
  ring under you with three small marks (radius 13 u, `MIST` outline): `dodgeL` with **Q** at the left of the ring,
  `dodgeR` with **E** at the right, `guard` with **Space** in front (towards the camera). Pressed: `SWAP` to 2.4 u
  outline. Guard held: the front half of your ring becomes a thick `MIST` arc. A successful guard or dodge: one ripple
  of your ring; the screen-edge flash of today's HUD is removed.
- **Your stamina**: the third vitals line (7.7) is visible during the fight.
- **You are hit**: your ring flashes ember for 0.15 s, the health line shows the loss (7.7), the screen edge darkens
  for 0.25 s (ember-tinted vignette at 0.25). With **Numbers: On**, damage numbers appear as today (bone for dealt,
  ember for taken, 18 u, Alegreya Sans Medium). Default: off.
- **End**: win: the ring breaks into its teeth, which fall and fade (0.5 s); the carcass can then be selected.
  Flee / disengage: rings fade (`OUT`), guard and dodge marks fade, stamina line stays until full.

### 7.7 Health, hunger, stamina (bottom-left)

- **Where**: right of the seed. Three hairlines, 124 u long: stamina y 662 (only when shown), health y 674, hunger y 686.
  A 6 u tick closes each line at its maximum. A small glyph (8 u) starts each: a solid dot (health), a bitten round
  (hunger), a small cross (stamina).
- **Looks**: track 1.2 u bone at 0.24; value 2.4 u, round caps: health `BONE`, hunger `OCHRE`, stamina `MIST`.
- **Quiet**: resting 0.74 (text-free, thin). **On change**: the line goes to 1.0, the changed part is shown for 0.8 s
  (gain: an almost white, 4 u thick segment; loss: an ember segment that fades), then `REST`.
- **Stamina** appears (`IN`) when it drops below full or a fight starts; hides (`OUT`) 2 s after it is full and no fight.
- **Low health** (below 30 %): the line turns `EMBER`, 3.4 u thick with a soft ember glow, opacity `PULSE`; the edges
  of the view close in (a `#2A0F0A` radial vignette, 0 at 55 % of the radius to 0.78 at the corners, breathing with the
  pulse between 0.6 and 1 of that); the world loses 15 % saturation; a slow heartbeat; the creature limps and hangs its
  head (animation slice). Below 15 % the pulse period drops to 0.8 s.
- **Hungry** (below 25 %): the hunger line pulses once every 8 s and the glyph tilts; a stomach sound. Below 10 %: the
  line turns ember and joins the low-health rules without the vignette.
- **Never**: numbers. With **Numbers: On** the values show as "72" at the right end of each line (13.5 u, `FOG`).
- **Diegetic twin**: the body says the same (posture, limp, a thinner belly later); the lines are the precise reading.

### 7.8 Observe and intimidate

- **Observe progress**: the dotted ochre ground ring (36 dots) lights its dots clockwise from the creature's front as
  `observe_ticks / observe_ticks_max` grows; unlit dots at 0.25. Above the creature a small `observe` glyph (20 u)
  rests at 0.8 while unseen. **Seen** (`social_cancelled` reason `seen`): the glyph closes (the eye becomes a flat
  line), the lit dots fall away, the ring fades to bone. **A clue revealed**: the ring's dots gather into one mote that
  flies to the seed (`MOTE`), the seed brightens, and a whisper line names the clue (7.10); the ring starts again.
  A finished chain: moment line "Learned: ..." (7.10).
- **Intimidate contest**: on `roar` or `display` a shock ring leaves **your** feet along the ground towards the target
  (a dusk arc of 80 degrees, growing to the distance between you in 0.4 s). The target's double ring flickers while C
  decides. **Success**: its ring breaks outwards into four pieces that fade, the creature turns and leaves, and the
  ring follows it for 2 s at 0.4 before fading; it does not become hostile. **Failure**: the shock ring folds back,
  the target's ring turns to ember teeth for 1 s (it stood its ground), and stays ember if it is now hostile.
  No "It backed off" text.

### 7.9 DNA, species (top-left) and the compass (top centre)

- **DNA**: the `dna` glyph (24 u, `COPPER`) at (40, 38) and the **spendable balance** as a number (19 u Medium, bone).
  The total earned is in the journal. Resting 0.74.
  - **Gain**: a copper mote (radius 4.5 u with a 9 u halo and a short fading tail) rises from the source in the world
    (the carcass, the befriended creature, the place discovered), flies on a curve to the glyph (`MOTE`), the glyph and
    number go to 1.0, the number counts up, and "+3" in copper (16 u) shows after the pips for 1.5 s. The source is where
    the mote came from, so the toast "+3 DNA (carcass)" is gone.
  - **Spend** (at the nest): the number counts down; a mote leaves towards the nest.
- **Species resolved**: after the number, one ring per species present on the island (radius 3.6 u, 13 u apart, bone
  outline at 0.8); a resolved species is a solid copper dot. More than 8 species: "3 / 12" in text instead.
  **On resolving**: the ring fills (`GROW`), a ripple, the moment line names it. Hover shows "Species resolved" / "Especies resueltas".
- **Compass**: a hairline 280 u wide at y 34, fading out at both ends, a tick every 15 degrees (taller every 45), the
  letter **N** only (it is the same in both languages), a fixed centre pointer. Marks ride on it at their bearing:
  `nest` (always), the selected creature (a small diamond, bone, or ember if hostile), discovered landmarks and meteor
  shards (small dots; later). A mark farther than the edge sticks to the end at 0.5.
  Resting 0.74; it brightens for `REST` time when the camera yaw changes by more than 20 degrees or a mark is added.
  **There is no minimap**: zooming out is the map (CAMERA-ZOOM section 2); above z = 0.7 the compass fades out because
  the strategic icons take over.

### 7.10 Words that pass: whisper lines, moment lines, refusals

- **Whisper line** (replaces toasts): one line of Alegreya Sans 16 u, bone at 0.92, with the halo, no background,
  centred at y 676. At most one at a time, 3.5 s, then `OUT`; a newer one replaces it. Use only for what a mark cannot
  say: a clue ("Rondo: sings at first light"), a rule the player has just hit ("Your body cannot digest meat"), a save.
- **Moment line** (rare, a few per session): Alegreya Italic 28 u, centred at y 520, with its glyph drawn stroke by
  stroke on its left (0.6 s). Holds 3.5 s. For: a move learned, a species resolved, the first bond with a species, an
  alliance, a meteor shard. One at a time, queued. Example: "Learned: Pounce" / "Aprendido: Salto".
- **Refusals from C** are shown on the mark first, text second:

  | C error | Mark | Whisper (first two times only) |
  |---|---|---|
  | `on_cooldown`, `unavailable`, `not_equipped` | the petal shakes | - |
  | `full` (eat) | the hunger line bumps 2 u | - |
  | `cannot_digest` | the eat petal shakes, dashed | "Your body cannot digest meat" |
  | befriend refused (hostile, in a fight) | the befriend arc/petal shows its bar, the target's ring flashes ember teeth | "It will not listen until it is calm" |
  | `not_at_nest` (loadout) | the `nest` mark on the compass brightens | "Only at the nest" |
  | out of range, walking in | nothing (the creature walks) | - |

- **Rival heckle, herd trust falling**: shown on the creatures (a toothed flash on the heckler's ring; every herd
  member's ring appears for 1 s with its trust arc shrinking). No text.

### 7.11 Eating

- **Carcass selected**: ochre ground ring cut into as many arcs as the carcass had bites (4), lit for the bites left.
  Mode ring with Eat (east) and Observe (north). Field note: name + "remains".
- **Each bite** (C event): one arc of the ring breaks off towards your creature and fades (0.3 s); the hunger line
  grows by the bite with the bright gain segment (7.7); a wet bite sound; the carcass shrinks (as today).
- **First bite of a carcass**: the DNA mote (7.9). **Last bite**: the ring is gone, a `bone` glyph rises 10 u from the
  carcass and fades (you got a bone; the gift petal will show it).
- **Full**: the hunger line bumps; the eat petal goes dashed. **Cannot digest**: see 7.10.

### 7.12 Death and the egg

- **Death** (`outcome` 2): time slows to 0.4x for 1 s; your ground marks break and fade; the world loses all saturation
  over 1.2 s while **fog closes in from the edges** (a `#E7E4DA` radial veil, the dawn fog colour, to 0.9; not a black
  fade: this planet takes you back in fog); every sign except the seed fades out; one low call.
- **The egg**: the fog opens on the nest (camera already there, z = 0.25). A bone ring pulses once on the egg, a
  crack sound, the creature rises. One whisper line: "Back at the nest" / "De vuelta en el nido". Signs return (`IN`)
  one by one over 1 s: vitals first.
- **What it cost** (if C takes something): a mote leaves the DNA sign and fades, the number counts down. No dialog.
- **A new trace of life** (`outcome` 1) is a moment line; **the wild creature goes home** (`outcome` 3) is no text at
  all: its ring fades as it leaves.

### 7.13 The seed (menu icon) and the menu

- **Seed**: an open ring (radius 12 u, a gap at the upper right) with a centre dot, at (40, 680), bone at 0.74. It is
  the seed capsule of the planet's story. Hover: 1.0 and the word "Menu" / "Menú" with its key (Esc) to its right, over
  the vitals (which fade for the moment). It pulses once when the journal has a new note (a mote arrived).
- **Opens**: click the seed, or Esc with nothing selected. The game pauses, the veil comes in (`OUT` time), the ring
  of the seed closes its gap.
- **Menu**: a text list rising from the seed, Alegreya Sans 22 u, 33 u apart, left edge x 64, key names in a column at
  x 214 (`FOG`). No panel, no buttons: the focused item is Medium weight at 1.0 with a 14 u copper tick to its left;
  the others 0.82; unavailable 0.40 with its reason beside it.

  | Item (en / es) | Key | Opens |
  |---|---|---|
  | Resume / Seguir | Esc | closes the menu |
  | Journal / Diario | J | species pages (everything the old card showed, the clues, the reasons), moves, places |
  | Family tree / Árbol familiar | T | the lineage view (A13): the entry point; the view itself is a later design |
  | Loadout / Movimientos | L | 7.14; "at the nest" / "en el nido" beside it when it is not available |
  | Settings / Ajustes | | a second column at x 330 (below) |
  | Keys / Teclas | F1 | the key sheet (7.15) |
  | Save / Guardar, Load / Cargar | | as today (`pause_menu` signals) |
  | Main menu / Menú principal | | |

- **Settings column**: a title in Alegreya Italic 23 u, then rows 33 u apart: label at x 330, control at x 480.
  A choice is the options as words, the chosen one Medium with a copper underline. A slider is a hairline with a bone
  knob (radius 5 u). Rows: Language (English / Español); Size of the signs (0.85 to 1.5); Names on signs (On hover /
  Always); Numbers (Off / On); Stronger outlines (Off / On); Less motion (Off / On); Sound, Music, Effects, Ambience
  (the four existing buses); the existing game settings follow under a thin rule.
- **Keyboard**: Up/Down or W/S move the focus, Enter or Space chooses, Left/Right or A/D change a setting, Esc goes
  back one level. Focus is always visible (the copper tick). Mouse: hover is focus.
- **Closes**: Esc or Resume: the list fades (`OUT`), the veil lifts, the game resumes.

### 7.14 Loadout (key L, at the nest)

- **Shows**: L, or the menu item, only within the nest radius and outside a fight (the C rule). Elsewhere: 7.10.
  Closes by itself if a fight starts or you walk out of the radius (as today).
- **Looks** (`08-loadout.jpg`): a light veil (0.42); a title "At the nest" / "En el nido" (Alegreya Italic 24 u);
  a row of **known moves** as tokens (glyph 25 u inside an outline of radius about 23 u), a thin rule, and the **four
  slots** below (radius 27 u) with their keys 1 to 4. The game is not paused.
- **Role = outline shape** (not six colours):

  | Role | Outline |
  |---|---|
  | Basic | circle |
  | Engage | triangle pointing right |
  | Poke | diamond |
  | Control | square |
  | Defence | half circle (dome) |
  | Signature | hexagon; the signature slot has a double outline |

- **States**: a move not known yet: its role outline dashed at 0.45 with **no glyph** (no spoiler). A move the body
  cannot do (part level 0): glyph at 0.38 and a small bar. Focused token: copper outline 2.6 u, and under the row its
  name (19 u Medium) and one line: role and what it does (14.5 u, `FOG`), for example "Engage · leaps in, stuns".
- **Use**: drag a token to a slot, or click a token then a slot, or with keys: Left/Right to focus a token, 1 to 4 to
  put it in that slot, Backspace on a focused slot to empty it. A dotted copper line joins the token to the slot while
  choosing. The choice is sent as the C order (`loadout SLOT MOVE`), as today; a refusal shakes the token and shows the
  C reason as a whisper.
- **Hides**: L or Esc.

### 7.15 Key legend and onboarding

- **During play there is no legend.** The D13 corner hint is off by default after onboarding.
- **F1 held**: the full key sheet over a veil, generated from the InputMap as today (`devtools/legend.gd`,
  `legend.json`): groups as Alegreya Italic titles, rows "key  label" in two or three columns, keys as thin rounded
  outlines (the only place besides hints where a key cap is drawn), the current context's group first. No panel.
- **Onboarding** (the first minutes): one hint at a time, centred at y 676: a key cap and a short phrase
  (`02b-selected-radial-es.jpg`: "Click  on a creature to choose it"). Sequence, each shown until the player has done
  it twice or 25 s have passed, never during a fight:
  1. Click the ground to walk / hold to follow. 2. Drag to look around, wheel to come closer or go far.
  3. Click a creature to choose it. 4. (ring open) Choose how to meet it: all four names shown. 5. (mode chosen) 1 to 4.
  6. (first fight) Space guards, Q and E dodge. 7. (first carcass) Eat. 8. (at the nest) L changes your moves.
  9. F1 shows every key.
  The first three selections show all mode names on the ring. Progress is saved (`ui/onboarding` in the settings);
  "Keys" in the menu has "Show the hints again".
- **Dev builds**: the dev rows of the legend stay in the F1 sheet only.

### 7.16 Trust and hostility without a selection

- **Posture first** (animation slices, listed for the animators): curious = head and ears towards you; wary = body
  turned away, head up; hostile = head low, crest or spines raised, slow approach; trusting = approaches, head level,
  soft call; bonded = follows and mirrors your idle.
- **Hover** (pointer over a creature, 0.25 s): its ground ring shows at 0.4 in its relationship style: stranger = bone
  smooth, trusted or ally = lichen arc of its trust, hostile = ember teeth. It fades 0.5 s after the pointer leaves.
- **Hunted**: any hostile creature that has noticed you carries the thin ember toothed ring at 0.5 (0.75 at low
  health), whether or not it is selected, and an ember diamond on the compass if it is behind you.
- **Allies**: bonded creatures near you (within 12 m) show a small lichen dot at their feet while you stand still.

## 8. Ground marks (how the diegetic rings are drawn)

All world rings (move marker, follow marker, selection, trust, beat, health, wind-up disc, threat, your defence ring,
nest ring) are one thing: a **ground mark**, a small mesh that lies on the terrain and is shaded by one shader with
parameters (radius, line width, colour, style smooth / teeth / dots / double / cut, arc fraction and start, count,
inner disc, second ring). Requirements:

- It follows the terrain (the mesh takes its heights from `Game.ground`), is hidden by creatures and rocks in front of
  it (normal depth test), and is drawn above the grass's base.
- Line width has a floor of 1.5 px on screen so a far ring does not vanish; teeth and dots merge into a plain line
  below 3 px.
- The dark edge (halo) is part of the shader.
- The project renders with `gl_compatibility`, where Godot's `Decal` node does not exist: the mesh approach is required.
- The mode ring, petals, field note and vitals are **screen-space** (`Control` drawing), anchored to projected world points.

## 9. Input changes

| Before | After |
|---|---|
| Radial is modal with a dark backdrop; keys A / B / O / I | Ring is not modal; **W** observe, **A** befriend, **S** intimidate, **D** attack / eat while it is open |
| A mode is always set (attack by default) | No mode until chosen; a fight selects the attacker in attack mode |
| Hotbar clickable at the bottom | Petals clickable above the target; guard and dodge marks clickable at your feet |
| Esc: close radial, then deselect, then pause | Esc: close ring, then deselect, then menu (same order) |
| F1 tap toggles the corner hint | F1 hold = key sheet; the corner hint exists only as onboarding hints |
| Pause button top-right | the seed bottom-left |
| - | **J** journal, **T** family tree (new actions `journal`, `family_tree`) |

## 10. Accessibility

- **Colour**: no meaning depends on hue (principle 4, the line-style table). Liked / disliked is dot / bar. Low health
  is thicker and pulsing, not only ember. Checked pairs: `LICHEN` / `EMBER` (lightness 0.58 / 0.30), `OCHRE` / `DUSK`.
- **Contrast**: every mark has the `INK` halo. **Stronger outlines** raises the halo to a solid 1.5 u dark outline,
  resting opacity to 0.9 and all hairlines by 0.6 u.
- **Size**: **Size of the signs** 0.85 to 1.5 (default 1.0 at 720p-1080p height scaling; 1.15 suggested above 1440p
  on small screens). It scales screen-space marks and text, and ground-mark line widths; ring radii stay tied to bodies.
- **Hit targets**: at least 44 u (mode arcs, petals with their key label, menu rows 33 u high x full width).
- **Keyboard only**: everything reachable: Tab ring, W A S D modes, 1 to 4, G / H, L, J, T, Esc, menu navigation.
- **Motion**: **Less motion** (section 5). No flashing faster than 3 Hz anywhere.
- **Sound**: no information is sound-only; each sound has its mark.
- **Names on signs: Always** for players who prefer words to glyphs; **Numbers: On** for players who want values.
- **Language**: Spanish and English for every string (Q48: the human UI is bilingual). No text is baked into a shape
  of fixed width; labels grow away from their glyph. Keep labels to one or two words.

| English | Spanish | Where |
|---|---|---|
| Befriend | Amistad | mode ring |
| Attack | Atacar | mode ring |
| Observe | Observar | mode ring |
| Intimidate | Intimidar | mode ring |
| Eat | Comer | mode ring |
| remains | restos | field note |
| Menu | Menú | seed |
| Resume / Journal / Family tree / Loadout / Settings / Keys / Save / Load / Main menu | Seguir / Diario / Árbol familiar / Movimientos / Ajustes / Teclas / Guardar / Cargar / Menú principal | menu |
| at the nest | en el nido | menu, loadout |
| Size of the signs / Names on signs / Numbers / Stronger outlines / Less motion | Tamaño de los signos / Nombres en los signos / Números / Contornos más fuertes / Menos movimiento | settings |
| On hover / Always / Off / On | Al pasar / Siempre / No / Sí | settings |
| Learned: {move} | Aprendido: {move} | moment line |
| Back at the nest | De vuelta en el nido | whisper |
| Your body cannot digest meat | Tu cuerpo no digiere carne | whisper |
| It will not listen until it is calm | No te escuchará hasta que se calme | whisper |
| Only at the nest | Solo en el nido | whisper |
| Click the ground to walk | Haz clic en el suelo para caminar | hint |
| Click a creature to choose it | Haz clic en una criatura para elegirla | hint |

The longest Spanish label is about 1.4x its English one; layouts above leave 1.6x.
Creature and move names are data and are not translated here (Rondo, Garfio stay).

## 11. What goes away

The title "Primigenia / THE FIRST VALLEY" in play; the Pause button; the top-left meters panel and its text
("DNA 4 (4 to spend)", "Species resolved 0 / 4", "Food 69 / 100", "Gift [G]: fruit x2 [H] next"); the bottom-left
vitals panel with the name and "100"; the bottom hotbar and its Guard / Dodge buttons; the creature card panel; the
target name plate with its bar; the wind-up bar and label; the filled radial wheel with its backdrop and hint texts;
the toasts box and DNA toast box; floating "+18 trust", "In rhythm!", "Combo x1.5" texts (kept only as numbers with
**Numbers: On**); the screen-edge flash; the permanent corner key legend; the loadout drop-downs.

## 12. Open questions for the owner

1. **Mode keys.** The ring uses W / A / S / D by position (north observe, west befriend, south intimidate, east
   attack), replacing A / B / O / I. Recommended: yes (language-neutral, no clash with A = left). Alternative: keep the letters.
2. **No default mode.** After selecting, 1-4 do nothing until a mode is chosen (one more input, no accidental bite);
   a fight selects the attacker in attack mode at once. Recommended. Alternative: remember the last mode per species.
3. **Compass, not a minimap.** A thin strip with N, the nest and the target; the zoomed-out camera is the map.
   Recommended. Alternative: a 96 u round minimap top-right.
4. **Numbers off by default.** Trust, damage and vitals are read from lines and rings; "Numbers: On" in Settings
   brings the values back. DNA always has its number. Recommended; the risk is that fights feel less exact.
5. **DNA shows the spendable balance only**; the total earned lives in the journal. Recommended.
6. **The card moves to the journal.** In play only the name, diet and relationship show; temperament notes, likes and
   dislikes, clue counts are a journal page (J). Recommended; alternative: holding Alt over a creature shows a longer field note.

## 13. Implemented (as built, 2026-11-19)

Slices S0 to S8 of [PLAN-ui-diegetic.md](PLAN-ui-diegetic.md) are in; [UI.md](UI.md) describes the code and the keys.
Evidence: `docs/evidence/godot/ui-diegetic/` (`make godot-ui-diegetic-evidence`; `sheet.jpg` puts each mockup next to the game).

**The owner's answers to section 12 (they override the text above where they differ):**

1. Modes are chosen with the **mouse only**: click the west half (Befriend), east half (Attack / Eat), north (Observe) or south
   (Intimidate) of the ring. No W A S D or letter mode keys; W A S D keep walking while the ring is open. A "keyboard modes"
   accessibility setting is **deferred** (it is not trivial: the focus order and the ring's arcs would need a key map).
2. **No default mode.** After a selection keys 1-4 do nothing until a mode is chosen; a fight starts with the attacker selected
   in Attack mode and no ring. Clicking the creature you are fighting keeps Attack.
3. A **small round map** top-right (not the compass strip): coastline, rivers, the nest, the selected creature, your heading,
   discovered `?` places (the API takes them; the game has no such data yet). It fades out when the strategic camera takes over.
4. **Numbers are off by default** (trust, damage, vitals values); "Numbers: On" brings them back. DNA always shows its number.
5. DNA shows the **spendable balance**; the total earned is on the journal stub.
6. The long creature card is the journal's (`journal_data.gd`); in play only the field note.

Plus the owner's original asks: the white circle where you click (fades on arrival; hold-to-follow uses a softer, gliding marker),
a small menu icon bottom-left (the seed: settings, pause, journal and family tree stubs, key sheet), social and aggressive options
only with a creature selected, the key legend only on F1 or during the onboarding hints.

**Where the code differs from the plan:**

- `Style.u(x)` is `x * ui_scale`, not `x * viewport_h / 720 * ui_scale`: the project's `canvas_items` stretch mode already
  scales the canvas with the window height, so the plan's formula would scale twice.
- The new ember token is `Palette.EMBER_HOT`; `Palette.EMBER` (a pale gold) is still used by the dev tools and the main menu.
  The old panel tokens, `box()` and `make_theme()` stay for `devtools/` (console, tuning, feedback, site picker), `studio/` and the
  main menu, which keep their own look; the game UI uses `Palette.make_diegetic_theme()`. The Alegreya font is applied by that
  theme, not as the project default font, so the studio does not change.
- `Game.visual_ground` does not exist on this branch: `GroundMark.visual_ground()` returns the terrain, or the water surface over
  rivers, ponds and the sea (the ribbons lie 0.12 m above the water level and hid a ring on the bed).
- Line widths of ground marks are given in screen pixels and converted with the camera distance (one hairline weight at every zoom).
- The mode-ring key hints and the "key under the mode name" are gone with the keyboard choice. The ring does not fade out after a
  choice (it hides at once; the ground ring cross-fades in `SWAP`).
- Guard and dodge are a screen-space ring and three marks at your feet (`defence_marks.gd`), not a ground mark; the plan's
  `set_player_ring` is not implemented. The combo pearls are drawn by `ring_fx.gd` from world points that `GroundMarks` computes.
- Clicking deep water, a pond, the sea or ground steeper than the 51.6 degree slope ceiling orders **nothing** and shows the cut
  "cannot go there" ring (`Island.walk_blocked`); before, the order was sent and C stopped at the shore.
- `Game.persist_settings` (default true) lets tests and evidence avoid writing the player's settings file.
- The fade of `modal_open`: the ring is no longer modal, so `Game.modal_open` is only the menu and the loadout sheet.

**Deferred (listed in the design, not built):** the creature's white hit rim, sing sound arcs, the bite piece that flies off a ring,
the bone glyph after the last bite, the echo ring of the beat and the doubled inner ring in the rhythm window, the world losing 15 %
saturation and the heartbeat at low health, the death slow-down and the egg ring (death does fold in the fog and hides the signs),
the stomach tilt of hunger, the liked/disliked dots beyond what C reports in `likes` / `dislikes`, the loadout token state "the body
cannot do this" (C only reports known / not known) and dragging a token, allies' dots at their feet, a tired-skill bar, the intimidate
success ring that breaks into four pieces, and every posture/animation item of 7.16. The journal and family tree are stubs (veil,
title, DNA earned).


## 14. Field journal (G38, implemented on `c2/journal-polish`)

The journal stub is replaced by a notebook (`godot/ui/journal_view.gd`; data in `journal_model.gd`; pictures in `journal_art.gd`). Paper and
iron-gall ink, Alegreya faces, one copper accent; it is the one surface of the UI that is a thing in the player's hands rather than a sign
on the picture, so it has a paper sheet (no rounded boxes). Opened by J or the menu entry, closed by Esc, J, T or a click outside; the world
waits while it is open. Sections (tabs on the top edge): **Species** (live-rendered side portrait, silhouette and "? ? ?" until met; temperament,
diet, befriended / hunted pips and the Q43 state, home range, observed clues, likes), **Parts** (46-part catalogue, found / owned / level,
silhouettes for the undiscovered), **Secrets** (meteor shards with their line, fossils and old bones studied, the hidden cave), **Recipes**
(unknown / hinted / known / mastered with clue slots). Left / Right or the wheel turn spreads, Tab changes section; the key legend has a
`journal` context. Each page's source in `state()` is listed at the top of `journal_model.gd`; sections the world does not report yet hide.
Evidence: `docs/evidence/godot/journal/` (`make godot-journal-evidence`).
