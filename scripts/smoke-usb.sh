#!/bin/bash
# Validate the ISO as virtual USB mass storage, without any physical disks.
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c dist/oma-snap-console-arm64.iso.sha256
docker run --rm -i --network none --name oma-snap-usb-test \
  -v "$PWD/dist:/images:ro" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -device virtio-rng-pci \
  -device qemu-xhci -drive if=none,id=stick,format=raw,readonly=on,file=/images/oma-snap-console-arm64.iso \
  -device usb-storage,drive=stick,removable=on,bootindex=1 -nic none -nographic -no-reboot
