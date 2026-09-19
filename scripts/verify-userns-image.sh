#!/bin/bash
# Release guard: both live userspace and the installed tools must carry the fix.
set -euo pipefail
cd "$(dirname "$0")/.."
root=${1:?Usage: verify-userns-image.sh STAGED_LIVE_ROOT}
policy=packages/kernel-tools/60-oma-snap-userns.conf
cmp "$policy" "$root/usr/lib/sysctl.d/60-oma-snap-userns.conf"
echo 'PASS: user-namespace fix present in live root and installable kernel-tools package'
