#!/bin/bash
# Rebuild the HP additions against the headers extracted with this candidate.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-kernel-set-camera.sh SET_NAME}
[[ $# == 1 && $name =~ ^[a-zA-Z0-9._-]+$ ]] || exit 1
set_root=build/kernel-sets/$name
release=$(jq -er .kernel_release "$set_root/extracted.json")
[[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]] || exit 1
[[ ! -e $set_root/hp-camera ]] || { echo 'Preserve the existing module build.' >&2; exit 1; }
cp -a packages/hp-camera/src "$set_root/hp-camera"
headers=/output/kernel-sets/$name/root/usr/src/linux-headers-$release
module=/output/kernel-sets/$name/hp-camera
# Generate the embedded overlay from the tracked DTS, using the candidate's dtc.
docker exec oma-snap-root "$headers/scripts/dtc/dtc" -@ -I dts -O dtb \
  -o "$module/hp-camera.dtbo" "$module/hp-camera.dts"
(cd tools/overlay-header && go run . "../../$set_root/hp-camera/hp-camera.dtbo" "../../$set_root/hp-camera/overlay-data.h")
docker exec -e KBUILD_BUILD_USER=oma-snap -e KBUILD_BUILD_HOST=builder \
  oma-snap-root make -C "$headers" M="$module" CC=gcc \
  "KCFLAGS=-ffile-prefix-map=/output/kernel-sets/$name=/usr/src/oma-snap" modules
for module_name in ov05c10 hp_camera_overlay hp_camera_children; do
  vermagic=$(modinfo -F vermagic "$set_root/hp-camera/$module_name.ko")
  [[ $vermagic == "$release "* ]] || { echo 'Module ABI does not match candidate.' >&2; exit 1; }
done
sha256sum "$set_root"/hp-camera/*.ko > "$set_root/hp-camera.sha256"
echo 'PASS: HP camera modules rebuilt for the extracted candidate ABI'
