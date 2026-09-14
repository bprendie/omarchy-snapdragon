#!/bin/bash
# Authenticate saved inputs again, then extract only in a fresh isolated build root.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: prepare-kernel-set.sh CANDIDATE NEW_SET_NAME [EXTERNAL_POLICY]}
set_name=${2:?Missing new set name}
policy=${3:-profiles/snapdragon/kernel-track.json}
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $set_name =~ ^[a-zA-Z0-9._-]+$ ]] || exit 1
[[ ( $# == 2 || $# == 3 ) && ! -e build/kernel-sets/$set_name && -f $policy ]] || exit 1
mkdir -p build/kernel-sets
(cd tools/kernel-candidate && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o ../../build/kernel-candidate .)
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD/build/kernel-candidate:/usr/local/bin/kernel-candidate:ro" \
  -v "$(realpath "$policy"):/policy.json:ro" \
  -v "$PWD/build/kernel-candidates/$name:/candidate:ro" \
  -v "$PWD/build/kernel-sets:/sets" oma-snap-candidate-builder:local \
  kernel-candidate --policy /policy.json --verify /candidate --extract "/sets/$set_name"
