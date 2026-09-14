#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
name=${1:-kernel-set-boot-vm}
[[ $name =~ ^[a-zA-Z0-9_-]+$ ]]
dir=build/$name
test -s "$dir/boot.img"
test -s "$dir/root.img"
# Never accept a PASS marker left by an earlier boot.
[[ ! -e $dir/serial.log ]]
docker run --rm --network none --user "$(id -u):$(id -g)" \
  --name oma-snap-kernel-set-boot-test \
  -v "$PWD/$dir:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci \
  -drive if=none,id=loader,format=raw,readonly=on,file=/work/boot.img \
  -device virtio-blk-pci,drive=loader,bootindex=1 \
  -drive if=none,id=root,format=raw,file=/work/root.img \
  -device virtio-blk-pci,drive=root,bootindex=2 \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -nic none -display none -monitor none -no-reboot
expected=$(awk 'NR == 1 {set=$0} NR == 3 {print "OMA_SET_BOOT_PASS: " set " " $0}' "$dir/root/etc/oma-test-expected")
tr -d '\r' < "$dir/serial.log" | grep -Fx "$expected"
if grep -q 'OMA_SET_BOOT_FAIL:' "$dir/serial.log"; then exit 1; fi
echo 'PASS: retained set survived a real ARM UEFI/initramfs/root transition'
