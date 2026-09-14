#!/bin/bash
# Installed ARM VM only; queue the authenticated different-ABI rollback fixture.
set -euo pipefail
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
[[ $(findmnt -n -o SOURCE /boot) == /dev/vda1 ]]
[[ ! -e /var/lib/pacman/db.lck ]]
id=4f9f71d26d9a93760cd0a4315d5e7656903ef00377b6b17912f4c168b125849d
[[ ! -e /usr/lib/oma-snap/sets/$id ]]
work=/var/tmp/oma-snap-abi30-install-test
[[ ! -e $work ]]
mkdir "$work"
sha256sum /boot/oma-snap/grub/grub.cfg > "$work/grub-before.sha256"
cat > "$work/pacman.conf" <<'CONF'
[options]
Architecture = aarch64
CheckSpace
SigLevel = PackageRequired DatabaseRequired TrustedOnly
[oma-snap-test]
Server = file:///var/tmp/kernel-repo-v020-abi30-test
CONF
env OMARCHY_UPDATE_PACMAN=1 pacman --config "$work/pacman.conf" -Syu --noconfirm "oma-snap-set-$id"
[[ $(pacman -Q oma-snap-kernel-tools) == 'oma-snap-kernel-tools 0.2.0-9' ]]
systemctl start --wait oma-snap-kernel-prepare.service
complete=/var/lib/oma-snap/jobs/complete/$id.json
entry=$(jq -er '.boot_entry' "$complete")
[[ $entry =~ ^[a-f0-9]{64}$ ]]
jq -e --arg id "$id" '.hardware_set == $id and .kernel_release == "7.0.0-30-generic"' "/boot/oma-snap/entries/$entry/entry.json"
sha256sum -c "$work/grub-before.sha256"
oma-snap-kernel-queue --check-provider-prepared
test ! -e /var/lib/pacman/db.lck
echo 'PASS: different-ABI test set prepared automatically without changing the installed provider or boot selection'
