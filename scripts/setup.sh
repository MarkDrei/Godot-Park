#!/usr/bin/env bash
# Installs everything needed to build and export this project — without root.
# Idempotent: already installed parts are skipped. Re-run any time.
#
#   Godot editor + export templates, JDK 17 (Temurin), Android SDK (platform-tools,
#   build-tools, platform), debug keystore, Godot editor settings.
#
# Install location: $GODOT_TOOLS (default ~/.local/opt/godot-park), ~3 GB.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
GODOT_TOOLS="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}"
ANDROID_CMDLINE_TOOLS_ZIP="commandlinetools-linux-16111833_latest.zip"
ANDROID_BUILD_TOOLS="35.0.1"
ANDROID_PLATFORM="android-35"

GODOT_DIR="$GODOT_TOOLS/godot-$GODOT_VERSION"
GODOT_BIN="$GODOT_DIR/godot"
JDK_DIR="$GODOT_TOOLS/jdk-17"
SDK_DIR="$GODOT_TOOLS/android-sdk"
KEYSTORE="$GODOT_TOOLS/debug.keystore"
DL="$GODOT_TOOLS/downloads"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
mkdir -p "$GODOT_TOOLS" "$DL"

download() { # url target
  [[ -f "$2" ]] || { log "Download $(basename "$2")"; curl -fL --retry 3 -o "$2.part" "$1" && mv "$2.part" "$2"; }
}

# --- Godot editor (self-contained mode: settings + templates live next to the binary) ---
if [[ ! -x "$GODOT_BIN" ]]; then
  base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable"
  zip="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  download "$base/$zip" "$DL/$zip"
  mkdir -p "$GODOT_DIR"
  unzip -oq "$DL/$zip" -d "$GODOT_DIR"
  mv "$GODOT_DIR/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$GODOT_BIN"
  touch "$GODOT_DIR/._sc_"   # self-contained marker
  rm -f "$DL/$zip"
fi

# --- Export templates ---
TEMPLATES="$GODOT_DIR/editor_data/export_templates/${GODOT_VERSION}.stable"
if [[ ! -f "$TEMPLATES/version.txt" ]]; then
  tpz="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
  download "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/$tpz" "$DL/$tpz"
  log "Extract export templates"
  tmp="$GODOT_TOOLS/tpl-tmp"; rm -rf "$tmp"; mkdir -p "$tmp" "$(dirname "$TEMPLATES")"
  unzip -q "$DL/$tpz" -d "$tmp"
  rm -rf "$TEMPLATES"; mv "$tmp/templates" "$TEMPLATES"; rm -rf "$tmp"
  # Only keep what we export to (web + android) to save disk.
  find "$TEMPLATES" -type f ! -name 'web_*' ! -name 'android_*' ! -name 'version.txt' -delete
  rm -f "$DL/$tpz"
fi

# --- JDK 17 ---
if [[ ! -x "$JDK_DIR/bin/java" ]]; then
  download "https://api.adoptium.net/v3/binary/latest/17/ga/linux/x64/jdk/hotspot/normal/eclipse" "$DL/jdk17.tar.gz"
  log "Extract JDK 17"
  rm -rf "$JDK_DIR"; mkdir -p "$JDK_DIR"
  tar -xzf "$DL/jdk17.tar.gz" -C "$JDK_DIR" --strip-components=1
  rm -f "$DL/jdk17.tar.gz"
fi
export JAVA_HOME="$JDK_DIR"

# --- Android SDK (only what pre-built APK export needs; no NDK/Gradle) ---
SDKMANAGER="$SDK_DIR/cmdline-tools/latest/bin/sdkmanager"
if [[ ! -x "$SDKMANAGER" ]]; then
  download "https://dl.google.com/android/repository/$ANDROID_CMDLINE_TOOLS_ZIP" "$DL/$ANDROID_CMDLINE_TOOLS_ZIP"
  rm -rf "$SDK_DIR/cmdline-tools"; mkdir -p "$SDK_DIR/cmdline-tools"
  unzip -q "$DL/$ANDROID_CMDLINE_TOOLS_ZIP" -d "$SDK_DIR/cmdline-tools"
  mv "$SDK_DIR/cmdline-tools/cmdline-tools" "$SDK_DIR/cmdline-tools/latest"
  rm -f "$DL/$ANDROID_CMDLINE_TOOLS_ZIP"
fi
if [[ ! -x "$SDK_DIR/build-tools/$ANDROID_BUILD_TOOLS/apksigner" || ! -x "$SDK_DIR/platform-tools/adb" \
      || ! -d "$SDK_DIR/platforms/$ANDROID_PLATFORM" ]]; then
  log "Install Android SDK packages"
  # Accept licenses (newer cmdline-tools no longer need this; `yes` dies of SIGPIPE, hence || true).
  yes 2>/dev/null | "$SDKMANAGER" --sdk_root="$SDK_DIR" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" --sdk_root="$SDK_DIR" "platform-tools" "build-tools;$ANDROID_BUILD_TOOLS" "platforms;$ANDROID_PLATFORM" >/dev/null
fi

# --- Debug keystore ---
if [[ ! -f "$KEYSTORE" ]]; then
  log "Create debug keystore"
  "$JDK_DIR/bin/keytool" -genkeypair -keystore "$KEYSTORE" -storepass android -keypass android \
    -alias androiddebugkey -dname "CN=Android Debug,O=Android,C=US" -keyalg RSA -keysize 2048 -validity 10000 >/dev/null
fi

# --- Godot editor settings (SDK paths + debug keystore) ---
settings=$(ls "$GODOT_DIR"/editor_data/editor_settings-*.tres 2>/dev/null | head -1 || true)
if [[ -z "$settings" ]]; then
  log "Initialise Godot editor settings"
  tmpproj="$GODOT_TOOLS/init-project"; mkdir -p "$tmpproj"; : > "$tmpproj/project.godot"
  "$GODOT_BIN" --headless --editor --quit --path "$tmpproj" >/dev/null 2>&1 || true
  rm -rf "$tmpproj"
  settings=$(ls "$GODOT_DIR"/editor_data/editor_settings-*.tres | head -1)
fi
set_setting() { # key value
  sed -i "\|^$1 = |d" "$settings"
  sed -i "/^\[resource\]/a $1 = \"$2\"" "$settings"
}
set_setting "export/android/java_sdk_path" "$JDK_DIR"
set_setting "export/android/android_sdk_path" "$SDK_DIR"
set_setting "export/android/debug_keystore" "$KEYSTORE"
set_setting "export/android/debug_keystore_user" "androiddebugkey"
set_setting "export/android/debug_keystore_pass" "android"

rmdir "$DL" 2>/dev/null || true
log "Setup complete: $GODOT_BIN (Godot $GODOT_VERSION)"
