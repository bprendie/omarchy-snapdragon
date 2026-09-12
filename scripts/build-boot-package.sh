#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
project_root=$PWD
(
  cd tools/boot-install
  go test ./...
  go vet ./...
  GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -trimpath -o "$project_root/dist/oma-snap-boot-install" .
)
mkdir -p build/boot-package
cp packages/boot/PKGBUILD dist/oma-snap-boot-install profiles/t14s-lcd/mkinitcpio-installed.conf \
  profiles/t14s-lcd/initcpio/oma_snap_qcom build/boot-package/
docker exec oma-snap-root test ! -e /var/lib/pacman/db.lck
docker exec --user alarm --workdir /output/boot-package oma-snap-root makepkg --nodeps --noconfirm --force
sha256sum build/boot-package/*.pkg.tar.* > manifests/boot-package.sha256
