#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/verify-gnupg
chmod 700 build/verify-gnupg
gpg --homedir build/verify-gnupg --import downloads/ubuntu-cdimage.asc sources/archlinuxarm-keyring/archlinuxarm.gpg
verify() {
  local signature=$1 artifact=$2 fingerprint=$3
  gpg --homedir build/verify-gnupg --status-fd 1 --verify "$signature" "$artifact" > build/signature-status.txt
  rg -q "^\[GNUPG:\] VALIDSIG $fingerprint " build/signature-status.txt
}
verify downloads/ubuntu-SHA256SUMS.gpg downloads/ubuntu-SHA256SUMS 843938DF228D22F7B3742BC0D94AA3F0EFE21092
verify downloads/ArchLinuxARM-aarch64-latest.tar.gz.sig downloads/ArchLinuxARM-aarch64-latest.tar.gz 68B3537F39A313B3E574D06777193F152BDBE6A6
sha256sum -c manifests/bootstrap.sha256
