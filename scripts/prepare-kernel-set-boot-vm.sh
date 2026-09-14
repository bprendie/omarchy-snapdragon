#!/bin/bash
# Assemble a disposable root and ARM UEFI loader from a completed staging build.
set -euo pipefail
cd "$(dirname "$0")/.."
builder=${1:?Usage: prepare-kernel-set-boot-vm.sh CONTAINER STAGING_DIRECTORY NEW_NAME}
stage=${2:?Missing staging directory}
name=${3:?Missing new fixture name}
[[ $name =~ ^[a-zA-Z0-9_-]+$ && $stage == /var/lib/oma-snap/staging/* ]]
dir=build/$name
[[ ! -e $dir ]]
mkdir -p "$dir"
docker cp "$builder:$stage/built.json" "$dir/built.json"
id=$(jq -er '.hardware_set' "$dir/built.json")
release=$(jq -er '.kernel_release' "$dir/built.json")
entry=$(jq -er '.boot_entry' "$dir/built.json")
[[ $id =~ ^[a-f0-9]{64}$ && $entry =~ ^[a-f0-9]{64}$ ]]
[[ $release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[0-9]+-generic$ ]]
jq -e '.schema == 1 and .status == "built-unvalidated"' "$dir/built.json" >/dev/null
set_path=/usr/lib/oma-snap/sets/$id
docker exec "$builder" oma-snap-kernel-set --verify-installed "$set_path"
mkdir -p "$dir/root"/{bin,sbin,etc,proc,sys,dev,run,usr/lib/oma-snap/sets}
mkdir -p "$dir/root/usr/lib/"{modules,firmware}/"$release"
docker cp "$builder:$set_path" "$dir/root/usr/lib/oma-snap/sets/$id"
docker cp "$builder:$set_path/vmlinuz.efi" "$dir/vmlinuz.efi"
docker cp "$builder:$stage/initramfs.img" "$dir/initramfs.img"
docker cp "$builder:$stage/boot-set" "$dir/root/etc/oma-test-expected"
printf '%s\n' "$id" "$release" "$entry" | cmp - "$dir/root/etc/oma-test-expected"
for pair in kernel:vmlinuz.efi initramfs:initramfs.img; do
  field=${pair%%:*}_sha256
  file=${pair#*:}
  expected=$(jq -er --arg field "$field" '.[$field]' "$dir/built.json")
  [[ $expected =~ ^[a-f0-9]{64}$ ]]
  printf '%s  %s\n' "$expected" "$dir/$file" | sha256sum -c -
done
docker cp "$builder:/usr/lib/initcpio/busybox" "$dir/root/bin/busybox"
ln -s usr/lib "$dir/root/lib"
# The Arch initcpio BusyBox is dynamically linked, even in the minimal root.
for lib in ld-linux-aarch64.so.1 libc.so.6 libcrypt.so.2; do
  docker cp -L "$builder:/usr/lib/$lib" "$dir/root/usr/lib/$lib"
done
install -m755 tests/kernel-set-boot-init "$dir/root/sbin/init"
docker run --rm --platform linux/arm64 --network none \
  -v "$PWD/$dir/root:/testroot:ro" oma-snap-arch-base:local \
  chroot /testroot /bin/busybox true
truncate -s 2G "$dir/root.img"
mkfs.ext4 -q -F -L SETROOT -d "$dir/root" "$dir/root.img"
cp tests/kernel-set-boot-grub.cfg "$dir/grub.cfg"
docker exec oma-snap-root grub-mkstandalone -O arm64-efi \
  -o "/output/$name/BOOTAA64.EFI" "boot/grub/grub.cfg=/output/$name/grub.cfg"
docker run --rm --network none --user "$(id -u):$(id -g)" \
  -v "$PWD/$dir:/work" oma-snap-builder:local bash -ec '
  truncate -s 512M /work/boot.img
  mformat -i /work/boot.img -v SETBOOT ::
  mmd -i /work/boot.img ::/EFI ::/EFI/BOOT
  mcopy -i /work/boot.img /work/BOOTAA64.EFI ::/EFI/BOOT/BOOTAA64.EFI
  mcopy -i /work/boot.img /work/vmlinuz.efi /work/initramfs.img ::/
'
echo "Prepared component fixture: $dir"
