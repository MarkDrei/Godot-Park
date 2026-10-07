#!/usr/bin/env bash
# Re-imports the project headless and prints GDScript errors with their source lines.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}/godot-${GODOT_VERSION:-4.7.2}/godot"
LOG="$(mktemp)"
timeout 300 "$GODOT" --headless --path "$ROOT" --import >"$LOG" 2>&1
grep -E "SCRIPT ERROR|^ERROR" -A1 "$LOG" | grep -v "^--" | paste - - | sed 's/\t */ | /' |
while IFS= read -r l; do
	echo "$l"
	loc=$(sed -n 's/.*(res:\/\/\([^:]*\):\([0-9]*\)).*/\1:\2/p' <<<"$l")
	if [[ -n "$loc" && "${loc##*:}" != "0" ]]; then
		echo "    > $(sed -n "${loc##*:}p" "$ROOT/${loc%%:*}" | sed 's/^\s*//')"
	fi
done
rm -f "$LOG"
