#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec oma-snap-root test -e /.dockerenv
bash scripts/quattro-package-list.sh > build/quattro-selected-packages
# Upstream's ARM compositor stack must be selected as a group. The ordinary
# ARM repositories currently contain a different build/ABI combination.
sed -E 's@^(hyprland|hyprtoolkit|hyprland-guiutils)$@omarchy/\1@' \
  build/quattro-selected-packages > build/quattro-package-targets
docker exec -e OMARCHY_UPDATE_PACMAN=1 oma-snap-root bash -c '
  mapfile -t packages < /output/quattro-package-targets
  pacman -S --needed --noconfirm "${packages[@]}"
' > build/quattro-full-package-transaction.log 2>&1
