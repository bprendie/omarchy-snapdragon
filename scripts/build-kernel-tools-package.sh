#!/bin/bash
# Build update tooling without changing the published legacy installer package.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-kernel-tools-package.sh NEW_BUILD_NAME}
[[ $name =~ ^[a-zA-Z0-9_-]+$ ]]
dir=build/$name
[[ ! -e $dir ]]
mkdir -p "$dir"
destination=$PWD/$dir
for tool in kernel-set boot-stage boot-publish kernel-retain kernel-queue kernel-maintenance; do
  (cd "tools/$tool" && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 \
    go build -trimpath -buildvcs=false -ldflags=-buildid= -o "$destination/oma-snap-$tool" .)
done
cp packages/kernel-tools/{PKGBUILD,kernel-tools.install,esp-path} "$dir/"
cp profiles/snapdragon/mkinitcpio-update.conf "$dir/"
cp profiles/t14s-lcd/initcpio/oma_snap_qcom "$dir/oma_snap_qcom_update"
cp profiles/snapdragon/initcpio/install/oma_snap_set "$dir/oma_snap_set_install"
cp profiles/snapdragon/initcpio/hooks/oma_snap_set "$dir/oma_snap_set_hook"
cp profiles/snapdragon/alpm-hooks/*.hook profiles/snapdragon/systemd/* "$dir/"
docker exec oma-snap-root test ! -e /var/lib/pacman/db.lck
docker exec --user alarm \
  -e SOURCE_DATE_EPOCH=1785542400 -e LC_ALL=C -e TZ=UTC \
  oma-snap-root bash -ec '
    task=/tmp/oma-snap-kernel-tools-build
    mkdir "$task"
    trap '\''rm -rf "$task"'\'' EXIT
    cp -a "/output/$1/." "$task/"
    cd "$task"
    PKGDEST="/output/$1" makepkg --nodeps --noconfirm
  ' bash "$name"
sha256sum "$dir"/*.pkg.tar.* > "$dir/package.sha256"
echo "Built local kernel tools package: $dir"
