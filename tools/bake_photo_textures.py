#!/usr/bin/env python3
"""Pack ambientCG (CC0) 1K-JPG material zips into the terrain's photographic texture set.

usage: python3 -I bake_photo_textures.py SRC_DIR OUT_DIR   (SRC_DIR/<Asset>/<Asset>_1K-JPG_{Color,NormalGL,Displacement}.jpg)
Writes two 4x2 atlases of 1024 tiles (the Godot Texture2DArray importer slices them into 8 layers): rock_albedo.jpg (sRGB albedo)
and rock_pack.jpg (R,G tangent normal xy OpenGL, B height stretched to the 1st..99th percentile). Prints the mean linear albedo of each, which rock_photo.gdshaderinc divides out (the palette keeps the
island's colour mood; the photograph supplies only the local variation). Needs numpy and Pillow; reads images only.
"""
import sys, os
import numpy as np
from PIL import Image

MATERIALS = {  # name: ambientCG asset
    "andesite": "Rock048", "strata": "Rock022", "basalt": "Rock050", "tuff": "Rock061",
    "scree": "Gravel040", "talus": "Ground108", "soil": "Ground039", "sediment": "Ground079S",
}

PACK_SIZE = {"soil": 512, "sediment": 512, "scree": 512}   # fine-grained materials: a half-size normal pack is enough

def srgb_to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)

def main(src, out):
    os.makedirs(out, exist_ok=True)
    cols, rows = 4, 2   # layer = row * cols + col: the Texture2DArray importer slices the atlas in this order
    S = 1024
    alb = Image.new("RGB", (cols * S, rows * S))
    pak = Image.new("RGB", (cols * S, rows * S))
    for layer, (name, asset) in enumerate(MATERIALS.items()):
        base = f"{src}/{asset}/{asset}_1K-JPG_"
        col = Image.open(base + "Color.jpg").convert("RGB")
        nrm = np.asarray(Image.open(base + "NormalGL.jpg").convert("RGB"))
        hgt = np.asarray(Image.open(base + "Displacement.jpg").convert("L")).astype(np.float32)
        lo, hi = np.percentile(hgt, [1, 99])
        h = np.clip((hgt - lo) / max(hi - lo, 1e-3), 0, 1)
        pk = np.dstack([nrm[:, :, 0], nrm[:, :, 1], (h * 255 + 0.5).astype(np.uint8)])
        pimg = Image.fromarray(pk.astype(np.uint8), "RGB")
        if name in PACK_SIZE:   # fine-grained materials: a half-size normal pack, scaled back up into its layer
            pimg = pimg.resize((PACK_SIZE[name],) * 2, Image.LANCZOS).resize((S, S), Image.BICUBIC)
        x, y = (layer % cols) * S, (layer // cols) * S
        alb.paste(col, (x, y))
        pak.paste(pimg, (x, y))
        mean = srgb_to_lin(np.asarray(col).astype(np.float32) / 255.0).reshape(-1, 3).mean(0)
        print(f"layer {layer} {name:9s} {asset:10s} const vec3 PH_MEAN_{name.upper()} = vec3({mean[0]:.4f}, {mean[1]:.4f}, {mean[2]:.4f});")
    alb.save(f"{out}/rock_albedo.jpg", quality=88, optimize=True)
    pak.save(f"{out}/rock_pack.jpg", quality=93, subsampling=0, optimize=True)

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
