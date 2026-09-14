#!/bin/bash
# Build the update-aware Omarchy pair separately from the published MVP pair.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-quattro-update-profile.sh NEW_BUILD_NAME}
[[ $name =~ ^[a-zA-Z0-9_-]+$ && ! -e build/$name ]]
bash scripts/prepare-quattro-profile.sh
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec oma-snap-root test -e /.dockerenv
docker exec oma-snap-root install -d -o alarm -g alarm "/output/$name"
cp profiles/snapdragon/pacman-update.conf "build/$name/pacman-update.conf"
docker exec oma-snap-root bash -ec '
  dest=/output/$1/source
  mkdir "$dest"
  cp -a /sources/omarchy-snap/. "$dest/"
  rm -f "$dest/.git"
  for channel in stable rc edge; do
    cp "/output/$1/pacman-update.conf" "$dest/default/pacman/pacman-$channel.conf"
  done
  chown -R alarm:alarm "$dest"
' bash "$name"
for package in omarchy omarchy-settings; do
  docker exec oma-snap-root bash -ec '
    dest=/output/$1/$2
    [[ ! -e $dest ]]
    cp -a "/sources/omarchy-pkgs/pkgbuilds/$2" "$dest"
    sed -i "s/^pkgrel=1$/pkgrel=1.9/" "$dest/PKGBUILD"
    if [[ $2 == omarchy ]]; then
      printf "\ndepends_aarch64+=(\047oma-snap-kernel-tools>=0.2.0-10\047)\n" >> "$dest/PKGBUILD"
      printf "depends_aarch64+=(\047oma-snap-repository>=0.2.0-1\047)\n" >> "$dest/PKGBUILD"
    fi
    chown -R alarm:alarm "$dest"
  ' bash "$name" "$package"
  docker exec --user alarm -e "OMARCHY_SRC=/output/$name/source" \
    -e SOURCE_DATE_EPOCH=1785542400 -e LC_ALL=C -e TZ=UTC oma-snap-root \
    bash -ec 'cd "/output/$1/$2"; makepkg --nodeps --noconfirm' \
    bash "$name" "$package" > "build/$name/$package.log" 2>&1
done
sha256sum "build/$name/"*/*.pkg.tar.* > "build/$name/packages.sha256"
git -C sources/omarchy-snap rev-parse HEAD > "build/$name/source-revision"
sha256sum patches/000{2,4,5,6,7}-*.patch > "build/$name/source-patches.sha256"
sha256sum profiles/snapdragon/pacman-update.conf > "build/$name/repository-profile.sha256"
echo "Built update-aware Omarchy pair: build/$name"
