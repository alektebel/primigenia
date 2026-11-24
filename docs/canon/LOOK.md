# Look canon

The owner's taste for how the world and creatures look, so agents can judge visual work without asking. Agreed 2026-11-21 (taste session round 1, "okey a todo"). Builds on A24 (naturalistic creatures, player's colours authoritative) and A28 (natural island). Changing this file is an owner decision.

## 1. Style: naturalistic, slightly stylised
Believable materials and light, clear shapes, a controlled palette. Same principle as the motion canon: real, a little exaggerated so it reads from the strategic camera. Not documentary photorealism, not painterly, not cartoon.

**Update 2026-11-24 (A98, owner):** the world goes further toward realism: physically based sky and aerial perspective (Hillaire 2020), real moisture-driven vegetation, modelled trees and rocks, ground materials with normal and roughness detail. Shapes stay slightly stylised. Creatures get the realism layer (skin, wetness, muscle) so they sit in the same world. The failure list below still applies.

## 2. The planet: Earth-like with alien accents
A real-feeling place that is not Earth: Earth-like geology, water and light, with a few alien touches (vegetation hues slightly shifted, an off-Earth sunset sky tint, some odd flora). Leaves room for stranger worlds in later stages.

## 3. Light follows the day cycle
The 20-minute day (A27) drives the look: marked dawn and dusk (warm, long shadows), neutral midday, readable night. Shaders are judged at dawn, midday, dusk and night, not one hour.

## 4. Creature skin from genome and habitat
Matte by default; wet only on aquatic/amphibious creatures and wet zones (snout, mouth, belly per A24); gloss only where the player chose it. Never plastic. The player's hues are never shifted (A24).

## 5. Readability is allowed, subtly
Subtle rim light, distance fog and creature-vs-ground value contrast so the player's creature and threats read at any distance. Never visible outlines or glows that break the naturalism.

## 6. Low tier is the same game
Integrated GPUs keep the same palette and composition with simpler shading. Low must look like the same game, less detailed, not a different one.

## 7. Failures (any of these fails a review)
| Failure | How it is checked |
|---|---|
| Plastic shine | specular/roughness range per material; reference comparison |
| Oversaturated colour | saturation histogram vs palette limits |
| Noisy, "dirty" textures | high-frequency energy at game camera distance |
| Visible tiling | repetition detection on wide shots |
| Flat light, no shadows | luminance contrast and shadow coverage per shot |
| Too much bloom or blur | clipped-highlight fraction, sharpness |
| Black cartoon outlines | never used |

## 8. References
Owner's own images go in `~/Desarrollo/cpore-refs/look/` (outside the repo). Until then, Claude's candidates (tracker D-24, 48 h auto-accept): Prehistoric Planet (creature skin and light), Horizon Zero Dawn (stylised-natural landscapes, readability), Spore (creature readability), and freely licensed photos of volcanic islands (Galápagos, Hawai'i) from Wikimedia Commons for terrain, rock and vegetation.

## How agents use this
Every visual change: run the visual scorecard at the fixed cameras and four times of day, check §7, compare with references. Prototype in the three.js lab, ship in Godot (A35). If the numbers improve, nothing in §7 fails and low tier holds its fps, it may merge without asking (A33).
