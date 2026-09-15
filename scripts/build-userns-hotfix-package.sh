#!/bin/bash
# Repackage the released tools payload unchanged, adding only the sysctl fix.
# This avoids importing unrelated development hook changes into the hotfix.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 2 ]] || { echo 'Usage: build-userns-hotfix-package.sh BASELINE_TOOLS_PACKAGE NEW_BUILD_NAME' >&2; exit 1; }
baseline=$1 name=$2
[[ -f $baseline && $name =~ ^[a-zA-Z0-9_-]+$ && ! -e build/$name ]]
destination=$PWD/build/$name
mkdir -p "$destination/payload"
bsdtar -xf "$baseline" -C "$destination/payload"
grep -Fxq 'pkgname = oma-snap-kernel-tools' "$destination/payload/.PKGINFO"
grep -Fxq 'pkgver = 0.2.2-1' "$destination/payload/.PKGINFO"
cp "$destination/payload/.PKGINFO" "$destination/baseline.PKGINFO"
cp "$destination/payload/.INSTALL" "$destination/kernel-tools.install"
rm "$destination/payload/"{.PKGINFO,.BUILDINFO,.MTREE,.INSTALL}
cp packages/kernel-tools/60-oma-snap-userns.conf "$destination/"
python3 - "$destination/PKGBUILD" <<'PY'
from pathlib import Path
import sys
metadata = Path('packages/kernel-tools/PKGBUILD').read_text().split('package() {', 1)[0]
Path(sys.argv[1]).write_text(metadata + '''package() {
  cp -a "$startdir/payload/." "$pkgdir/"
  install -Dm644 "$startdir/60-oma-snap-userns.conf" "$pkgdir/usr/lib/sysctl.d/60-oma-snap-userns.conf"
}
''')
PY
docker exec --user alarm -e SOURCE_DATE_EPOCH=1789488000 -e LC_ALL=C -e TZ=UTC \
  oma-snap-root bash -ec 'cd "/output/$1"; makepkg --nodeps --noconfirm' bash "$name"
sha256sum "$destination"/*.pkg.tar.* > "$destination/package.sha256"
echo "Built $destination; original runtime files retained"
