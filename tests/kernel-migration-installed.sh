#!/bin/bash
# Full installed ARM VM only. Run phases across explicit guest reboots; this
# script never reboots and never runs on a physical laptop.
set -euo pipefail
phase=${1:?Usage: kernel-migration-installed.sh PHASE HARDWARE_SET}
set_id=${2:?Missing hardware-set identity}
[[ $set_id =~ ^[a-f0-9]{64}$ ]]
[[ $(uname -m) == aarch64 && $EUID == 0 && $(systemd-detect-virt) == qemu ]]
[[ $(findmnt -n -o SOURCE /boot) == /dev/vda1 ]]
[[ $(systemctl show oma-snap-kernel-prepare.service -p ActiveState --value) == inactive ]]
[[ ! -e /var/lib/pacman/db.lck ]]
work=/var/tmp/oma-snap-installed-migration
complete=/var/lib/oma-snap/jobs/complete/$set_id.json
entry=$(jq -er '.boot_entry' "$complete")
[[ $entry =~ ^[a-f0-9]{64}$ ]]
release=$(jq -er '.kernel_release' "/usr/lib/oma-snap/sets/$set_id/set.json")
menu=/boot/oma-snap/grub/grub.cfg
case "$phase" in
  migrate)
    [[ ! -e $work ]]
    mkdir "$work"
    cp "$menu" "$work/released-grub.cfg"
    sha256sum /boot/oma-snap/7.0.0-31-generic/{vmlinuz.efi,initramfs.img} > "$work/released-payload.sha256"
    oma-snap-boot-publish --migrate-legacy --select legacy --fallback "$entry"
    cmp "$work/released-grub.cfg" /boot/oma-snap/grub/legacy/grub.cfg
    grep -Fx 'set default=oma-snap-legacy' "$menu"
    ;;
  activate)
    sha256sum -c "$work/released-payload.sha256"
    oma-snap-boot-publish --select "$entry" --fallback legacy
    grep -Fx "set default=oma-snap-$entry" "$menu"
    ;;
  check-candidate)
    [[ $(cat /run/oma-snap/booted-set) == "$set_id" ]]
    [[ $(cat /run/oma-snap/booted-entry) == "$entry" ]]
    [[ $(uname -r) == "$release" ]]
    for kind in modules firmware; do
      options=$(findmnt -rn -M "/usr/lib/$kind/$release" -o OPTIONS)
      [[ ,$options, == *,ro,* ]]
      [[ $(stat -c '%d:%i' "/usr/lib/$kind/$release") == \
         "$(stat -c '%d:%i' "/usr/lib/oma-snap/sets/$set_id/$kind/$release")" ]]
    done
    systemctl is-active multi-user.target
    sha256sum -c "$work/released-payload.sha256"
    ;;
  rollback)
    oma-snap-boot-publish --select legacy --fallback "$entry"
    grep -Fx 'set default=oma-snap-legacy' "$menu"
    ;;
  check-legacy)
    [[ $(uname -r) == 7.0.0-31-generic ]]
    [[ ! -e /run/oma-snap/booted-set && ! -e /run/oma-snap/booted-entry ]]
    for kind in modules firmware; do
      ! mountpoint -q "/usr/lib/$kind/7.0.0-31-generic"
    done
    systemctl is-active multi-user.target
    sha256sum -c "$work/released-payload.sha256"
    ;;
  *) echo "Unknown phase: $phase" >&2; exit 2 ;;
esac
test ! -e /var/lib/pacman/db.lck
echo "PASS: installed VM migration phase $phase"
