#!/bin/bash
# Stage a separate initramfs while retaining the original GRUB entry and image.
set -euo pipefail
[[ $EUID == 0 && $(uname -m) == aarch64 ]] || exit 1
cd -- "$(dirname -- "$0")"
sha256sum -c SHA256SUMS
[[ $(uname -r) == 7.0.0-31-generic ]] || exit 1
boot=/boot/oma-snap
config=$boot/grub/grub.cfg
image=initramfs-unlock.img
if [[ -f image-name ]]; then read -r image < image-name; fi
case $image in initramfs-unlock.img|initramfs-splash.img) ;; *) exit 1 ;; esac
candidate=$boot/7.0.0-31-generic/$image
backup=$config.before-${image%.img}
[[ $(findmnt -rn -M /boot -o FSTYPE) == vfat ]] || exit 1
if [[ ${1:-} == restore ]]; then
  cmp "$config" grub-test.cfg
  cp grub-original.cfg "$config.restore"
  mv "$config.restore" "$config"
  sync
  echo 'Original boot selection restored; reboot when ready.'
  exit 0
fi
[[ $# == 0 ]] || exit 1
cmp "$config" grub-original.cfg
[[ ! -e $candidate && ! -e $backup ]] || {
  echo 'Existing test artifacts found; refusing to overwrite.' >&2
  exit 1
}
grub-script-check grub-test.cfg
cp "$config" "$backup"
cp "$image" "$candidate"
cmp "$image" "$candidate"
cp grub-test.cfg "$config.new"
mv "$config.new" "$config"
sync
efibootmgr -n 0002
echo 'Unlock test selected. Original Omarchy entry remains in the GRUB menu.'
echo 'Save your work, then reboot. This script does not reboot automatically.'
