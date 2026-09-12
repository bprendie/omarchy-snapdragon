#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/prepare-quattro-profile.sh
sha256sum -c manifests/quattro-profile-packages.sha256
sha256sum -c manifests/bridge-packages.sha256
sha256sum -c manifests/boot-package.sha256
bash scripts/quattro-package-list.sh > build/quattro-selected-packages
cp profiles/t14s-lcd/installer-extra.packages build/quattro-installer-targets
sed -E 's@^(hyprland|hyprtoolkit|hyprland-guiutils)$@omarchy/\1@' \
  build/quattro-selected-packages > build/quattro-package-targets
docker exec oma-snap-root bash -ec '
  test ! -e /var/lib/pacman/db.lck
  mkdir -p /output/quattro-offline-db/{local,sync} /output/pkg-cache /output/offline-mirror
  cp -a /var/lib/pacman/sync/. /output/quattro-offline-db/sync/
  cp -an /var/cache/pacman/pkg/. /output/pkg-cache/
  mapfile -t targets < /output/quattro-package-targets
  mapfile -t installer_targets < /output/quattro-installer-targets
  targets+=("${installer_targets[@]}")
  pacman --dbpath /output/quattro-offline-db -Sw --noconfirm --cachedir /output/pkg-cache "${targets[@]}"
  pacman --dbpath /output/quattro-offline-db -Sp --print-format "%f" "${targets[@]}" > /output/quattro-offline-files
  while read -r filename; do
    test -f "/output/pkg-cache/$filename"
    cp -a "/output/pkg-cache/$filename" /output/offline-mirror/
    if [[ -f /output/pkg-cache/$filename.sig ]]; then
      cp -a "/output/pkg-cache/$filename.sig" /output/offline-mirror/
    fi
  done < /output/quattro-offline-files
  shopt -s nullglob
  local_packages=(/output/quattro-profile/*/*.pkg.tar.xz /output/kernel-package/*.pkg.tar.xz /output/firmware-package/*.pkg.tar.xz /output/boot-package/*.pkg.tar.xz)
  test "${#local_packages[@]}" -eq 5
  for package in "${local_packages[@]}"; do
    cp -a "$package" /output/offline-mirror/
    basename "$package" >> /output/quattro-offline-files
  done
  bash /sources/omarchy-iso/builder/prune-offline-mirror.sh /output/offline-mirror < /output/quattro-offline-files
' > build/offline-mirror-build.log 2>&1
sha256sum build/offline-mirror/*.pkg.tar.xz build/offline-mirror/*.pkg.tar.zst > manifests/offline-packages.sha256
bash scripts/finalize-offline-mirror.sh
