#!/usr/bin/env python3
"""Drainage metrics for a terrain dump, or a fresh generate via terrain_cli.

Strahler bifurcation ratio Rb is the slope of Horton's law
(log N_w = a - w log Rb) when at least three orders exist, otherwise the
mean of N_w / N_{w+1}. Hack's exponent is the OLS slope of
log(main-stream length) on log(drainage area) at independent basin outlets.
A second pooled fit at junctions + outlets is reported as a sensitivity check.
Hypsometric integral is (mean - min) / (max - min).

Channel cells are those whose D8 contributing area exceeds --area m².
Directions are the generator's, stored in the dump, so the tree matches
the flow map.
"""
import argparse
import math
import json
from pathlib import Path
import struct
import subprocess
import sys

DX = [1, 1, 0, -1, -1, -1, 0, 1]
DY = [0, 1, 1, 1, 0, -1, -1, -1]


def load_dump(path):
    with open(path, "rb") as f:
        blob = f.read()
    if len(blob)<28:
        raise ValueError(f"{path}: incomplete header")
    magic, version, seed, n, size, flags = struct.unpack_from("<8sIIifI", blob, 0)
    if magic != b"CPTER10\x00":
        raise ValueError(f"{path}: bad magic {magic!r}")
    if version!=1 or not 8<=n<=2048 or not math.isfinite(size) or size<=0 or flags not in (0,1):
        raise ValueError(f"{path}: invalid terrain header")
    nn = n * n
    off = 28
    need = off + nn * 4 * 3 + nn
    if len(blob) != need:
        raise ValueError(f"{path}: expected {need} bytes, got {len(blob)}")
    height = struct.unpack_from(f"<{nn}f", blob, off)
    off += nn * 4
    flow = struct.unpack_from(f"<{nn}f", blob, off)
    off += nn * 4
    sediment = struct.unpack_from(f"<{nn}f", blob, off)
    off += nn * 4
    dirs = struct.unpack_from(f"<{nn}b", blob, off)
    if not all(math.isfinite(v) for v in height+flow+sediment):
        raise ValueError(f"{path}: nonfinite map")
    for i,d in enumerate(dirs):
        if not -1<=d<=7 or (d>=0 and not (0<=i%n+DX[d]<n and 0<=i//n+DY[d]<n)):
            raise ValueError(f"{path}: invalid flow direction at {i}")
    return {
        "version": version, "seed": seed, "n": n, "size": size, "flags": flags,
        "height": height, "flow": flow, "sediment": sediment, "dir": dirs,
    }


def recv_of(n, dirs, i):
    d = dirs[i]
    if d < 0:
        return -1
    x, y = i % n, i // n
    return (y + DY[d]) * n + (x + DX[d])


def metrics(dump, area_m2, pooled=False):
    if not math.isfinite(area_m2) or area_m2<=0:
        raise ValueError("channel area must be finite and positive")
    n = dump["n"]
    size = dump["size"]
    cell = size / n
    cell_area = cell * cell
    nn = n * n
    height = dump["height"]
    flow = dump["flow"]
    dirs = dump["dir"]
    min_cells = max(1.0, area_m2 / cell_area)
    channel = [flow[i] * nn >= min_cells for i in range(nn)]

    preds = [[] for _ in range(nn)]
    recv = [-1] * nn
    for i in range(nn):
        r = recv_of(n, dirs, i)
        recv[i] = r
        if r >= 0:
            preds[r].append(i)

    indeg = [0] * nn
    for i in range(nn):
        if recv[i] >= 0:
            indeg[recv[i]] += 1
    queue = [i for i in range(nn) if indeg[i] == 0]
    order = [0] * nn
    longest = [0.0] * nn
    qh = 0
    while qh < len(queue):
        i = queue[qh]
        qh += 1
        # Hack length starts at the drainage divide, not at the channel
        # threshold. Truncating L but retaining total A biases h upward.
        ix, iy = i % n, i // n
        for pred in preds[i]:
            px, py = pred % n, pred // n
            dist = cell * (math.sqrt(2.0) if px != ix and py != iy else 1.0)
            longest[i] = max(longest[i], longest[pred] + dist)
        if channel[i]:
            ups = [p for p in preds[i] if channel[p]]
            if not ups:
                order[i] = 1
            else:
                counts = {}
                for p in ups:
                    counts[order[p]] = counts.get(order[p], 0) + 1
                m = max(counts)
                order[i] = m + 1 if counts[m] >= 2 else m
        r = recv[i]
        if r >= 0:
            indeg[r] -= 1
            if indeg[r] == 0:
                queue.append(r)

    if len(queue)!=nn:
        raise ValueError("flow directions contain a cycle")

    # One segment per run of a given order: count its downstream end.
    seg = {}
    outlets = []
    for i in range(nn):
        if order[i] < 1:
            continue
        r = recv[i]
        ends = r < 0 or not channel[r] or order[r] != order[i]
        if ends:
            seg[order[i]] = seg.get(order[i], 0) + 1
            outlets.append(i)

    orders_present = sorted(seg)
    ratios = []
    for w in orders_present:
        nxt = seg.get(w + 1, 0)
        if nxt:
            ratios.append(seg[w] / nxt)
    rb = None
    rb_how = "none"
    if len(orders_present) >= 3:
        # log N = a - w log(Rb). Slope of log N vs w is -log(Rb).
        xs = orders_present
        ys = [math.log(seg[w]) for w in xs]
        mx = sum(xs) / len(xs)
        my = sum(ys) / len(ys)
        var = sum((x - mx) ** 2 for x in xs)
        if var > 0:
            slope = sum((x - mx) * (y - my) for x, y in zip(xs, ys)) / var
            if slope < 0:
                rb = math.exp(-slope)
                rb_how = "horton"
    if rb is None and ratios:
        rb = sum(ratios) / len(ratios)
        rb_how = "mean"

    # Hack uses independent basins. Nested junction samples are correlated;
    # include them only in the explicitly labelled sensitivity fit.
    points = []
    for i in range(nn):
        if order[i] < 1 or longest[i] <= cell:
            continue
        n_up = sum(1 for p in preds[i] if channel[p])
        r = recv[i]
        is_outlet = r < 0 or not channel[r]
        if is_outlet or (pooled and n_up >= 2):
            area = flow[i] * size * size
            if area > 0 and longest[i] > 0:
                points.append((math.log(area), math.log(longest[i])))
    hack = None
    hack_r2 = None
    if len(points) >= 8:
        xs = [p[0] for p in points]
        ys = [p[1] for p in points]
        mx = sum(xs) / len(xs)
        my = sum(ys) / len(ys)
        var = sum((x - mx) ** 2 for x in xs)
        if var > 0:
            cov = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
            hack = cov / var
            vary = sum((y - my) ** 2 for y in ys)
            hack_r2 = (cov * cov) / (var * vary) if vary > 0 else 0.0

    hmin = min(height)
    hmax = max(height)
    hmean = sum(height) / nn
    hypo = (hmean - hmin) / (hmax - hmin) if hmax > hmin else 0.0
    n_channel = sum(1 for c in channel if c)
    return {
        "n": n, "size": size, "seed": dump["seed"], "flags": dump["flags"],
        "area_m2": area_m2, "min_cells": min_cells, "hack_sampling": "pooled" if pooled else "outlets",
        "channel_cells": n_channel, "segments": seg, "ratios": ratios,
        "rb": rb, "rb_how": rb_how, "hack": hack, "hack_r2": hack_r2, "hack_n": len(points),
        "hypsometric": hypo, "hmin": hmin, "hmax": hmax, "hmean": hmean,
    }


def dist_range(x, lo, hi):
    if x is None:
        return None
    if x < lo:
        return lo - x
    if x > hi:
        return x - hi
    return 0.0


def fmt(m):
    seg = " ".join(f"{k}:{v}" for k, v in sorted(m["segments"].items())) or "-"
    rb = f"{m['rb']:.3f}" if m["rb"] is not None else "n/a"
    hack = f"{m['hack']:.3f}" if m["hack"] is not None else "n/a"
    r2 = f"{m['hack_r2']:.2f}" if m.get("hack_r2") is not None else "n/a"
    return (
        f"seed {m['seed']} n {m['n']} channels {m['channel_cells']} "
        f"orders [{seg}] Rb {rb} ({m['rb_how']}) "
        f"h {hack} r2 {r2} (n={m['hack_n']}) HI {m['hypsometric']:.3f} "
        f"height [{m['hmin']:.1f}, {m['hmax']:.1f}]"
    )


def generate(cli, seed, n, droplets, thermal, path):
    cmd = [cli, "dump", "--seed", str(seed), "--n", str(n),
           "--droplets", str(droplets), "--thermal", str(thermal), "--out", path]
    subprocess.check_call(["nice", "-n", "10", *cmd])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("dumps", nargs="*")
    ap.add_argument("--pooled", action="store_true", help="sensitivity fit using nested junctions + outlets")
    ap.add_argument("--check", action="store_true", help="require eroded metric gaps no worse for each seed and better in aggregate")
    ap.add_argument("--json", help="write machine-readable metrics to this file")
    ap.add_argument("--area", type=float, default=8000.0, help="channel threshold, m^2")
    ap.add_argument("--cli")
    ap.add_argument("--seeds", default="1,7,42")
    ap.add_argument("--n", type=int, default=1024)
    ap.add_argument("--droplets", type=int, default=70000)
    ap.add_argument("--thermal", type=int, default=5)
    ap.add_argument("--workdir", default="/tmp")
    args = ap.parse_args()
    rows = []
    if args.cli:
        Path(args.workdir).mkdir(parents=True,exist_ok=True)
        for seed in [int(s) for s in args.seeds.split(",") if s]:
            for kind, drops, thermal in (("base", 0, 0), ("eroded", args.droplets, args.thermal)):
                path = f"{args.workdir}/terrain-{kind}-{seed}.bin"
                generate(args.cli, seed, args.n, drops, thermal, path)
                m = metrics(load_dump(path), args.area, args.pooled)
                m["kind"] = kind
                rows.append(m)
                print(f"{kind:7} {fmt(m)}")
        print()
        by = {}
        for m in rows:
            by.setdefault(m["seed"], {})[m["kind"]] = m
        for seed, pair in by.items():
            b, e = pair.get("base"), pair.get("eroded")
            if not b or not e:
                continue
            db = (dist_range(b["rb"], 3, 5), dist_range(b["hack"], 0.5, 0.6))
            de = (dist_range(e["rb"], 3, 5), dist_range(e["hack"], 0.5, 0.6))
            def score(d):
                return None if d[0] is None or d[1] is None else d[0]/2 + d[1]/0.1
            print(f"seed {seed} normalised distance base {score(db)} eroded {score(de)} "
                  f"(Rb gap {db[0]} -> {de[0]}, h gap {db[1]} -> {de[1]})")
    else:
        if not args.dumps:
            ap.error("give dumps or --cli")
        for path in args.dumps:
            m = metrics(load_dump(path), args.area, args.pooled)
            rows.append(m)
            print(fmt(m))
    if args.check:
        if not args.cli:
            ap.error("--check requires --cli for paired base/eroded data")
        improvements=[]
        for seed,pair in by.items():
            def gap(m):
                a,b=dist_range(m["rb"],3,5),dist_range(m["hack"],.5,.6)
                return math.inf if a is None or b is None else a/2+b/.1
            before,after=gap(pair["base"]),gap(pair["eroded"])
            if not math.isfinite(after) or after>before+1e-6:
                raise SystemExit(f"natural structure FAIL: seed {seed} gap {before:.6f} -> {after:.6f}")
            improvements.append(before-after)
        if not improvements or sum(improvements)<=0:
            raise SystemExit("natural structure FAIL: no aggregate improvement")
        print("natural structure PASS: paired gaps non-worse; aggregate gap improved (outlet Hack fit)")
    if args.json:
        Path(args.json).write_text(json.dumps(rows,indent=2)+"\n")


if __name__ == "__main__":
    main()
