#!/bin/bash
# Assemble a candidate hardware package from built kernel inputs and pinned firmware.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: prepare-hardware-package.sh SET_NAME NEW_PACKAGE_NAME [--asus-a16]}
package=${2:?Missing new package name}
[[ ( $# == 2 || ( $# == 3 && $3 == --asus-a16 ) ) && $name =~ ^[a-zA-Z0-9._-]+$ && $package =~ ^[a-zA-Z0-9._-]+$ ]] || exit 1
destination=build/kernel-sets/$package
firmware=build/kernel-sets/$package-firmware
[[ ! -e $destination && ! -e $firmware ]] || exit 1
mkdir "$firmware"
# These are local MVP packages with separately recorded vendor provenance.
# Hash pinning does not grant firmware redistribution rights.
inputs=(
  build/firmware-package/oma-snap-firmware-ubuntu-20260319.217ca6e4-2-any.pkg.tar.xz
  build/hp-firmware-package/oma-snap-firmware-hp-7700.1-1-any.pkg.tar.xz
  build/asus-a14-firmware-package/oma-snap-firmware-asus-a14-1.312.8100.0-1-any.pkg.tar.xz
  build/t14s-npu-firmware-package/oma-snap-firmware-t14s-npu-1.0.0.23-1-any.pkg.tar.xz
  build/hp-audio-package/oma-snap-audio-hp-0.1.0-1-any.pkg.tar.xz
)
manifests=(manifests/bridge-packages.sha256 manifests/hp-firmware-package.sha256 manifests/asus-a14-firmware-package.sha256 manifests/t14s-npu-firmware-package.sha256 manifests/hp-audio-package.sha256)
if [[ ${3:-} == --asus-a16 ]]; then
  inputs+=(build/asus-a16-firmware-package-v2/oma-snap-firmware-asus-a16-1.312.4500.0-2-any.pkg.tar.xz)
  manifests+=(manifests/asus-a16-firmware-package.sha256)
fi
args=()
for i in "${!inputs[@]}"; do
  archive=${inputs[$i]}
  awk -v path="$archive" '$2 == path { print; found++ } END { if (found != 1) exit 1 }' "${manifests[$i]}" > "$firmware/check.sha256"
  sha256sum -c "$firmware/check.sha256"
  identity=$(bsdtar -xOf "$archive" .PKGINFO | awk '$1 == "pkgname" { print $3 }')
  [[ $identity =~ ^oma-snap-firmware-[a-z0-9-]+$ || $identity == oma-snap-audio-hp ]] || exit 1
  mkdir "$firmware/$identity"
  bsdtar -xf "$archive" -C "$firmware/$identity"
  args+=(--firmware "$firmware/$identity")
done
(cd tools/kernel-set && go build -trimpath -o ../../build/kernel-set .)
build/kernel-set --input "build/kernel-sets/$name" --output "$destination" "${args[@]}"
build/kernel-set --verify "$destination"
