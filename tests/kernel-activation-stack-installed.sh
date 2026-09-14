#!/bin/bash
# Installed ARM QEMU only; upgrade the real updater while its provider is unapproved.
set -euo pipefail
[[ $EUID == 0 && $(uname -m) == aarch64 && $(systemd-detect-virt) == qemu ]]
[[ $(findmnt -n -o SOURCE /boot) == /dev/vda1 && ! -e /var/lib/pacman/db.lck ]]
[[ $(systemctl show oma-snap-kernel-prepare.service -p ActiveState --value) == inactive ]]
[[ $(jq -r .status /usr/share/oma-snap/kernel-provider/candidate.json) == unvalidated ]]
[[ ! -e /var/lib/oma-snap/provider-activation.json ]]
work=/var/tmp/oma-snap-activation-stack-test
repo=/var/tmp/kernel-repo-v020-activation-test
[[ ! -e $work ]]
(cd "$repo" && sha256sum -c SHA256SUMS)
mkdir "$work"
sha256sum /boot/oma-snap/grub/grub.cfg > "$work/grub-before.sha256"
cat > "$work/pacman.conf" <<CONF
[options]
Architecture = aarch64
CheckSpace
SigLevel = PackageRequired DatabaseRequired TrustedOnly
[oma-snap-test]
Server = file://$repo
CONF
env OMARCHY_UPDATE_PACMAN=1 pacman --config "$work/pacman.conf" -Syu --noconfirm
[[ $(pacman -Q oma-snap-kernel-tools) == 'oma-snap-kernel-tools 0.2.0-10' ]]
[[ $(pacman -Q omarchy) == 'omarchy 4.0.3-1.9' ]]
[[ $(pacman -Q omarchy-settings) == 'omarchy-settings 4.0.3-1.9' ]]
export OMARCHY_PATH=/usr/share/omarchy
export PATH="$OMARCHY_PATH/bin:$PATH"
omarchy-update-snapdragon-kernel
sha256sum -c "$work/grub-before.sha256"
[[ ! -e /var/lib/oma-snap/provider-activation.json && ! -e /var/lib/pacman/db.lck ]]
[[ $(systemctl show oma-snap-kernel-prepare.service -p ActiveState --value) == inactive ]]
echo 'PASS: signed activation-aware updater installed; unapproved provider remains unselected'
