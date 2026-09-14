#!/bin/bash
# Resolve the fresh installer transaction without installing any packages.
set -euo pipefail
cd "$(dirname "$0")/.."
root=build/snapdragon-v022/root
check=build/v022-offline-check
[[ ! -e $check ]]
mkdir -p "$check/db/"{local,sync}
cp "$root/var/cache/oma-snap/repository/oma-snap.db.tar.gz" "$check/db/sync/oma-snap.db"
cp "$root/var/cache/oma-snap/repository/oma-snap.db.tar.gz.sig" "$check/db/sync/oma-snap.db.sig"
for repo in offline oma-snap-local; do
  cp "$root/var/cache/omarchy/mirror/offline/$repo.db.tar.gz" "$check/db/sync/$repo.db"
done
cat > "$check/pacman.conf" <<CONF
[options]
Architecture = aarch64
GPGDir = /output/snapdragon-v022/root/etc/pacman.d/gnupg
SigLevel = Required DatabaseOptional
[oma-snap]
SigLevel = PackageRequired DatabaseRequired TrustedOnly
Server = file:///output/snapdragon-v022/root/var/cache/oma-snap/repository
[oma-snap-local]
SigLevel = Never
Server = file:///output/snapdragon-v022/root/var/cache/omarchy/mirror/offline
[offline]
Server = file:///output/snapdragon-v022/root/var/cache/omarchy/mirror/offline
CONF
docker exec oma-snap-root bash -ec '
  mapfile -t targets < /output/quattro-selected-packages
  mapfile -t installer < /output/quattro-installer-targets
  pacman --config /output/v022-offline-check/pacman.conf --dbpath /output/v022-offline-check/db \
    -Sp --noconfirm --print-format "%f" "${targets[@]}" "${installer[@]}" \
    omarchy omarchy-settings oma-snap-boot archlinuxarm-keyring \
    oma-snap-kernel oma-snap-kernel-tools oma-snap-repository oma-snap-audio-asus-a16 \
    oma-snap-firmware-hp oma-snap-audio-hp oma-snap-firmware-asus-a14 \
    oma-snap-camera-hp oma-snap-firmware-t14s-npu oma-snap-hotkeys-hp \
    libcamera libcamera-tools pipewire-libcamera gst-plugin-libcamera \
    > /output/v022-offline-check/packages.txt
'
while IFS= read -r package; do
  [[ -s $root/var/cache/omarchy/mirror/offline/$package || -s $root/var/cache/oma-snap/repository/$package ]]
done < "$check/packages.txt"
grep -Fxq oma-snap-audio-asus-a16-0.2.2-1-any.pkg.tar.xz "$check/packages.txt"
grep -Fxq oma-snap-kernel-tools-0.2.2-1-aarch64.pkg.tar.xz "$check/packages.txt"
printf 'PASS: offline installer dependency closure (%s packages), including A16 audio and new kernel tools\n' "$(wc -l < "$check/packages.txt")"
