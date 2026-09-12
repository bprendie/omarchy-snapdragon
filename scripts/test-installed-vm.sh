#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Run after the installer VM exits. QEMU's disk lock rejects concurrent use.
vm_dir="${OMA_SNAP_VM_DIR:-build/install-vm}"
ssh_port="${OMA_SNAP_SSH_PORT:-2323}"
[[ $vm_dir =~ ^build/[a-zA-Z0-9_-]+$ ]] || { echo 'VM directory must be a direct child of build/' >&2; exit 1; }
[[ $ssh_port =~ ^[0-9]+$ ]] && (( ssh_port > 1024 && ssh_port < 65536 )) || { echo 'Invalid SSH port' >&2; exit 1; }
test -s "$vm_dir/target.img"
docker run --rm -i --network host --user "$(id -u):$(id -g)" --name oma-snap-installed-test \
  -v "$PWD/build:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive "if=none,id=target,format=raw,file=/work/${vm_dir#build/}/target.img" \
  -device virtio-blk-pci,drive=target,bootindex=1 \
  -netdev "user,id=net,restrict=on,hostfwd=tcp:127.0.0.1:$ssh_port-:22" \
  -device virtio-net-pci,netdev=net,romfile= \
  -qmp "unix:/work/${vm_dir#build/}/installed.sock,server=on,wait=off" \
  -chardev socket,id=serial,path=/work/${vm_dir#build/}/installed-serial.sock,server=on,wait=off,logfile=/work/${vm_dir#build/}/installed-serial.log \
  -display none -serial chardev:serial -monitor none
