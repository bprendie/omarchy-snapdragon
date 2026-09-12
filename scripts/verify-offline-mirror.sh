#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c manifests/offline-packages.sha256 > build/offline-hash-check.log
cp profiles/t14s-lcd/installer-extra.packages build/quattro-installer-targets
# Quattro's pinned configurator selects PipeWire through archinstall, in addition
# to the desktop list. Check its actual package requests so list drift fails here.
docker exec oma-snap-root python -c 'from archinstall.applications.audio import AudioApp; print("\n".join(AudioApp().pipewire_packages))' > build/archinstall-audio-targets
comm -23 <(sort -u build/archinstall-audio-targets) <(sort -u build/quattro-installer-targets) > build/installer-missing-targets
[[ ! -s build/installer-missing-targets ]] || { cat build/installer-missing-targets >&2; exit 1; }
docker exec oma-snap-root bash -ec '
  mkdir -p /output/offline-check-db/{local,sync}
  cp /output/offline-mirror/offline.db.tar.gz /output/offline-check-db/sync/offline.db
  cp /output/offline-mirror/oma-snap-local.db.tar.gz /output/offline-check-db/sync/oma-snap-local.db
  cat > /output/offline-check.conf <<EOF
[options]
Architecture = aarch64
SigLevel = Required DatabaseOptional
[oma-snap-local]
SigLevel = Never
Server = file:///output/offline-mirror
[offline]
Server = file:///output/offline-mirror
EOF
  mapfile -t targets < /output/quattro-selected-packages
  mapfile -t installer_targets < /output/quattro-installer-targets
  pacman --config /output/offline-check.conf --dbpath /output/offline-check-db \
    -Sp --noconfirm --print-format "%f" "${targets[@]}" \
    "${installer_targets[@]}" \
    omarchy omarchy-settings oma-snap-boot > /output/offline-dependency-closure.txt
' > build/offline-dependency-check.log 2>&1
echo 'PASS: selected offline package hashes and dependency closure; not an install/signature test'
