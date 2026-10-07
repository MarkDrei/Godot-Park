#!/usr/bin/env bash
# Runs all automated tests: unit tests, a scripted play-through (smoke test)
# and an accelerated half-day simulation. Exit code != 0 on failure.
#   scripts/test.sh          # unit + smoke + simulation
#   scripts/test.sh unit     # only unit tests
#   WEB=1 scripts/test.sh    # additionally export web and take screenshots
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}/godot-${GODOT_VERSION:-4.7.2}/godot"
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
"$ROOT/scripts/setup.sh" >/dev/null
fail=0

log "Import"
timeout 300 "$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1

log "Unit tests"
out=$(timeout 300 "$GODOT" --headless --path "$ROOT" res://tests/test_runner.tscn 2>&1)
echo "$out" | grep -E "FAIL|tests,|SCRIPT ERROR"
echo "$out" | grep -q "tests, 0 failed" || fail=1
[[ "${1:-}" == unit ]] && exit $fail

log "Smoke test (scripted play-through)"
out=$("$ROOT/scripts/run_headless.sh" 400000 --smoke=1 --time=11 --season=1 --weather=0 2>&1)
echo "$out" | grep -E "FAIL|SMOKE|SCRIPT ERROR|unique issues"
echo "$out" | grep -q "SMOKE OK" || fail=1
echo "$out" | grep -q "SCRIPT ERROR" && fail=1

log "Simulation (half a day at 6x speed)"
out=$("$ROOT/scripts/run_headless.sh" 20000 --time=9 --season=1 --weather=0 --speed=6 --stats=1 2>&1)
echo "$out" | grep -E "TEST STATS|SCRIPT ERROR|unique issues" | cut -c1-200
echo "$out" | grep -q "SCRIPT ERROR" && fail=1
stuck=$(echo "$out" | grep -o "stuck_total=[0-9]*" | tail -1 | cut -d= -f2)
if [[ -n "$stuck" && "$stuck" -gt 50 ]]; then echo "too many stuck walkers: $stuck"; fail=1; fi

if [[ "${WEB:-0}" == 1 ]]; then
  log "Web export + screenshots"
  "$ROOT/scripts/web_test.sh" || fail=1
fi
[[ $fail == 0 ]] && log "All tests passed" || log "TESTS FAILED"
exit $fail
