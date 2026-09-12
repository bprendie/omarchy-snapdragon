#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Test a rebuilt initramfs against the preserved console root, without a target disk.
test_dir=build/initramfs-smoke
[[ ! -e $test_dir/boot.img ]] || { echo 'Preserve the previous smoke artifacts first' >&2; exit 1; }
sha256sum -c dist/oma-snap-console-arm64.iso.sha256
# The preserved console root has 7.0.0-30 modules; do not pair it with a new kernel.
rg -q 'usr/lib/modules/7.0.0-30-generic/modules.dep' build/initramfs-contents.txt
for module in panel-edp pwm_bl leds-qcom-lpg; do
  rg -q "/$module\.ko" build/initramfs-contents.txt
done
mkdir -p "$test_dir"
cp build/initramfs.img "$test_dir/initramfs.img"
cp build/ubuntu-casper/vmlinuz "$test_dir/vmlinuz.efi"
sha256sum "$test_dir/initramfs.img" "$test_dir/vmlinuz.efi" > "$test_dir/inputs.sha256"
cat > "$test_dir/grub.cfg" <<'EOF'
search --no-floppy --label OMA_SMOKE --set=root
set timeout=0
menuentry 'Initramfs smoke test' {
  linux /vmlinuz.efi archisobasedir=oma_snap archisolabel=OMA_SNAP arch=aarch64 cow_spacesize=1G console=tty0 console=ttyAMA0,115200
  initrd /initramfs.img
}
EOF
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o /output/initramfs-smoke/BOOTAA64.EFI \
  'boot/grub/grub.cfg=/output/initramfs-smoke/grub.cfg'
docker run --rm -v "$PWD/$test_dir:/work" oma-snap-builder:local bash -ec '
  truncate -s 512M /work/boot.img
  mformat -i /work/boot.img -v OMA_SMOKE ::
  mmd -i /work/boot.img ::/EFI ::/EFI/BOOT
  mcopy -i /work/boot.img /work/BOOTAA64.EFI ::/EFI/BOOT/BOOTAA64.EFI
  mcopy -i /work/boot.img /work/vmlinuz.efi /work/initramfs.img ::/
'
docker run --rm --network none --user "$(id -u):$(id -g)" --name oma-snap-initramfs-test \
  -v "$PWD/dist:/images:ro" -v "$PWD/$test_dir:/work" oma-snap-builder:local \
  qemu-system-aarch64 -machine virt -cpu cortex-a72 -m 4096 -smp 2 \
  -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -device virtio-rng-pci \
  -device qemu-xhci \
  -drive if=none,id=loader,format=raw,readonly=on,file=/work/boot.img \
  -device usb-storage,drive=loader,removable=on,bootindex=1 \
  -drive if=none,id=live,format=raw,readonly=on,file=/images/oma-snap-console-arm64.iso \
  -device usb-storage,drive=live,removable=on,bootindex=2 \
  -chardev socket,id=serial,path=/work/serial.sock,server=on,wait=off,logfile=/work/serial.log \
  -serial chardev:serial -qmp unix:/work/qmp.sock,server=on,wait=off \
  -nic none -display none -monitor none -no-reboot
