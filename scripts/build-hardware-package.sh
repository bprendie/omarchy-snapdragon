#!/bin/bash
# Build an assembled private hardware set at a fixed makepkg path.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-hardware-package.sh PACKAGE_NAME}
[[ $# == 1 && $name =~ ^[a-zA-Z0-9._-]+$ ]]
dir=build/kernel-sets/$name
[[ -f $dir/PKGBUILD && -f $dir/set.json ]]
shopt -s nullglob
archives=("$dir/"*.pkg.tar "$dir/"*.pkg.tar.*)
[[ ${#archives[@]} == 0 ]]
(cd tools/kernel-set && go build -trimpath -o ../../build/kernel-set .)
build/kernel-set --verify "$dir"
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec --user alarm -e SOURCE_DATE_EPOCH=1785542400 -e LC_ALL=C -e TZ=UTC \
  oma-snap-root bash -ec '
    stage=/tmp/oma-snap-hardware-package-build
    mkdir "$stage"
    cleanup() { rm -rf "$stage"; }
    trap cleanup EXIT
    cp -a --reflink=auto "/output/kernel-sets/$1/"{PKGBUILD,set.json,payload} "$stage/"
    cd "$stage"
    cp /etc/makepkg.conf "$stage/makepkg.conf"
    echo PKGEXT=.pkg.tar >> "$stage/makepkg.conf"
    PKGDEST="/output/kernel-sets/$1" makepkg --config "$stage/makepkg.conf" --nodeps --noconfirm
  ' bash "$name"
raw=("$dir/"*.pkg.tar)
if (( ${#raw[@]} )); then xz -T4 -1 "${raw[@]}"; fi
sha256sum "$dir/"*.pkg.tar.* > "$dir/package.sha256"
echo "Built retained hardware package: $dir"
