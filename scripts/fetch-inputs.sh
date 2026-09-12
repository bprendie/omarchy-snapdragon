#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p downloads/repos sources
fetch() {
  local url=$1 file=$2
  [[ -s $file ]] || curl -fL --retry 3 --output "$file.part" "$url"
  [[ -s $file ]] || mv "$file.part" "$file"
}
base=https://cdimage.ubuntu.com/releases/26.04/release
fetch "$base/ubuntu-26.04.1-desktop-arm64.iso" downloads/ubuntu-26.04.1-desktop-arm64.iso
fetch "$base/SHA256SUMS" downloads/ubuntu-SHA256SUMS
fetch "$base/SHA256SUMS.gpg" downloads/ubuntu-SHA256SUMS.gpg
fetch 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x843938DF228D22F7B3742BC0D94AA3F0EFE21092' downloads/ubuntu-cdimage.asc
# Official aliases lack valid HTTPS certificates. Mandatory signatures verify payloads.
fetch http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz downloads/ArchLinuxARM-aarch64-latest.tar.gz
fetch http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz.sig downloads/ArchLinuxARM-aarch64-latest.tar.gz.sig
# Do not automatically refresh a previously selected repository snapshot.
for repo in core extra alarm; do
  fetch "http://mirror.archlinuxarm.org/aarch64/$repo/$repo.db" "downloads/repos/$repo.db"
done
while read -r url && read -r revision; do
  name=${url##*/}; name=${name%.git}
  [[ ! -d sources/$name ]] || continue
  git clone --no-checkout "$url" "sources/$name"
  git -C "sources/$name" checkout --detach "$revision"
done < manifests/source-revisions.txt
scripts/verify-inputs.sh
