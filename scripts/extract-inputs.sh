#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/verify-inputs.sh
[[ ! -e build/ubuntu-hardware && ! -e build/ubuntu-casper ]] || { echo 'Extracted input already exists' >&2; exit 1; }
xorriso -osirrox on -indev downloads/ubuntu-26.04.1-desktop-arm64.iso \
  -extract /casper build/ubuntu-casper -extract /boot/grub build/ubuntu-grub -extract /EFI build/ubuntu-efi
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  unsquashfs -no-progress -d build/ubuntu-hardware build/ubuntu-casper/minimal.squashfs boot usr/lib/modules usr/lib/firmware "usr/share/doc/linux-firmware*"
  chown -R 1000:1000 build/ubuntu-hardware
'
