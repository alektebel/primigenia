# Playtest 2026-11-25: first session on Star massif

The owner's first session on the Star massif build (`ac5801e6`, seed 1, AMD iGPU, gl_compatibility). 24 in-game notes, all from 00:38 to 01:05, quest "Make a friend" step 2/5 throughout.
Screenshots: `feedback/notes/<stamp>-<id>/` (git-ignored); `python3 tools/feedback/notes.py show <id>`. Close each note with `notes.py done <id> "<commit>"`.
Two older open notes are folded in (4f8fe4 from 11-23, e165fe from 11-22).

Work starts 2026-11-25 (day). Order: **P1 rendering bugs → P2 controls → P3 debug switches → P4 creature look → P5 design (grilling first)**.

## P1: rendering bugs on the 8 km island (B1 regressions, fix first)
| Note | Owner's words | What the screenshot shows | Likely cause / first look |
|---|---|---|---|
| 6ab42a | "broken graphics" | Night, near trees: the mountain is torn into huge stretched sheets and spikes reaching up into the sky. | Far-terrain chunk/LOD vertices or skirts wrong at the 8 km scale (B1 widened water/river culling only). Check `terrain` chunk build and LOD seams at the island's real bounds. |
| b2d7f2, d4e6a7 | "the mountain gets unsharded if I look up too much", "if I look up the floor gets unsharded?" | Looking up: the ground disappears, the trees float in the sky. | Terrain chunk culling AABB too small/flat (same class as B1's ±2 km water/river boxes). Give chunks their real height range. |
| 08044b | "mountain doesnt look very good" | (at x 75, z 107, looking east at the massif) | Probably the same as 6ab42a; recheck after the fix, then G (ground materials). |
| e1a940 | "texture feels wrong" | A steep slope that is one flat dark-brown soil colour, no rock, no variation. | Slope material: the steep soil should go to rock; G1 (biome/veg ground weights) is the real fix, a slope→rock rule is the quick one. |
| 72aad0 | "texture looks a bit wrong" (nest) | Creature texture in the nest view. | Check with P4 parts work. |
| 70bc78 | "leaves and stuff should be transparent when the creature is under them" | Canopy hides the creature. | Camera-occluder fade (dither) for foliage between camera and player. |

## P2: controls and movement
| Note | Owner's words | Task |
|---|---|---|
| 2d7828 | "if I select a place to go, I want to keep going or sprinting at that place while I'm able to select creatures to interact with them. right now, if I select a creature, my creature stops" | Selecting a creature must not cancel the current move/sprint order. |
| 51d0b8, 4f8fe4 | "if I select a creature and attack it, I cant sprint to it", "I want to be able to run to the creature, when I go attack it it just goes walking slowly" | Approach-to-attack runs (and honours sprint). |
| 89e156 | "my foes [friends] should attack with me if somebody attacks me, in some distance" | Pack defends the player within a radius. |
| b3b68a | "should we allow the user to vary the camera to its liking semi permanently in order to be able to see the landscape while we go around?" | Camera orbit/pitch the player sets stays (no auto-recentre) — confirm in grilling. |
| 870702 | "stamina should ideally go next to the creature like a circular bar, like botw" | Stamina wheel next to the creature, shown only while it drains/refills. |
| b8dde2 | "I still see the zanco tag" | Hide species name tags over creatures (the "Starter B: Lean runner gen 1" label too) unless selected/observed. |
| 990d7d | "what do you mean E spined fossil" | Unclear UI text: find the "spined fossil" string, rewrite it in plain words. |

## P3: debug switches (cheap, do early: they speed up the rest)
| Note | Owner's words | Task |
|---|---|---|
| 299e28 | "infinite stamina for now as well" | Dev toggle: infinite stamina (default ON for now). |
| 79d9ea | "let me x2 or x5 the speed in order to debug it easily" | Dev time scale ×1/×2/×5 key. |

## P4: creature look and animation
| Note | Owner's words | Task |
|---|---|---|
| 7b0a41 | "going uphill is weird look at its leg" | Leg IK on slopes (`cpore-motion` skill). |
| af08ef, b32dc3 | "animation for digging as well", "the dig place looks weird" | Dig animation; the dig mark is a flat plank/disc floating on the slope — conform it to the ground. |
| 456212 | "vertebras are too big, so are joints" (nest) | Scale down vertebra and joint meshes. |
| 434d22 | "animation of going out of the eggs is not really good" | Redo the hatch animation. |
| 7f22c5 | "add the rest of the parts" (nest/editor) | Port the remaining parts to the editor. |
| e165fe | "the shoulders of the creature seem weird and detached" (11-22) | Shoulder attachment. |

## P5: design (grilling round before any build)
| Note | Owner's words |
|---|---|
| 420112 | "I want to be able to befriend from my own species for now. There should be slots at the right. At the start, no befriend and progress befriendings one by one. For now let me add 3" |
| 396323 | "would be cool to have burrow creatures like the one of star wars that set up traps" (design queue: original trapdoor/antlion-style ambusher, not a recreation) |
| b3b68a | camera freedom (above) |

## Also noted
- The game ran on the AMD 860M, not the RTX (`failed to load driver: nvidia-drm`). fps on the RTX still unmeasured.
