# Creature-part inspiration and provenance

Researched 2026-11-12. All cpore part meshes are original procedural geometry
from `tools/blender-mcp/sample_parts.py`. No Spore meshes, textures, icons, or
other game assets are imported. Spore names below identify reference sources
only; cpore part names and silhouettes are new.

## Design patterns

- [SporeWiki: Creature Stage](https://spore.fandom.com/wiki/Creature_Stage):
  mouths, senses, limbs, graspers, feet, weapons, and details map to combat,
  social, and movement abilities. Relevant archetypes include bite, charge,
  strike, ranged spit, singing, dancing, charm, jumping, gliding, and sneaking.
- [IGN: Spore Creature Creator Center](https://microsites.ign.com/spore/101.html)
  and its [part screenshot](https://microsites.ign.com/spore/images/screen2.jpg):
  exaggerated eyes and mouths, strongly differentiated limbs, playful
  proportions, and parts whose function remains readable on an unusual body.
- [Creature Creator guide mirror](https://esporo.net/uploads/2019/07/creature_creator.pdf):
  personality-driven, function-based, and Earth-influenced construction;
  mouth diet roles, jumping feet, adhesive feet, gliding details, and vocal
  mouths. The cpore set combines all three approaches without reproducing the
  guide's named parts.

## Biological references

- [Smithsonian Ocean: Smasher mantis shrimp](https://ocean.si.edu/ocean-life/invertebrates/smasher-mantis-shrimp):
  a heavy raptorial striking appendage informs `arm_smasher`.
- [Smithsonian Ocean: Anglerfish lures](https://ocean.si.edu/ocean-life/fish/anglerfish-lure-prey-throughout-ocean):
  a dorsal-fin-derived prey lure informs the curved stalk and luminous tip of
  `lure_lantern`.
- [Song et al., Journal of Experimental Biology: gecko toe adhesion](https://polypedal.berkeley.edu/wp-content/uploads/jeb223438.pdf):
  five compliant, distributed toes and their ability to conform to varied
  surfaces inform `foot_gecko`.
- [Wainwright and Bennett: chameleon tongue projection](https://fishlab.ucdavis.edu/wp-content/uploads/sites/397/2020/06/Wainwright-Bennett-1992.pdf):
  projectile feeding informs `tongue_spring`; the cpore version uses an
  oversized elastic profile and sticky paddle for gameplay readability.
- [Natural History Museum: Ankylosaurs](https://www.nhm.ac.uk/discover/ankylosaurs-the-dinosaurs-with-built-in-armour.html):
  armor and bony tail clubs inform `tail_hammer`.
- [Natural History Museum: Parasaurolophus](https://www.nhm.ac.uk/discover/dino-directory/parasaurolophus.html):
  a pronounced cranial silhouette and beaked jaws contribute to the exaggerated
  resonating profile of `snout_trumpet`; this is not a reconstruction.

## Second collection

| cpore part | Visual/function brief |
| --- | --- |
| `beak_crusher` | Broad herbivore beak with visible grinding ridges; bite/sing. |
| `mandible_shear` | Opposed curved insect mandibles; bite/strike. |
| `snout_trumpet` | Flared resonating snout with sound ports; sing/charm. |
| `tongue_spring` | Projectile tongue and sticky paddle; ranged capture. |
| `sac_spitter` | Twin pressure sacs and a bright nozzle; ranged spit. |
| `arm_smasher` | Jointed striking arm with an oversized club; strike. |
| `foot_spring` | Long angular jumping limb with a contrasting tendon; jump/sprint/dance. |
| `foot_hoof` | Compact cloven hooves and rear dewclaws; charge/dance. |
| `foot_gecko` | Five splayed, padded, ridged toes; climb/sneak. |
| `lure_lantern` | Curved sensory stalk and caged luminous bulb; charm/perception. |
| `wing_insect` | Two veined membrane lobes; glide. |
| `tail_hammer` | Muscular curved tail and lateral bony club; strike/defense. |

Suggested abilities are illustrative metadata, not authoritative cpore
simulation balance or `cpore.creature/1` genome definitions.
