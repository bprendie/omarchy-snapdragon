#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
revision=e7b20b2b16cdda18eb8ae143c8d95c4815c0288e
archive=downloads/hp-audio/audioreach-e7b20b2.tar.gz
mkdir -p downloads/hp-audio build/hp-audio-source build/hp-audio-package
if [[ ! -s $archive ]]; then
  curl -fL --retry 2 "https://codeload.github.com/linux-msm/audioreach-topology/tar.gz/$revision" -o "$archive.part"
  mv "$archive.part" "$archive"
fi
echo "bce3f22893decde37a810ed17ac690abc9c9fd39e7417021abc37e925cb1c82e  $archive" | sha256sum -c -
tar -xf "$archive" --strip-components=1 -C build/hp-audio-source
m4 -I build/hp-audio-source build/hp-audio-source/X1E80100-LENOVO-Thinkpad-T14s.m4 > build/hp-audio-source/hp.conf
alsatplg -c build/hp-audio-source/hp.conf -o build/hp-audio-package/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin
echo 'aa303397750f883ecaeed874d7547da658500596247676a6d405bf1ec43290b5  build/hp-audio-package/X1E80100-HP-ELITEBOOK-ULTRA-G1Q-tplg.bin' | sha256sum -c -
cp packages/hp-audio/{PKGBUILD,PROVENANCE.txt} build/hp-audio-package/
cp build/hp-audio-source/LICENSE.BSD-3-Clause build/hp-audio-package/
docker exec oma-snap-root chown -R alarm:alarm /output/hp-audio-package
docker exec --user alarm --workdir /output/hp-audio-package oma-snap-root makepkg --nodeps --nocheck --noconfirm
sha256sum build/hp-audio-package/*.pkg.tar.xz > manifests/hp-audio-package.sha256
