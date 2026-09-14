#!/bin/bash
# Verify the built pair, including ownership after ARM fakeroot packaging.
set -euo pipefail
cd "$(dirname "$0")/.."
dir=${1:?Usage: quattro-update-packages.sh BUILD_DIRECTORY [VERSION] [MIN_TOOLS_VERSION]}
version=${2:-4.0.3-1.9}
minimum_tools=${3:-0.2.0-10}
[[ $version =~ ^[0-9.]+-[0-9.]+$ && $minimum_tools =~ ^[0-9.]+-[0-9.]+$ ]]
[[ $dir =~ ^build/[a-zA-Z0-9_-]+$ ]]
sha256sum -c "$dir/packages.sha256"
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
for package in omarchy omarchy-settings; do
  archive=$dir/$package/$package-$version-aarch64.pkg.tar.xz
  bsdtar --numeric-owner -tvf "$archive" > "$scratch/ownership"
  awk '$3 != 0 || $4 != 0 {print; bad=1} END {exit bad}' "$scratch/ownership"
  mkdir "$scratch/$package"
  bsdtar -xf "$archive" -C "$scratch/$package"
  grep -Fx "pkgver = $version" "$scratch/$package/.PKGINFO"
done
root=$scratch/omarchy
grep -Fx "depend = oma-snap-kernel-tools>=$minimum_tools" "$root/.PKGINFO"
grep -Fx 'depend = oma-snap-repository>=0.2.0-1' "$root/.PKGINFO"
for channel in stable rc edge; do
  cmp profiles/snapdragon/pacman-update.conf "$scratch/omarchy-settings/usr/share/omarchy/default/pacman/pacman-$channel.conf"
done
for name in omarchy-update omarchy-update-snapdragon-kernel omarchy-update-restart omarchy-update-orphan-pkgs omarchy-refresh-pacman; do
  cmp "sources/omarchy-snap/bin/$name" "$root/usr/bin/$name"
  [[ -x $root/usr/bin/$name ]]
  [[ $(readlink "$root/usr/share/omarchy/bin/$name") == /usr/bin/$name ]]
done
bash scripts/quattro-package-list.sh | cmp - "$root/usr/share/omarchy/install/omarchy-base.packages"
for package in libcamera libcamera-tools gst-plugin-libcamera pipewire-libcamera; do
  grep -Fx "$package" "$root/usr/share/omarchy/install/omarchy-base.packages"
done
echo 'PASS: update-aware Omarchy pair has root ownership, coordinated tool dependency and tested updater/camera payloads'
