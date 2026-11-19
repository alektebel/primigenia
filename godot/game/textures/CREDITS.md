# Texture credits

All photographic ground materials are from **ambientCG** (https://ambientcg.com), published under the **Creative Commons CC0 1.0
Universal** public-domain dedication (https://creativecommons.org/publicdomain/zero/1.0/): no attribution is required; it is given here
anyway. Author: ambientCG (Lennart Demes, Struffelproductions), as credited on each asset page. Downloaded as the 1K-JPG packs; only the Color,
NormalGL and Displacement images are used (`tools/bake_photo_textures.py` packs them into the two atlases below).

| Layer | Name in the game | ambientCG asset | URL | Capture |
|---|---|---|---|---|
| 0 | andesite (cliffs, ridges) | Rock048 | https://ambientcg.com/a/Rock048 | photogrammetry |
| 1 | bedded strata (bedded faces, cap rock) | Rock022 | https://ambientcg.com/a/Rock022 | photogrammetry |
| 2 | basalt (volcanic flows) | Rock050 | https://ambientcg.com/a/Rock050 | photogrammetry |
| 3 | tuff (warm cracked patches) | Rock061 | https://ambientcg.com/a/Rock061 | procedural (PBR) |
| 4 | scree (gravel) | Gravel040 | https://ambientcg.com/a/Gravel040 | photogrammetry |
| 5 | talus (coarse debris, deposition fans) | Ground108 | https://ambientcg.com/a/Ground108 | photogrammetry |
| 6 | volcanic soil (bare ground, steep turf edges) | Ground039 | https://ambientcg.com/a/Ground039 | photogrammetry |
| 7 | sediment (beach and river sand) | Ground079S | https://ambientcg.com/a/Ground079S | photogrammetry |

Files in `photo/`:

* `rock_albedo.jpg`: 4x2 atlas of 1024 px sRGB albedo tiles (JPEG q88). Imported as a Texture2DArray (8 layers, layer = row * 4 + column).
* `rock_pack.jpg`: the same atlas for R,G = tangent-space normal xy (OpenGL convention, +y up in the image, as ambientCG's NormalGL) and
  B = height (Displacement stretched to its 1st..99th percentile). Layers 4 to 7 come from 512 px sources scaled back to 1024.
* Both are imported VRAM-compressed (BC3/S3TC, `.import` files), about 5.6 MB of video memory each with mipmaps.

Before this set the terrain used `rock_detail.png` and `scree_detail.png`, baked procedurally from Voronoi noise by this project (removed).
