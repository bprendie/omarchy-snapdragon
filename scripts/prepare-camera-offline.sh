#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/camera-offline-packages
docker exec oma-snap-root pacman -Sw --noconfirm \
  --cachedir /output/camera-offline-packages \
  libcamera libcamera-tools pipewire-libcamera gst-plugin-libcamera
# Fail if the pinned package set is unavailable or changed. Do not silently
# substitute a newer camera stack into the tested base image.
sha256sum -c manifests/camera-offline-packages.sha256
