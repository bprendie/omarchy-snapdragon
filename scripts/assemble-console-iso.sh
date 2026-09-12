#!/bin/bash
# Offline assembly. Input root export and initramfs must already be validated.
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/verify-kernel-update.sh
sha256sum -c manifests/bootstrap.sha256
[[ -s build/live-root.tar && -s build/initramfs.img ]] || { echo 'Missing root export or initramfs' >&2; exit 1; }
[[ ! -e dist/oma-snap-console-arm64.iso ]] || { echo 'ISO exists; move it aside before rebuilding' >&2; exit 1; }
mkdir -p build/iso/oma_snap/{boot,aarch64} build/iso/boot/grub
chmod -R u+w build/iso
install -m644 build/ubuntu-kernel-7.0.0-31/boot/vmlinuz-7.0.0-31-generic build/iso/oma_snap/boot/vmlinuz.efi
install -m644 build/initramfs.img build/iso/oma_snap/boot/initramfs.img
install -m644 profiles/t14s-lcd/grub.cfg build/iso/boot/grub/grub.cfg
cp -a --remove-destination build/ubuntu-grub/arm64-efi build/iso/boot/grub/
cp -a --remove-destination build/ubuntu-grub/fonts build/iso/boot/grub/
mkdir -p build/iso/EFI/BOOT
cp -a --remove-destination build/ubuntu-efi/boot/. build/iso/EFI/BOOT/
# Extract Ubuntu's EFI partition exactly as described by its El Torito table.
# Its hash is recorded after extraction; source ISO itself is pinned.
dd if=downloads/ubuntu-26.04.1-desktop-arm64.iso of=build/efi.img bs=2048 skip=2025472 count=3072 status=none
# Construct squashfs as root in an isolated container to retain ownership/modes.
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  test ! -e build/live-root-export || { echo "Export directory already exists" >&2; exit 1; }
  mkdir build/live-root-export
  tar --numeric-owner -xpf build/live-root.tar -C build/live-root-export
  test -d build/live-root-export/usr/lib/modules/7.0.0-31-generic
  test -d build/live-root-export/usr/lib/firmware/7.0.0-31-generic/qcom/x1e80100/LENOVO/21N1
  cmp build/live-root-export/usr/lib/oma-snap/7.0.0-31-generic/vmlinuz.efi build/ubuntu-kernel-7.0.0-31/boot/vmlinuz-7.0.0-31-generic
  rm -f build/live-root-export/.dockerenv build/live-root-export/.containerenv
  rm -f build/live-root-export/run/systemd/container build/live-root-export/run/host/container-manager
  printf "oma-snap\n" > build/live-root-export/etc/hostname
  printf "127.0.0.1 localhost\n::1 localhost\n" > build/live-root-export/etc/hosts
  rm -f build/live-root-export/etc/resolv.conf
  ln -s /run/NetworkManager/resolv.conf build/live-root-export/etc/resolv.conf
  rm -rf build/live-root-export/etc/pacman.d/gnupg/private-keys-v1.d
  rm -f build/iso/oma_snap/aarch64/airootfs.sfs
  mksquashfs build/live-root-export build/iso/oma_snap/aarch64/airootfs.sfs -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress -all-time 1789084800 -mkfs-time 1789084800
  chown 1000:1000 build/iso/oma_snap/aarch64/airootfs.sfs
'
(cd build/iso/oma_snap/aarch64 && sha512sum airootfs.sfs > airootfs.sha512)
# GRUB's embedded search uses /.disk/info; retain that discovery marker.
mkdir -p build/iso/.disk
printf 'oma_snap Arch Linux ARM console prototype\n' > build/iso/.disk/info
xorriso -as mkisofs -r -V OMA_SNAP -o dist/oma-snap-console-arm64.iso \
  -append_partition 2 0xef build/efi.img -appended_part_as_gpt \
  -e '--interval:appended_partition_2:all::' -no-emul-boot \
  -partition_cyl_align off build/iso
sha256sum dist/oma-snap-console-arm64.iso > dist/oma-snap-console-arm64.iso.sha256
xorriso -indev dist/oma-snap-console-arm64.iso -report_el_torito plain -report_system_area plain > build/iso-layout.log 2>&1
