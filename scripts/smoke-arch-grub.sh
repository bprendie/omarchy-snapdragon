#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c dist/oma-snap-console-arm64.iso.sha256
cat > build/grub-arm64-test.cfg <<'EOF'
search --no-floppy --label OMA_SNAP --set=root
set timeout=0
menuentry 'Arch GRUB with Ubuntu Stubble kernel' {
  linux /oma_snap/boot/vmlinuz.efi archisobasedir=oma_snap archisolabel=OMA_SNAP arch=aarch64 cow_spacesize=1G console=tty0 console=ttyAMA0,115200
  initrd /oma_snap/boot/initramfs.img
}
EOF
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o /output/grub-arm64-test.efi 'boot/grub/grub.cfg=/output/grub-arm64-test.cfg'
docker run --rm -v "$PWD/build:/work" oma-snap-builder:local bash -ec '
  truncate -s 32M /work/grub-arm64-test.img
  mformat -i /work/grub-arm64-test.img ::
  mmd -i /work/grub-arm64-test.img ::/EFI ::/EFI/BOOT
  mcopy -i /work/grub-arm64-test.img /work/grub-arm64-test.efi ::/EFI/BOOT/BOOTAA64.EFI
'
docker run --rm -i --network none --name oma-snap-grub-test \
  -v "$PWD/dist:/images:ro" -v "$PWD/build:/work:ro" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -device virtio-rng-pci \
  -device qemu-xhci \
  -drive if=none,id=loader,format=raw,readonly=on,file=/work/grub-arm64-test.img \
  -device usb-storage,drive=loader,removable=on,bootindex=1 \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/oma-snap-console-arm64.iso \
  -device usb-storage,drive=live,removable=on,bootindex=2 \
  -nic none -nographic -no-reboot
