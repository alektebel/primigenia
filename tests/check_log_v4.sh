#!/bin/sh
# Input log v4 (run column): a v2 golden rewritten as v4 with run=0 replays to the very same hashes; with run=1 from tick 100 the
# hashes match until tick 100 and differ after (the run toggle is set before the step); a bad run value is refused.
set -e
CLI=${1:-build/world_cli}; SRC=${2:-tests/golden/world-42.log}; OUT=${3:-build}
N=$(sed -n '/^[0-9][0-9]*$/{p;q}' "$SRC")        # the first lone integer line is the tick count
conv() { awk -v from="$1" -v to="$2" -v n="$N" 'NR==1{print "CPORE_WORLD_LOG 4";next} $0==n&&!s{s=NR;print;next} s&&NR<=s+n{t=NR-s-1;print $0, (t>=from&&t<to)?1:0;next} {print} END{print "0"}' "$SRC"; }
conv 0 0 > "$OUT/world-v4-zero.log"
$CLI --replay "$OUT/world-v4-zero.log" | diff -q - "${SRC%.log}.hashes" >/dev/null
conv 100 1500 > "$OUT/world-v4-run.log"
$CLI --replay "$OUT/world-v4-run.log" > "$OUT/world-v4-run.hashes"
head -100 "$OUT/world-v4-run.hashes" > "$OUT/world-v4-run.head"
head -100 "${SRC%.log}.hashes" | diff -q - "$OUT/world-v4-run.head" >/dev/null
! diff -q "$OUT/world-v4-run.hashes" "${SRC%.log}.hashes" >/dev/null
awk -v n="$N" '$0==n&&!s{s=NR} s&&NR==s+1{print $0 " 2";next} {print}' "$OUT/world-v4-zero.log" > "$OUT/world-v4-bad.log"
! $CLI --replay "$OUT/world-v4-bad.log" >/dev/null 2>&1
echo "input log v4: run=0 equals v2, the run column changes the hashes from its tick on, a bad run value is refused"
