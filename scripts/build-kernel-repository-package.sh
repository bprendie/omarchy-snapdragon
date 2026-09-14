#!/bin/bash
# Package an explicitly pinned public trust anchor. This does not promote a kernel.
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:?Usage: build-kernel-repository-package.sh NEW_NAME PUBLIC_KEY FINGERPRINT SERVER [--local-test]}
public_key=${2:?Missing public key}
fingerprint=${3:?Missing expected primary fingerprint}
server=${4:?Missing repository Server URL}
mode=${5:-release}
[[ $# == 4 || ( $# == 5 && $mode == --local-test ) ]]
[[ $name =~ ^[a-zA-Z0-9_-]+$ && ! -e build/$name ]]
[[ $fingerprint =~ ^[A-F0-9]{40}$ && -f $public_key && ! -L $public_key ]]
# Disallow configuration injection, shell expansion and credentials in mirrors.
[[ $server =~ ^https://[a-zA-Z0-9.-]+(:[0-9]+)?/[a-zA-Z0-9/_.-]+$ ||
   ( $mode == --local-test && $server =~ ^file:///[a-zA-Z0-9/_.-]+$ ) ]]
[[ $(docker exec oma-snap-root uname -m) == aarch64 ]]
docker exec oma-snap-root test -e /.dockerenv
mkdir "build/$name"
work=$PWD/build/$name
key_work=$(mktemp -d)
trap 'rm -rf "$key_work"' EXIT
chmod 700 "$key_work"
gpg --homedir "$key_work" --batch --import "$public_key" > "$work/key-import.log" 2>&1
# Export only public material for the exact requested primary, even if the input
# bundle contains additional public keys or private material.
actual=$(gpg --homedir "$key_work" --batch --with-colons --list-keys "$fingerprint" 2>/dev/null |
  awk -F: '$1 == "pub" {primary=1; next} primary && $1 == "fpr" {print $10; primary=0}')
[[ $actual == "$fingerprint" ]]
# The pinned primary is the signer used by the repository builder. Do not ship
# an expired, revoked, disabled or non-signing primary as a new trust anchor.
gpg --homedir "$key_work" --batch --with-colons --list-keys "$fingerprint" 2>/dev/null |
  awk -F: -v now="$(date +%s)" '$1 == "pub" {
    found++
    if ($2 ~ /^[redi]$/ || $6 > now || ($7 != "" && $7 <= now) || $12 !~ /s/) bad=1
  } END {exit (found != 1 || bad)}'
gpg --homedir "$key_work" --batch --export "$fingerprint" > "$work/oma-snap.gpg"
test -s "$work/oma-snap.gpg"
printf '%s:4:\n' "$fingerprint" > "$work/oma-snap-trusted"
: > "$work/oma-snap-revoked"
printf '# Managed by oma-snap-repository; local changes are preserved by pacman.\nServer = %s\n' "$server" > "$work/oma-snap-mirrorlist"
jq -n --arg fingerprint "$fingerprint" --arg server "$server" --arg mode "$mode" \
  '{schema:1, fingerprint:$fingerprint, server:$server, mode:$mode}' > "$work/repository.json"
cp packages/kernel-repository/{PKGBUILD,repository.install} "$work/"
docker exec oma-snap-root chown -R alarm:alarm "/output/$name"
docker exec --user alarm -e SOURCE_DATE_EPOCH=1785542400 -e LC_ALL=C -e TZ=UTC \
  oma-snap-root bash -ec '
    stage=/tmp/oma-snap-repository-build
    mkdir "$stage"
    cleanup() { rm -rf "$stage"; }
    trap cleanup EXIT
    cp "/output/$1/"{PKGBUILD,repository.install,oma-snap.gpg,oma-snap-trusted,oma-snap-revoked,oma-snap-mirrorlist,repository.json} "$stage/"
    cd "$stage"
    makepkg --nodeps --noconfirm
    cp ./*.pkg.tar.* "/output/$1/"
  ' bash "$name" \
  > "$work/build.log" 2>&1
sha256sum "$work/"*.pkg.tar.* > "$work/packages.sha256"
echo "Built repository configuration package: $work"
