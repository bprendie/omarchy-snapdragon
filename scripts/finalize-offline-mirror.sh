#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run after prepare-offline-mirror.sh has finished, never concurrently with repo-add.
test -s manifests/offline-packages.sha256
cp profiles/t14s-lcd/installer-extra.packages build/quattro-installer-targets
docker exec oma-snap-root bash -ec '
  mapfile -t installer_targets < /output/quattro-installer-targets
  pacman --dbpath /output/quattro-offline-db -Sw --noconfirm --cachedir /output/pkg-cache "${installer_targets[@]}"
  pacman --dbpath /output/quattro-offline-db -Sp --print-format "%f" "${installer_targets[@]}" > /output/quattro-extra-files
  while read -r filename; do
    cp -a "/output/pkg-cache/$filename" "/output/pkg-cache/$filename.sig" /output/offline-mirror/
  done < /output/quattro-extra-files
  chown -R 1000:1000 /output/offline-mirror
' > build/offline-mirror-finalize.log 2>&1
shopt -s nullglob
local_packages=(build/quattro-profile/*/*.pkg.tar.xz build/kernel-package/*.pkg.tar.xz build/firmware-package/*.pkg.tar.xz build/boot-package/*.pkg.tar.xz)
[[ ${#local_packages[@]} == 5 ]]
declare -A local_names=()
for package in "${local_packages[@]}"; do local_names[${package##*/}]=1; done
upstream=() local_mirror=()
for package in build/offline-mirror/*.pkg.tar.{xz,zst}; do
  if [[ ${local_names[${package##*/}]:-} == 1 ]]; then
    local_mirror+=("$package")
  else
    [[ -s $package.sig ]] || { echo "Missing upstream signature: $package" >&2; exit 1; }
    upstream+=("$package")
  fi
done
[[ ${#local_mirror[@]} == 5 && ${#upstream[@]} -gt 100 ]]
rm -f build/offline-mirror/{offline,oma-snap-local}.{db,files}*
# Native host tooling only indexes archives; it executes no ARM payload or install hooks.
repo-add --include-sigs build/offline-mirror/offline.db.tar.gz "${upstream[@]}" >> build/offline-mirror-finalize.log 2>&1
repo-add build/offline-mirror/oma-snap-local.db.tar.gz "${local_mirror[@]}" >> build/offline-mirror-finalize.log 2>&1
repo-add --version > manifests/offline-indexer-version.txt
sha256sum build/offline-mirror/*.pkg.tar.{xz,zst} > manifests/offline-packages.sha256
