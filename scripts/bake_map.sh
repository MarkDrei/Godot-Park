#!/usr/bin/env bash
# Bakes the whole map (every area built) into assets/map/world.png. The game draws the
# Oststadt, the Westpark and the Ritterburg from it until they are loaded (MapImage.BAKED), so their maps and
# the "Gesamtkarte" work without building them.
#   scripts/bake_map.sh            # bake now
#   scripts/bake_map.sh --changed  # only when a map input changed since origin/main (release.sh)
# The scenario test areas::test_baked_map_is_up_to_date fails when the image is out of date.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# What the baked parts are drawn from: the town's, the Westpark's and the Burg's layout, map
# writers and builders (trees, booths, walls), and the drawing itself.
INPUTS=(src/world/map_image.gd src/core/park_map.gd src/core/city_layout.gd src/core/fair_layout.gd
  src/world/city_map.gd src/world/fair_map.gd src/world/fair_builder.gd src/world/world_builder.gd
  src/world/tree_planter.gd src/world/city_builder.gd src/world/city_decor.gd src/core/park_layout.gd
  src/core/burg_layout.gd src/world/burg_map.gd src/world/burg_builder.gd src/game/herb_spots.gd)
if [[ "${1:-}" == --changed ]]; then
  base="$(git merge-base HEAD origin/main 2>/dev/null || echo HEAD)"
  if [[ -z "$(git diff --name-only "$base" -- "${INPUTS[@]}"; git ls-files --others --exclude-standard -- "${INPUTS[@]}")" ]]; then
    echo "map: no map input changed"
    exit 0
  fi
fi
mkdir -p assets/map
out="$(timeout 300 scripts/godot.sh --headless --path . -- --bake_map=res://assets/map/world.png --areas=all 2>&1)" || true
grep -q "BAKE MAP .*: OK" <<<"$out" || { echo "$out" | tail -20; echo "map: baking failed" >&2; exit 1; }
# Import it, so the game (and the export) finds the new image.
timeout 300 scripts/godot.sh --headless --path . --import >/dev/null 2>&1 || true
echo "map: baked assets/map/world.png ($(du -k assets/map/world.png | cut -f1) KB)"
