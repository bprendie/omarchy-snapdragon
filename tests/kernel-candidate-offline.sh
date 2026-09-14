#!/bin/bash
# Run inside the candidate builder with /candidate and /policy.json read-only.
set -euo pipefail
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp -a /candidate "$work/input"
input=$work/input
verify() { kernel-candidate --policy /policy.json --verify "$input"; }
reject() {
  if verify > "$work/error" 2>&1; then
    echo "FAIL: accepted $1" >&2
    exit 1
  fi
  grep -F "$2" "$work/error" >/dev/null || { cat "$work/error"; exit 1; }
  echo "PASS: rejected $1"
}
verify
sed -i 's/"kernel_release": "[^"]*"/"kernel_release": "0.0.0-0-generic"/' "$input/candidate.json"
reject 'edited candidate identity' 'candidate does not match authenticated dependency resolution'
cp /candidate/candidate.json "$input/candidate.json"
release=$(find "$input" -name InRelease -print -quit)
original=/candidate/${release#"$input/"}
sed -i 's/Origin: Ubuntu/Origin: NotUbuntu/' "$release"
reject 'tampered signed metadata' 'signature'
cp "$original" "$release"
index=$(find "$input" -name Packages.xz -print -quit)
original=/candidate/${index#"$input/"}
printf X | dd of="$index" bs=1 seek=16 count=1 conv=notrunc status=none
reject 'tampered package index' 'SHA256 mismatch'
cp "$original" "$index"
deb=$(find "$input/artifacts" -name '*.deb' -print -quit)
original=/candidate/artifacts/$(basename "$deb")
printf X | dd of="$deb" bs=1 seek=16 count=1 conv=notrunc status=none
reject 'tampered package payload' 'SHA256 mismatch'
cp "$original" "$deb"
rm "$deb"
ln -s "$original" "$deb"
reject 'symlink payload substitution' 'invalid file/size'
echo 'PASS: offline candidate authentication rejects altered inputs'
