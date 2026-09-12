#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
scripts/verify-inputs.sh
scripts/verify-kernel-update.sh
# Complete all package transactions before starting makepkg, whose BUILDINFO reads the database.
docker exec oma-snap-root test ! -e /var/lib/pacman/db.lck
for name in kernel firmware; do
  mkdir -p "build/$name-package"
  cp "packages/ubuntu-t14s-$name/PKGBUILD" "build/$name-package/"
  docker exec --user alarm --workdir "/output/$name-package" oma-snap-root makepkg --nodeps --nocheck --force
done
docker exec oma-snap-root bash -ec '
  pacman -U --noconfirm /output/kernel-package/*.pkg.tar.xz /output/firmware-package/*.pkg.tar.xz
  depmod 7.0.0-31-generic
'
sha256sum build/{kernel,firmware}-package/*.pkg.tar.xz > manifests/bridge-packages.sha256
