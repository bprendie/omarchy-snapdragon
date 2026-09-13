#!/bin/bash
# Boot the complete release ISO in generic ARM UEFI; no physical hardware emulation.
set -euo pipefail
cd "$(dirname "$0")/.."
version=${1:-0.1.2}
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
iso=omarchy-snapdragon-v${version}.iso
vm_dir=build/snapdragon-v${version//./_}-vm
[[ ! -e $vm_dir/serial.log ]] || { echo 'Preserve the existing VM evidence first.' >&2; exit 1; }
sha256sum -c "$iso.sha256"
mkdir -p "$vm_dir"
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --name "oma-snap-v${version//./-}-smoke" \
  -v "$PWD/$iso:/image.iso:ro" -v "$PWD/$vm_dir:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive if=none,id=live,format=raw,readonly=on,file=/image.iso \
  -device usb-storage,drive=live,removable=on,bootindex=1 \
  -nic none -display none -monitor none -no-reboot \
  -qmp unix:/work/qmp.sock,server=on,wait=off \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial
