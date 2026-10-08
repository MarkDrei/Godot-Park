# Export the Godot project for the web and as an Android APK, serve both with nginx on port 3000
# (platform convention). The APK is offered at /download.
FROM debian:bookworm-slim AS build
ARG GODOT_VERSION=4.7.2
ARG ANDROID_CMDLINE_TOOLS=commandlinetools-linux-16111833_latest.zip
ARG ANDROID_BUILD_TOOLS=35.0.1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
      openjdk-17-jdk-headless \
    && rm -rf /var/lib/apt/lists/*
# Godot editor (headless) plus only the web and Android export templates.
RUN base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable" \
    && curl -fsSL -o /tmp/godot.zip "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp/godot && mv /tmp/godot/Godot_v* /usr/local/bin/godot && rm -rf /tmp/godot* \
    && tpl="/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" && mkdir -p "$tpl" \
    && curl -fsSL -o /tmp/t.tpz "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && unzip -q -j /tmp/t.tpz templates/version.txt templates/web_nothreads_release.zip templates/web_nothreads_debug.zip \
         templates/android_release.apk templates/android_debug.apk -d "$tpl" \
    && rm /tmp/t.tpz
# Minimal Android SDK: Godot needs apksigner (build-tools) and platform-tools.
ENV ANDROID_HOME=/opt/android-sdk
RUN mkdir -p $ANDROID_HOME/cmdline-tools \
    && curl -fsSL -o /tmp/clt.zip "https://dl.google.com/android/repository/${ANDROID_CMDLINE_TOOLS}" \
    && unzip -q /tmp/clt.zip -d $ANDROID_HOME/cmdline-tools && mv $ANDROID_HOME/cmdline-tools/cmdline-tools $ANDROID_HOME/cmdline-tools/latest \
    && rm /tmp/clt.zip \
    && (yes | $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME --licenses >/dev/null 2>&1 || true) \
    && $ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --sdk_root=$ANDROID_HOME "platform-tools" "build-tools;${ANDROID_BUILD_TOOLS}" >/dev/null \
    && mkdir -p /root/.config/godot \
    && printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\nexport/android/java_sdk_path = "%s"\nexport/android/android_sdk_path = "%s"\n' \
         "$(dirname $(dirname $(readlink -f $(which javac))))" "$ANDROID_HOME" > /root/.config/godot/editor_settings-4.7.tres
WORKDIR /src
COPY . .
# Release-signed APK with the project's own keystore (stable signature, so updates install over old versions).
ENV GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/src/deploy/bank-frei.keystore \
    GODOT_ANDROID_KEYSTORE_RELEASE_USER=bankfrei \
    GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=bankfrei
RUN godot --headless --path . --import >/dev/null 2>&1 || true \
    && mkdir -p /out \
    && godot --headless --path . --export-release Web /out/index.html \
    && test -s /out/index.wasm && test -s /out/index.pck \
    && sed -i "s/^version\/code=.*/version\/code=$(( $(date +%s) / 60 ))/" export_presets.cfg \
    && godot --headless --path . --export-release Android /out/bank-frei.apk \
    && $ANDROID_HOME/build-tools/*/apksigner verify /out/bank-frei.apk \
    && version="$(sed -n 's/^config\/version="\(.*\)"/\1/p' project.godot)" \
    && size="$(awk "BEGIN{printf \"%.0f\", $(stat -c %s /out/bank-frei.apk)/1048576}")" \
    && sed -e "s/__VERSION__/$version/" -e "s/__SIZE__/$size/" -e "s/__BUILD__/$(date -u +%Y-%m-%d\ %H:%M)/" deploy/download.html > /out/download.html

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /out /usr/share/nginx/html
EXPOSE 3000
