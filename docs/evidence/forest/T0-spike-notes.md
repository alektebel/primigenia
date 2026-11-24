# T0 spike from the jungle lab (Blender tree growth), 2026-11-24

`tools/forest/grow_trees.py` (Blender 5.3, `blender --background --python tools/forest/grow_trees.py -- web/gaitlab/forest_assets`, about 1 s) grows 19 woody skeletons and exports `web/gaitlab/forest_assets/trees.glb` (4.2 MB, 38 meshes, 2 LODs each) plus `trees.json` (30 KB: clump anchors, limb points, H, dbh, first branch).

What worked
- Plain recursive growth in bmesh (no Geometry Nodes, no Sapling): stems fork low, limbs leave 40-85 degrees from vertical with a random-walk crook plus phototropism, sub-limbs and twigs, pipe-model radii, buttress fins by ring radius. It gives the crooked, thick-limbed, multi-stem laurel silhouette the references show, which the old in-browser trees (one trunk, a dome) could not.
- Wood only from Blender; leaves stay cards placed in the browser on exported clump anchors (about 50 small clumps per tree, along every limb). The canopy measures integrate those same clumps, so the numbers describe the picture.
- Moss mask as vertex-colour alpha (up-facing, thick, low wood), turned into moss per version in JS. Exported by the glTF exporter as COLOR_0 RGBA (`export_vertex_color='ACTIVE'`); the loader is 25 lines (no GLTFLoader needed on three r128).
- Kinds: laurel (5), crooked (3), tall (3), giant with buttress (2), small understory (3), whippy sapling (3). Deterministic per seed.

What did not / open
- Size: L0 wood is about 1.4k triangles per tree on average, 4.2 MB total. For a phone page quantise positions to 16 bit and drop L0 twigs, or bake impostors (T1).
- Crossed leaf cards beat a camera-facing vertex-shader blend: the blend (aCen/aOff, 78-100% toward the camera) smeared crowns into horizontal streaks and was dropped.
- Blender gave us no leaf geometry; a Godot build wants real leaf clusters (Blender particle instancing or a baked leaf atlas) and octahedral impostors from the same skeletons.
- Species are not Nieblon-specific yet; the lore council gap (emergent giant, understory tree fern) is covered only by stand-ins (`giant`, `small`).
