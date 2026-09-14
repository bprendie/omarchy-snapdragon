#!/bin/bash
# Synthetic packages/evidence only: exercise the real gate and signing commands.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 2 ]]
key_home=$1 key=$2
work=$(mktemp -d)
name=kernel-promotion-synthetic-$(date +%s)-$$
trap 'rm -rf "$work"' EXIT
id=$(printf 'a%.0s' {1..64})
mkdir -p "$work/hardware/usr/lib/oma-snap/sets/$id"
printf 'pkgname = oma-snap-set-%s\npkgver = 0.2.0-1\narch = aarch64\n' "$id" > "$work/hardware/.PKGINFO"
jq -n --arg id "$id" '{id:$id,kernel_release:"7.0.0-31-generic"}' > "$work/hardware/usr/lib/oma-snap/sets/$id/set.json"
bsdtar -cJf "$work/hardware.pkg.tar.xz" -C "$work/hardware" .PKGINFO usr
: > "$work/evidence.jsonl"
for kind in source-verification package-reproducibility camera-build vm-rollback vm-encrypted-boot; do
  printf 'SYNTHETIC FIXTURE ONLY: %s\n' "$kind" > "$work/$kind.log"
  hash=$(sha256sum "$work/$kind.log" | cut -d' ' -f1)
  jq -cn --arg kind "$kind" --arg path "$kind.log" --arg hash "$hash" '{kind:$kind,path:$path,sha256:$hash}' >> "$work/evidence.jsonl"
done
hash=$(sha256sum "$work/hardware.pkg.tar.xz" | cut -d' ' -f1)
jq -sn --arg id "$id" --arg hash "$hash" --slurpfile evidence "$work/evidence.jsonl" \
  '{schema:1,status:"approved",channel:"testing",sequence:1,reviewer:"SYNTHETIC TEST ONLY",hardware_set:$id,
    kernel_release:"7.0.0-31-generic",package_sha256:$hash,
    hardware_validation:{t14s:"untested","hp-g1q":"untested","asus-ux3407ra":"untested"},evidence:$evidence}' > "$work/approval.json"
(cd tools/kernel-promotion && go build -trimpath -o ../../build/kernel-promotion .)
build/kernel-promotion --approval "$work/approval.json" --package "$work/hardware.pkg.tar.xz" --output "$work/generated"
mkdir -p "$work/provider/usr/share/oma-snap/kernel-provider"
cp "$work/generated/candidate.json" "$work/provider/usr/share/oma-snap/kernel-provider/candidate.json"
printf 'pkgname = oma-snap-kernel\npkgver = 1:1-1\narch = aarch64\n' > "$work/provider/.PKGINFO"
bsdtar -cJf "$work/provider.pkg.tar.xz" -C "$work/provider" .PKGINFO usr
for spec in oma-snap-kernel-tools:0.2.0-10 omarchy:4.0.3-1.9 omarchy-settings:4.0.3-1.9 oma-snap-repository:0.2.0-1; do
  package=${spec%%:*} version=${spec#*:}
  mkdir "$work/$package"
  printf 'pkgname = %s\npkgver = %s\narch = aarch64\n' "$package" "$version" > "$work/$package/.PKGINFO"
  if [[ $package == oma-snap-repository ]]; then
    mkdir -p "$work/$package/usr/share/oma-snap"
    jq -n --arg key "$key" '{schema:1,fingerprint:$key,mode:"--local-test",server:"file:///synthetic"}' > "$work/$package/usr/share/oma-snap/repository.json"
    bsdtar -cJf "$work/$package.pkg.tar.xz" -C "$work/$package" .PKGINFO usr
  else
    bsdtar -cJf "$work/$package.pkg.tar.xz" -C "$work/$package" .PKGINFO
  fi
done
args=("$key_home" "$key" "$work/approval.json" "$work/hardware.pkg.tar.xz" "$work/provider.pkg.tar.xz" 0
  "$work/oma-snap-kernel-tools.pkg.tar.xz" "$work/omarchy.pkg.tar.xz" "$work/omarchy-settings.pkg.tar.xz" "$work/oma-snap-repository.pkg.tar.xz")
bash scripts/build-promoted-kernel-repo.sh "$name" "${args[@]}"
(cd "build/$name" && sha256sum -c SHA256SUMS)
[[ -L build/$name/oma-snap.db && -s build/$name/oma-snap.db.sig ]]
printf 'changed evidence\n' >> "$work/vm-rollback.log"
if bash scripts/build-promoted-kernel-repo.sh "$name-rejected" "${args[@]}"; then
  echo 'Changed evidence was accepted' >&2; exit 1
fi
[[ ! -e build/$name-rejected ]]
printf 'SYNTHETIC PACKAGES ONLY; NEVER INSTALL OR PUBLISH.\n' > "build/$name/SYNTHETIC-TEST-ONLY.txt"
echo "PASS: signed synthetic repository and rejection before signing; evidence: build/$name"
