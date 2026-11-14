# Studio v4 — imported part materials

Audit of the 24 Blender GLBs in `web/studio/parts/`, after the loader in
`web/studio/studio.js` replaces each primitive's material. Names are the glTF
mesh and material names. The loader's `PropertyBinding.sanitizeNodeName` turns
spaces into underscores and drops other punctuation before the mesh name is
read; the region choice uses the material name, which is unchanged, plus an
emissive check.

No imported slot maps to `dark`. Obsidian sockets use the eye region (pupil).

## How a region is chosen

1. Emissive materials, and material names matching lantern / chartreuse / glow, are `glow`.
2. `beak_crusher` is `keratin` on every slot (the upper beak reuses the belly material name).
3. `Warm sand underside` on a wing, or on a mesh whose name contains wing, membrane or fan, is `membrane`. This is the insect wing's lower sail.
4. Otherwise the name in `parts.json` `material_regions`, then a name heuristic, then the category fallback (wings and fins → membrane, weapons and digging claws → keratin, senses → eye, else skin).

## What each region draws

| Region | Material |
|---|---|
| skin | Creature skin (`skinM`) |
| membrane | Same skin colours, double-sided, opacity 0.82, roughness 0.94, and a backlight term in `onBeforeCompile` when the sun is behind the surface. Transmission is not used: in three r128 it is an extra full-scene pass. Flat membranes also keep a fixed skin weight of 0.42 so a downward normal is not painted as belly, and the albedo is darkened so a sky-facing sheet does not clip to white under ACES. |
| keratin | `boneM`, except non-ivory slots of a beak, which use `beakM` |
| eye | `irisM` when the material name contains "iris", otherwise `pupM` |
| glow | The creator's `glowM` (cyan, emissive). The mesh does not cast or receive shadows. |
| dark | Unused by these GLBs |

## Slot table

| Part | glTF mesh | Material | Region |
|---|---|---|---|
| arm_grasper | Cone.035 | Tidal teal skin | skin |
| arm_grasper | Cone.035 | Warm sand underside | skin |
| arm_grasper | Cone.035 | Plum keratin | keratin |
| arm_grasper | Cone.035 | Ivory teeth and claws | keratin |
| arm_smasher | Cone.067 | Cobalt chitin | keratin |
| arm_smasher | Cone.067 | Plum keratin | keratin |
| arm_smasher | Cone.067 | Ivory teeth and claws | keratin |
| beak_crusher | Upper crushing beak | Warm sand underside | keratin |
| beak_crusher | Upper crushing beak | Plum keratin | keratin |
| beak_crusher | Upper crushing beak | Ivory teeth and claws | keratin |
| eye_stalk | Cone | Tidal teal skin | skin |
| eye_stalk | Cone | Warm sand underside | skin |
| eye_stalk | Cone | Golden iris | eye |
| eye_stalk | Cone | Obsidian eyes | eye |
| eye_triad | Sphere.003 | Tidal teal skin | skin |
| eye_triad | Sphere.003 | Warm sand underside | skin |
| eye_triad | Sphere.003 | Golden iris | eye |
| eye_triad | Sphere.003 | Obsidian eyes | eye |
| foot_gecko | Cone.080 | Tidal teal skin | skin |
| foot_gecko | Cone.080 | Warm sand underside | skin |
| foot_gecko | Cone.080 | Ivory teeth and claws | keratin |
| foot_hoof | Cone.077 | Tidal teal skin | skin |
| foot_hoof | Cone.077 | Warm sand underside | skin |
| foot_hoof | Cone.077 | Plum keratin | keratin |
| foot_hoof | Cone.077 | Ivory teeth and claws | keratin |
| foot_spring | Cone.072 | Tidal teal skin | skin |
| foot_spring | Cone.072 | Warm sand underside | skin |
| foot_spring | Cone.072 | Ivory teeth and claws | keratin |
| foot_spring | Cone.072 | Cobalt chitin | keratin |
| frill_fan | Display fan | Coral membrane | membrane |
| frill_fan | Display fan | Ivory teeth and claws | keratin |
| horn_crown | Cone.013 | Tidal teal skin | skin |
| horn_crown | Cone.013 | Plum keratin | keratin |
| jaw_nipper | Sphere.013 | Tidal teal skin | skin |
| jaw_nipper | Sphere.013 | Warm sand underside | skin |
| jaw_nipper | Sphere.013 | Ivory teeth and claws | keratin |
| leg_sprinter | Cone.024 | Tidal teal skin | skin |
| leg_sprinter | Cone.024 | Plum keratin | keratin |
| leg_sprinter | Cone.024 | Ivory teeth and claws | keratin |
| leg_sucker | Cone.029 | Tidal teal skin | skin |
| leg_sucker | Cone.029 | Warm sand underside | skin |
| lure_lantern | Lantern stalk | Cobalt chitin | keratin |
| lure_lantern | Lantern stalk | Lantern chartreuse | glow |
| lure_lantern | Lantern stalk | Plum keratin | keratin |
| mandible_shear | Sphere.025 | Cobalt chitin | keratin |
| mandible_shear | Sphere.025 | Plum keratin | keratin |
| mandible_shear | Sphere.025 | Ivory teeth and claws | keratin |
| sac_spitter | Sphere.034 | Coral membrane | membrane |
| sac_spitter | Sphere.034 | Lantern chartreuse | glow |
| sac_spitter | Sphere.034 | Cobalt chitin | keratin |
| shell_plate | Sphere.015 | Plum keratin | keratin |
| shell_plate | Sphere.015 | Ivory teeth and claws | keratin |
| snout_trumpet | Resonating snout | Tidal teal skin | skin |
| snout_trumpet | Resonating snout | Warm sand underside | skin |
| snout_trumpet | Resonating snout | Plum keratin | keratin |
| snout_trumpet | Resonating snout | Obsidian eyes | eye |
| tail_hammer | Hammer tail | Tidal teal skin | skin |
| tail_hammer | Hammer tail | Plum keratin | keratin |
| tail_hammer | Hammer tail | Cobalt chitin | keratin |
| tail_hammer | Hammer tail | Ivory teeth and claws | keratin |
| tail_paddle | Cone.041 | Tidal teal skin | skin |
| tail_paddle | Cone.041 | Coral membrane | membrane |
| tail_paddle | Cone.041 | Plum keratin | keratin |
| tail_spike | Cone.044 | Tidal teal skin | skin |
| tail_spike | Cone.044 | Plum keratin | keratin |
| tail_spike | Cone.044 | Ivory teeth and claws | keratin |
| tongue_spring | Sphere.030 | Tidal teal skin | skin |
| tongue_spring | Sphere.030 | Plum keratin | keratin |
| tongue_spring | Sphere.030 | Coral membrane | membrane |
| tongue_spring | Sphere.030 | Warm sand underside | skin |
| wing_glider | Gliding membrane | Coral membrane | membrane |
| wing_glider | Gliding membrane | Plum keratin | keratin |
| wing_insect | Upper insect wing | Coral membrane | membrane |
| wing_insect | Upper insect wing | Warm sand underside | membrane |
| wing_insect | Upper insect wing | Cobalt chitin | keratin |

## What was wrong

`Lantern chartreuse` was mapped to `eye`. The name does not contain "iris", so the bulb and the spitter highlights drew with the black pupil material. They now use `glow`.

Wing, frill and paddle membranes used the skin shader with `normal.y` as the belly weight, opacity 0.66 and `depthWrite: false`. A downward face became the pale belly colour, and a flat sheet reflected the sky. Membranes now keep the creature's skin mix, a fixed non-belly weight, high roughness, and the backlight term. Wing fingers, insect veins, frill ribs and paddle edges stay on the keratin materials (`Plum keratin`, `Cobalt chitin`, `Ivory teeth and claws`).

## Contact sheet

[studio-v4-materials.png](studio-v4-materials.png) is a 3×3 sheet, one part on the Merodeador (Prowler) preset per palette category. `digging_claws` has no GLB; that cell is the procedural `excavadora`.

Renderer: headless Chromium, `--use-angle=swiftshader --enable-unsafe-swiftshader`, executable `~/.cache/ms-playwright/chromium-1254/chrome-linux64/chrome`. The only 404 during these loads was `/favicon.ico`.
