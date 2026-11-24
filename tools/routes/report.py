#!/usr/bin/env python3
"""Run real C route simulations; retain evidence even when certification fails."""
import argparse
from pathlib import Path
import subprocess
import sys

parser = argparse.ArgumentParser(__doc__)
parser.add_argument("seeds", nargs="*", type=int, default=[1, 7, 42])
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
subprocess.run([sys.executable, "tools/routes/fixtures.py", "--check"], cwd=root, check=True)
subprocess.run(["make", "build/routes_test"], cwd=root, check=True)
failed = False
for seed in args.seeds:
    result = subprocess.run(["nice", "-n", "10", "build/routes_test", "--island", "star", str(seed)],
                            cwd=root, text=True, stdout=subprocess.PIPE, check=False)
    print(result.stdout, end="")
    target = root / f"docs/evidence/routes/star-seed{seed}.md"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(result.stdout)
    failed |= result.returncode != 0
raise SystemExit(1 if failed else 0)
