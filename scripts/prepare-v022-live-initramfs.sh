#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
set_name=${1:?Hardware package build name}
[[ $# == 1 && $set_name =~ ^[a-zA-Z0-9._-]+$ ]]
payload=build/kernel-sets/$set_name/payload
id=$(jq -er .id "build/kernel-sets/$set_name/set.json")
release=$(jq -er .kernel_release "build/kernel-sets/$set_name/set.json")
[[ $id =~ ^[a-f0-9]{64}$ && $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-qcom-x1e$ ]]
stage=build/snapdragon-v022
[[ -d $stage/root && ! -e $stage/live-initramfs.img ]]
docker cp profiles/t14s-lcd/mkinitcpio.conf oma-snap-root:/etc/mkinitcpio-oma-snap.conf
docker cp profiles/t14s-lcd/initcpio/oma_snap_qcom oma-snap-root:/usr/lib/initcpio/install/oma_snap_qcom
docker exec oma-snap-root bash -ec '
  release=$1; payload=/output/kernel-sets/$2/payload
  test ! -e "/usr/lib/modules/$release"
  test ! -e "/usr/lib/firmware/$release"
  cp -a --reflink=auto "$payload/modules/$release" /usr/lib/modules/
  cp -a --reflink=auto "$payload/firmware/$release" /usr/lib/firmware/
  cp "$payload/vmlinuz.efi" "/boot/vmlinuz-$release"
  mkinitcpio --nopost -k "$release" -c /etc/mkinitcpio-oma-snap.conf -g /output/snapdragon-v022/live-initramfs.img
  lsinitcpio /output/snapdragon-v022/live-initramfs.img > /output/snapdragon-v022/live-initramfs-contents.txt
  chmod 644 /output/snapdragon-v022/live-initramfs.img /output/snapdragon-v022/live-initramfs-contents.txt
' bash "$release" "$set_name"
sha256sum "$stage/live-initramfs.img" > "$stage/live-initramfs.sha256"
printf '%s\n' "$id" > "$stage/live-initramfs.set"
