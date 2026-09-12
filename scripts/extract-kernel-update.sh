#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kernel-update.sh
output=build/ubuntu-kernel-7.0.0-31
[[ ! -e $output ]] || { echo 'Preserve the existing extracted kernel first' >&2; exit 1; }
mkdir -p "$output"
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD/downloads/ubuntu-kernel-current:/input:ro" -v "$PWD/$output:/output" \
  oma-snap-builder:local bash -ec '
  for name in linux-image-7.0.0-31-generic linux-modules-7.0.0-31-generic; do
    package=${name}_7.0.0-31.31_arm64
    dpkg-deb -x "/input/$package.deb" /output
    dpkg-deb -e "/input/$package.deb" "/output/control-$package"
  done
'
