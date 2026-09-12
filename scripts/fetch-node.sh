#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
file=downloads/node-v26.8.2-linux-arm64.tar.gz
if [[ ! -s $file ]]; then
  curl -fL --retry 3 https://nodejs.org/dist/v26.8.2/node-v26.8.2-linux-arm64.tar.gz -o "$file.part"
  mv "$file.part" "$file"
fi
sha256sum -c manifests/node.sha256
