#!/bin/bash
# Reuse v0.2.2's boot assets and hardware; replace only the root and menu label.
set -euo pipefail
cd "$(dirname "$0")/.."
[[ $# == 1 && $1 =~ ^[a-zA-Z0-9_-]+$ ]] || { echo 'Usage: assemble-v0221-hotfix.sh SIGNED_REPOSITORY_BUILD_NAME' >&2; exit 1; }
repository=$1
stage=build/snapdragon-v0221
iso=omarchy-snapdragon-v0.2.2-1.iso
[[ -d $stage/root && -f $stage/grub.cfg && ! -e $iso ]]
key=6B516CB2E4C718688CB66A111E22DE33B6C29CF5
[[ $(cat "build/$repository/repository-key.fingerprint") == "$key" ]]
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
gpg --homedir "$scratch" --batch --import "build/$repository/repository-key.gpg"
gpg --homedir "$scratch" --batch --export "$key" > "$scratch/pinned.gpg"
gpgv --keyring "$scratch/pinned.gpg" "build/$repository/SHA256SUMS.sig" "build/$repository/SHA256SUMS"
(cd "build/$repository" && sha256sum -c SHA256SUMS)
cmp build/kernel-repo-v022-a16-testing/approval.json "build/$repository/approval.json"
tar -xOf "build/$repository/oma-snap-kernel-tools-0.2.2-2-aarch64.pkg.tar.xz" \
  usr/lib/sysctl.d/60-oma-snap-userns.conf | cmp - packages/kernel-tools/60-oma-snap-userns.conf
sed 's/v0\.2\.2 -/v0.2.2-1 -/' "$stage/grub.cfg" > "$stage/grub-hotfix.cfg"
docker run --rm --network none -v "$PWD:/repo:ro" -v "$PWD/build:/work" oma-snap-builder:local bash -ec '
  root=/work/snapdragon-v0221/root
  # The unchanged baseline live root does not have kernel-tools installed.
  test ! -d "$root/var/lib/pacman/local/oma-snap-kernel-tools-0.2.2-1"
  install -Dm644 /repo/packages/kernel-tools/60-oma-snap-userns.conf "$root/usr/lib/sysctl.d/60-oma-snap-userns.conf"
  rm -rf "$root/var/cache/oma-snap/repository"
  cp -a "/work/$1" "$root/var/cache/oma-snap/repository"
  chown -R 0:0 "$root/var/cache/oma-snap/repository"
  bash /repo/scripts/verify-userns-image.sh /work/snapdragon-v0221/root
  mksquashfs "$root" /work/snapdragon-v0221/airootfs.sfs -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress
  chown 1000:1000 /work/snapdragon-v0221/airootfs.sfs
' bash "$repository"
(cd "$stage" && sha512sum airootfs.sfs > airootfs.sha512)
# Replay preserves the existing EFI and diagnostic appended partitions.
xorriso -indev omarchy-snapdragon-v0.2.2.iso -outdev "$iso" \
  -boot_image any replay \
  -map "$stage/airootfs.sfs" /oma_snap/aarch64/airootfs.sfs \
  -map "$stage/airootfs.sha512" /oma_snap/aarch64/airootfs.sha512 \
  -map "$stage/grub-hotfix.cfg" /boot/grub/grub.cfg \
  -commit -end
sha256sum "$iso" > "$iso.sha256"
echo "Built $iso with live and installed user-namespace compatibility fix"
