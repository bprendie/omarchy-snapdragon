#!/bin/bash
# Run in a disposable privileged builder with two fresh FAT images at /output,
# private payload/staging inputs and ARM publisher binaries. Native mount tools
# avoid loop-ioctl limitations in userspace ARM emulation.
set -euo pipefail
stage=${1:?Missing staging directory}
mapfile -t identity < "$stage/boot-set"
entry=${identity[2]}
[[ $entry =~ ^[a-f0-9]{64}$ ]]
mkdir -p /boot
trap 'umount /boot 2>/dev/null || true' EXIT
mount -o loop /output/boot-large.img /boot
mkdir -p /boot/oma-snap/grub
printf '%s\n' 'working default unchanged' > /boot/oma-snap/grub/grub.cfg
oma-snap-boot-publish --stage "$stage"
test -s "/boot/oma-snap/entries/$entry/entry.cfg"
cmp "$stage/initramfs.img" "/boot/oma-snap/entries/$entry/initramfs.img"
cmp "/usr/lib/oma-snap/sets/${identity[0]}/vmlinuz.efi" "/boot/oma-snap/entries/$entry/vmlinuz.efi"
printf '%s\n' 'working default unchanged' | cmp - /boot/oma-snap/grub/grub.cfg
echo 'PASS: FAT publication preserves payload bytes and existing GRUB default'
umount /boot
mount -o loop /output/boot-small.img /boot
mkdir -p /boot/oma-snap/grub
printf '%s\n' 'working default unchanged' > /boot/oma-snap/grub/grub.cfg
if oma-snap-boot-publish --stage "$stage"; then
  echo 'FAIL: oversized payload unexpectedly published' >&2
  exit 1
fi
test ! -e "/boot/oma-snap/entries/$entry"
[[ -z $(find /boot/oma-snap/entries -mindepth 1 -print -quit) ]]
printf '%s\n' 'working default unchanged' | cmp - /boot/oma-snap/grub/grub.cfg
echo 'PASS: full FAT filesystem leaves no published/partial entry and preserves default'
