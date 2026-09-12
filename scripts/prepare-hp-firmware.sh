#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p downloads/hp-firmware build/hp-firmware-audit build/hp-firmware-package
input=downloads/hp-firmware/sp162865.exe
if [[ ! -s $input ]]; then
  curl -fL --retry 2 --max-time 600 \
    https://ftp.hp.com/pub/softpaq/sp162501-163000/sp162865.exe -o "$input.part"
  mv "$input.part" "$input"
fi
sha256sum -c manifests/hp-firmware-input.sha256
# Extract data only; never run the vendor installer or flash BIOS capsules.
7z x -y -obuild/hp-firmware-audit/extracted "$input" \
  src/Driver/qcdx8380/qcdxkmsuc8380.mbn \
  src/Driver/1ADSP_7700_0711_hamoa/qcadsp8380.mbn \
  src/Driver/1ADSP_7700_0711_hamoa/adsp_dtbs.elf \
  src/Driver/1qcnspmcdm_ext_cdsp8380_7800/qccdsp8380.mbn \
  src/Driver/1qcnspmcdm_ext_cdsp8380_7800/cdsp_dtbs.elf
cp packages/hp-elitebook-firmware/{PKGBUILD,sp162865.cva,PROVENANCE.txt} build/hp-firmware-package/
docker exec oma-snap-root chown -R alarm:alarm /output/hp-firmware-package
docker exec --user alarm --workdir /output/hp-firmware-package oma-snap-root \
  makepkg --nodeps --nocheck --noconfirm
sha256sum build/hp-firmware-package/*.pkg.tar.xz > manifests/hp-firmware-package.sha256
