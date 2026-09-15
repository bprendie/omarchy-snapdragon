#!/bin/bash
# Release guard: both live userspace and the installed tools must carry the fix.
set -euo pipefail
cd "$(dirname "$0")/.."
root=${1:?Usage: verify-userns-image.sh STAGED_LIVE_ROOT}
policy=packages/kernel-tools/60-oma-snap-userns.conf
cmp "$policy" "$root/usr/lib/sysctl.d/60-oma-snap-userns.conf"
shopt -s nullglob
archives=("$root"/var/cache/oma-snap/repository/oma-snap-kernel-tools-*.pkg.tar.{xz,zst,gz})
[[ ${#archives[@]} == 1 ]] || { echo 'Expected exactly one signed-repository kernel-tools package' >&2; exit 1; }
bsdtar -xOf "${archives[0]}" usr/lib/sysctl.d/60-oma-snap-userns.conf | cmp - "$policy"
echo 'PASS: user-namespace fix present in live root and installable kernel-tools package'
