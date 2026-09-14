#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: discover-kernel-candidate.sh NEW_NAME [--download]}
[[ $name =~ ^[a-zA-Z0-9_-]+$ ]] || exit 1
[[ $# == 1 || ( $# == 2 && $2 == --download ) ]] || exit 1
policy=${OMA_SNAP_KERNEL_POLICY:-profiles/snapdragon/kernel-track.json}
[[ -f $policy ]]
mkdir -p build/kernel-candidates
[[ ! -e build/kernel-candidates/$name ]] || { echo 'Candidate already exists.' >&2; exit 1; }
(cd tools/kernel-candidate && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o ../../build/kernel-candidate .)
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD/build/kernel-candidates:/candidates" -v "$PWD/build/kernel-candidate:/usr/local/bin/kernel-candidate:ro" \
  -v "$(realpath "$policy"):/policy.json:ro" \
  -v "$PWD/profiles/snapdragon/ubuntu-concept-keyring.gpg:/concept-keyring.gpg:ro" \
  oma-snap-candidate-builder:local kernel-candidate --policy /policy.json --output "/candidates/$name" "${@:2}"
