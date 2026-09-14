#!/bin/bash
# Explicit phases across guest reboots; never reboots or runs on physical hardware.
set -euo pipefail
phase=${1:?Usage: kernel-abi-rollback-installed.sh PHASE}
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
[[ $(findmnt -n -o SOURCE /boot) == /dev/vda1 && ! -e /var/lib/pacman/db.lck ]]
[[ $(systemctl show oma-snap-kernel-prepare.service -p ActiveState --value) == inactive ]]
old=4f9f71d26d9a93760cd0a4315d5e7656903ef00377b6b17912f4c168b125849d
new=66fd1aeac79199ae7e9e9b126dc2d8b0c996cb6afe2562d3f94f93cd157587bc
old_entry=$(jq -er .boot_entry "/var/lib/oma-snap/jobs/complete/$old.json")
new_entry=$(jq -er .boot_entry "/var/lib/oma-snap/jobs/complete/$new.json")
[[ $old_entry =~ ^[a-f0-9]{64}$ && $new_entry =~ ^[a-f0-9]{64}$ && $old_entry != "$new_entry" ]]
old_release=$(jq -er .kernel_release "/usr/lib/oma-snap/sets/$old/set.json")
new_release=$(jq -er .kernel_release "/usr/lib/oma-snap/sets/$new/set.json")
[[ $old_release == 7.0.0-30-generic && $new_release == 7.0.0-31-generic ]]
root_device=$(findmnt -n -o SOURCE /)
root_device=${root_device%%\[*}
root_type=$(lsblk -ndo TYPE "$root_device")
if [[ ${OMA_SNAP_EXPECT_ENCRYPTED:-0} == 1 ]]; then [[ $root_type == crypt ]]; fi
work=/var/tmp/oma-snap-abi-rollback-test
menu=/boot/oma-snap/grub/grub.cfg
if [[ $phase == initialize ]]; then
  [[ ! -e $work ]]
  mkdir "$work"
  cp "$menu" "$work/initial-grub.cfg"
  sha256sum /boot/oma-snap/7.0.0-31-generic/{vmlinuz.efi,initramfs.img} > "$work/legacy.sha256"
  printf '%s\n' "$root_type" > "$work/root-type"
else
  [[ $(cat "$work/root-type") == "$root_type" ]]
  case "$phase" in
    select-old|select-new)
      selected=$old_entry fallback=$new_entry
      if [[ $phase == select-new ]]; then selected=$new_entry fallback=$old_entry; fi
      oma-snap-boot-publish --select "$selected" --fallback "$fallback"
      grep -Fx "set default=oma-snap-$selected" "$menu"
      ;;
    check-old|check-new)
      id=$old entry=$old_entry release=$old_release
      if [[ $phase == check-new ]]; then id=$new entry=$new_entry release=$new_release; fi
      [[ $(uname -r) == "$release" ]]
      [[ $(cat /run/oma-snap/booted-set) == "$id" && $(cat /run/oma-snap/booted-entry) == "$entry" ]]
      for kind in modules firmware; do
        target=/usr/lib/$kind/$release
        options=$(findmnt -rn -M "$target" -o OPTIONS)
        [[ ,$options, == *,ro,* ]]
        [[ $(stat -c '%d:%i' "$target") == "$(stat -c '%d:%i' "/usr/lib/oma-snap/sets/$id/$kind/$release")" ]]
      done
      systemctl is-active multi-user.target
      cat /proc/sys/kernel/random/boot_id
      ;;
    *) echo 'Unknown test phase' >&2; exit 2 ;;
  esac
  for id in "$old_entry" "$new_entry" legacy; do
    [[ $(grep -Fc -- "--id 'oma-snap-$id'" "$menu") == 1 ]]
  done
fi
sha256sum -c "$work/legacy.sha256"
test ! -e /var/lib/pacman/db.lck
echo "PASS: different-ABI phase $phase; root device type $root_type"
