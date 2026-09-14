#!/bin/bash
# Parse the proposed deployment profile without touching the host configuration.
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
printf 'Server = file:///fixture/signed-snapdragon\n' > "$work/oma-snap-mirrorlist"
printf 'Server = file:///fixture/alarm/$repo/os/$arch\n' > "$work/mirrorlist"
sed "s|/etc/pacman.d/|$work/|g" profiles/snapdragon/pacman-update.conf > "$work/pacman.conf"
query() { pacman-conf --config "$work/pacman.conf" "$@"; }
[[ $(query --repo-list) == $'oma-snap\ncore\nextra\nalarm\nomarchy' ]]
[[ $(query IgnorePkg) == $'hyprland\nhyprtoolkit\nhyprland-guiutils' ]]
[[ $(query --repo oma-snap Usage) == All ]]
[[ $(query --repo oma-snap SigLevel) == $'PackageRequired\nPackageTrustedOnly\nDatabaseRequired\nDatabaseTrustedOnly' ]]
[[ $(query --repo oma-snap Server) == file:///fixture/signed-snapdragon ]]
[[ $(query --repo omarchy Usage) == $'Sync\nSearch\nInstall' ]]
# A deployment must supply the mirrorlist. Its absence must not silently fall
# back to an upstream provider or report a configured Snapdragon repository.
rm "$work/oma-snap-mirrorlist"
if query --repo-list > "$work/missing.out" 2>&1; then
  echo 'Missing deployment mirrorlist unexpectedly accepted' >&2
  exit 1
fi
echo 'PASS: update profile prioritizes signed Snapdragon packages and preserves desktop holds'
