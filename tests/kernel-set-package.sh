#!/bin/bash
# Verify the built package's private payload against its assembly manifest.
set -euo pipefail
cd "$(dirname "$0")/.."
package=${1:?Usage: kernel-set-package.sh ARCHIVE ASSEMBLY_DIRECTORY}
assembly=${2:?Missing assembly directory}
id=$(jq -er .id "$assembly/set.json")
[[ $id =~ ^[a-f0-9]{64}$ ]] || exit 1
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
bsdtar --numeric-owner -tvf "$package" > "$scratch/ownership"
awk '$3 != 0 || $4 != 0 {print; bad=1} END {exit bad}' "$scratch/ownership"
bsdtar -tf "$package" > "$scratch/files"
# A payload package must not own live module directories, /boot or system config.
awk -v prefix="usr/lib/oma-snap/sets/$id/" '
  /^\.(PKGINFO|BUILDINFO|MTREE)$/ { next }
  /^(usr\/|usr\/lib\/|usr\/lib\/oma-snap\/|usr\/lib\/oma-snap\/sets\/)$/ { next }
  index($0, prefix) == 1 { next }
  { print "Unexpected package path: " $0; bad=1 }
  END { exit bad }
' "$scratch/files"
mkdir "$scratch/extracted"
bsdtar -xf "$package" -C "$scratch/extracted"
root="$scratch/extracted/usr/lib/oma-snap/sets/$id"
cmp "$assembly/set.json" "$root/set.json"
build/kernel-set --verify-installed "$root"
mv "$root/set.json" "$scratch/set.json"
mv "$root" "$scratch/payload"
build/kernel-set --verify "$scratch"
echo 'PASS: package preserves the complete manifest and owns only its private set'
