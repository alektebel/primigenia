#!/usr/bin/env python3
"""Measure each terrain switch alone against unchanged v2 (same seed/work)."""
import argparse
import json
import subprocess
from pathlib import Path
from metrics import load_dump

SWITCHES = ('gentle-bases', 'layout-variety', 'cliff-bands', 'sea-cliffs', 'hard-rock', 'volcano', 'caves')


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--cli', default='build/terrain_cli')
    ap.add_argument('--seed', type=int, default=42)
    ap.add_argument('--n', type=int, default=1024)
    ap.add_argument('--out', default='build/terrain/ablations.json')
    ap.add_argument('--workdir', default='build/terrain/ablations', help='scratch directory for binary maps')
    ap.add_argument('--v2cc', action='store_true', help='measure cliffs/strata separately, together, and with caves')
    args = ap.parse_args()
    dest = Path(args.out)
    dest.parent.mkdir(parents=True, exist_ok=True)
    workdir = Path(args.workdir)
    workdir.mkdir(parents=True, exist_ok=True)
    baseline = None
    rows = []
    variants = (None, 'cliff-bands', 'sea-cliffs', 'hard-rock', 'cliffs-strata', 'cliffs-strata-caves') if args.v2cc else (None, *SWITCHES)
    for enabled in variants:
        path = workdir / f'ablation-{enabled or "v2"}.bin'
        cmd = [args.cli, 'dump', '--seed', str(args.seed), '--n', str(args.n), '--out', str(path)]
        active = {'cliff-bands', 'sea-cliffs', 'hard-rock'} if enabled in ('cliffs-strata', 'cliffs-strata-caves') else {enabled}
        if enabled == 'cliffs-strata-caves':
            active.add('caves')
        for switch in SWITCHES:
            cmd += ['--' + switch, str(int(switch in active))]
        subprocess.run(['nice', '-n', '10', *cmd], check=True, stdout=subprocess.DEVNULL)
        terrain = load_dump(path)
        if baseline is None:
            baseline = terrain
        delta = [a-b for a, b in zip(terrain['height'], baseline['height'])]
        row = dict(switch=enabled or 'v2', changed_cells=sum(v != 0 for v in delta),
                   changed_fraction=sum(v != 0 for v in delta)/(args.n*args.n),
                   max_height_delta_m=max(map(abs, delta)), height_sum_delta_m=sum(delta),
                   volcanic_cells=terrain['material'].count(3), caves=len(terrain['caves']))
        rows.append(row)
        print(row)
    dest.write_text(json.dumps(dict(seed=args.seed, n=args.n, rows=rows), indent=2)+'\n')


if __name__ == '__main__':
    main()
