#!/usr/bin/env bash
# Exports the web build and screenshots it in headless Chromium (no root needed).
# Usage: scripts/web_test.sh [preset ...]   -> build/screenshots/<preset>.png
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}/web-test"
PORT="${PORT:-8765}"
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

if [[ "${SKIP_EXPORT:-0}" != 1 ]]; then
  "$ROOT/scripts/export.sh" web
fi

# Playwright + Chromium headless shell, installed into the tools dir.
mkdir -p "$TOOLS"
if [[ ! -d "$TOOLS/node_modules/playwright" ]]; then
  log "Install Playwright"
  (cd "$TOOLS" && npm init -y >/dev/null && npm install --silent playwright@1 >/dev/null)
fi
export PLAYWRIGHT_BROWSERS_PATH="$TOOLS/browsers"
if ! ls "$PLAYWRIGHT_BROWSERS_PATH" 2>/dev/null | grep -q chromium_headless_shell; then
  log "Install headless Chromium"
  (cd "$TOOLS" && npx playwright install --only-shell chromium >/dev/null)
fi
# Shared libraries Chromium needs, fetched as .debs and unpacked (no root).
SHELL_BIN=$(ls -d "$PLAYWRIGHT_BROWSERS_PATH"/chromium_headless_shell-*/chrome-headless-shell-linux64/chrome-headless-shell | head -1)
LIBROOT="$TOOLS/libroot"
export LD_LIBRARY_PATH="$LIBROOT/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"
if ldd "$SHELL_BIN" | grep -q "not found"; then
  log "Fetch missing system libraries"
  mkdir -p "$TOOLS/debs" "$LIBROOT"
  (cd "$TOOLS/debs" && apt-get download libatk1.0-0t64 libatk-bridge2.0-0t64 libxcomposite1 libxdamage1 libxfixes3 \
    libxrandr2 libgbm1 libasound2t64 libatspi2.0-0t64 libwayland-server0 libxrender1 libxi6 >/dev/null 2>&1 || true)
  for d in "$TOOLS"/debs/*.deb; do dpkg-deb -x "$d" "$LIBROOT"; done
  rm -rf "$TOOLS/debs"
fi

mkdir -p "$ROOT/build/screenshots"
python3 -m http.server -d "$ROOT/build/web" "$PORT" >/dev/null 2>&1 &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1
log "Screenshots -> build/screenshots"
node "$ROOT/tests/web/shots.cjs" "$TOOLS/node_modules" "http://localhost:$PORT" "$ROOT/build/screenshots" "$@"
