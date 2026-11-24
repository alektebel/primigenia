#!/usr/bin/env python3
"""Reference for godot/extension/atmosphere.cpp: Hillaire 2020 eqs. 1-11, written for clarity, not speed.

Builds the 256x64 transmittance LUT and the 32x32 multiple-scattering LUT (Psi_ms) with the same conventions as the C++
(see atmosphere.h). Deliberately NOT structured like the C++ (no precomputed ray data, one straight loop per sample).

The plan asked for a numpy port; numpy is not installed on the build machine and installs are not allowed, so this is plain
Python with multiprocessing. The maths is the same and the run takes a few seconds.

  python3 tools/atmo/ref.py --preset canon|earth --out build/atmo_ref_canon.json

Also writes "fine": the transmittance at 24 chosen LUT texels integrated with 4000 steps instead of 40, an independent check
of the LUT values themselves (the paper's 40 uniform steps are coarse near the horizon; the test reports that error).
"""
import argparse
import json
import math
import multiprocessing
import sys

TRANS_W, TRANS_H, TRANS_STEPS = 256, 64, 40
MS_W, MS_H, MS_SIDE, MS_STEPS = 32, 32, 8, 20

EARTH = dict(
    ground_radius_km=6360.0, top_radius_km=6460.0,
    rayleigh_scattering=(5.802e-3, 13.558e-3, 33.1e-3), rayleigh_scale_height_km=8.0,
    mie_scattering=3.996e-3, mie_absorption=4.40e-3, mie_scale_height_km=1.2, mie_g=0.8,
    ozone_absorption=(0.650e-3, 1.881e-3, 0.085e-3), ozone_center_km=25.0, ozone_half_width_km=15.0,
    ground_albedo=0.3,
)


def canon():
    p = dict(EARTH)
    p.update(ground_radius_km=6614.0, top_radius_km=6714.0,
             rayleigh_scattering=tuple(1.6 * c for c in EARTH["rayleigh_scattering"]),
             rayleigh_scale_height_km=7.6,
             mie_scattering=1.5 * EARTH["mie_scattering"], mie_absorption=1.5 * EARTH["mie_absorption"],
             ground_albedo=0.12)
    return p


PRESETS = {"earth": EARTH, "canon": None}


def medium(p, h):
    """(rayleigh scattering rgb, mie scattering, extinction rgb) at height h km (eqs. 2-3, Table 1)."""
    h = max(h, 0.0)
    dr = math.exp(-h / p["rayleigh_scale_height_km"])
    dm = math.exp(-h / p["mie_scale_height_km"])
    do = max(0.0, 1.0 - abs(h - p["ozone_center_km"]) / p["ozone_half_width_km"])
    ray = [c * dr for c in p["rayleigh_scattering"]]
    mie_s = p["mie_scattering"] * dm
    mie_e = (p["mie_scattering"] + p["mie_absorption"]) * dm
    ext = [ray[c] + mie_e + p["ozone_absorption"][c] * do for c in range(3)]
    return ray, mie_s, ext


def transmittance(p, r, mu, steps):
    """T(r, mu) to the top of the atmosphere, midpoint rule with `steps` steps (eq. 2)."""
    rt = p["top_radius_km"]
    d = -r * mu + math.sqrt(max(r * r * mu * mu - r * r + rt * rt, 0.0))
    dt = d / steps
    tau = [0.0, 0.0, 0.0]
    for s in range(steps):
        t = (s + 0.5) * dt
        rs = math.sqrt(r * r + 2 * r * mu * t + t * t)
        _, _, ext = medium(p, rs - p["ground_radius_km"])
        for c in range(3):
            tau[c] += ext[c] * dt
    return [math.exp(-x) for x in tau]


def trans_texel(p, i, j):
    rg, rt = p["ground_radius_km"], p["top_radius_km"]
    big_h = math.sqrt(rt * rt - rg * rg)
    rho = big_h * j / (TRANS_H - 1)
    r = math.sqrt(rho * rho + rg * rg)
    dmin, dmax = rt - r, rho + big_h
    d = dmin + (i / (TRANS_W - 1)) * (dmax - dmin)
    mu = max(-1.0, min(1.0, (big_h * big_h - rho * rho - d * d) / (2 * r * d))) if d > 0 else 1.0
    return r, mu


def trans_row(args):
    p, j = args
    return [transmittance(p, *trans_texel(p, i, j), TRANS_STEPS) for i in range(TRANS_W)]


def lookup(p, lut, r, mu):
    """Bilinear lookup of the LUT with the Bruneton parameterisation (texel index = x * (n - 1))."""
    rg, rt = p["ground_radius_km"], p["top_radius_km"]
    big_h = math.sqrt(rt * rt - rg * rg)
    rho = math.sqrt(max(r * r - rg * rg, 0.0))
    d = -r * mu + math.sqrt(max(r * r * mu * mu - r * r + rt * rt, 0.0))
    dmin, dmax = rt - r, rho + big_h
    xmu = min(1.0, max(0.0, (d - dmin) / (dmax - dmin))) if dmax > dmin else 0.0
    xr = min(1.0, max(0.0, rho / big_h))
    fx, fy = xmu * (TRANS_W - 1), xr * (TRANS_H - 1)
    ix, iy = min(int(fx), TRANS_W - 2), min(int(fy), TRANS_H - 2)
    ax, ay = fx - ix, fy - iy
    out = []
    for c in range(3):
        a, b = lut[iy][ix][c], lut[iy][ix + 1][c]
        e, f = lut[iy + 1][ix][c], lut[iy + 1][ix + 1][c]
        out.append((a * (1 - ax) + b * ax) * (1 - ay) + (e * (1 - ax) + f * ax) * ay)
    return out


def directions():
    """64 uniformly distributed directions: 8 x 8 stratified, equal solid angle."""
    out = []
    for a in range(MS_SIDE):
        for b in range(MS_SIDE):
            az = 2 * math.pi * (a + 0.5) / MS_SIDE
            z = 1 - 2 * (b + 0.5) / MS_SIDE
            s = math.sqrt(max(0.0, 1 - z * z))
            out.append((s * math.cos(az), s * math.sin(az), z))
    return out


def phase_rayleigh(c):
    return 3 / (16 * math.pi) * (1 + c * c)


def phase_mie(g, c):
    return 3 / (8 * math.pi) * (1 - g * g) * (1 + c * c) / ((2 + g * g) * (1 + g * g - 2 * g * c) ** 1.5)


def ms_texel(p, lut, i, j):
    """Psi_ms for sun cos = 2u-1 (u = i/31), height v = j/31 (eqs. 5-10). Unit sun illuminance."""
    rg, rt = p["ground_radius_km"], p["top_radius_km"]
    cs = 2 * (i / (MS_W - 1)) - 1
    sun = (math.sqrt(max(0.0, 1 - cs * cs)), 0.0, cs)
    r0 = rg + (j / (MS_H - 1)) * (rt - rg)
    dirs = directions()
    l2 = [0.0] * 3
    fms = [0.0] * 3
    for d in dirs:
        mu = d[2]
        tmax = -r0 * mu + math.sqrt(max(r0 * r0 * mu * mu - r0 * r0 + rt * rt, 0.0))
        gd = r0 * r0 * mu * mu - r0 * r0 + rg * rg
        hit = mu < 0 and gd >= 0
        if hit:
            tmax = max(0.0, -r0 * mu - math.sqrt(gd))
        dt = tmax / MS_STEPS
        cphase = d[0] * sun[0] + d[2] * sun[2]
        phr, phm = phase_rayleigh(cphase), phase_mie(p["mie_g"], cphase)
        thr = [1.0, 1.0, 1.0]
        for s in range(MS_STEPS):
            t = (s + 0.5) * dt
            pos = (d[0] * t, d[1] * t, r0 + d[2] * t)
            r = math.sqrt(sum(x * x for x in pos))
            ray, mie_s, ext = medium(p, r - rg)
            mus = (pos[0] * sun[0] + pos[1] * sun[1] + pos[2] * sun[2]) / r
            shadow = 0.0 if (mus < 0 and r * r * mus * mus - r * r + rg * rg >= 0) else 1.0
            ts = lookup(p, lut, r, mus) if shadow else [0.0] * 3
            for c in range(3):
                st = math.exp(-ext[c] * dt)
                w = thr[c] * (1 - st) / ext[c]  # analytic integral of T over the step (ext > 0 always: Rayleigh)
                l2[c] += w * ts[c] * (ray[c] * phr + mie_s * phm)  # L0: sigma_s T S p (eq. 4)
                fms[c] += w * (ray[c] + mie_s)  # L_f = int sigma_s T dt (eq. 8)
                thr[c] *= st
        if hit:
            pg = (d[0] * tmax, d[1] * tmax, r0 + d[2] * tmax)
            rgr = math.sqrt(sum(x * x for x in pg))
            mus = (pg[0] * sun[0] + pg[1] * sun[1] + pg[2] * sun[2]) / rgr
            if mus > 0:
                ts = lookup(p, lut, rgr, mus)
                for c in range(3):
                    l2[c] += thr[c] * ts[c] * mus * p["ground_albedo"] / math.pi  # eq. 6 ground bounce
    n = len(dirs)
    # eq. 5 and 7 with the uniform phase 1/4pi: the sphere integral is the mean; eq. 9 and 10.
    return [(l2[c] / n) / (1 - fms[c] / n) for c in range(3)]


_G = {}


def _init(p, lut):
    _G["p"], _G["lut"] = p, lut


def ms_row(j):
    p, lut = _G["p"], _G["lut"]
    return [ms_texel(p, lut, i, j) for i in range(MS_W)]


FINE_TEXELS = [(i, j) for j in (0, 10, 25, 40, 55, 63) for i in (64, 160, 224, 255)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preset", choices=["canon", "earth"], default="canon")
    ap.add_argument("--out", required=True)
    ap.add_argument("--jobs", type=int, default=min(8, multiprocessing.cpu_count()))
    a = ap.parse_args()
    p = canon() if a.preset == "canon" else dict(EARTH)
    with multiprocessing.Pool(a.jobs) as pool:
        lut = pool.map(trans_row, [(p, j) for j in range(TRANS_H)])
        with multiprocessing.Pool(a.jobs, initializer=_init, initargs=(p, lut)) as pool2:
            ms = pool2.map(ms_row, range(MS_H))
    fine = [{"i": i, "j": j, "t": transmittance(p, *trans_texel(p, i, j), 4000)} for i, j in FINE_TEXELS]
    flat = lambda rows: [v for row in rows for px in row for v in px]
    with open(a.out, "w") as f:
        json.dump({"preset": a.preset, "trans": flat(lut), "ms": flat(ms), "fine": fine}, f)
    print("wrote", a.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
