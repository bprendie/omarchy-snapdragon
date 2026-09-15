#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
dir=${1:?Usage: kernel-tools-package.sh BUILD_DIRECTORY}
[[ $dir =~ ^build/[a-zA-Z0-9_-]+$ ]]
shopt -s nullglob
archives=("$dir"/oma-snap-kernel-tools-*.pkg.tar.xz)
[[ ${#archives[@]} == 1 ]]
archive=${archives[0]}
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
bsdtar -xf "$archive" -C "$scratch"
for tool in kernel-set boot-stage boot-publish kernel-retain kernel-queue kernel-maintenance; do
  cmp "$dir/oma-snap-$tool" "$scratch/usr/bin/oma-snap-$tool"
  [[ -x $scratch/usr/bin/oma-snap-$tool ]]
  file "$scratch/usr/bin/oma-snap-$tool" | grep -q 'ARM aarch64'
done
cmp profiles/snapdragon/alpm-hooks/60-depmod.hook "$scratch/etc/pacman.d/hooks/60-depmod.hook"
cmp profiles/snapdragon/systemd/linux-modules-cleanup-oma-snap.conf "$scratch/usr/lib/systemd/system/linux-modules-cleanup.service.d/oma-snap.conf"
cmp profiles/snapdragon/mkinitcpio-update.conf "$scratch/usr/share/oma-snap/kernel-update/mkinitcpio.conf"
cmp packages/kernel-tools/60-oma-snap-userns.conf "$scratch/usr/lib/sysctl.d/60-oma-snap-userns.conf"
cmp profiles/t14s-lcd/initcpio/oma_snap_qcom "$scratch/usr/lib/initcpio/install/oma_snap_qcom_update"
cmp profiles/snapdragon/initcpio/hooks/oma_snap_set "$scratch/usr/lib/initcpio/hooks/oma_snap_set"
cmp profiles/snapdragon/initcpio/install/oma_snap_set "$scratch/usr/lib/initcpio/install/oma_snap_set"
for hook in 01-oma-snap-retain 02-oma-snap-retain-legacy 95-oma-snap-prepare; do
  cmp "profiles/snapdragon/alpm-hooks/$hook.hook" "$scratch/usr/share/libalpm/hooks/$hook.hook"
done
for type in path service; do
  cmp "profiles/snapdragon/systemd/oma-snap-kernel-prepare.$type" "$scratch/usr/lib/systemd/system/oma-snap-kernel-prepare.$type"
done
grep -Fx 'backup = etc/oma-snap/esp-path' "$scratch/.PKGINFO"
grep -Fx 'backup = etc/pacman.d/hooks/60-depmod.hook' "$scratch/.PKGINFO"
grep -Fx 'depend = kernel-modules-hook' "$scratch/.PKGINFO"
grep -Fx 'depend = rsync' "$scratch/.PKGINFO"
grep -Fx /boot "$scratch/etc/oma-snap/esp-path"
[[ ! -e $scratch/usr/bin/oma-snap-boot-install && ! -e $scratch/usr/lib/initcpio/install/oma_snap_qcom ]]
[[ ! -e $scratch/usr/share/oma-snap/mkinitcpio-installed.conf && ! -e $scratch/boot ]]
echo 'PASS: ARM tools and scoped hooks/configuration packaged without legacy boot ownership'
