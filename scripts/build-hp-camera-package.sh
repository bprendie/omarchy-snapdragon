#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
output=build/hp-camera-package
headers=/usr/src/linux-headers-7.0.0-31-generic
docker exec oma-snap-root test -f "$headers/Module.symvers"
mkdir -p "$output"
cp -a packages/hp-camera/. "$output/"
docker exec oma-snap-root "$headers/scripts/dtc/dtc" -@ -I dts -O dtb \
  -o /output/hp-camera-package/src/hp-camera.dtbo /output/hp-camera-package/src/hp-camera.dts
python3 - <<'PY'
from pathlib import Path
p = Path('build/hp-camera-package/src')
data = (p / 'hp-camera.dtbo').read_bytes()
(p / 'overlay-data.h').write_text('static const unsigned char overlay_data[] __aligned(8) = {\n' + ','.join(hex(x) for x in data) + '\n};\n')
PY
docker exec oma-snap-root make -C "$headers" M=/output/hp-camera-package/src CC=gcc modules
docker exec oma-snap-root chown -R alarm:alarm /output/hp-camera-package
docker exec --user alarm --workdir /output/hp-camera-package oma-snap-root makepkg --nodeps --noconfirm --force
