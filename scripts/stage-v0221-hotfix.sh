#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
stage=build/snapdragon-v0221
[[ ! -e $stage ]]
printf '%s  %s\n' 9fcde763a1d70e59f5c0dba1579f30008d6d362ec2f1da6f9404304ae789f5bc \
  omarchy-snapdragon-v0.2.2.iso | sha256sum -c -
mkdir "$stage"
xorriso -osirrox on -indev omarchy-snapdragon-v0.2.2.iso \
  -extract /oma_snap/aarch64/airootfs.sfs "$stage/base.sfs" \
  -extract /boot/grub/grub.cfg "$stage/grub.cfg"
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local \
  unsquashfs -processors 4 -no-progress -d /work/snapdragon-v0221/root /work/snapdragon-v0221/base.sfs
