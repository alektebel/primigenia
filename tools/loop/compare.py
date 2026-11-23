#!/usr/bin/env python3
"""Compare two loop scorecard runs: tools/loop/compare.py <baseline> <label> [--root docs/evidence/loop/score] [--tol 0.20]
Per seed (metrics_<name>.json written by score.py): every metric with a direction is better, worse or the same; a metric that got
worse by more than --tol (default 20%, the plan's regression gate) is a REGRESSION and the exit code is 1. Labels may be paths."""
import glob, json, os, sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import score  # noqa: E402

ROOT = os.path.join(HERE, "..", "..", "docs", "evidence", "loop", "score")
# lower is better unless listed here
HIGHER = {"species_10min", "species_30min", "species_seen", "dna_at_editor", "dna_total", "walked_m", "bonds", "kills"}
NEUTRAL = {"run_s", "fights", "deaths", "evolves", "nest_visits", "flight_s", "editor_open_s", "part_found_s", "w_fire_s", "garfio_win_rate"}


def load(label):
    d = label if os.path.isdir(label) else os.path.join(ROOT, label)
    out = {}
    for f in sorted(glob.glob(os.path.join(d, "metrics_*.json"))):
        out[os.path.basename(f)[8:-5]] = json.load(open(f))["metrics"]
    return out


def main(argv):
    tol = 0.20
    args = list(argv)
    if "--tol" in args:
        i = args.index("--tol")
        tol = float(args[i + 1])
        del args[i:i + 2]
    root = None
    if "--root" in args:
        i = args.index("--root")
        global ROOT
        ROOT = args[i + 1]
        del args[i:i + 2]
    a, b = load(args[0]), load(args[1])
    keys = [k for k, *_ in score.TARGETS] + [k for k, *_ in score.BOT_ONLY] + ["walked_m", "dna_total", "species_seen", "kills", "bonds"]
    regress, better, same = [], [], 0
    for seed in sorted(set(a) & set(b)):
        for k in keys:
            va, vb = a[seed].get(k), b[seed].get(k)
            if k in NEUTRAL or va is None and vb is None:
                continue
            if va is None or vb is None:
                (regress if vb is None else better).append((seed, k, va, vb, "n/a" if vb is None else "now measured"))
                continue
            worse = (vb < va) if k in HIGHER else (vb > va)
            delta = abs(vb - va) / max(abs(va), 1e-9) if va else (0 if vb == va else 1)
            if delta <= 0.005:
                same += 1
            elif worse and delta > tol:
                regress.append((seed, k, va, vb, "%+.0f%%" % (100 * (vb - va) / max(abs(va), 1e-9))))
            elif worse:
                same += 1
            else:
                better.append((seed, k, va, vb, "%+.0f%%" % (100 * (vb - va) / max(abs(va), 1e-9))))
    print("# Loop compare %s -> %s (seeds in both: %s)\n" % (args[0], args[1], ", ".join(sorted(set(a) & set(b))) or "none"))
    print("better %d, regressed more than %d%%: %d, within tolerance %d\n" % (len(better), round(tol * 100), len(regress), same))
    for title, rows in (("Regressions", regress), ("Improved", better)):
        print("## %s\n\n| seed | metric | %s | %s | change |\n|---|---|---|---|---|" % (title, args[0], args[1]))
        for seed, k, va, vb, ch in rows:
            print("| %s | %s | %s | %s | %s |" % (seed, k, score.fmt(va), score.fmt(vb), ch))
        print()
    return 1 if regress else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
