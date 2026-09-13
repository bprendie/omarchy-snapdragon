#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=build/snapdragon-v0_1_2-installer-root
[[ -d $root/var/cache/omarchy/mirror/offline ]]
mkdir -p build/snapdragon-v0_1_2-check-db/{local,sync}
cp "$root/var/cache/omarchy/mirror/offline/offline.db.tar.gz" build/snapdragon-v0_1_2-check-db/sync/offline.db
cp "$root/var/cache/omarchy/mirror/offline/oma-snap-local.db.tar.gz" build/snapdragon-v0_1_2-check-db/sync/oma-snap-local.db
cat > build/snapdragon-v0_1_2-check.conf <<CONF
[options]
Architecture = aarch64
SigLevel = Required DatabaseOptional
[oma-snap-local]
SigLevel = Never
Server = file:///output/snapdragon-v0_1_2-installer-root/var/cache/omarchy/mirror/offline
[offline]
Server = file:///output/snapdragon-v0_1_2-installer-root/var/cache/omarchy/mirror/offline
CONF
docker exec oma-snap-root bash -ec '
  mapfile -t targets < /output/quattro-selected-packages
  mapfile -t installer < /output/quattro-installer-targets
  pacman --config /output/snapdragon-v0_1_2-check.conf --dbpath /output/snapdragon-v0_1_2-check-db \
    -Sp --noconfirm --print-format "%f" "${targets[@]}" "${installer[@]}" \
    omarchy omarchy-settings oma-snap-boot archlinuxarm-keyring \
    oma-snap-firmware-hp oma-snap-audio-hp oma-snap-firmware-asus-a14 \
    oma-snap-camera-hp oma-snap-firmware-t14s-npu oma-snap-hotkeys-hp \
    libcamera libcamera-tools pipewire-libcamera gst-plugin-libcamera \
    > /output/snapdragon-v0_1_2-dependency-closure.txt
'
while IFS= read -r package; do
  [[ -s $root/var/cache/omarchy/mirror/offline/$package ]]
done < build/snapdragon-v0_1_2-dependency-closure.txt
sha256sum -c manifests/camera-offline-packages.sha256 manifests/hp-hotkeys-package.sha256 manifests/hp-camera-package.sha256 manifests/t14s-npu-firmware-package.sha256
printf '%s\n' 'PASS: offline dependency closure and added package hashes'
