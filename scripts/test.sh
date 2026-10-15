#!/usr/bin/env bash
# Runs all automated tests: unit tests, scenario tests (doc/test-scenarios.md) and an
# accelerated half-day simulation with invariant checks. Exit code != 0 on failure.
#   scripts/test.sh            # unit + scenarios + simulation
#   scripts/test.sh unit       # only unit tests
#   scripts/test.sh scenarios  # unit tests + scenarios
#   SEED=7 scripts/test.sh     # other random seed (default 1; same seed = same simulation)
#   WEB=1 scripts/test.sh      # additionally export web and take screenshots
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/scripts/godot.sh"   # memory-limited (see godot.sh)
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
"$ROOT/scripts/setup.sh" >/dev/null
fail=0
SEED="${SEED:-1}"

log "Import"
timeout 300 "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1
export SKIP_IMPORT=1   # the scripts below would import again

log "Unit tests"
out=$(timeout 300 "$GODOT" --headless --path "$ROOT" res://tests/test_runner.tscn 2>&1)
echo "$out" | grep -E "FAIL|tests,|SCRIPT ERROR"
echo "$out" | grep -q "tests, 0 failed" || fail=1
echo "$out" | grep -q "SCRIPT ERROR" && fail=1
[[ "${1:-}" == unit ]] && exit $fail

# The simulation runs next to the scenario files (4 Godot processes, ~2 GB together).
SIM="$(mktemp)"
trap 'rm -f "$SIM"' EXIT
if [[ "${1:-}" != scenarios ]]; then
  # 60 fps x 6 = 0.1 game s per frame; 7300 frames = 730 game minutes (09:00 -> ~21:10).
  FPS=60 "$ROOT/scripts/run_headless.sh" 7300 --seed=$SEED --save=simulation --time=9 --season=1 --weather=0 --speed=6 --stats=1 --city=1 >"$SIM" 2>&1 &
  sim_pid=$!
fi

log "Scenario tests"
SEED=$SEED "$ROOT/scripts/scenario.sh" || fail=1
[[ "${1:-}" == scenarios ]] && exit $fail

log "Simulation (half a day at 6x speed with the Oststadt, seed $SEED)"
wait "$sim_pid"
out=$(cat "$SIM")
echo "$out" | grep -E "TEST STATS|TEST INVARIANT|SCRIPT ERROR|unique issues" | cut -c1-200
echo "$out" | grep -q "SCRIPT ERROR" && fail=1
echo "$out" | grep -q "TEST INVARIANT" && { echo "invariant violated"; fail=1; }
stuck=$(echo "$out" | grep -o "stuck_total=[0-9]*" | tail -1 | cut -d= -f2)
if [[ -n "$stuck" && "$stuck" -gt 50 ]]; then echo "too many stuck walkers: $stuck"; fail=1; fi

if [[ "${WEB:-0}" == 1 ]]; then
  log "Web export + screenshots"
  "$ROOT/scripts/web_test.sh" || fail=1
fi
[[ $fail == 0 ]] && log "All tests passed" || log "TESTS FAILED"
exit $fail
