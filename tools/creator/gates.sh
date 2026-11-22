#!/usr/bin/env bash
# Gate suites for the creator scorecard: studio, ui and first-quest e2e (the e2e opens the editor). Writes <outdir>/gates.json
# {"studio": "pass|fail|skip", "ui": ..., "first_quest": ..., "secs": {...}}. Usage: tools/creator/gates.sh <outdir> [quick]
# "quick" skips the (long) first-quest e2e and records it as "skip". Headless Godot only, nice, timeouts, no GPU.
set -u
OUT=${1:?outdir}
QUICK=${2:-}
GODOT=${GODOT:-godot}
mkdir -p "$OUT"
cd "$(dirname "$0")/../.."
res=()
run() { # name cmd...
  local name=$1; shift
  local t0=$SECONDS
  if "$@" > "$OUT/.gate_$name.log" 2>&1; then r=pass; else r=fail; fi
  res+=("\"$name\": \"$r\"")
  secs+=("\"$name\": $((SECONDS - t0))")
  echo "gate $name: $r ($((SECONDS - t0)) s)"
}
secs=()
run studio bash -c "nice -n 10 timeout 600 $GODOT --headless --path godot/studio --script res://tests/test_studio.gd && node godot/studio/tests/node_check.js"
run ui nice -n 10 timeout 600 $GODOT --headless --path godot --script res://tests/ui_test.gd
if [ "$QUICK" = quick ]; then
  res+=("\"first_quest\": \"skip\""); secs+=("\"first_quest\": 0")
else
  run first_quest nice -n 10 timeout 1500 $GODOT --headless --fixed-fps 60 --path godot --script res://game/tests/first_quest_e2e.gd
fi
printf '{%s, "secs": {%s}}\n' "$(IFS=,; echo "${res[*]}")" "$(IFS=,; echo "${secs[*]}")" > "$OUT/gates.json"
rm -f "$OUT"/.gate_*.log.keep
