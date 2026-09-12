#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
input=downloads/asus-a14/bsp-1.312.8100.0.exe
mkdir -p downloads/asus-a14 build/asus-a14-audit build/asus-a14-firmware-package
if [[ ! -s $input ]]; then
  curl -fL --retry 2 --max-time 600 \
    https://dlcdnets.asus.com/pub/ASUS/nb/Image/Driver/DriverPackage/48168/SOCPackage_forWebSite_Qualcomm_Z_V1.312.8100.0_48168.exe -o "$input.part"
  mv "$input.part" "$input"
fi
echo "ce4593e948157ede6d936bec0db03b09bcbb39c3b11fab5d89c52b8954e72fde  $input" | sha256sum -c -
7z x -y -obuild/asus-a14-audit/extracted "$input" \
  QualcommBSP/qcdx8380/qcdxkmsuc8380.mbn \
  QualcommBSP/qcnspmcdm_ext_cdsp8380/cdsp_dtbs.elf \
  QualcommBSP/qcnspmcdm_ext_cdsp8380/qccdsp8380.mbn \
  QualcommBSP/qcsubsys_ext_adsp8380/adsp_dtbs.elf \
  QualcommBSP/qcsubsys_ext_adsp8380/qcadsp8380.mbn
cp packages/asus-a14-firmware/{PKGBUILD,PROVENANCE.txt} build/asus-a14-firmware-package/
docker exec oma-snap-root chown -R alarm:alarm /output/asus-a14-firmware-package
docker exec --user alarm --workdir /output/asus-a14-firmware-package oma-snap-root makepkg --nodeps --nocheck --noconfirm
sha256sum "$input" > manifests/asus-a14-firmware-input.sha256
sha256sum build/asus-a14-firmware-package/*.pkg.tar.xz > manifests/asus-a14-firmware-package.sha256
