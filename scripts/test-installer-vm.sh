#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
vm_dir=${OMA_SNAP_VM_DIR:-build/install-vm}
ssh_port=${OMA_SNAP_SSH_PORT:-2323}
vm_name=${OMA_SNAP_VM_NAME:-oma-snap-install-test}
[[ $vm_name =~ ^oma-snap-[a-zA-Z0-9_-]+$ ]] || exit 1
iso=${OMA_SNAP_TEST_ISO:-dist/oma-snap-installer-arm64.iso}
[[ $iso =~ ^dist/[A-Za-z0-9._-]+[.]iso$ ]] || { echo 'Test ISO must be directly in dist/' >&2; exit 1; }
[[ $vm_dir =~ ^build/[a-zA-Z0-9_-]+$ ]] || { echo 'VM directory must be a direct child of build/' >&2; exit 1; }
[[ $ssh_port =~ ^[0-9]+$ ]] && (( ssh_port > 1024 && ssh_port < 65536 )) || { echo 'Invalid SSH port' >&2; exit 1; }
[[ ! -e $vm_dir/target.img ]] || { echo 'VM target already exists; preserve it before starting a new install' >&2; exit 1; }
sha256sum -c "$iso.sha256"
OMA_SNAP_TEST_ISO="$iso" OMA_SNAP_VM_DIR="$vm_dir" bash scripts/make-install-fixture.sh
sha256sum "$iso" > "$vm_dir/iso.sha256"
truncate -s 40G "$vm_dir/target.img"
docker run --rm -i --network host --user "$(id -u):$(id -g)" --name "$vm_name" \
  -v "$PWD/dist:/images:ro" -v "$PWD/build:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci \
  -device usb-kbd -device usb-tablet \
  -drive if=none,id=target,format=raw,file=/work/${vm_dir#build/}/target.img \
  -device virtio-blk-pci,drive=target,bootindex=1 \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/${iso#dist/} \
  -device usb-storage,drive=live,removable=on,bootindex=2 \
  -drive if=none,id=seed,format=raw,readonly=on,file=/work/${vm_dir#build/}/cidata.img \
  -device usb-storage,drive=seed,removable=on \
  -netdev user,id=net,restrict=on,hostfwd=tcp:127.0.0.1:${ssh_port}-:22 \
  -device virtio-net-pci,netdev=net,romfile= \
  -qmp unix:/work/${vm_dir#build/}/qmp.sock,server=on,wait=off \
  -chardev socket,id=serial,path=/work/${vm_dir#build/}/serial.sock,server=on,wait=off,logfile=/work/${vm_dir#build/}/serial.log \
  -display none -serial chardev:serial -monitor none -no-reboot
