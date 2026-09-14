#!/bin/bash
# Explicit maintainer approval produces a provider; this does not publish it.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 4 ]] || { echo 'Usage: build-kernel-provider-package.sh NEW_NAME APPROVAL_JSON HARDWARE_PACKAGE PREVIOUS_SEQUENCE' >&2; exit 1; }
name=$1
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $4 =~ ^[0-9]+$ ]]
dir=build/$name
[[ ! -e $dir ]]
(cd tools/kernel-promotion && go build -trimpath -o ../../build/kernel-promotion .)
build/kernel-promotion --approval "$2" --package "$3" --previous-sequence "$4" --output "$dir"
docker exec oma-snap-root test ! -e /var/lib/pacman/db.lck
docker exec --user alarm -e SOURCE_DATE_EPOCH=1785542400 -e LC_ALL=C -e TZ=UTC \
  oma-snap-root bash -ec '
    stage=/tmp/oma-snap-kernel-provider-build
    mkdir "$stage"
    trap '\''rm -rf "$stage"'\'' EXIT
    cp "/output/$1/"{PKGBUILD,candidate.json} "$stage/"
    cd "$stage"
    PKGDEST="/output/$1" makepkg --nodeps --noconfirm
  ' bash "$name"
shopt -s nullglob
archives=("$dir/"*.pkg.tar.*)
[[ ${#archives[@]} == 1 ]]
normalized="$dir/oma-snap-kernel-$(jq -er .sequence "$dir/candidate.json")-1-aarch64.pkg.tar.xz"
if [[ ${archives[0]} != "$normalized" ]]; then
  mv "${archives[0]}" "$normalized"
  archives=("$normalized")
fi
bsdtar -xOf "${archives[0]}" usr/share/oma-snap/kernel-provider/candidate.json | cmp - "$dir/candidate.json"
sha256sum "${archives[0]}" > "$dir/package.sha256"
echo "Built approved provider: $dir; not signed or published"
