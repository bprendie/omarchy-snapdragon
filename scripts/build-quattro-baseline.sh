#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/fetch-quattro.sh
# Existing isolated ARM build root only; never invokes host pacman or setup.
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec oma-snap-root test -e /.dockerenv
docker exec oma-snap-root pacman -S --needed --noconfirm imagemagick
docker exec oma-snap-root install -d -o alarm -g alarm /output/quattro-packages
for pair in 'omarchy runtime' 'omarchy-settings settings'; do
  read -r package directory <<< "$pair"
  docker exec oma-snap-root bash -c '
    if [[ ! -d /output/quattro-packages/$2 ]]; then
      cp -a "/sources/omarchy-pkgs/pkgbuilds/$1" "/output/quattro-packages/$2"
      chown -R alarm:alarm "/output/quattro-packages/$2"
    fi
    cmp "/sources/omarchy-pkgs/pkgbuilds/$1/PKGBUILD" "/output/quattro-packages/$2/PKGBUILD"
  ' bash "$package" "$directory"
  # Baseline archive build only. --nodeps does not establish installability.
  docker exec --user alarm -e OMARCHY_SRC=/sources/omarchy-release oma-snap-root \
    bash -c 'cd "/output/quattro-packages/$1" && makepkg --nodeps --noconfirm --force' \
    bash "$directory" > "build/quattro-$directory-build.log" 2>&1
done
sha256sum build/quattro-packages/{runtime,settings}/*.pkg.tar.* > manifests/quattro-packages.sha256
