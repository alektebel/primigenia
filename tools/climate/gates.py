#!/usr/bin/env python3
"""M2 region gates (docs/plans/island-realism.md 4.5) on the maps `terrain_cli maps --desc ISL --climate --out PREFIX` writes.

  python3 tools/climate/gates.py --cli build/terrain_cli --desc build/island/star_f0.isl --prefix PREFIX [--json out.json]

Reads PREFIX-biome.pgm (n x n), PREFIX-climate.rgba (R = precipitation, 0..4000 mm/yr), PREFIX-height.f32 and the island
meta (`terrain_cli layout-json --desc`), and checks:
  Forest vale     >= 80 % of its land cells are cloud forest or dry forest. Cells that terrain overrides decide (cliff, beach)
                  are left out of the denominator and both numbers are reported: `forest_vale_forest_pct` (the gate) and
                  `forest_vale_forest_pct_all_land`.
  Canyon badlands >= 70 % desert, badlands or scrub (same rule: `canyon_dry_pct`, `canyon_dry_pct_all_land`)
  Mesa top        >= 80 % tundra or alpine, over the region's cells within 10 % of the region's highest ground (the plateau is
                  not a flat disc after the domain warp and erosion; its cliff wall is a terrain override)
  Nest valley     >= 80 % meadow (nest region = the valley floor disc)
  rain ratio      windward / lee annual P >= 8: the 95th percentile of land P (the wet windward belts, Hilo's side) over the
                  mean P of the Canyon badlands (the lee, Waikoloa's side). The Forest vale's mean over the Canyon's mean is
                  reported as `vale_over_canyon` (information only: the vale is a low valley, not the wettest ground)
  snow            no snow cell below 600 m game height
Exit status 1 when a gate fails. Plain Python + Pillow (no numpy).
"""
import argparse, json, subprocess, sys
from array import array
from PIL import Image, ImageDraw

B = dict(SEA=0, REEF=1, BEACH=2, MEADOW=3, JUNGLE=4, DRY_FOREST=5, SCRUB=6, DESERT=7, BADLANDS=8, ALPINE=9, TUNDRA=10, SNOW=11, CLIFF=12)
NAMES = {v: k.lower() for k, v in B.items()}


def region_mask(r, n, size_m, nest_r):
    sc = n / size_m
    pts = [((x + size_m / 2) * sc, (y + size_m / 2) * sc) for x, y in r["pts"]]
    rr = (r["w"] or nest_r) * sc
    m = Image.new("L", (n, n), 0)
    d = ImageDraw.Draw(m)
    if len(pts) > 1:
        d.line(pts, fill=255, width=int(rr * 2))
    for p in pts:
        d.ellipse((p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr), fill=255)
    return m


def load(prefix):
    biome = Image.open(prefix + "-biome.pgm")
    n = biome.size[0]
    raw = open(prefix + "-climate.rgba", "rb").read()
    cn = int(round((len(raw) // 4) ** 0.5))
    clim = Image.frombytes("RGBA", (cn, cn), raw)
    h = array("f"); h.frombytes(open(prefix + "-height.f32", "rb").read())
    return biome, clim, h, n


def run(a):
    meta = json.loads(subprocess.run([a.cli, "layout-json", "--desc", a.desc, "--n", "64", "--droplets", "0", "--stream", "0", "--thermal", "0"],
                                     capture_output=True, text=True, check=True).stdout)
    biome, clim, h, n = load(a.prefix)
    size_m = float(meta["size_m"])
    P = clim.getchannel("R").resize((n, n), Image.BILINEAR)
    land = biome.point([0, 0] + [255] * 254)  # 255 where land (biome > REEF)
    land = biome.point(lambda v: 255 if v > B["REEF"] else 0)
    out = {"n": n, "gates": {}, "regions": {}}
    reg = {r["name"]: r for r in meta["regions"]}

    def stats(name, mask=None, top=False):
        r = reg[name]
        m = region_mask(r, n, size_m, meta["nest_r"]) if mask is None else mask
        lm = Image.composite(land, Image.new("L", (n, n), 0), m)   # land cells inside the region
        if top:   # the highest ground of the region: within 10 % of its maximum height
            mb = m.tobytes()
            x0, y0, x1, y1 = m.getbbox()
            idx = [y * n + x for y in range(y0, y1) for x in range(x0, x1) if mb[y * n + x]]
            hmax = max(h[i] for i in idx)
            tb = bytearray(n * n)
            for i in idx:
                if h[i] >= 0.9 * hmax: tb[i] = 255
            lm = Image.frombytes("L", (n, n), bytes(tb))
        hist = biome.histogram(lm)
        tot = max(1, sum(hist))
        frac = {NAMES[i]: round(100.0 * hist[i] / tot, 1) for i in range(13) if hist[i]}
        ph = P.histogram(lm)
        meanP = sum(i * c for i, c in enumerate(ph)) / max(1, sum(ph)) * 4000.0 / 255.0
        out["regions"][name] = {"cells": tot, "biome_pct": frac, "mean_P_mm": round(meanP, 1)}
        return hist, tot, meanP

    def pct(hist, tot, ids, overrides=("CLIFF", "BEACH")):
        den = tot - sum(hist[B[i]] for i in overrides)
        return 100.0 * sum(hist[B[i]] for i in ids) / max(1, den)

    g = out["gates"]
    hist, tot, pf = stats("Forest vale")
    g["forest_vale_forest_pct"] = (round(pct(hist, tot, ["JUNGLE", "DRY_FOREST"]), 1), ">=", 80.0)
    out["forest_vale_forest_pct_all_land"] = round(pct(hist, tot, ["JUNGLE", "DRY_FOREST"], ()), 1)
    hist, tot, pc = stats("Canyon badlands")
    g["canyon_dry_pct"] = (round(pct(hist, tot, ["DESERT", "BADLANDS", "SCRUB"]), 1), ">=", 70.0)
    out["canyon_dry_pct_all_land"] = round(pct(hist, tot, ["DESERT", "BADLANDS", "SCRUB"], ()), 1)
    hist, tot, _ = stats("Mesa", top=True)
    g["mesa_cold_pct"] = (round(pct(hist, tot, ["TUNDRA", "ALPINE"]), 1), ">=", 80.0)
    hist, tot, _ = stats("Nest valley")
    g["nest_meadow_pct"] = (round(pct(hist, tot, ["MEADOW"]), 1), ">=", 80.0)
    out["vale_over_canyon"] = round(pf / max(pc, 1e-3), 2)
    # whole-island extremes over land (8-bit R: 15.7 mm steps)
    ph = P.histogram(land)
    cum, tl, lo, hi = 0, max(1, sum(ph)), None, None
    for i, c in enumerate(ph):
        cum += c
        if lo is None and cum >= 0.05 * tl: lo = i * 4000.0 / 255.0
        if hi is None and cum >= 0.95 * tl: hi = i * 4000.0 / 255.0
    g["rain_ratio_windward_vs_lee"] = (round(hi / max(pc, 1e-3), 2), ">=", 8.0)
    out["land_P_mm"] = {"p05": round(lo, 0), "p95": round(hi, 0), "max": round(max(i for i, c in enumerate(ph) if c) * 4000.0 / 255.0, 0),
                        "min": round(min(i for i, c in enumerate(ph) if c) * 4000.0 / 255.0, 0)}
    bb = biome.tobytes()
    snow_h, at = [], bb.find(bytes([B["SNOW"]]))
    while at >= 0:
        snow_h.append(h[at]); at = bb.find(bytes([B["SNOW"]]), at + 1)
    out["snow"] = {"cells": len(snow_h), "min_h_m": round(min(snow_h), 1) if snow_h else None, "max_h_m": round(max(snow_h), 1) if snow_h else None}
    g["snow_min_height_m"] = (out["snow"]["min_h_m"] if snow_h else 9999.0, ">=", 600.0)
    out["island_biome_pct"] = {NAMES[i]: round(100.0 * c / max(1, sum(biome.histogram(land)[B["BEACH"]:])), 1) for i, c in enumerate(biome.histogram(land)) if c and i > B["REEF"]}
    ok = all(v >= t for v, _, t in g.values())
    out["pass"] = ok
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cli", default="build/terrain_cli")
    ap.add_argument("--desc", required=True)
    ap.add_argument("--prefix", required=True)
    ap.add_argument("--json")
    a = ap.parse_args()
    out = run(a)
    for k, (v, _, t) in out["gates"].items():
        print("%-32s %8s  (need >= %s)  %s" % (k, v, t, "ok" if v >= t else "FAIL"))
    print("land P mm/yr", out["land_P_mm"], "snow", out["snow"])
    for k, v in out["regions"].items():
        print(" ", k, v)
    print(" island", out["island_biome_pct"])
    if a.json:
        json.dump(out, open(a.json, "w"), indent=1)
    sys.exit(0 if out["pass"] else 1)


if __name__ == "__main__":
    main()
