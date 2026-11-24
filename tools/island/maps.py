#!/usr/bin/env python3
"""A83 island layout candidates: shaded relief + slope/walkability maps with regions, routes, gates and the nest.

  python3 tools/island/maps.py --cli build/terrain_cli --out web/gaitlab/island [--n 1024] [--seed 1] [--layouts 1,2,3,4 | --desc island.isl]

Runs `terrain_cli maps` (the real C generator with --layout N, full erosion), reads the PPM/PGM it writes, draws the labels
with Pillow and writes jpg maps plus stats.json (reachability per region for a plain body and with climbing parts).
"""
import argparse, heapq, json, os, subprocess, sys, tempfile
from PIL import Image, ImageDraw, ImageFont

SIZE_M = 8000.0
FONT = "/usr/share/fonts/TTF/DejaVuSansCondensed-Bold.ttf"
KIND_COLOR = {
    "nest": (255, 214, 96), "forest": (40, 170, 70), "canyon": (240, 120, 40), "badlands": (230, 90, 60),
    "plateau": (170, 90, 220), "islet": (60, 200, 230), "coast": (240, 210, 90), "terraces": (210, 170, 90),
    "mountain": (190, 190, 200), "cliffs": (120, 140, 170), "reef": (60, 230, 200), "trench": (40, 70, 200),
}
SEA_KINDS = ("reef", "trench")
BIOME_NAME = {"meadow": "meadow", "mountain": "mountain range", "jungle": "jungle / forest", "desert": "desert / badlands + canyon",
              "tundra": "tundra", "cliffs": "cliffs", "reef": "Caribbean reef sea", "trench": "abyssal trench"}
SLOPE_RGB = {0: (30, 70, 120), 1: (140, 200, 110), 2: (232, 214, 96), 3: (240, 150, 60), 4: (205, 50, 50), 5: (90, 170, 215)}


def run(cli, args, **kw):
    r = subprocess.run([cli] + args, capture_output=True, text=True, **kw)
    if r.returncode:
        sys.exit("terrain_cli failed: %s\n%s" % (" ".join(args), r.stderr))
    return r.stdout


def font(sz):
    try:
        return ImageFont.truetype(FONT, sz)
    except OSError:
        return ImageFont.load_default()


class Proj:
    def __init__(self, w):
        self.w = w

    def pt(self, x, y):
        return ((x + SIZE_M / 2) / SIZE_M * self.w, (y + SIZE_M / 2) / SIZE_M * self.w)

    def m(self, d):
        return d / SIZE_M * self.w


def text_box(d, xy, s, f, fill=(255, 255, 255), bg=(10, 14, 20, 190)):
    x, y = xy
    l, t, r, b = d.textbbox((x, y), s, font=f)
    d.rounded_rectangle((l - 4, t - 2, r + 4, b + 2), 4, fill=bg)
    d.text((x, y), s, font=f, fill=fill)


def overlay(img, meta, labels, land=None, paths=None):
    """regions, routes, gates, nest and landmarks on a copy of img (RGB)."""
    W = img.size[0]
    P = Proj(W)
    base = img.convert("RGBA")
    fill = Image.new("RGBA", base.size, (0, 0, 0, 0))
    fd = ImageDraw.Draw(fill)
    if labels:
        for r in meta["regions"]:
            c = KIND_COLOR.get(r["kind"], (255, 255, 255))
            pts = [P.pt(*p) for p in r["pts"]]
            wpx = P.m(r["w"]) * 2
            if r["kind"] == "nest" or r["kind"] in SEA_KINDS:
                continue
            if len(pts) > 1:
                fd.line(pts, fill=c + (58,), width=int(wpx), joint="curve")
            for p in pts:
                rr = P.m(r["w"])
                fd.ellipse((p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr), fill=c + (58,))
    if land is not None:
        a = fill.getchannel('A'); from PIL import ImageChops; fill.putalpha(ImageChops.multiply(a, land))
    sea = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(sea)
    if labels:
        for r in meta["regions"]:
            if r["kind"] in SEA_KINDS:
                c = KIND_COLOR[r["kind"]]
                for p_ in r["pts"]:
                    px, py = P.pt(*p_); rr = P.m(r["w"])
                    sd.ellipse((px - rr, py - rr, px + rr, py + rr), fill=c + (90,), outline=c + (255,), width=3)
    base = Image.alpha_composite(base, fill)
    base = Image.alpha_composite(base, sea)
    d = ImageDraw.Draw(base)
    f_big, f_mid, f_sm = font(int(W * 0.0155)), font(int(W * 0.0125)), font(int(W * 0.0105))
    # region outlines + gate dashes
    if labels:
        for r in meta["regions"]:
            c = KIND_COLOR.get(r["kind"], (255, 255, 255))
            for p in r["pts"]:
                px, py = P.pt(*p)
                rr = P.m(r["w"]) if r["w"] else P.m(meta["nest_r"])
                if r["gate"]:
                    a = 0
                    while a < 360:
                        d.arc((px - rr, py - rr, px + rr, py + rr), a, a + 12, fill=c + (255,), width=3)
                        a += 24
                elif r["kind"] != "nest" and len(r["pts"]) == 1:
                    d.ellipse((px - rr, py - rr, px + rr, py + rr), outline=c + (210,), width=2)
    # routes: the cheapest walkable path for a plain body (slope under 51.6 deg) through the route's waypoints
    for ri, rt in enumerate(meta["routes"]):
        pp = paths.get(ri) if paths else None
        pts = [P.pt(*p) for p in rt["pts"]]
        if pp:
            pl = [(x * W / 256.0, y * W / 256.0) for x, y in pp]
            d.line(pl, fill=(15, 15, 15, 255), width=7, joint="curve")
            d.line(pl, fill=(255, 245, 200, 255), width=3, joint="curve")
        else:
            for a_, b_ in zip(pts, pts[1:]):
                d.line([a_, b_], fill=(255, 70, 70, 255), width=3)
        if labels:
            ex, ey = pts[-1]
            n = rt["name"].split(":")[0] if ":" in rt["name"] else rt["name"]
            text_box(d, (min(ex + 6, W - 150), min(max(ey - 8, 4), W - 24)), n, f_sm, bg=(60, 50, 20, 200))
    # nest
    nx, ny = P.pt(0, 0)
    rr = P.m(meta["nest_r"])
    d.ellipse((nx - rr, ny - rr, nx + rr, ny + rr), outline=(255, 214, 96, 255), width=4)
    star = []
    import math
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rad = 15 if k % 2 == 0 else 6
        star.append((nx + rad * math.cos(a), ny + rad * math.sin(a)))
    d.polygon(star, fill=(255, 214, 96, 255), outline=(20, 20, 20, 255))
    text_box(d, (nx + 18, ny - 34), "NEST", f_big, fill=(255, 225, 120))
    # gates
    for r in meta["regions"]:
        if r["gate"]:
            px, py = P.pt(*r["pts"][0])
            tag = "GATE: climbers" if r["gate"] == 1 else "GATE: swim / glide"
            d.regular_polygon((px, py, 14), 4, rotation=45, fill=(255, 80, 80, 255), outline=(255, 255, 255, 255))
            if labels:
                text_box(d, (px + 18, py - 8), "%s (%s)" % (r["name"], tag), f_mid, fill=(255, 200, 200))
    if labels:
        for r in meta["regions"]:
            if r["gate"] or r["kind"] == "nest":
                continue
            px, py = P.pt(*r["pts"][len(r["pts"]) // 2])
            text_box(d, (px - 30, py - 8), "%s [%s]" % (r["name"], r["biome"]) if r["biome"] not in ("none",) else r["name"], f_mid, fill=tuple(min(255, int(v * 0.6 + 120)) for v in KIND_COLOR.get(r["kind"], (255, 255, 255))))
        for m in meta["marks"]:
            if m["kind"] in ("plateau",):
                continue
            px, py = P.pt(m["x"], m["y"])
            if m["kind"] in ("volcano", "reactor"):
                col = (255, 90, 40, 255) if m["kind"] == "volcano" else (190, 255, 60, 255)
                d.regular_polygon((px, py, 13), 6 if m["kind"] == "reactor" else 3, fill=col, outline=(20, 20, 20, 255))
                text_box(d, (px + 16, py - 10), m["name"], f_sm, fill=col[:3], bg=(10, 14, 20, 200))
                continue
            d.polygon([(px, py - 9), (px - 8, py + 6), (px + 8, py + 6)], fill=(255, 255, 255, 255), outline=(20, 20, 20, 255))
            text_box(d, (px + 11, py - 20), m["name"], f_sm, fill=(235, 235, 235), bg=(10, 14, 20, 150))
    # scale bar and compass
    bar = P.m(500)
    x0, y0 = 20, W - 34
    bar = P.m(1000)
    d.rectangle((x0 - 4, y0 - 20, x0 + bar + 90, y0 + 14), fill=(10, 14, 20, 200))
    d.line((x0, y0, x0 + bar, y0), fill=(255, 255, 255, 255), width=4)
    d.text((x0 + bar + 8, y0 - 10), "1 km", font=f_sm, fill=(255, 255, 255, 255))
    if labels:
        wx, wy = meta["wind"]
        cx0, cy0 = 90, 80
        d.rectangle((14, 14, 250, 118), fill=(10, 14, 20, 190))
        d.text((22, 18), "Prevailing wind (wet side)", font=f_sm, fill=(210, 235, 255, 255))
        d.line((cx0 - wx * 40, cy0 - wy * 30 + 10, cx0 + wx * 40, cy0 + wy * 30 + 10), fill=(130, 200, 255, 255), width=5)
        hx, hy = cx0 + wx * 40, cy0 + wy * 30 + 10
        d.ellipse((hx - 8, hy - 8, hx + 8, hy + 8), fill=(130, 200, 255, 255))
        d.text((22, 98), "lee side = rain shadow", font=f_sm, fill=(240, 200, 150, 255))
        # biome key
        present = []
        for r in meta["regions"]:
            if r["biome"] != "none" and r["biome"] not in [b for b, _ in present]:
                present.append((r["biome"], KIND_COLOR.get(r["kind"], (255, 255, 255))))
        ky = W - 40 - 22 * len(present) - 8
        d.rectangle((10, ky - 24, 300, W - 46), fill=(10, 14, 20, 200))
        d.text((18, ky - 20), "Biomes (%d of 8)" % len(present), font=f_sm, fill=(255, 255, 255, 255))
        for k, (b, c) in enumerate(present):
            d.rectangle((18, ky + 2 + k * 22, 36, ky + 16 + k * 22), fill=c + (255,), outline=(255, 255, 255, 255))
            d.text((44, ky + k * 22), BIOME_NAME[b], font=f_sm, fill=(235, 235, 235, 255))
    d.text((W - 36, 10), "N", font=f_big, fill=(255, 255, 255, 255))
    d.polygon([(W - 28, 40), (W - 36, 62), (W - 20, 62)], fill=(255, 255, 255, 255))
    return base.convert("RGB")


def slope_image(cls_img, shade_img, reach_img):
    W = cls_img.size[0]
    pal = []
    for i in range(256):
        pal += list(SLOPE_RGB.get(i, (0, 0, 0)))
    c = cls_img.copy()
    c.putpalette(pal)
    rgb = c.convert("RGB")
    sh = shade_img.point(lambda v: int(150 + v * 0.45)).convert("RGB")
    from PIL import ImageChops
    out = ImageChops.multiply(rgb, sh).point(lambda v: min(255, int(v * 1.35)))
    # land not reachable by a plain body: hatch grey-violet over walkable cells; reachable only with climbing: lilac tint
    reach = reach_img.copy()
    lut_other = [0] * 256
    lut_other[0] = 255   # unreachable by anyone
    unreach_mask = reach.point(lut_other).convert("L")
    land_walk = cls_img.point([0, 255, 255, 255, 0, 255] + [0] * 250).convert("L")
    from PIL import ImageChops as IC
    plain_mask = reach.point([0, 255] + [0] * 254).convert("L")
    # walkable but cut off from the nest for a plain body
    cut = IC.subtract(land_walk, plain_mask)
    tint = Image.new("RGB", out.size, (140, 60, 200))
    out = Image.composite(Image.blend(out, tint, 0.55), out, cut)
    return out



WALK_COST = {1: 1.0, 2: 1.5, 3: 3.0, 5: 1.6}


def grid_paths(cls_img, meta):
    """Walk each route's waypoints over the 256 grid; returns {route index: [(gx, gy)...]} or None when blocked."""
    G = 256
    g = cls_img.resize((G, G), Image.NEAREST)
    px = list(g.tobytes())
    cost = [WALK_COST.get(v, 0.0) for v in px]

    def snap(x, y):
        gx, gy = int((x + SIZE_M / 2) / SIZE_M * G), int((y + SIZE_M / 2) / SIZE_M * G)
        gx, gy = min(max(gx, 0), G - 1), min(max(gy, 0), G - 1)
        best = None
        for r in range(0, 31):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    x2, y2 = gx + dx, gy + dy
                    if 0 <= x2 < G and 0 <= y2 < G and cost[y2 * G + x2] > 0:
                        return (x2, y2)
        return best

    def walk(a, b):
        INF = 1e18
        dist = {a: 0.0}
        prev = {}
        h = [(0.0, a)]
        while h:
            dd, u = heapq.heappop(h)
            if u == b:
                out = [u]
                while u in prev:
                    u = prev[u]; out.append(u)
                return out[::-1]
            if dd > dist.get(u, INF):
                continue
            ux, uy = u
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if not dx and not dy:
                        continue
                    vx, vy = ux + dx, uy + dy
                    if not (0 <= vx < G and 0 <= vy < G):
                        continue
                    c = cost[vy * G + vx]
                    if c <= 0:
                        continue
                    nd = dd + c * (1.4142 if dx and dy else 1.0)
                    if nd < dist.get((vx, vy), INF):
                        dist[(vx, vy)] = nd; prev[(vx, vy)] = u
                        heapq.heappush(h, (nd, (vx, vy)))
        return None

    res = {}
    for ri, rt in enumerate(meta["routes"]):
        pts = [snap(*p) for p in rt["pts"]]
        chain = []
        ok = all(pts)
        for a, b in zip(pts, pts[1:]):
            if not ok:
                break
            seg = walk(a, b)
            if not seg:
                ok = False
                break
            chain += seg
        res[ri] = [(x + 0.5, y + 0.5) for x, y in chain] if ok and chain else None
    return res


def region_mask(meta_r, W, nest_r):
    P = Proj(W)
    m = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(m)
    pts = [P.pt(*p) for p in meta_r["pts"]]
    rr = P.m(meta_r["w"] or nest_r)
    if len(pts) > 1:
        d.line(pts, fill=255, width=int(rr * 2))
    for p in pts:
        d.ellipse((p[0] - rr, p[1] - rr, p[0] + rr, p[1] + rr), fill=255)
    return m


BIOME_NAMES = ["sea", "reef", "beach", "meadow", "cloud forest", "dry forest", "scrub", "desert", "badlands", "alpine", "tundra", "snow", "cliff"]
BIOME_RGB = [(30, 70, 130), (60, 190, 200), (222, 207, 150), (146, 200, 88), (16, 104, 52), (104, 150, 58), (192, 172, 92), (226, 190, 108),
             (186, 98, 58), (150, 152, 172), (196, 214, 226), (250, 250, 255), (108, 100, 96)]


def ramp(stops, v):
    """v in 0..1 through (pos, rgb) stops."""
    for (a, ca), (b, cb) in zip(stops, stops[1:]):
        if v <= b:
            t = 0 if b == a else (v - a) / (b - a)
            return tuple(int(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))
    return stops[-1][1]


PRECIP_STOPS = [(0.0, (120, 82, 46)), (0.06, (206, 168, 98)), (0.15, (230, 218, 120)), (0.3, (120, 190, 110)), (0.55, (40, 140, 170)), (0.8, (40, 70, 190)), (1.0, (110, 40, 170))]


def lut_image(img, stops):
    lut = [ramp(stops, v / 255.0) for v in range(256)]
    out = Image.new("RGB", img.size)
    out.putdata([lut[v] for v in img.convert("L").tobytes()])
    return out


def key_strip(W, items, title):
    """a legend: items = [(label, rgb)]"""
    strip = Image.new("RGB", (W, 40), (20, 24, 30))
    d = ImageDraw.Draw(strip)
    f = font(int(W * 0.0115))
    d.text((12, 12), title, font=f, fill=(255, 255, 255))
    x = 18 + int(d.textlength(title, font=f))
    for label, rgb in items:
        d.rectangle((x, 11, x + 18, 29), fill=rgb, outline=(235, 235, 235))
        d.text((x + 24, 12), label, font=f, fill=(235, 235, 235))
        x += 36 + int(d.textlength(label, font=f)) + 8
    return strip


GATE_REGIONS = {"Forest vale": (60, 230, 110), "Canyon badlands": (255, 150, 70), "Mesa": (200, 150, 255), "Nest valley": (255, 214, 96)}


def climate_overlay(img, meta):
    """light overlay for the climate images: the four gated regions as outlines, the nest, the wind, scale and north."""
    W = img.size[0]
    P = Proj(W)
    base = img.convert("RGBA")
    d = ImageDraw.Draw(base)
    f_mid, f_sm = font(int(W * 0.0125)), font(int(W * 0.0105))
    for r in meta["regions"]:
        c = GATE_REGIONS.get(r["name"])
        if not c:
            continue
        pts = [P.pt(*p) for p in r["pts"]]
        rr = P.m(r["w"] or meta["nest_r"])
        m = Image.new("L", (W, W), 0)
        md = ImageDraw.Draw(m)
        if len(pts) > 1:
            md.line(pts, fill=255, width=int(rr * 2))
        for (px, py) in pts:
            md.ellipse((px - rr, py - rr, px + rr, py + rr), fill=255)
        from PIL import ImageFilter, ImageChops
        edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(5)))
        base.paste(Image.new("RGBA", (W, W), c + (255,)), (0, 0), edge)
        d = ImageDraw.Draw(base)
        lx, ly = pts[len(pts) // 2]
        text_box(d, (lx - 30, ly - 10), r["name"], f_mid, fill=c, bg=(10, 14, 20, 190))
    nx, ny = P.pt(0, 0)
    d.regular_polygon((nx, ny, 9), 4, rotation=45, fill=(255, 214, 96, 255), outline=(20, 20, 20, 255))
    wx, wy = meta["wind"]       # the layout's wind: the direction of travel
    cx, cy = 70, 62
    d.rectangle((14, 14, 232, 96), fill=(10, 14, 20, 190))
    d.text((22, 18), "Trade wind blows from the NE", font=f_sm, fill=(210, 235, 255, 255))
    d.line((cx - wx * 38, cy - wy * 30, cx + wx * 38, cy + wy * 30), fill=(130, 200, 255, 255), width=5)
    d.ellipse((cx + wx * 38 - 7, cy + wy * 30 - 7, cx + wx * 38 + 7, cy + wy * 30 + 7), fill=(130, 200, 255, 255))
    d.text((120, 52), "toward the SW,\nlee = rain shadow", font=f_sm, fill=(240, 200, 150, 255))
    bar = P.m(1000)
    x0, y0 = 20, W - 30
    d.rectangle((x0 - 4, y0 - 16, x0 + bar + 70, y0 + 12), fill=(10, 14, 20, 200))
    d.line((x0, y0, x0 + bar, y0), fill=(255, 255, 255, 255), width=4)
    d.text((x0 + bar + 8, y0 - 9), "1 km", font=f_sm, fill=(255, 255, 255, 255))
    d.text((W - 34, 10), "N", font=f_mid, fill=(255, 255, 255, 255))
    d.polygon([(W - 26, 34), (W - 34, 54), (W - 18, 54)], fill=(255, 255, 255, 255))
    return base.convert("RGB")


def climate_images(pre, name, meta, a, relief):
    """--climate: precipitation, biome, vegetation and cloud/fog images from the maps terrain_cli wrote (docs/plans/island-realism.md 4.2)."""
    px = a.px
    cn_raw = open(pre + "-climate.rgba", "rb").read()
    cn = int(round((len(cn_raw) // 4) ** 0.5))
    clim = Image.merge("RGBA", [c.resize((px, px), Image.BILINEAR) for c in Image.frombytes("RGBA", (cn, cn), cn_raw).split()])   # per channel: an RGBA resize would premultiply by the alpha (fog)
    biome = Image.open(pre + "-biome.pgm").resize((px, px), Image.NEAREST)
    n = Image.open(pre + "-biome.pgm").size[0]
    veg = Image.merge("RGBA", [c.resize((px, px), Image.BILINEAR) for c in Image.frombytes("RGBA", (n, n), open(pre + "-veg.rgba", "rb").read()).split()])
    land = biome.point(lambda v: 255 if v > 1 else 0)
    quiet = dict(meta, routes=[])
    shade = relief.convert("L").point(lambda v: int(205 + v * 0.2))   # light: the colours must read as data, not as relief
    from PIL import ImageChops

    def shaded(rgb):
        """rgb modulated by the relief shading so the ground reads under the colour"""
        k = shade.point(lambda v: min(255, int(v * 1.0)))
        return ImageChops.multiply(rgb, Image.merge("RGB", (k, k, k)))

    out = {}
    pr = lut_image(clim.getchannel("R"), PRECIP_STOPS)
    pr = Image.composite(shaded(pr), pr, land)
    sea_img = Image.new("RGB", (px, px), (34, 60, 96))
    pr = Image.composite(pr, sea_img, land.point(lambda v: 255 if v else 0))
    out["precip"] = (climate_overlay(pr, meta), key_strip(px, [("0", ramp(PRECIP_STOPS, 0)), ("250", ramp(PRECIP_STOPS, 0.0625)), ("600", ramp(PRECIP_STOPS, 0.15)),
                                                                          ("1200", ramp(PRECIP_STOPS, 0.3)), ("2200", ramp(PRECIP_STOPS, 0.55)), ("3200", ramp(PRECIP_STOPS, 0.8)), ("4000+ mm/yr", ramp(PRECIP_STOPS, 1.0))], "Annual precipitation  "))
    lut = BIOME_RGB
    bi = Image.new("RGB", (px, px)); bi.putdata([lut[v] for v in biome.tobytes()])
    bi = Image.composite(shaded(bi), bi, land)
    out["biome"] = (climate_overlay(bi, meta), key_strip(px, list(zip(BIOME_NAMES, BIOME_RGB))[2:], "Biome  "))
    # vegetation: ground tone by grass and canopy, dark green canopy, undergrowth thickens it, litter/moss wetness adds blue-green
    can, und, gra, lit = (veg.getchannel(i) for i in range(4))
    base = Image.new("RGB", (px, px), (150, 128, 96))
    gcol = Image.new("RGB", (px, px), (150, 188, 84))
    ccol = Image.new("RGB", (px, px), (14, 82, 38))
    v1 = Image.composite(gcol, base, gra)
    v2 = Image.composite(ccol, v1, can.point(lambda v: min(255, int(v * 1.1))))
    v2 = Image.composite(Image.new("RGB", (px, px), (8, 52, 28)), v2, und.point(lambda v: int(v * 0.5)))
    v2 = Image.composite(Image.new("RGB", (px, px), (240, 244, 250)), v2, biome.point(lambda v: 255 if v == 11 else 0))
    v2 = Image.composite(Image.new("RGB", (px, px), (118, 110, 104)), v2, biome.point(lambda v: 255 if v == 12 else 0))
    v2 = Image.composite(shaded(v2), v2, land)
    v2 = Image.composite(v2, sea_img, land)
    out["veg"] = (climate_overlay(v2, meta), key_strip(px, [("bare ground", (150, 128, 96)), ("grass", (150, 188, 84)), ("canopy", (14, 82, 38)), ("snow", (240, 244, 250)), ("cliff", (118, 110, 104))], "Vegetation  "))
    # clouds: cloud water (R) and fog frequency (A) over the relief, the trade-wind cloud belt
    qc, fog = clim.getchannel("B"), clim.getchannel("A")
    cl = relief.convert("RGB").copy()
    cl = Image.composite(Image.new("RGB", (px, px), (245, 248, 252)), cl, qc.point(lambda v: min(200, int(v * 1.5))))
    cl = Image.composite(Image.new("RGB", (px, px), (170, 200, 215)), cl, fog.point(lambda v: min(160, int(v * 1.0))))
    out["cloud"] = (climate_overlay(cl, meta), key_strip(px, [("cloud water", (245, 248, 252)), ("fog frequency", (170, 200, 215))], "Cloud and fog  "))
    for k, (img, key) in out.items():
        both = Image.new("RGB", (px, px + 40)); both.paste(img.convert("RGB"), (0, 0)); both.paste(key, (0, px))
        both.save(os.path.join(a.out, "%s-%s.jpg" % (name, k) if a.suffix is None else "%s-%s-%s.jpg" % (name, a.suffix, k)), quality=a.quality, optimize=True)


def legend_strip(W):
    strip = Image.new("RGB", (W, 70), (20, 24, 30))
    d = ImageDraw.Draw(strip)
    f = font(int(W * 0.0125))
    items = [("under 30 deg", 1), ("30-45", 2), ("45-51.6", 3), ("over 51.6: blocked for a plain body", 4), ("shallow water", 5), ("sea / deep water", 0)]
    x = 14
    for label, k in items:
        d.rectangle((x, 12, x + 22, 34), fill=SLOPE_RGB[k], outline=(240, 240, 240))
        d.text((x + 28, 12), label, font=f, fill=(235, 235, 235))
        x += 36 + int(d.textlength(label, font=f)) + 12
    d.rectangle((14, 42, 36, 62), fill=(140, 60, 200), outline=(240, 240, 240))
    d.text((42, 42), "walkable land cut off from the nest for a plain body (needs climbing parts, swimming or flight)", font=f, fill=(235, 235, 235))
    return strip


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cli", default="build/terrain_cli")
    ap.add_argument("--out", default="web/gaitlab/island")
    ap.add_argument("--n", type=int, default=1536)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--layouts", default="1,2,3,4")
    ap.add_argument("--desc", default=None, help="an ISL1 island blob (tools/island/pack.mjs): map that island instead of --layouts")
    ap.add_argument("--px", type=int, default=1100)
    ap.add_argument("--quality", type=int, default=80)
    ap.add_argument("--climate", action="store_true", help="with --desc: also the climate maps (precipitation, biome, vegetation, cloud) and the M2 region gates")
    ap.add_argument("--height", default=None, help="with --climate: reuse a -height.f32 from an earlier run (climate pass only, 0.1 s)")
    ap.add_argument("--cal", action="append", default=[], help="with --climate: SLOT=VALUE climate calibration override (island.h CP_ISL_CAL_*), repeatable")
    ap.add_argument("--suffix", default=None, help="file name tag for the climate images")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stats = {}
    with tempfile.TemporaryDirectory() as tmp:
        for L in ([0] if a.desc else [int(x) for x in a.layouts.split(",")]):
            pre = os.path.join(tmp, "l%d" % L)
            sel = ["--desc", a.desc] if a.desc else ["--layout", str(L)]
            gen = json.loads(run(a.cli, ["maps"] + sel + ["--seed", str(a.seed), "--n", str(a.n), "--out", pre] + (["--climate"] if a.climate and a.desc else []) +
                                (["--height", a.height] if a.height and a.desc else []) + [x for c in a.cal for x in ("--cal", c)]))
            meta = json.loads(run(a.cli, ["layout-json"] + sel + ["--n", "64", "--droplets", "0", "--stream", "0", "--thermal", "0"]))
            relief = Image.open(pre + "-relief.ppm").convert("RGB").resize((a.px, a.px), Image.LANCZOS)
            cls = Image.open(pre + "-cls.pgm").resize((a.px, a.px), Image.NEAREST)
            shade = Image.open(pre + "-shade.pgm").resize((a.px, a.px), Image.BILINEAR)
            reach = Image.open(pre + "-reach.pgm").resize((a.px, a.px), Image.NEAREST)
            name = meta["id"]
            global SIZE_M
            SIZE_M = float(meta["size_m"])
            land = cls.point([0, 255, 255, 255, 255, 255] + [255] * 250).convert("L")
            paths = grid_paths(Image.open(pre + "-cls.pgm"), meta)
            overlay(relief, meta, True, land, paths).save(os.path.join(a.out, "%s-map.jpg" % name), quality=a.quality, optimize=True)
            relief.save(os.path.join(a.out, "%s-relief.jpg" % name), quality=a.quality, optimize=True)
            if a.climate and a.desc:
                climate_images(pre, name, meta, a, relief)
                sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "climate"))
                import gates
                g = gates.run(argparse.Namespace(cli=a.cli, desc=a.desc, prefix=pre))
                with open(os.path.join(a.out, "%s-climate-gates.json" % name), "w") as f:
                    json.dump(g, f, indent=1)
                print("climate gates", "PASS" if g["pass"] else "FAIL", json.dumps({k: v[0] for k, v in g["gates"].items()}))
            sl = overlay(slope_image(cls, shade, reach), meta, False, None, paths)
            strip = legend_strip(a.px)
            both = Image.new("RGB", (a.px, a.px + 70))
            both.paste(sl, (0, 0)); both.paste(strip, (0, a.px))
            both.save(os.path.join(a.out, "%s-slope.jpg" % name), quality=a.quality, optimize=True)
            # per-region reachability (fractions of land cells in the region)
            rs = []
            for r in meta["regions"]:
                m = region_mask(r, a.px, meta["nest_r"])
                hist_c = cls.histogram(m)
                land = sum(hist_c) - hist_c[0]
                hr = reach.histogram(m)
                landmask_total = max(1, land)
                plain = hr[1]
                climb = hr[2]
                # reach counts include sea? no: reach is only set on land cells
                # gate verdict: the core of the region (half its radius) as a plain body and with climbing parts
                core = region_mask(dict(r, w=max(r["w"] * 0.5, 8)), a.px, meta["nest_r"])
                hc = reach.histogram(core); tot = max(1, sum(hc))
                core_plain, core_climb = 100.0 * hc[1] / tot, 100.0 * hc[2] / tot
                rs.append({"core_plain_pct": round(core_plain, 1), "core_climb_only_pct": round(core_climb, 1),
                           "name": r["name"], "kind": r["kind"], "gate": r["gate"], "land_px": land,
                           "plain_pct": round(100.0 * plain / landmask_total, 1), "climb_only_pct": round(100.0 * climb / landmask_total, 1)})
            routes_ok = {meta["routes"][i]["name"]: bool(v) for i, v in paths.items()}
            land_total = gen["land_cells"]
            cell = gen["cell_m"]
            stats[name] = {"id": name, "layout": L, "land_km2": round(land_total * cell * cell / 1e6, 2),
                           "plain_reach_pct": round(100.0 * gen["plain_reach"] / land_total, 1),
                           "climb_reach_pct": round(100.0 * gen["climb_reach"] / land_total, 1), "regions": rs,
                           "routes_walkable": routes_ok,
                           "route_paths": {meta["routes"][i]["name"]: [[round((x / 256.0) * SIZE_M - SIZE_M / 2), round((y / 256.0) * SIZE_M - SIZE_M / 2)] for x, y in v[::3]] for i, v in paths.items() if v}, "params": meta["params"], "marks": meta["marks"]}
            print(name, json.dumps(stats[name]))
    with open(os.path.join(a.out, "stats-desc.json" if a.desc else "stats.json"), "w") as f:
        json.dump(stats, f, indent=1)


if __name__ == "__main__":
    main()
