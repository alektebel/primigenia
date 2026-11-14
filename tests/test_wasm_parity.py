"""Compare every committed golden tick and every generated duel tick, byte for byte."""
from pathlib import Path
import subprocess


def run(*args):
    return subprocess.check_output(args, text=True)


logs = sorted(Path('tests/golden').glob('*.log'))
assert len(logs) >= 5, f'expected the 5 committed golden logs, found {len(logs)}'
golden_ticks = 0
for log in logs:
    expected = log.with_suffix('.hashes').read_text()
    actual = run('node', 'build/wasm/combat_golden.cjs', str(log))
    assert actual == expected, f'WASM golden mismatch: {log}'
    assert len(actual.splitlines()) == 10000
    golden_ticks += len(actual.splitlines())
print(f'WASM goldens: {len(logs)} logs, {golden_ticks} matching tick hashes', flush=True)
native = run('build/combat_parity', '--duels')
wasm = run('node', 'build/wasm/combat_parity.cjs', '--duels')
assert native == wasm, 'native/WASM bot duel hash streams differ'
counts = native.splitlines()[-1].split()
assert counts[0] == 'counts' and int(counts[1]) >= 200
assert sum(line.startswith('duel ') for line in native.splitlines()) == 200
print(f'Bot parity: {counts[1]} duels, {counts[2]} matching tick hashes; '
      '25 ordered bot pairings × 2 profile sets × 4 seeds')
