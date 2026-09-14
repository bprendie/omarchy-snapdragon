#!/bin/bash
# Network-disabled ARM container. /repo is signed, /unsigned has a signed DB
# but no package signature, and /work stores evidence. No host keyring changes.
set -euo pipefail
key=${1:?Missing independently supplied expected fingerprint}
mode=${2:-all}
[[ $mode == all || $mode == negative-only ]]
[[ $key =~ ^[A-F0-9]{40}$ ]]
mkdir -p /work/gnupg /work/db/local /work/cache
chmod 700 /work/gnupg
gpg --homedir /work/gnupg --batch --with-colons --show-keys /repo/repository-key.gpg > /work/key-details.txt
actual=$(awk -F: '$1 == "fpr" {print $10;exit}' /work/key-details.txt)
[[ $actual == "$key" ]]
if [[ $mode == all ]]; then
  pacman-key --gpgdir /work/gnupg --init
  pacman-key --gpgdir /work/gnupg --add /repo/repository-key.gpg
  pacman-key --gpgdir /work/gnupg --lsign-key "$key"
fi
config() {
  local output=$1 server=$2 db=$3 cache=$4
  mkdir -p "$db/local" "$cache"
  cat > "$output" <<EOF
[options]
Architecture = aarch64
DBPath = $db
CacheDir = $cache
GPGDir = /work/gnupg
SigLevel = PackageRequired DatabaseRequired TrustedOnly
[oma-snap-test]
Server = file://$server
EOF
}
if [[ $mode == all ]]; then
config /work/good.conf /repo /work/db /work/cache
pacman --config /work/good.conf -Syy --noconfirm
mapfile -t packages < <(pacman --config /work/good.conf -Slq oma-snap-test)
[[ ${#packages[@]} == 2 ]]
pacman --config /work/good.conf -Sddw --noconfirm "${packages[@]}"
for archive in /repo/*.pkg.tar.xz; do cmp "$archive" "/work/cache/${archive##*/}"; done
echo 'PASS: ARM pacman accepts required database/package signatures and exact payload bytes'
mkdir /work/bad-db
cp -a /repo/oma-snap-test.db* /work/bad-db/
printf tampered >> /work/bad-db/oma-snap-test.db.tar.gz
config /work/bad-db.conf /work/bad-db /work/bad-db-state /work/bad-db-cache
if pacman --config /work/bad-db.conf -Syy --noconfirm > /work/bad-db.log 2>&1; then
  echo 'FAIL: altered database accepted' >&2; exit 1
fi
cat /work/bad-db.log
grep -qi 'signature' /work/bad-db.log
echo 'PASS: ARM pacman rejects an altered signed database'
fi
mkdir /work/bad-package-same-size
cp -a /repo/oma-snap-test.db* /work/bad-package-same-size/
cp /repo/oma-snap-kernel-tools-*.pkg.tar.xz* /work/bad-package-same-size/
printf '\0' | dd of=/work/bad-package-same-size/oma-snap-kernel-tools-0.2.0-1-aarch64.pkg.tar.xz bs=1 seek=1 count=1 conv=notrunc status=none
config /work/same-size.conf /work/bad-package-same-size /work/same-size-state /work/same-size-cache
pacman --config /work/same-size.conf -Syy --noconfirm
if pacman --config /work/same-size.conf -Sddw --noconfirm oma-snap-kernel-tools > /work/same-size.log 2>&1; then
  echo 'FAIL: altered package accepted' >&2; exit 1
fi
cat /work/same-size.log
grep -Eqi 'invalid|corrupt' /work/same-size.log
echo 'PASS: ARM pacman rejects altered package bytes under a valid signed database'
config /work/unsigned.conf /unsigned /work/unsigned-state /work/unsigned-cache
pacman --config /work/unsigned.conf -Syy --noconfirm
if pacman --config /work/unsigned.conf -Sddw --noconfirm oma-snap-kernel-tools > /work/unsigned.log 2>&1; then
  echo 'FAIL: unsigned package accepted under valid signed database' >&2; exit 1
fi
cat /work/unsigned.log
grep -Eqi 'signature|\.pkg\.tar\.xz\.sig' /work/unsigned.log
echo 'PASS: ARM pacman requires package signatures independently of database signing'
