#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_root="$PWD/sources/omarchy-snap"
git -C "$source_root" apply --reverse --check "$PWD/patches/0004-quattro-retained-kernel-orphans.patch"
git -C "$source_root" apply --reverse --check "$PWD/patches/0005-quattro-kernel-preparation-wait.patch"
git -C "$source_root" apply --reverse --check "$PWD/patches/0006-quattro-kernel-reboot-identity.patch"
git -C "$source_root" apply --reverse --check "$PWD/patches/0007-quattro-refresh-kernel-wait.patch"
git -C "$source_root" apply --reverse --check "$PWD/patches/0002-quattro-arm-profile.patch"
bash scripts/quattro-package-list.sh | cmp - "$source_root/install/omarchy-base.packages"
# Stock cloud-tool provisioning must not be silently removed from this port.
for file in install/user/mise.sh install/user/first-run/enable-user-units.sh; do
  cmp "sources/omarchy-release/$file" "$source_root/$file"
done
trackpoint='run_logged "$OMARCHY_INSTALL/user/hardware/lenovo/t14s-trackpoint.sh"'
[[ $(grep -Fxc "$trackpoint" "$source_root/install/user/all.sh") == 1 ]]
awk -v added="$trackpoint" '$0 != added' "$source_root/install/user/all.sh" |
  cmp sources/omarchy-release/install/user/all.sh -
[[ ! -e $source_root/default/local-only ]]
bash scripts/quattro-package-list.sh | grep -qx herdr
for channel in stable edge rc; do
  cmp profiles/t14s-lcd/pacman.conf "$source_root/default/pacman/pacman-$channel.conf"
  cmp profiles/t14s-lcd/mirrorlist "$source_root/default/pacman/mirrorlist-$channel"
done
bash -n "$source_root/install/user/mise-work.sh"
bash "$source_root/test/shell.d/first-run-test.sh"
bash "$source_root/test/shell.d/provision-user-test.sh"
echo 'PASS: stock AI setup retained; ARM repositories retained; provisioning regressions pass'
