#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ ! -e build/live-root.tar ]] || { echo 'Root export already exists' >&2; exit 1; }
cp dist/oma-snap-inventory-arm64 build/
cp scripts/configure-live-root.sh build/
docker exec oma-snap-root bash /output/configure-live-root.sh
docker exec oma-snap-root pacman -Q > manifests/console-packages.txt
docker export oma-snap-root -o build/live-root.tar
sha256sum build/live-root.tar > manifests/console-root-export.sha256
