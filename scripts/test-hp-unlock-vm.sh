#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=build/hp-unlock-vm
[[ -s build/hp-unlock-test/initramfs.img ]]
[[ ! -e $test_dir/boot.img && ! -e $test_dir/serial.log ]]
mkdir -p "$test_dir"
if [[ ! -e $test_dir/encrypted.img ]]; then
  # Public test-only key and cheap KDF for software CPU emulation, not real disks.
  printf %s oma-test-only > "$test_dir/test-key"
  truncate -s 128M "$test_dir/encrypted.img"
  cryptsetup luksFormat --batch-mode --type luks2 --pbkdf pbkdf2 \
    --pbkdf-force-iterations 1000 --key-file "$test_dir/test-key" "$test_dir/encrypted.img"
fi
cp build/hp-unlock-test/{vmlinuz.efi,initramfs.img} "$test_dir/"
cat > "$test_dir/grub.cfg" <<'EOF'
search --no-floppy --label OMA_UNLOCK --set=root
set timeout=0
menuentry 'HP unlock candidate - VM regression' {
  linux /vmlinuz.efi cryptdevice=/dev/vda:root root=/dev/mapper/root rw quiet splash console=tty0
  initrd /initramfs.img
}
EOF
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o /output/hp-unlock-vm/BOOTAA64.EFI \
  'boot/grub/grub.cfg=/output/hp-unlock-vm/grub.cfg'
docker run --rm --network none -v "$PWD/$test_dir:/work" oma-snap-builder:local bash -ec '
  truncate -s 512M /work/boot.img
  mformat -i /work/boot.img -v OMA_UNLOCK ::
  mmd -i /work/boot.img ::/EFI ::/EFI/BOOT
  mcopy -i /work/boot.img /work/BOOTAA64.EFI ::/EFI/BOOT/BOOTAA64.EFI
  mcopy -i /work/boot.img /work/vmlinuz.efi /work/initramfs.img ::/
'
docker run --rm --network none --user "$(id -u):$(id -g)" --name oma-snap-hp-unlock-test \
  -v "$PWD/$test_dir:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci -device usb-kbd \
  -drive if=none,id=loader,format=raw,readonly=on,file=/work/boot.img \
  -device usb-storage,drive=loader,removable=on,bootindex=1 \
  -drive if=none,id=root,format=raw,file=/work/encrypted.img \
  -device virtio-blk-pci,drive=root \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -nic none -display none -monitor none -no-reboot
