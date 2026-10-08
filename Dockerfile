# Export the Godot project for the web, serve it with nginx on port 3000 (platform convention).
FROM debian:bookworm-slim AS build
ARG GODOT_VERSION=4.7.2
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 \
    && rm -rf /var/lib/apt/lists/*
# Godot editor (headless) and only the web export templates (keeps the layer small and cacheable).
RUN base="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable" \
    && curl -fsSL -o /tmp/godot.zip "$base/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
    && unzip -q /tmp/godot.zip -d /tmp/godot && mv /tmp/godot/Godot_v* /usr/local/bin/godot && rm -rf /tmp/godot* \
    && tpl="/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable" && mkdir -p "$tpl" \
    && curl -fsSL -o /tmp/t.tpz "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" \
    && unzip -q -j /tmp/t.tpz templates/version.txt templates/web_nothreads_release.zip templates/web_nothreads_debug.zip -d "$tpl" \
    && rm /tmp/t.tpz
WORKDIR /src
COPY . .
RUN godot --headless --path . --import >/dev/null 2>&1 || true \
    && mkdir -p /out && godot --headless --path . --export-release Web /out/index.html \
    && test -s /out/index.wasm && test -s /out/index.pck

FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /out /usr/share/nginx/html
EXPOSE 3000
