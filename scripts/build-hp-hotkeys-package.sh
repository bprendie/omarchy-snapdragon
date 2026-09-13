#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/hp-hotkeys-package
cp packages/hp-hotkeys/{PKGBUILD,oma-snap-hp-hotkeys} \
  profiles/hp-elitebook-ultra-g1q/hp_media_keys.lua build/hp-hotkeys-package/
docker exec --user alarm --workdir /output/hp-hotkeys-package oma-snap-root \
  makepkg --nodeps --noconfirm --force
sha256sum build/hp-hotkeys-package/*.pkg.tar.xz > manifests/hp-hotkeys-package.sha256
