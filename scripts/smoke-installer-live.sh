#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
iso=${OMA_SNAP_TEST_ISO:-dist/oma-snap-installer-kernel31-arm64.iso}
vm_dir=${OMA_SNAP_VM_DIR:-build/installer-live-kernel31}
ssh_port=${OMA_SNAP_SSH_PORT:-2326}
[[ $iso =~ ^(dist/[A-Za-z0-9._-]+|omarchy-snapdragon-v[0-9.]+)[.]iso$ ]] || { echo 'ISO must be in dist/ or a versioned Snapdragon ISO at repo root' >&2; exit 1; }
[[ $vm_dir =~ ^build/[a-zA-Z0-9_-]+$ ]] || { echo 'VM directory must be a direct child of build/' >&2; exit 1; }
[[ $ssh_port =~ ^[0-9]+$ ]] && (( ssh_port > 1024 && ssh_port < 65536 )) || { echo 'Invalid SSH port' >&2; exit 1; }
[[ ! -e $vm_dir/serial.log ]] || { echo 'Preserve the previous live test first' >&2; exit 1; }
sha256sum -c "$iso.sha256"
mkdir -p "$vm_dir"
# No installation target or cidata: this only boots the live environment.
docker run --rm --network host --user "$(id -u):$(id -g)" --name oma-snap-live-test \
  -v "$PWD/$iso:/images/live.iso:ro" -v "$PWD/$vm_dir:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/live.iso \
  -device usb-storage,drive=live,removable=on,bootindex=1 \
  -netdev user,id=net,restrict=on,hostfwd=tcp:127.0.0.1:${ssh_port}-:22 \
  -device virtio-net-pci,netdev=net,romfile= \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -display none -monitor none -no-reboot
