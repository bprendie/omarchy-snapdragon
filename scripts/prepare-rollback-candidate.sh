#!/bin/bash
# Explicitly test an older ABI from current signed indexes; never change the track.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: prepare-rollback-candidate.sh NEW_CANDIDATE KERNEL_RELEASE}
release=${2:?Missing older test ABI}
[[ $# == 2 && $name =~ ^[a-zA-Z0-9_-]+$ ]]
[[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]]
policy=build/kernel-rollback-policies/$name.json
[[ ! -e $policy && ! -e build/kernel-candidates/$name ]]
mkdir -p build/kernel-rollback-policies build/kernel-candidates
jq --arg release "$release" '.rollback_test_release = $release' \
  profiles/snapdragon/kernel-track.json > "$policy"
(cd tools/kernel-candidate && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o ../../build/kernel-candidate .)
docker run --rm --user "$(id -u):$(id -g)" \
  -v "$PWD/build/kernel-candidate:/usr/local/bin/kernel-candidate:ro" \
  -v "$PWD/$policy:/policy.json:ro" \
  -v "$PWD/build/kernel-candidates:/candidates" oma-snap-candidate-builder:local \
  kernel-candidate --policy /policy.json --output "/candidates/$name" --download
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD/build/kernel-candidate:/usr/local/bin/kernel-candidate:ro" \
  -v "$PWD/$policy:/policy.json:ro" \
  -v "$PWD/build/kernel-candidates/$name:/candidate:ro" oma-snap-candidate-builder:local \
  kernel-candidate --policy /policy.json --verify /candidate
echo "Rollback-only candidate: build/kernel-candidates/$name; external policy: $policy"
