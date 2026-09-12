#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(git -C sources/omarchy-arm rev-parse HEAD) == 579f15c699dab01e2b3b12e2c4d2503873359be9 ]] || { echo 'Omarchy base revision differs from pin' >&2; exit 1; }
for patch in patches/*.patch; do
  if git -C sources/omarchy-arm apply --reverse --check "$PWD/$patch" 2>/dev/null; then
    continue
  fi
  git -C sources/omarchy-arm apply --check "$PWD/$patch"
  git -C sources/omarchy-arm apply "$PWD/$patch"
done
