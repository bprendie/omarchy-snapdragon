#!/bin/bash
# Disposable builder test. /boot is a new mounted FAT image, not a laptop ESP.
set -euo pipefail
first=${1:?Missing first staging directory}
second=${2:?Missing second staging directory}
mapfile -t a < "$first/boot-set"
mapfile -t b < "$second/boot-set"
[[ ${a[2]} != "${b[2]}" ]]
oma-snap-boot-publish --stage "$first"
oma-snap-boot-publish --stage "$second"
for selected in "${a[2]}" "${b[2]}" "${a[2]}"; do
  fallback=${b[2]}
  [[ $selected != "${b[2]}" ]] || fallback=${a[2]}
  oma-snap-boot-publish --select "$selected" --fallback "$fallback"
  grep -Fx "set default=oma-snap-$selected" /boot/oma-snap/grub/grub.cfg
  for id in "${a[2]}" "${b[2]}"; do
    grep -F -- "--id 'oma-snap-$id'" /boot/oma-snap/grub/grub.cfg
  done
done
echo 'PASS: FAT menu selects A/B/A and retains both entries'
cp /boot/oma-snap/grub/grub.cfg /output/menu-before-invalid.cfg
printf broken > "/boot/oma-snap/entries/${b[2]}/vmlinuz.efi"
if oma-snap-boot-publish --select "${a[2]}" --fallback "${b[2]}"; then
  echo 'FAIL: corrupted fallback accepted' >&2
  exit 1
fi
cmp /output/menu-before-invalid.cfg /boot/oma-snap/grub/grub.cfg
cp "/usr/lib/oma-snap/sets/${b[0]}/vmlinuz.efi" "/boot/oma-snap/entries/${b[2]}/vmlinuz.efi"
sync
echo 'PASS: corrupted fallback cannot change the FAT boot menu'
cp "$first/boot-set" /output/first-boot-set
cp "$second/boot-set" /output/second-boot-set
chmod 644 /output/{first,second}-boot-set
