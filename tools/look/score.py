#!/usr/bin/env python3
"""Visual scorecard (docs/briefs/look-score.md): measures every shot of a capture directory, judges it against
docs/research/look-targets.json, writes <dir>/<shot>.json, summary.json, summary.md and contact_<tod>.jpg.
Usage: score.py <label dir> [targets.json]      (Python 3 stdlib + Pillow; no numpy)

Shot names: <tier>_<tod>_<shot>.jpg (world; tier low|medium) and creature_<tod>_<id>_<view>.jpg (creature close-ups on the preview
stage). A <name>_mask.png next to a shot marks the pixels of the creature (world creature_dist, every creature shot); metrics of
creature shots use only those pixels. times_<tier>.json holds wall-clock ms per frame (software GL).
Metric definitions (all on 1280x720 JPG, luminance = Rec.601 L in 0..255 unless said):
  sat_mean, sat_p95, sat_over   HSV saturation 0..1 over pixels with V>0.15; sat_over = fraction with S>0.85
  contrast                      (p95 - p5) of luminance / 255; shadow/flat-light proxy
  clip_frac, crush_frac         fraction of luminance >= 250 (bloom proxy) and <= 12 (crushed shadow)
  spec_frac                     fraction of pixels with V>0.95 and S<0.2 (white specular glints: plastic-shine proxy; creature shots only are checked)
  hf_noise                      mean |L - gaussian_blur(L, r=1)|: pixel-scale texture energy at game distance (noise / dirt proxy)
  sharp_p99                     p99 of |Laplacian(L)|: edge strength, low = blurred
  tiling                        wide ground strip, detrended, max normalised autocorrelation at lags >= 12 px at 1/4 scale (repetition)
  dist_contrast                 creature_dist: |mean L(creature) - mean L(ring of background around it)| / 255
  tod_lum_ratio                 night shots: mean luminance / the same shot at midday (the day cycle must darken the world)
  warmth_shift                  dawn/dusk shots: (mean R / mean B) / the same at midday (warm light at the day's ends)
  tier_delta                    mean |difference| of 32x18 thumbnails, low vs medium of the same shot (0..1); low must look like the same game
"""
import glob, json, math, os, sys
from array import array
from operator import mul
from PIL import Image, ImageChops, ImageFilter, ImageStat

HERE = os.path.dirname(os.path.abspath(__file__))
TARGETS = os.path.join(HERE, "..", "..", "docs", "research", "look-targets.json")
TODS = ["dawn", "midday", "dusk", "night"]
WIDE = {"vista_wide", "valley_east", "valley_chase", "madre_spring", "riverbank"}


def parse(name):
    p = name.split("_")
    if p[0] == "creature":
        return {"kind": "creature", "tier": "any", "tod": p[1], "shot": "_".join(p[2:]), "creature": p[2], "view": p[3]}
    return {"kind": "world", "tier": p[0], "tod": p[1], "shot": "_".join(p[2:])}


def pct(hist, q):
    tot = sum(hist)
    if tot == 0:
        return None
    acc, target = 0, q * tot
    for i, h in enumerate(hist):
        acc += h
        if acc >= target:
            return i
    return len(hist) - 1


def tiling_score(lum):
    # ground strip: bottom 40%, 1/4 scale, detrended by subtracting a wide blur
    w, h = lum.size
    strip = lum.crop((0, int(h * 0.6), w, h)).resize((w // 4, int(h * 0.4) // 4), Image.BOX)
    base = strip.filter(ImageFilter.GaussianBlur(6))
    sw, sh = strip.size
    a = [list(map(lambda x, y: x - y, strip.crop((0, r, sw, r + 1)).tobytes(), base.crop((0, r, sw, r + 1)).tobytes())) for r in range(sh)]
    var = sum(sum(x * x for x in row) for row in a)
    if var < 1e-6:
        return 0.0
    best = 0.0
    for dy in range(6, min(sh - 6, 15), 2):          # 2-D lattice only: streaks along one axis (rivers, bands) do not count
        for dx in range(-sw // 2, sw // 2 + 1, 2):
            if abs(dx) < 8:
                continue
            s = 0.0
            n = 0
            for r in range(sh - dy):
                ra, rb = a[r], a[r + dy]
                if dx >= 0:
                    seg = sum(map(mul, ra[dx:], rb[: sw - dx]))
                    n += sw - dx
                else:
                    seg = sum(map(mul, ra[: sw + dx], rb[-dx:]))
                    n += sw + dx
                s += seg
            if n < sw * sh * 0.3:
                continue
            best = max(best, (s / n) / (var / (sw * sh)))
    return round(best, 4)


def measure(path, mask_path=None, wide=False):
    im = Image.open(path).convert("RGB")
    mask = Image.open(mask_path).convert("L") if mask_path and os.path.exists(mask_path) else None
    m = {}
    hsv = im.convert("HSV")
    _, S, V = hsv.split()
    use = V.point(lambda v: 255 if v > 38 else 0)
    if mask is not None:
        use = ImageChops.multiply(use, mask.point(lambda v: 255 if v > 0 else 0)).point(lambda v: 255 if v > 0 else 0)
        m["mask_frac"] = round(ImageStat.Stat(mask.point(lambda v: 1 if v > 0 else 0)).mean[0], 5)
    hs = S.histogram(mask=use)
    n = sum(hs)
    if n:
        m["sat_mean"] = round(sum(i * c for i, c in enumerate(hs)) / n / 255, 4)
        m["sat_p95"] = round(pct(hs, 0.95) / 255, 4)
        m["sat_over"] = round(sum(hs[218:]) / n, 5)   # S > 0.85
    spec = ImageChops.multiply(V.point(lambda v: 255 if v > 242 else 0), S.point(lambda v: 255 if v < 51 else 0))
    if mask is not None:
        spec = ImageChops.multiply(spec, mask.point(lambda v: 255 if v > 0 else 0))
    hsp = spec.histogram(mask=use if False else (mask.point(lambda v: 255 if v > 0 else 0) if mask is not None else None))
    if sum(hsp):
        m["spec_frac"] = round(hsp[255] / sum(hsp), 5)
    lum = im.convert("L")
    hl = lum.histogram(mask=mask.point(lambda v: 255 if v > 0 else 0) if mask is not None else None)
    n = sum(hl)
    if n:
        m["lum_mean"] = round(sum(i * c for i, c in enumerate(hl)) / n, 2)
        rch, _, bch = im.split()
        m["mean_r"] = round(sum(i * c for i, c in enumerate(rch.histogram(mask=mask.point(lambda v: 255 if v > 0 else 0) if mask is not None else None))) / n, 2)
        m["mean_b"] = round(sum(i * c for i, c in enumerate(bch.histogram(mask=mask.point(lambda v: 255 if v > 0 else 0) if mask is not None else None))) / n, 2)
        m["contrast"] = round((pct(hl, 0.95) - pct(hl, 0.05)) / 255, 4)
        m["clip_frac"] = round(sum(hl[250:]) / n, 5)
        m["crush_frac"] = round(sum(hl[:13]) / n, 5)
    mk = mask.point(lambda v: 255 if v > 0 else 0) if mask is not None else None
    hp = ImageChops.difference(lum, lum.filter(ImageFilter.GaussianBlur(1)))
    hh = hp.histogram(mask=mk)
    n = sum(hh)
    if n:
        m["hf_noise"] = round(sum(i * c for i, c in enumerate(hh)) / n, 4)
    lap = lum.filter(ImageFilter.Kernel((3, 3), (0, 1, 0, 1, -4, 1, 0, 1, 0), 1, 128))
    lap = lap.point(lambda v: abs(v - 128) * 2 if abs(v - 128) < 128 else 255)
    hlp = lap.histogram(mask=mk)
    if sum(hlp):
        m["sharp_p99"] = pct(hlp, 0.99)
    if wide:
        m["tiling"] = tiling_score(lum)
    return m, lum, mask


def dist_contrast(lum, mask):
    mk = mask.point(lambda v: 255 if v > 0 else 0)
    ring = ImageChops.subtract(mk.filter(ImageFilter.MaxFilter(31)).filter(ImageFilter.MaxFilter(31)), mk.filter(ImageFilter.MaxFilter(7)))
    hc, hr = lum.histogram(mask=mk), lum.histogram(mask=ring)
    nc, nr = sum(hc), sum(hr)
    if nc < 50 or nr < 50:
        return None
    mc = sum(i * c for i, c in enumerate(hc)) / nc
    mr = sum(i * c for i, c in enumerate(hr)) / nr
    return round(abs(mc - mr) / 255, 4)


def thumb_delta(a, b):
    ta = Image.open(a).convert("L").resize((32, 18), Image.BOX)
    tb = Image.open(b).convert("L").resize((32, 18), Image.BOX)
    return round(ImageStat.Stat(ImageChops.difference(ta, tb)).mean[0] / 255, 4)


def get(m, path):
    cur = m
    for k in path.split("."):
        if not isinstance(cur, dict) or k not in cur:
            return None
        cur = cur[k]
    return cur


def judge(op, v, t):
    return {"<": v < t, "<=": v <= t, ">": v > t, ">=": v >= t}[op]


def applies(chk, info):
    for k in ("tiers", "tods", "shots", "kinds"):
        if k in chk:
            key = {"tiers": "tier", "tods": "tod", "shots": "shot", "kinds": "kind"}[k]
            val = chk[k]
            if val == "all":
                continue
            v = info[key]
            if not any(v == x or (x.endswith("*") and v.startswith(x[:-1])) for x in val):
                return False
    return True


def main():
    d = sys.argv[1].rstrip("/")
    targets = json.load(open(sys.argv[2] if len(sys.argv) > 2 else TARGETS))
    shots = sorted(os.path.basename(p)[:-4] for p in glob.glob(os.path.join(d, "*.jpg")) if not os.path.basename(p).startswith("contact_"))
    rows = []
    for name in shots:
        info = parse(name)
        mpath = os.path.join(d, name + "_mask.png")
        wide = info["kind"] == "world" and info["shot"] in WIDE
        m, lum, mask = measure(os.path.join(d, name + ".jpg"), mpath if os.path.exists(mpath) else None, wide)
        if info["shot"] == "creature_dist" and mask is not None:
            m["dist_contrast"] = dist_contrast(lum, mask)
        if info["kind"] == "world" and info["tier"] == "low":
            o = os.path.join(d, "medium_%s_%s.jpg" % (info["tod"], info["shot"]))
            if os.path.exists(o):
                m["tier_delta"] = thumb_delta(os.path.join(d, name + ".jpg"), o)
        rows.append({"name": name, "info": info, "metrics": m})
    # day-cycle metrics: the same shot at another time of day (LOOK.md section 3: light follows the day cycle)
    by = {(r["info"]["tier"], r["info"]["shot"], r["info"]["tod"]): r["metrics"] for r in rows}
    for r in rows:
        i, m = r["info"], r["metrics"]
        ref = by.get((i["tier"], i["shot"], "midday"))
        if not ref or "lum_mean" not in m or "lum_mean" not in ref or not ref["lum_mean"]:
            continue
        if i["tod"] == "night":
            m["tod_lum_ratio"] = round(m["lum_mean"] / ref["lum_mean"], 4)
        if i["tod"] in ("dawn", "dusk") and m.get("mean_b") and ref.get("mean_b"):
            m["warmth_shift"] = round((m["mean_r"] / m["mean_b"]) / (ref["mean_r"] / ref["mean_b"]), 4)
    for r in rows:
        checks = []
        for chk in targets["checks"]:
            if not applies(chk, r["info"]):
                continue
            v = get(r["metrics"], chk["metric"])
            if v is None:
                checks.append(dict(chk, actual=None, verdict="N/A"))
            else:
                checks.append(dict(chk, actual=v, verdict="PASS" if judge(chk["op"], v, chk["value"]) else "FAIL"))
        r["checks"] = checks
        json.dump(r, open(os.path.join(d, r["name"] + ".json"), "w"), indent=1, sort_keys=True)
    perf = {}
    for f in sorted(glob.glob(os.path.join(d, "times_*.json"))):
        t = json.load(open(f))
        tier = os.path.basename(f)[6:-5]
        v = sorted(t.values())
        if v:
            perf[tier] = {"frames_ms_median": round(v[len(v) // 2], 1), "frames_ms_p95": round(v[min(len(v) - 1, int(len(v) * 0.95))], 1), "fps_median": round(1000.0 / v[len(v) // 2], 2), "shots": len(v)}
    summ = {"label": os.path.basename(d), "perf": perf, "rows": rows}
    json.dump(summ, open(os.path.join(d, "summary.json"), "w"), indent=1, sort_keys=True)
    write_md(d, summ, targets)
    contact_sheets(d, shots)


def write_md(d, summ, targets):
    rows = summ["rows"]
    L = ["# Visual scorecard `%s`" % summ["label"], "",
         "PASS/FAIL against `docs/research/look-targets.json` (every target is a **starting value**, source in the file; LOOK.md section 7 rows). Metric definitions: `tools/look/score.py`.", ""]
    # table of check results by id
    ids = []
    for r in rows:
        for c in r["checks"]:
            if c["id"] not in ids:
                ids.append(c["id"])
    L += ["## Summary by check", "", "| check | LOOK.md failure | target | shots checked | failing | worst |", "|---|---|---|---|---|---|"]
    fails_by_id = {}
    for cid in ids:
        cs = [(r["name"], c) for r in rows for c in r["checks"] if c["id"] == cid and c["verdict"] != "N/A"]
        if not cs:
            continue
        ch = cs[0][1]
        bad = [(n, c) for n, c in cs if c["verdict"] == "FAIL"]
        fails_by_id[cid] = bad
        better_low = ch["op"] in ("<", "<=")
        worst = (max if better_low else min)(cs, key=lambda x: x[1]["actual"]) if bad else None
        L.append("| %s | %s | %s %s | %d | %s | %s |" % (cid, ch["failure"], ch["op"], ch["value"], len(cs), ("**%d**" % len(bad)) if bad else "0",
                 ("%s = %s" % (worst[0], worst[1]["actual"])) if worst else "-"))
    L += ["", "## Weak spots today (failing checks)", ""]
    any_fail = False
    for cid, bad in fails_by_id.items():
        if bad:
            any_fail = True
            L.append("- **%s** (%s): %s" % (cid, bad[0][1]["failure"], "; ".join("%s=%s" % (n, c["actual"]) for n, c in bad[:12]) + (" ..." if len(bad) > 12 else "")))
    if not any_fail:
        L.append("- none: every check passes, so the targets are too loose; tighten them")
    L += ["", "## Performance (software GL, wall clock per frame, informational: no verdict, compare builds with tools/look/compare.py)", ""]
    L += ["| tier | median ms/frame | p95 ms | fps (median) | shots timed |", "|---|---|---|---|---|"]
    for t, p in summ["perf"].items():
        L.append("| %s | %s | %s | %s | %s |" % (t, p["frames_ms_median"], p["frames_ms_p95"], p["fps_median"], p["shots"]))
    L += ["", "## Per shot", "", "| shot | sat p95 | sat>0.85 | contrast | clip | crush | hf noise | sharp p99 | tiling | dist contrast | tier delta | night/day lum | warmth | fails |", "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
    f = lambda v: "-" if v is None else str(v)
    for r in rows:
        m = r["metrics"]
        nf = [c["id"] for c in r["checks"] if c["verdict"] == "FAIL"]
        L.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % (r["name"], f(m.get("sat_p95")), f(m.get("sat_over")), f(m.get("contrast")), f(m.get("clip_frac")),
                 f(m.get("crush_frac")), f(m.get("hf_noise")), f(m.get("sharp_p99")), f(m.get("tiling")), f(m.get("dist_contrast")), f(m.get("tier_delta")), f(m.get("tod_lum_ratio")), f(m.get("warmth_shift")), ("**" + ", ".join(nf) + "**") if nf else "-"))
    L += ["", "## Not measurable", ""] + ["- " + s for s in targets.get("not_measurable", [])]
    open(os.path.join(d, "summary.md"), "w").write("\n".join(L) + "\n")


def contact_sheets(d, shots):
    for tod in TODS:
        names = [n for n in shots if parse(n)["tod"] == tod]
        if not names:
            continue
        cols = 4
        tw, th = 320, 180
        rows_n = (len(names) + cols - 1) // cols
        sheet = Image.new("RGB", (cols * tw, rows_n * th), (16, 16, 16))
        for i, n in enumerate(names):
            sheet.paste(Image.open(os.path.join(d, n + ".jpg")).convert("RGB").resize((tw, th), Image.LANCZOS), ((i % cols) * tw, (i // cols) * th))
        sheet.save(os.path.join(d, "contact_%s.jpg" % tod), quality=85)


main()
