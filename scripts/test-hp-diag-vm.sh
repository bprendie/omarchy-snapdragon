#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ ! -e build/hp-diag-vm/usb.img ]]
sha256sum -c dist/oma-snap-hp-diag-arm64.iso.sha256
mkdir -p build/hp-diag-vm
cp --reflink=auto dist/oma-snap-hp-diag-arm64.iso build/hp-diag-vm/usb.img
sfdisk -d build/hp-diag-vm/usb.img > build/hp-diag-vm/partition-table.txt
# Only a writable copy of the diagnostic USB is attached, never a host device.
docker run --rm --network none --user "$(id -u):$(id -g)" --name oma-snap-hp-diag-test \
  -v "$PWD/build/hp-diag-vm:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive if=none,id=live,format=raw,file=/work/usb.img \
  -device usb-storage,drive=live,removable=on,bootindex=1 \
  -netdev user,id=net,restrict=on -device virtio-net-pci,netdev=net,romfile= \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -display none -monitor none -no-reboot
