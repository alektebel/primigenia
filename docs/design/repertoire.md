# Combat and befriend repertoire (proposal, 2026-11-23)

Owner request: "write this down. Let's expand the repertoire of attacks and befriendings we want. First we can start with 4. Later we pick our 4 attacks from the possible ones, depending on our organs and skills."

Status: **proposal**. The owner picks; decisions go to `docs/DESIGN.md`. The animation process is A60: one action at a time, starting with the starter B bite (lab: `web/gaitlab/bite.html`).

## What already exists in the game (C, `core/src/combat.c`)
- 15 moves. Each has a role (basic, engage, poke, control, defence, signature) and the body part that unlocks it:

  | Role | Moves |
  |---|---|
  | basic | bite, peck, claw_swipe |
  | engage | charge, pounce |
  | poke | spit, quill_volley, flame |
  | control | tail_strike, roar, stomp |
  | defence | guard, dodge, curl_up |
  | signature | spine_volley |

- 4 loadout slots (keys 1–4). The starter loadout today is bite, spit, peck, roar.
- Befriending uses 4 beat actions: sing, dance, charm, pose.

## The rule: 4 attacks + 4 social actions, chosen from what your body can do
1. **Organs unlock moves.** Each organ or part unlocks 1–3 moves. A better or bigger organ makes the move stronger (damage, range, status length).
2. **Skills unlock moves through play.** Examples:
   - 10 successful hunts → "grab-shake"
   - 5 befriends with one species → that species' favourite gesture
   - surviving a fall → "roll landing"
3. **Recipes are secret moves (existing rule G50).** At least two parts plus a diet condition, e.g. spikes + tail club + carnivore diet → "spiked tail club".
4. **Choose 4 attack slots and 4 social slots** from everything unlocked. Swap them at the nest or in the editor. Suggested soft rule: keep at least one basic move.
5. **The editor shows which moves an organ would unlock** before you pay for it, so parts are chosen for what they let you do as well as how they look.

## Starting 4 (proposal)
- **Attacks for starter B** (beak, lean runner legs), one per role so the first fights teach the system:
  1. **Peck/bite** (basic). The heron-style strike from the bite study.
  2. **Pounce** (engage). Hop onto the prey; legs.
  3. **Dodge** (defence). Side-step; always available.
  4. **Roar** (control). Scares prey and stops a charge; throat.
  This replaces today's bite / spit / peck / roar, which repeats two basics and has a ranged spit that B's beak doesn't explain.
- **Social:** sing, dance, charm, pose, as today.

## Expanded attack catalogue (proposal)
New moves are marked **new**.

| Organ / part | Moves it can unlock | Role | Animation idea |
|---|---|---|---|
| Mouth: beak | peck, **grab-shake** (hold + shake, bleed) | basic / control | heron freeze-strike; dog/komodo head shake |
| Mouth: jaws | bite, **crushing bite** (slow, high damage, breaks guard) | basic / signature | crocodile lunge, long hold |
| Mouth: fangs | **venom bite** (poison over time) | basic | snake-fast strike, quick retreat |
| Legs | pounce, **hind kick** (knockback behind you), stomp (heavy bodies) | engage / control | crouch-leap; donkey kick; ground dust |
| Horns / head | charge, **head-butt** (short stun) | engage / control | lowered head, accelerating gallop, recoil on both |
| Arms: grasper (A58) | **grapple** (grab + bite combo), **throw**, **slap** | engage / control / basic | lock and shove; hip throw; open-hand swat |
| Arms: smasher (A58) | **club smash** (stun), **ground slam** (sweep) | control | shoulder and torso twist; slam with dust ring |
| Claws | claw swipe, **rake** (2–3 quick hits) | basic | shoulder-led swipe, alternating rake |
| Tail | tail strike, **tail club** (knockdown), **sting** (poison) | control / poke | body turns, then the tail whips; scorpion arc |
| Spit gland | spit (slow), **acid spit** (armour down) | poke | neck pump, then a lob |
| Quills / spines | quill volley, spine volley | poke / signature | body shudder, then the release |
| Fire gland (A38, D-28) | flame (needs ≥ 16 % O₂ and air); **steam/acid jet** where there is less | poke | neck rears, cone breath |
| Throat | roar, **screech** (short-range stun) | control | chest expands, head thrown forward |
| Body / armour | guard, curl up, dodge, **spin attack** (spiky bodies) | defence / control | ball roll; spinning spikes |
| Tentacles (octopus, A55) | **wrap/constrict** (hold + damage), **ink cloud** (blind and escape) | control / defence | multi-arm wrap; jet back in ink |
| Electric organ | **shock** (stun in contact; stronger in water) | control | body flash, prey twitch |
| Wings (A56) | **wing buffet** (knockback), **dive strike** (from the air) | control / engage | wings flare; wingover into a dive |

## Expanded social catalogue (proposal)
Each species has 1–2 **favourite gestures**. Using them raises befriend progress faster, Spore-like, so observing a species pays off. These are rough proposals; the animation study (A60) refines them.

| Organ / part | Social actions | Animation idea |
|---|---|---|
| Throat | sing, **call-and-answer** (mimic the target's call; a skill) | throat pulse, head up |
| Legs | dance, **stomp dance**, **hop dance** | rhythmic steps, body bob |
| Mouth / arms | charm, **offer food** (give a carried item) | lean in, present the item |
| Crest / frill / feathers | pose, **crest display**, **frill flare** | rise tall, flare and hold |
| Arms (grasper) | **groom**, **wave** | gentle hand strokes; open-arm wave |
| Skin (chromatophores) | **colour flash** (octopus-like) | pulsing colour waves |
| Wings | **wing display** | spread and shimmer |
| Head | **nuzzle**, **head bob** | head rub; bird-like bobbing |
| Glow organ | **light show** (night bonus) | rhythmic glow |
| Tail | **tail wag**, **tail curl** | wag; curl around the friend |
| Any body | **play** (chase-and-tag invitation), **lie down** (calm, show the belly) | play bow, then a short run; settle |

## Order of work (A60 process)
1. bite / peck
2. impact effects shared by every move (hit-pause, flinch, knockback, dust, shake)
3. pounce
4. dodge
5. roar
6. the four social actions
7. arm moves (grapple, club smash)
8. the rest by organ

Each move: 3–4 versions shown large → owner pick → port to the game → loop scorecard check.

## Owner answers (2026-11-23)
- **Starting 4:** add **acid spit** in place of one move. Proposal: **dodge becomes a universal action on its own key** (always available, takes no slot), which frees a slot. The starting 4 become **peck/bite (basic), pounce (engage), acid spit (poke), roar (control)**. Starter B needs a small spit gland, as the old loadout's spit implied.
- **Skills unlocked through play:** undecided. Proposal (48 h auto-accept): v1 uses organs plus recipes only; skills come in a later version.
- **Befriending per species:** yes, and more than gestures. Each species has a favourite gesture plus a **befriend condition**:
  - only at night
  - bring it food it likes
  - defend it against a raid (predators attack its group, and you fight them off)
  - approach slowly without running
  - repeat its call
  - groom its young
  These show up in the field note after observing (O).

## Signature attacks: cool and biologically real (proposal)
Each is unlocked by an organ, usually as a recipe (G50), and is rarer and stronger than basic moves.

| Attack | Real animal | Organ / recipe | Effect | Animation |
|---|---|---|---|---|
| **Flamethrower** (exists, A38) | none on Earth; the island's vent-cooked fire gland | fire gland, ≥ 16 % O₂ (D-28) | cone, burn | neck rears, cone breath, embers |
| **Boiling spray** | bombardier beetle (hot chemical spray from the abdomen) | rear gland + armour | short-range burn and fear | abdomen swings, pulsed spray with pops |
| **Sonic snap** | pistol shrimp (cavitation bubble stun) | big claw; strongest underwater | stun at range in water | claw snaps, shockwave ring, bubbles |
| **Blinding spit** | spitting cobra (venom aimed at the eyes) | spit gland + fangs | blind (accuracy down) | hood flares, twin jets |
| **Smash punch** | mantis shrimp (club strike) | club arm (smasher) | heavy hit, breaks shells and guard | coil, blur-fast punch, flash |
| **Electric discharge** | electric eel (chain shock, stronger in water) | electric organ | stun, chains to a second target | body glows, arcs jump |
| **Tongue snatch** | chameleon (ballistic tongue) | long tongue | pulls small prey or items to you | eyes lock, tongue shoots and reels in |
| **Water jet** | archerfish (knocks prey off branches) | spit gland, near water | knockdown at range | aim, jet, and the target falls |
| **Stink cloud** | skunk (sprayed musk) | scent gland | area fear; enemies flee | tail up, back turned, cloud |
| **Blood squirt** | horned lizard (squirts blood from the eyes) | head crest + armour | scares predators | crouch, head jerk, squirt |
| **Quill storm** | porcupine (quills released when brushed) | back spines | thorns: hurts attackers in melee | quills raise and rattle |
| **Ground-pound shockwave** | elephant-scale stomp, exaggerated | heavy legs | knockdown ring | rear up, slam, dust ring |
| **Death roll** | crocodile (grab and spin) | jaws + heavy tail | big damage while holding | grab, the whole body rolls |
| **Ink cloud** | octopus and squid | ink sac (water) | blind and escape | jet back, ink bloom |

## Social evolution: befriend actions grow with organs (proposal, owner 2026-11-23)
Each social action has tiers. A better organ makes the gesture bigger, adds a variant, and raises befriend progress per beat. Pose needs a display organ (A77).

| Action | Tier 1 (starting) | Tier 2 | Tier 3 | Signature |
|---|---|---|---|---|
| **Sing** | trill (throat) | **throat sac**: deep boom with an inflating pouch | **resonating crest or chamber**: low call heard far away; attracts from range | **duet**: call-and-answer with the target species' own call (needs to have observed it) |
| **Dance** | bob-and-weave (legs) | longer or more legs: stomp and hop combos | tail or plumes: sweeping display dance | **group dance**: your pack or family joins in |
| **Charm** | preen/show-off | **arms/hands**: offer food, groom | **gift**: carry and give the species' favourite food (befriend condition) | **nest invite**: lead it to your nest |
| **Pose** *(needs a display organ)* | **crest** display | **frill or extensible crest**: flare and hold | **sail or wing display**: spread and shimmer | **colour-change skin**: pulsing colour waves (octopus-like) |

Different bodies perform the same action in their own way: arms wave and clap, wings spread, tentacles flash colour and wave, snakes sway and flare a hood. Each species' favourite gesture and its befriend condition (A62) decide which works best.

## Social duel: befriending as deep as combat (owner approved 2026-11-23, A78)
| Combat | Befriending |
|---|---|
| Distance bands | **far:** call to get noticed · **approach:** slow walk, lowered posture, head turned (running scares) · **close:** groom, offer food, nuzzle |
| The target fights back | **Target mood:** wary → curious → trusting → bonded, a reaction every beat (ears, posture, a step closer or away, an alarm call). Sudden moves, roars or nearby predators knock it back. |
| Combos | **Call-and-answer chains:** the target performs a sequence and you answer in kind. Right = combo bonus, wrong = trust loss. |
| Roles | **opener** (get noticed) · **build** (raise trust) · **calm** (counters fear) · **signature** (big surge, organ-unlocked) |
| Momentum | **Patience:** stillness and slow moves build trust; rushing backfires |
| Tactics with brain growth | read emotions (mood bar visible) · mimic any call · befriend a herd **leader** and the herd follows · trade food for help · ask allies to fight or scout |
| Rewards | DNA plus allies that fight, guide to parts and bring food |

### Special charms for intelligent species (brain-gated)
Highly intelligent species (big brain organ or species trait) ignore simple charms and respond to:
- **Play:** a game of tag or fetch with an object, or a puzzle such as rolling a stone so they can reach fruit
- **Teaching:** show them a skill (dig, crack a nut on a rock) and they copy it; that bond is strong
- **Gift of a tool or rare object:** a shiny stone, a fossil, a shell
- **Shared language:** learn their call vocabulary by observing; each "word" opens a response
- **Mirror and recognition:** they recognise you after a first meeting and remember how you treated them (a fight → hostile, a gift → friendly)

### Easter eggs: hidden befriend conditions (A62)
Some species only bond under a secret condition, found by observing, by field-note hints or by accident:
- **Only in the dark** (nocturnal shy species, glow-signal species)
- **A special fruit** (a rare plant from the food web; carry it to them)
- **Defend it from a raid** (predators attack its group; fight them off and it bonds instantly)
- Others to design: approach from downwind; befriend its young first; sing its own call back at dawn; meet it in rain; return a lost egg to its nest
