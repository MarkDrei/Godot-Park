#!/usr/bin/env bash
# Runs the game headless for N frames (default 900) and prints unique errors/warnings.
# Extra args are passed to the game, e.g.: scripts/run_headless.sh 900 --control=jens --time=12
# FPS=30 runs with a fixed frame time (deterministic steps, as fast as the CPU allows);
# then N frames = N/FPS game seconds (times speed=).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="$ROOT/scripts/godot.sh"   # memory-limited (see godot.sh)
FRAMES="${1:-900}"
shift || true
LOG="$(mktemp)"
timeout 300 "$GODOT" --headless --path "$ROOT" --import >"$LOG" 2>&1
FIXED=()
[[ -n "${FPS:-}" ]] && FIXED=(--fixed-fps "$FPS")
timeout 900 "$GODOT" --headless --path "$ROOT" "${FIXED[@]}" --quit-after "$FRAMES" -- "$@" >"$LOG" 2>&1
status=$?
python3 - "$LOG" <<'PY'
import sys, re, collections
lines = open(sys.argv[1], errors="replace").read().split("\n")
seen = collections.OrderedDict()
i = 0
while i < len(lines):
    l = lines[i]
    if l.startswith(("ERROR", "SCRIPT ERROR", "WARNING", "USER ERROR", "USER WARNING")):
        ctx = [l]
        j = i + 1
        while j < len(lines) and re.match(r"^\s+(at:|GDScript backtrace|\[\d+\])", lines[j]):
            ctx.append(lines[j]); j += 1
        key = l + (ctx[1] if len(ctx) > 1 else "")
        if key in seen: seen[key][0] += 1
        else: seen[key] = [1, ctx[:6]]
        i = j
        continue
    if l.startswith(("AUTOTEST", "TEST", "SMOKE", "SCENARIO", "  ok", "  FAIL", "  night")):
        print(l)
    i += 1
for k, (n, ctx) in seen.items():
    print(f"[{n}x] " + "\n      ".join(ctx))
print(f"unique issues: {len(seen)}")
PY
rm -f "$LOG"
exit $status
