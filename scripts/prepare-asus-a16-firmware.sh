#!/bin/bash
# Build the retained, hash-pinned vendor inputs; no Windows code is executed.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 0 && ! -e build/asus-a16-firmware-package-v2 ]]
sha256sum -c manifests/asus-a16-firmware-files.sha256
sha256sum -c manifests/asus-a16-upstream-firmware.sha256
mkdir build/asus-a16-firmware-package-v2
cp -a packages/asus-a16-firmware/. build/asus-a16-firmware-package-v2/
archive=downloads/hp-audio/audioreach-e7b20b2.tar.gz
echo "bce3f22893decde37a810ed17ac690abc9c9fd39e7417021abc37e925cb1c82e  $archive" | sha256sum -c -
mkdir build/asus-a16-firmware-package-v2/topology-source
tar -xf "$archive" --strip-components=1 -C build/asus-a16-firmware-package-v2/topology-source
src=build/asus-a16-firmware-package-v2/topology-source
m4 -I "$src" "$src/GLYMUR-ASUS-Zenbook-A16-UX3607OA.m4" > "$src/a16.conf"
alsatplg -c "$src/a16.conf" -o build/asus-a16-firmware-package-v2/GLYMUR-ASUS-Zenbook-A16-UX3607OA-tplg.bin
cp "$src/LICENSE.BSD-3-Clause" build/asus-a16-firmware-package-v2/
docker exec oma-snap-root chown -R alarm:alarm /output/asus-a16-firmware-package-v2
docker exec --user alarm --workdir /output/asus-a16-firmware-package-v2 \
  oma-snap-root makepkg --nodeps --noconfirm
sha256sum build/asus-a16-firmware-package-v2/*.pkg.tar.xz > manifests/asus-a16-firmware-package.sha256
