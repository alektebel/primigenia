#!/usr/bin/env python3
"""Reference implementation of the Smith & Barstad linear theory of orographic
precipitation (docs/plans/island-realism.md section 4, step M0).

Plain Python, no numpy (numpy is not installed here).  Double precision, a
simple recursive radix-2 FFT, written for clarity, not speed.  The C kernel
(core/src/climate.c) is checked against the fixtures this file writes.

    python3 tools/climate/lt_ref.py check      # self checks (exact triangle ridge, upslope limit, abstract numbers)
    python3 tools/climate/lt_ref.py figure     # docs/evidence/island/climate/ref/lt_ref.jpg
    python3 tools/climate/lt_ref.py fixtures   # tests/fixtures/climate/lt_*.bin

The model (see tools/climate/README.md for the paper quotes):

    Phat(k,l) = Cw i sigma hhat(k,l) / ([1 - i m Hw][1 + i sigma tau_c][1 + i sigma tau_f])
    sigma = U k + V l
    m^2   = (N^2 - sigma^2) / sigma^2 * (k^2 + l^2)
    m     = sgn(sigma) sqrt(m^2)      if m^2 >= 0   (propagating)
    m     = + i sqrt(-m^2)            if m^2 <  0   (evanescent)
    P     = max(IFFT(Phat) + P_inf, 0)

Units here are SI inside (Cw in kg m^-3, heights and distances in m, times in
s, wind in m s^-1) and **mm per hour** at the interface (P, P_inf), because
kg m^-2 s^-1 is mm s^-1 and the papers quote mm h^-1.

Fourier convention: forward e^{-i(kx+ly)}, inverse e^{+i(kx+ly)} / N^2, as in
numpy.  k = 2 pi j / (N dx) with j in [-N/2, N/2).  The Nyquist row and column
of Phat are zeroed (a real field has no unique phase there), in both this file
and the C kernel, so the spectrum is exactly Hermitian and the C kernel can use
real-pair packing.
"""
import math
import os
import struct
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))

# --------------------------------------------------------------------------
# FFT (recursive radix-2, complex numbers as Python complex)
# --------------------------------------------------------------------------


def fft(a, inverse=False):
    """Unnormalised DFT of a list whose length is a power of two.
    forward: sum a[j] e^{-2 pi i jk/N};  inverse: e^{+...} (no 1/N)."""
    n = len(a)
    if n == 1:
        return [a[0]]
    ev = fft(a[0::2], inverse)
    od = fft(a[1::2], inverse)
    sgn = 1.0 if inverse else -1.0
    out = [0j] * n
    h = n // 2
    for k in range(h):
        w = complex(math.cos(2 * math.pi * k / n), sgn * math.sin(2 * math.pi * k / n)) * od[k]
        out[k] = ev[k] + w
        out[k + h] = ev[k] - w
    return out


def fft2(g, inverse=False):
    """2-D DFT of a list of rows (list of lists of complex)."""
    rows = [fft(r, inverse) for r in g]
    ny, nx = len(rows), len(rows[0])
    cols = [fft([rows[y][x] for y in range(ny)], inverse) for x in range(nx)]
    return [[cols[x][y] for x in range(nx)] for y in range(ny)]


def freq(j, n):
    return j if j < n // 2 else j - n


# --------------------------------------------------------------------------
# Linear theory
# --------------------------------------------------------------------------

DEFAULTS = dict(U=15.0, V=0.0, Cw=7.4e-3 * 6.5 / 5.8, Nm=0.005, Hw=2500.0,
                tau_c=1000.0, tau_f=1000.0, P0=0.0)
# Cw = rho_Sref * Gamma_m / gamma  (eq. 4) with the abstract's values
# 7.4 g m^-3, -6.5 / -5.8 C km^-1  ->  8.29e-3 kg m^-3.


def transfer(k, l, p):
    """Transfer function T(k,l) of eq. (2): Phat = T * hhat.  Returns complex."""
    sigma = p["U"] * k + p["V"] * l
    if abs(sigma) < 1e-12:
        return 0j
    K2 = k * k + l * l
    m2 = (p["Nm"] ** 2 - sigma * sigma) / (sigma * sigma) * K2
    if m2 >= 0.0:
        m = math.copysign(math.sqrt(m2), sigma)      # propagating: sgn(sigma) sqrt
        dyn = 1.0 - 1j * m * p["Hw"]
    else:
        dyn = 1.0 + math.sqrt(-m2) * p["Hw"]          # evanescent m = +i sqrt(-m2): 1 - i(i r)H = 1 + rH
    cloud = (1.0 + 1j * sigma * p["tau_c"]) * (1.0 + 1j * sigma * p["tau_f"])
    return p["Cw"] * 1j * sigma / (dyn * cloud)


def cloud_transfer(k, l, p):
    """Transfer function of the cloud water qc (derived from eq. 1a):
    qchat = tau_c * Shat_dyn / (1 + i sigma tau_c),  Shat_dyn = Cw i sigma hhat / (1 - i m Hw)."""
    sigma = p["U"] * k + p["V"] * l
    if abs(sigma) < 1e-12:
        return 0j
    K2 = k * k + l * l
    m2 = (p["Nm"] ** 2 - sigma * sigma) / (sigma * sigma) * K2
    if m2 >= 0.0:
        dyn = 1.0 - 1j * math.copysign(math.sqrt(m2), sigma) * p["Hw"]
    else:
        dyn = 1.0 + math.sqrt(-m2) * p["Hw"]
    return p["Cw"] * 1j * sigma * p["tau_c"] / (dyn * (1.0 + 1j * sigma * p["tau_c"]))


def next_pow2(v):
    n = 1
    while n < v:
        n *= 2
    return n


def lt_2d(h, n, dx, params, truncate=True, want_qc=False, pad_n=None):
    """Precipitation (mm/h) over the n x n height map h (flat row-major list,
    y major, metres), cell size dx metres.  The map is zero-padded to
    pad_n x pad_n (default 2n), centred.  Returns P, or (P, qc) with want_qc
    (qc in kg m^-2)."""
    p = dict(DEFAULTS)
    p.update(params)
    N = pad_n or 2 * n
    off = (N - n) // 2
    g = [[0j] * N for _ in range(N)]
    for y in range(n):
        for x in range(n):
            g[y + off][x + off] = complex(h[y * n + x])
    H = fft2(g)
    PH = [[0j] * N for _ in range(N)]
    QH = [[0j] * N for _ in range(N)] if want_qc else None
    for jy in range(N):
        if jy == N // 2:
            continue
        l = 2 * math.pi * freq(jy, N) / (N * dx)
        for jx in range(N):
            if jx == N // 2:
                continue
            k = 2 * math.pi * freq(jx, N) / (N * dx)
            PH[jy][jx] = transfer(k, l, p) * H[jy][jx]
            if want_qc:
                QH[jy][jx] = cloud_transfer(k, l, p) * H[jy][jx]
    Pg = fft2(PH, inverse=True)
    sc = 3600.0 / (N * N)
    P = []
    for y in range(n):
        for x in range(n):
            v = Pg[y + off][x + off].real * sc + p["P0"]
            P.append(max(v, 0.0) if truncate else v)
    if not want_qc:
        return P
    Qg = fft2(QH, inverse=True)
    q = [Qg[y + off][x + off].real / (N * N) for y in range(n) for x in range(n)]
    return P, q


def lt_1d(h, dx, params, truncate=True, pad_n=None):
    """1-D version (l = 0, V ignored): same transfer function along x."""
    p = dict(DEFAULTS)
    p.update(params)
    n = len(h)
    N = pad_n or next_pow2(2 * n)
    off = (N - n) // 2
    g = [0j] * N
    for i in range(n):
        g[i + off] = complex(h[i])
    H = fft(g)
    PH = [0j] * N
    for j in range(N):
        if j == N // 2:
            continue
        k = 2 * math.pi * freq(j, N) / (N * dx)
        PH[j] = transfer(k, 0.0, p) * H[j]
    Pg = fft(PH, inverse=True)
    out = []
    for i in range(n):
        v = Pg[i + off].real * 3600.0 / N + p["P0"]
        out.append(max(v, 0.0) if truncate else v)
    return out


def upslope_2d(h, n, dx, p):
    """Raw upslope source Cw U.grad h (mm/h), centred differences (interior)."""
    out = [0.0] * (n * n)
    for y in range(1, n - 1):
        for x in range(1, n - 1):
            gx = (h[y * n + x + 1] - h[y * n + x - 1]) / (2 * dx)
            gy = (h[(y + 1) * n + x] - h[(y - 1) * n + x]) / (2 * dx)
            out[y * n + x] = p["Cw"] * (p["U"] * gx + p["V"] * gy) * 3600.0
    return out


# --------------------------------------------------------------------------
# Test terrains
# --------------------------------------------------------------------------


def gaussian_hill(n, dx, hm, a, cx=None, cy=None):
    cx = (n / 2.0) if cx is None else cx
    cy = (n / 2.0) if cy is None else cy
    return [hm * math.exp(-(((x - cx) * dx) ** 2 + ((y - cy) * dx) ** 2) / (a * a))
            for y in range(n) for x in range(n)]


def triangle_ridge_2d(n, dx, hm, d, cx=None):
    cx = (n / 2.0) if cx is None else cx
    return [max(hm * (1.0 - abs((x - cx) * dx) / d), 0.0) for y in range(n) for x in range(n)]


class Lcg:
    """Tiny deterministic generator for fixture terrains (32-bit LCG)."""
    def __init__(self, s):
        self.s = s & 0xFFFFFFFF

    def u(self):
        self.s = (self.s * 1664525 + 1013904223) & 0xFFFFFFFF
        return (self.s >> 8) / float(1 << 24)


def bumpy(n, dx, seed):
    r = Lcg(seed)
    h = [0.0] * (n * n)
    for _ in range(7):
        cx, cy = r.u() * n, r.u() * n
        a = (3 + 7 * r.u()) * dx
        hm = 200 + 700 * r.u()
        for y in range(n):
            for x in range(n):
                h[y * n + x] += hm * math.exp(-(((x - cx) * dx) ** 2 + ((y - cy) * dx) ** 2) / (a * a))
    # zero the outer 4-cell frame smoothly so the padded domain is tidy
    for y in range(n):
        for x in range(n):
            e = min(x, y, n - 1 - x, n - 1 - y)
            if e < 6:
                s = e / 6.0
                h[y * n + x] *= s * s * (3 - 2 * s)
    return h


def island(n, dx, seed):
    """Cone island with a rough rim: height 1500 m, radius ~ 0.4 n cells."""
    r = Lcg(seed)
    ph = [r.u() * 6.2831853 for _ in range(4)]
    am = [0.18, 0.1, 0.07, 0.04]
    h = [0.0] * (n * n)
    for y in range(n):
        for x in range(n):
            ux, uy = (x - n / 2.0) / n, (y - n / 2.0) / n
            rr = math.hypot(ux, uy)
            th = math.atan2(uy, ux)
            rad = 0.4 * (1 + sum(am[i] * math.cos((i + 2) * th + ph[i]) for i in range(4)))
            v = 1.0 - rr / rad
            h[y * n + x] = 1500.0 * v * v if v > 0 else 0.0
    return h


# fixtures: name -> (n, dx, params, truncate, terrain)
def fixture_cases():
    n, dx = 64, 1000.0
    return [
        ("gauss", n, dx, dict(U=8.0, V=0.0), True, gaussian_hill(n, dx, 800.0, 8000.0)),
        ("ridge", n, dx, dict(U=15.0, V=0.0, P0=0.0), False, triangle_ridge_2d(n, dx, 500.0, 15000.0)),
        ("bumpy", n, dx, dict(U=-5.0, V=6.0, tau_c=600.0, tau_f=1500.0, Hw=2000.0, P0=0.05), True, bumpy(n, dx, 7)),
        ("island", n, dx, dict(U=6.0, V=-3.0, Nm=0.01, Hw=3000.0, tau_c=1200.0, tau_f=800.0), True, island(n, dx, 11)),
    ]


FIXTURE_DIR = os.path.join(ROOT, "tests", "fixtures", "climate")
FIXTURE_MAGIC = 0x4C545231  # 'LTR1'


def write_fixtures():
    os.makedirs(FIXTURE_DIR, exist_ok=True)
    for name, n, dx, params, trunc, h in fixture_cases():
        p = dict(DEFAULTS)
        p.update(params)
        P, q = lt_2d(h, n, dx, p, truncate=trunc, want_qc=True)
        path = os.path.join(FIXTURE_DIR, "lt_%s.bin" % name)
        with open(path, "wb") as f:
            f.write(struct.pack("<ii", FIXTURE_MAGIC, n))
            f.write(struct.pack("<9d", dx, p["U"], p["V"], p["Cw"], p["Nm"], p["Hw"], p["tau_c"], p["tau_f"], p["P0"]))
            f.write(struct.pack("<i", 1 if trunc else 0))
            f.write(struct.pack("<i", 0))
            for arr in (h, P, q):
                f.write(struct.pack("<%df" % (n * n), *arr))
        print("wrote", os.path.relpath(path, ROOT), "max P %.3f mm/h" % max(P))


# --------------------------------------------------------------------------
# Checks
# --------------------------------------------------------------------------


def exact_triangle(x, U, Cw, tau, A=500.0, d=15000.0):
    """Exact solution of (1a,1b) with Hw = 0, tau_c = 0, tau_f = tau over the
    triangle ridge h = A (1 - |x|/d).  Derived here from U dq/dx = S - q/tau,
    P = q/tau, S = Cw U h'; the same closed form is in the PISM LTOP test
    (triangle_ridge_exact).  Returns mm/h, truncated at 0."""
    C = Cw * U * A / d
    Ut = U * tau
    if -d <= x < 0:
        v = C * (1.0 - math.exp(-(x + d) / Ut))
    elif x >= 0:
        v = C * (math.exp(-x / Ut) * (2.0 - math.exp(-d / Ut)) - 1.0)
    else:
        v = 0.0
    return max(v, 0.0) * 3600.0


def abstract_ridge(dx=250.0, half=120000.0):
    """The abstract's triangle ridge: hm 500 m, a = 15 km, rises from x = -15 km,
    U = 15 m/s, Nm 0.005, Hw 2500, tau 1000 s.  Returns x, h and the three curves."""
    n = int(2 * half / dx)
    xs = [-half + (i + 0.5) * dx for i in range(n)]
    h = [max(500.0 * (1.0 - abs(x) / 15000.0), 0.0) for x in xs]
    p = dict(DEFAULTS)
    raw = lt_1d(h, dx, dict(Hw=0.0, tau_c=0.0, tau_f=0.0), truncate=False)
    dyn = lt_1d(h, dx, dict(Hw=2500.0, tau_c=0.0, tau_f=0.0), truncate=False)
    full = lt_1d(h, dx, dict(Hw=2500.0, tau_c=1000.0, tau_f=1000.0), truncate=True)
    return xs, h, raw, dyn, full


def run_checks():
    ok = True

    def rep(name, cond, msg):
        nonlocal ok
        print(("PASS " if cond else "FAIL ") + name + ": " + msg)
        ok = ok and cond

    # 1. Cw from eq. 4 with the abstract's numbers -> 15 mm/h raw upslope on the triangle ridge
    cw = DEFAULTS["Cw"]
    raw_mm = cw * 15.0 * 500.0 / 15000.0 * 3600.0
    rep("abstract-raw", abs(raw_mm - 15.0) < 0.3, "Cw U hm/a = %.2f mm/h (abstract: 15 mm/hr)" % raw_mm)

    # 2. m = tau = 0 matches the exact upslope on the windward slope (1-D numeric LT, no truncation)
    xs, h, raw, dyn, full = abstract_ridge()
    mid = [raw[i] for i, x in enumerate(xs) if -13000 < x < -2000]
    rep("upslope-limit", max(abs(v - 14.9) for v in mid) < 0.3, "windward slope %.2f..%.2f mm/h (exact 14.9)" % (min(mid), max(mid)))

    # 3. exact triangle ridge with one delay (Hw = 0, tau_c = 0), numeric LT vs closed form
    dx = 125.0
    n = 2048
    xs2 = [-128000.0 + (i + 0.5) * dx for i in range(n)]
    h2 = [max(500.0 * (1.0 - abs(x) / 15000.0), 0.0) for x in xs2]
    num = lt_1d(h2, dx, dict(Hw=0.0, tau_c=0.0, tau_f=1000.0), truncate=True)
    ex = [exact_triangle(x, 15.0, cw, 1000.0) for x in xs2]
    err = max(abs(a - b) for a, b in zip(num, ex))
    rep("exact-ridge", err < 0.25, "max |numeric - closed form| = %.3f mm/h (peak %.2f)" % (err, max(ex)))

    # 4. abstract: dynamics shifts the peak upwind of the delay-only case; delays shift it downstream
    def argmax(a):
        return xs[max(range(len(a)), key=lambda i: a[i])]

    xp_raw = max(raw)
    # dynamics: source S peaks upstream of the slope break; condensation maximum shifts upwind and total falls
    rep("dyn-reduces", sum(max(v, 0) for v in dyn) < 0.9 * sum(max(v, 0) for v in raw),
        "dynamics-only positive total %.0f vs raw %.0f" % (sum(max(v, 0) for v in dyn), sum(max(v, 0) for v in raw)))
    xs_dyn_peak = argmax(dyn)
    xs_full_peak = argmax(full)
    rep("full-peak-near-top", abs(xs_full_peak) < 5000.0, "full-model peak at x = %.1f km, %.2f mm/h (abstract: ~3 mm/hr near the hill top)" % (xs_full_peak / 1000.0, max(full)))
    rep("delay-shifts-downstream", xs_full_peak > xs_dyn_peak, "peak x: dynamics %.1f km -> with delays %.1f km" % (xs_dyn_peak / 1000.0, xs_full_peak / 1000.0))
    neg_up = [x for x, v in zip(xs, dyn) if v < 0 and -15000 < x < 0]
    rep("source-negative-upstream-of-crest", len(neg_up) > 0 and min(neg_up) > -15000 and max(neg_up) < 0,
        "S_dyn < 0 for x in %.1f..%.1f km (abstract: negative slightly upstream of the crest)" % (min(neg_up) / 1000.0, max(neg_up) / 1000.0) if neg_up else "none")

    # 5. Hermitian/rotation: wind rotated 90 deg and map rotated 90 deg agree (2-D)
    n3, dx3 = 16, 2000.0
    h3 = bumpy(n3, dx3, 3)
    pA = lt_2d(h3, n3, dx3, dict(U=7.0, V=2.0))
    # map rotation: new[y][x] = old[x][n-1-y] sends the old point (xo,yo) to (yo, n-1-xo),
    # i.e. the vector (a,b) -> (b,-a); so the wind (U,V) = (7,2) becomes (2,-7)
    h3r = [h3[x * n3 + (n3 - 1 - y)] for y in range(n3) for x in range(n3)]
    pB = lt_2d(h3r, n3, dx3, dict(U=2.0, V=-7.0))
    pAr = [pA[x * n3 + (n3 - 1 - y)] for y in range(n3) for x in range(n3)]
    e = max(abs(a - b) for a, b in zip(pAr, pB)) / max(max(pA), 1e-9)
    rep("rotation", e < 1e-9, "rotated wind vs rotated map: rel err %.2e" % e)
    return ok


# --------------------------------------------------------------------------
# Figure (plain-Python raster -> PPM -> ImageMagick for text and JPG)
# --------------------------------------------------------------------------


class Canvas:
    def __init__(self, w, h, bg=(255, 255, 255)):
        self.w, self.h = w, h
        self.px = bytearray(bytes(bg) * (w * h))
        self.labels = []

    def set(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            i = 3 * (y * self.w + x)
            self.px[i:i + 3] = bytes(c)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(max(y0, 0), min(y1, self.h)):
            for x in range(max(x0, 0), min(x1, self.w)):
                self.set(x, y, c)

    def line(self, x0, y0, x1, y1, c, th=1):
        dx, dy = x1 - x0, y1 - y0
        steps = int(max(abs(dx), abs(dy), 1))
        for i in range(steps + 1):
            x = x0 + dx * i / steps
            y = y0 + dy * i / steps
            for ox in range(-(th // 2), th - th // 2):
                for oy in range(-(th // 2), th - th // 2):
                    self.set(int(round(x)) + ox, int(round(y)) + oy, c)

    def dashed(self, x0, y0, x1, y1, c, th=2, on=8, off=5):
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy)
        pos = 0.0
        while pos < L:
            e = min(pos + on, L)
            self.line(x0 + dx * pos / L, y0 + dy * pos / L, x0 + dx * e / L, y0 + dy * e / L, c, th)
            pos += on + off

    def text(self, x, y, s, size=14, color="black"):
        self.labels.append((x, y, s, size, color))

    def save(self, path_jpg):
        ppm = path_jpg + ".ppm"
        with open(ppm, "wb") as f:
            f.write(b"P6\n%d %d\n255\n" % (self.w, self.h))
            f.write(self.px)
        cmd = ["convert", ppm, "-font", "Adwaita-Sans"]
        for x, y, s, size, col in self.labels:
            cmd += ["-pointsize", str(size), "-fill", col, "-annotate", "+%d+%d" % (x, y + size), s]
        cmd += ["-quality", "88", path_jpg]
        subprocess.run(cmd, check=True, stderr=subprocess.DEVNULL)
        os.remove(ppm)


def ramp(t):
    stops = [(0.0, (30, 20, 80)), (0.25, (30, 90, 160)), (0.5, (40, 160, 130)), (0.75, (230, 210, 60)), (1.0, (250, 250, 235))]
    t = min(max(t, 0.0), 1.0)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            u = (t - t0) / (t1 - t0)
            return tuple(int(c0[i] + (c1[i] - c0[i]) * u) for i in range(3))
    return stops[-1][1]


def plot_curves(cv, x0, y0, w, h, xs, series, xr, yr, title, xlabel, ylabel):
    """series: list of (values, color, thickness, dashed_bool, label, terrain_bool)."""
    cv.rect(x0, y0, x0 + w, y0 + h, (250, 250, 250))
    cv.line(x0, y0, x0 + w, y0, (0, 0, 0)); cv.line(x0, y0 + h, x0 + w, y0 + h, (0, 0, 0))
    cv.line(x0, y0, x0, y0 + h, (0, 0, 0)); cv.line(x0 + w, y0, x0 + w, y0 + h, (0, 0, 0))

    def X(v): return x0 + (v - xr[0]) / (xr[1] - xr[0]) * w
    def Y(v): return y0 + h - (v - yr[0]) / (yr[1] - yr[0]) * h

    # grid and zero line
    ystep = 5 if yr[1] - yr[0] > 8 else 0.25
    gy = math.ceil(yr[0] / ystep) * ystep
    while gy <= yr[1] + 1e-9:
        cv.line(x0, Y(gy), x0 + w, Y(gy), (225, 225, 225) if abs(gy) > 1e-9 else (120, 120, 120))
        cv.text(x0 - 34, Y(gy) - 8, "%g" % gy, 12)
        gy += ystep
    gx = math.ceil(xr[0] / 10.0) * 10
    while gx <= xr[1]:
        cv.line(X(gx), y0, X(gx), y0 + h, (235, 235, 235))
        cv.text(X(gx) - 10, y0 + h + 4, "%g" % gx, 12)
        gx += 10
    for vals, col, th, dsh, lab, _ in series:
        pts = [(X(xv), Y(min(max(v, yr[0]), yr[1]))) for xv, v in zip(xs, vals) if xr[0] <= xv <= xr[1]]
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            if dsh:
                cv.dashed(ax, ay, bx, by, col, th, 6, 4)
            else:
                cv.line(ax, ay, bx, by, col, th)
    cv.text(x0, y0 - 22, title, 15)
    cv.text(x0 + w // 2 - 40, y0 + h + 22, xlabel, 12)
    cv.text(x0 - 36, y0 - 6, ylabel, 12)
    ly = y0 + 6
    for vals, col, th, dsh, lab, _ in series:
        cv.line(x0 + w - 270, ly + 7, x0 + w - 245, ly + 7, col, th)
        cv.text(x0 + w - 238, ly - 1, lab, 12)
        ly += 17


def make_figure():
    W, Hh = 1280, 1240
    cv = Canvas(W, Hh)
    cv.text(20, 8, "Smith & Barstad linear theory: reference (tools/climate/lt_ref.py, plain Python)", 18)

    # --- panel A: the abstract's triangle ridge
    xs, h, raw, dyn, full = abstract_ridge()
    xk = [x / 1000.0 for x in xs]
    hs = [v / 500.0 * 6.0 - 6.0 for v in h]      # terrain drawn as a -6..0 band
    series = [
        (hs, (150, 150, 150), 2, False, "terrain (500 m, drawn scaled)", True),
        (raw, (0, 0, 0), 2, False, "raw upslope (m = tau = 0)", False),
        (dyn, (200, 40, 40), 2, True, "dynamics only (Hw 2500 m)", False),
        (full, (30, 80, 200), 3, True, "dynamics + delays (tau 1000 s), P>=0", False),
    ]
    plot_curves(cv, 70, 70, 560, 300, xk, series, (-40, 40), (-16, 16),
                "A. Triangle ridge, abstract Fig. 1 (U 15 m/s, flow left to right)", "x (km)", "mm/h")

    # --- panel B: Gaussian 1-D profiles for several H~ and tau~ (BS05 Fig.1 nondimensional numbers)
    a = 20000.0
    dxg = 500.0
    ng = 512
    xg = [(-128000.0 + (i + 0.5) * dxg) for i in range(ng)]
    hg = [500.0 * math.exp(-(x / a) ** 2) for x in xg]
    U, Nm = 15.0, 0.005
    cases = [("H~0 tau~0", 0.0, 0.0, (0, 0, 0), False), ("H~1 tau~0", 1.0, 0.0, (200, 40, 40), False),
             ("H~0 tau~1", 0.0, 1.0, (40, 150, 60), False), ("H~1 tau~1", 1.0, 1.0, (30, 80, 200), False),
             ("H~2 tau~2", 2.0, 2.0, (150, 60, 190), True)]
    norm = None
    ser = [([v / 500.0 * 0.6 - 0.1 for v in hg], (150, 150, 150), 2, False, "terrain (scaled)", True)]
    for lab, Ht, tt, col, dsh in cases:
        Hw = Ht * U / Nm
        tau = tt * a / U
        P = lt_1d(hg, dxg, dict(U=U, Hw=Hw, tau_c=tau, tau_f=tau), truncate=True)
        if norm is None:
            norm = max(P)   # raw upslope maximum
        ser.append(([v / norm for v in P], col, 2, dsh, lab, False))
    plot_curves(cv, 700, 70, 540, 300, [x / 1000.0 for x in xg], ser, (-80, 80), (-0.15, 1.1),
                "B. 2-D-ridge Gaussian (a 20 km), normalised by raw peak", "x (km)", "P / P_raw,max")

    # --- panel C: BS05 Fig.1-style maps: normalised precipitation vs (H~, tau~) at three points of a 2-D Gaussian hill
    n, dx = 32, 5000.0       # 160 km box
    ahl = 20000.0
    hh = gaussian_hill(n, dx, 500.0, ahl)
    c = n // 2
    steps = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
    tsteps = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]
    ix_up = c - int(round(ahl / dx))
    ix_dn = c + int(round(ahl / dx))
    raw_up = None
    grid = {}
    for i, Ht in enumerate(steps):
        for j, tt in enumerate(tsteps):
            P = lt_2d(hh, n, dx, dict(U=U, V=0.0, Hw=Ht * U / Nm, tau_c=tt * ahl / U, tau_f=tt * ahl / U), truncate=True)
            grid[(i, j)] = (P[c * n + ix_up], P[c * n + c], P[c * n + ix_dn])
    ref = grid[(0, 0)][0]
    titles = ["upslope point (x = -a)", "peak (x = 0)", "downslope point (x = +a)"]
    for pi in range(3):
        bx, by = 70 + pi * 410, 470
        cell = 52
        for i in range(len(steps)):
            for j in range(len(tsteps)):
                v = grid[(i, j)][pi] / ref
                cv.rect(bx + j * cell, by + (len(steps) - 1 - i) * cell, bx + (j + 1) * cell - 1, by + (len(steps) - i) * cell - 1, ramp(v / 1.2))
                cv.text(bx + j * cell + 8, by + (len(steps) - 1 - i) * cell + 18, "%.2f" % v, 11, "white" if v < 0.55 / 1.0 * 1.0 else "black")
        cv.text(bx, by - 42, "C%d. %s" % (pi + 1, titles[pi]), 14)
        cv.text(bx, by - 22, "x: tau~ = U tau / a (0..2.5)    y: H~ = N Hw / U (0..2.5, up)", 11)
        cv.text(bx, by + len(steps) * cell + 6, "values normalised by the raw upslope value at x = -a (BS05 Fig. 1)", 11)

    # --- panel D: 2-D maps for the Gaussian hill, raw vs full
    n2, dx2 = 64, 2000.0
    hh2 = gaussian_hill(n2, dx2, 500.0, 20000.0)
    Pr = lt_2d(hh2, n2, dx2, dict(U=15.0, Hw=0.0, tau_c=0.0, tau_f=0.0), truncate=True)
    Pf = lt_2d(hh2, n2, dx2, dict(U=15.0, Hw=2500.0, tau_c=1000.0, tau_f=1000.0), truncate=True)
    mx = max(Pr)
    for pi, (arr, ttl) in enumerate([(Pr, "D1. raw upslope, truncated"), (Pf, "D2. full model (Hw 2500 m, tau 1000 s)")]):
        bx, by = 70 + pi * 410, 880
        s = 5
        for y in range(n2):
            for x in range(n2):
                v = arr[y * n2 + x] / mx
                cv.rect(bx + x * s, by + y * s, bx + (x + 1) * s, by + (y + 1) * s, ramp(v))
        cv.text(bx, by - 24, ttl + "  (max %.1f mm/h)" % max(arr), 14)
        cv.line(bx + 8, by + 14, bx + 60, by + 14, (255, 255, 255), 2)
        cv.line(bx + 60, by + 14, bx + 52, by + 8, (255, 255, 255), 2)
        cv.line(bx + 60, by + 14, bx + 52, by + 20, (255, 255, 255), 2)
        cv.text(bx + 8, by + 20, "wind", 11, "white")
    cv.text(70 + 2 * 410 - 10, 860, "Reading the figure", 14)
    notes = ["A: dynamics lowers and shifts the condensation", "   upwind (source goes negative just upstream of", "   the crest); the delays cut it again and move the", "   peak downstream, near the crest (~3 mm/h).", "B/C: bigger H~ or tau~ lowers the windward value;", "   a longer delay pushes water onto the lee side.", "D: plan view, wind to the right."]
    for i, s_ in enumerate(notes):
        cv.text(70 + 2 * 410 - 10, 885 + i * 18, s_, 12)
    out = os.path.join(ROOT, "docs", "evidence", "island", "climate", "ref", "lt_ref.jpg")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    cv.save(out)
    print("wrote", os.path.relpath(out, ROOT))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "check"
    if cmd == "check":
        sys.exit(0 if run_checks() else 1)
    elif cmd == "figure":
        make_figure()
    elif cmd == "fixtures":
        write_fixtures()
    else:
        print(__doc__)
        sys.exit(2)
