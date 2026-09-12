#!/bin/bash
# ARM UEFI virtual hardware only. No host devices, no network, no disk installation.
set -euo pipefail
cd "$(dirname "$0")/.."
sha256sum -c dist/oma-snap-console-arm64.iso.sha256
docker run --rm -i --network none --name oma-snap-uefi-test \
  -v "$PWD/dist:/images:ro" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci \
  -device virtio-scsi-pci \
  -drive if=none,id=cdrom,format=raw,readonly=on,file=/images/oma-snap-console-arm64.iso \
  -device scsi-cd,drive=cdrom -nic none -nographic -no-reboot
