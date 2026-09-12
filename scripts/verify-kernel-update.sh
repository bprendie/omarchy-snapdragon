#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c manifests/ubuntu-kernel-7.0.0-31-index.sha256 \
  manifests/ubuntu-kernel-7.0.0-31.sha256
for index in InRelease security/InRelease; do
  docker run --rm --network none \
    -v "$PWD/downloads/ubuntu-kernel-current:/audit:ro" oma-snap-builder:local \
    gpgv --keyring /usr/share/keyrings/ubuntu-archive-keyring.gpg \
    "/audit/$index"
done
