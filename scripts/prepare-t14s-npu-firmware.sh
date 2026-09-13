#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
input=downloads/lenovo/n42qq23w.exe
output=build/t14s-npu-firmware-package
mkdir -p downloads/lenovo "$output/firmware"
if [[ ! -s $input ]]; then
  curl -fL --retry 2 https://download.lenovo.com/pccbbs/mobiles/n42qq23w.exe -o "$input.part"
  mv "$input.part" "$input"
fi
echo "9ec6ae30abd40f56aa6b3b0b480686acbbb72ff12ba186b3f45f61fc924ef4f3  $input" | sha256sum -c -
# Extract only; never execute the Windows installer. Requires innoextract.
innoextract -d build/t14s-npu-extracted "$input"
source_dir='build/t14s-npu-extracted/code$GetExtractPath$/N42QQ23W/N42QG16W/Core_drivers/qcnspmcdm_ext_cdsp8380'
cp "$source_dir/qccdsp8380.mbn" "$source_dir/cdsp_dtbs.elf" "$output/firmware/"
sha256sum -c manifests/t14s-npu-firmware-files.sha256
cp packages/t14s-npu-firmware/* "$output/"
docker exec oma-snap-root chown -R alarm:alarm /output/t14s-npu-firmware-package
docker exec --user alarm --workdir /output/t14s-npu-firmware-package oma-snap-root makepkg --nodeps --noconfirm --force
sha256sum "$output"/*.pkg.tar.xz > manifests/t14s-npu-firmware-package.sha256
