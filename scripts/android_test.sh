#!/usr/bin/env bash
# Boots a headless Android emulator, installs the debug APK, starts the game,
# takes a screenshot (build/screenshots/android.png) and scans logcat for errors.
#
# KVM is needed. Without being in the 'kvm' group, the emulator runs inside a
# throw-away Docker container (requires membership in the 'docker' group).
# Emulator + system image (~2 GB) are removed again unless KEEP_EMULATOR=1.
#
# Checks: APK installs, game starts, world builds ("BANKFREI READY" in logcat),
# keeps running (activity resumed) and does not crash. Note: the emulator's
# SwiftShader GL inside the container fails to link Godot's scene shaders
# (GL_MAX_FRAGMENT_UNIFORM_VECTORS 261) even for an empty Godot project, so the
# screenshot is only a smoke indicator – check visuals on a real device.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="${GODOT_TOOLS:-$HOME/.local/opt/godot-park}"
SDK="$TOOLS/android-sdk"
IMAGE="system-images;android-34;google_apis;x86_64"
WAIT="${WAIT:-90}"
APK="${APK:-$ROOT/build/android/godot-park.apk}"
READY="${READY:-BANKFREI READY}"
log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

[[ -f "$APK" ]] || "$ROOT/scripts/export.sh" android
export JAVA_HOME="$TOOLS/jdk-17"
log "Install emulator and system image"
"$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" "emulator" "$IMAGE" >/dev/null
mkdir -p "$TOOLS/avd" "$TOOLS/emuhome" "$ROOT/build/screenshots"
export ANDROID_AVD_HOME="$TOOLS/avd"
echo no | "$SDK/cmdline-tools/latest/bin/avdmanager" create avd -f -n park -k "$IMAGE" -d pixel_6 -p "$TOOLS/avd/park.avd" >/dev/null

cat > "$TOOLS/emuhome/run.sh" <<INNER
#!/usr/bin/env bash
set -e
export ANDROID_SDK_ROOT="$SDK" ANDROID_AVD_HOME="$TOOLS/avd" HOME="$TOOLS/emuhome"
ADB="$SDK/platform-tools/adb"
"$SDK/emulator/emulator" -avd park -no-window -no-audio -no-snapshot -no-boot-anim -gpu swiftshader_indirect -accel on >"$TOOLS/emuhome/emulator.log" 2>&1 &
timeout 600 "\$ADB" wait-for-device
for i in \$(seq 1 120); do
  [[ "\$("\$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]] && break
  sleep 3
done
"\$ADB" install -r "$APK"
sleep 60   # let the freshly booted system settle
"\$ADB" logcat -c
"\$ADB" shell am start -W -n de.ironstrike.godotpark/com.godot.game.GodotAppLauncher
for i in \$(seq 1 $WAIT); do
  "\$ADB" logcat -d | grep -q "$READY" && break
  sleep 1
done
"\$ADB" logcat -d | grep "$READY" || echo "game did not report ready"
sleep 5
"\$ADB" shell input tap 1500 530   # dismiss the "Viewing full screen" hint
sleep 3
"\$ADB" shell input keyevent KEYCODE_ENTER
sleep 20
"\$ADB" exec-out screencap -p > "$ROOT/build/screenshots/android.png"
"\$ADB" logcat -d > "$ROOT/build/android-logcat.txt"
"\$ADB" shell dumpsys activity activities | grep -iE "ResumedActivity" > "$ROOT/build/android-resumed.txt" || true
"\$ADB" emu kill || true
INNER
chmod +x "$TOOLS/emuhome/run.sh"

if [[ -r /dev/kvm && -w /dev/kvm ]]; then
  log "Run emulator (native KVM)"
  "$TOOLS/emuhome/run.sh"
else
  log "Run emulator in a temporary Docker container (KVM via --device)"
  KVM_GID=$(stat -c %g /dev/kvm)
  docker run --rm --device /dev/kvm -v "$TOOLS:$TOOLS" -v "$ROOT:$ROOT" ubuntu:24.04 bash -c "
    apt-get update -qq >/dev/null && apt-get install -y -qq --no-install-recommends libpulse0 libnss3 libgl1 libxcomposite1 \
      libxcursor1 libxdamage1 libxi6 libxtst6 libasound2t64 libxrandr2 libxkbfile1 libbsd0 libdbus-1-3 libfontconfig1 \
      libx11-xcb1 libxcb-cursor0 libegl1 libgbm1 libdrm2 libxkbcommon0 >/dev/null
    setpriv --reuid=$(id -u) --regid=$(id -g) --groups=$KVM_GID bash $TOOLS/emuhome/run.sh"
fi

log "Logcat summary"
grep "$READY" "$ROOT/build/android-logcat.txt" || true
grep -iE "godot" "$ROOT/build/android-logcat.txt" | grep -iE "error|fatal|crash" | head -20 || true
cat "$ROOT/build/android-resumed.txt" || true
if grep -qE "FATAL EXCEPTION|SIGSEGV|SCRIPT ERROR" "$ROOT/build/android-logcat.txt" || ! grep -q godotpark "$ROOT/build/android-resumed.txt" || ! grep -q "$READY" "$ROOT/build/android-logcat.txt"; then
  log "Android test FAILED (see build/android-logcat.txt)"
  status=1
else
  log "Android test OK – screenshot: build/screenshots/android.png"
  status=0
fi
if [[ "${KEEP_EMULATOR:-0}" != 1 ]]; then
  "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --uninstall "emulator" "$IMAGE" >/dev/null || true
  rm -rf "$TOOLS/avd" "$TOOLS/emuhome"
fi
exit $status
