#!/usr/bin/env bash
# One-shot build: installs the toolchain if missing (scripts/setup.sh), then exports
# Web (build/web) and Android debug APK (build/android) and sanity-checks both.
#
#   scripts/export.sh            # web + android, debug
#   scripts/export.sh web        # only one target (web | android)
#   RELEASE=1 scripts/export.sh  # release export (Android then needs a release keystore)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_TOOLS="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}"
GODOT_BIN="$GODOT_TOOLS/godot-$GODOT_VERSION/godot"
SDK_DIR="$GODOT_TOOLS/android-sdk"
MODE="--export-debug"; [[ "${RELEASE:-0}" == 1 ]] && MODE="--export-release"
TARGETS=("${@:-web android}"); TARGETS=(${TARGETS[*]})

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

GODOT_VERSION="$GODOT_VERSION" GODOT_TOOLS="$GODOT_TOOLS" "$ROOT/scripts/setup.sh"
export JAVA_HOME="$GODOT_TOOLS/jdk-17" PATH="$GODOT_TOOLS/jdk-17/bin:$PATH"

log "Import project assets"
"$ROOT/scripts/godot.sh" --headless --path "$ROOT" --import >/dev/null 2>&1

export_preset() { # preset path
  mkdir -p "$(dirname "$ROOT/$2")"
  log "Export $1 → $2"
  local out; out=$("$ROOT/scripts/godot.sh" --headless --path "$ROOT" "$MODE" "$1" "$ROOT/$2" 2>&1) || { echo "$out"; exit 1; }
  if grep -qE '^(ERROR|SCRIPT ERROR)' <<<"$out"; then echo "$out"; exit 1; fi
}

for t in "${TARGETS[@]}"; do
  case "$t" in
    web)
      rm -rf "$ROOT/build/web"
      export_preset "Web" "build/web/index.html"
      for f in index.html index.js index.wasm index.pck; do
        [[ -s "$ROOT/build/web/$f" ]] || { echo "missing build/web/$f"; exit 1; }
      done
      log "Web OK: build/web ($(du -sh "$ROOT/build/web" | cut -f1)) — test: python3 -m http.server -d build/web 8000"
      ;;
    android)
      rm -rf "$ROOT/build/android"
      export_preset "Android" "build/android/godot-park.apk"
      apk="$ROOT/build/android/godot-park.apk"
      bt=$(ls -d "$SDK_DIR"/build-tools/* | sort -V | tail -1)
      "$bt/apksigner" verify "$apk"
      "$bt/aapt" dump badging "$apk" | grep -E "^(package|sdkVersion|targetSdkVersion|native-code)"
      log "Android OK: $(du -h "$apk" | cut -f1) — install: $SDK_DIR/platform-tools/adb install -r build/android/godot-park.apk"
      ;;
    *) echo "unknown target: $t (web | android)"; exit 1 ;;
  esac
done
