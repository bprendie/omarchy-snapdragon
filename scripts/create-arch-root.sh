#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/verify-inputs.sh
sha256sum -c manifests/repository-metadata.sha256
if docker container inspect oma-snap-root >/dev/null 2>&1; then
  echo 'oma-snap-root already exists; preserve or remove that project container explicitly before rebuilding' >&2
  exit 1
fi
mkdir -p build/pkg-cache
docker import --platform linux/arm64 downloads/ArchLinuxARM-aarch64-latest.tar.gz oma-snap-arch-base:local
docker run -d --platform linux/arm64 --name oma-snap-root \
  -v "$PWD/downloads:/inputs:ro" -v "$PWD/build:/output" -v "$PWD/sources:/sources:ro" \
  oma-snap-arch-base:local /usr/bin/sleep infinity
docker exec oma-snap-root bash -ec '
  test "$(uname -m)" = aarch64
  pacman-key --init
  pacman-key --populate archlinuxarm
  cp /inputs/repos/*.db /var/lib/pacman/sync/
  printf "Server = http://mirror.archlinuxarm.org/\$arch/\$repo\n" > /etc/pacman.d/mirrorlist
  sed -i "/^\[aur\]/,+1d; /^DownloadUser/d" /etc/pacman.conf
  pacman -R --noconfirm linux-aarch64
  pacman -Su --noconfirm --cachedir /output/pkg-cache mkinitcpio-archiso base-devel networkmanager openssh mesa foot sudo alsa-ucm-conf alsa-utils pipewire-pulse wireplumber
'
