#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_root="$PWD/sources/omarchy-snap"
# Stock cloud-tool provisioning must not be silently removed from this port.
for file in install/user/mise.sh install/user/all.sh install/user/first-run/enable-user-units.sh; do
  cmp "sources/omarchy-release/$file" "$source_root/$file"
done
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
