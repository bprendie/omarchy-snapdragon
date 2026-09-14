#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 0 && ! -e build/asus-a16-audio-package ]]
mkdir build/asus-a16-audio-package
cp packages/asus-a16-audio/{PKGBUILD,PROVENANCE.txt} build/asus-a16-audio-package/
docker exec oma-snap-root chown -R alarm:alarm /output/asus-a16-audio-package
docker exec --user alarm --workdir /output/asus-a16-audio-package oma-snap-root makepkg --nodeps --noconfirm
sha256sum build/asus-a16-audio-package/*.pkg.tar.xz > manifests/asus-a16-audio-package.sha256
