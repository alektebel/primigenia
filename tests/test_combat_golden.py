"""Compare fresh replay processes with committed per-tick hashes, never regenerate."""
from pathlib import Path
import subprocess
import sys

binary = sys.argv[1] if len(sys.argv) > 1 else "build/combat_golden"
seeds = (0, 1, 42, 987654321, 4294967295)
root = Path(__file__).resolve().parent / "golden"
for seed in seeds:
    log = root / f"combat-{seed}.log"
    expected = (root / f"combat-{seed}.hashes").read_text().splitlines()
    actual = subprocess.check_output([binary, str(log)], text=True).splitlines()
    if len(expected) != 10000 or len(actual) != 10000:
        raise AssertionError(f"seed {seed}: golden and replay must each have 10,000 ticks")
    for tick, (want, got) in enumerate(zip(expected, actual)):
        if want != got:
            raise AssertionError(f"seed {seed}, tick {tick}: expected {want}, got {got}")
    print(f"golden seed {seed}: 10,000 tick hashes match in a fresh process")
