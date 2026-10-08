#!/usr/bin/env bash
# Runs the project's Godot with a memory limit (default 3 GB, no swap). When Godot
# needs more, only Godot is killed (exit code 137), not the shell or the session.
# All scripts start Godot through this wrapper; use it for manual runs too:
#   scripts/godot.sh --headless --path . --quit-after 900 -- --control=jens
#   GODOT_MEM=2G scripts/godot.sh …
GODOT_BIN="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}/godot-${GODOT_VERSION:-4.7.2}/godot"
exec systemd-run --user --scope -q -p MemoryMax="${GODOT_MEM:-3G}" -p MemorySwapMax=0 "$GODOT_BIN" "$@"
