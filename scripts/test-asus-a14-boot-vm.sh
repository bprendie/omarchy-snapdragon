#!/bin/bash
# Generic ARM VM regression with the ASUS candidate initramfs, not ASUS emulation.
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir=build/asus-a14-boot-vm
[[ -s build/asus-a14-audit/initramfs.img && ! -e $test_dir/boot.img ]]
mkdir -p "$test_dir"
cp build/asus-a14-audit/initramfs.img "$test_dir/"
cp build/installer-iso/oma_snap/boot/vmlinuz.efi "$test_dir/"
cat > "$test_dir/grub.cfg" <<'EOF'
search --no-floppy --label ASUS_TEST --set=root
set timeout=0
menuentry 'ASUS A14 preliminary initramfs - generic ARM VM' {
  linux /vmlinuz.efi archisobasedir=oma_snap archisolabel=OMA_SNAP arch=aarch64 cow_spacesize=2G copytoram=y copytoram_size=12G systemd.gpt_auto=no rd.systemd.gpt_auto=no console=ttyAMA0,115200 console=tty0
  initrd /initramfs.img
}
EOF
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o /output/asus-a14-boot-vm/BOOTAA64.EFI \
  'boot/grub/grub.cfg=/output/asus-a14-boot-vm/grub.cfg'
docker run --rm --network none -v "$PWD/$test_dir:/work" oma-snap-builder:local bash -ec '
  truncate -s 512M /work/boot.img
  mformat -i /work/boot.img -v ASUS_TEST ::
  mmd -i /work/boot.img ::/EFI ::/EFI/BOOT
  mcopy -i /work/boot.img /work/BOOTAA64.EFI ::/EFI/BOOT/BOOTAA64.EFI
  mcopy -i /work/boot.img /work/vmlinuz.efi /work/initramfs.img ::/
'
docker run --rm --network none --user "$(id -u):$(id -g)" --name oma-snap-asus-boot-test \
  -v "$PWD/$test_dir:/work" -v "$PWD/dist:/images:ro" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 8192 -smp 4 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd \
  -device virtio-rng-pci -device virtio-gpu-pci -device qemu-xhci -device usb-kbd \
  -drive if=none,id=loader,format=raw,readonly=on,file=/work/boot.img \
  -device usb-storage,drive=loader,removable=on,bootindex=1 \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/oma-snap-installer-thinkpad-hp-audio-arm64.iso \
  -device usb-storage,drive=live,removable=on,bootindex=2 \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -nic none -display none -monitor none -no-reboot
