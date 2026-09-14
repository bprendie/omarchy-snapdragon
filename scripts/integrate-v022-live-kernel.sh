#!/bin/bash
# Put the same retained candidate used by the installer into the live boot path.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Repository build name}
[[ $# == 1 && $name =~ ^[a-zA-Z0-9_-]+$ ]]
stage=build/snapdragon-v022
repo=build/$name
id=$(jq -er .hardware_set "$repo/approval.json")
release=$(jq -er .kernel_release "$repo/approval.json")
[[ $id =~ ^[a-f0-9]{64}$ && $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-qcom-x1e$ ]]
shopt -s nullglob
packages=("$repo/oma-snap-set-$id-"*.pkg.tar.xz)
[[ ${#packages[@]} == 1 && -d $stage/root ]]
# Installing into a disposable live filesystem runs no package scripts.
xz -dc "${packages[0]}" | docker run --rm -i --network none -v "$PWD:/work" oma-snap-builder:local \
  tar -xf - -C /work/build/snapdragon-v022/root \
  --exclude .PKGINFO --exclude .BUILDINFO --exclude .MTREE
# Initramfs preparation is a separate resumable build step.
[[ -s $stage/live-initramfs.img && -s $stage/live-initramfs.sha256 ]]
[[ $(cat "$stage/live-initramfs.set") == "$id" ]]
sha256sum -c "$stage/live-initramfs.sha256"
docker run --rm --network none -v "$PWD/build:/work" oma-snap-builder:local bash -ec '
  root=/work/snapdragon-v022/root; id=$1; release=$2
  ln -s "/usr/lib/oma-snap/sets/$id/modules/$release" "$root/usr/lib/modules/$release"
  ln -s "/usr/lib/oma-snap/sets/$id/firmware/$release" "$root/usr/lib/firmware/$release"
  cp "$root/usr/lib/oma-snap/sets/$id/vmlinuz.efi" /work/snapdragon-v022/iso/oma_snap/boot/vmlinuz.efi
  cp /work/snapdragon-v022/live-initramfs.img /work/snapdragon-v022/iso/oma_snap/boot/initramfs.img
' bash "$id" "$release"
(cd tools/inspect-kernel && go run . ../../build/snapdragon-v022/iso/oma_snap/boot/vmlinuz.efi) \
  > "$stage/live-kernel-inspection.json"
jq -e '.device_trees | any(.compatible | index("asus,zenbook-a16-ux3607oa"))' "$stage/live-kernel-inspection.json" >/dev/null
printf 'Live kernel %s; ASUS A16 hardware remains untested; see the documented feature gaps.\n' "$release"
