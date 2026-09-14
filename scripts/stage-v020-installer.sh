#!/bin/bash
# Carry the released hardware-tested image forward as a new, editable candidate.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 0 ]]
iso=omarchy-snapdragon-v0.1.2.iso
destination=build/snapdragon-v020
[[ -f $iso && ! -e $destination ]]
printf '%s  %s\n' c622aff8c5e413e71d26009ad09192b4dc31e50a050198c5e2d7235bd39ddb5d "$iso" | sha256sum -c -
mkdir "$destination"
xorriso -osirrox on -indev "$iso" -extract / "$destination/iso" \
  -extract_boot_images "$destination/boot-images"
(cd "$destination/iso/oma_snap/aarch64" && sha512sum -c airootfs.sha512)
# The pinned ISO's appended diagnostic FAT partition is not an El Torito image.
dd if="$iso" of="$destination/diagnostic.img" bs=4M \
  skip=$((13593340 * 512)) count=$((1048576 * 512)) \
  iflag=skip_bytes,count_bytes status=none
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local \
  unsquashfs -processors 2 -no-progress -d /work/snapdragon-v020/root \
  /work/snapdragon-v020/iso/oma_snap/aarch64/airootfs.sfs
printf '%s  %s\n' c622aff8c5e413e71d26009ad09192b4dc31e50a050198c5e2d7235bd39ddb5d "$iso" > "$destination/base-iso.sha256"
echo 'Staged verified v0.1.2 base for v0.2.0; no updated image assembled'
