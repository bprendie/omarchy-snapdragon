#!/bin/bash
# Inspect the built deployment package without importing keys into the host.
set -euo pipefail
cd "$(dirname "$0")/.."
dir=${1:?Usage: kernel-repository-package.sh BUILD_DIRECTORY FINGERPRINT SERVER MODE}
fingerprint=${2:?Missing expected fingerprint}
server=${3:?Missing expected mirror}
mode=${4:?Missing expected mode}
[[ $dir =~ ^build/[a-zA-Z0-9_-]+$ && $fingerprint =~ ^[A-F0-9]{40}$ ]]
sha256sum -c "$dir/packages.sha256"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
archive=$dir/oma-snap-repository-0.2.0-1-any.pkg.tar.xz
bsdtar --numeric-owner -tvf "$archive" > "$work/ownership"
awk '$3 != 0 || $4 != 0 {print; bad=1} END {exit bad}' "$work/ownership"
mkdir "$work/root" "$work/gnupg"
chmod 700 "$work/gnupg"
bsdtar -xf "$archive" -C "$work/root"
root=$work/root
grep -Fx 'backup = etc/pacman.d/oma-snap-mirrorlist' "$root/.PKGINFO"
cmp packages/kernel-repository/repository.install "$root/.INSTALL"
printf '%s:4:\n' "$fingerprint" | cmp - "$root/usr/share/pacman/keyrings/oma-snap-trusted"
[[ ! -s $root/usr/share/pacman/keyrings/oma-snap-revoked ]]
gpg --homedir "$work/gnupg" --batch --import "$root/usr/share/pacman/keyrings/oma-snap.gpg" > "$work/import.log" 2>&1
[[ $(gpg --homedir "$work/gnupg" --batch --with-colons --list-secret-keys 2>/dev/null | wc -l) == 0 ]]
actual=$(gpg --homedir "$work/gnupg" --batch --with-colons --list-keys 2>/dev/null |
  awk -F: '$1 == "pub" {primary=1; next} primary && $1 == "fpr" {print $10; primary=0}')
[[ $actual == "$fingerprint" ]]
jq -e --arg fingerprint "$fingerprint" --arg server "$server" --arg mode "$mode" \
  '.schema == 1 and .fingerprint == $fingerprint and .server == $server and .mode == $mode' \
  "$root/usr/share/oma-snap/repository.json"
printf '[options]\nArchitecture = auto\n[oma-snap]\nInclude = %s\n' \
  "$root/etc/pacman.d/oma-snap-mirrorlist" > "$work/pacman.conf"
[[ $(pacman-conf --config "$work/pacman.conf" --repo oma-snap Server) == "$server" ]]
echo 'PASS: repository package contains only pinned public trust and the expected preserved mirror configuration'
