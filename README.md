# Godot-Park

Godot Park — Godot 4 app for **Web** and **Android**.

## Quick start

```bash
scripts/export.sh          # installs toolchain if missing, exports web + android
scripts/export.sh web      # only web   (build/web)
scripts/export.sh android  # only android debug APK (build/android/godot-park.apk)
```

No root needed. The first run downloads ~1.5 GB into `~/.local/opt/godot-park`
(override with `GODOT_TOOLS=...`):

| Part | Version |
|------|---------|
| Godot editor + export templates (web/android only) | 4.7.2 (`GODOT_VERSION`) |
| JDK (Temurin) | 17 |
| Android SDK | platform-tools, build-tools 35.0.1, android-35 |
| Debug keystore | `debug.keystore` (alias `androiddebugkey`, pw `android`) |

Godot runs in self-contained mode, so its editor settings (SDK paths, keystore) live in
`~/.local/opt/godot-park/godot-4.7.2/editor_data/` and don't touch `~/.config/godot`.
`scripts/setup.sh` alone only installs/repairs the toolchain.

## Project layout

| Path | Content |
|------|---------|
| `project.godot` | Project settings: portrait 720×1280, stretch `canvas_items`, Compatibility renderer (WebGL2 / GLES3) |
| `scenes/main.tscn`, `scenes/main.gd` | Minimal app: title, tap counter, engine/OS info |
| `export_presets.cfg` | Presets `Web` (single-threaded, no SharedArrayBuffer/COOP/COEP headers needed) and `Android` (pre-built APK, arm64 + x86_64) |
| `scripts/` | `setup.sh` (toolchain), `export.sh` (build) |
| `build/` | Export output (git-ignored) |

## Testing

- **Web:** `python3 -m http.server -d build/web 8000`, open http://localhost:8000.
- **Android:** `~/.local/opt/godot-park/android-sdk/platform-tools/adb install -r build/android/godot-park.apk`
  (or download the APK to the phone and allow installing from unknown sources).
- **Editor (GUI):** `~/.local/opt/godot-park/godot-4.7.2/godot --path .` (needs a desktop; on the VPS use headless only).

## Notes

- Release builds for Android (`RELEASE=1`) need a release keystore set in the Android preset
  (`keystore/release*`) or via `GODOT_ANDROID_KEYSTORE_RELEASE_*` env vars. Don't commit it.
- Play Store needs an AAB: switch the preset to a Gradle build (also needs NDK + `android_source.zip`
  installed into `android/`), not set up yet.
