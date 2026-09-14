#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root=$PWD
name=${1:-boot-package}
[[ $# -le 1 && $name =~ ^[a-zA-Z0-9_-]+$ ]]
if [[ $# == 1 ]]; then [[ ! -e build/$name ]]; fi
(
  cd tools/boot-install
  go test ./...
  go vet ./...
  GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -o "$project_root/dist/oma-snap-boot-install" .
)
mkdir -p "build/$name"
cp packages/boot/PKGBUILD dist/oma-snap-boot-install profiles/t14s-lcd/mkinitcpio-installed.conf \
  profiles/t14s-lcd/initcpio/oma_snap_qcom "build/$name/"
docker exec oma-snap-root test ! -e /var/lib/pacman/db.lck
docker exec --user alarm --workdir "/output/$name" oma-snap-root makepkg --nodeps --noconfirm --force
if [[ $# == 0 ]]; then
  sha256sum "build/$name/"*.pkg.tar.* > manifests/boot-package.sha256
else
  sha256sum "build/$name/"*.pkg.tar.* > "build/$name/package.sha256"
fi
