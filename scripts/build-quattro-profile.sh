#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/prepare-quattro-profile.sh
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec oma-snap-root test -e /.dockerenv
docker exec oma-snap-root install -d -o alarm -g alarm /output/quattro-profile
for package in omarchy omarchy-settings; do
  docker exec oma-snap-root bash -c '
    [[ ! -e /output/quattro-profile/$1 ]]
    cp -a "/sources/omarchy-pkgs/pkgbuilds/$1" "/output/quattro-profile/$1"
    sed -i "s/^pkgrel=1$/pkgrel=1.4/" "/output/quattro-profile/$1/PKGBUILD"
    chown -R alarm:alarm "/output/quattro-profile/$1"
  ' bash "$package"
  docker exec --user alarm -e OMARCHY_SRC=/sources/omarchy-snap oma-snap-root \
    bash -c 'cd "/output/quattro-profile/$1" && makepkg --nodeps --noconfirm' \
    bash "$package" > "build/quattro-profile-$package.log" 2>&1
done
sha256sum build/quattro-profile/*/*.pkg.tar.* > manifests/quattro-profile-packages.sha256
