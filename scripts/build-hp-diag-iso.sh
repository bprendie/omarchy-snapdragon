#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iso=dist/oma-snap-hp-diag-arm64.iso
[[ ! -e $iso && ! -e build/hp-diag-root && ! -e build/hp-diag-iso ]]
test -d build/installer-root-export
test -s build/initramfs.img
mkdir -p build/hp-diag-build
(cd tools/hp-diag && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -o ../../build/hp-diag-build/oma-snap-hp-diag .)
docker run --rm --network none -v "$PWD:/work" -w /work oma-snap-builder:local bash -ec '
  cp -a --reflink=auto build/installer-root-export build/hp-diag-root
  root=build/hp-diag-root
  rm -rf "$root/var/cache/omarchy/mirror" "$root/var/cache/pacman/pkg"
  rm -f "$root/root/.automated_script.sh"
  install -Dm755 build/hp-diag-build/oma-snap-hp-diag "$root/usr/local/bin/oma-snap-hp-diag"
  install -Dm644 profiles/hp-elitebook-ultra-g1q/oma-snap-diag.service "$root/etc/systemd/system/oma-snap-diag.service"
  mkdir -p "$root/etc/systemd/system/multi-user.target.wants"
  ln -s ../oma-snap-diag.service "$root/etc/systemd/system/multi-user.target.wants/oma-snap-diag.service"
  for unit in sddm.service pacman-init.service udisks2.service; do
    rm -f "$root/etc/systemd/system/$unit"
    ln -s /dev/null "$root/etc/systemd/system/$unit"
  done
  printf "HP diagnostic live boot. No installation will start.\nLogs save to OMADIAG on this USB; successful capture powers off automatically.\n" > "$root/etc/issue"
  printf "cat /etc/issue\n" > "$root/root/.bash_profile"
  mkdir -p build/hp-diag-iso/oma_snap/{boot,aarch64} build/hp-diag-iso/boot/grub build/hp-diag-iso/EFI/BOOT
  cp -a build/installer-iso/oma_snap/boot/. build/hp-diag-iso/oma_snap/boot/
  cp -a build/ubuntu-grub/{arm64-efi,fonts} build/hp-diag-iso/boot/grub/
  cp -a build/ubuntu-efi/boot/. build/hp-diag-iso/EFI/BOOT/
  cp profiles/hp-elitebook-ultra-g1q/grub-diag.cfg build/hp-diag-iso/boot/grub/grub.cfg
  mksquashfs "$root" build/hp-diag-iso/oma_snap/aarch64/airootfs.sfs -noappend -comp zstd -Xcompression-level 3 -processors 4 -no-progress
  truncate -s 512M build/hp-diag-logs.img
  mkfs.vfat -F32 -n OMADIAG build/hp-diag-logs.img
  printf "oma-snap-hp-diagnostic-v1\n" > build/hp-diag-build/DIAG-VOLUME.txt
  printf "Boot this USB on the HP and wait for automatic poweroff (usually 2-4 minutes).\nReturn the USB to the Dragonfly. Logs appear in hp-diag-* folders here.\nCOMPLETE.txt inside the folder means all snapshots were saved.\nIf it has not powered off after 6 minutes, shut down before unplugging and try the fallback GRUB entry.\n" > build/hp-diag-build/README.txt
  mcopy -i build/hp-diag-logs.img build/hp-diag-build/{DIAG-VOLUME,README}.txt ::/
  chown -R 1000:1000 build/hp-diag-iso build/hp-diag-build build/hp-diag-logs.img
'
(cd build/hp-diag-iso/oma_snap/aarch64 && sha512sum airootfs.sfs > airootfs.sha512)
mkdir -p build/hp-diag-iso/.disk
printf 'oma_snap HP diagnostic live image\n' > build/hp-diag-iso/.disk/info
xorriso -as mkisofs -iso-level 3 -r -V OMA_SNAP -o "$iso" \
  -append_partition 2 0xef build/efi.img -append_partition 3 0x0c build/hp-diag-logs.img \
  -appended_part_as_gpt -e '--interval:appended_partition_2:all::' -no-emul-boot \
  -partition_cyl_align off build/hp-diag-iso
sha256sum "$iso" > "$iso.sha256"
