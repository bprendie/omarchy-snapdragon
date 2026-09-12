#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iso_output=${OMA_SNAP_ISO_OUTPUT:-dist/oma-snap-installer-arm64.iso}
[[ $iso_output =~ ^dist/[A-Za-z0-9._-]+[.]iso$ ]] || { echo 'ISO output must be an .iso file directly in dist/' >&2; exit 1; }
[[ ! -e build/installer-root-export && ! -e build/installer-iso && ! -e $iso_output ]] || { echo 'Preserve previous ISO staging, extracted root and output before assembly' >&2; exit 1; }
bash scripts/verify-offline-mirror.sh
bash scripts/verify-kernel-update.sh
sha256sum -c manifests/installer-root-export.sha256 manifests/bootstrap.sha256
test -s build/initramfs.img
mkdir -p build/installer-iso/oma_snap/{boot,aarch64} build/installer-iso/boot/grub build/installer-iso/EFI/BOOT
install -m644 build/ubuntu-kernel-7.0.0-31/boot/vmlinuz-7.0.0-31-generic build/installer-iso/oma_snap/boot/vmlinuz.efi
install -m644 build/initramfs.img build/installer-iso/oma_snap/boot/initramfs.img
sed 's/Arch ARM console prototype (RAM overlay)/Quattro ARM installer development candidate/' \
  profiles/t14s-lcd/grub.cfg > build/installer-iso/boot/grub/grub.cfg
cp -a build/ubuntu-grub/{arm64-efi,fonts} build/installer-iso/boot/grub/
cp -a build/ubuntu-efi/boot/. build/installer-iso/EFI/BOOT/
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  mkdir build/installer-root-export
  tar --numeric-owner -xpf build/installer-root.tar -C build/installer-root-export
  root=build/installer-root-export
  for list in omarchy-base.packages omarchy-other.packages; do
    test -s "$root/usr/share/omarchy-iso/$list"
    cmp "$root/usr/share/omarchy/install/$list" "$root/usr/share/omarchy-iso/$list"
  done
  test -d "$root/usr/lib/modules/7.0.0-31-generic"
  test -d "$root/usr/lib/firmware/7.0.0-31-generic/qcom/x1e80100/LENOVO/21N1"
  cmp "$root/usr/lib/oma-snap/7.0.0-31-generic/vmlinuz.efi" build/ubuntu-kernel-7.0.0-31/boot/vmlinuz-7.0.0-31-generic
  rm -f "$root/.dockerenv" "$root/.containerenv" "$root/run/systemd/container" "$root/run/host/container-manager"
  rm -rf "$root/etc/pacman.d/gnupg/private-keys-v1.d" "$root/var/cache/pacman/pkg" "$root/opt/oma-snap-node"
  mkdir -p "$root/var/cache/pacman/pkg" "$root/var/cache/omarchy/mirror/offline"
  cp -a build/offline-mirror/. "$root/var/cache/omarchy/mirror/offline/"
  cp profiles/t14s-lcd/pacman-offline.conf "$root/etc/pacman.conf"
  printf "oma-snap-installer\n" > "$root/etc/hostname"
  printf "127.0.0.1 localhost\n::1 localhost\n" > "$root/etc/hosts"
  rm -f "$root/etc/resolv.conf"
  ln -s /run/NetworkManager/resolv.conf "$root/etc/resolv.conf"
  wc -l < build/offline-dependency-closure.txt > "$root/usr/share/omarchy-iso/expected-packages"
  mksquashfs "$root" build/installer-iso/oma_snap/aarch64/airootfs.sfs -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress -all-time 1789084800 -mkfs-time 1789084800
  chown 1000:1000 build/installer-iso/oma_snap/aarch64/airootfs.sfs
'
(cd build/installer-iso/oma_snap/aarch64 && sha512sum airootfs.sfs > airootfs.sha512)
mkdir -p build/installer-iso/.disk
printf 'oma_snap Quattro ARM installer development candidate\n' > build/installer-iso/.disk/info
OMA_SNAP_ISO_OUTPUT="$iso_output" bash scripts/write-installer-iso.sh
