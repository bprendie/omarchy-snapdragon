#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p sources
while read -r name url revision; do
  directory="sources/$name"
  if [[ ! -d $directory ]]; then
    git init "$directory"
    git -C "$directory" remote add origin "$url"
    git -C "$directory" fetch --depth 1 origin "$revision"
    git -C "$directory" checkout --detach "$revision"
  fi
  actual=$(git -C "$directory" rev-parse HEAD)
  [[ $actual == "$revision" ]] || { echo "$name: expected $revision, found $actual" >&2; exit 1; }
  [[ -z $(git -C "$directory" status --porcelain) ]] || { echo "$name: modified source tree" >&2; exit 1; }
done < manifests/quattro-sources.tsv
