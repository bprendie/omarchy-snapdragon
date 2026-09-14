#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/fetch-quattro.sh
revision=0534987009061cbe2dacdde4ad564092ab698d12
directory=sources/omarchy-snap
if [[ ! -d $directory ]]; then
  git -C sources/omarchy-quattro worktree add --detach ../omarchy-snap "$revision"
fi
[[ $(git -C "$directory" rev-parse HEAD) == "$revision" ]]
for patch_file in "$PWD/patches/0002-quattro-arm-profile.patch" "$PWD/patches/0004-quattro-retained-kernel-orphans.patch" "$PWD/patches/0005-quattro-kernel-preparation-wait.patch" "$PWD/patches/0006-quattro-kernel-reboot-identity.patch" "$PWD/patches/0007-quattro-refresh-kernel-wait.patch"; do
  if git -C "$directory" apply --check "$patch_file" 2>/dev/null; then
    git -C "$directory" apply "$patch_file"
  else
    git -C "$directory" apply --reverse --check "$patch_file"
  fi
done
bash scripts/quattro-package-list.sh | cmp - "$directory/install/omarchy-base.packages"
git -C "$directory" diff --check

iso_directory=sources/omarchy-iso-snap
iso_revision=a23f8d464dcb0616a61bfaa8026e23d0533da209
if [[ ! -d $iso_directory ]]; then
  git -C sources/omarchy-iso worktree add --detach ../omarchy-iso-snap "$iso_revision"
fi
[[ $(git -C "$iso_directory" rev-parse HEAD) == "$iso_revision" ]]
iso_patch="$PWD/patches/0003-quattro-arm-installer.patch"
if git -C "$iso_directory" apply --check "$iso_patch" 2>/dev/null; then
  git -C "$iso_directory" apply "$iso_patch"
else
  git -C "$iso_directory" apply --reverse --check "$iso_patch"
fi
git -C "$iso_directory" diff --check
